import SwiftUI

struct StudyLinkID: Identifiable { let id: UUID }
struct StudyConversationID: Identifiable { let id: UUID }

/// Shows a saved link and opens it only when the owner asks.
struct StudyLinkSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let link: SavedLink

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    CollectionItemGlyph(kind: .link, accent: .gold, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LINK")
                            .font(.caption.weight(.semibold))
                            .tracking(1.4)
                            .foregroundStyle(CollectionAccent.gold.color)
                        Text(link.title)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                    }
                }
                Text(link.url)
                    .font(.body)
                    .foregroundStyle(Color(theme.palette.secondary))
                    .textSelection(.enabled)
                Button {
                    guard let url = URL(string: link.url) else { return }
                    openURL(url)
                } label: {
                    Label("Open Link", systemImage: "safari")
                }
                .buttonStyle(CollectionProminentButtonStyle(fullWidth: true))
                .accessibilityIdentifier("collections.openLink")
                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .appSurface()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

/// The sample conversation stands in until Companion can open a real one.
struct StudyConversationSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let conversation: StudyConversation
    var seeCompanion: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    CollectionItemGlyph(kind: .conversation, accent: .slate, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CONVERSATION")
                            .font(.caption.weight(.semibold))
                            .tracking(1.4)
                            .foregroundStyle(CollectionAccent.slate.color)
                        Text(conversation.title)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                            .accessibilityIdentifier("collections.conversation.title")
                    }
                }
                Text(conversation.detail)
                    .font(.body)
                    .foregroundStyle(Color(theme.palette.ink))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Nothing here is a real chat yet. Companion will replace this placeholder.")
                    .font(.subheadline)
                    .foregroundStyle(Color(theme.palette.secondary))
                Button {
                    seeCompanion()
                    dismiss()
                } label: {
                    Label("See Companion", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(CollectionProminentButtonStyle(fullWidth: true))
                .accessibilityIdentifier("collections.seeCompanion")
                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .appSurface()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}
