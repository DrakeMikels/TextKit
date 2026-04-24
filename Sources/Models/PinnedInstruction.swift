import Foundation

struct PinnedInstruction: Codable, Equatable, Hashable, Identifiable {
    let id: String
    var name: String
    var instruction: String
    let isBuiltIn: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        instruction: String,
        isBuiltIn: Bool,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PinnedInstruction {
    static let customOptionId = "custom.new"

    static let conciseProfessional = PinnedInstruction(
        id: "builtin.concise-professional",
        name: "Concise Professional",
        instruction: "Make the output concise, professional, and clear. Remove filler while preserving the original intent.",
        isBuiltIn: true,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    static let friendlyClear = PinnedInstruction(
        id: "builtin.friendly-clear",
        name: "Friendly Clear",
        instruction: "Make the output friendly, natural, and easy to understand while keeping it concise.",
        isBuiltIn: true,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    static let executiveSummary = PinnedInstruction(
        id: "builtin.executive-summary",
        name: "Executive Summary",
        instruction: "Make the output brief, high-signal, and executive-ready. Focus only on the most important information.",
        isBuiltIn: true,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    static let directCTA = PinnedInstruction(
        id: "builtin.direct-cta",
        name: "Direct CTA",
        instruction: "Make the output direct and action-oriented. Include a clear next step or call to action when appropriate.",
        isBuiltIn: true,
        createdAt: Date(timeIntervalSince1970: 0),
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    static let builtIns: [PinnedInstruction] = [
        .conciseProfessional,
        .friendlyClear,
        .executiveSummary,
        .directCTA
    ]
}
