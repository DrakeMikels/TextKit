import Foundation
import Observation

struct LocalModelDescriptor {
    let displayName: String
    let repository: String
    let suggestedFilename: String
    let runtime: String
}

@Observable
final class ModelManager {
    let defaultModel = LocalModelDescriptor(
        displayName: "Qwen2.5 0.5B Instruct",
        repository: "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
        suggestedFilename: "qwen2.5-0.5b-instruct-q5_k_m.gguf",
        runtime: "llama.cpp-compatible GGUF backend"
    )

    private(set) var isWarm = false

    var statusSummary: String {
        isWarm ? "On-device · warm" : "On-device"
    }

    func markWarm() {
        isWarm = true
    }
}
