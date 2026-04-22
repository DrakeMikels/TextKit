import Testing
@testable import TextKit

struct InferenceEngineTests {
    @Test
    func extractsAssistantResponseFromCompletionOutput() {
        let engine = InferenceEngine()
        let stdout = """
        user
        Tell me the word OK only.
        assistant
        Okay

        > EOF by user
        """

        let reply = engine._extractAssistantResponseForTests(from: stdout)

        #expect(reply == "Okay")
    }
}
