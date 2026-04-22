import Foundation

enum ToolKind: String, CaseIterable, Codable, Identifiable {
    case rewrite
    case prompt
    case extract
    case reply

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rewrite:
            "Rewrite"
        case .prompt:
            "Prompt"
        case .extract:
            "Extract"
        case .reply:
            "Reply"
        }
    }

    var systemImage: String {
        switch self {
        case .rewrite:
            "wand.and.stars"
        case .prompt:
            "text.bubble"
        case .extract:
            "line.3.horizontal.decrease.circle"
        case .reply:
            "arrowshape.turn.up.left"
        }
    }

    var description: String {
        switch self {
        case .rewrite:
            "Improve tone or clarity."
        case .prompt:
            "Turn intent into a stronger prompt."
        case .extract:
            "Pull structure from messy text."
        case .reply:
            "Draft a response to copied text."
        }
    }

    var modes: [ToolMode] {
        ToolMode.modes(for: self)
    }

    var defaultMode: ToolMode {
        modes[0]
    }
}
