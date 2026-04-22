import Foundation

struct ReductionEngine {
    private enum Profile {
        case safe
        case longText
        case logs
        case structured
    }

    private static let sentenceBoundaryRegex = try! NSRegularExpression(
        pattern: #"(?<=[.!?])\s+(?=[A-Z])"#
    )
    private static let timestampRegex = try! NSRegularExpression(
        pattern: #"\b(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)\b"#
    )
    private static let timestampReferenceRegex = try! NSRegularExpression(
        pattern: #"\[t=(\d+)\]"#
    )
    private static let wordRegex = try! NSRegularExpression(
        pattern: #"[A-Za-z]{7,}"#
    )
    private static let substitutionSymbols = [
        "!", "@", "#", "$", "%", "^", "&", "*", "~", "`", "|", "<", ">", "?",
        "\u{03B1}", "\u{03B2}", "\u{03B3}", "\u{03B4}", "\u{03B5}", "\u{03B6}",
        "\u{03B7}", "\u{03B8}", "\u{03B9}", "\u{03BA}", "\u{03BB}", "\u{03BC}",
        "\u{03BD}", "\u{03BE}", "\u{03C0}", "\u{03C1}", "\u{03C3}", "\u{03C4}",
        "\u{03C5}", "\u{03C6}", "\u{03C7}", "\u{03C8}", "\u{03C9}"
    ]

    func reduce(_ text: String, mode: ToolMode) -> ReductionResult {
        let reducedText = reduce(text, using: profile(for: mode))
        return ReductionResult(
            text: reducedText,
            stats: ReductionStats(
                originalCharacterCount: text.count,
                reducedCharacterCount: reducedText.count,
                originalEstimatedTokenCount: estimateTokens(text),
                reducedEstimatedTokenCount: estimateTokens(reducedText)
            )
        )
    }

    func restore(_ compressed: String) -> String {
        let withDictionaryRestored = dictDesubstitute(compressed)
        return decompressTimestamps(withDictionaryRestored)
    }

