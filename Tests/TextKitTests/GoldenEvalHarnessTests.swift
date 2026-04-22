import Foundation
import Testing
@testable import TextKit

private struct GoldenEvalCase: Decodable {
    let id: String
    let modeID: String
    let inputText: String
    let refineInstruction: String?
    let referenceOutput: String
    let requiredPhrases: [String]
    let requiredAnyOfPhrases: [String]
    let forbiddenPhrases: [String]
    let expectsBullets: Bool?
    let minBulletCount: Int?
    let minWords: Int?
    let maxWords: Int?
    let minWordReduction: Double?
    let minReferenceSimilarity: Double?
    let minimumScore: Double?

    private enum CodingKeys: String, CodingKey {
        case id
        case modeID
        case inputText
        case refineInstruction
        case referenceOutput
        case requiredPhrases
        case requiredAnyOfPhrases
        case forbiddenPhrases
        case expectsBullets
        case minBulletCount
        case minWords
        case maxWords
        case minWordReduction
        case minReferenceSimilarity
        case minimumScore
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        modeID = try container.decode(String.self, forKey: .modeID)
        inputText = try container.decode(String.self, forKey: .inputText)
        refineInstruction = try container.decodeIfPresent(String.self, forKey: .refineInstruction)
        referenceOutput = try container.decode(String.self, forKey: .referenceOutput)
        requiredPhrases = try container.decodeIfPresent([String].self, forKey: .requiredPhrases) ?? []
        requiredAnyOfPhrases = try container.decodeIfPresent([String].self, forKey: .requiredAnyOfPhrases) ?? []
        forbiddenPhrases = try container.decodeIfPresent([String].self, forKey: .forbiddenPhrases) ?? []
        expectsBullets = try container.decodeIfPresent(Bool.self, forKey: .expectsBullets)
        minBulletCount = try container.decodeIfPresent(Int.self, forKey: .minBulletCount)
        minWords = try container.decodeIfPresent(Int.self, forKey: .minWords)
        maxWords = try container.decodeIfPresent(Int.self, forKey: .maxWords)
        minWordReduction = try container.decodeIfPresent(Double.self, forKey: .minWordReduction)
        minReferenceSimilarity = try container.decodeIfPresent(Double.self, forKey: .minReferenceSimilarity)
        minimumScore = try container.decodeIfPresent(Double.self, forKey: .minimumScore)
    }

    var mode: ToolMode {
        ToolMode.mode(for: modeID) ?? .rewriteClean
    }

    var minimumPassingScore: Double {
        minimumScore ?? 0.75
    }
}

private struct GoldenEvalScore {
    let value: Double
    let details: [String]
}

private struct GoldenEvalResult {
    let testCase: GoldenEvalCase
    let output: String
    let score: Double
    let passed: Bool
    let details: [String]

    static func failure(testCase: GoldenEvalCase, message: String) -> GoldenEvalResult {
        GoldenEvalResult(
            testCase: testCase,
            output: "",
            score: 0,
            passed: false,
            details: [message]
        )
    }
}

private struct GoldenEvalConfiguration {
    let quantPreset: QuantPreset
    let modelProfile: ModelProfile
    let minimumPassRate: Double
    let caseFilter: String?
    let modeFilter: String?
    let useStrictProfile: Bool

    static func fromEnvironment() -> GoldenEvalConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let quantPreset = QuantPreset(rawValue: environment["TEXTKIT_EVAL_QUANT"] ?? "") ?? .balanced
        let modelProfile = ModelProfile(rawValue: environment["TEXTKIT_EVAL_MODEL_PROFILE"] ?? "") ?? .balanced
        let minimumPassRate = Double(environment["TEXTKIT_EVAL_MIN_PASS_RATE"] ?? "") ?? 1
        let caseFilter = environment["TEXTKIT_EVAL_CASE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let modeFilter = environment["TEXTKIT_EVAL_MODE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let useStrictProfile = environment["TEXTKIT_EVAL_USE_STRICT_PROFILE"] != "0"

        return GoldenEvalConfiguration(
            quantPreset: quantPreset,
            modelProfile: modelProfile,
            minimumPassRate: minimumPassRate,
            caseFilter: caseFilter?.isEmpty == true ? nil : caseFilter,
            modeFilter: modeFilter?.isEmpty == true ? nil : modeFilter,
            useStrictProfile: useStrictProfile
        )
    }
}

private struct GoldenEvalLoader {
    func loadCases() throws -> [GoldenEvalCase] {
        let url = try #require(Bundle.module.url(forResource: "golden_eval_cases", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([GoldenEvalCase].self, from: data)
    }
}

