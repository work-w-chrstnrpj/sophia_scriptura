import Foundation

enum SophyFolderIntentParser {
    private static let createPattern = #"(?i)\b(create|make|add|new)\b.{0,40}\bfolders?\b"#

    static func parse(_ text: String) -> [SophyFolderNodeDraft]? {
        guard text.range(of: createPattern, options: .regularExpression) != nil else { return nil }
        guard let name = extractName(from: text) else { return nil }
        return nodes(named: name)
    }

    static func nodes(named rawName: String) -> [SophyFolderNodeDraft]? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 120 else { return nil }
        if name.localizedCaseInsensitiveCompare("No Folder") == .orderedSame { return nil }
        let key = slug(name)
        let description = "This folder is notes about \(name)."
        return [SophyFolderNodeDraft(key: key, parentKey: nil, name: name, description: description)]
    }

    private static func extractName(from text: String) -> String? {
        let patterns = [
            #"(?i)(?:called|named)\s+"([^"]{1,120})""#,
            #"(?i)(?:called|named)\s+'([^']{1,120})'"#,
            #"(?i)(?:called|named)\s+([^,.;\n]{1,120})"#,
            #"(?i)\bfolder\s+(?:for|about)\s+([^,.;\n]{1,120})"#,
        ]
        for pattern in patterns {
            if let capture = firstCapture(in: text, pattern: pattern) {
                let trimmed = capture.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[capture])
    }

    private static func slug(_ name: String) -> String {
        let lowered = name.lowercased()
        let allowed = lowered.map { character -> Character in
            if character.isLetter || character.isNumber { return character }
            if character == " " || character == "-" { return "-" }
            return "-"
        }
        let collapsed = String(allowed)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = collapsed.isEmpty ? "folder" : collapsed
        return String(base.prefix(40))
    }
}
