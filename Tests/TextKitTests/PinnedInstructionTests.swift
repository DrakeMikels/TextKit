import Foundation
import Testing
@testable import TextKit

struct PinnedInstructionTests {
    @Test
    @MainActor
    func builtInInstructionsLoadByDefault() {
        let store = makeStore()

        #expect(store.pinnedInstructions.filter(\.isBuiltIn).count == 4)
        #expect(store.pinnedInstructions.contains { $0.name == "Concise Professional" })
        #expect(store.pinnedInstructions.contains { $0.name == "Friendly Clear" })
        #expect(store.pinnedInstructions.contains { $0.name == "Executive Summary" })
        #expect(store.pinnedInstructions.contains { $0.name == "Direct CTA" })
    }

    @Test
    @MainActor
    func customInstructionCanBeSaved() {
        let store = makeStore()

        let saved = store.saveCustomPinnedInstruction(
            name: "Recruiting",
            instruction: "Make it concise for candidate outreach."
        )

        #expect(saved != nil)
        #expect(store.pinnedInstructions.contains { $0.name == "Recruiting" && !$0.isBuiltIn })
        #expect(store.selectedPinnedInstruction?.name == "Recruiting")
        #expect(store.pinnedInstructionText == "Make it concise for candidate outreach.")
    }

    @Test
    @MainActor
    func customInstructionCanBeRenamed() throws {
        let store = makeStore()
        let saved = try #require(store.saveCustomPinnedInstruction(
            name: "Recruiting",
            instruction: "Make it concise for candidate outreach."
        ))

        let renamed = store.renameCustomPinnedInstruction(id: saved.id, name: "Sales")

        #expect(renamed)
        #expect(store.pinnedInstructions.contains { $0.id == saved.id && $0.name == "Sales" })
    }

    @Test
    @MainActor
    func customInstructionCanBeDeleted() throws {
        let store = makeStore()
        let saved = try #require(store.saveCustomPinnedInstruction(
            name: "Recruiting",
            instruction: "Make it concise for candidate outreach."
        ))

        let deleted = store.deleteCustomPinnedInstruction(id: saved.id)

        #expect(deleted)
        #expect(!store.pinnedInstructions.contains { $0.id == saved.id })
    }

    @Test
    @MainActor
    func builtInInstructionCannotBeDeleted() {
        let store = makeStore()

        let deleted = store.deleteCustomPinnedInstruction(id: PinnedInstruction.conciseProfessional.id)

        #expect(!deleted)
        #expect(store.pinnedInstructions.contains { $0.id == PinnedInstruction.conciseProfessional.id })
    }

    @Test
    func cacheKeyChangesWhenPinnedInstructionChanges() {
        let base = CacheKey(
            clipboardHash: 1,
            tool: .rewrite,
            modeID: ToolMode.rewriteClean.id,
            modelOption: .stable,
            modelProfile: .balanced,
            quantPreset: .balanced,
            refineInstruction: "",
            pinnedInstructionFingerprint: "builtin.concise-professional|concise",
            configurationFingerprint: "template"
        )
        let changed = CacheKey(
            clipboardHash: 1,
            tool: .rewrite,
            modeID: ToolMode.rewriteClean.id,
            modelOption: .stable,
            modelProfile: .balanced,
            quantPreset: .balanced,
            refineInstruction: "",
            pinnedInstructionFingerprint: "builtin.friendly-clear|friendly",
            configurationFingerprint: "template"
        )

        #expect(base != changed)
    }

    @Test
    @MainActor
    func clipboardPrecomputeRequestUsesPinnedInstructionWhenEnabled() {
        let store = makeStore()
        store.isPinnedInstructionEnabled = true
        store.selectPinnedInstruction(id: PinnedInstruction.directCTA.id)

        let appModel = AppModel(settingsStore: store, startsClipboardMonitoring: false)
        appModel.selectedTool = .rewrite
        appModel.selectedMode = .rewriteClean

        let request = appModel._requestForPrecomputeTests(inputText: "Can we meet tomorrow?")

        #expect(request.pinnedInstruction == PinnedInstruction.directCTA.instruction)
        #expect(request.inputText == "Can we meet tomorrow?")
    }

    @MainActor
    private func makeStore() -> SettingsStore {
        let suiteName = "TextKitTests.PinnedInstruction.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SettingsStore(defaults: defaults)
    }
}
