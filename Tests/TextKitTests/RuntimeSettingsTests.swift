import Foundation
import Testing
@testable import TextKit

struct RuntimeSettingsTests {
    @Test
    func quantPresetMapsToExpectedModelFiles() {
        #expect(LocalModelOption.stable.suggestedFilename(for: .fast) == "qwen2.5-0.5b-instruct-q4_k_s.gguf")
        #expect(LocalModelOption.stable.suggestedFilename(for: .balanced) == "qwen2.5-0.5b-instruct-q4_k_m.gguf")
        #expect(LocalModelOption.stable.suggestedFilename(for: .quality) == "qwen2.5-0.5b-instruct-q5_k_m.gguf")
        #expect(LocalModelOption.experimental.suggestedFilename(for: .fast) == "Qwen3.5-0.8B.q4_k_s.gguf")
        #expect(LocalModelOption.experimental.suggestedFilename(for: .balanced) == "Qwen3.5-0.8B.q4_k_m.gguf")
        #expect(LocalModelOption.experimental.suggestedFilename(for: .quality) == "Qwen3.5-0.8B.q5_k_m.gguf")
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

        store.localModelOption = .experimental
        #expect(store.generationSettingsRevision == initialGenerationRevision + 3)
        #expect(store.runtimeSelectionRevision == initialRuntimeRevision + 2)
    }

    @Test
    @MainActor
    func settingsStoreMigratesLegacyRewriteDefaults() throws {
        let suiteName = "TextKitTests.SettingsStoreMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyDocument = PromptProfileDocument(
            version: 1,
            strictModeEnabled: false,
            modeConfigurations: Dictionary(
                uniqueKeysWithValues: ToolMode.allCases.map { mode in
                    (mode.id, ModePromptConfiguration.legacyDefaultV1(for: mode))
                }
            )
        )

        let encoded = try JSONEncoder().encode(legacyDocument)
        defaults.set(encoded, forKey: "settings.promptProfile")

        let store = SettingsStore(defaults: defaults)

        #expect(
            store.editablePromptConfiguration(for: .rewriteClean)
                == .default(for: .rewriteClean)
        )
        #expect(
            store.editablePromptConfiguration(for: .rewriteShort)
                == .default(for: .rewriteShort)
        )
        #expect(
            store.editablePromptConfiguration(for: .rewriteProfessional)
                == .default(for: .rewriteProfessional)
        )
    }
}
