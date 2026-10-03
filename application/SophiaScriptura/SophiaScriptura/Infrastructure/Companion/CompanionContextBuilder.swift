import Foundation

/// Builds the provider-facing turn list from pinned preset and local conversation history.
enum CompanionContextBuilder {
    static let maxTurnCharacters = 24_000
    static let markdownResponseInstruction = """
    Output contract (required): Every assistant reply MUST be valid Markdown, never a single unbroken paragraph or single line of plain text.

    Line breaks (critical):
    - The app previews standard Markdown. Use actual newline characters, not literal escaped \\n sequences in the response text.
    - Start a new paragraph with a blank line: two real newline characters in your output.
    - Put a blank line before every heading and before every bullet or numbered list.
    - Do not glue sentences, headings, or list items together without blank lines between blocks.
    - Never place a period, question mark, or exclamation point directly against the next word (write ". The" not ".The").
    - Never place a bold section title immediately after a period without a blank line before the opening **.

    Markdown structure:
    - Use ## or ### for section headings (with a space after the hashes), for example: ### Main idea
    - Use **bold** sparingly for key terms.
    - Keep each opening and closing ** pair in the same paragraph or list item.
    - Use - or 1. lists when they improve clarity.
    - Do not wrap the entire response in one code block.

    Example shape:
    ### Main idea
    First short paragraph.

    ### Context
    Second paragraph with **key term** emphasized.

    ### Application
    - First point
    - Second point
    """

    static let studyScopeGuardrail = """
    Study scope: This Companion serves Bible study, Christian theology, religion, spirituality, and discipleship centered on Jesus Christ. When a message is clearly unrelated to Scripture, faith, church life, or Christian formation (for example general trivia, entertainment, secular business or tech tasks, politics, or lifestyle advice with no study connection), do not fulfill the off-topic request. Briefly explain the limit, warmly invite a Bible or faith question, and point the user to Jesus Christ as the heart of this app. Keep redirection concise. When a message mixes off-topic and on-topic parts, answer only the on-topic parts and note the limit.
    """

    static func completionRequest(
        conversation: CompanionConversation,
        messages: [CompanionMessage],
        attachments: [CompanionAttachment],
        pendingUserText: String
    ) -> LLMCompletionRequest {
        let ordered = messages
            .filter { $0.conversationID == conversation.id }
            .sorted { $0.sequence < $1.sequence }

        var turns: [LLMChatTurn] = []
        var budget = maxTurnCharacters

        for message in ordered.reversed() {
            guard message.deliveryState == .complete || message.role == .user else { continue }
            let text = (message.providerContent ?? message.content).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            guard text.count <= budget else { break }
            budget -= text.count
            turns.insert(LLMChatTurn(role: message.role, content: text), at: 0)
        }

        let userText = pendingUserText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userText.isEmpty {
            turns.append(LLMChatTurn(role: .user, content: userText))
        }

        var instruction = conversation.presetSnapshot.resolvedInstruction
        instruction += "\n\n\(studyScopeGuardrail)"
        instruction += "\n\nResponse format:\n\(markdownResponseInstruction)"
        instruction += "\n\n\(CompanionResponseFormatting.sourcesAppendixInstruction)"
        let attachmentNotes = attachments
            .filter { $0.conversationID == conversation.id }
            .map { attachment -> String in
                switch attachment.disclosure {
                case .referenceOnly:
                    return "Attached passage reference (reference only): \(attachment.referenceLabel)"
                case .textTransmitted:
                    return "Attached passage \(attachment.referenceLabel): \(attachment.payload ?? "")"
                case .localOnly:
                    return "Attached local context: \(attachment.referenceLabel)"
                }
            }
        if !attachmentNotes.isEmpty {
            instruction += "\n\nExplicit attachments for this conversation:\n" + attachmentNotes.joined(separator: "\n")
        }

        return LLMCompletionRequest(
            modelID: conversation.modelID,
            systemInstruction: instruction,
            turns: turns
        )
    }

    static func invalidateSummaries(in summaries: inout [ContextSummary], deletedMessageIDs: Set<UUID>) {
        summaries.removeAll { summary in
            summary.sourceMessageIDs.contains(where: deletedMessageIDs.contains)
        }
    }
}
