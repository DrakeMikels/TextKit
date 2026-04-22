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
    private let runtimeName = "llama.cpp local runtime"

    private(set) var isWarm = false
    private(set) var runtimeState: ModelRuntimeState = .unknown

    var runtimeExecutableURL: URL? {
        Self.resolveExecutable(named: "llama-completion")
    }

    var serverExecutableURL: URL? {
        Self.resolveExecutable(named: "llama-server")
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
            return "Checking local AI"
        case .missingRuntime:
            return "Local AI tools missing"
        case .missingModel:
            return "Model not downloaded"
        case .ready:
            return isWarm ? "On-device · warm" : "On-device"
        case .running:
            return "Working locally"
        case let .failed(message):
            return message
        }
    }

    func runtimeDetail(for quantPreset: QuantPreset) -> String {
        let model = model(for: quantPreset)

        switch runtimeState {
        case .unknown:
            return "Checking whether the local AI is ready."
        case .missingRuntime:
            return "TextKit still needs its local AI tools before it can run on this Mac."
        case .missingModel:
            return "TextKit still needs to download the selected local model."
        case .ready:
            return "This Mac is ready to use \(model.displayName) locally."
        case .running:
            return "TextKit is using \(model.displayName) on this Mac."
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

    func markReady(isWarm: Bool) {
        self.isWarm = isWarm
        runtimeState = .ready
    }

    func markMissingRuntime() {
        isWarm = false
        runtimeState = .missingRuntime
    }

    func markMissingModel() {
        isWarm = false
        runtimeState = .missingModel
    }

    func markFailure(_ message: String) {
        isWarm = false
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
            runtimeState = .failed("Couldn't check whether the local AI is ready.")
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
