import SwiftUI

/// Shared themed chrome for Companion chat and Quiz footers.
struct CompanionStudyChrome<Content: View>: View {
    @Environment(\.appTheme) private var theme
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(12)
        .background(Color(theme.palette.paper))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(theme.palette.rule).opacity(0.55))
                .frame(height: 1)
        }
    }
}

struct CompanionCollapsibleSidebarSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        Section {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("companion.section.\(title)")

            if isExpanded {
                content()
            }
        }
    }
}

struct CompanionPresetPicker: View {
    @ObservedObject var session: CompanionSession
    let conversationID: UUID

    private var conversation: CompanionConversation? {
        session.conversations.first { $0.id == conversationID }
    }

    var body: some View {
        if let conversation {
            VStack(alignment: .leading, spacing: 4) {
                Text("Preset")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Picker("Context preset", selection: Binding(
                    get: { conversation.presetSnapshot.presetID },
                    set: { session.updateConversationPreset(conversationID, presetID: $0) }
                )) {
                    ForEach(session.presetCatalog.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.subheadline)
                .accessibilityIdentifier("companion.preset")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
