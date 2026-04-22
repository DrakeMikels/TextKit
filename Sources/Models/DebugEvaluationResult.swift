import Foundation

struct DebugEvaluationResult {
    let rawOutput: String
    let finalizedOutput: String
    let keepsRuntimeWarm: Bool
}

enum DebugEvaluationError: LocalizedError {
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            "Add sample text before running a live check."
        }
    }
}
