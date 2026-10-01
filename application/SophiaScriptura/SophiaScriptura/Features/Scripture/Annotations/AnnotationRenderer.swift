import UIKit
import CryptoKit

@MainActor enum AnnotationRenderer {
    static func fontHash(_ name: String) -> String {
        var data = Data((name + "|" + ProcessInfo.processInfo.operatingSystemVersionString).utf8)
        for url in (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if let bytes = try? Data(contentsOf: url) { data.append(bytes) }
        }
        return digest(data)
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func text(_ document: ChapterDocument, font: UIFont, palette: ReaderPalette) -> NSAttributedString {
        let map = ChapterTextMap(document: document)
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 6; paragraph.paragraphSpacing = 12
        let result = NSMutableAttributedString(string: map.text, attributes: [.font: font, .foregroundColor: palette.ink, .paragraphStyle: paragraph])
        for run in map.runs where run.range.length > 0 {
            switch run.block.kind {
            case "label":
                if let verse = run.block.verses.first {
                    result.addAttributes([.link: URL(string: "sophia-verse:\(verse)")!, .font: UIFont.systemFont(ofSize: 15, weight: .semibold)], range: run.range)
                }
            case "note": result.addAttributes([.link: URL(string: "sophia-note:\(run.range.location)")!, .font: UIFont.systemFont(ofSize: 14)], range: run.range)
            case "heading": result.addAttributes([.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: palette.secondary], range: run.range)
            default: break
            }
            if ["q1", "q2", "pi1", "li1"].contains(run.block.style), run.block.kind == "body" {
                let poetry = paragraph.mutableCopy() as! NSMutableParagraphStyle
                poetry.headIndent = run.block.style == "q2" ? 36 : 18; poetry.firstLineHeadIndent = poetry.headIndent
                result.addAttribute(.paragraphStyle, value: poetry, range: run.range)
            }
        }
        return result
    }
    static func measure(_ document: ChapterDocument, preferences: ReaderPreferences, width available: Double) -> AnnotationLayout {
        let family = preferences.appearancePreset == nil ? preferences.typeface : preferences.appearance.readingFamily
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: ScriptureFonts.font(family, size: CGFloat(19 + preferences.sizeStep * 2)))
        // Match the ordinary reader's centered column, then reserve equal blank space outside it.
        let textWidth = min(760, max(320, available)) - 66
        return layout(document, font: font, width: textWidth + 400, textWidth: textWidth, surrounding: true)
    }
    static func layout(_ document: ChapterDocument, font: UIFont, width: Double, textWidth: Double, surrounding: Bool = false) -> AnnotationLayout {
        let storage = NSTextStorage(attributedString: text(document, font: font, palette: .init(0xffffff, 0x000000, 0x494949)))
        let manager = NSLayoutManager(), container = NSTextContainer(size: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0; storage.addLayoutManager(manager); manager.addTextContainer(container)
        manager.ensureLayout(for: container)
        let inset = surrounding ? 200.0 : 24.0
        let algorithm = surrounding ? "continuous-textkit1-surround-v2" : "continuous-textkit1-v1"
        let height = ceil(manager.usedRect(for: container).height) + inset * 2
        var geometry = "\(algorithm)|\(document.contentRevision)|\(width)|\(textWidth)|\(height)|\(font.fontName)|\(font.pointSize)|\(fontHash(font.fontName))"
        manager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: manager.numberOfGlyphs)) { rect, used, _, range, _ in
            geometry += "|\(range.location),\(range.length)|\(rect.origin.x),\(rect.origin.y),\(rect.width),\(rect.height)|\(used.origin.x),\(used.origin.y),\(used.width),\(used.height)"
        }
        return AnnotationLayout(algorithm: algorithm, fontName: font.fontName, fontResourceHash: fontHash(font.fontName), fontSize: font.pointSize,
            width: width, textWidth: textWidth, height: height, inset: inset, marginStart: surrounding ? width - inset : textWidth + 48,
            lineSpacing: 6, paragraphSpacing: 12, signature: digest(Data(geometry.utf8)))
    }
    static func matches(_ group: AnnotationGroup, document: ChapterDocument) -> Bool {
        matches(group.layout, source: group.source, document: document)
    }
    static func matches(_ layout: AnnotationLayout, source: AnnotationSource, document: ChapterDocument) -> Bool {
        // Register bundled families before resolving the persisted PostScript font name.
        _ = ScriptureFonts.font("Georgia", size: 20)
        guard source == AnnotationSource(document), let font = UIFont(name: layout.fontName, size: layout.fontSize) else { return false }
        return self.layout(document, font: font, width: layout.width, textWidth: layout.textWidth, surrounding: layout.surroundingSpace) == layout
    }
}
