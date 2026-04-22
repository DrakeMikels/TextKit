import Foundation

struct RouteDecision {
    let tool: ToolKind
    let preferredMode: ToolMode?
    let shouldAutoGenerate: Bool
}

struct RouteEngine {
    private static let timestampRegex = try! NSRegularExpression(
        pattern: #"\b\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?\b"#
    )

    func route(_ text: String, fallback: ToolKind) -> ToolKind {
        decide(text, fallback: fallback).tool
    }

    func decide(_ text: String, fallback: ToolKind) -> RouteDecision {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return RouteDecision(
                tool: fallback,
                preferredMode: nil,
                shouldAutoGenerate: !fallback.requiresManualSubmit
            )
        }

        let lowercased = trimmed.lowercased()

        if let preferredReduceMode = preferredReduceMode(for: trimmed, lowercased: lowercased) {
            return RouteDecision(
                tool: .reduce,
                preferredMode: preferredReduceMode,
                shouldAutoGenerate: false
            )
        }

        if containsAny(lowercased, phrases: [
            "thanks for reaching out",
            "let me know",
            "just checking in",
            "following up",
            "can you",
            "could you"
        ]) {
            return RouteDecision(tool: .reply, preferredMode: nil, shouldAutoGenerate: true)
        }

        if containsAny(lowercased, phrases: [
            "write a prompt",
            "help me generate",
            "create a prompt",
            "ai prompt",
            "for chatgpt",
            "for claude"
        ]) {
            return RouteDecision(tool: .prompt, preferredMode: nil, shouldAutoGenerate: true)
        }

        if containsDateSignal(lowercased) || containsAny(lowercased, phrases: [
            "action item",
            "deadline",
            "send this",
            "before then",
            "by friday"
        ]) {
            return RouteDecision(tool: .extract, preferredMode: nil, shouldAutoGenerate: true)
        }

        return RouteDecision(
            tool: fallback,
            preferredMode: nil,
            shouldAutoGenerate: !fallback.requiresManualSubmit
        )
    }

    private func containsAny(_ text: String, phrases: [String]) -> Bool {
        phrases.contains(where: text.contains)
    }

    private func containsDateSignal(_ text: String) -> Bool {
        [
            "today",
            "tomorrow",
            "monday",
            "tuesday",
            "wednesday",
            "thursday",
            "friday",
            "saturday",
            "sunday",
            "am",
            "pm"
        ].contains(where: text.contains)
    }

    private func preferredReduceMode(for text: String, lowercased: String) -> ToolMode? {
        guard text.count >= 1_500 else { return nil }

        let newlineCount = text.filter(\.isNewline).count
        let semicolonCount = text.filter { $0 == ";" }.count
        let equalsCount = text.filter { $0 == "=" }.count
        let braceCount = text.filter { "{}[]".contains($0) }.count
        let timestampMatches = Self.timestampRegex.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        )
        let logKeywordHits = [
            "warning",
            "error",
            "status",
            "request",
            "trace",
            "build",
            "metrics",
            "queue",
            "worker",
            "redis",
            "database",
            "json",
            "payload",
            "candidate",
            "analytics"
        ].reduce(into: 0) { partialResult, keyword in
            if lowercased.contains(keyword) {
                partialResult += 1
            }
        }

        let looksStructured = semicolonCount >= 8
            || newlineCount >= 10
            || equalsCount >= 10
            || braceCount >= 6
            || logKeywordHits >= 4
        let looksLikeLogs = timestampMatches >= 2 || semicolonCount >= 8 || newlineCount >= 10

        guard looksStructured || looksLikeLogs else { return nil }
        return equalsCount >= 10 || braceCount >= 6 ? .reduceStructured : .reduceLogs
    }
}
