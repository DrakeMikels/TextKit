import Foundation

enum ToolKind: String, CaseIterable, Codable, Identifiable {
    case rewrite
    case prompt
    case extract
    case reply
    case reduce

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
        case .reduce:
            "Reduce"
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
        case .reduce:
            "arrow.down.right.and.arrow.up.left"
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
        case .reduce:
            "Shrink repetitive logs or long text."
        }
    }

    var usesModel: Bool {
        self != .reduce
    }

    var requiresManualSubmit: Bool {
        self == .reduce
    }

    var modes: [ToolMode] {
        ToolMode.modes(for: self)
    }

    var defaultMode: ToolMode {
        switch self {
        case .reduce:
            .reduceStructured
        default:
            modes[0]
        }
    }
}
