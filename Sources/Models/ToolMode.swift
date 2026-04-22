import Foundation

struct ToolMode: Hashable, Codable, Identifiable {
    let id: String
    let title: String
    let tool: ToolKind

    static let rewriteClean = ToolMode(id: "rewrite.clean", title: "Clean", tool: .rewrite)
    static let rewriteShort = ToolMode(id: "rewrite.short", title: "Short", tool: .rewrite)
    static let rewriteProfessional = ToolMode(id: "rewrite.professional", title: "Professional", tool: .rewrite)
    static let rewriteBullet = ToolMode(id: "rewrite.bullet", title: "Bullet", tool: .rewrite)

    static let promptBalanced = ToolMode(id: "prompt.balanced", title: "Balanced", tool: .prompt)
    static let promptDetailed = ToolMode(id: "prompt.detailed", title: "Detailed", tool: .prompt)
    static let promptConstrained = ToolMode(id: "prompt.constrained", title: "Constrained", tool: .prompt)
    static let promptCreative = ToolMode(id: "prompt.creative", title: "Creative", tool: .prompt)

    static let extractActionItems = ToolMode(id: "extract.action-items", title: "Action Items", tool: .extract)
    static let extractKeyPoints = ToolMode(id: "extract.key-points", title: "Key Points", tool: .extract)
    static let extractEntities = ToolMode(id: "extract.entities", title: "Entities", tool: .extract)
    static let extractDates = ToolMode(id: "extract.dates", title: "Dates", tool: .extract)

    static let replyCasual = ToolMode(id: "reply.casual", title: "Casual", tool: .reply)
    static let replyProfessional = ToolMode(id: "reply.professional", title: "Professional", tool: .reply)
    static let replyConcise = ToolMode(id: "reply.concise", title: "Concise", tool: .reply)
    static let replyWarm = ToolMode(id: "reply.warm", title: "Warm", tool: .reply)

    static func modes(for tool: ToolKind) -> [ToolMode] {
        switch tool {
        case .rewrite:
            [.rewriteClean, .rewriteShort, .rewriteProfessional, .rewriteBullet]
        case .prompt:
            [.promptBalanced, .promptDetailed, .promptConstrained, .promptCreative]
        case .extract:
            [.extractActionItems, .extractKeyPoints, .extractEntities, .extractDates]
        case .reply:
            [.replyCasual, .replyProfessional, .replyConcise, .replyWarm]
        }
    }
}
