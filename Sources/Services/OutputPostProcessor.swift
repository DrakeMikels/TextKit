import Foundation

struct OutputPostProcessor {
    func finalize(_ rawOutput: String, for request: GenerationRequest) -> String {
        let rawTrimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = clean(rawTrimmed)

        let finalized: String
        switch request.mode.id {
        case ToolMode.rewriteBullet.id:
            let bulletItems = normalizedBulletItems(from: cleaned.isEmpty ? request.inputText : cleaned)
            finalized = bulletItems.isEmpty ? rawTrimmed : bulletList(from: bulletItems)
        case ToolMode.promptBalanced.id,
             ToolMode.promptDetailed.id,
             ToolMode.promptConstrained.id,
             ToolMode.promptCreative.id:
            finalized = finalizePrompt(cleaned)
        case ToolMode.extractActionItems.id:
            finalized = finalizeActionItems(cleaned, sourceText: request.inputText)
        case ToolMode.extractKeyPoints.id:
            finalized = finalizeKeyPoints(cleaned, sourceText: request.inputText)
        case ToolMode.extractEntities.id:
            finalized = finalizeEntities(cleaned, sourceText: request.inputText)
        case ToolMode.extractDates.id:
            finalized = finalizeDates(cleaned, sourceText: request.inputText)
        case ToolMode.replyCasual.id,
             ToolMode.replyProfessional.id,
             ToolMode.replyConcise.id,
             ToolMode.replyWarm.id:
            finalized = finalizeReply(cleaned, concise: request.mode == .replyConcise)
        default:
            finalized = normalizeParagraph(cleaned)
        }

        let trimmedFinal = finalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedFinal.isEmpty ? rawTrimmed : trimmedFinal
    }

    func _finalizeForTests(_ rawOutput: String, for request: GenerationRequest) -> String {
        finalize(rawOutput, for: request)
    }

    private func finalizePrompt(_ cleaned: String) -> String {
        stripWrappingQuotes(from: cleaned)
    }

    private func finalizeActionItems(_ cleaned: String, sourceText: String) -> String {
        if containsNoResultSignal(cleaned, phrases: ["no action items"]) {
            return "No action items found."
        }

        let actionItems = normalizedBulletItems(from: cleaned)
        if !actionItems.isEmpty {
            return bulletList(from: actionItems)
        }

        let fallbackItems = heuristicActionItems(from: sourceText)
        return fallbackItems.isEmpty ? "No action items found." : bulletList(from: fallbackItems)
    }

    private func finalizeKeyPoints(_ cleaned: String, sourceText: String) -> String {
        let keyPoints = normalizedBulletItems(from: cleaned)
        if !keyPoints.isEmpty {
            return bulletList(from: keyPoints)
        }

        let fallbackItems = heuristicKeyPoints(from: sourceText)
        return fallbackItems.isEmpty ? "No key points found." : bulletList(from: fallbackItems)
    }

    private func finalizeEntities(_ cleaned: String, sourceText: String) -> String {
        if containsNoResultSignal(cleaned, phrases: ["no notable entities", "no entities"]) {
            return "No notable entities found."
        }

        let entities = normalizedBulletItems(from: cleaned)
        if !entities.isEmpty {
            return bulletList(from: entities)
        }

        let fallbackItems = heuristicEntities(from: sourceText)
        return fallbackItems.isEmpty ? "No notable entities found." : bulletList(from: fallbackItems)
    }

    private func finalizeDates(_ cleaned: String, sourceText: String) -> String {
        if containsNoResultSignal(cleaned, phrases: ["no dates or times", "no dates", "no deadlines"]) {
            return "No dates or times found."
        }

        let dates = normalizedBulletItems(from: cleaned)
        if !dates.isEmpty {
            return bulletList(from: dates)
        }

        let fallbackItems = heuristicDates(from: sourceText)
        return fallbackItems.isEmpty ? "No dates or times found." : bulletList(from: fallbackItems)
    }

    private func finalizeReply(_ cleaned: String, concise: Bool) -> String {
        var reply = normalizeParagraph(stripWrappingQuotes(from: cleaned))

        guard concise else { return reply }

        let sentences = sentenceFragments(from: reply)
        if let firstSentence = sentences.first, sentences.count > 1 {
            reply = firstSentence
        }

        let words = reply.split(whereSeparator: \.isWhitespace)
        if words.count > 32 {
            reply = words.prefix(32).joined(separator: " ")
        }

        return reply
    }

    private func clean(_ text: String) -> String {
        var cleaned = text.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("```"), cleaned.hasSuffix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            if lines.count >= 3 {
                cleaned = lines.dropFirst().dropLast().joined(separator: "\n")
            }
        }

