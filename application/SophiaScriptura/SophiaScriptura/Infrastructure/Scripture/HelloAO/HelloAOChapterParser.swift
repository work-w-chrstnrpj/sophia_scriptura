import Foundation
import CryptoKit

enum HelloAOChapterParser {
    static func parse(_ wire: HelloAOChapterWire, eligible: HelloAOEligibleEdition) throws -> ChapterDocument {
        guard wire.translation.id == eligible.providerEditionID,
              wire.book.id.count >= 3,
              wire.chapter.number > 0 else { throw HelloAOError.invalidResponse }

        let referenceSystemID = ScriptureReferenceIdentity.referenceSystemID(forEditionID: eligible.appEditionID) ?? ""
        let revision = wire.translation.sha256 ?? "provider-unversioned"
        let edition = ScriptureEdition(
            id: eligible.appEditionID,
            referenceSystemID: referenceSystemID,
            contentRevision: revision,
            name: eligible.name,
            abbreviation: eligible.abbreviation,
            attribution: eligible.attribution
        )

        var blocks: [ScriptureBlock] = []
        var label = ""
        var verses: [Int] = []
        var blockIndex = 0
        let chapterID = "\(wire.book.id).\(wire.chapter.number)"

        func append(
            kind: String,
            text: String,
            style: String,
            poetryLevel: Int? = nil,
            wordsOfJesus: Bool? = nil,
            sourceNoteID: String? = nil,
            sourceCaller: String? = nil
        ) {
            blocks.append(
                ScriptureBlock(
                    id: "\(chapterID).\(blockIndex)",
                    kind: kind,
                    text: text,
                    label: label,
                    verses: verses,
                    style: style,
                    poetryLevel: poetryLevel,
                    wordsOfJesus: wordsOfJesus,
                    sourceNoteID: sourceNoteID,
                    sourceCaller: sourceCaller
                )
            )
            blockIndex += 1
        }

        func render(_ pieces: [HelloAOContentPiece]) -> (text: String, wordsOfJesus: Bool) {
            var text = ""
            var woj = false
            for piece in pieces {
                switch piece {
                case .text(let value):
                    text += value
                case .noteId:
                    break
                case .lineBreak:
                    if !text.isEmpty { text += "\n" }
                case .formatted(let formatted):
                    if formatted.lineBreak == true, !text.isEmpty { text += "\n" }
                    if let value = formatted.text { text += value }
                    if formatted.wordsOfJesus == true { woj = true }
                }
            }
            return (text, woj)
        }

        for item in wire.chapter.content {
            switch item.type {
            case "heading", "hebrew_subtitle", "subtitle":
                let previousLabel = label
                let previousVerses = verses
                label = ""
                verses = []
                let rendered = render(item.content ?? [])
                let style = item.type == "hebrew_subtitle" ? "hebrew_subtitle" : "s"
                append(kind: "heading", text: rendered.text, style: style)
                label = previousLabel
                verses = previousVerses
            case "line_break":
                append(kind: "break", text: "", style: "b")
            case "verse":
                guard let number = item.number, number > 0, number < 1000 else { throw HelloAOError.invalidResponse }
                label = String(number)
                verses = [number]
                append(kind: "label", text: label, style: "v")
                let rendered = render(item.content ?? [])
                if !rendered.text.isEmpty {
                    append(kind: "body", text: rendered.text, style: "p", wordsOfJesus: rendered.wordsOfJesus ? true : nil)
                }
            default:
                throw HelloAOError.invalidResponse
            }
        }

        if let footnotes = wire.chapter.footnotes {
            for note in footnotes {
                append(
                    kind: "note",
                    text: note.text,
                    style: "f",
                    sourceNoteID: String(note.noteId),
                    sourceCaller: note.caller
                )
            }
        }

        let document = ChapterDocument(
            schemaVersion: 1,
            editionID: edition.id,
            contentRevision: edition.contentRevision,
            book: wire.book.id,
            chapter: wire.chapter.number,
            blocks: blocks,
            storedReferenceSystemID: referenceSystemID
        )
        guard !document.verseNumbers.isEmpty,
              document.verseNumbers.allSatisfy({ verse in blocks.contains { $0.kind == "label" && $0.verses.contains(verse) } })
        else { throw HelloAOError.invalidResponse }
        _ = edition
        return document
    }

    static func books(from wire: HelloAOBooksWire, eligible: HelloAOEligibleEdition) throws -> [ScriptureBook] {
        guard wire.books.count == eligible.expectedBookCount else { throw HelloAOError.invalidResponse }
        return try wire.books.enumerated().map { index, row in
            guard let count = row.numberOfChapters, count > 0 else { throw HelloAOError.invalidResponse }
            let title = row.commonName ?? row.name ?? row.id
            return ScriptureBook(
                id: row.id,
                title: title,
                testament: HelloAOBooks.testament(bookIndex: index, totalBooks: wire.books.count, bookID: row.id),
                order: row.order ?? (index + 1),
                chapterCount: count
            )
        }
    }

    static func chapterInventory(from books: [ScriptureBook]) -> [String] {
        books.flatMap { book in (1...book.chapterCount).map { "\(book.id).\($0)" } }
    }

    static func digest(_ document: ChapterDocument) -> String {
        let canonical = (try? JSONEncoder().encode(document)) ?? Data()
        return SHA256.hash(data: canonical).compactMap { String(format: "%02x", $0) }.joined()
    }
}
