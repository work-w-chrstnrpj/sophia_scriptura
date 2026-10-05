import UIKit

/// Draws vertical quote bars beside block-quoted body text (Notion-style).
final class NoteBlockQuoteBarView: UIView {
    var spans: [NoteTextSpan] = []
    weak var textView: UITextView?
    var barColor: UIColor = .separator

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func draw(_ rect: CGRect) {
        guard let textView, spans.contains(where: \.blockQuote) else { return }
        let layoutManager = textView.layoutManager
        let barWidth: CGFloat = 3
        let inset: CGFloat = 14

        for span in spans where span.blockQuote && span.length > 0 {
            let charRange = NSRange(location: span.location, length: span.length)
            guard charRange.location >= 0, NSMaxRange(charRange) <= (textView.text as NSString).length else { continue }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
            var bars: [CGRect] = []
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
                var fragment = usedRect
                fragment.origin.x = inset
                fragment.size.width = barWidth
                let inTextView = fragment.offsetBy(dx: textView.textContainerInset.left, dy: textView.textContainerInset.top)
                bars.append(textView.convert(inTextView, to: self))
            }
            for bar in mergeLineBars(bars) {
                let path = UIBezierPath(roundedRect: bar, cornerRadius: barWidth / 2)
                barColor.setFill()
                path.fill()
            }
        }
    }

    private func mergeLineBars(_ bars: [CGRect]) -> [CGRect] {
        guard !bars.isEmpty else { return [] }
        let sorted = bars.sorted { $0.minY < $1.minY }
        var merged: [CGRect] = []
        var current = sorted[0]
        for bar in sorted.dropFirst() {
            if abs(bar.minX - current.minX) < 0.5, bar.minY <= current.maxY + 4 {
                current = current.union(bar)
            } else {
                merged.append(current)
                current = bar
            }
        }
        merged.append(current)
        return merged
    }
}
