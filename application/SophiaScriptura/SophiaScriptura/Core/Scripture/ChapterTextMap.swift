import Foundation

/// UTF-16 mapping is constructed from typed source blocks, never by finding repeated prose.
struct ChapterTextMap {
    struct Run {
        let block: ScriptureBlock
        let range: NSRange
    }
    let document: ChapterDocument
    let text: String
    let runs: [Run]

    init(document: ChapterDocument) {
        self.document = document
        var text = ""
        var runs: [Run] = []
        for block in document.blocks {
            let value: String
            switch block.kind {
            case "break": value = text.hasSuffix("\n") || text.isEmpty ? "" : "\n"
            case "label": value = (text.isEmpty || text.hasSuffix("\n") || text.hasSuffix(" ") ? "" : " ") + block.text + " "
            case "note": value = " ⓘ "
            case "heading": value = "\n" + block.text + "\n"
            default: value = (block.style == "qs" ? " " : "") + block.text
            }
            runs.append(Run(block: block, range: NSRange(location: text.utf16.count, length: value.utf16.count)))
            text += value
        }
        self.text = text; self.runs = runs
    }

    struct Selection {
        let text: String
        let editionID: String
        let contentRevision: String
        let sourceLabels: [String]
        let passages: [PassageRange]
    }
    func selection(in range: NSRange) -> Selection {
        let source = text as NSString
        var value = ""
        var separator = ""
        var labels: [String] = []
        var verses: [Int] = []
        for run in runs {
            let intersection = NSIntersectionRange(run.range, range)
            guard intersection.length > 0 else { continue }
            if run.block.kind == "body" {
                value += separator + source.substring(with: intersection)
                separator = ""
                if !labels.contains(run.block.label) { labels.append(run.block.label) }
                for verse in run.block.verses where !verses.contains(verse) { verses.append(verse) }
            } else if run.block.kind == "break" || run.block.kind == "label" {
                if !value.isEmpty && !value.hasSuffix(" ") && !value.hasSuffix("\n") {
                    separator = run.block.kind == "break" ? "\n" : " "
                }
            }
        }
        return Selection(text: value,
                         editionID: document.editionID, contentRevision: document.contentRevision,
                         sourceLabels: labels, passages: verses.map { PassageRange(start: document.verse($0), end: document.verse($0)) })
    }
    /// Expands a partial selection to complete involved verse bodies, without headings or notes.
    /// Bridged verse blocks are included once, using the same typed mapping as selection.
    func fullVerseSelection(for selected: Selection) -> Selection? {
        guard selected.editionID == document.editionID,
              selected.contentRevision == document.contentRevision,
              !selected.passages.isEmpty,
              selected.passages.allSatisfy({
                  $0.start.book == document.book && $0.end.book == document.book &&
                  $0.start.chapter == document.chapter && $0.end.chapter == document.chapter &&
                  $0.start.verse > 0 && $0.end.verse >= $0.start.verse
              }) else { return nil }
        let verses = Set(selected.passages.flatMap { Array($0.start.verse...$0.end.verse) })
        let body = runs.filter {
            $0.block.kind == "body" && $0.range.length > 0 &&
            $0.block.verses.contains(where: verses.contains)
        }
        guard let first = body.first, let last = body.last else { return nil }
        return selection(in: NSUnionRange(first.range, last.range))
    }

    func range(for verse: Int) -> NSRange? {
        runs.first { $0.block.kind == "label" && $0.block.verses.contains(verse) }?.range
    }
    func focusRanges(for verse: Int) -> [NSRange] {
        runs.filter { ["label", "body"].contains($0.block.kind) && $0.block.verses.contains(verse) && $0.range.length > 0 }.map(\.range)
    }
    func verse(at offset: Int) -> Int? {
        runs.last { $0.range.location <= offset && !$0.block.verses.isEmpty }?.block.verses.first
    }

    struct VerseExcerpt {
        var startVerse: Int
        var endVerse: Int
        var text: String
        var ranges: [NSRange]
    }

    /// Keeps only the highlighted words. A verse that is cut off keeps its number and an ellipsis at the cut.
    func excerpt(in range: NSRange) -> VerseExcerpt? {
        let source = text as NSString
        var verses: [Int] = []
        for run in runs {
            let intersection = NSIntersectionRange(run.range, range)
            guard intersection.length > 0, run.block.kind == "body" else { continue }
            for verse in run.block.verses where !verses.contains(verse) { verses.append(verse) }
        }
        guard let start = verses.min(), let end = verses.max() else { return nil }
        var pieces: [String] = []
        var highlights: [NSRange] = []
        for verse in verses {
            let body = runs.filter { $0.block.kind == "body" && $0.block.verses.contains(verse) && $0.range.length > 0 }
            guard let first = body.first, let last = body.last else { continue }
            let coversStart = range.location <= first.range.location && NSMaxRange(range) > first.range.location
            let coversEnd = range.location < NSMaxRange(last.range) && NSMaxRange(range) >= NSMaxRange(last.range)
            var fragment = ""
            var separator = ""
            for run in runs {
                let intersection = NSIntersectionRange(run.range, range)
                guard intersection.length > 0 else { continue }
                if run.block.kind == "body" && run.block.verses.contains(verse) {
                    fragment += separator + source.substring(with: intersection)
                    separator = ""
                    highlights.append(intersection)
                } else if run.block.kind == "break" || run.block.kind == "label" {
                    if !fragment.isEmpty && !fragment.hasSuffix(" ") && !fragment.hasSuffix("\n") {
                        separator = run.block.kind == "break" ? "\n" : " "
                    }
                }
            }
            let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            var piece = coversStart ? "\(verse) \(trimmed)" : "\(verse)...\(trimmed)"
            if !coversEnd { piece += "..." }
            pieces.append(piece)
        }
        guard !pieces.isEmpty else { return nil }
        return VerseExcerpt(startVerse: start, endVerse: end, text: pieces.joined(separator: " "), ranges: highlights)
    }
}
