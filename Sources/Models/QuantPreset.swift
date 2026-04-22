import Foundation

enum QuantPreset: String, CaseIterable, Codable, Identifiable {
    case fast
    case balanced
    case quality

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var helperDetail: String {
        switch self {
        case .fast:
            "Smallest download and quickest runtime, with lighter output quality."
        case .balanced:
            "Best starting point for most Macs. Good balance of size, speed, and quality."
        case .quality:
            "Largest download with the strongest quality of the three."
        }
    }
}
