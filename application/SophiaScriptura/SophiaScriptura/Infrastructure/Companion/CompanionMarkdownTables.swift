import Foundation

struct CompanionMarkdownTable: Equatable {
    var headers: [String]
    var rows: [[String]]
}

enum CompanionMarkdownTableParser {
    enum Segment: Equatable {
        case prose(String)
        case table(CompanionMarkdownTable)
    }

    static func containsTable(_ markdown: String) -> Bool {
        segments(from: markdown).contains {
            if case .table = $0 { return true }
            return false
        }
    }

    static func segments(from markdown: String) -> [Segment] {
        guard !markdown.isEmpty else { return [] }
        let lines = markdown.components(separatedBy: .newlines)
        var output: [Segment] = []
        var prose: [String] = []
        var index = 0

        func flushProse() {
            guard !prose.isEmpty else { return }
            let joined = prose.joined(separator: "\n")
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                output.append(.prose(joined))
            }
            prose = []
        }

        while index < lines.count {
            let line = lines[index]
            guard isTableRow(line) else {
                prose.append(line)
                index += 1
                continue
            }
            var tableLines: [String] = []
            while index < lines.count, isTableRow(lines[index]) {
                tableLines.append(lines[index])
                index += 1
            }
            guard let table = table(from: tableLines) else {
                prose.append(contentsOf: tableLines)
                continue
            }
            flushProse()
            output.append(.table(table))
        }
        flushProse()
        return output
    }

    private static func table(from lines: [String]) -> CompanionMarkdownTable? {
        guard lines.count >= 2 else { return nil }
        let parsed = lines.map(splitTableRow)
        guard parsed.allSatisfy({ $0.count >= 2 }) else { return nil }
        let columnCount = parsed.map(\.count).max() ?? 0
        guard columnCount >= 2 else { return nil }

        func normalized(_ cells: [String]) -> [String] {
            var row = cells
            while row.count < columnCount { row.append("") }
            if row.count > columnCount { row = Array(row.prefix(columnCount)) }
            return row
        }

        if isSeparatorRow(lines[1]) {
            return CompanionMarkdownTable(
                headers: normalized(parsed[0]),
                rows: parsed.dropFirst(2).map(normalized)
            )
        }
        return CompanionMarkdownTable(headers: [], rows: parsed.map(normalized))
    }

    static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        return splitTableRow(trimmed).count >= 2
    }

    static func isSeparatorRow(_ line: String) -> Bool {
        let cells = splitTableRow(line)
        guard cells.count >= 2 else { return false }
        return cells.allSatisfy { cell in
            let stripped = cell.replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
            return !stripped.isEmpty && stripped.allSatisfy { $0 == "-" }
        }
    }

    static func splitTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
