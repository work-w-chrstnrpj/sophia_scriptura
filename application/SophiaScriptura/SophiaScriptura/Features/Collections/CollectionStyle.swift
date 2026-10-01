import SwiftUI
import UIKit

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
