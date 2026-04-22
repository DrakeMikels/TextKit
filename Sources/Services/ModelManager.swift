import Foundation
import Observation

struct LocalModelDescriptor {
    let displayName: String
    let repository: String
    let suggestedFilename: String
    let runtime: String
    let quantPreset: QuantPreset
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
    private let modelDisplayName = "Qwen2.5 0.5B Instruct"
    private let modelRepository = "Qwen/Qwen2.5-0.5B-Instruct-GGUF"
    private let runtimeName = "llama.cpp via llama-completion"

    private(set) var isWarm = false
    private(set) var runtimeState: ModelRuntimeState = .unknown

    var runtimeExecutableURL: URL? {
        Self.resolveExecutable(named: "llama-completion")
    }

    var runtimeProbeExecutableURL: URL? {
        Self.resolveExecutable(named: "llama-cli")
    }

    func model(for quantPreset: QuantPreset) -> LocalModelDescriptor {
        LocalModelDescriptor(
            displayName: modelDisplayName,
            repository: modelRepository,
            suggestedFilename: quantPreset.suggestedFilename,
            runtime: runtimeName,
            quantPreset: quantPreset
        )
    }

    func setupCommand(for quantPreset: QuantPreset) -> String {
        "./script/setup_model_runtime.sh --quant \(quantPreset.rawValue)"
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

    func runtimeDetail(for quantPreset: QuantPreset) -> String {
        let model = model(for: quantPreset)

        switch runtimeState {
        case .unknown:
            return "Checking for llama.cpp and the cached \(model.suggestedFilename)."
        case .missingRuntime:
            return "Run \(setupCommand(for: quantPreset)) to install llama.cpp and cache the model."
        case .missingModel:
            return "Run \(setupCommand(for: quantPreset)) to download \(model.suggestedFilename)."
        case .ready:
            return "Using \(model.displayName) (\(model.quantPreset.title) quant) from the local Hugging Face cache."
        case .running:
            return "Running \(model.displayName) locally with llama.cpp."
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

    func refreshAvailability(for quantPreset: QuantPreset) async {
        guard runtimeExecutableURL != nil else {
            runtimeState = .missingRuntime
            return
        }

        guard let probeExecutableURL = runtimeProbeExecutableURL ?? runtimeExecutableURL else {
            runtimeState = .missingRuntime
            return
        }

        do {
            let model = model(for: quantPreset)
            let result = try await ProcessRunner.run(
                executableURL: probeExecutableURL,
                arguments: ["--cache-list"]
            )

            let modelIsCached = result.stdout.contains("\(model.repository):\(model.quantPreset.cacheTag)")
                || result.stdout.contains(model.suggestedFilename)

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
