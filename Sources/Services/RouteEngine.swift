import Foundation

struct RouteEngine {
    func route(_ text: String, fallback: ToolKind) -> ToolKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        let lowercased = trimmed.lowercased()

        if containsAny(lowercased, phrases: [
            "thanks for reaching out",
            "let me know",
            "just checking in",
            "following up",
            "can you",
            "could you"
        ]) {
            return .reply
        }

        if containsAny(lowercased, phrases: [
            "write a prompt",
            "help me generate",
            "create a prompt",
            "ai prompt",
            "for chatgpt",
            "for claude"
        ]) {
            return .prompt
        }

        if containsDateSignal(lowercased) || containsAny(lowercased, phrases: [
            "action item",
            "deadline",
            "send this",
            "before then",
            "by friday"
        ]) {
            return .extract
        }

        return fallback
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
}