    func estimateTokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 1 }
        return max(1, Int(ceil(Double(text.count) / 4)))
    }

    func normalizeWhitespace(_ text: String) -> String {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        normalized = replacingMatches(
            in: normalized,
            pattern: #"[^\S\n]+"#,
            with: " "
        )
        normalized = replacingMatches(
            in: normalized,
            pattern: #"\n{3,}"#,
            with: "\n\n"
        )
        normalized = replacingMatches(
            in: normalized,
            pattern: #"[ \t]+\n"#,
            with: "\n"
        )
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func dedup(_ text: String) -> String {
        let paragraphs = text.components(separatedBy: "\n")
        var seenSentences = Set<String>()
        var resultParagraphs: [String] = []
        var previousTrimmed: String?

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.count < 20 {
                if !isStructuralOnly(trimmed),
                   let previousTrimmed,
                   previousTrimmed == trimmed
                {
                    continue
                }

                resultParagraphs.append(paragraph)
                previousTrimmed = trimmed
                continue
            }

            let sentences = splitSentences(in: trimmed)
            var kept: [String] = []

            for sentence in sentences {
                let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedSentence.count < 15 || !seenSentences.contains(trimmedSentence) {
                    kept.append(trimmedSentence)
                    if trimmedSentence.count >= 15 {
                        seenSentences.insert(trimmedSentence)
                    }
                }
            }

            if !kept.isEmpty {
                let joined = kept.joined(separator: " ")
                resultParagraphs.append(joined)
                previousTrimmed = joined.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return resultParagraphs.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

    func compressTimestamps(_ text: String) -> String {
        let matches = Self.timestampRegex.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
        guard matches.count >= 2 else { return text }

        var seen: [String: Int] = [:]
        var output = ""
        var currentIndex = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            output += text[currentIndex..<range.lowerBound]
            let timestamp = String(text[range])
            if let index = seen[timestamp] {
                output += "[t=\(index)]"
            } else {
                seen[timestamp] = seen.count
                output += timestamp
            }
            currentIndex = range.upperBound
        }

        output += text[currentIndex...]
        return output
    }

    func decompressTimestamps(_ text: String) -> String {
        var orderedTimestamps: [String] = []
        var seen = Set<String>()

        for match in Self.timestampRegex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let timestamp = String(text[range])
            if seen.insert(timestamp).inserted {
                orderedTimestamps.append(timestamp)
            }
        }

        var output = ""
        var currentIndex = text.startIndex

        for match in Self.timestampReferenceRegex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text),
                  let indexRange = Range(match.range(at: 1), in: text),
                  let index = Int(text[indexRange]),
                  index < orderedTimestamps.count
            else {
                continue
            }

            output += text[currentIndex..<range.lowerBound]
            output += orderedTimestamps[index]
            currentIndex = range.upperBound
        }

        output += text[currentIndex...]
        return output
    }

    func dictSubstitute(_ text: String) -> String {
        var frequencies: [String: Int] = [:]
        var firstSeenIndex: [String: Int] = [:]
        var nextSeenIndex = 0

        for match in Self.wordRegex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let word = String(text[range])
            frequencies[word, default: 0] += 1
            if firstSeenIndex[word] == nil {
                firstSeenIndex[word] = nextSeenIndex
                nextSeenIndex += 1
            }
        }

        guard !frequencies.isEmpty else { return text }

        let ranked = frequencies.keys.sorted { lhs, rhs in
            let lhsScore = (frequencies[lhs] ?? 0) * max(0, lhs.count - 1)
            let rhsScore = (frequencies[rhs] ?? 0) * max(0, rhs.count - 1)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return (firstSeenIndex[lhs] ?? 0) < (firstSeenIndex[rhs] ?? 0)
        }

        var substitutions: [(word: String, symbol: String)] = []
        var symbolIndex = 0

        for word in ranked {
            guard symbolIndex < Self.substitutionSymbols.count else { break }
            let occurrences = frequencies[word] ?? 0
            let savingPerUse = word.count - 1
            let keyCost = word.count + 3
            let netSaving = savingPerUse * occurrences - keyCost

            if netSaving > 0 {
                substitutions.append((word: word, symbol: Self.substitutionSymbols[symbolIndex]))
                symbolIndex += 1
            }
        }

        guard !substitutions.isEmpty else { return text }

        var result = text
        for substitution in substitutions.sorted(by: { $0.word.count > $1.word.count }) {
            let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: substitution.word))\b"#
            result = replacingMatches(in: result, pattern: pattern, with: substitution.symbol)
        }

        let keyTable = substitutions.map { "\($0.symbol)=\($0.word)" }.joined(separator: " ")
        return "[\(keyTable)]\(result)"
    }

    func dictDesubstitute(_ text: String) -> String {
        guard text.hasPrefix("["),
              let endIndex = text.firstIndex(of: "]")
        else {
            return text
        }

        let header = String(text[text.index(after: text.startIndex)..<endIndex])
        let body = String(text[text.index(after: endIndex)...])
        let pairs = header.split(separator: " ")

        guard !pairs.isEmpty else { return text }

        var substitutions: [(symbol: String, word: String)] = []
        for pair in pairs {
            let pieces = pair.split(separator: "=", maxSplits: 1)
            guard pieces.count == 2, !pieces[0].isEmpty, !pieces[1].isEmpty else {
                return text
            }
            substitutions.append((symbol: String(pieces[0]), word: String(pieces[1])))
        }

        var result = body
        for substitution in substitutions {
            result = result.replacingOccurrences(of: substitution.symbol, with: substitution.word)
        }
        return result
    }

    private func reduce(_ text: String, using profile: Profile) -> String {
        var reducedText = normalizeWhitespace(text)

        switch profile {
        case .safe:
            break
        case .longText:
            reducedText = dedup(reducedText)
        case .logs:
            reducedText = dedup(reducedText)
            reducedText = compressTimestamps(reducedText)
        case .structured:
            reducedText = dedup(reducedText)
            reducedText = compressTimestamps(reducedText)
            reducedText = dictSubstitute(reducedText)
        }

        return reducedText
    }

    private func profile(for mode: ToolMode) -> Profile {
        switch mode.id {
        case ToolMode.reduceLongText.id:
            .longText
        case ToolMode.reduceLogs.id:
            .logs
        case ToolMode.reduceStructured.id:
            .structured
        default:
            .safe
        }
    }

    private func splitSentences(in text: String) -> [String] {
        let matches = Self.sentenceBoundaryRegex.matches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
        guard !matches.isEmpty else { return [text] }

        var sentences: [String] = []
        var currentIndex = text.startIndex

        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            sentences.append(String(text[currentIndex..<range.lowerBound]))
            currentIndex = range.upperBound
        }

        sentences.append(String(text[currentIndex...]))
        return sentences
    }

    private func isStructuralOnly(_ text: String) -> Bool {
        guard !text.isEmpty else { return true }
        let allowedCharacters = CharacterSet(charactersIn: "{}()[];,:")
        return text.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }

    private func replacingMatches(
        in text: String,
        pattern: String,
        with template: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}
