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
    var version: Int = 1
    var strictModeEnabled: Bool
    var modeConfigurations: [String: ModePromptConfiguration]
}
