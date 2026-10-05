import SwiftUI

/// Extended ink chooser: defaults, presets, black/white, and system color picker.
struct NoteInkColorPalette: View {
    @Environment(\.appTheme) private var theme
    let session: NotesSession
    @Binding var isPresented: Bool
    @State private var pickerColor = Color(uiColor: .label)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Text Color")
                .font(.headline)
                .foregroundStyle(Color(theme.palette.ink))

            LazyVGrid(columns: columns, spacing: 10) {
                paletteSwatch(title: "Auto", colors: [Color(theme.palette.ink)], selected: session.bodyFormatState.usesDefaultInk) {
                    session.formatBodyInkColor(.default)
                }
                paletteSwatch(title: "Black", colors: [.black], selected: session.bodyFormatState.matchesPreset(8)) {
                    session.formatBodyInkColor(.preset(8))
                }
                paletteSwatch(title: "White", colors: [.white], selected: session.bodyFormatState.matchesPreset(9)) {
                    session.formatBodyInkColor(.preset(9))
                }
                ForEach(NoteTextFormatting.InkColor.allCases.filter { $0.rawValue <= 7 }) { preset in
                    paletteSwatch(title: nil, colors: [Color(uiColor: preset.uiColor)], selected: session.bodyFormatState.matchesPreset(preset.rawValue)) {
                        session.formatBodyInkColor(.preset(preset.rawValue))
                    }
                }
            }

            ColorPicker("Custom color", selection: $pickerColor, supportsOpacity: false)
                .foregroundStyle(Color(theme.palette.ink))
                .onChange(of: pickerColor) { _, color in
                    session.formatBodyInkColor(.hex(color.rgbHex))
                }
        }
        .padding(16)
        .frame(width: 300)
        .background(Color(uiColor: .systemBackground))
    }

    private func paletteSwatch(title: String?, colors: [Color], selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(colors.count == 1 ? colors[0] : Color.clear)
                    if colors.count > 1 {
                        Circle()
                            .fill(
                                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    Circle()
                        .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
                }
                .frame(width: 32, height: 32)
                .overlay {
                    if selected {
                        Circle()
                            .strokeBorder(Color(uiColor: .label).opacity(0.6), lineWidth: 2)
                    }
                }
                if let title {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private extension Color {
    var rgbHex: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
