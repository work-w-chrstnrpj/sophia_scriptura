import Foundation

enum ScriptureVerseText {
    static func appendFragment(_ fragment: String, to text: inout String) {
        guard !fragment.isEmpty else { return }
        if let last = text.last, let first = fragment.first, shouldInsertSpace(after: last, before: first) {
            text.append(" ")
        }
        text.append(fragment)
    }

    static func shouldInsertSpace(after left: Character, before right: Character) -> Bool {
        if left.isWhitespace || right.isWhitespace { return false }
        if left == "\n" || right == "\n" { return false }
        if ";:,.".contains(left) && (right.isLetter || right.isNumber) { return true }
        if left.isLetter && right.isLetter { return true }
        if left.isNumber && right.isLetter { return true }
        if left.isLetter && right.isNumber { return true }
        return false
    }
}