        cleaned = stripLeadingLabel(from: cleaned)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripLeadingLabel(from text: String) -> String {
        let labelPrefixes = [
            "rewrite",
            "rewritten text",
            "rewritten version",
            "prompt",
            "final prompt",
            "reply",
            "response",
            "draft reply",
            "action items",
            "key points",
            "entities",
            "dates",
            "deadlines"
        ]

        var workingText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = workingText.components(separatedBy: "\n")
        if let firstLine = lines.first {
            let trimmedLine = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedLine = normalizedLabel(trimmedLine)

            if labelPrefixes.contains(normalizedLine) {
                return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }

            for label in labelPrefixes {
                let prefix = "\(label):"
                if normalizedLine.hasPrefix(prefix) {
                    let originalIndex = trimmedLine.index(trimmedLine.startIndex, offsetBy: prefix.count)
                    let remainder = trimmedLine[originalIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if remainder.isEmpty {
                        return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    workingText = remainder + (lines.count > 1 ? "\n" + lines.dropFirst().joined(separator: "\n") : "")
                    return workingText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return workingText
    }

    private func normalizedLabel(_ value: String) -> String {
        value.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
    }

    private func stripWrappingQuotes(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return trimmed }

        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("“") && trimmed.hasSuffix("”"))
        {
            return String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmed
    }

    private func normalizeParagraph(_ text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func normalizedBulletItems(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lines = trimmed.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var explicitItems: [String] = []
        var usedExplicitBullets = false

        for line in lines {
            if let stripped = stripListPrefix(from: line) {
                explicitItems.append(cleanListItem(stripped))
                usedExplicitBullets = true
            }
        }

        if usedExplicitBullets {
            return deduplicated(explicitItems)
        }

        if lines.count > 1 {
            return deduplicated(lines.map(cleanListItem))
        }

        return deduplicated(clauseFragments(from: trimmed, splitCommas: true).map(cleanListItem))
    }

    private func stripListPrefix(from line: String) -> String? {
        let pattern = #"^(?:[-*•]|\d+[.)])\s+"#
        guard let range = line.range(of: pattern, options: .regularExpression) else {
            return nil
        }

        return String(line[range.upperBound...])
    }

    private func cleanListItem(_ item: String) -> String {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-*• "))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return trimmed }

        let punctuationStripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
        let first = punctuationStripped.prefix(1).uppercased()
        return first + punctuationStripped.dropFirst()
    }

    private func bulletList(from items: [String]) -> String {
        items.map { "- \($0)" }.joined(separator: "\n")
    }

    private func heuristicActionItems(from text: String) -> [String] {
        let signals = [
            "send",
            "review",
            "confirm",
            "finish",
            "update",
            "draft",
            "prepare",
            "follow up",
            "schedule",
            "check",
            "write",
            "create",
            "finalize",
            "share",
            "ship",
            "call",
            "email"
        ]

        return deduplicated(
            clauseFragments(from: text, splitCommas: true)
                .map(normalizeActionClause)
                .filter { clause in
                    let lowercased = clause.lowercased()
                    return !clause.isEmpty && (
                        signals.contains(where: lowercased.contains)
                            || lowercased.contains("need to")
                            || lowercased.contains("needs to")
                            || lowercased.hasPrefix("please ")
                            || lowercased.hasPrefix("can you ")
                            || lowercased.hasPrefix("could you ")
                            || lowercased.hasPrefix("let's ")
                    )
                }
        )
    }

    private func heuristicKeyPoints(from text: String) -> [String] {
        deduplicated(sentenceFragments(from: text).prefix(3).map(cleanListItem))
    }

    private func heuristicEntities(from text: String) -> [String] {
        let pattern = #"\b(?:[A-Z][A-Za-z]+|[A-Z]{2,})(?:\s+(?:[A-Z][A-Za-z]+|[A-Z]{2,}|&))*\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let ignored = Set([
            "I",
            "The",
            "A",
            "An",
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday",
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December"
        ])

        let entities = matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else { return nil }
            let candidate = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            return ignored.contains(candidate) ? nil : candidate
        }

        return deduplicated(entities)
    }

    private func heuristicDates(from text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return []
        }

        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let items = matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else { return nil }
            return text[range].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return deduplicated(items)
    }

    private func containsNoResultSignal(_ text: String, phrases: [String]) -> Bool {
        let normalized = text.lowercased()
        return phrases.contains(where: normalized.contains)
    }

    private func clauseFragments(from text: String, splitCommas: Bool) -> [String] {
        let newlineSeparated = text
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: ";") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let baseFragments = newlineSeparated.count > 1 ? newlineSeparated : sentenceFragments(from: text)

        if !splitCommas {
            return baseFragments
        }

        return baseFragments.flatMap { fragment in
            let commaSeparated = fragment.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if commaSeparated.count > 1 {
                return commaSeparated
            }

            if fragment.contains(" and ") {
                let conjunctionSeparated = fragment.components(separatedBy: " and ")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                if conjunctionSeparated.count > 1 {
                    return conjunctionSeparated
                }
            }

            return [fragment]
        }
    }

    private func sentenceFragments(from text: String) -> [String] {
        let nsText = text as NSString
        var sentences: [String] = []
        nsText.enumerateSubstrings(
            in: NSRange(location: 0, length: nsText.length),
            options: [.bySentences, .substringNotRequired]
        ) { _, range, _, _ in
            let sentence = nsText.substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
        }

        if !sentences.isEmpty {
            return sentences
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [trimmed]
    }

    private func normalizeActionClause(_ clause: String) -> String {
        let replacements = [
            "please ",
            "can you ",
            "could you ",
            "let's ",
            "we need to ",
            "need to ",
            "needs to "
        ]

        var normalized = clause.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()

        for replacement in replacements where lowercased.hasPrefix(replacement) {
            normalized = String(normalized.dropFirst(replacement.count))
            break
        }

        return cleanListItem(normalized)
    }

    private func deduplicated(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var orderedItems: [String] = []

        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }

            seen.insert(key)
            orderedItems.append(trimmed)
        }

        return orderedItems
    }
}