private struct GoldenEvalScorer {
    func score(output: String, for testCase: GoldenEvalCase) -> GoldenEvalScore {
        let normalizedOutput = normalize(output)
        let outputWords = wordCount(in: output)
        let inputWords = wordCount(in: testCase.inputText)
        let similarity = tokenSimilarity(between: output, and: testCase.referenceOutput)
        let bulletCount = bulletLineCount(in: output)

        var totalWeight = 0.0
        var earnedWeight = 0.0
        var details: [String] = []

        if !testCase.requiredPhrases.isEmpty {
            totalWeight += 2
            let matchedCount = testCase.requiredPhrases.filter { normalizedOutput.contains(normalize($0)) }.count
            let coverage = Double(matchedCount) / Double(testCase.requiredPhrases.count)
            earnedWeight += 2 * coverage
            if matchedCount != testCase.requiredPhrases.count {
                let missing = testCase.requiredPhrases.filter { !normalizedOutput.contains(normalize($0)) }
                details.append("missing required phrases: \(missing.joined(separator: ", "))")
            }
        }

        if !testCase.requiredAnyOfPhrases.isEmpty {
            totalWeight += 1
            let matched = testCase.requiredAnyOfPhrases.contains { normalizedOutput.contains(normalize($0)) }
            if matched {
                earnedWeight += 1
            } else {
                details.append("missing one-of phrases: \(testCase.requiredAnyOfPhrases.joined(separator: ", "))")
            }
        }

        if !testCase.forbiddenPhrases.isEmpty {
            totalWeight += 1
            let matches = testCase.forbiddenPhrases.filter { normalizedOutput.contains(normalize($0)) }
            let safeRatio = 1 - (Double(matches.count) / Double(testCase.forbiddenPhrases.count))
            earnedWeight += max(0, safeRatio)
            if !matches.isEmpty {
                details.append("contains forbidden phrases: \(matches.joined(separator: ", "))")
            }
        }

        if let expectsBullets = testCase.expectsBullets {
            totalWeight += 2
            let outputHasBullets = bulletCount > 0
            if outputHasBullets == expectsBullets {
                earnedWeight += 2
            } else {
                details.append(expectsBullets ? "expected bullet output" : "expected paragraph output")
            }
        }

        if let minBulletCount = testCase.minBulletCount {
            totalWeight += 1
            let coverage = min(1, Double(bulletCount) / Double(minBulletCount))
            earnedWeight += coverage
            if bulletCount < minBulletCount {
                details.append("bullet count \(bulletCount) < \(minBulletCount)")
            }
        }

        if let minWords = testCase.minWords {
            totalWeight += 1
            let coverage = min(1, Double(outputWords) / Double(minWords))
            earnedWeight += coverage
            if outputWords < minWords {
                details.append("word count \(outputWords) < \(minWords)")
            }
        }

        if let maxWords = testCase.maxWords {
            totalWeight += 1
            if outputWords <= maxWords {
                earnedWeight += 1
            } else {
                details.append("word count \(outputWords) > \(maxWords)")
            }
        }

        if let minWordReduction = testCase.minWordReduction {
            totalWeight += 2
            let actualReduction = inputWords == 0 ? 0 : max(0, Double(inputWords - outputWords) / Double(inputWords))
            let coverage = min(1, actualReduction / minWordReduction)
            earnedWeight += 2 * coverage
            if actualReduction < minWordReduction {
                details.append(
                    String(
                        format: "word reduction %.2f < %.2f",
                        actualReduction,
                        minWordReduction
                    )
                )
            }
        }

        if let minReferenceSimilarity = testCase.minReferenceSimilarity {
            totalWeight += 3
            let coverage = min(1, similarity / minReferenceSimilarity)
            earnedWeight += 3 * coverage
            if similarity < minReferenceSimilarity {
                details.append(
                    String(
                        format: "reference similarity %.2f < %.2f",
                        similarity,
                        minReferenceSimilarity
                    )
                )
            }
        }

        let finalScore = totalWeight == 0 ? 0 : earnedWeight / totalWeight
        let summary = [
            String(format: "score=%.2f", finalScore),
            String(format: "similarity=%.2f", similarity),
            "words=\(outputWords)"
        ]

        return GoldenEvalScore(value: finalScore, details: summary + details)
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func wordCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private func bulletLineCount(in text: String) -> Int {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ")
            }
            .count
    }

    private func tokenSimilarity(between lhs: String, and rhs: String) -> Double {
        let lhsTokens = tokenCounts(for: lhs)
        let rhsTokens = tokenCounts(for: rhs)
        let lhsCount = lhsTokens.values.reduce(0, +)
        let rhsCount = rhsTokens.values.reduce(0, +)

        guard lhsCount > 0, rhsCount > 0 else { return 0 }

        let overlap = lhsTokens.reduce(into: 0) { partialResult, entry in
            partialResult += min(entry.value, rhsTokens[entry.key] ?? 0)
        }

        return (2 * Double(overlap)) / Double(lhsCount + rhsCount)
    }

    private func tokenCounts(for text: String) -> [String: Int] {
        let normalized = text.lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
        let tokens = normalized.split(whereSeparator: \.isWhitespace)
        return tokens.reduce(into: [:]) { partialResult, token in
            partialResult[String(token), default: 0] += 1
        }
    }
}

private struct GoldenEvalRunner {
    private let configuration: GoldenEvalConfiguration

    init(configuration: GoldenEvalConfiguration) {
        self.configuration = configuration
    }

