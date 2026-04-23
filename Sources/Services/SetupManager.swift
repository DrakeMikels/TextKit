import Foundation
import Observation

@MainActor
@Observable
final class SetupManager {
    private enum SetupError: LocalizedError {
        case runtimeStillMissing
        case downloadFailed(String)
        case verificationFailed(String)

        var errorDescription: String? {
            switch self {
            case .runtimeStillMissing:
                return "This copy of TextKit is missing its local AI runtime. Reinstall the app to continue."
            case let .downloadFailed(message):
                return message
            case let .verificationFailed(message):
                return message
            }
        }
    }

    private let systemPrompt = "You are a helpful assistant."
    private let smokePrompt = "Reply with only the word OK."

    private(set) var isRunning = false
    private(set) var progressValue = 0.0
    private(set) var stepTitle = ""
    private(set) var stepDetail = ""
    private(set) var failureMessage: String?

    var hasFailure: Bool {
        failureMessage != nil
    }

    func runSetup(for model: LocalModelDescriptor) async -> Bool {
        guard !isRunning else { return false }

        failureMessage = nil
        isRunning = true
        updateProgress(
            title: "Checking your Mac",
            detail: "Looking for the bundled local AI runtime and selected model.",
            progress: 0.08
        )

        defer { isRunning = false }

        do {
            if !runtimeToolsAvailable {
                updateProgress(
                    title: "Checking local AI runtime",
                    detail: "TextKit is confirming that its built-in local AI runtime is available.",
                    progress: 0.28
                )
                throw SetupError.runtimeStillMissing
            }

            guard let completionExecutableURL = RuntimeLocator.executableURL(named: "llama-completion") else {
                throw SetupError.runtimeStillMissing
            }

            if !(await modelIsCached(model)) {
                updateProgress(
                    title: "Downloading the model",
                    detail: "Downloading \(model.displayName) for offline use.",
                    progress: 0.68
                )

                do {
                    _ = try await ProcessRunner.run(
                        executableURL: completionExecutableURL,
                        arguments: downloadArguments(for: model),
                        environment: RuntimeLocator.processEnvironment()
                    )
                } catch {
                    throw SetupError.downloadFailed(error.localizedDescription)
                }
            }

            updateProgress(
                title: "Checking the download",
                detail: "Running a quick local check before TextKit starts using the model.",
                progress: 0.92
            )

            do {
                _ = try await ProcessRunner.run(
                    executableURL: completionExecutableURL,
                    arguments: verificationArguments(for: model),
                    environment: RuntimeLocator.processEnvironment()
                )
            } catch {
                throw SetupError.verificationFailed(error.localizedDescription)
            }

            updateProgress(
                title: "Setup complete",
                detail: "\(model.displayName) is ready to use on this Mac.",
                progress: 1
            )
            return true
        } catch {
            failureMessage = error.localizedDescription
            stepTitle = "Setup failed"
            stepDetail = failureMessage ?? "TextKit could not finish the local AI setup."
            progressValue = 0
            return false
        }
    }

    func resetFailure() {
        guard !isRunning else { return }
        failureMessage = nil
    }

    func primaryButtonTitle(for runtimeState: ModelRuntimeState) -> String {
        if hasFailure {
            return "Try Again"
        }

        switch runtimeState {
        case .missingRuntime:
            return "Check Again"
        case .missingModel:
            return "Download Model"
        default:
            return "Set Up Local AI"
        }
    }

    func summary(for runtimeState: ModelRuntimeState, model: LocalModelDescriptor) -> String {
        if isRunning {
            return stepDetail
        }

        if let failureMessage {
            return failureMessage
        }

        switch runtimeState {
        case .missingRuntime:
            return "TextKit couldn't find its bundled local AI runtime. Reinstall the app to continue."
        case .missingModel:
            return "TextKit needs to download the selected model once before it can work offline."
        default:
            return "\(model.displayName) is almost ready."
        }
    }

    private var runtimeToolsAvailable: Bool {
        RuntimeLocator.executableURL(named: "llama-completion") != nil
            && RuntimeLocator.executableURL(named: "llama-cli") != nil
            && RuntimeLocator.executableURL(named: "llama-server") != nil
    }

    private func modelIsCached(_ model: LocalModelDescriptor) async -> Bool {
        guard let probeExecutableURL = RuntimeLocator.executableURL(named: "llama-cli") else {
            return false
        }

        do {
            let result = try await ProcessRunner.run(
                executableURL: probeExecutableURL,
                arguments: ["--cache-list"],
                environment: RuntimeLocator.processEnvironment()
            )

            return result.stdout.contains("\(model.repository):\(model.cacheTag)")
                || result.stdout.contains(model.suggestedFilename)
        } catch {
            return false
        }
    }

    private func downloadArguments(for model: LocalModelDescriptor) -> [String] {
        var arguments = [
            "--verbosity", "0",
            "--simple-io",
            "--no-warmup",
            "-hf", model.repository,
            "-hff", model.suggestedFilename,
            "-sys", systemPrompt,
            "-p", smokePrompt,
            "-n", "8",
            "--temp", "0"
        ]

        if model.requiresReasoningOff {
            arguments.append(contentsOf: ["--reasoning", "off"])
        }

        return arguments
    }

    private func verificationArguments(for model: LocalModelDescriptor) -> [String] {
        var arguments = [
            "--verbosity", "0",
            "--offline",
            "--simple-io",
            "--no-warmup",
            "-hf", model.repository,
            "-hff", model.suggestedFilename,
            "-sys", systemPrompt,
            "-p", smokePrompt,
            "-n", "8",
            "--temp", "0"
        ]

        if model.requiresReasoningOff {
            arguments.append(contentsOf: ["--reasoning", "off"])
        }

        return arguments
    }

    private func updateProgress(title: String, detail: String, progress: Double) {
        stepTitle = title
        stepDetail = detail
        progressValue = progress
    }
}
