import Foundation

enum CompanionPassageReference {
    static func label(bookTitle: String, chapter: Int, startVerse: Int, endVerse: Int) -> String {
        if startVerse == endVerse {
            return "\(bookTitle) \(chapter):\(startVerse)"
        }
        return "\(bookTitle) \(chapter):\(startVerse)–\(endVerse)"
    }
}
