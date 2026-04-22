import Testing
@testable import TextKit

struct ModelManagerTests {
    @Test
    @MainActor
    func readyStateTracksWarmFlag() {
        let manager = ModelManager()

        manager.markReady(isWarm: false)
        #expect(manager.statusSummary == "On-device")

        manager.markReady(isWarm: true)
        #expect(manager.statusSummary == "On-device · warm")
    }

    @Test
    @MainActor
    func resolvesExperimentalModelDescriptor() {
        let manager = ModelManager()

        let descriptor = manager.model(for: .experimental, quantPreset: .balanced)

        #expect(descriptor.displayName.contains("Experimental"))
        #expect(descriptor.repository == "AaryanK/Qwen3.5-0.8B-GGUF")
        #expect(descriptor.suggestedFilename == "Qwen3.5-0.8B.q4_k_m.gguf")
        #expect(descriptor.requiresReasoningOff)
    }
}
