import SwiftUI
import UIKit

enum CollectionSurface {
    static let background = adaptive(light: UIColor(red: 0.97, green: 0.95, blue: 0.91, alpha: 1), dark: .systemBackground)
    static let card = adaptive(light: UIColor.white.withAlphaComponent(0.72), dark: .secondarySystemBackground)
    static let ink = adaptive(light: UIColor(red: 0.16, green: 0.14, blue: 0.13, alpha: 1), dark: .label)
    static let secondaryInk = adaptive(light: UIColor(red: 0.36, green: 0.34, blue: 0.31, alpha: 1), dark: .secondaryLabel)

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension CollectionAccent {
    var color: Color {
        switch self {
        case .oxblood: return Color(red: 0.45, green: 0.16, blue: 0.15)
        case .sage: return Color(red: 0.28, green: 0.43, blue: 0.34)
        case .slate: return Color(red: 0.25, green: 0.34, blue: 0.43)
        case .gold: return Color(red: 0.63, green: 0.44, blue: 0.16)
        }
    }
}

extension CollectionArtifactKind {
    var tint: Color {
        switch self {
        case .scripture: return Color(red: 0.45, green: 0.16, blue: 0.15)
        case .note: return Color(red: 0.28, green: 0.43, blue: 0.34)
        case .conversation: return Color(red: 0.25, green: 0.34, blue: 0.43)
        case .link: return Color(red: 0.63, green: 0.44, blue: 0.16)
        }
    }
}
