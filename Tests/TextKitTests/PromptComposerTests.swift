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

    @Test
    func includesPinnedInstructionWhenEnabled() {
        let composer = PromptComposer()
        let request = GenerationRequest(
            inputText: "Please review the launch notes.",
            pinnedInstruction: "Make it concise and executive-ready.",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteProfessional,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteProfessional)
        )

        let prompt = composer.compose(for: request)

        #expect(prompt.userPrompt.contains("Pinned Instruction:\nMake it concise and executive-ready."))
        #expect(!prompt.userPrompt.contains("Refine Instruction:"))
    }

    @Test
    func excludesPinnedInstructionWhenDisabled() {
        let composer = PromptComposer()
        let request = GenerationRequest(
            inputText: "Please review the launch notes.",
            pinnedInstruction: "",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteProfessional,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteProfessional)
        )

        let prompt = composer.compose(for: request)

        #expect(!prompt.userPrompt.contains("Pinned Instruction:"))
    }

    @Test
    func includesPinnedAndRefineInstructionsWhenBothArePresent() {
        let composer = PromptComposer()
        let request = GenerationRequest(
            inputText: "Please review the launch notes.",
            pinnedInstruction: "Make it concise and executive-ready.",
            refineInstruction: "Make it slightly warmer.",
            tool: .rewrite,
            mode: .rewriteProfessional,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteProfessional)
        )

        let prompt = composer.compose(for: request)

        #expect(prompt.userPrompt.contains("Pinned Instruction:\nMake it concise and executive-ready."))
        #expect(prompt.userPrompt.contains("Refine Instruction:\nMake it slightly warmer."))
        #expect(
            prompt.userPrompt.range(of: "Pinned Instruction:")!.lowerBound
                < prompt.userPrompt.range(of: "Refine Instruction:")!.lowerBound
        )
    }
}
