import Foundation

struct InferenceEngine {
    func generate(for request: GenerationRequest, prompt: String) -> String {
        let input = normalizedWhitespace(request.inputText)

        switch request.tool {
        case .rewrite:
            return rewrite(input: input, mode: request.mode, refine: request.refineInstruction)
        case .prompt:
            return promptify(input: input, mode: request.mode, refine: request.refineInstruction)
        case .extract:
            return extract(input: input, mode: request.mode)
        case .reply:
            return reply(input: input, mode: request.mode, refine: request.refineInstruction)
        }
    }

    private func rewrite(input: String, mode: ToolMode, refine: String) -> String {
        switch mode.id {
        case ToolMode.rewriteClean.id:
            return sentenceCase(input)
        case ToolMode.rewriteShort.id:
            return shortened(input, wordLimit: 18)
        case ToolMode.rewriteProfessional.id:
            return "Polished version: \(sentenceCase(input))"
        case ToolMode.rewriteBullet.id:
            return bullets(from: input, fallbackPrefix: "Key point")
        default:
            return sentenceCase(input)
        }
    }

    private func promptify(input: String, mode: ToolMode, refine: String) -> String {
        let extraLine = refine.isEmpty ? nil : "Additional constraint: \(refine)"

        let baseLines: [String]
        switch mode.id {
        case ToolMode.promptDetailed.id:
            baseLines = [
                "Goal:",
                input,
                "",
                "Return:",
                "- Clear output structure",
                "- Relevant constraints",
                "- Important context"
            ]
        case ToolMode.promptConstrained.id:
            baseLines = [
                "Task: \(input)",
                "Constraints:",
                "- Be concise",
                "- Use a structured format",
                "- Do not add unnecessary explanation"
            ]
        case ToolMode.promptCreative.id:
            baseLines = [
                "You are a creative assistant.",
                "Complete this request with strong voice and originality:",
                input
            ]
        default:
            baseLines = [
                "Task: \(input)",
                "Output guidance: respond clearly, directly, and in a paste-ready format."
            ]
        }

        return (baseLines + [extraLine].compactMap { $0 }).joined(separator: "\n")
    }

    private func extract(input: String, mode: ToolMode) -> String {
        switch mode.id {
        case ToolMode.extractActionItems.id:
            let items = actionItems(in: input)
            return items.isEmpty ? "No action items found." : items.map { "• \($0)" }.joined(separator: "\n")
        case ToolMode.extractEntities.id:
            let items = entities(in: input)
            return items.isEmpty ? "No notable entities found." : items.map { "• \($0)" }.joined(separator: "\n")
        case ToolMode.extractDates.id:
            let items = dates(in: input)
            return items.isEmpty ? "No dates or times found." : items.map { "• \($0)" }.joined(separator: "\n")
        default:
            let items = keyPoints(in: input)
            return items.map { "• \($0)" }.joined(separator: "\n")
        }
    }

    private func reply(input: String, mode: ToolMode, refine: String) -> String {
        let snippet = shortened(input, wordLimit: 12)

        switch mode.id {
        case ToolMode.replyProfessional.id:
            return "Thanks for the note. I reviewed \"\(snippet)\" and will follow up shortly."
        case ToolMode.replyConcise.id:
            return "Thanks. I’ll take a look and follow up soon."
        case ToolMode.replyWarm.id:
            return "Thanks for sharing this. I appreciate the context and will get back to you soon."
        default:
            return "Thanks for sending this over. I’ll take a look and get back to you."
        }
    }

    private func normalizedWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func sentenceCase(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private func shortened(_ text: String, wordLimit: Int) -> String {
        let words = text.split(separator: " ")
        guard words.count > wordLimit else { return text }
        return words.prefix(wordLimit).joined(separator: " ") + "..."
    }

    private func bullets(from text: String, fallbackPrefix: String) -> String {
        let parts = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return "• \(fallbackPrefix): \(text)"
        }

        return parts.prefix(4).enumerated().map { index, part in
            "• \(index == 0 ? part : shortened(part, wordLimit: 14))"
        }.joined(separator: "\n")
    }

    private func keyPoints(in text: String) -> [String] {
        let points = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if points.isEmpty {
            return [text]
        }

        return Array(points.prefix(4))
    }

    private func actionItems(in text: String) -> [String] {
        let lines = keyPoints(in: text)
        let actionSignals = ["please", "send", "review", "follow up", "need to", "action"]
        let matches = lines.filter { line in
            let lowercased = line.lowercased()
            return actionSignals.contains(where: lowercased.contains)
        }

        return matches.isEmpty ? Array(lines.prefix(2)) : matches
    }

    private func entities(in text: String) -> [String] {
        let pattern = #"\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        let values = matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }

        return Array(NSOrderedSet(array: values)) as? [String] ?? []
    }

    private func dates(in text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}
