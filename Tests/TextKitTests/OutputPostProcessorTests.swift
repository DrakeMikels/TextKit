import Testing
@testable import TextKit

struct OutputPostProcessorTests {
    private let processor = OutputPostProcessor()

    @Test
    func normalizesRewriteBulletOutputIntoBullets() {
        let request = GenerationRequest(
            inputText: ToolMode.rewriteBullet.sampleInput,
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteBullet,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteBullet)
        )

        let result = processor._finalizeForTests(
            "1. finish the onboarding copy\n2. update the launch checklist\n3. confirm the release email owner",
            for: request
        )

        #expect(result == """
        - Finish the onboarding copy
        - Update the launch checklist
        - Confirm the release email owner
        """)
    }

    @Test
    func naturalizesShortRewriteWhenModelReturnsNotes() {
        let request = GenerationRequest(
            inputText: "hey john just checking if friday still works for the launch review i can move it if needed",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteShort,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteShort)
        )

        let result = processor._finalizeForTests(
            "check friday for launch review, move if needed",
            for: request
        )

        #expect(result == "John, does Friday still work for the launch review? I can move it if needed.")
    }

    @Test
    func professionalRewriteAddsClearerToneWhenOutputStaysCasual() {
        let request = GenerationRequest(
            inputText: "hey john just checking if friday still works for the launch review i can move it if needed",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteProfessional,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteProfessional)
        )

        let result = processor._finalizeForTests(
            "Hey John, just checking if Friday still works for the launch review. I can move it if needed.",
            for: request
        )

        #expect(result == "Hi John, could you confirm whether Friday still works for the launch review? I can move it if needed.")
    }

    @Test
    func stripsPromptLabelsFromPromptModes() {
        let request = GenerationRequest(
            inputText: ToolMode.promptBalanced.sampleInput,
            refineInstruction: "",
            tool: .prompt,
            mode: .promptBalanced,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .promptBalanced)
        )

        let result = processor._finalizeForTests(
            "Prompt:\nWrite a concise launch plan with milestones and owners.",
            for: request
        )

        #expect(result == "Write a concise launch plan with milestones and owners.")
    }

    @Test
    func usesEntityFallbackWhenModelOutputIsEmptyish() {
        let request = GenerationRequest(
            inputText: ToolMode.extractEntities.sampleInput,
            refineInstruction: "",
            tool: .extract,
            mode: .extractEntities,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .extractEntities)
        )

        let result = processor._finalizeForTests("Entities:", for: request)

        #expect(result.contains("- Sarah Chen"))
        #expect(result.contains("- OpenAI"))
        #expect(result.contains("- Alex Rivera"))
        #expect(result.contains("- Hugging Face"))
        #expect(result.contains("- Denver"))
    }

    @Test
    func usesDateFallbackWhenModelOutputIsEmptyish() {
        let request = GenerationRequest(
            inputText: ToolMode.extractDates.sampleInput,
            refineInstruction: "",
            tool: .extract,
            mode: .extractDates,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .extractDates)
        )

        let result = processor._finalizeForTests("Dates:", for: request)

        #expect(result.contains("- Thursday at 2pm"))
        #expect(result.contains("- April 30"))
    }

    @Test
    func returnsExplicitNoResultForMissingActionItems() {
        let request = GenerationRequest(
            inputText: "Thank you again for the thoughtful note.",
            refineInstruction: "",
            tool: .extract,
            mode: .extractActionItems,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .extractActionItems)
        )

        let result = processor._finalizeForTests("No action items.", for: request)

        #expect(result == "No action items found.")
    }

    @Test
    func keepsReplyConciseWhenTheModelRunsLong() {
        let request = GenerationRequest(
            inputText: ToolMode.replyConcise.sampleInput,
            refineInstruction: "",
            tool: .reply,
            mode: .replyConcise,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .replyConcise)
        )

        let result = processor._finalizeForTests(
            "Reply: Absolutely, this still works for me. I can review it later today and send notes afterward.",
            for: request
        )

        #expect(!result.contains("Reply:"))
        #expect(result == "Absolutely, this still works for me.")
    }
}
