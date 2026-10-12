import Foundation

struct HelloAOEditionRepository: ScriptureContentRepository {
    let store: HelloAOStore
    let providerEditionID: String
    let manifest: HelloAOInstalledManifest

    func edition() async throws -> ScriptureEdition { manifest.edition }

    func books() async throws -> [ScriptureBook] { manifest.books }

    func chapter(book: String, number: Int) async throws -> ChapterDocument {
        try await store.chapter(providerEditionID: providerEditionID, book: book, number: number)
    }

    func resolve(_ range: PassageRange) async throws -> [ScriptureBlock] {
        let edition = manifest.edition
        guard range.start.referenceSystemID == edition.referenceSystemID,
              range.end.referenceSystemID == edition.referenceSystemID else { throw ScriptureError.passageUnmapped }
        let books = manifest.books
        guard let startBook = books.first(where: { $0.id == range.start.book }),
              let endBook = books.first(where: { $0.id == range.end.book }),
              (startBook.order, range.start.chapter, range.start.verse) <= (endBook.order, range.end.chapter, range.end.verse),
              range.start.chapter > 0, range.end.chapter > 0,
              range.start.verse > 0, range.end.verse > 0 else { throw ScriptureError.passageUnmapped }
        var result: [ScriptureBlock] = []
        for book in books where book.order >= startBook.order && book.order <= endBook.order {
            let firstChapter = book.id == startBook.id ? range.start.chapter : 1
            let lastChapter = book.id == endBook.id ? range.end.chapter : book.chapterCount
            guard firstChapter <= lastChapter, lastChapter <= book.chapterCount else { throw ScriptureError.passageUnmapped }
            for chapterNumber in firstChapter...lastChapter {
                let document = try await chapter(book: book.id, number: chapterNumber)
                let lower = book.id == startBook.id && chapterNumber == range.start.chapter ? range.start.verse : 1
                let upper = book.id == endBook.id && chapterNumber == range.end.chapter ? range.end.verse : Int.max
                result += document.blocks.filter { $0.kind == "body" && $0.verses.contains { lower...upper ~= $0 } }
            }
        }
        return result
    }
}
