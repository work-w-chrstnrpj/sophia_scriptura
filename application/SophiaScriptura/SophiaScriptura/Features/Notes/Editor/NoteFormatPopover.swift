import SwiftUI

/// Compact format sheet modeled on Apple Notes (style row, tool clusters, ink colors, lists).
struct NoteFormatPopover: View {
    @Environment(\.appTheme) private var theme
    let session: NotesSession
    @State private var showInkPalette = false

    private let panelWidth: CGFloat = 376

    private var format: NoteTextFormatting.ActiveState { session.bodyFormatState }

    var body: some View {
        VStack(spacing: 0) {
            styleRow
            sectionDivider
            FormatToolCluster {
                FormatToolButton("bold", title: "Bold", isActive: format.bold) { session.formatBody(.bold) }
                FormatToolButton("italic", title: "Italic", isActive: format.italic) { session.formatBody(.italic) }
                FormatToolButton("underline", title: "Underline", isActive: format.underline) { session.formatBody(.underline) }
                FormatToolButton("strikethrough", title: "Strikethrough", isActive: format.strikethrough) { session.formatBody(.strikethrough) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            sectionDivider
            colorRow
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            sectionDivider
            FormatToolCluster {
                FormatToolButton("list.bullet", title: "Bulleted list", isActive: format.bulletList) { session.formatBodyList(.bullet) }
                FormatToolButton("list.number", title: "Numbered list", isActive: format.numberedList) { session.formatBodyList(.numbered) }
                FormatToolButton("decrease.indent", title: "Decrease indent", isActive: false) { session.formatBodyIndent(outdent: true) }
                FormatToolButton("increase.indent", title: "Increase indent", isActive: false) { session.formatBodyIndent(outdent: false) }
                FormatToolButton("text.quote", title: "Block quote", isActive: format.blockQuote) { session.formatBodyBlockQuote() }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: panelWidth)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    private var sectionDivider: some View {
        Divider().overlay(Color(uiColor: .separator).opacity(0.35))
    }

    private var styleRow: some View {
        FormatToolCluster {
            FormatStyleButton(title: "Title", level: 1, activeLevel: format.level, font: .system(size: 15, weight: .bold)) {
                session.formatBody(.level(1))
            }
            FormatStyleButton(title: "Heading", level: 2, activeLevel: format.level, font: .system(size: 14, weight: .bold)) {
                session.formatBody(.level(2))
            }
            FormatStyleButton(title: "Subhead", level: 3, activeLevel: format.level, font: .system(size: 13, weight: .semibold)) {
                session.formatBody(.level(3))
            }
            FormatStyleButton(title: "Body", level: 0, activeLevel: format.level, font: .system(size: 13)) {
                session.formatBody(.level(0))
            }
            FormatStyleButton(title: "Mono", level: 4, activeLevel: format.level, font: .system(size: 12, design: .monospaced)) {
                session.formatBody(.level(4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityIdentifier("notes.format.style")
    }

    private var colorRow: some View {
        HStack(spacing: 0) {
            defaultColorButton
            ForEach(NoteTextFormatting.InkColor.allCases) { preset in
                colorDot(preset)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var inkAccentSelected: Bool {
        !format.colorMixed && !format.usesDefaultInk
    }

    private var defaultColorButton: some View {
        Button {
            showInkPalette = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .quaternarySystemFill))
                Text("A")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(theme.palette.ink))
                VStack {
                    Spacer()
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 16, height: 2.5)
                        .offset(y: -5)
                }
            }
            .frame(width: 34, height: 34)
            .overlay {
                if inkAccentSelected {
                    Circle()
                        .strokeBorder(Color(uiColor: .label).opacity(0.55), lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Text color palette")
        .accessibilityAddTraits(inkAccentSelected ? .isSelected : [])
        .popover(isPresented: $showInkPalette, arrowEdge: .top) {
            NoteInkColorPalette(session: session, isPresented: $showInkPalette)
        }
        .frame(maxWidth: .infinity)
    }

    private func colorDot(_ preset: NoteTextFormatting.InkColor) -> some View {
        let selected = format.matchesPreset(preset.rawValue)
        return Button {
            session.formatBodyInkColor(.preset(preset.rawValue))
        } label: {
            Circle()
                .fill(Color(uiColor: preset.uiColor))
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .strokeBorder(Color(uiColor: .separator).opacity(0.25), lineWidth: 0.5)
                }
                .overlay {
                    if selected {
                        Circle()
                            .strokeBorder(Color(uiColor: .label).opacity(0.55), lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Text color")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .frame(maxWidth: .infinity)
    }
}

private struct FormatToolCluster<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(Color(uiColor: .quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct FormatActiveBackground: View {
    let isActive: Bool

    var body: some View {
        if isActive {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        }
    }
}

private struct FormatStyleButton: View {
    let title: String
    let level: Int
    let activeLevel: Int
    let font: Font
    let action: () -> Void

    private var isActive: Bool { activeLevel >= 0 && activeLevel == level }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(Color(uiColor: isActive ? .label : .secondaryLabel))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background { FormatActiveBackground(isActive: isActive) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct FormatToolButton: View {
    let symbol: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    init(_ symbol: String, title: String, isActive: Bool, action: @escaping () -> Void) {
        self.symbol = symbol
        self.title = title
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: isActive ? .semibold : .medium))
                .foregroundStyle(Color(uiColor: isActive ? .label : .secondaryLabel))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background { FormatActiveBackground(isActive: isActive) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
