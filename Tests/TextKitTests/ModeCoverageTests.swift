import Testing
@testable import TextKit

struct ModeCoverageTests {
    @Test
    func everyToolStillExposesFourModes() {
        for tool in ToolKind.allCases {
            #expect(tool.modes.count == 4)
            #expect(tool.modes.allSatisfy { $0.tool == tool })
        }
    }

    @Test
    func everyModeHasUsableDefaults() {
        for mode in ToolMode.allCases {
            let configuration = ModePromptConfiguration.default(for: mode)
            #expect(!configuration.systemInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!configuration.taskTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!mode.sampleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(configuration.maxTokens >= 32)
        }
    }

    @Test
    func rewriteModesUseDistinctPromptDefaults() {
        let modes: [ToolMode] = [.rewriteClean, .rewriteShort, .rewriteProfessional]
        let configurations = modes.map(ModePromptConfiguration.default)

        #expect(Set(configurations.map(\.systemInstruction)).count == modes.count)
        #expect(Set(configurations.map(\.taskTemplate)).count == modes.count)
    }

    @Test
    func summarizeModesUseDistinctPromptDefaults() {
        let modes: [ToolMode] = [.summarizeBrief, .summarizeBalanced, .summarizeDetailed, .summarizeExecutive]
        let configurations = modes.map(ModePromptConfiguration.default)

        #expect(Set(configurations.map(\.systemInstruction)).count == modes.count)
        #expect(Set(configurations.map(\.taskTemplate)).count == modes.count)
    }
}
