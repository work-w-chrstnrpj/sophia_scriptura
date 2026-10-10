import SwiftUI

enum SettingsDeletionKind: Identifiable {
    case conversations
    case notes
    case collections
    case reminders
    case activities
    case gleanings
    case bookmarks
    case links
    case quizHistory
    case sophyHistory

    var id: String {
        switch self {
        case .conversations: "conversations"
        case .notes: "notes"
        case .collections: "collections"
        case .reminders: "reminders"
        case .activities: "activities"
        case .gleanings: "gleanings"
        case .bookmarks: "bookmarks"
        case .links: "links"
        case .quizHistory: "quizHistory"
        case .sophyHistory: "sophyHistory"
        }
    }

    var buttonTitle: String {
        switch self {
        case .conversations: "Clear all conversations"
        case .notes: "Clear all notes"
        case .collections: "Clear all collections"
        case .reminders: "Clear all reminders"
        case .activities: "Clear all activities"
        case .gleanings: "Clear all gleanings"
        case .bookmarks: "Clear bookmarks"
        case .links: "Clear all links"
        case .quizHistory: "Clear quiz history"
        case .sophyHistory: "Clear Sophy history"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .conversations: "Clear all conversations?"
        case .notes: "Clear all notes?"
        case .collections: "Clear all collections?"
        case .reminders: "Clear all reminders?"
        case .activities: "Clear all activities?"
        case .gleanings: "Clear all gleanings?"
        case .bookmarks: "Clear all bookmarks?"
        case .links: "Clear all links?"
        case .quizHistory: "Clear quiz history?"
        case .sophyHistory: "Clear Sophy history?"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .conversations:
            "Every Companion conversation and its messages will be removed from this iPad. Provider keys are kept."
        case .notes:
            "Every note, including archived notes and their content, will be permanently removed."
        case .collections:
            "Every collection folder is deleted. Notes, bookmarks, gleanings, and links stay in No Folder."
        case .reminders:
            "Every Activity reminder and its scheduled notification will be removed."
        case .activities:
            "Every saved activity record and any in-progress timer draft will be removed."
        case .gleanings:
            "Every gleaning passage and its insight text will be removed."
        case .bookmarks:
            "Every scripture bookmark will be removed."
        case .links:
            "Every saved web link will be removed."
        case .quizHistory:
            "Every Quiz Me session, score, and archived quiz will be removed. Provider keys and quiz defaults are kept."
        case .sophyHistory:
            "Sophy’s command history on this iPad will be removed. Notes, folders, and reminders she already saved stay."
        }
    }
}

struct SettingsDeleteDataHubView: View {
    @Environment(\.appTheme) private var theme
    var notes: NotesSession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var companion: CompanionSession
    @ObservedObject var activity: ActivityStore
    @ObservedObject var sophy: SophySession

    @State private var pendingDeletion: SettingsDeletionKind?
    @State private var confirmEverything = false

    private let kinds: [SettingsDeletionKind] = [
        .conversations, .quizHistory, .notes, .collections, .reminders, .activities, .gleanings, .bookmarks, .links, .sophyHistory
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Each action is permanent on this iPad. Export backups from Settings first when you want a recovery copy.")
                    .font(.footnote)
                    .foregroundStyle(Color(theme.palette.secondary))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    ForEach(Array(kinds.enumerated()), id: \.element.id) { index, kind in
                        deleteRow(kind)
                        if index < kinds.count - 1 {
                            Divider()
                                .overlay(Color(theme.palette.rule))
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(theme.palette.rule), lineWidth: 1))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Delete all data")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(theme.palette.ink))
                    Text("Removes every conversation, quiz, note, collection, reminder, activity, gleaning, bookmark, link, and Sophy history entry in one step. Provider keys stay on this iPad.")
                        .font(.footnote)
                        .foregroundStyle(Color(theme.palette.secondary))
                    Button("Delete all") { confirmEverything = true }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .accessibilityIdentifier("settings.delete.all")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(theme.palette.rule), lineWidth: 1))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("Delete data")
        .navigationBarTitleDisplayMode(.inline)
        .appSurface()
        .overlay {
            if confirmEverything {
                StudyTypedDeletionOverlay(
                    title: "Delete all data?",
                    message: "Every item in the sections above will be permanently removed from this iPad. Provider keys, quiz defaults, and appearance settings stay.",
                    onConfirm: {
                        deleteEverything()
                        confirmEverything = false
                    },
                    onCancel: { confirmEverything = false }
                )
            } else if let kind = pendingDeletion {
                StudyTypedDeletionOverlay(
                    title: kind.confirmationTitle,
                    message: kind.confirmationMessage,
                    onConfirm: {
                        perform(kind)
                        pendingDeletion = nil
                    },
                    onCancel: { pendingDeletion = nil }
                )
            }
        }
        .animation(.easeOut(duration: 0.18), value: pendingDeletion != nil || confirmEverything)
        .accessibilityIdentifier("settings.delete.hub")
    }

    private func deleteRow(_ kind: SettingsDeletionKind) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(kind.buttonTitle)
                .font(.body)
                .foregroundStyle(Color(theme.palette.ink))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Clear") { pendingDeletion = kind }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.leading, 8)
                .accessibilityIdentifier("settings.delete.\(kind.id)")
        }
        .padding(.vertical, 10)
        .frame(minHeight: 52)
    }

    private func deleteEverything() {
        for kind in kinds { perform(kind) }
    }

    private func perform(_ kind: SettingsDeletionKind) {
        switch kind {
        case .conversations:
            companion.removeAllConversations()
        case .quizHistory:
            companion.removeAllQuizHistory()
        case .notes:
            notes.removeAllNotes()
            Task { await notes.save() }
        case .collections:
            collections.removeAllCollections()
        case .reminders:
            activity.removeAllReminders()
        case .activities:
            activity.removeAllActivityRecords()
        case .gleanings:
            collections.removeAllPassages(kind: .gleaning)
        case .bookmarks:
            collections.removeAllPassages(kind: .bookmark)
        case .links:
            collections.removeAllLinks()
        case .sophyHistory:
            Task { await sophy.clearHistory() }
        }
    }
}
