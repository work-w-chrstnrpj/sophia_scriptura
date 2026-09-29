import Foundation

/// Walk typed USX-derived JSON. Never search or reconstruct verses from prose.
struct APIChapterParser {
    static func parse(_ source: APIChapter, edition: ScriptureEdition) throws -> ChapterDocument {
        guard let chapter = Int(source.number), chapter > 0,
              source.id == "\(source.bookId).\(chapter)", edition.id == "api.bible." + source.bibleId else { throw LicensedContentError.invalidContent }
        var blocks: [ScriptureBlock] = []
        var label = ""
        var verses: [Int] = []
        func append(_ kind: String, _ text: String, _ style: String) {
            blocks.append(ScriptureBlock(id:"\(source.id).\(blocks.count)",kind:kind,text:text,label:label,verses:verses,style:style))
        }
        func plain(_ node: APINode) -> String { node.text ?? (node.items ?? []).map(plain).joined() }
        func numbers(_ value: String) throws -> [Int] {
            let parts = value.split(separator:"-")
            func number(_ part: Substring) -> Int? { Int(part.prefix(while: { $0.isNumber })) }
            guard (1...2).contains(parts.count), let first = number(parts[0]), first > 0, first < 1000 else { throw LicensedContentError.invalidContent }
            if parts.count == 1 { return [first] }
            guard let last = number(parts[1]), last >= first, last < 1000 else { throw LicensedContentError.invalidContent }
            return Array(first...last)
        }
        func walk(_ node: APINode, style: String) throws {
            if node.type == "text" {
                guard let text = node.text else { throw LicensedContentError.invalidContent }
                if !text.isEmpty { append(verses.isEmpty ? "heading" : "body",text,style) }
                return
            }
            guard node.type == "tag", let name = node.name else { throw LicensedContentError.invalidContent }
            let currentStyle = node.attrs?.style ?? style
            switch name {
            case "verse":
                guard let number = node.attrs?.number else { throw LicensedContentError.invalidContent }
                label = number; verses = try numbers(number)
                append("label",number,"v")
                // API.Bible may repeat the visible number as a child. The label above
                // is authoritative, so deliberately do not duplicate that child.
            case "note": append("note",plain(node),currentStyle)
            case "para":
                let isHeading = ["s","ms","mt","mte","r","sr","d","sp","cl","cd","qa"].contains { currentStyle == $0 || currentStyle.hasPrefix($0 + "1") || currentStyle.hasPrefix($0 + "2") || currentStyle.hasPrefix($0 + "3") || currentStyle.hasPrefix($0 + "4") }
                if isHeading {
                    let previousLabel = label, previousVerses = verses
                    label = ""; verses = []; append("heading",plain(node),currentStyle)
                    label = previousLabel; verses = previousVerses
                } else {
                    append("break","",currentStyle)
                    for child in node.items ?? [] { try walk(child,style:currentStyle) }
                }
            case "char", "ref", "link", "table", "row", "cell":
                for child in node.items ?? [] { try walk(child,style:currentStyle) }
            case "chapter": break
            default:
                // Preserve body text when API.Bible introduces a presentational USX
                // tag. Structural identities are still validated at verse boundaries.
                for child in node.items ?? [] { try walk(child,style:currentStyle) }
            }
        }
        for node in source.content { try walk(node,style:"p") }
        let document = ChapterDocument(schemaVersion:1,editionID:edition.id,contentRevision:edition.contentRevision,book:source.bookId,chapter:chapter,blocks:blocks)
        guard !document.verseNumbers.isEmpty, source.verseCount > 0,
              document.verseNumbers.allSatisfy({ verse in blocks.contains { $0.kind == "label" && $0.verses.contains(verse) } }) else { throw LicensedContentError.invalidContent }
        return document
    }
}
