import SwiftUI

struct SettingsTrashHubView: View {
    @Environment(\.appTheme) private var theme
    var notes: NotesSession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var companion: CompanionSession

    var body: some View {
        List {
            NavigationLink("Plans") { PlanLifecycleLibrary(store: collections, notes: notes, archived: false) }
            NavigationLink("Points to Ponder") {
                StudyTrashedPointsView(store: collections)
            }
            .accessibilityIdentifier("settings.trash.points")
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
    @ObservedObject private var protection = ItemProtectionSession.shared
    @Bindable var session: NotesSession
    @ObservedObject var collections: CollectionsStore
    @State private var search = ""
    @State private var searchPresented = false
    @State private var sort = "Deleted"
    @State private var tag = ""
    @State private var pendingPermanentDelete: UUID?
    @State private var selection = StudySelectionSession()
    @State private var pendingBulkDelete: Set<UUID> = []
    @State private var confirmBulkDelete = false

    private var notes: [NoteDocument] {
        session.snapshot.notes.filter {
            $0.isTrashed && collections.accessAllowed($0.access)
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
                if !notes.isEmpty {
                    StudySelectModeButton(active: selection.active, identifier: "trash.notes.select") {
                        if selection.active { selection.cancel() } else { selection.active = true }
                    }
                }
            }
            if selection.active {
                StudyBulkActionBar(
                    allSelected: selection.allVisibleSelected(notes.map(\.id)),
                    selectedCount: selection.ids.count,
                    primaryTitle: "Restore",
                    selectAllIdentifier: "trash.notes.selectAll",
                    primaryIdentifier: "trash.notes.restoreSelected",
                    destructiveIdentifier: "trash.notes.deleteSelected",
                    onToggleAll: { selection.toggleVisible(notes.map(\.id)) },
                    onPrimary: {
                        let ids = selection.ids
                        for id in ids { session.restoreFromTrash(id) }
                        selection.finishAction()
                    },
                    onDestructive: {
                        pendingBulkDelete = selection.ids
                        confirmBulkDelete = !pendingBulkDelete.isEmpty
                    }
                )
            }
            if notes.isEmpty {
                ContentUnavailableView("Trash is empty", systemImage: "trash", description: Text("Deleted notes stay here for \(TrashRetention.dayCount) days."))
            } else {
                List(notes) { note in
                    StudySelectableRow(id: note.id, selected: selection.ids.contains(note.id), selectionActive: selection.active) {
                        selection.toggle(note.id)
                    } content: {
                        TrashedStudyRow(
                        title: note.title,
                        subtitle: note.kind.displayName,
                        trashedAt: note.trashedAt,
                        onRestore: { session.restoreFromTrash(note.id) },
                        onDelete: { pendingPermanentDelete = note.id }
                    )
                    }
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
        .alert("Delete \(pendingBulkDelete.count) notes permanently?", isPresented: $confirmBulkDelete) {
            Button("Delete Permanently", role: .destructive) {
                let ids = pendingBulkDelete
                pendingBulkDelete.removeAll()
                for id in ids { session.permanentlyDelete(id) }
                selection.finishAction()
            }
            Button("Cancel", role: .cancel) { pendingBulkDelete.removeAll() }
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
    @State private var selection = StudySelectionSession()
    @State private var pendingBulkDelete: Set<UUID> = []
    @State private var confirmBulkDelete = false

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
                if !collections.isEmpty {
                    StudySelectModeButton(active: selection.active, identifier: "trash.collections.select") {
                        if selection.active { selection.cancel() } else { selection.active = true }
                    }
                }
            }
            if selection.active {
                StudyBulkActionBar(
                    allSelected: selection.allVisibleSelected(collections.map(\.id)),
                    selectedCount: selection.ids.count,
                    primaryTitle: "Restore",
                    selectAllIdentifier: "trash.collections.selectAll",
                    primaryIdentifier: "trash.collections.restoreSelected",
                    destructiveIdentifier: "trash.collections.deleteSelected",
                    onToggleAll: { selection.toggleVisible(collections.map(\.id)) },
                    onPrimary: {
                        let ids = selection.ids
                        for id in ids { store.restoreCollectionFromTrash(id: id) }
                        selection.finishAction()
                    },
                    onDestructive: {
                        pendingBulkDelete = selection.ids
                        confirmBulkDelete = !pendingBulkDelete.isEmpty
                    }
                )
            }
            if collections.isEmpty {
                ContentUnavailableView("Trash is empty", systemImage: "trash")
            } else {
                List(collections) { collection in
                    StudySelectableRow(id: collection.id, selected: selection.ids.contains(collection.id), selectionActive: selection.active) {
                        selection.toggle(collection.id)
                    } content: {
                        TrashedStudyRow(
                            title: collection.name,
                            subtitle: store.isLocked(collection.id) ? "Locked" : collection.detail,
                            trashedAt: collection.trashedAt,
                            onRestore: { store.restoreCollectionFromTrash(id: collection.id) },
                            onDelete: { pendingPermanentDelete = collection.id }
                        )
                    }
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
            Text("For a deleted Plan folder, this also permanently removes its Plan and deleted folder tree. Shared items remain in their other locations. Ordinary collection subfolders move up one level. This cannot be undone.")
        }
        .alert("Delete \(pendingBulkDelete.count) collections permanently?", isPresented: $confirmBulkDelete) {
            Button("Delete Permanently", role: .destructive) {
                let ids = pendingBulkDelete
                pendingBulkDelete.removeAll()
                for id in ids { store.permanentlyDeleteCollection(id: id) }
                selection.finishAction()
            }
            Button("Cancel", role: .cancel) { pendingBulkDelete.removeAll() }
        } message: {
            Text("For a deleted Plan folder, this also permanently removes its Plan and deleted folder tree. Shared items remain in their other locations. Ordinary collection subfolders move up one level. This cannot be undone.")
        }
    }
}

struct StudyTrashedConversationsView: View {
    @ObservedObject var session: CompanionSession
    @State private var search = ""
    @State private var searchPresented = false
    @State private var pendingPermanentDelete: UUID?
    @State private var selection = StudySelectionSession()
    @State private var pendingBulkDelete: Set<UUID> = []
    @State private var confirmBulkDelete = false

    private var conversations: [CompanionConversation] {
        session.trashedConversations.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            studyListCommandBar(title: "Trashed conversations", searchPresented: $searchPresented, search: $search, prompt: "Search trashed conversations", searchIdentifier: "trash.search") {
                if !conversations.isEmpty {
                    StudySelectModeButton(active: selection.active, identifier: "trash.conversations.select") {
                        if selection.active { selection.cancel() } else { selection.active = true }
                    }
                }
            }
            if selection.active {
                StudyBulkActionBar(
                    allSelected: selection.allVisibleSelected(conversations.map(\.id)),
                    selectedCount: selection.ids.count,
                    primaryTitle: "Restore",
                    selectAllIdentifier: "trash.conversations.selectAll",
                    primaryIdentifier: "trash.conversations.restoreSelected",
                    destructiveIdentifier: "trash.conversations.deleteSelected",
                    onToggleAll: { selection.toggleVisible(conversations.map(\.id)) },
                    onPrimary: {
                        let ids = selection.ids
                        for id in ids { session.restoreConversationFromTrash(id) }
                        selection.finishAction()
                    },
                    onDestructive: {
                        pendingBulkDelete = selection.ids
                        confirmBulkDelete = !pendingBulkDelete.isEmpty
                    }
                )
            }
            if conversations.isEmpty {
                ContentUnavailableView("Trash is empty", systemImage: "trash")
            } else {
                List(conversations) { conversation in
                    StudySelectableRow(id: conversation.id, selected: selection.ids.contains(conversation.id), selectionActive: selection.active) {
                        selection.toggle(conversation.id)
                    } content: {
                        TrashedStudyRow(
                            title: conversation.title,
                            subtitle: conversation.updatedAt.formatted(date: .abbreviated, time: .shortened),
                            trashedAt: conversation.trashedAt,
                            onRestore: { session.restoreConversationFromTrash(conversation.id) },
                            onDelete: { pendingPermanentDelete = conversation.id }
                        )
                    }
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
        .alert("Delete \(pendingBulkDelete.count) conversations permanently?", isPresented: $confirmBulkDelete) {
            Button("Delete Permanently", role: .destructive) {
                let ids = pendingBulkDelete
                pendingBulkDelete.removeAll()
                for id in ids { session.permanentlyDeleteConversation(id) }
                selection.finishAction()
            }
            Button("Cancel", role: .cancel) { pendingBulkDelete.removeAll() }
        } message: {
            Text("This removes the conversations and their messages and cannot be undone.")
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

struct StudyTrashedPointsView: View {
    @ObservedObject var store: CollectionsStore
    @State private var pendingDelete: UUID?

    var body: some View {
        List(store.pointsToPonder.filter { $0.trashedAt != nil }) { point in
            TrashedStudyRow(title: point.question, subtitle: "Point to Ponder", trashedAt: point.trashedAt,
                onRestore: { store.restorePoint(point.id) }, onDelete: { pendingDelete = point.id })
        }
        .overlay { if !store.pointsToPonder.contains(where: { $0.trashedAt != nil }) { ContentUnavailableView("Trash is empty", systemImage: "trash") } }
        .navigationTitle("Points to Ponder trash")
        .appSurface()
        .alert("Delete this question permanently?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete Permanently", role: .destructive) {
                if let id = pendingDelete { store.permanentlyDeletePoint(id) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { Text("This cannot be undone.") }
    }
}
