import Foundation

struct GenerationRequest {
    let inputText: String
    let pinnedInstruction: String
    let refineInstruction: String
    let tool: ToolKind
    let mode: ToolMode
    let modelProfile: ModelProfile
    let quantPreset: QuantPreset
    let promptConfiguration: ModePromptConfiguration

    init(
        inputText: String,
        pinnedInstruction: String = "",
        refineInstruction: String,
        tool: ToolKind,
        mode: ToolMode,
        modelProfile: ModelProfile,
        quantPreset: QuantPreset,
        promptConfiguration: ModePromptConfiguration
    ) {
        self.inputText = inputText
        self.pinnedInstruction = pinnedInstruction
        self.refineInstruction = refineInstruction
        self.tool = tool
        self.mode = mode
        self.modelProfile = modelProfile
        self.quantPreset = quantPreset
        self.promptConfiguration = promptConfiguration
    }

    var effectiveMaxTokens: Int {
        let scaledValue = Double(promptConfiguration.maxTokens) * modelProfile.tokenBudgetMultiplier
        return max(32, min(512, Int(scaledValue.rounded())))
    }
}
