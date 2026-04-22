import Foundation

enum LocalModelOption: String, CaseIterable, Codable, Identifiable {
    case stable
    case experimental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stable:
            "Qwen2.5 0.5B"
        case .experimental:
            "Qwen3.5 0.8B (Experimental)"
        }
    }

    var displayName: String {
        title
    }

    var repository: String {
        switch self {
        case .stable:
            "Qwen/Qwen2.5-0.5B-Instruct-GGUF"
        case .experimental:
            "AaryanK/Qwen3.5-0.8B-GGUF"
        }
    }

    var runtimeName: String {
        "llama.cpp local runtime"
    }

    var requiresReasoningOff: Bool {
        switch self {
        case .stable:
            false
        case .experimental:
            true
        }
    }

    var helperDetail: String {
        switch self {
        case .stable:
            "Fastest and most stable local option."
        case .experimental:
            "Larger model for eval and side-by-side testing. May be slower or less predictable."
        }
    }

    var setupBadgeTitle: String {
        switch self {
        case .stable:
            "Recommended"
        case .experimental:
            "Experimental"
        }
    }

    var setupSummary: String {
        switch self {
        case .stable:
            "Best first download for everyday rewriting, replies, and summaries."
        case .experimental:
            "Optional larger model for comparison testing and side-by-side evaluation."
        }
    }

    func suggestedFilename(for quantPreset: QuantPreset) -> String {
        switch self {
        case .stable:
            switch quantPreset {
            case .fast:
                "qwen2.5-0.5b-instruct-q4_0.gguf"
            case .balanced:
                "qwen2.5-0.5b-instruct-q4_k_m.gguf"
            case .quality:
                "qwen2.5-0.5b-instruct-q5_k_m.gguf"
            }
        case .experimental:
            switch quantPreset {
            case .fast:
                "Qwen3.5-0.8B.q4_k_s.gguf"
            case .balanced:
                "Qwen3.5-0.8B.q4_k_m.gguf"
            case .quality:
                "Qwen3.5-0.8B.q5_k_m.gguf"
            }
        }
    }

    func cacheTag(for quantPreset: QuantPreset) -> String {
        switch self {
        case .stable:
            switch quantPreset {
            case .fast:
                "Q4_0"
            case .balanced:
                "Q4_K_M"
            case .quality:
                "Q5_K_M"
            }
        case .experimental:
            switch quantPreset {
            case .fast:
                "Q4_K_S"
            case .balanced:
                "Q4_K_M"
            case .quality:
                "Q5_K_M"
            }
        }
    }
}
