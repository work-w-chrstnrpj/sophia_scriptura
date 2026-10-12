import SwiftUI
import UIKit

enum SophySlashCommandStyle {
    private static let tokenPattern = #"(?<=^|\s)(/\S*)"#

    /// Highlights `/command` tokens with the active appearance accent (preset color).
    static func attributedText(_ text: String, accent: UIColor, ink: UIColor) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = Color(uiColor: ink)
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return attributed }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, range: range) {
            guard let tokenRange = Range(match.range(at: 1), in: text),
                  let start = AttributedString.Index(tokenRange.lowerBound, within: attributed),
                  let end = AttributedString.Index(tokenRange.upperBound, within: attributed) else { continue }
            attributed[start..<end].foregroundColor = Color(uiColor: accent)
            attributed[start..<end].font = .body.weight(.semibold)
        }
        return attributed
    }

    static func showsHighlightedOverlay(for text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
