import SwiftUI

struct CompanionScripturePanel: View {
    @ObservedObject var session: CompanionSession
    var expandToTab: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        if let conversationID = session.scripturePanelConversationID,
           let conversation = session.conversations.first(where: { $0.id == conversationID }) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Ask")
                        .font(.headline)
                    Spacer()
                    Button("Expand") {
                        session.selectConversation(conversationID)
                        session.panelExpandedToTab = true
                        expandToTab()
                    }
                    .font(.subheadline)
                    Button {
                        session.scripturePanelConversationID = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(theme.palette.paper))

                Divider().overlay(Color(theme.palette.rule))

                CompanionConversationView(session: session, conversation: conversation, compact: true, pendingNoteSave: .constant(nil))
            }
            .frame(minWidth: 360, maxWidth: 420)
            .background(Color(theme.palette.paper))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color(theme.palette.rule))
                    .frame(width: 1)
                    .ignoresSafeArea()
            }
        }
    }
}
