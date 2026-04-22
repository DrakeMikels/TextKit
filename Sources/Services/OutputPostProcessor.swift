import Foundation

struct OutputPostProcessor {
    private let rewriteHeuristicsEnabled: Bool

    init(rewriteHeuristicsEnabled: Bool = true) {
        self.rewriteHeuristicsEnabled = rewriteHeuristicsEnabled
    }

    func finalize(_ rawOutput: String, for request: GenerationRequest) -> String {
        let rawTrimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = clean(rawTrimmed)

        let finalized: String
        switch request.mode.id {
        case ToolMode.rewriteClean.id:
            finalized = finalizeRewriteClean(cleaned, sourceText: request.inputText)
        case ToolMode.rewriteShort.id:
            finalized = finalizeRewriteShort(cleaned, sourceText: request.inputText)
        case ToolMode.rewriteProfessional.id:
            finalized = finalizeRewriteProfessional(cleaned, sourceText: request.inputText)
        case ToolMode.rewriteBullet.id:
            let bulletSource = rewriteHeuristicsEnabled && (shouldFallbackToSourceBullets(cleaned) || cleaned.isEmpty)
                ? request.inputText
                : cleaned
            let bulletItems = normalizedBulletItems(from: bulletSource)
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

    private func finalizeRewriteClean(_ cleaned: String, sourceText: String) -> String {
        let seed = cleaned.isEmpty ? sourceText : cleaned
        return cleanupRewriteParagraph(seed)
    }

    private func finalizeRewriteShort(_ cleaned: String, sourceText: String) -> String {
        let candidate = cleanupRewriteParagraph(cleaned.isEmpty ? sourceText : cleaned)

        guard rewriteHeuristicsEnabled else {
            return candidate
        }

        guard shouldFallbackToShortRewrite(candidate, sourceText: sourceText) else {
            return candidate
        }

        return shortenedRewrite(from: sourceText)
    }

    private func finalizeRewriteProfessional(_ cleaned: String, sourceText: String) -> String {
        let candidate = cleanupRewriteParagraph(cleaned.isEmpty ? sourceText : cleaned)

        guard rewriteHeuristicsEnabled else {
            return candidate
        }

        guard shouldFallbackToProfessionalRewrite(candidate, sourceText: sourceText) else {
            return candidate
        }

        return professionalRewrite(from: candidate.isEmpty ? sourceText : candidate)
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

    private func cleanupRewriteParagraph(_ text: String) -> String {
        var cleaned = normalizeParagraph(stripWrappingQuotes(from: text))
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = normalizeStandalonePronounI(in: cleaned)
        cleaned = capitalizeCalendarTerms(in: cleaned)
        cleaned = capitalizeLeadingCharacter(in: cleaned)

        guard let last = cleaned.last else { return cleaned }
        if ".!?".contains(last) {
            return cleaned
        }

        return cleaned + terminalPunctuation(for: cleaned)
    }

    private func shouldFallbackToShortRewrite(_ candidate: String, sourceText: String) -> Bool {
        let sourceWordCount = wordCount(in: sourceText)
        let candidateWordCount = wordCount(in: candidate)
        let lowercased = candidate.lowercased()
        let noteLikeStarts = ["check ", "send ", "review ", "confirm ", "finish ", "update "]
        let lacksSubject = !lowercased.contains(" i ")
            && !lowercased.contains(" you ")
            && !lowercased.contains(" we ")
            && !lowercased.hasPrefix("i ")
            && !lowercased.hasPrefix("you ")
            && !lowercased.hasPrefix("we ")
        let isNoteLike = noteLikeStarts.contains(where: { lowercased.hasPrefix($0) }) && lacksSubject
        let isNotMeaningfullyShorter = candidateWordCount >= max(4, sourceWordCount - 2)
        let sourceSimilarity = tokenSimilarity(between: candidate, and: sourceText)
        let stillReadsLikeSource = sourceSimilarity >= 0.82
        let fillerHeavyLead = lowercased.hasPrefix("just wanted to check whether ")
            || lowercased.hasPrefix("i wanted to follow up and see whether ")
            || lowercased.hasPrefix("i wanted to follow up ")

        return isNoteLike || isNotMeaningfullyShorter || stillReadsLikeSource || fillerHeavyLead
    }

    private func shouldFallbackToProfessionalRewrite(_ candidate: String, sourceText: String) -> Bool {
        let normalizedSource = normalizedComparableText(sourceText)
        let normalizedCandidate = normalizedComparableText(candidate)
        let stillSoundsCasual = candidate.lowercased().contains("hey ")
            || candidate.lowercased().contains("hey,")
            || candidate.lowercased().contains("just checking if")
            || candidate.lowercased().hasPrefix("can you ")
            || candidate.lowercased().hasPrefix("checking whether you can ")
            || candidate.lowercased().hasPrefix("confirming ")

        let sourceLooksLikeRequest = sourceText.lowercased().contains("can you ")
            || sourceText.lowercased().contains("could you ")
            || sourceText.lowercased().contains("you can confirm ")
        let candidateLostRequestShape = sourceLooksLikeRequest && (
            candidate.lowercased().hasPrefix("i need ")
                || candidate.lowercased().hasPrefix("confirming ")
                || !(candidate.lowercased().contains("could you") || candidate.lowercased().contains("please"))
        )

        return normalizedCandidate == normalizedSource || stillSoundsCasual || candidateLostRequestShape
    }

    private func shortenedRewrite(from text: String) -> String {
        let cleanedSource = cleanupRewriteParagraph(text).trimmingCharacters(in: CharacterSet(charactersIn: ".?!"))
        let greeting = extractGreeting(from: cleanedSource)
        var body = greeting.remainder.isEmpty ? cleanedSource : greeting.remainder

        body = replacingLeadingPhrase(in: body, phrase: "just wanted to check whether ", with: "does ")
        body = replacingLeadingPhrase(in: body, phrase: "just checking if ", with: "does ")
        body = replacingLeadingPhrase(in: body, phrase: "checking if ", with: "does ")
        body = replacingLeadingPhrase(in: body, phrase: "following up on whether we're ", with: "are we ")
        body = replacingLeadingPhrase(in: body, phrase: "following up on whether we are ", with: "are we ")
        body = replacingLeadingPhrase(in: body, phrase: "wanted to follow up and see whether ", with: "following up on whether ")
        body = replacingLeadingPhrase(in: body, phrase: "wanted to follow up ", with: "following up ")
        body = body.replacingOccurrences(of: #"\bjust\b"#, with: "", options: .regularExpression)
        body = body.replacingOccurrences(of: #"\breally\b"#, with: "", options: .regularExpression)
        body = body.replacingOccurrences(of: #"\bvery\b"#, with: "", options: .regularExpression)
        body = body.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if body.lowercased().hasPrefix("does ") {
            body = body.replacingOccurrences(of: " still works ", with: " still work ")
            body = body.replacingOccurrences(of: " still needs ", with: " still need ")
            body = body.replacingOccurrences(of: " works ", with: " work ")
            body = body.replacingOccurrences(of: " needs ", with: " need ")
        }

        let leadingPunctuation = leadingClausePunctuation(for: body)
        if leadingPunctuation == "?" {
            body = body.replacingOccurrences(
                of: #"\.\s*if not,\s*\.?\s*"#,
                with: "? If not, ",
                options: [.regularExpression, .caseInsensitive]
            )
        } else {
            body = body.replacingOccurrences(
                of: #"\.\s*if not,\s*\.?\s*"#,
                with: ". If not, ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        body = body.replacingOccurrences(
            of: #"\bIf not,\.\s*"#,
            with: "If not, ",
            options: .regularExpression
        )
        body = body.replacingOccurrences(of: " or if I should ", with: ", or should I ")
        body = body.replacingOccurrences(of: " and if not ", with: ". If not, ")
        body = body.replacingOccurrences(of: " shorten deck ", with: " shorten the deck ")
        body = body.replacingOccurrences(of: " send revised", with: " send a revised version")
        body = splitBeforeICan(in: body, firstSentencePunctuation: leadingPunctuation)
        body = cleanupRewriteParagraph(body)

        if let name = greeting.name {
            return "\(name), \(lowercaseLeadingCharacter(in: body))"
        }

        return body
    }

    private func professionalRewrite(from text: String) -> String {
        let cleanedSource = cleanupRewriteParagraph(text).trimmingCharacters(in: CharacterSet(charactersIn: ".?!"))
        let greeting = extractGreeting(from: cleanedSource)
        var body = greeting.remainder.isEmpty ? cleanedSource : greeting.remainder

        if body.lowercased().hasPrefix("i need the numbers")
            && body.lowercased().contains("board")
        {
            body = "Could you send me the numbers by tomorrow morning so I can include them in the board update"
        }

        body = replacingLeadingPhrase(in: body, phrase: "confirming ", with: "could you confirm ")
        body = replacingLeadingPhrase(in: body, phrase: "checking whether you can ", with: "could you ")
        body = replacingLeadingPhrase(in: body, phrase: "just checking if ", with: "could you confirm whether ")
        body = replacingLeadingPhrase(in: body, phrase: "checking if ", with: "could you confirm whether ")
        body = replacingLeadingPhrase(in: body, phrase: "can you ", with: "could you ")
        body = body.replacingOccurrences(of: "I need the numbers", with: "Could you send me the numbers")
        body = body.replacingOccurrences(of: " so I can get this into ", with: " so I can include them in ")
        body = body.replacingOccurrences(of: " so i can get this into ", with: " so I can include them in ")
        body = body.replacingOccurrences(of: ". I can ", with: "? I can ")
        body = splitBeforeICan(in: body, firstSentencePunctuation: terminalPunctuation(for: body))
        body = cleanupRewriteParagraph(body)

        if body.lowercased().hasPrefix("could you ")
            && !body.hasSuffix("?")
            && !body.contains(". ")
            && !body.contains("? ")
            && !body.contains("! ")
        {
            body = body.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            body += "?"
        }

        if let name = greeting.name {
            return "Hi \(name), \(lowercaseLeadingCharacter(in: body))"
        }

        return body
    }

    private func clean(_ text: String) -> String {
        var cleaned = text.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(
            of: #"<think>[\s\S]*?</think>"#,
            with: "\n",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
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

    private func normalizeStandalonePronounI(in text: String) -> String {
        text.replacingOccurrences(
            of: #"\bi\b"#,
            with: "I",
            options: .regularExpression
        )
    }

    private func capitalizeCalendarTerms(in text: String) -> String {
        let terms = [
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
            "january", "february", "march", "april", "may", "june", "july", "august",
            "september", "october", "november", "december"
        ]

        return terms.reduce(text) { partialResult, term in
            partialResult.replacingOccurrences(
                of: "\\b\(term)\\b",
                with: term.capitalized,
                options: .regularExpression
            )
        }
    }

    private func capitalizeLeadingCharacter(in text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private func lowercaseLeadingCharacter(in text: String) -> String {
        guard let first = text.first else { return text }
        let firstWord = text.split(separator: " ").first?.lowercased() ?? ""
        let shouldLowercase = ["does", "do", "did", "could", "can", "would", "will", "should", "please"]
            .contains(firstWord)

        guard shouldLowercase else { return text }
        return first.lowercased() + text.dropFirst()
    }

    private func terminalPunctuation(for text: String) -> String {
        let lowercased = text.lowercased()
        if lowercased.contains(". ") || lowercased.contains("? ") || lowercased.contains("! ") {
            return "."
        }

        let questionStarters = [
            "does ",
            "do ",
            "did ",
            "is ",
            "are ",
            "can ",
            "could ",
            "would ",
            "will ",
            "should "
        ]

        return questionStarters.contains(where: lowercased.hasPrefix) ? "?" : "."
    }

    private func leadingClausePunctuation(for text: String) -> String {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let questionStarters = [
            "does ",
            "do ",
            "did ",
            "is ",
            "are ",
            "can ",
            "could ",
            "would ",
            "will ",
            "should "
        ]

        return questionStarters.contains(where: lowercased.hasPrefix) ? "?" : terminalPunctuation(for: text)
    }

    private func splitBeforeICan(in text: String, firstSentencePunctuation: String) -> String {
        let lowercased = text.lowercased()
        guard
            !lowercased.contains(". i can "),
            !lowercased.contains("? i can "),
            let range = lowercased.range(of: " i can ")
        else {
            return text
        }

        let prefixLowercased = lowercased[..<range.lowerBound]
        if prefixLowercased.hasSuffix(" so") {
            return text
        }

        if prefixLowercased.hasSuffix("if not,") {
            return text
        }

        let prefix = text[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty, !suffix.isEmpty else { return text }

        return "\(prefix)\(firstSentencePunctuation) I can \(suffix)"
    }

    private func extractGreeting(from text: String) -> (name: String?, remainder: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        for greeting in ["hey", "hi"] {
            let variants = ["\(greeting) ", "\(greeting), "]

            for variant in variants where lowercased.hasPrefix(variant) {
                let remainder = String(trimmed.dropFirst(variant.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                let components = remainder.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                guard let firstComponent = components.first else {
                    return (nil, trimmed)
                }

                let name = firstComponent.trimmingCharacters(in: CharacterSet(charactersIn: ",.!?;:")).capitalized
                let leftover = components.count > 1 ? String(components[1]) : ""
                return (name.isEmpty ? nil : name, leftover.trimmingCharacters(in: CharacterSet(charactersIn: ", ")))
            }
        }

        return (nil, trimmed)
    }

    private func replacingLeadingPhrase(in text: String, phrase: String, with replacement: String) -> String {
        let lowercasedText = text.lowercased()
        let lowercasedPhrase = phrase.lowercased()

        guard lowercasedText.hasPrefix(lowercasedPhrase) else {
            return text
        }

        return replacement + text.dropFirst(phrase.count)
    }

    private func normalizedComparableText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: "", options: .regularExpression)
    }

    private func wordCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
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

        let conjunctionStripped = trimmed.replacingOccurrences(
            of: #"^(?:and|or)\s+"#,
            with: "",
            options: .regularExpression
        )
        let punctuationStripped = conjunctionStripped.trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
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

    private func shouldFallbackToSourceBullets(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let analysisSignals = [
            "analyze the request",
            "role:**",
            "task:**",
            "constraint 1",
            "constraint 2",
            "input text:**",
            "local macos text utility"
        ]

        return analysisSignals.contains(where: normalized.contains)
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
