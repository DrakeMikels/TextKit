import Testing
@testable import TextKit

struct SetupManagerTests {
    @Test
    @MainActor
    func choosesActionTitlesFromRuntimeState() {
        let manager = SetupManager()

        #expect(manager.primaryButtonTitle(for: .missingRuntime) == "Install Local AI")
        #expect(manager.primaryButtonTitle(for: .missingModel) == "Download Model")
        #expect(manager.primaryButtonTitle(for: .ready) == "Set Up Local AI")
    }

    @Test
    @MainActor
    func summarizesMissingModelState() {
        let manager = SetupManager()
        let model = LocalModelDescriptor(
            displayName: "Qwen2.5 0.5B Instruct",
            repository: "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
            suggestedFilename: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
            runtime: "llama.cpp local runtime",
            quantPreset: .balanced
        )

        let summary = manager.summary(for: .missingModel, model: model)

        #expect(summary.contains("download"))
        #expect(summary.contains("offline"))
    }
}
