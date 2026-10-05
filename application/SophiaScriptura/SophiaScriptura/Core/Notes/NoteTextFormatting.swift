import UIKit

/// Optional character styles for a Page or Journal body. Empty means the historical plain body.
struct NoteTextSpan: Codable, Equatable, Sendable {
    var location: Int
    var length: Int
    var bold = false
    var italic = false
    var underline = false
    var strikethrough = false
    /// 0 body, 1 title, 2 heading, 3 subheading, 4 monospaced.
    var level = 0
    /// 1…9 preset ink colors; nil uses the note paper ink when `colorHex` is also nil.
    var colorIndex: Int?
    /// Six-digit RRGGBB custom ink when presets are not enough.
    var colorHex: String?
    var blockQuote = false

    var isPlain: Bool {
        !bold && !italic && !underline && !strikethrough && level == 0 && colorIndex == nil && colorHex == nil && !blockQuote
    }

    private enum CodingKeys: String, CodingKey {
        case location, length, bold, italic, underline, strikethrough, level, colorIndex, colorHex, blockQuote
    }

    init(
        location: Int,
        length: Int,
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        strikethrough: Bool = false,
        level: Int = 0,
        colorIndex: Int? = nil,
        colorHex: String? = nil,
        blockQuote: Bool = false
    ) {
        self.location = location
        self.length = length
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.level = level
        self.colorIndex = colorIndex
        self.colorHex = colorHex
        self.blockQuote = blockQuote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        location = try container.decode(Int.self, forKey: .location)
        length = try container.decode(Int.self, forKey: .length)
        bold = try container.decodeIfPresent(Bool.self, forKey: .bold) ?? false
        italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
        underline = try container.decodeIfPresent(Bool.self, forKey: .underline) ?? false
        strikethrough = try container.decodeIfPresent(Bool.self, forKey: .strikethrough) ?? false
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 0
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        blockQuote = try container.decodeIfPresent(Bool.self, forKey: .blockQuote) ?? false
    }
}

enum NoteTextFormatting {
    enum Change: Equatable {
        case bold, italic, underline, strikethrough, level(Int), inkColor(ColorSpec), blockQuote
    }

    enum ColorSpec: Equatable {
        case `default`
        case preset(Int)
        case hex(String)
    }

    /// Preset body ink colors aligned with Apple Notes, plus black and white.
    enum InkColor: Int, CaseIterable, Identifiable {
        case purple = 1, pink, orange, yellow, green, blue, gray, black, white
        var id: Int { rawValue }

        var uiColor: UIColor {
            switch self {
            case .purple: return .systemPurple
            case .pink: return .systemPink
            case .orange: return .systemOrange
            case .yellow: return .systemYellow
            case .green: return .systemGreen
            case .blue: return .systemBlue
            case .gray: return .systemGray
            case .black: return .black
            case .white: return .white
            }
        }
    }

    static func inkColor(_ index: Int?) -> UIColor? {
        guard let index else { return nil }
        if index == 8 { return .black }
        if index == 9 { return .white }
        guard let preset = InkColor(rawValue: index) else { return nil }
        return preset.uiColor
    }

    static func resolvedInk(for span: NoteTextSpan) -> UIColor? {
        if let hex = span.colorHex, let color = UIColor(rgbHex: hex) { return color }
        return inkColor(span.colorIndex)
    }

    static func font(_ span: NoteTextSpan) -> UIFont {
        let size: CGFloat
        switch span.level {
        case 1: size = 34
        case 2: size = 28
        case 3: size = 24
        case 4: size = 20
        default: size = 22
        }
        let base = span.level == 4
            ? UIFont.monospacedSystemFont(ofSize: size, weight: span.bold ? .semibold : .regular)
            : UIFont.systemFont(ofSize: size, weight: span.bold ? .semibold : .regular)
        guard span.italic, let traits = base.fontDescriptor.withSymbolicTraits(base.fontDescriptor.symbolicTraits.union(.traitItalic)) else { return base }
        return UIFont(descriptor: traits, size: size)
    }

