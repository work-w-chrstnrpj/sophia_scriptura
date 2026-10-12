import Foundation

struct SophyScriptureNavigationRequest: Equatable, Sendable {
    var book: String
    var chapter: Int
    var verse: Int
    var editionAbbreviation: String?
    var referenceLabel: String
}

enum SophyScriptureNavigationParser {
    private static let translationPattern = #"(?i)\b(WEBP?|NIV|NKJV|NASB|NLT|ESV|BSB)\b"#
    private static let referencePattern = #"(?i)\b(\d+)\s*:\s*(\d+)\b"#
    private static let chapterPattern = #"(?i)\bchapter\s+(\d+)\b"#

    static func parse(_ text: String, books: [ScriptureBook]) -> SophyScriptureNavigationRequest? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        let mentionsScripture = lower.contains("scripture") || lower.contains(" bible") || lower.hasSuffix("bible")
        let navigationCue = ["take me to", "go to", "open ", "let me view", "show me", "view "].contains { lower.contains($0) }
        guard mentionsScripture || navigationCue else { return nil }

        guard let book = resolveBook(in: trimmed, books: books) else { return nil }
        let edition = translationAbbreviation(in: trimmed)
        var chapter = 1
        var verse = 1
        if let match = trimmed.range(of: referencePattern, options: .regularExpression) {
            let slice = String(trimmed[match])
            let numbers = slice.split { !$0.isNumber }.compactMap { Int($0) }
            if numbers.count >= 2 {
                chapter = numbers[0]
                verse = numbers[1]
            }
        } else if let match = trimmed.range(of: chapterPattern, options: .regularExpression) {
            let slice = String(trimmed[match])
            if let number = slice.split(whereSeparator: { !$0.isNumber }).compactMap({ Int($0) }).last {
                chapter = number
            }
        }

        guard chapter > 0, verse > 0 else { return nil }
        let title = books.first(where: { $0.id == book })?.title ?? book
        let reference = verse > 0 && chapter > 0 ? "\(title) \(chapter):\(verse)" : title
        return SophyScriptureNavigationRequest(
            book: book,
            chapter: chapter,
            verse: verse,
            editionAbbreviation: edition,
            referenceLabel: reference
        )
    }

    static func resolveBook(in text: String, books: [ScriptureBook]) -> String? {
        let lower = text.lowercased()
        if let bookOfRange = lower.range(of: "book of") {
            let tail = String(lower[bookOfRange.upperBound...])
            if let match = matchTitle(tail, books: books) { return match }
        }
        for book in books.sorted(by: { $0.title.count > $1.title.count }) {
            if lower.contains(book.title.lowercased()) { return book.id }
        }
        let tokens = lower.split { !$0.isLetter }.map(String.init)
        for token in tokens where token.count >= 3 {
            if let match = books.first(where: { $0.title.lowercased() == token || $0.id.lowercased() == token }) {
                return match.id
            }
        }
        return nil
    }

    private static func matchTitle(_ fragment: String, books: [ScriptureBook]) -> String? {
        let cleaned = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = books.first(where: { $0.title.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) {
            return exact.id
        }
        return books.sorted(by: { $0.title.count > $1.title.count }).first {
            cleaned.localizedCaseInsensitiveContains($0.title.lowercased()) || $0.title.localizedCaseInsensitiveContains(cleaned)
        }?.id
    }

    private static func translationAbbreviation(in text: String) -> String? {
        guard let range = text.range(of: translationPattern, options: .regularExpression) else { return nil }
        let raw = String(text[range]).uppercased()
        return raw == "WEBP" ? "WEB" : raw
    }
}
