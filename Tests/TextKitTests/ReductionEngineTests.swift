import Testing
@testable import TextKit

struct ReductionEngineTests {
    private let engine = ReductionEngine()

    @Test
    func estimateTokensMatchesConduitConvention() {
        #expect(engine.estimateTokens("") == 1)
        #expect(engine.estimateTokens("abcd") == 1)
        #expect(engine.estimateTokens("abcde") == 2)
    }

    @Test
    func safeModeOnlyNormalizesWhitespace() {
        let input = "alpha   beta\r\n\r\ngamma\rdelta"

        let result = engine.reduce(input, mode: .reduceSafe)

        #expect(result.text == "alpha beta\n\ngamma\ndelta")
        #expect(result.stats.originalEstimatedTokenCount >= result.stats.reducedEstimatedTokenCount)
    }

    @Test
    func logsModeCollapsesRepeatedTimestamps() {
        let input = """
        2026-04-17T05:31:10.534Z INFO request=42 status=ok 2026-04-17T05:31:10.534Z
        2026-04-17T05:31:10.534Z INFO request=43 status=ok 2026-04-17T05:31:10.534Z
        """

        let result = engine.reduce(input, mode: .reduceLogs)

        #expect(result.text.contains("[t=0]"))
        #expect(result.stats.reductionPercent > 0)
    }

    @Test
    func structuredModeAddsDictionaryHeaderWhenItHelps() {
        let input = """
        The algorithm validates input before processing and the algorithm returns the processed response at 2026-04-17T05:31:10.534Z. The algorithm should stay deterministic at 2026-04-17T05:31:10.534Z.
        """

        let result = engine.reduce(input, mode: .reduceStructured)

        #expect(result.text.hasPrefix("["))
        #expect(result.text.contains("=algorithm"))
        #expect(result.text.contains("[t=0]"))
    }

    @Test
    func restoreRecoversTimestampAndDictionaryPasses() {
        let input = "The algorithm validates input before processing at 2026-04-17T05:31:10.534Z and the algorithm returns the processed response at 2026-04-17T05:31:10.534Z."

        let result = engine.reduce(input, mode: .reduceStructured)
        let restored = engine.restore(result.text)

        #expect(restored == engine.normalizeWhitespace(input))
    }
}
