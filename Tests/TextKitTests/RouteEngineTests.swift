import Testing
@testable import TextKit

struct RouteEngineTests {
    @Test
    func routesReplySignalsToReply() {
        let engine = RouteEngine()
        let result = engine.route("Thanks for reaching out. Let me know what works for you.", fallback: .rewrite)
        #expect(result == .reply)
    }

    @Test
    func routesPromptSignalsToPrompt() {
        let engine = RouteEngine()
        let result = engine.route("Write a prompt for ChatGPT that creates a launch plan.", fallback: .rewrite)
        #expect(result == .prompt)
    }

    @Test
    func routesExtractSignalsToExtract() {
        let engine = RouteEngine()
        let result = engine.route("Let's meet Thursday at 2pm and send the draft by Friday.", fallback: .rewrite)
        #expect(result == .extract)
    }

    @Test
    func fallsBackWhenNoStrongSignalExists() {
        let engine = RouteEngine()
        let result = engine.route("Clean up this paragraph so it reads better.", fallback: .rewrite)
        #expect(result == .rewrite)
    }

    @Test
    func routesLargeStructuredInputToReduceWithoutAutoRun() {
        let engine = RouteEngine()
        let input = Array(repeating: "warning status=ready build=a91f3c7 analytics queue worker payload trace id=42;", count: 30)
            .joined(separator: " ")

        let result = engine.decide(input, fallback: .rewrite)

        #expect(result.tool == .reduce)
        #expect(result.preferredMode == .reduceStructured)
        #expect(result.shouldAutoGenerate == false)
    }
}
