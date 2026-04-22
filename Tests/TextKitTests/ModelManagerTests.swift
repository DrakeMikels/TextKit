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
}
