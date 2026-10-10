import SwiftUI

struct SettingsArchiveHubView: View {
    @Environment(\.appTheme) private var theme
    var notes: NotesSession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var companion: CompanionSession

    var body: some View {
        List {
            NavigationLink {
                StudyArchivedNotesView(session: notes, collections: collections)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes archive")
                    Text("Click to see all archived notes")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Color(theme.palette.secondary))
                }
            }
            .accessibilityIdentifier("settings.archive.notes")

            NavigationLink {
                StudyArchivedCollectionsView(store: collections)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collections archive")
                    Text("Click to see all archived collections")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Color(theme.palette.secondary))
                }
            }
            .accessibilityIdentifier("settings.archive.collections")

            NavigationLink {
                StudyArchivedConversationsView(session: companion)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversations archive")
                    Text("Click to see all archived conversations")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Color(theme.palette.secondary))
                }
            }
            .accessibilityIdentifier("settings.archive.conversations")
        }
        .navigationTitle("Archive")
        .appSurface()
    }
}

struct StudyArchivedNotesView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject private var protection = ItemProtectionSession.shared
    @Bindable var session: NotesSession
    @ObservedObject var collections: CollectionsStore
    @State private var search = ""
    @State private var searchPresented = false
    @State private var sort = "Modified"
    @State private var tag = ""
    @State private var noteKindFilter: NoteKind?
    @State private var selection = StudySelectionSession()
    @State private var pendingTrashIDs: Set<UUID> = []
    @State private var confirmTrash = false
    private var notes: [NoteDocument] {
        let _ = protection.unlocked
        return session.snapshot.notes.filter {
            $0.isArchived
                && !collections.concealsNote($0.id)
                && (search.isEmpty || (session.isLocked($0) ? $0.title : $0.searchableText).localizedCaseInsensitiveContains(search))
                && (tag.isEmpty || (!session.isLocked($0) && $0.tags.contains(tag)))
                && (noteKindFilter == nil || $0.kind == noteKindFilter)
        }.sorted {
            if sort == "Title", $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if sort == "Created", $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            if sort == "Modified", $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            studyListCommandBar(title: "Archived notes", searchPresented: $searchPresented, search: $search, prompt: "Search archived notes", searchIdentifier: "archive.search") {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(["Modified", "Created", "Title"], id: \.self) { Text($0) }
                    }
                    Picker("Tag", selection: $tag) {
                        Text("All tags").tag("")
                        ForEach(Array(Set(session.snapshot.notes.filter { !session.isLocked($0) && !collections.concealsNote($0.id) }.flatMap(\.tags))).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Type", selection: $noteKindFilter) {
                        Text("All types").tag(NoteKind?.none)
                        ForEach(NoteKind.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(Optional(kind))
                        }
                    }
                } label: {
                    LibraryHeaderIcon(systemImage: "line.3.horizontal.decrease")
                }
                if !notes.isEmpty {
                    StudySelectModeButton(active: selection.active, identifier: "archive.notes.select") {
                        if selection.active { selection.cancel() } else { selection.active = true }
                    }
                }
            }
            if selection.active {
                StudyBulkActionBar(
                    allSelected: selection.allVisibleSelected(notes.map(\.id)),
                    selectedCount: selection.ids.count,
                    primaryTitle: "Unarchive",
                    selectAllIdentifier: "archive.notes.selectAll",
                    primaryIdentifier: "archive.notes.unarchiveSelected",
                    destructiveIdentifier: "archive.notes.deleteSelected",
                    onToggleAll: { selection.toggleVisible(notes.map(\.id)) },
                    onPrimary: { unarchiveSelected() },
                    onDestructive: {
                        pendingTrashIDs = selection.ids
                        confirmTrash = !pendingTrashIDs.isEmpty
                    }
                )
            }
            if notes.isEmpty {
                ContentUnavailableView("No archived notes", systemImage: "archivebox", description: Text("No notes match your filters."))
            } else {
                List(notes) { note in
                    StudySelectableRow(id: note.id, selected: selection.ids.contains(note.id), selectionActive: selection.active) {
                        selection.toggle(note.id)
                    } content: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title).font(.headline)
                            Text(note.kind.displayName).font(.caption).foregroundStyle(.secondary)
                            Text("Archived \(note.archivedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                                .font(.caption2)
                                .foregroundStyle(Color(theme.palette.secondary))
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { session.moveToTrash(note.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        Button { session.unarchive(note.id) } label: {
                            Label("Unarchive", systemImage: "arrow.uturn.backward")
                        }
                        .tint(Color(theme.palette.accent))
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationTitle("Notes archive")
        .navigationBarTitleDisplayMode(.inline)
        .appSurface()
        .alert("Move \(pendingTrashIDs.count) notes to Trash?", isPresented: $confirmTrash) {
            Button("Move to Trash", role: .destructive) { trashSelected() }
            Button("Cancel", role: .cancel) { pendingTrashIDs.removeAll() }
        } message: {
            Text("Trash keeps notes for \(TrashRetention.dayCount) days.")
        }
    }

    private func unarchiveSelected() {
        let ids = selection.ids
        for id in ids { session.unarchive(id) }
        selection.finishAction()
    }

    private func trashSelected() {
        let ids = pendingTrashIDs
        pendingTrashIDs.removeAll()
        for id in ids { session.moveToTrash(id) }
        selection.finishAction()
    }
}

struct StudyArchivedCollectionsView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject private var protection = ItemProtectionSession.shared
    @ObservedObject var store: CollectionsStore
    @State private var search = ""
    @State private var searchPresented = false
    @State private var sort = "Modified"
    @State private var selection = StudySelectionSession()
    @State private var pendingTrashIDs: Set<UUID> = []
    @State private var confirmTrash = false
    private var collections: [StudyCollection] {
        store.archivedCollections.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || (!store.isLocked($0.id) && $0.detail.localizedCaseInsensitiveContains(search))
        }.sorted {
            if sort == "Name", $0.name != $1.name { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return ($0.archivedAt ?? $0.modifiedAt) > ($1.archivedAt ?? $1.modifiedAt)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            studyListCommandBar(title: "Archived collections", searchPresented: $searchPresented, search: $search, prompt: "Search archived collections", searchIdentifier: "archive.search") {
                Menu {
                    Picker("Sort", selection: $sort) {
                        Text("Modified").tag("Modified")
                        Text("Name").tag("Name")
                    }
                } label: {
                    LibraryHeaderIcon(systemImage: "line.3.horizontal.decrease")
                }
                if !collections.isEmpty {
                    StudySelectModeButton(active: selection.active, identifier: "archive.collections.select") {
                        if selection.active { selection.cancel() } else { selection.active = true }
                    }
                }
            }
            if selection.active {
                StudyBulkActionBar(
                    allSelected: selection.allVisibleSelected(collections.map(\.id)),
                    selectedCount: selection.ids.count,
                    primaryTitle: "Unarchive",
                    selectAllIdentifier: "archive.collections.selectAll",
                    primaryIdentifier: "archive.collections.unarchiveSelected",
                    destructiveIdentifier: "archive.collections.deleteSelected",
                    onToggleAll: { selection.toggleVisible(collections.map(\.id)) },
                    onPrimary: {
                        let ids = selection.ids
                        for id in ids { store.unarchiveCollection(id: id) }
                        selection.finishAction()
                    },
                    onDestructive: {
                        pendingTrashIDs = selection.ids
                        confirmTrash = !pendingTrashIDs.isEmpty
                    }
                )
            }
            if collections.isEmpty {
                ContentUnavailableView("No archived collections", systemImage: "archivebox")
            } else {
                List(collections) { collection in
                    StudySelectableRow(id: collection.id, selected: selection.ids.contains(collection.id), selectionActive: selection.active) {
                        selection.toggle(collection.id)
                    } content: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(collection.name).font(.headline)
                            Text(store.isLocked(collection.id) ? "Locked" : collection.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { store.moveCollectionToTrash(id: collection.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        Button { store.unarchiveCollection(id: collection.id) } label: {
                            Label("Unarchive", systemImage: "arrow.uturn.backward")
                        }
                        .tint(Color(theme.palette.accent))
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationTitle("Collections archive")
        .navigationBarTitleDisplayMode(.inline)
        .appSurface()
        .alert("Move \(pendingTrashIDs.count) collections to Trash?", isPresented: $confirmTrash) {
            Button("Move to Trash", role: .destructive) {
                let ids = pendingTrashIDs
                pendingTrashIDs.removeAll()
                for id in ids { store.moveCollectionToTrash(id: id) }
                selection.finishAction()
            }
            Button("Cancel", role: .cancel) { pendingTrashIDs.removeAll() }
        } message: {
            Text("Trash keeps collections until you restore or delete them permanently.")
        }
    }
}

struct StudyArchivedConversationsView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var session: CompanionSession
    @State private var search = ""
    @State private var searchPresented = false
    @State private var selection = StudySelectionSession()
    @State private var pendingTrashIDs: Set<UUID> = []
    @State private var confirmTrash = false
    private var conversations: [CompanionConversation] {
        session.archivedConversations.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            studyListCommandBar(title: "Archived conversations", searchPresented: $searchPresented, search: $search, prompt: "Search conversations", searchIdentifier: "archive.search") {
                if !conversations.isEmpty {
                    StudySelectModeButton(active: selection.active, identifier: "archive.conversations.select") {
                        if selection.active { selection.cancel() } else { selection.active = true }
                    }
                }
            }
            if selection.active {
                StudyBulkActionBar(
                    allSelected: selection.allVisibleSelected(conversations.map(\.id)),
                    selectedCount: selection.ids.count,
                    primaryTitle: "Unarchive",
                    selectAllIdentifier: "archive.conversations.selectAll",
                    primaryIdentifier: "archive.conversations.unarchiveSelected",
                    destructiveIdentifier: "archive.conversations.deleteSelected",
                    onToggleAll: { selection.toggleVisible(conversations.map(\.id)) },
                    onPrimary: {
                        let ids = selection.ids
                        for id in ids { session.unarchiveConversation(id) }
                        selection.finishAction()
                    },
                    onDestructive: {
                        pendingTrashIDs = selection.ids
                        confirmTrash = !pendingTrashIDs.isEmpty
                    }
                )
            }
            if conversations.isEmpty {
                ContentUnavailableView("No archived conversations", systemImage: "archivebox")
            } else {
                List(conversations) { conversation in
                    StudySelectableRow(id: conversation.id, selected: selection.ids.contains(conversation.id), selectionActive: selection.active) {
                        selection.toggle(conversation.id)
                    } content: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title).font(.headline)
                            Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { session.moveConversationToTrash(conversation.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        Button { session.unarchiveConversation(conversation.id) } label: {
                            Label("Unarchive", systemImage: "arrow.uturn.backward")
                        }
                        .tint(Color(theme.palette.accent))
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationTitle("Conversations archive")
        .navigationBarTitleDisplayMode(.inline)
        .appSurface()
        .alert("Move \(pendingTrashIDs.count) conversations to Trash?", isPresented: $confirmTrash) {
            Button("Move to Trash", role: .destructive) {
                let ids = pendingTrashIDs
                pendingTrashIDs.removeAll()
                for id in ids { session.moveConversationToTrash(id) }
                selection.finishAction()
            }
            Button("Cancel", role: .cancel) { pendingTrashIDs.removeAll() }
        } message: {
            Text("Trash keeps conversations until you restore or delete them permanently.")
        }
    }
}

@ViewBuilder
func studyListCommandBar<Filter: View>(
    title: String,
    searchPresented: Binding<Bool>,
    search: Binding<String>,
    prompt: String,
    searchIdentifier: String,
    @ViewBuilder filter: () -> Filter
) -> some View {
    HStack(spacing: 4) {
        Text(title).font(.title2.weight(.semibold))
        Spacer(minLength: 12)
        if searchPresented.wrappedValue {
            LibrarySearchField(text: search, prompt: prompt, accessibilityIdentifier: searchIdentifier, dismiss: { searchPresented.wrappedValue = false })
                .frame(minWidth: 180, idealWidth: 260, maxWidth: 320)
        } else {
            Button { searchPresented.wrappedValue = true } label: {
                LibraryHeaderIcon(systemImage: "magnifyingglass")
            }
            .buttonStyle(.plain)
        }
        filter()
    }
}

struct StudySelectionSession {
    var active = false
    var ids = Set<UUID>()

    mutating func toggle(_ id: UUID) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }

    mutating func toggleVisible(_ visible: [UUID]) {
        if allVisibleSelected(visible) { ids.subtract(visible) } else { ids.formUnion(visible) }
    }

    func allVisibleSelected(_ visible: [UUID]) -> Bool {
        !visible.isEmpty && visible.allSatisfy { ids.contains($0) }
    }

    mutating func cancel() {
        active = false
        ids.removeAll()
    }

    mutating func finishAction() { cancel() }
}

struct StudySelectModeButton: View {
    let active: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(active ? "Done" : "Select", action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier(identifier)
    }
}

struct StudyBulkActionBar: View {
    @Environment(\.appTheme) private var theme
    let allSelected: Bool
    let selectedCount: Int
    let primaryTitle: String
    let selectAllIdentifier: String
    let primaryIdentifier: String
    let destructiveIdentifier: String
    let onToggleAll: () -> Void
    let onPrimary: () -> Void
    let onDestructive: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(allSelected ? "Deselect All" : "Select All", action: onToggleAll)
                .accessibilityIdentifier(selectAllIdentifier)
            Spacer(minLength: 8)
            Text("\(selectedCount) selected")
                .font(.footnote)
                .foregroundStyle(Color(theme.palette.secondary))
            Button(primaryTitle, action: onPrimary)
                .disabled(selectedCount == 0)
                .accessibilityIdentifier(primaryIdentifier)
            Button("Delete", role: .destructive, action: onDestructive)
                .disabled(selectedCount == 0)
                .accessibilityIdentifier(destructiveIdentifier)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct StudySelectableRow<Content: View>: View {
    @Environment(\.appTheme) private var theme
    let id: UUID
    let selected: Bool
    let selectionActive: Bool
    let toggle: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if selectionActive {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color(theme.palette.accent) : Color(theme.palette.secondary))
                    .accessibilityHidden(true)
            }
            content()
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { if selectionActive { toggle() } }
        .accessibilityIdentifier("study.select.\(id.uuidString)")
        .accessibilityAddTraits(selectionActive && selected ? .isSelected : [])
    }
}
