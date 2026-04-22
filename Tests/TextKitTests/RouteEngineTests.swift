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
}
