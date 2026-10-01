import PencilKit

/// PencilKit adapts canonical black ink to white in dark appearance.
/// Never pre-invert it: that makes PencilKit invert the color a second time.
enum NoteInkAppearance {
    static func canonicalDrawing(_ drawing: PKDrawing) -> PKDrawing {
        let traits = UITraitCollection(userInterfaceStyle: .light)
        return PKDrawing(strokes: drawing.strokes.map { value in
            var stroke = value
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            let color = stroke.ink.color.resolvedColor(with: traits)
            if color.getRed(&r, green: &g, blue: &b, alpha: &a),
               max(r, g, b) - min(r, g, b) < 0.08, (r < 0.18 || r > 0.82) {
                stroke.ink = PKInk(stroke.ink.inkType, color: UIColor.black.withAlphaComponent(a))
            }
            return stroke
        })
    }
    static func image(_ drawing: PKDrawing, from rect: CGRect, scale: CGFloat, traits: UITraitCollection) -> UIImage {
        var image: UIImage!
        traits.performAsCurrent { image = canonicalDrawing(drawing).image(from: rect, scale: scale) }
        return image
    }
}
extension NoteTint {
    var color: UIColor {
        switch self {
        case .yellow: .systemYellow
        case .orange: .systemOrange
        case .red: .systemRed
        case .pink: .systemPink
        case .purple: .systemPurple
        case .blue: .systemBlue
        case .teal: .systemTeal
        case .green: .systemGreen
        case .neutral: .secondaryLabel
        }
    }
}
