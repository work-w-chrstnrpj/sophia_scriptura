import SwiftUI
import UIKit
import CoreText

/// Presentation-only tokens. Preset identifiers are persisted; colors and fonts are not.
enum ScriptureAppearance: String, CaseIterable, Identifiable {
    // inkAndLinen remains the persisted identifier for the renamed Royal Ink preset.
    case oldPaper, midnightLibrary, quietSage, sepiaNotes, inkAndLinen, treeOfKnowledge, springLeaf
    var id: String { rawValue }
    var title: String {
        switch self {
        case .oldPaper: "OldPaper"
        case .midnightLibrary: "Midnight Library"
        case .quietSage: "Quiet Sage"
        case .sepiaNotes: "Sepia Notes"
        case .inkAndLinen: "Royal Ink"
        case .treeOfKnowledge: "Tree of Knowledge"
        case .springLeaf: "Spring Leaf"
        }
    }
    var readingFamily: String {
        switch self {
        case .oldPaper: "Georgia"
        case .midnightLibrary: "Cormorant Garamond"
        case .quietSage, .springLeaf: "Lora"
        case .sepiaNotes: "EB Garamond"
        case .inkAndLinen: "Libre Baskerville"
        case .treeOfKnowledge: "Playfair Display"
        }
    }
    var interfaceFamily: String {
        switch self {
        case .oldPaper: "System"
        case .midnightLibrary, .springLeaf: "DM Sans"
        case .quietSage: "Manrope"
        case .sepiaNotes: "EB Garamond"
        case .inkAndLinen, .treeOfKnowledge: "Source Sans 3"
        }
    }
    var headingFamily: String { self == .sepiaNotes ? "Caveat" : readingFamily }
    func palette(dark: Bool) -> ReaderPalette {
        if dark {
            switch self {
            case .oldPaper: return ReaderPalette(0x181818, 0xf2f2f2, 0xbfbfbf)
            case .sepiaNotes: return ReaderPalette(0x2c241b, 0xf4e4c6, 0xe7ba78)
            case .treeOfKnowledge: return ReaderPalette(0x29241f, 0xede1ce, 0xe0b198)
            case .inkAndLinen: return ReaderPalette(0x25212b, 0xeee8f4, 0xc8b4de)
            case .quietSage: return ReaderPalette(0x1e2828, 0xe4efed, 0xa0cfca)
            case .midnightLibrary: return ReaderPalette(0x202633, 0xeff1f4, 0xbac6d4)
            default: return ReaderPalette(0x202522, 0xe8eee9, 0xafd3ba)
            }
        }
        switch self {
        case .oldPaper: return ReaderPalette(0xffffff, 0x000000, 0x494949)
        case .midnightLibrary: return ReaderPalette(0xf4f6fa, 0x202633, 0x4a6280)
        case .quietSage: return ReaderPalette(0xe9f0ee, 0x253535, 0x426966)
        case .sepiaNotes: return ReaderPalette(0xf5e5c6, 0x382b1d, 0x806039)
        case .inkAndLinen: return ReaderPalette(0xf7f4fa, 0x2e2538, 0x69527f)
        case .treeOfKnowledge: return ReaderPalette(0xf7f2e7, 0x382e29, 0x8b4436)
        case .springLeaf: return ReaderPalette(0xfcfcf9, 0x253b34, 0x315f4c)
        }
    }
}

struct ReaderPalette {
    let paper: UIColor
    let ink: UIColor
    let accent: UIColor
    var secondary: UIColor { ink.withAlphaComponent(0.72) }
    var rule: UIColor { ink.withAlphaComponent(0.16) }
    var soft: UIColor { ink.withAlphaComponent(0.07) }
    init(_ paper: UInt32, _ ink: UInt32, _ accent: UInt32) {
        func color(_ value: UInt32) -> UIColor {
            UIColor(red:CGFloat((value >> 16) & 255)/255, green:CGFloat((value >> 8) & 255)/255,
                    blue:CGFloat(value & 255)/255, alpha:1)
        }
        self.paper = color(paper); self.ink = color(ink); self.accent = color(accent)
    }
}

/// Fonts ship with the app: no network request is made when selecting a preset.
enum ScriptureFonts {
    private static let registered: Void = {
        for url in Bundle.main.urls(forResourcesWithExtension:"ttf", subdirectory:nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
    static func font(_ family: String, size: CGFloat) -> UIFont {
        _ = registered
        if family == "System" { return .systemFont(ofSize:size) }
        let names = UIFont.fontNames(forFamilyName:family)
        let name = names.first(where: { $0.hasSuffix("-Regular") }) ?? names.first ?? family
        return UIFont(name:name,size:size) ?? UIFont(name:"Georgia",size:size)!
    }
    static func interface(_ appearance: ScriptureAppearance, size: CGFloat = 15) -> Font {
        Font(UIFontMetrics(forTextStyle:.body).scaledFont(for:font(appearance.interfaceFamily,size:size)))
    }
}

enum ScriptureVerseNumberStyle {
    private static let relativeSize: CGFloat = 0.62
    private static let baselineFactor: CGFloat = 0.38

    static func uiKitAttributes(readingFont: UIFont, verse: Int) -> [NSAttributedString.Key: Any] {
        let superscriptSize = max(11, readingFont.pointSize * relativeSize)
        let font = UIFontMetrics(forTextStyle: .caption2).scaledFont(
            for: .systemFont(ofSize: superscriptSize, weight: .semibold)
        )
        return [
            .link: URL(string: "sophia-verse:\(verse)")!,
            .font: font,
            .baselineOffset: readingFont.pointSize * baselineFactor,
        ]
    }

    static func swiftUISuperscript(_ number: Int, bodySize: CGFloat) -> (font: Font, baselineOffset: CGFloat) {
        let superscriptSize = max(11, bodySize * relativeSize)
        return (
            .system(size: superscriptSize, design: .serif).weight(.semibold),
            bodySize * baselineFactor
        )
    }
}

extension ReaderPreferences {
    var appearance: ScriptureAppearance { ScriptureAppearance(rawValue:appearancePreset ?? "") ?? .oldPaper }
    func palette(for appearance: ScriptureAppearance, colorScheme: ColorScheme) -> ReaderPalette {
        let dark = theme == "dark" || (theme == "system" && colorScheme == .dark)
        return appearance.palette(dark:dark)
    }
}
