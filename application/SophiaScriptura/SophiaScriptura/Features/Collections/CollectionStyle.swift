import SwiftUI
import UIKit

extension CollectionAccent {
    private var components: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        switch self {
        case .preset: return (0.45, 0.45, 0.45)
        case .oxblood: return (0.45, 0.16, 0.15)
        case .brick: return (0.52, 0.22, 0.20)
        case .rose: return (0.58, 0.25, 0.32)
        case .blush: return (0.68, 0.46, 0.50)
        case .terracotta: return (0.64, 0.32, 0.19)
        case .copper: return (0.58, 0.36, 0.24)
        case .gold: return (0.63, 0.44, 0.16)
        case .honey: return (0.70, 0.52, 0.22)
        case .mustard: return (0.66, 0.54, 0.18)
        case .wheat: return (0.68, 0.60, 0.36)
        case .olive: return (0.45, 0.48, 0.21)
        case .moss: return (0.38, 0.46, 0.28)
        case .sage: return (0.28, 0.43, 0.34)
        case .fern: return (0.30, 0.50, 0.36)
        case .teal: return (0.17, 0.41, 0.42)
        case .sea: return (0.20, 0.46, 0.48)
        case .slate: return (0.25, 0.34, 0.43)
        case .navy: return (0.18, 0.24, 0.38)
        case .indigo: return (0.30, 0.30, 0.52)
        case .plum: return (0.42, 0.24, 0.43)
        case .lavender: return (0.52, 0.44, 0.58)
        case .orchid: return (0.50, 0.30, 0.52)
        case .umber: return (0.42, 0.31, 0.22)
        case .sand: return (0.62, 0.52, 0.40)
        case .taupe: return (0.48, 0.42, 0.36)
        case .stone: return (0.46, 0.46, 0.44)
        case .pewter: return (0.40, 0.42, 0.44)
        case .fog: return (0.54, 0.55, 0.56)
        }
    }

    func resolvedUIColor(in theme: AppTheme) -> UIColor {
        self == .preset ? theme.palette.accent : uiColor
    }

    func resolvedColor(in theme: AppTheme) -> Color {
        Color(uiColor: resolvedUIColor(in: theme))
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
        case .annotation: return CollectionAccent.plum.color
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
    @Environment(\.appTheme) private var theme
    let accent: CollectionAccent
    var unfiled = false
    var icon: CollectionIcon = .folder
    var size: CGFloat = 44

    var body: some View {
        let tint = accent.resolvedColor(in: theme)
        Image(systemName: unfiled ? "tray.fill" : icon.symbolName)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct CollectionIconGrid: View {
    @Environment(\.appTheme) private var theme
    @Binding var selection: CollectionIcon

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52, maximum: 60), spacing: 10)], spacing: 10) {
            ForEach(CollectionIcon.allCases) { icon in
                let selected = icon == selection
                Button { selection = icon } label: {
                    Image(systemName: icon.symbolName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(selected ? Color(theme.palette.paper) : Color(theme.palette.ink))
                        .frame(width: 44, height: 44)
                        .background(selected ? Color(theme.palette.accent) : Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color(theme.palette.rule), lineWidth: selected ? 0 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("collections.icon.\(icon.rawValue)")
            }
        }
        .padding(.vertical, 4)
    }
}

struct CollectionItemGlyph: View {
    @Environment(\.appTheme) private var theme
    let kind: CollectionArtifactKind
    let accent: CollectionAccent
    var size: CGFloat = 40

    var body: some View {
        let tint = accent.resolvedColor(in: theme)
        Image(systemName: kind.symbolName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Filled capsule whose label always uses the paper color against the theme accent.
struct CollectionProminentButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var fullWidth = false
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(theme.palette.paper))
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 48)
            .background(
                Capsule().fill(
                    destructive ? Color(CollectionAccent.oxblood.uiColor) : Color(theme.palette.accent)
                )
            )
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
                let swatch = accent == .preset ? Color(theme.palette.accent) : accent.color
                Button {
                    selection = accent
                } label: {
                    ZStack {
                        Circle()
                            .fill(swatch)
                            .frame(width: 34, height: 34)
                        if accent == .preset {
                            Circle()
                                .strokeBorder(Color(theme.palette.ink).opacity(0.25), lineWidth: 1)
                                .frame(width: 34, height: 34)
                        }
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
