import SwiftUI
import UIKit

struct LibraryHeaderTitle: View {
    @Environment(\.appTheme) private var theme
    let title: String

    var body: some View {
        Text(title)
            .font(Font(UIFontMetrics(forTextStyle: .title2).scaledFont(
                for: ScriptureFonts.font(theme.appearance.headingFamily, size: 24)
            )))
            .foregroundStyle(Color(theme.palette.ink))
    }
}

/// Shared, minimal controls for library headers such as Notes and Collections.
struct LibrarySearchField: View {
    @Environment(\.appTheme) private var theme
    @Binding var text: String
    let prompt: String
    let accessibilityIdentifier: String
    let dismiss: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(Color(theme.palette.secondary))
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .submitLabel(.search)
                .focused($focused)
                .accessibilityIdentifier(accessibilityIdentifier)

            Button {
                text = ""
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color(theme.palette.secondary))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close search")
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1)
        }
        .onAppear { focused = true }
    }
}

struct LibraryHeaderIcon: View {
    @Environment(\.appTheme) private var theme
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(Color(theme.palette.ink))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}
