import Foundation

/// How a collection arranges its subfolders. Automatic applies Smart Order when it
/// recognizes a pattern, such as Bible books or numbered names. Name stays alphabetical.
enum CollectionSubfolderArrange: String, CaseIterable, Identifiable {
    case automatic
    case smart
    case name
    case modified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .smart: return "Smart Order"
        case .name: return "Name"
        case .modified: return "Recently modified"
        }
    }

    /// Earlier builds stored this choice as "bible".
    static func stored(_ raw: String) -> Self {
        if raw == "bible" { return .smart }
        return Self(rawValue: raw) ?? .automatic
    }
}

/// Smart Order for collection folders. Recognized Bible books and testaments follow
/// reading order. Every other name uses number-aware order, so “Chapter 2” stays before
/// “Chapter 10”. The bundled Protestant book sequence is the fallback. A loaded edition
/// catalog wins when a folder name matches one of its books.
enum BibleCollectionOrder {
    private static let oldTestamentRank = 0
    private static let apocryphaRank = 1
    private static let newTestamentRank = 2

    private static let aliases: [String: Int] = {
        var table: [String: Int] = [:]
        for (offset, names) in bookNames.enumerated() {
            for name in names {
                table[name] = (offset + 1) * 10
            }
        }
        // After Malachi (390) and before Matthew (400).
        for (offset, names) in deuterocanonicalNames.enumerated() {
            for name in names {
                table[name] = 391 + offset
            }
        }
        return table
    }()

    static func prefersScriptureOrder(parentName: String, childNames: [String], books: [ScriptureBook] = []) -> Bool {
        let recognized = childNames.filter { rank(for: $0, books: books) != nil }
        guard !recognized.isEmpty else { return false }
        if isScriptureContainer(parentName) { return true }
        return recognized.count >= 2 && recognized.count * 2 >= childNames.count
    }

    static func prefersNumberOrder(_ names: [String]) -> Bool {
        names.contains { $0.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) } }
    }

    static func sorted<T>(_ items: [T], name: (T) -> String, books: [ScriptureBook] = [], scripture: Bool = true) -> [T] {
        items.sorted { lhs, rhs in
            comesBefore(name(lhs), name(rhs), books: books, scripture: scripture)
        }
    }

    private static func comesBefore(_ lhs: String, _ rhs: String, books: [ScriptureBook], scripture: Bool) -> Bool {
        if scripture {
            switch (rank(for: lhs, books: books), rank(for: rhs, books: books)) {
            case let (left?, right?) where left != right:
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                break
            }
        }
        return naturalAscending(lhs, rhs)
    }

    /// Numbers compare as whole values. “2” comes before “10”, then the remaining text decides.
    static func naturalAscending(_ lhs: String, _ rhs: String) -> Bool {
        let left = chunks(lhs)
        let right = chunks(rhs)
        let count = min(left.count, right.count)
        for index in 0..<count {
            switch (left[index], right[index]) {
            case let (.number(leftValue), .number(rightValue)) where leftValue != rightValue:
                return leftValue < rightValue
            case let (.text(leftText), .text(rightText)):
                let order = leftText.localizedCaseInsensitiveCompare(rightText)
                if order != .orderedSame { return order == .orderedAscending }
            case (.number, .text):
                return true
            case (.text, .number):
                return false
            default:
                break
            }
        }
        if left.count != right.count { return left.count < right.count }
        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private enum Chunk {
        case text(String)
        case number(Int)
    }

    private static func chunks(_ name: String) -> [Chunk] {
        var result: [Chunk] = []
        var text = ""
        var digits = ""
        func flushText() {
            guard !text.isEmpty else { return }
            result.append(.text(text))
            text = ""
        }
        func flushDigits() {
            guard let value = Int(digits) else { return }
            result.append(.number(value))
            digits = ""
        }
        for character in name {
            if character.isNumber {
                flushText()
                digits.append(character)
            } else {
                flushDigits()
                text.append(character)
            }
        }
        flushText()
        flushDigits()
        return result
    }

    static func rank(for name: String, books: [ScriptureBook] = []) -> Int? {
        let key = normalize(name)
        if let section = sectionRank(key) { return section }
        if let match = books.first(where: { normalize($0.title) == key }) {
            return match.order * 10
        }
        return aliases[key]
    }

    static func isScriptureContainer(_ name: String) -> Bool {
        let key = normalize(name)
        return key == "bible" || sectionRank(key) != nil
    }

    private static func sectionRank(_ key: String) -> Int? {
        switch key {
        case "old testament", "ot", "hebrew bible", "hebrew scriptures":
            return oldTestamentRank
        case "apocrypha", "deuterocanonical", "deuterocanon":
            return apocryphaRank
        case "new testament", "nt":
            return newTestamentRank
        default:
            return nil
        }
    }

    static func normalize(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
        let cleaned = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        var words = String(cleaned).split(whereSeparator: \.isWhitespace).map(String.init)
        if words.first == "the" { words.removeFirst() }
        if let first = words.first, let number = leadingNumber(first) {
            words[0] = number
        }
        var key = words.joined(separator: " ")
        switch key {
        case "psalm":
            key = "psalms"
        case "song of songs", "canticles", "canticle of canticles":
            key = "song of solomon"
        case "revelations", "revelation of john", "apocalypse":
            key = "revelation"
        default:
            break
        }
        return key
    }

    private static func leadingNumber(_ word: String) -> String? {
        switch word {
        case "first", "1st", "i": return "1"
        case "second", "2nd", "ii": return "2"
        case "third", "3rd", "iii": return "3"
        default: return nil
        }
    }

    /// Protestant 66, in reading order. Each entry lists the folder names that mean that book.
    private static let bookNames: [[String]] = [
        ["genesis"], ["exodus"], ["leviticus"], ["numbers"], ["deuteronomy"],
        ["joshua"], ["judges"], ["ruth"],
        ["1 samuel"], ["2 samuel"], ["1 kings"], ["2 kings"],
        ["1 chronicles"], ["2 chronicles"],
        ["ezra"], ["nehemiah"], ["esther"],
        ["job"], ["psalms"], ["proverbs"], ["ecclesiastes"], ["song of solomon"],
        ["isaiah"], ["jeremiah"], ["lamentations"], ["ezekiel"], ["daniel"],
        ["hosea"], ["joel"], ["amos"], ["obadiah"], ["jonah"], ["micah"], ["nahum"],
        ["habakkuk"], ["zephaniah"], ["haggai"], ["zechariah"], ["malachi"],
        ["matthew"], ["mark"], ["luke"], ["john"], ["acts"], ["romans"],
        ["1 corinthians"], ["2 corinthians"], ["galatians"], ["ephesians"], ["philippians"],
        ["colossians"], ["1 thessalonians"], ["2 thessalonians"],
        ["1 timothy"], ["2 timothy"], ["titus"], ["philemon"],
        ["hebrews"], ["james"], ["1 peter"], ["2 peter"],
        ["1 john"], ["2 john"], ["3 john"], ["jude"], ["revelation"]
    ]

    /// Placed after Malachi and before Matthew when the loaded edition has no order of its own.
    private static let deuterocanonicalNames: [[String]] = [
        ["tobit"], ["judith"], ["wisdom", "wisdom of solomon"], ["sirach", "ecclesiasticus"],
        ["baruch"], ["1 maccabees"], ["2 maccabees"], ["3 maccabees"], ["4 maccabees"]
    ]
}
