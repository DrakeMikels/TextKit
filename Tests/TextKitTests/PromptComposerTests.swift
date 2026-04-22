import Testing
@testable import TextKit

struct PromptComposerTests {
    @Test
    func includesRefineInstructionWhenPresent() {
        let composer = PromptComposer()
        let request = GenerationRequest(
            inputText: "Draft a better reply.",
            refineInstruction: "Keep it under 50 words.",
            tool: .reply,
            mode: .replyProfessional,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .replyProfessional)
        )

        let prompt = composer.compose(for: request)

        #expect(prompt.systemPrompt.contains("You are TextKit"))
        #expect(prompt.systemPrompt.contains("Draft replies that feel human"))
        #expect(prompt.userPrompt.contains("Refine Instruction:\nKeep it under 50 words."))
        #expect(prompt.userPrompt.contains("Input:\nDraft a better reply."))
    }
}
