import Foundation
import Testing
@testable import TextKit

struct RuntimeSettingsTests {
    @Test
    func quantPresetMapsToExpectedModelFiles() {
        #expect(QuantPreset.fast.suggestedFilename == "qwen2.5-0.5b-instruct-q4_k_s.gguf")
        #expect(QuantPreset.balanced.suggestedFilename == "qwen2.5-0.5b-instruct-q4_k_m.gguf")
        #expect(QuantPreset.quality.suggestedFilename == "qwen2.5-0.5b-instruct-q5_k_m.gguf")
    }

    @Test
    func modelProfileAdjustsEffectiveTokenBudget() {
        let baseConfiguration = ModePromptConfiguration.default(for: .promptDetailed)

        let fastRequest = GenerationRequest(
            inputText: "Create a detailed launch prompt.",
            refineInstruction: "",
            tool: .prompt,
            mode: .promptDetailed,
            modelProfile: .fast,
            quantPreset: .balanced,
            promptConfiguration: baseConfiguration
        )

        let balancedRequest = GenerationRequest(
            inputText: "Create a detailed launch prompt.",
            refineInstruction: "",
            tool: .prompt,
            mode: .promptDetailed,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: baseConfiguration
        )

        let qualityRequest = GenerationRequest(
            inputText: "Create a detailed launch prompt.",
            refineInstruction: "",
            tool: .prompt,
            mode: .promptDetailed,
            modelProfile: .quality,
            quantPreset: .balanced,
            promptConfiguration: baseConfiguration
        )

        #expect(fastRequest.effectiveMaxTokens < balancedRequest.effectiveMaxTokens)
        #expect(qualityRequest.effectiveMaxTokens > balancedRequest.effectiveMaxTokens)
    }

    @Test
    @MainActor
    func settingsStoreSeparatesGenerationAndRuntimeRevisions() {
        let suiteName = "TextKitTests.SettingsStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        let initialGenerationRevision = store.generationSettingsRevision
        let initialRuntimeRevision = store.runtimeSelectionRevision

        store.setTaskTemplate("Task: Return only a short rewrite.", for: .rewriteShort)
        #expect(store.generationSettingsRevision == initialGenerationRevision + 1)
        #expect(store.runtimeSelectionRevision == initialRuntimeRevision)

        store.quantPreset = .quality
        #expect(store.generationSettingsRevision == initialGenerationRevision + 2)
        #expect(store.runtimeSelectionRevision == initialRuntimeRevision + 1)
    }
}
