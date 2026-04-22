import Foundation
import Observation

@MainActor
@Observable
final class SetupManager {
    private enum SetupError: LocalizedError {
        case homebrewMissing
        case runtimeInstallFailed(String)
        case runtimeStillMissing
        case downloadFailed(String)
        case verificationFailed(String)

        var errorDescription: String? {
            switch self {
            case .homebrewMissing:
                return "Homebrew is required before TextKit can install its local AI tools."
            case let .runtimeInstallFailed(message):
                return message
            case .runtimeStillMissing:
                return "TextKit installed the local AI tools, but they still are not available."
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
            detail: "Looking for the local AI tools and selected model.",
            progress: 0.08
        )

        defer { isRunning = false }

        do {
            guard let brewURL = Self.resolveExecutable(named: "brew") else {
                throw SetupError.homebrewMissing
            }

            if !runtimeToolsAvailable {
                updateProgress(
                    title: "Installing local AI tools",
                    detail: "Adding the tools TextKit needs to run on-device.",
                    progress: 0.28
                )

                do {
                    _ = try await ProcessRunner.run(
                        executableURL: brewURL,
                        arguments: ["install", "llama.cpp"]
                    )
                } catch {
                    throw SetupError.runtimeInstallFailed(error.localizedDescription)
                }
            }

            guard let completionExecutableURL = Self.resolveExecutable(named: "llama-completion") else {
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
                        arguments: downloadArguments(for: model)
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
                    arguments: verificationArguments(for: model)
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
            return "Install Local AI"
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
            return "TextKit needs a few local AI tools before it can run on this Mac."
        case .missingModel:
            return "TextKit needs to download the selected model once before it can work offline."
        default:
            return "\(model.displayName) is almost ready."
        }
    }

    private var runtimeToolsAvailable: Bool {
        Self.resolveExecutable(named: "llama-completion") != nil
            && Self.resolveExecutable(named: "llama-cli") != nil
            && Self.resolveExecutable(named: "llama-server") != nil
    }

    private func modelIsCached(_ model: LocalModelDescriptor) async -> Bool {
        guard let probeExecutableURL = Self.resolveExecutable(named: "llama-cli") else {
            return false
        }

        do {
            let result = try await ProcessRunner.run(
                executableURL: probeExecutableURL,
                arguments: ["--cache-list"]
            )

            return result.stdout.contains("\(model.repository):\(model.quantPreset.cacheTag)")
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

    private static func resolveExecutable(named executable: String) -> URL? {
        let defaultPaths = [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)"
        ]

        for path in defaultPaths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in environmentPath.split(separator: ":") {
            let candidatePath = String(directory) + "/" + executable
            if FileManager.default.isExecutableFile(atPath: candidatePath) {
                return URL(fileURLWithPath: candidatePath)
            }
        }

        return nil
    }
}
