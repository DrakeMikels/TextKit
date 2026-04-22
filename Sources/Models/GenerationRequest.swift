import Foundation

struct GenerationRequest {
    let inputText: String
    let refineInstruction: String
    let tool: ToolKind
    let mode: ToolMode
    let modelProfile: ModelProfile
    let quantPreset: QuantPreset
}
