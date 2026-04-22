import Foundation

actor LlamaServerCoordinator {
    private struct RuntimeSignature: Equatable {
        let repository: String
        let filename: String
    }

    private let host = "127.0.0.1"
    private let port = 38081

    private var process: Process?
    private var activeSignature: RuntimeSignature?
    private var idleShutdownTask: Task<Void, Never>?
    private var intentionallyStoppingPID: Int32?

    func generate(
        for request: GenerationRequest,
        prompt: ComposedPrompt,
        executableURL: URL,
        model: LocalModelDescriptor,
        modelManager: ModelManager,
        warmCacheSeconds: Double
    ) async throws -> String {
        try await ensureServer(
            executableURL: executableURL,
            model: model,
            modelManager: modelManager
        )

        let response = try await requestCompletion(for: request, prompt: prompt)
        await MainActor.run {
            modelManager.markWarm()
        }
        scheduleIdleShutdown(after: warmCacheSeconds, modelManager: modelManager)
        return response
    }

    func stop(modelManager: ModelManager? = nil) async {
        idleShutdownTask?.cancel()
        idleShutdownTask = nil

        guard let process else {
            activeSignature = nil
            if let modelManager {
                await MainActor.run {
                    modelManager.markReady(isWarm: false)
                }
            }
            return
        }

        if process.isRunning {
            intentionallyStoppingPID = process.processIdentifier
            process.terminate()
            try? await Task.sleep(for: .milliseconds(250))
            if process.isRunning {
                process.interrupt()
            }
        }

        self.process = nil
        activeSignature = nil

        if let modelManager {
            await MainActor.run {
                modelManager.markReady(isWarm: false)
            }
        }
    }

    private func ensureServer(
        executableURL: URL,
        model: LocalModelDescriptor,
        modelManager: ModelManager
    ) async throws {
        let signature = RuntimeSignature(
            repository: model.repository,
            filename: model.suggestedFilename
        )

        if let process, process.isRunning, activeSignature == signature {
            if try await healthCheck() {
                return
            }
        }

        await stop()

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "--offline",
            "-hf", model.repository,
            "-hff", model.suggestedFilename,
            "--host", host,
            "--port", String(port),
            "--ctx-size", "4096",
            "--parallel", "1",
            "--reasoning", "off",
            "--verbosity", "1"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            Task {
                await self?.handleTermination(modelManager: modelManager)
            }
        }

        do {
            try process.run()
        } catch {
            throw InferenceEngineError.executionFailed("Couldn't start the local AI server.")
        }

        self.process = process
        activeSignature = signature

        do {
            try await waitUntilHealthy()
            await MainActor.run {
                modelManager.markWarm()
            }
        } catch {
            await stop(modelManager: modelManager)
            throw error
        }
    }

    private func waitUntilHealthy() async throws {
        for _ in 0..<50 {
            try Task.checkCancellation()

            if let process, !process.isRunning {
                throw InferenceEngineError.executionFailed("The local AI server stopped unexpectedly.")
            }

            if try await healthCheck() {
                return
            }

            try await Task.sleep(for: .milliseconds(200))
        }

        throw InferenceEngineError.executionFailed("The local AI server did not become ready in time.")
    }

    private func healthCheck() async throws -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/health") else {
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                return false
            }

            let payload = try JSONDecoder().decode(HealthResponse.self, from: data)
            return payload.status == "ok"
        } catch {
            return false
        }
    }

    private func requestCompletion(
        for request: GenerationRequest,
        prompt: ComposedPrompt
    ) async throws -> String {
        guard let url = URL(string: "http://\(host):\(port)/v1/chat/completions") else {
            throw InferenceEngineError.executionFailed("The local AI server URL is invalid.")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120

        let body = ChatCompletionRequest(
            messages: [
                ChatMessage(role: "system", content: prompt.systemPrompt),
                ChatMessage(role: "user", content: prompt.userPrompt)
            ],
            temperature: request.promptConfiguration.temperature,
            maxTokens: request.effectiveMaxTokens,
            seed: request.promptConfiguration.seed >= 0 ? request.promptConfiguration.seed : nil,
            stream: false
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw InferenceEngineError.executionFailed("The local AI server returned an invalid response.")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                if let errorPayload = try? JSONDecoder().decode(ServerErrorResponse.self, from: data),
                   let errorMessage = errorPayload.error?.message, !errorMessage.isEmpty {
                    throw InferenceEngineError.executionFailed(errorMessage)
                }

                throw InferenceEngineError.executionFailed("The local AI server returned status \(httpResponse.statusCode).")
            }

            let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            let content = completion.choices.first?.message.content
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !content.isEmpty else {
                throw InferenceEngineError.emptyOutput
            }

            return content
        } catch let error as InferenceEngineError {
            throw error
        } catch {
            throw InferenceEngineError.executionFailed(error.localizedDescription)
        }
    }

    private func scheduleIdleShutdown(after seconds: Double, modelManager: ModelManager) {
        idleShutdownTask?.cancel()

        guard seconds > 0 else {
            return
        }

        idleShutdownTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }

            await self.stop(modelManager: modelManager)
        }
    }

    private func handleTermination(modelManager: ModelManager) async {
        if process?.processIdentifier == intentionallyStoppingPID || intentionallyStoppingPID != nil {
            intentionallyStoppingPID = nil
            process = nil
            activeSignature = nil
            idleShutdownTask?.cancel()
            idleShutdownTask = nil
            return
        }

        process = nil
        activeSignature = nil
        idleShutdownTask?.cancel()
        idleShutdownTask = nil

        await MainActor.run {
            if case .running = modelManager.runtimeState {
                modelManager.markFailure("The local AI server stopped unexpectedly.")
            } else {
                modelManager.markReady(isWarm: false)
            }
        }
    }
}

private struct HealthResponse: Decodable {
    let status: String
}

private struct ChatCompletionRequest: Encodable {
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let seed: Int?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case seed
        case stream
    }
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        let message: ChatMessage
    }

    let choices: [Choice]
}

private struct ServerErrorResponse: Decodable {
    struct ErrorPayload: Decodable {
        let message: String?
    }

    let error: ErrorPayload?
}
