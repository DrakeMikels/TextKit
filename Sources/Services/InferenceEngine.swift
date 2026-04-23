import Foundation

struct InferenceOutput {
    let text: String
    let keepsRuntimeWarm: Bool
}

enum InferenceEngineError: LocalizedError {
    case missingRuntime(String)
    case modelNotInstalled(String)
    case executionFailed(String)
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case let .missingRuntime(command):
            return "The local AI runtime is missing. Reinstall TextKit, or run \(command) if you're setting up the repo locally."
        case let .modelNotInstalled(command):
            return "The Qwen model is not cached locally yet. Run \(command)."
        case let .executionFailed(message):
            return message
        case .emptyOutput:
            return "The local model returned an empty response."
        }
    }
}

struct InferenceEngine {
    private let serverCoordinator = LlamaServerCoordinator()

    func generate(
        for request: GenerationRequest,
        prompt: ComposedPrompt,
        executableURL: URL?,
        serverExecutableURL: URL?,
        model: LocalModelDescriptor,
        setupCommand: String,
        warmCacheSeconds: Double,
        modelManager: ModelManager
    ) async throws -> InferenceOutput {
        if warmCacheSeconds > 0, let serverExecutableURL {
            do {
                let output = try await serverCoordinator.generate(
                    for: request,
                    prompt: prompt,
                    executableURL: serverExecutableURL,
                    model: model,
                    modelManager: modelManager,
                    warmCacheSeconds: warmCacheSeconds
                )

                return InferenceOutput(text: output, keepsRuntimeWarm: true)
            } catch let error as InferenceEngineError {
                if case .modelNotInstalled = error {
                    throw error
                }

                await serverCoordinator.stop()
            } catch {
                await serverCoordinator.stop()
            }
        }

        let output = try await generateWithCompletion(
            for: request,
            prompt: prompt,
            executableURL: executableURL,
            model: model,
            setupCommand: setupCommand
        )

        return InferenceOutput(text: output, keepsRuntimeWarm: false)
    }

    func stopWarmRuntime(modelManager: ModelManager) async {
        await serverCoordinator.stop(modelManager: modelManager)
    }

    func _extractAssistantResponseForTests(from stdout: String) -> String {
        extractAssistantResponse(from: stdout)
    }

    func _extractChatCompletionContentForTests(from data: Data) throws -> String {
        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return completion.choices.first?.message.content ?? ""
    }

    private func generateWithCompletion(
        for request: GenerationRequest,
        prompt: ComposedPrompt,
        executableURL: URL?,
        model: LocalModelDescriptor,
        setupCommand: String
    ) async throws -> String {
        guard let executableURL else {
            throw InferenceEngineError.missingRuntime(setupCommand)
        }

        let result: ProcessResult
        do {
            result = try await ProcessRunner.run(
                executableURL: executableURL,
                arguments: arguments(for: request, prompt: prompt, model: model),
                environment: RuntimeLocator.processEnvironment()
            )
        } catch let error as ProcessRunnerError {
            switch error {
            case let .nonZeroExit(_, _, _, stderr):
                if stderr.contains("required file is not available in cache (offline mode)") {
                    throw InferenceEngineError.modelNotInstalled(setupCommand)
                }
                throw InferenceEngineError.executionFailed(cleanError(stderr))
            case let .launchFailed(message):
                throw InferenceEngineError.executionFailed(message)
            }
        } catch {
            throw InferenceEngineError.executionFailed(error.localizedDescription)
        }

        let output = extractAssistantResponse(from: result.stdout)
        guard !output.isEmpty else {
            throw InferenceEngineError.emptyOutput
        }

        return output
    }

    private func arguments(
        for request: GenerationRequest,
        prompt: ComposedPrompt,
        model: LocalModelDescriptor
    ) -> [String] {
        var arguments = [
            "--verbosity", "0",
            "--offline",
            "--simple-io",
            "--no-warmup",
            "-hf", model.repository,
            "-hff", model.suggestedFilename,
            "-sys", prompt.systemPrompt,
            "-p", prompt.userPrompt,
            "-n", String(request.effectiveMaxTokens),
            "--temp", String(format: "%.2f", request.promptConfiguration.temperature),
            "-s", String(request.promptConfiguration.seed)
        ]

        if model.requiresReasoningOff {
            arguments.append(contentsOf: ["--reasoning", "off"])
        }

        return arguments
    }

    private func extractAssistantResponse(from stdout: String) -> String {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let assistantRange = trimmed.range(of: "\nassistant\n", options: .backwards) {
            var reply = String(trimmed[assistantRange.upperBound...])
            if let eofRange = reply.range(of: "\n\n> EOF by user", options: .backwards) {
                reply = String(reply[..<eofRange.lowerBound])
            }
            return reply.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let promptRange = trimmed.range(of: "\n> ", options: .backwards) {
            let afterPrompt = trimmed[promptRange.upperBound...]
            if let separator = afterPrompt.range(of: "\n\n") {
                var reply = String(afterPrompt[separator.upperBound...])
                if let exitingRange = reply.range(of: "\n\nExiting...", options: .backwards) {
                    reply = String(reply[..<exitingRange.lowerBound])
                }
                return reply.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return trimmed
    }

    private func cleanError(_ stderr: String) -> String {
        let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "llama.cpp failed to generate a response." : trimmed
    }
}
