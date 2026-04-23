import Foundation

enum ModelProfile: String, CaseIterable, Codable, Identifiable {
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
            "Returns shorter results more quickly."
        case .balanced:
            "Best default for most clips and everyday use."
        case .quality:
            "Allows more detail and a little more work per response."
        }
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
