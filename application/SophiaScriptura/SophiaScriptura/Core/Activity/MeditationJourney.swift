import Foundation

struct MeditationJourneyLaunch: Equatable, Sendable {
    var referenceSystemID: String
    var editionID: String?
    /// When nil, the journey uses seven curated passages from the bundled catalog.
    var chosenRange: PassageRange?
}

enum MeditationPassageRules {
    static func clampedEndVerse(start: Int, proposedEnd: Int, available: [Int]) -> Int {
        guard available.contains(start) else { return available.first ?? proposedEnd }
        let maxEnd = start + 1
        let capped = min(max(proposedEnd, start), maxEnd)
        if available.contains(capped) { return capped }
        if available.contains(start) { return start }
        return available.last ?? capped
    }

    static func range(
        book: String,
        chapter: Int,
        startVerse: Int,
        endVerse: Int,
        referenceSystemID: String
    ) -> PassageRange {
        let start = VerseID(referenceSystemID: referenceSystemID, book: book, chapter: chapter, verse: startVerse)
        let end = VerseID(referenceSystemID: referenceSystemID, book: book, chapter: chapter, verse: max(startVerse, endVerse))
        return PassageRange(start: start, end: end)
    }

    static func verseCount(in range: PassageRange) -> Int {
        guard range.start.book == range.end.book,
              range.start.chapter == range.end.chapter else { return 2 }
        return max(1, range.end.verse - range.start.verse + 1)
    }
}

struct MeditationSeedPassage: Codable, Equatable {
    var book: String
    var chapter: Int
    var startVerse: Int
    var endVerse: Int

    func range(referenceSystemID: String) -> PassageRange {
        MeditationPassageRules.range(
            book: book,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: min(endVerse, startVerse + 1),
            referenceSystemID: referenceSystemID
        )
    }
}

enum MeditationPassageCatalog {
    private static let resource = "meditation-passages.seed"

    static func bundled(referenceSystemID: String) -> [PassageRange] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let seeds = try? JSONDecoder().decode([MeditationSeedPassage].self, from: data),
              !seeds.isEmpty else {
            return fallback(referenceSystemID: referenceSystemID)
        }
        return seeds.map { $0.range(referenceSystemID: referenceSystemID) }
    }

    static func randomSeven(referenceSystemID: String) -> [PassageRange] {
        Array(bundled(referenceSystemID: referenceSystemID).shuffled().prefix(7))
    }

    private static func fallback(referenceSystemID: String) -> [PassageRange] {
        [
            MeditationSeedPassage(book: "PSA", chapter: 23, startVerse: 1, endVerse: 1),
            MeditationSeedPassage(book: "PSA", chapter: 46, startVerse: 10, endVerse: 10),
            MeditationSeedPassage(book: "JHN", chapter: 3, startVerse: 16, endVerse: 17),
            MeditationSeedPassage(book: "PHP", chapter: 4, startVerse: 6, endVerse: 7),
            MeditationSeedPassage(book: "ISA", chapter: 41, startVerse: 10, endVerse: 10),
            MeditationSeedPassage(book: "MAT", chapter: 11, startVerse: 28, endVerse: 28),
            MeditationSeedPassage(book: "ROM", chapter: 8, startVerse: 38, endVerse: 39),
            MeditationSeedPassage(book: "JOS", chapter: 1, startVerse: 9, endVerse: 9),
            MeditationSeedPassage(book: "1PE", chapter: 5, startVerse: 7, endVerse: 7),
            MeditationSeedPassage(book: "COL", chapter: 3, startVerse: 15, endVerse: 15),
        ].map { $0.range(referenceSystemID: referenceSystemID) }
    }
}

struct MeditationScriptureLine: Equatable, Sendable {
    /// Inline superscript verse number; nil when the reference label already identifies a single verse.
    var verseNumber: Int?
    var text: String
}

enum MeditationPassageResolver {
    static func displayLines(
        for range: PassageRange,
        repository: any ScriptureContentRepository
    ) async throws -> [MeditationScriptureLine] {
        guard range.start.book == range.end.book,
              range.start.chapter == range.end.chapter else {
            throw ScriptureError.passageUnmapped
        }
        let document = try await repository.chapter(book: range.start.book, number: range.start.chapter)
        let lower = range.start.verse
        let upper = range.end.verse
        guard document.verseNumbers.contains(lower), document.verseNumbers.contains(upper) else {
            throw ScriptureError.passageUnmapped
        }
        if lower == upper {
            let body = document.body(for: lower)
            guard !body.isEmpty else { return [] }
            return [MeditationScriptureLine(verseNumber: nil, text: body)]
        }
        return (lower...upper).compactMap { verse in
            let body = document.body(for: verse)
            return body.isEmpty ? nil : MeditationScriptureLine(verseNumber: verse, text: body)
        }
    }
}

struct MeditationJourneyPage: Identifiable, Equatable {
    enum Kind: Equatable {
        case intro
        case scripture(reference: String, lines: [MeditationScriptureLine])
        case closing
        case exit
    }

    let id: Int
    let kind: Kind
}

enum MeditationJourneyBuilder {
    static func pages(
        launch: MeditationJourneyLaunch,
        books: [ScriptureBook],
        resolved: [(PassageRange, [MeditationScriptureLine])]
    ) -> [MeditationJourneyPage] {
        var result: [MeditationJourneyPage] = [.init(id: 0, kind: .intro)]
        for (offset, item) in resolved.enumerated() {
            let label = ActivityPassageLabel.text(item.0, books: books)
            result.append(.init(id: offset + 1, kind: .scripture(reference: label, lines: item.1)))
        }
        let closingID = result.count
        result.append(.init(id: closingID, kind: .closing))
        result.append(.init(id: closingID + 1, kind: .exit))
        return result
    }

    static func ranges(for launch: MeditationJourneyLaunch) -> [PassageRange] {
        if let chosen = launch.chosenRange {
            return [chosen]
        }
        return MeditationPassageCatalog.randomSeven(referenceSystemID: launch.referenceSystemID)
    }
}
