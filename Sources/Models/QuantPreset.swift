import Foundation

enum QuantPreset: String, CaseIterable, Codable, Identifiable {
    case fast
    case balanced
    case quality

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var cacheTag: String {
        switch self {
        case .fast:
            "Q4_K_S"
        case .balanced:
            "Q4_K_M"
        case .quality:
            "Q5_K_M"
        }
    }

    var suggestedFilename: String {
        switch self {
        case .fast:
            "qwen2.5-0.5b-instruct-q4_k_s.gguf"
        case .balanced:
            "qwen2.5-0.5b-instruct-q4_k_m.gguf"
        case .quality:
            "qwen2.5-0.5b-instruct-q5_k_m.gguf"
        }
    }
}
