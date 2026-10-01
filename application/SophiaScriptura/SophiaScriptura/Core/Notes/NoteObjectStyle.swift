import Foundation

/// Optional styles keep pre-existing v3 objects readable with their original defaults.
enum NoteShape: String, Codable, CaseIterable, Sendable {
    case rectangle, roundedRectangle, circle, triangle, diamond, star, hexagon, heart, arrow
    var title: String { self == .roundedRectangle ? "Rounded rectangle" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .rectangle: "rectangle.fill"
        case .roundedRectangle: "rectangle.roundedtop.fill"
        case .circle: "circle.fill"
        case .triangle: "triangle.fill"
        case .diamond: "diamond.fill"
        case .star: "star.fill"
        case .hexagon: "hexagon.fill"
        case .heart: "heart.fill"
        case .arrow: "arrow.right"
        }
    }
}
enum NoteTint: String, Codable, CaseIterable, Sendable {
    case yellow, orange, red, pink, purple, blue, teal, green, neutral
}
