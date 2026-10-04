import Foundation

enum CompanionStudySources {
    static func passageSource(for conversation: CompanionConversation) -> CompanionSource? {
        let book = conversation.passageAnchor?.bookID ?? conversation.chapterAnchor?.bookID
        let chapter = conversation.passageAnchor?.chapter ?? conversation.chapterAnchor?.chapter
        let edition = conversation.passageAnchor?.editionID ?? conversation.chapterAnchor?.editionID
        let reference = conversation.passageAnchor?.referenceLabel ?? conversation.chapterAnchor?.referenceLabel
        guard let book, let chapter, let reference else { return nil }
        var url: String?
        if edition == "web.engwebp", book.range(of: #"^[A-Z0-9]{3}$"#, options: .regularExpression) != nil,
           (1...150).contains(chapter) {
            let number = String(format: book == "PSA" ? "%03d" : "%02d", chapter)
            url = "https://ebible.org/engwebp/\(book)\(number).htm"
        }
        return CompanionSource(title: reference, authorOrPublisher: edition == "web.engwebp" ? "World English Bible · eBible.org" : nil,
                               url: url, retrievalProvider: "attached-scripture",
                               claim: "Passage selected for this conversation. This link does not verify the model's interpretation.")
    }

    static func lookupURL(for source: CompanionSource) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: [source.title, source.authorOrPublisher].compactMap { $0 }.joined(separator: " "))]
        return components?.url
    }

    static func provenanceLabel(for source: CompanionSource) -> String {
        switch source.retrievalProvider {
        case "attached-scripture": return "Selected Scripture"
        case "model-bibliography", "model-link": return "Model reference · not verified"
        default: return "Provider source"
        }
    }
}
