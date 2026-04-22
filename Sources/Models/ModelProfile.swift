import Foundation

enum ModelProfile: String, CaseIterable, Codable, Identifiable {
    case fast
    case balanced
    case quality

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var tokenBudgetMultiplier: Double {
        switch self {
        case .fast:
            0.75
        case .balanced:
            1
        case .quality:
            1.25
        }
    }
}
