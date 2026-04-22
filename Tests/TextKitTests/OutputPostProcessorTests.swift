import Testing
@testable import TextKit

struct OutputPostProcessorTests {
    private let processor = OutputPostProcessor()
    private let ablatedProcessor = OutputPostProcessor(rewriteHeuristicsEnabled: false)

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
    func stripsThinkTagsFromRewriteOutput() {
        let request = GenerationRequest(
            inputText: ToolMode.rewriteClean.sampleInput,
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteClean,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteClean)
        )

        let result = processor._finalizeForTests(
            "<think>\nreasoning\n</think>\nHey John, just checking if Friday still works for the launch review. I can move it if needed.",
            for: request
        )

        #expect(!result.contains("<think>"))
        #expect(result == "Hey John, just checking if Friday still works for the launch review. I can move it if needed.")
    }

    @Test
    func fallsBackToSourceBulletsWhenModelReturnsMetaAnalysis() {
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
            """
            - Analyze the Request:
            - Task:** Convert the input text into concise bullet points
            - Constraint 1:** Keep only the important content
            - Input Text:** Need to finish the onboarding copy
            """,
            for: request
        )

        #expect(result == """
        - Need to finish the onboarding copy
        - Update the launch checklist
        - Confirm who owns the release email draft
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
    func shortRewriteCompressesSoftLeadInsWhenModelBarelyChangesInput() {
        let request = GenerationRequest(
            inputText: "just wanted to check whether the launch email still needs legal review or if i should send the final version now",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteShort,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteShort)
        )

        let result = processor._finalizeForTests(
            "Just wanted to check whether the launch email still needs legal review or if I should send the final version now.",
            for: request
        )

        #expect(result == "Does the launch email still need legal review, or should I send the final version now?")
    }

    @Test
    func shortRewriteTurnsFollowUpStatusChecksIntoDirectQuestion() {
        let request = GenerationRequest(
            inputText: "following up on whether we're still aligned on the plan. if not, i can trim the deck and send another pass.",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteShort,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteShort)
        )

        let result = processor._finalizeForTests(
            "Following up on whether we're still aligned on the plan. if not,. I can trim the deck and send another pass.",
            for: request
        )

        #expect(result == "Are we still aligned on the plan? If not, I can trim the deck and send another pass.")
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
    func professionalRewriteKeepsRequestDirectionWhenModelTurnsItIntoNeedStatement() {
        let request = GenerationRequest(
            inputText: "can you send me the numbers by tomorrow morning so i can get this into the board update",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteProfessional,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteProfessional)
        )

        let result = processor._finalizeForTests(
            "I need the numbers by tomorrow morning so I can update the board.",
            for: request
        )

        #expect(result == "Could you send me the numbers by tomorrow morning so I can include them in the board update?")
    }

    @Test
    func professionalRewriteFixesCasualConfirmationLeadIn() {
        let request = GenerationRequest(
            inputText: "hey sam checking whether you can confirm the revised invoice today so we can close this out",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteProfessional,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteProfessional)
        )

        let result = processor._finalizeForTests(
            "Hey, Sam, confirming the revised invoice today so we can close this out.",
            for: request
        )

        #expect(result == "Hi Sam, could you confirm the revised invoice today so we can close this out?")
    }

    @Test
    func professionalRewriteStripsMetaWrapperLeadIn() {
        let request = GenerationRequest(
            inputText: "sure — here’s a different long-form sample, written more like a messy terminal/debug session with mixed logs, stack traces, retries, and noisy output for compression testing:",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteProfessional,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteProfessional)
        )

        let result = processor._finalizeForTests(
            #"Here is the polished version of your message: "Sure, here's a different long-form sample, written more like a messy terminal/debug session with mixed logs, stack traces, retries, and noisy output for compression testing.""#,
            for: request
        )

        #expect(result == "Sure, here's a different long-form sample, written more like a messy terminal/debug session with mixed logs, stack traces, retries, and noisy output for compression testing.")
    }

    @Test
    func ablatedRewriteProcessorLeavesModelOutputMostlyUntouched() {
        let request = GenerationRequest(
            inputText: "can you send me the numbers by tomorrow morning so i can get this into the board update",
            refineInstruction: "",
            tool: .rewrite,
            mode: .rewriteProfessional,
            modelProfile: .balanced,
            quantPreset: .balanced,
            promptConfiguration: .default(for: .rewriteProfessional)
        )

        let result = ablatedProcessor._finalizeForTests(
            "I need the numbers by tomorrow morning so I can update the board.",
            for: request
        )

        #expect(result == "I need the numbers by tomorrow morning so I can update the board.")
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
