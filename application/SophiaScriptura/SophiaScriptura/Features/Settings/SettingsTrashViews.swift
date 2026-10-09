import SwiftUI

struct SettingsTrashHubView: View {
    @Environment(\.appTheme) private var theme
    var notes: NotesSession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var companion: CompanionSession

    var body: some View {
        List {
            NavigationLink {
                StudyTrashedNotesView(session: notes, collections: collections)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                    Text("Deleted notes are kept for \(TrashRetention.dayCount) days")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Color(theme.palette.secondary))
                }
            }
            .accessibilityIdentifier("settings.trash.notes")

            NavigationLink {
                StudyTrashedCollectionsView(store: collections)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collections")
                    Text("Restore folders or delete them permanently")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Color(theme.palette.secondary))
                }
            }
            .accessibilityIdentifier("settings.trash.collections")

            NavigationLink {
                StudyTrashedConversationsView(session: companion)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversations")
                    Text("Restore chats or delete them permanently")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Color(theme.palette.secondary))
                }
            }
            .accessibilityIdentifier("settings.trash.conversations")
        }
        .navigationTitle("Trash")
        .appSurface()
    }
}

struct StudyTrashedNotesView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject private var protection = ItemProtectionSession.shared
    @Bindable var session: NotesSession
    @ObservedObject var collections: CollectionsStore
    @State private var search = ""
    @State private var searchPresented = false
    @State private var sort = "Deleted"
    @State private var tag = ""
    @State private var pendingPermanentDelete: UUID?

    private var notes: [NoteDocument] {
        session.snapshot.notes.filter {
            $0.isTrashed
                && (search.isEmpty || collections.searchableNoteText($0).localizedCaseInsensitiveContains(search))
                && (tag.isEmpty || (collections.canRevealNoteMetadata($0) && $0.tags.contains(tag)))
        }.sorted {
            if sort == "Title", $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if sort == "Modified", $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return ($0.trashedAt ?? $0.updatedAt) > ($1.trashedAt ?? $1.updatedAt)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            studyListCommandBar(title: "Trashed notes", searchPresented: $searchPresented, search: $search, prompt: "Search trashed notes", searchIdentifier: "trash.search") {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(["Deleted", "Modified", "Title"], id: \.self) { Text($0) }
                    }
                    Picker("Tag", selection: $tag) {
                        Text("All tags").tag("")
                        ForEach(collections.visibleNoteTags(in: session.snapshot.notes.filter(\.isTrashed)), id: \.self) { Text($0).tag($0) }
                    }
                } label: {
                    LibraryHeaderIcon(systemImage: "line.3.horizontal.decrease")
                }
            }
            if notes.isEmpty {
                ContentUnavailableView("Trash is empty", systemImage: "trash", description: Text("Deleted notes stay here for \(TrashRetention.dayCount) days."))
            } else {
                List(notes) { note in
                    TrashedStudyRow(
                        title: note.title,
                        subtitle: note.kind.displayName,
                        trashedAt: note.trashedAt,
                        onRestore: { session.restoreFromTrash(note.id) },
                        onDelete: { pendingPermanentDelete = note.id }
                    )
                }
                .listStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationTitle("Notes trash")
        .navigationBarTitleDisplayMode(.inline)
        .appSurface()
        .alert("Delete this note permanently?", isPresented: Binding(
            get: { pendingPermanentDelete != nil },
            set: { if !$0 { pendingPermanentDelete = nil } }
        )) {
            Button("Delete Permanently", role: .destructive) {
                if let id = pendingPermanentDelete { session.permanentlyDelete(id) }
                pendingPermanentDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingPermanentDelete = nil }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

struct StudyTrashedCollectionsView: View {
    @ObservedObject private var protection = ItemProtectionSession.shared
    @ObservedObject var store: CollectionsStore
    @State private var search = ""
    @State private var searchPresented = false
    @State private var sort = "Deleted"
    @State private var pendingPermanentDelete: UUID?

    private var collections: [StudyCollection] {
        store.trashedCollections.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || (!store.isLocked($0.id) && $0.detail.localizedCaseInsensitiveContains(search))
        }.sorted {
            if sort == "Name", $0.name != $1.name { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return ($0.trashedAt ?? $0.modifiedAt) > ($1.trashedAt ?? $1.modifiedAt)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            studyListCommandBar(title: "Trashed collections", searchPresented: $searchPresented, search: $search, prompt: "Search trashed collections", searchIdentifier: "trash.search") {
                Menu {
                    Picker("Sort", selection: $sort) {
                        Text("Deleted").tag("Deleted")
                        Text("Name").tag("Name")
                    }
                } label: {
                    LibraryHeaderIcon(systemImage: "line.3.horizontal.decrease")
                }
            }
            if collections.isEmpty {
                ContentUnavailableView("Trash is empty", systemImage: "trash")
            } else {
                List(collections) { collection in
                    TrashedStudyRow(
                        title: collection.name,
                        subtitle: store.isLocked(collection.id) ? "Locked" : collection.detail,
                        trashedAt: collection.trashedAt,
                        onRestore: { store.restoreCollectionFromTrash(id: collection.id) },
                        onDelete: { pendingPermanentDelete = collection.id }
                    )
                }
                .listStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationTitle("Collections trash")
        .navigationBarTitleDisplayMode(.inline)
        .appSurface()
        .alert("Delete this collection permanently?", isPresented: Binding(
            get: { pendingPermanentDelete != nil },
            set: { if !$0 { pendingPermanentDelete = nil } }
        )) {
            Button("Delete Permanently", role: .destructive) {
                if let id = pendingPermanentDelete { store.permanentlyDeleteCollection(id: id) }
                pendingPermanentDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingPermanentDelete = nil }
        } message: {
            Text("Subfolders move up one level. Items not in another collection move to No Folder. This cannot be undone.")
        }
    }
}

struct StudyTrashedConversationsView: View {
    @ObservedObject var session: CompanionSession
    @State private var search = ""
    @State private var searchPresented = false
    @State private var pendingPermanentDelete: UUID?

    private var conversations: [CompanionConversation] {
        session.trashedConversations.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            studyListCommandBar(title: "Trashed conversations", searchPresented: $searchPresented, search: $search, prompt: "Search trashed conversations", searchIdentifier: "trash.search") {
                EmptyView()
            }
            if conversations.isEmpty {
                ContentUnavailableView("Trash is empty", systemImage: "trash")
            } else {
                List(conversations) { conversation in
                    TrashedStudyRow(
                        title: conversation.title,
                        subtitle: conversation.updatedAt.formatted(date: .abbreviated, time: .shortened),
                        trashedAt: conversation.trashedAt,
                        onRestore: { session.restoreConversationFromTrash(conversation.id) },
                        onDelete: { pendingPermanentDelete = conversation.id }
                    )
                }
                .listStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationTitle("Conversations trash")
        .navigationBarTitleDisplayMode(.inline)
        .appSurface()
        .alert("Delete this conversation permanently?", isPresented: Binding(
            get: { pendingPermanentDelete != nil },
            set: { if !$0 { pendingPermanentDelete = nil } }
        )) {
            Button("Delete Permanently", role: .destructive) {
                if let id = pendingPermanentDelete { session.permanentlyDeleteConversation(id) }
                pendingPermanentDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingPermanentDelete = nil }
        } message: {
            Text("This removes the conversation and its messages and cannot be undone.")
        }
    }
}

private struct TrashedStudyRow: View {
    let title: String
    let subtitle: String
    let trashedAt: Date?
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            if let trashedAt {
                let expiry = TrashRetention.permanentDeleteAfter(trashedAt)
                let days = TrashRetention.daysRemaining(until: expiry)
                Text("Permanent delete in \(days) day\(days == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            Button(action: onRestore) {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
            .tint(.accentColor)
        }
    }
}