    static func apply(_ spans: [NoteTextSpan], to text: NSMutableAttributedString) {
        for span in spans where span.length > 0 {
            let range = NSRange(location: span.location, length: span.length)
            guard range.location >= 0, NSMaxRange(range) <= text.length else { continue }
            text.addAttribute(.font, value: font(span), range: range)
            if span.underline { text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
            if span.strikethrough { text.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
            if span.blockQuote {
                let style = NSMutableParagraphStyle()
                style.firstLineHeadIndent = 32
                style.headIndent = 32
                style.paragraphSpacing = 6
                text.addAttribute(.paragraphStyle, value: style, range: range)
            }
            if let color = resolvedInk(for: span) {
                text.addAttribute(.foregroundColor, value: color, range: range)
            } else if span.blockQuote {
                text.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: range)
            }
        }
    }

    static func quoteTargetRange(in body: String, line: NSRange) -> NSRange {
        let text = body as NSString
        var range = line
        if range.length > 0, text.substring(with: NSRange(location: NSMaxRange(range) - 1, length: 1)) == "\n" {
            range.length -= 1
        }
        return range.length > 0 ? range : NSRange(location: 0, length: 0)
    }

    static func lineRange(in body: String, utf16 location: Int) -> NSRange {
        let text = body as NSString
        let point = min(max(0, location), text.length)
        var line = text.lineRange(for: NSRange(location: point, length: 0))
        if line.length > 0, text.substring(with: NSRange(location: NSMaxRange(line) - 1, length: 1)) == "\n" {
            line.length -= 1
        }
        return line
    }

    /// Keeps styles attached to the characters around a body edit.
    static func adjusting(_ spans: [NoteTextSpan], replacing range: NSRange, delta: Int) -> [NoteTextSpan] {
        let editEnd = range.location + range.length
        let inserted = range.length + delta
        return spans.compactMap { span in
            var item = span
            let end = item.location + item.length
            if range.length == 0, range.location > item.location, range.location <= end {
                item.length += delta
                return item.length > 0 ? item : nil
            }
            if editEnd <= item.location {
                item.location += delta
                return item.length > 0 ? item : nil
            }
            if range.location >= end { return item }
            if range.location <= item.location, editEnd >= end { return nil }
            let tail = max(0, end - editEnd)
            if range.location <= item.location {
                if range.location == item.location {
                    item.location = range.location
                    item.length = inserted + tail
                } else {
                    item.location = range.location + inserted
                    item.length = tail
                }
                return item.length > 0 ? item : nil
            }
            let keptHead = range.location - item.location
            item.length = keptHead + inserted + tail
            return item.length > 0 ? item : nil
        }
    }

    static func changing(_ spans: [NoteTextSpan], range: NSRange, change: Change) -> [NoteTextSpan] {
        guard range.length > 0 else { return normalize(spans) }
        let enable: Bool
        switch change {
        case .bold: enable = !covered(spans, range: range) { $0.bold }
        case .italic: enable = !covered(spans, range: range) { $0.italic }
        case .underline: enable = !covered(spans, range: range) { $0.underline }
        case .strikethrough: enable = !covered(spans, range: range) { $0.strikethrough }
        case .blockQuote: enable = !covered(spans, range: range) { $0.blockQuote }
        case .level, .inkColor: enable = true
        }
        let start = range.location
        let end = start + range.length
        var outside: [NoteTextSpan] = []
        var cuts = [start, end]
        for span in spans {
            let spanStart = span.location
            let spanEnd = spanStart + span.length
            if spanEnd <= start || spanStart >= end {
                outside.append(span)
                continue
            }
            if spanStart < start {
                var left = span
                left.length = start - spanStart
                outside.append(left)
            }
            if spanEnd > end {
                var right = span
                right.location = end
                right.length = spanEnd - end
                outside.append(right)
            }
            cuts.append(max(spanStart, start))
            cuts.append(min(spanEnd, end))
        }
        var inside: [NoteTextSpan] = []
        let points = Array(Set(cuts)).sorted()
        for index in points.indices.dropLast() {
            let pieceStart = points[index]
            let pieceEnd = points[index + 1]
            guard pieceEnd > pieceStart, pieceStart >= start, pieceEnd <= end else { continue }
            var style = spans.first { $0.location <= pieceStart && pieceStart < $0.location + $0.length }
                ?? NoteTextSpan(location: pieceStart, length: pieceEnd - pieceStart)
            style.location = pieceStart
            style.length = pieceEnd - pieceStart
            switch change {
            case .bold: style.bold = enable
            case .italic: style.italic = enable
            case .underline: style.underline = enable
            case .strikethrough: style.strikethrough = enable
            case .blockQuote: style.blockQuote = enable
            case .level(let level): style.level = level
            case .inkColor(let spec):
                switch spec {
                case .default:
                    style.colorIndex = nil
                    style.colorHex = nil
                case .preset(let index):
                    style.colorIndex = normalizedColorIndex(index)
                    style.colorHex = nil
                case .hex(let hex):
                    style.colorIndex = nil
                    style.colorHex = normalizedHex(hex)
                }
            }
            if !style.isPlain { inside.append(style) }
        }
        return normalize(outside + inside)
    }

    enum ListKind { case bullet, numbered }

    static func lineRanges(in body: String, covering range: NSRange) -> [NSRange] {
        let text = body as NSString
        if text.length == 0 { return [NSRange(location: 0, length: 0)] }
        let first = lineRange(in: body, utf16: range.location)
        if range.length == 0 { return [first] }
        let lastStart = min(max(0, NSMaxRange(range) - 1), text.length - 1)
        let last = lineRange(in: body, utf16: lastStart)
        if first.location == last.location { return [first] }
        var lines = [first]
        var cursor = NSMaxRange(first)
        while cursor < last.location {
            let line = text.lineRange(for: NSRange(location: cursor, length: 0))
            lines.append(line)
            cursor = NSMaxRange(line)
        }
        if lines.last?.location != last.location { lines.append(last) }
        return lines
    }

    static func listEdit(in body: String, line: NSRange, kind: ListKind) -> (NSRange, String)? {
        let text = body as NSString
        let content = text.substring(with: line)
        switch kind {
        case .bullet:
            if content.hasPrefix("• ") { return nil }
            if let length = numberedPrefixLength(content) {
                return (NSRange(location: line.location, length: length), "• ")
            }
            return (NSRange(location: line.location, length: 0), "• ")
        case .numbered:
            if numberedPrefixLength(content) != nil { return nil }
            if content.hasPrefix("• ") {
                return (NSRange(location: line.location, length: 2), "1. ")
            }
            return (NSRange(location: line.location, length: 0), "1. ")
        }
    }

    static func indentEdit(in body: String, line: NSRange, outdent: Bool) -> (NSRange, String)? {
        let text = body as NSString
        let content = text.substring(with: line)
        if outdent {
            if content.hasPrefix("\t") { return (NSRange(location: line.location, length: 1), "") }
            if content.hasPrefix("    ") { return (NSRange(location: line.location, length: 4), "") }
            return nil
        }
        return (NSRange(location: line.location, length: 0), "\t")
    }

    private static func numberedPrefixLength(_ line: String) -> Int? {
        let pattern = "^\\d+\\. "
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)),
              match.range.location == 0 else { return nil }
        return match.range.length
    }

    static func checkboxEdit(in body: String, caret: Int) -> (NSRange, String) {
        let line = lineRange(in: body, utf16: caret)
        let text = (body as NSString).substring(with: line)
        if text.hasPrefix("☐ ") { return (NSRange(location: line.location, length: 2), "☑ ") }
        if text.hasPrefix("☑ ") { return (NSRange(location: line.location, length: 2), "☐ ") }
        if text.hasPrefix("☐") { return (NSRange(location: line.location, length: 1), "☑ ") }
        if text.hasPrefix("☑") { return (NSRange(location: line.location, length: 1), "☐ ") }
        return (NSRange(location: line.location, length: 0), "☐ ")
    }

    struct ActiveState: Equatable {
        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false
        var blockQuote = false
        var colorIndex: Int?
        var colorHex: String?
        var colorMixed = false

        var usesDefaultInk: Bool { !colorMixed && colorIndex == nil && colorHex == nil }

        func matchesPreset(_ index: Int) -> Bool {
            !colorMixed && colorIndex == index && colorHex == nil
        }
        /// Uniform style level; `-1` when the selection mixes levels.
        var level = 0
        var bulletList = false
        var numberedList = false

        static let empty = ActiveState()
    }

    static func inspectionRange(in body: String, selection: NSRange) -> NSRange {
        if selection.length > 0 { return selection }
        let length = body.utf16.count
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let index = min(max(0, selection.location), length - 1)
        return NSRange(location: index, length: 1)
    }

    static func activeState(formatting spans: [NoteTextSpan], body: String, selection: NSRange) -> ActiveState {
        let range = inspectionRange(in: body, selection: selection)
        guard range.length > 0 else { return .empty }
        let color = uniformColor(spans, range: range)
        let lines = lineRanges(in: body, covering: selection.length > 0 ? selection : lineRange(in: body, utf16: selection.location))
        return ActiveState(
            bold: covered(spans, range: range) { $0.bold },
            italic: covered(spans, range: range) { $0.italic },
            underline: covered(spans, range: range) { $0.underline },
            strikethrough: covered(spans, range: range) { $0.strikethrough },
            blockQuote: covered(spans, range: range) { $0.blockQuote },
            colorIndex: color.mixed ? nil : color.index,
            colorHex: color.mixed ? nil : color.hex,
            colorMixed: color.mixed,
            level: uniformLevel(spans, range: range),
            bulletList: lines.allSatisfy { (body as NSString).substring(with: $0).hasPrefix("• ") },
            numberedList: lines.allSatisfy { numberedPrefixLength((body as NSString).substring(with: $0)) != nil }
        )
    }

    private static func uniformLevel(_ spans: [NoteTextSpan], range: NSRange) -> Int {
        var index = range.location
        let end = NSMaxRange(range)
        var level: Int?
        while index < end {
            let value = spans.first { $0.location <= index && index < $0.location + $0.length }?.level ?? 0
            if let level, level != value { return -1 }
            level = value
            index += 1
        }
        return level ?? 0
    }

    private static func uniformColor(_ spans: [NoteTextSpan], range: NSRange) -> (index: Int?, hex: String?, mixed: Bool) {
        var index = range.location
        let end = NSMaxRange(range)
        var first: (Int?, String?)?
        while index < end {
            let signature = colorSignature(at: index, spans: spans)
            if first == nil {
                first = signature
            } else if first!.0 != signature.0 || first!.1 != signature.1 {
                return (nil, nil, true)
            }
            index += 1
        }
        return (first?.0, first?.1, false)
    }

    private static func colorSignature(at index: Int, spans: [NoteTextSpan]) -> (Int?, String?) {
        guard let span = spans.first(where: { $0.location <= index && index < $0.location + $0.length }) else {
            return (nil, nil)
        }
        return (span.colorIndex, span.colorHex)
    }

    private static func covered(_ spans: [NoteTextSpan], range: NSRange, has style: (NoteTextSpan) -> Bool) -> Bool {
        var index = range.location
        let end = range.location + range.length
        while index < end {
            guard let span = spans.first(where: { $0.location <= index && index < $0.location + $0.length }), style(span) else { return false }
            index = span.location + span.length
        }
        return index >= end
    }

    private static func normalize(_ spans: [NoteTextSpan]) -> [NoteTextSpan] {
        let sorted = spans.filter { $0.length > 0 && !$0.isPlain }.sorted {
            $0.location == $1.location ? $0.length > $1.length : $0.location < $1.location
        }
        var result: [NoteTextSpan] = []
        for span in sorted {
            guard var last = result.last else { result.append(span); continue }
            let lastEnd = last.location + last.length
            if sameStyle(last, span), lastEnd >= span.location {
                last.length = max(lastEnd, span.location + span.length) - last.location
                result[result.count - 1] = last
            } else if lastEnd > span.location, span.location > last.location {
                last.length = span.location - last.location
                result[result.count - 1] = last
                result.append(span)
            } else if lastEnd > span.location {
                result[result.count - 1] = span
            } else {
                result.append(span)
            }
        }
        return result
    }

    private static func sameStyle(_ lhs: NoteTextSpan, _ rhs: NoteTextSpan) -> Bool {
        lhs.bold == rhs.bold && lhs.italic == rhs.italic && lhs.underline == rhs.underline
            && lhs.strikethrough == rhs.strikethrough && lhs.level == rhs.level
            && lhs.colorIndex == rhs.colorIndex && lhs.colorHex == rhs.colorHex && lhs.blockQuote == rhs.blockQuote
    }

    private static func normalizedColorIndex(_ index: Int?) -> Int? {
        guard let index, index > 0, index <= 9 else { return nil }
        if index <= 7, InkColor(rawValue: index) == nil { return nil }
        return index
    }

    private static func normalizedHex(_ value: String) -> String? {
        let hex = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard hex.count == 6, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        return hex
    }
}

private extension UIColor {
    convenience init?(rgbHex: String) {
        var hex = rgbHex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard hex.count == 6, hex.allSatisfy(\.isHexDigit) else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else { return nil }
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
