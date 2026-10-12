import Foundation

enum ReadingWorkflowEndSuggestion {
    struct Location: Equatable {
        var book: String
        var chapter: Int
        var verse: Int
    }

    /// Suggests an ending passage when finishing guided Reading from the reader's current chapter.
    /// Falls back to the start location when the reader is in another book or an earlier chapter.
    static func suggestedEnd(
        start: VerseID,
        readerBook: String?,
        readerChapter: Int?
    ) -> Location {
        let fallback = Location(book: start.book, chapter: start.chapter, verse: start.verse)
        guard let readerBook, let readerChapter else { return fallback }
        guard readerBook == start.book, readerChapter >= start.chapter else { return fallback }
        let verse = readerChapter == start.chapter ? start.verse : 1
        return Location(book: readerBook, chapter: readerChapter, verse: verse)
    }
}
