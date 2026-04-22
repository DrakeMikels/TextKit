import Foundation

struct PromptComposer {
    private let systemPrompt = """
    You are TextKit, a local macOS text utility.
    You transform copied text according to the selected tool and mode.
    Do not explain your reasoning.
    Do not add commentary.
    Return only the final output.
    Keep outputs concise, paste-ready, and aligned to the selected tool.
    If the user adds a refine instruction, apply it only within the bounds of the selected tool and mode.
    """

    func compose(for request: GenerationRequest) -> String {
        let parts = [
            "System:\n\(systemPrompt)",
            "Mode Prompt:\n\(modePrompt(for: request.mode))",
            request.refineInstruction.isEmpty ? nil : "Refine Instruction:\n\(request.refineInstruction)",
            "Input:\n\(request.inputText)"
        ]

        return parts.compactMap { $0 }.joined(separator: "\n\n")
    }

    private func modePrompt(for mode: ToolMode) -> String {
        switch mode.id {
        case ToolMode.rewriteClean.id:
            """
            Task: Rewrite the text for clarity.
            Preserve the original meaning.
            Remove awkward phrasing.
            Return only the rewritten text.
            """
        case ToolMode.rewriteShort.id:
            """
            Task: Rewrite the text in fewer words.
            Preserve intent.
            Remove filler.
            Return only the shortened text.
            """
        case ToolMode.rewriteProfessional.id:
            """
            Task: Rewrite the text in a polished professional tone.
            Preserve the meaning.
            Avoid sounding robotic.
            Return only the rewritten text.
            """
        case ToolMode.rewriteBullet.id:
            """
            Task: Convert the text into concise bullet points.
            Keep only the important content.
            Return bullet points only.
            """
        case ToolMode.promptBalanced.id:
            """
            Task: Turn the text into a strong AI prompt.
            Clarify the goal.
            Make the request explicit.
            Add useful output guidance.
            Return only the final prompt.
            """
        case ToolMode.promptDetailed.id:
            """
            Task: Turn the text into a detailed AI prompt.
            Clarify the goal, desired output, important constraints, and relevant context.
            Return only the final prompt.
            """
        case ToolMode.promptConstrained.id:
            """
            Task: Turn the text into an AI prompt with explicit constraints.
            State the task clearly.
            Include brevity and output format guidance.
            Return only the final prompt.
            """
        case ToolMode.promptCreative.id:
            """
            Task: Turn the text into a sharper, more creative AI prompt.
            Keep the request clear but allow more style and voice.
            Return only the final prompt.
            """
        case ToolMode.extractActionItems.id:
            """
            Task: Extract action items from the text.
            Return concise bullet points.
            If no action items are present, return: No action items found.
            """
        case ToolMode.extractKeyPoints.id:
            """
            Task: Extract the key points from the text.
            Return concise bullet points.
            Do not include commentary.
            """
        case ToolMode.extractEntities.id:
            """
            Task: Extract important entities from the text.
            Include people, organizations, roles, products, or places when present.
            Return concise bullet points.
            If none are found, return: No notable entities found.
            """
        case ToolMode.extractDates.id:
            """
            Task: Extract dates, times, and deadlines from the text.
            Return concise bullet points.
            If none are found, return: No dates or times found.
            """
        case ToolMode.replyCasual.id:
            """
            Task: Draft a casual reply to the text.
            Keep it natural and concise.
            Return only the reply.
            """
        case ToolMode.replyProfessional.id:
            """
            Task: Draft a professional reply to the text.
            Keep it polite, clear, and concise.
            Return only the reply.
            """
        case ToolMode.replyConcise.id:
            """
            Task: Draft a very concise reply to the text.
            Use as few words as possible while preserving usefulness.
            Return only the reply.
            """
        case ToolMode.replyWarm.id:
            """
            Task: Draft a warm and thoughtful reply to the text.
            Keep it natural and not overly long.
            Return only the reply.
            """
        default:
            """
            Task: Return a concise transformed version of the text.
            """
        }
    }
}
