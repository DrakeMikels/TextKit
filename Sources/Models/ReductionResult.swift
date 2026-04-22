import Foundation

struct ReductionStats {
    let originalCharacterCount: Int
    let reducedCharacterCount: Int
    let originalEstimatedTokenCount: Int
    let reducedEstimatedTokenCount: Int

    var savedCharacterCount: Int {
        originalCharacterCount - reducedCharacterCount
    }

    var savedEstimatedTokenCount: Int {
        originalEstimatedTokenCount - reducedEstimatedTokenCount
    }

    var reductionPercent: Double {
        guard originalEstimatedTokenCount > 0 else { return 0 }
        return (1 - Double(reducedEstimatedTokenCount) / Double(originalEstimatedTokenCount)) * 100
    }
}

struct ReductionResult {
    let text: String
    let stats: ReductionStats
}
