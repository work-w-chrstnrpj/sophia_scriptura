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
    func range(for verse: Int) -> NSRange? {
        runs.first { $0.block.kind == "label" && $0.block.verses.contains(verse) }?.range
    }
    func focusRanges(for verse: Int) -> [NSRange] {
        runs.filter { ["label", "body"].contains($0.block.kind) && $0.block.verses.contains(verse) && $0.range.length > 0 }.map(\.range)
    }
    func verse(at offset: Int) -> Int? {
        runs.last { $0.range.location <= offset && !$0.block.verses.isEmpty }?.block.verses.first
    }
}