    @MainActor
    func run(cases testCases: [GoldenEvalCase]) async -> [GoldenEvalResult] {
        let modelManager = ModelManager()
        let promptComposer = PromptComposer()
        let inferenceEngine = InferenceEngine()
        let postProcessor = OutputPostProcessor()
        let scorer = GoldenEvalScorer()
        let model = modelManager.model(for: configuration.quantPreset)

        var results: [GoldenEvalResult] = []

        for testCase in testCases {
            let mode = testCase.mode
            var promptConfiguration = ModePromptConfiguration.default(for: mode)
            if configuration.useStrictProfile {
                promptConfiguration = promptConfiguration.strictAdjusted()
            }

            let request = GenerationRequest(
                inputText: testCase.inputText,
                refineInstruction: testCase.refineInstruction ?? "",
                tool: mode.tool,
                mode: mode,
                modelProfile: configuration.modelProfile,
                quantPreset: configuration.quantPreset,
                promptConfiguration: promptConfiguration
            )

            let prompt = promptComposer.compose(for: request)

            do {
                let rawOutput = try await inferenceEngine.generate(
                    for: request,
                    prompt: prompt,
                    executableURL: modelManager.runtimeExecutableURL,
                    serverExecutableURL: nil,
                    model: model,
                    setupCommand: modelManager.setupCommand(for: configuration.quantPreset),
                    warmCacheSeconds: 0,
                    modelManager: modelManager
                )

                let finalizedOutput = postProcessor.finalize(rawOutput.text, for: request)
                let score = scorer.score(output: finalizedOutput, for: testCase)

                results.append(
                    GoldenEvalResult(
                        testCase: testCase,
                        output: finalizedOutput,
                        score: score.value,
                        passed: score.value >= testCase.minimumPassingScore,
                        details: score.details
                    )
                )
            } catch {
                results.append(
                    .failure(
                        testCase: testCase,
                        message: error.localizedDescription
                    )
                )
            }
        }

        return results
    }
}

private extension Array where Element == GoldenEvalCase {
    func filtered(using configuration: GoldenEvalConfiguration) -> [GoldenEvalCase] {
        filter { testCase in
            let caseMatches = configuration.caseFilter.map { testCase.id.localizedCaseInsensitiveContains($0) } ?? true
            let modeMatches = configuration.modeFilter.map {
                testCase.modeID.localizedCaseInsensitiveContains($0)
                    || testCase.mode.title.localizedCaseInsensitiveContains($0)
                    || testCase.mode.tool.rawValue.localizedCaseInsensitiveContains($0)
            } ?? true

            return caseMatches && modeMatches
        }
    }
}

private extension Array where Element == GoldenEvalResult {
    var passRate: Double {
        guard !isEmpty else { return 0 }
        return Double(filter(\.passed).count) / Double(count)
    }

    func summaryLines(configuration: GoldenEvalConfiguration) -> [String] {
        var lines = [
            "TextKit Golden Eval",
            "modelProfile=\(configuration.modelProfile.rawValue) quant=\(configuration.quantPreset.rawValue) strict=\(configuration.useStrictProfile ? "1" : "0") cases=\(count) passRate=\(String(format: "%.2f", passRate)) threshold=\(String(format: "%.2f", configuration.minimumPassRate))"
        ]

        for result in self {
            lines.append(
                "\(result.passed ? "PASS" : "FAIL") \(String(format: "%.2f", result.score)) \(result.testCase.id)"
            )
            lines.append("output: \(result.output)")
            if !result.details.isEmpty {
                lines.append("details: \(result.details.joined(separator: " | "))")
            }
        }

        return lines
    }
}

struct GoldenEvalHarnessTests {
    @Test
    func scorerPassesReferenceOutput() throws {
        let loader = GoldenEvalLoader()
        let scorer = GoldenEvalScorer()
        let testCase = try #require(loader.loadCases().first)

        let score = scorer.score(output: testCase.referenceOutput, for: testCase)

        #expect(score.value >= testCase.minimumPassingScore)
    }

    @Test
    func scorerPenalizesMissingRequiredPhrase() throws {
        let loader = GoldenEvalLoader()
        let scorer = GoldenEvalScorer()
        let testCase = try #require(loader.loadCases().first)

        let score = scorer.score(output: "This leaves out the key details.", for: testCase)

        #expect(score.value < testCase.minimumPassingScore)
    }

    @Test
    @MainActor
    func runsGoldenEvalHarness() async throws {
        guard ProcessInfo.processInfo.environment["TEXTKIT_RUN_GOLDEN_EVAL"] == "1" else {
            return
        }

        let configuration = GoldenEvalConfiguration.fromEnvironment()
        let loader = GoldenEvalLoader()
        let selectedCases = try loader.loadCases().filtered(using: configuration)

        #expect(!selectedCases.isEmpty)

        let runner = GoldenEvalRunner(configuration: configuration)
        let results = await runner.run(cases: selectedCases)

        print(results.summaryLines(configuration: configuration).joined(separator: "\n"))

        #expect(results.passRate >= configuration.minimumPassRate)
    }
}
