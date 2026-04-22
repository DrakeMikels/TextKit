import Foundation

struct GenerationRequest {
    let inputText: String
    let refineInstruction: String
    let tool: ToolKind
    let mode: ToolMode
    let modelProfile: ModelProfile
    let quantPreset: QuantPreset
    let promptConfiguration: ModePromptConfiguration

    var effectiveMaxTokens: Int {
        let scaledValue = Double(promptConfiguration.maxTokens) * modelProfile.tokenBudgetMultiplier
        return max(32, min(512, Int(scaledValue.rounded())))
    }
}
