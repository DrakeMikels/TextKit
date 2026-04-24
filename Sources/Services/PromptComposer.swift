import Foundation

struct PromptComposer {
    static let lockedBaseSystemPrompt = """
    You are TextKit, a local macOS text utility.
    You transform copied text according to the selected tool and mode.
    Do not explain your reasoning.
    Do not add commentary.
    Return only the final output.
    Keep outputs concise, paste-ready, and aligned to the selected tool.
    If the user adds a refine instruction, apply it only within the bounds of the selected tool and mode.
    """

    func compose(for request: GenerationRequest) -> ComposedPrompt {
        let pinnedInstruction = request.pinnedInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let refineInstruction = request.refineInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let systemPrompt = [
            Self.lockedBaseSystemPrompt,
            request.promptConfiguration.systemInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let parts = [
            request.promptConfiguration.taskTemplate.trimmingCharacters(in: .whitespacesAndNewlines),
            pinnedInstruction.isEmpty ? nil : "Pinned Instruction:\n\(pinnedInstruction)",
            refineInstruction.isEmpty ? nil : "Refine Instruction:\n\(refineInstruction)",
            "Input:\n\(request.inputText)"
        ]

        return ComposedPrompt(
            systemPrompt: systemPrompt,
            userPrompt: parts.compactMap { $0 }.joined(separator: "\n\n")
        )
    }

    func preview(
        for mode: ToolMode,
        configuration: ModePromptConfiguration,
        sampleInput: String,
        pinnedInstruction: String = "",
        refineInstruction: String
    ) -> ComposedPrompt {
        let request = GenerationRequest(
            inputText: sampleInput,
            pinnedInstruction: pinnedInstruction,
            refineInstruction: refineInstruction,
            tool: mode.tool,
            mode: mode,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: configuration
        )

        return compose(for: request)
    }
}
