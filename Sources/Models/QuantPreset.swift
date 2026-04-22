import Foundation

enum QuantPreset: String, CaseIterable, Codable, Identifiable {
    case fast
    case balanced
    case quality

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}
