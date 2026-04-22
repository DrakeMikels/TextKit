import Foundation

struct ModePromptConfiguration: Codable, Hashable {
    var systemInstruction: String
    var taskTemplate: String
    var temperature: Double
    var maxTokens: Int
    var seed: Int

    static func `default`(for mode: ToolMode) -> ModePromptConfiguration {
        ModePromptConfiguration(
            systemInstruction: mode.defaultSystemInstruction,
            taskTemplate: mode.defaultTaskTemplate,
            temperature: mode.defaultTemperature,
            maxTokens: mode.defaultMaxTokens,
            seed: mode.defaultSeed
        )
    }

    static func legacyDefaultV1(for mode: ToolMode) -> ModePromptConfiguration {
        switch mode.id {
        case ToolMode.rewriteClean.id:
            ModePromptConfiguration(
                systemInstruction: "Keep the rewrite faithful to the original meaning. Favor natural phrasing over flashy wording.",
                taskTemplate: """
                Task: Rewrite the text for clarity.
                Preserve the original meaning.
                Remove awkward phrasing.
                Return only the rewritten text.
                """,
                temperature: 0.2,
                maxTokens: 120,
                seed: -1
            )
        case ToolMode.rewriteShort.id:
            ModePromptConfiguration(
                systemInstruction: "Keep the rewrite faithful to the original meaning. Favor natural phrasing over flashy wording.",
                taskTemplate: """
                Task: Rewrite the text in fewer words.
                Preserve intent.
                Remove filler.
                Return only the shortened text.
                """,
                temperature: 0.2,
                maxTokens: 120,
                seed: -1
            )
        case ToolMode.rewriteProfessional.id:
            ModePromptConfiguration(
                systemInstruction: "Keep the rewrite faithful to the original meaning. Favor natural phrasing over flashy wording.",
                taskTemplate: """
                Task: Rewrite the text in a polished professional tone.
                Preserve the meaning.
                Avoid sounding robotic.
                Return only the rewritten text.
                """,
                temperature: 0.2,
                maxTokens: 120,
                seed: -1
            )
        case ToolMode.rewriteBullet.id:
            ModePromptConfiguration(
                systemInstruction: "Keep the rewrite faithful to the original meaning. Favor natural phrasing over flashy wording.",
                taskTemplate: """
                Task: Convert the text into concise bullet points.
                Keep only the important content.
                Return bullet points only.
                """,
                temperature: 0.2,
                maxTokens: 120,
                seed: -1
            )
        default:
            .default(for: mode)
        }
    }

    func strictAdjusted() -> ModePromptConfiguration {
        var adjusted = self
        adjusted.temperature = min(adjusted.temperature, 0.15)
        if adjusted.seed < 0 {
            adjusted.seed = 7
        }
        return adjusted
    }
}

struct PromptProfileDocument: Codable {
    static let currentVersion = 2

    var version: Int = Self.currentVersion
    var strictModeEnabled: Bool
    var modeConfigurations: [String: ModePromptConfiguration]
}
