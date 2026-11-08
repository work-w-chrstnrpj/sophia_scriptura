import Foundation

enum CompanionConversationTitle {
    static let untitled = "New conversation"
    private static let limit = 72

    static func fromQuestion(_ question: String) -> String {
        let title = question.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !title.isEmpty else { return untitled }
        guard title.count > limit else { return title }
        let clipped = title.prefix(limit - 1)
        let boundary = title.dropFirst(clipped.count).first
        if boundary != " ", let space = clipped.lastIndex(of: " "), space > clipped.startIndex {
            return String(clipped[..<space]) + "…"
        }
        return String(clipped) + "…"
    }
}
