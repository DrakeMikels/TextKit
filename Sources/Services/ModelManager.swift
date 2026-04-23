import Foundation
import Observation

struct LocalModelDescriptor {
    let displayName: String
    let repository: String
    let suggestedFilename: String
    let cacheTag: String
    let runtime: String
    let quantPreset: QuantPreset
    let requiresReasoningOff: Bool

    init(
        displayName: String,
        repository: String,
        suggestedFilename: String,
        cacheTag: String,
        runtime: String,
        quantPreset: QuantPreset,
        requiresReasoningOff: Bool = false
    ) {
        self.displayName = displayName
        self.repository = repository
        self.suggestedFilename = suggestedFilename
        self.cacheTag = cacheTag
        self.runtime = runtime
        self.quantPreset = quantPreset
        self.requiresReasoningOff = requiresReasoningOff
    }
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
    private(set) var isWarm = false
    private(set) var runtimeState: ModelRuntimeState = .unknown

    var runtimeExecutableURL: URL? {
        RuntimeLocator.executableURL(named: "llama-completion")
    }

    var serverExecutableURL: URL? {
        RuntimeLocator.executableURL(named: "llama-server")
    }

    var runtimeProbeExecutableURL: URL? {
        RuntimeLocator.executableURL(named: "llama-cli")
    }

    func model(for modelOption: LocalModelOption, quantPreset: QuantPreset) -> LocalModelDescriptor {
        LocalModelDescriptor(
            displayName: modelOption.displayName,
            repository: modelOption.repository,
            suggestedFilename: modelOption.suggestedFilename(for: quantPreset),
            cacheTag: modelOption.cacheTag(for: quantPreset),
            runtime: modelOption.runtimeName,
            quantPreset: quantPreset,
            requiresReasoningOff: modelOption.requiresReasoningOff
        )
    }

    func setupCommand(for modelOption: LocalModelOption, quantPreset: QuantPreset) -> String {
        "./script/setup_model_runtime.sh --model \(modelOption.rawValue) --quant \(quantPreset.rawValue)"
    }

    var statusSummary: String {
        switch runtimeState {
        case .unknown:
            return "Checking local AI"
        case .missingRuntime:
            return "Local AI runtime missing"
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

    func runtimeDetail(for modelOption: LocalModelOption, quantPreset: QuantPreset) -> String {
        let model = model(for: modelOption, quantPreset: quantPreset)

        switch runtimeState {
        case .unknown:
            return "Checking whether the local AI is ready."
        case .missingRuntime:
            return "This copy of TextKit is missing its bundled local AI runtime."
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

    func refreshAvailability(for modelOption: LocalModelOption, quantPreset: QuantPreset) async {
        runtimeState = await availability(for: modelOption, quantPreset: quantPreset)
    }

    func availability(for modelOption: LocalModelOption, quantPreset: QuantPreset) async -> ModelRuntimeState {
        guard runtimeExecutableURL != nil else {
            return .missingRuntime
        }

        guard let probeExecutableURL = runtimeProbeExecutableURL ?? runtimeExecutableURL else {
            return .missingRuntime
        }

        do {
            let model = model(for: modelOption, quantPreset: quantPreset)
            let result = try await ProcessRunner.run(
                executableURL: probeExecutableURL,
                arguments: ["--cache-list"],
                environment: RuntimeLocator.processEnvironment()
            )

            let modelIsCached = result.stdout.contains("\(model.repository):\(model.cacheTag)")
                || result.stdout.contains(model.suggestedFilename)

            return modelIsCached ? .ready : .missingModel
        } catch {
            return .failed("Couldn't check whether the local AI is ready.")
        }
    }
}
