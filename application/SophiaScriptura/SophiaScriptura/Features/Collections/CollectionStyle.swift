import SwiftUI
import UIKit

extension CollectionAccent {
    private var components: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        switch self {
        case .oxblood: return (0.45, 0.16, 0.15)
        case .rose: return (0.58, 0.25, 0.32)
        case .terracotta: return (0.64, 0.32, 0.19)
        case .gold: return (0.63, 0.44, 0.16)
        case .mustard: return (0.66, 0.54, 0.18)
        case .olive: return (0.45, 0.48, 0.21)
        case .sage: return (0.28, 0.43, 0.34)
        case .teal: return (0.17, 0.41, 0.42)
        case .slate: return (0.25, 0.34, 0.43)
        case .indigo: return (0.30, 0.30, 0.52)
        case .plum: return (0.42, 0.24, 0.43)
        case .umber: return (0.42, 0.31, 0.22)
        }
    }

    /// Dark appearances lift each ink toward the paper so folders stay legible on dark surfaces.
    var uiColor: UIColor {
        let base = components
        return UIColor { traits in
            guard traits.userInterfaceStyle == .dark else {
                return UIColor(red: base.red, green: base.green, blue: base.blue, alpha: 1)
            }
            let lift: CGFloat = 0.38
            return UIColor(
                red: base.red + (1 - base.red) * lift,
                green: base.green + (1 - base.green) * lift,
                blue: base.blue + (1 - base.blue) * lift,
                alpha: 1
            )
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

extension CollectionArtifactKind {
    var tint: Color {
        switch self {
        case .scripture, .bookmark: return CollectionAccent.oxblood.color
        case .note: return CollectionAccent.sage.color
        case .conversation: return CollectionAccent.slate.color
        case .link, .gleaning: return CollectionAccent.gold.color
        }
    }
}

enum CollectionCount {
    static func items(_ count: Int) -> String { count == 1 ? "1 item" : "\(count) items" }
    static func subfolders(_ count: Int) -> String { count == 1 ? "1 subfolder" : "\(count) subfolders" }
}

/// Folder or tray glyph on a tinted tile; the tile size sets the hierarchy level.
struct CollectionFolderGlyph: View {
    let accent: CollectionAccent
    var unfiled = false
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: unfiled ? "tray.fill" : "folder.fill")
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(accent.color)
            .frame(width: size, height: size)
            .background(accent.color.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct CollectionItemGlyph: View {
    let kind: CollectionArtifactKind
    let accent: CollectionAccent
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: kind.symbolName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(accent.color)
            .frame(width: size, height: size)
            .background(accent.color.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Filled capsule whose label always uses the paper color against the theme accent.
struct CollectionProminentButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(theme.palette.paper))
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 48)
            .background(Capsule().fill(Color(theme.palette.accent)))
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.4)
            .contentShape(Capsule())
    }
}

/// Quiet capsule for secondary actions; ink label on a soft fill.
struct CollectionSecondaryButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(destructive ? Color(CollectionAccent.oxblood.uiColor) : Color(theme.palette.ink))
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(Color(theme.palette.soft)))
            .overlay(Capsule().stroke(Color(theme.palette.rule), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .contentShape(Capsule())
    }
}

struct CollectionColorGrid: View {
    @Environment(\.appTheme) private var theme
    @Binding var selection: CollectionAccent

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 56), spacing: 10)], spacing: 10) {
            ForEach(CollectionAccent.allCases) { accent in
                let selected = accent == selection
                Button {
                    selection = accent
                } label: {
                    ZStack {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 34, height: 34)
                        if selected {
                            Circle()
                                .stroke(Color(theme.palette.ink), lineWidth: 2)
                                .frame(width: 44, height: 44)
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accent.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("collections.color.\(accent.rawValue)")
            }
        }
        .padding(.vertical, 4)
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}
