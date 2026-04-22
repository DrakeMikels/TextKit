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

    static let allCases: [ToolMode] = [
        .rewriteClean,
        .rewriteShort,
        .rewriteProfessional,
        .rewriteBullet,
        .promptBalanced,
        .promptDetailed,
        .promptConstrained,
        .promptCreative,
        .extractActionItems,
        .extractKeyPoints,
        .extractEntities,
        .extractDates,
        .replyCasual,
        .replyProfessional,
        .replyConcise,
        .replyWarm
    ]

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

    static func mode(for id: String) -> ToolMode? {
        allCases.first { $0.id == id }
    }

    var defaultSystemInstruction: String {
        switch id {
        case ToolMode.rewriteClean.id:
            "Keep the rewrite close to the source. Fix grammar, capitalization, punctuation, and awkward phrasing. Do not make it more formal unless the source already is."
        case ToolMode.rewriteShort.id:
            "Make the rewrite materially shorter. Remove filler, repetition, and softeners before you remove meaning."
        case ToolMode.rewriteProfessional.id:
            "Rewrite the text as a polished workplace message. Use complete sentences, clean punctuation, and a professional but human tone."
        case ToolMode.rewriteBullet.id:
            "Turn the text into concise bullet points. Keep only the important content and remove extra wording."
        default:
            switch tool {
            case .rewrite:
                "Keep the rewrite faithful to the original meaning. Favor natural phrasing over flashy wording."
            case .prompt:
                "Produce prompts that are practical, explicit, and easy to paste into another AI system."
            case .extract:
                "Prefer concise, structured output and avoid inventing facts that are not present in the source text."
            case .reply:
                "Draft replies that feel human, brief, and appropriate to the selected tone."
            }
        }
    }

    var defaultTaskTemplate: String {
        switch id {
        case ToolMode.rewriteClean.id:
            """
            Task: Clean up the text so it reads smoothly.
            Preserve the original tone and almost all of the detail.
            Fix grammar, capitalization, and punctuation.
            Do not make it more formal.
            Return only the cleaned rewrite.
            """
        case ToolMode.rewriteShort.id:
            """
            Task: Rewrite the text in materially fewer words.
            Keep the key message and request.
            Remove filler, repetition, and softeners.
            Prefer one compact sentence when possible.
            Return only the shortened rewrite.
            """
        case ToolMode.rewriteProfessional.id:
            """
            Task: Rewrite the text so it sounds polished and professional.
            Preserve the meaning and request.
            Use complete sentences and clear punctuation.
            Keep it concise and human, not stiff.
            Return only the rewritten message.
            """
        case ToolMode.rewriteBullet.id:
            """
            Task: Convert the text into concise bullet points.
            Keep only the important content.
            Return bullet points only.
            """
        case ToolMode.promptBalanced.id:
            """
            Task: Turn the text into a strong AI prompt.
            Clarify the goal.
            Make the request explicit.
            Add useful output guidance.
            Return only the final prompt.
            """
        case ToolMode.promptDetailed.id:
            """
            Task: Turn the text into a detailed AI prompt.
            Clarify the goal, desired output, important constraints, and relevant context.
            Return only the final prompt.
            """
        case ToolMode.promptConstrained.id:
            """
            Task: Turn the text into an AI prompt with explicit constraints.
            State the task clearly.
            Include brevity and output format guidance.
            Return only the final prompt.
            """
        case ToolMode.promptCreative.id:
            """
            Task: Turn the text into a sharper, more creative AI prompt.
            Keep the request clear but allow more style and voice.
            Return only the final prompt.
            """
        case ToolMode.extractActionItems.id:
            """
            Task: Extract action items from the text.
            Return concise bullet points.
            If no action items are present, return: No action items found.
            """
        case ToolMode.extractKeyPoints.id:
            """
            Task: Extract the key points from the text.
            Return concise bullet points.
            Do not include commentary.
            """
        case ToolMode.extractEntities.id:
            """
            Task: Extract important entities from the text.
            Include people, organizations, roles, products, or places when present.
            Return concise bullet points.
            If none are found, return: No notable entities found.
            """
        case ToolMode.extractDates.id:
            """
            Task: Extract dates, times, and deadlines from the text.
            Return concise bullet points.
            If none are found, return: No dates or times found.
            """
        case ToolMode.replyCasual.id:
            """
            Task: Draft a casual reply to the text.
            Keep it natural and concise.
            Return only the reply.
            """
        case ToolMode.replyProfessional.id:
            """
            Task: Draft a professional reply to the text.
            Keep it polite, clear, and concise.
            Return only the reply.
            """
        case ToolMode.replyConcise.id:
            """
            Task: Draft a very concise reply to the text.
            Use as few words as possible while preserving usefulness.
            Return only the reply.
            """
        case ToolMode.replyWarm.id:
            """
            Task: Draft a warm and thoughtful reply to the text.
            Keep it natural and not overly long.
            Return only the reply.
            """
        default:
            """
            Task: Return a concise transformed version of the text.
            """
        }
    }

    var defaultTemperature: Double {
        switch tool {
        case .rewrite:
            0.2
        case .prompt:
            0.35
        case .extract:
            0.1
        case .reply:
            0.35
        }
    }

    var defaultMaxTokens: Int {
        switch tool {
        case .rewrite:
            120
        case .prompt:
            180
        case .extract:
            120
        case .reply:
            140
        }
    }

    var defaultSeed: Int {
        -1
    }

    var sampleInput: String {
        switch id {
        case ToolMode.rewriteClean.id:
            "hey john just checking if friday still works for the launch review i can move it if needed"
        case ToolMode.rewriteShort.id:
            "I wanted to follow up and see whether we are still aligned on the plan, and if not I can shorten the deck and send a revised version."
        case ToolMode.rewriteProfessional.id:
            "can you send me the numbers by tomorrow morning so i can get this into the board update"
        case ToolMode.rewriteBullet.id:
            "Need to finish the onboarding copy, update the launch checklist, and confirm who owns the release email draft."
        case ToolMode.promptBalanced.id:
            "Help me plan a launch checklist for a small macOS app."
        case ToolMode.promptDetailed.id:
            "Create a prompt for researching competitor menu bar apps and summarizing their strengths."
        case ToolMode.promptConstrained.id:
            "Write a prompt that gets a concise founder update in bullets."
        case ToolMode.promptCreative.id:
            "Turn an app concept into a bold landing page brief."
        case ToolMode.extractActionItems.id:
            "Please send the final copy today, review the install flow tomorrow, and confirm the release date before Friday."
        case ToolMode.extractKeyPoints.id:
            "TextKit is a menu bar app, it runs locally, and we want the first-run experience to guide users through model download."
        case ToolMode.extractEntities.id:
            "Mike met with Sarah Chen from OpenAI and Alex Rivera at Hugging Face in Denver."
        case ToolMode.extractDates.id:
            "Let's meet Thursday at 2pm and send the draft by April 30."
        case ToolMode.replyCasual.id:
            "Hey, just checking whether you're free to review this later today."
        case ToolMode.replyProfessional.id:
            "Thanks for the update. Could you please confirm whether the revised timeline is still on track?"
        case ToolMode.replyConcise.id:
            "Wanted to follow up and see if this still works on your side."
        case ToolMode.replyWarm.id:
            "Thank you for sending this over. I appreciate the context and wanted to check in on next steps."
        default:
            "Sample input"
        }
    }
}
