import SwiftUI

/// Lifted surface for grouped content. Cards sit one step above the page so sections read as
/// distinct objects instead of grey panels; dark mode relies on tone, not shadow.
private struct StudyCard: ViewModifier {
    @Environment(\.appTheme) private var theme
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(Color(theme.palette.card))
                    .shadow(color: Color(theme.palette.ink).opacity(theme.dark ? 0 : 0.06), radius: 14, y: 5)
            }
            .overlay(shape.stroke(Color(theme.palette.rule).opacity(0.7), lineWidth: 1))
    }
}

/// Groups a header's icon-only commands into one quiet capsule so they read as a toolbar.
private struct LibraryCommandCluster: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 4)
            .background(Color(theme.palette.card), in: Capsule())
            .overlay(Capsule().stroke(Color(theme.palette.rule).opacity(0.7), lineWidth: 1))
    }
}

extension View {
    func studyCard(cornerRadius: CGFloat = 20) -> some View { modifier(StudyCard(cornerRadius: cornerRadius)) }
    func libraryCommandCluster() -> some View { modifier(LibraryCommandCluster()) }
}
