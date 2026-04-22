import Foundation
import Observation

struct LocalModelDescriptor {
    let displayName: String
    let repository: String
    let suggestedFilename: String
    let runtime: String
}

enum ModelRuntimeState: Equatable {
    case unknown
    case missingRuntime
    case missingModel
    case ready
    case running
    case failed(String)
}

@MainActor
@Observable
final class ModelManager {
    let defaultModel = LocalModelDescriptor(
        displayName: "Qwen2.5 0.5B Instruct",
        repository: "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
        suggestedFilename: "qwen2.5-0.5b-instruct-q5_k_m.gguf",
        runtime: "llama.cpp via llama-completion"
    )

    private(set) var isWarm = false
    private(set) var runtimeState: ModelRuntimeState = .unknown

    var runtimeExecutableURL: URL? {
        Self.resolveExecutable(named: "llama-completion")
    }

    var runtimeProbeExecutableURL: URL? {
        Self.resolveExecutable(named: "llama-cli")
    }

    var setupCommand: String {
        "./script/setup_model_runtime.sh"
    }

    var statusSummary: String {
        switch runtimeState {
        case .unknown:
            return "Checking local model"
        case .missingRuntime:
            return "llama.cpp runtime missing"
        case .missingModel:
            return "Qwen model not downloaded"
        case .ready:
            return isWarm ? "On-device · warm" : "On-device"
        case .running:
            return "Generating locally"
        case let .failed(message):
            return message
        }
    }

    var runtimeDetail: String {
        switch runtimeState {
        case .unknown:
            return "Checking for llama.cpp and the cached Qwen GGUF."
        case .missingRuntime:
            return "Run \(setupCommand) to install llama.cpp and cache the model."
        case .missingModel:
            return "Run \(setupCommand) to download \(defaultModel.suggestedFilename)."
        case .ready:
            return "Using \(defaultModel.displayName) from the local Hugging Face cache."
        case .running:
            return "Running \(defaultModel.displayName) locally with llama.cpp."
        case let .failed(message):
            return message
        }
    }

    func markWarm() {
        isWarm = true
    }

    func markRunning() {
        isWarm = true
        runtimeState = .running
    }

    func markReady() {
        isWarm = true
        runtimeState = .ready
    }

    func markMissingRuntime() {
        runtimeState = .missingRuntime
    }

    func markMissingModel() {
        runtimeState = .missingModel
    }

    func markFailure(_ message: String) {
        runtimeState = .failed(message)
    }

    func refreshAvailability() async {
        guard runtimeExecutableURL != nil else {
            runtimeState = .missingRuntime
            return
        }

        guard let probeExecutableURL = runtimeProbeExecutableURL ?? runtimeExecutableURL else {
            runtimeState = .missingRuntime
            return
        }

        do {
            let result = try await ProcessRunner.run(
                executableURL: probeExecutableURL,
                arguments: ["--cache-list"]
            )

            let modelIsCached = result.stdout.contains("\(defaultModel.repository):Q5_K_M")
                || result.stdout.contains(defaultModel.suggestedFilename)

            runtimeState = modelIsCached ? .ready : .missingModel
        } catch {
            runtimeState = .failed("Failed to inspect llama.cpp cache.")
        }
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
