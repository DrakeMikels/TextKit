import Foundation

struct CacheKey: Hashable {
    let clipboardHash: Int
    let tool: ToolKind
    let modeID: String
    let modelOption: LocalModelOption
    let modelProfile: ModelProfile
    let quantPreset: QuantPreset
    let refineInstruction: String
    let configurationFingerprint: String
}

final class CacheStore {
    private var outputs: [CacheKey: String] = [:]

    func output(for key: CacheKey) -> String? {
        outputs[key]
    }

    func store(_ output: String, for key: CacheKey) {
        outputs[key] = output
    }

    func invalidateAll() {
        outputs.removeAll()
    }
}
