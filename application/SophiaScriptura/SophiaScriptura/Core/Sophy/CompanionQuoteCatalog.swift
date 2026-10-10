import Foundation

struct CompanionQuoteSeed: Codable, Equatable {
    var book: String
    var chapter: Int
    var startVerse: Int
    var endVerse: Int

    func range(referenceSystemID: String) -> PassageRange {
        MeditationPassageRules.range(
            book: book,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: min(endVerse, startVerse),
            referenceSystemID: referenceSystemID
        )
    }
}

private struct CompanionQuoteBundle: Codable {
    var sophy: [CompanionQuoteSeed]
    var sol: [CompanionQuoteSeed]
    var sabinus: [CompanionQuoteSeed]
}

enum CompanionQuoteCatalog {
    private static let resource = "study-companion-quotes.seed"

    static func seeds(for character: StudyCompanionCharacter) -> [CompanionQuoteSeed] {
        guard let bundle = loadBundle() else { return fallback(for: character) }
        switch character {
        case .sophy: return bundle.sophy
        case .sol: return bundle.sol
        case .sabinus: return bundle.sabinus
        }
    }

    static func nextSeed(for character: StudyCompanionCharacter, excluding last: CompanionQuoteSeed?) -> CompanionQuoteSeed {
        let pool = seeds(for: character)
        guard !pool.isEmpty else { return fallback(for: character).first! }
        if pool.count == 1 { return pool[0] }
        var choice = pool.randomElement()!
        if let last, pool.count > 1 {
            var attempts = 0
            while choice == last, attempts < 6 {
                choice = pool.randomElement()!
                attempts += 1
            }
        }
        return choice
    }

    private static func loadBundle() -> CompanionQuoteBundle? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CompanionQuoteBundle.self, from: data) else { return nil }
        return decoded
    }

    private static func fallback(for character: StudyCompanionCharacter) -> [CompanionQuoteSeed] {
        switch character {
        case .sophy:
            return [
                CompanionQuoteSeed(book: "PRO", chapter: 3, startVerse: 5, endVerse: 5),
                CompanionQuoteSeed(book: "PRO", chapter: 1, startVerse: 7, endVerse: 7)
            ]
        case .sol:
            return [
                CompanionQuoteSeed(book: "ECC", chapter: 3, startVerse: 1, endVerse: 1),
                CompanionQuoteSeed(book: "ECC", chapter: 12, startVerse: 13, endVerse: 13)
            ]
        case .sabinus:
            return [
                CompanionQuoteSeed(book: "JOB", chapter: 1, startVerse: 21, endVerse: 21),
                CompanionQuoteSeed(book: "JOB", chapter: 19, startVerse: 25, endVerse: 25)
            ]
        }
    }
}

enum CompanionQuoteResolver {
    static func resolve(
        seed: CompanionQuoteSeed,
        books: [ScriptureBook],
        referenceSystemID: String,
        repository: any ScriptureContentRepository
    ) async -> StudyCompanionIdleQuote? {
        let range = seed.range(referenceSystemID: referenceSystemID)
        guard let lines = try? await MeditationPassageResolver.displayLines(for: range, repository: repository) else { return nil }
        let text = lines.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let reference = ActivityPassageLabel.text(range, books: books)
        return StudyCompanionIdleQuote(reference: reference, text: text)
    }
}
