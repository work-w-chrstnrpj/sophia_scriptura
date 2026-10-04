import SwiftUI

struct SettingsArchiveHubView: View {
    @Environment(\.appTheme) private var theme
    var notes: NotesSession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var companion: CompanionSession

    var body: some View {
        List {
            NavigationLink {
                StudyArchivedNotesView(session: notes)
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
    @Bindable var session: NotesSession
    @State private var search = ""
    @State private var searchPresented = false
    @State private var sort = "Modified"
    @State private var tag = ""
    @State private var pendingPermanentDelete: UUID?

    private var notes: [NoteDocument] {
        session.snapshot.notes.filter {
            $0.deletedAt != nil
                && (search.isEmpty || $0.searchableText.localizedCaseInsensitiveContains(search))
                && (tag.isEmpty || $0.tags.contains(tag))
        }.sorted {
            if sort == "Title", $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if sort == "Created", $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            if sort == "Modified", $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            archiveCommandBar(title: "Archived notes", searchPresented: $searchPresented, search: $search, prompt: "Search archived notes") {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(["Modified", "Created", "Title"], id: \.self) { Text($0) }
                    }
                    Picker("Tag", selection: $tag) {
                        Text("All tags").tag("")
                        ForEach(Array(Set(session.snapshot.notes.flatMap(\.tags))).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                } label: {
                    LibraryHeaderIcon(systemImage: "line.3.horizontal.decrease")
                }
            }
            if notes.isEmpty {
                ContentUnavailableView("No archived notes", systemImage: "archivebox", description: Text("Archived notes appear here."))
            } else {
                List(notes) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title).font(.headline)
                        Text(note.kind.displayName).font(.caption).foregroundStyle(.secondary)
                        Text("Archived \(note.deletedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                            .font(.caption2)
                            .foregroundStyle(Color(theme.palette.secondary))
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("Restore") { session.restoreFromArchive(note.id) }
                            .tint(Color(theme.palette.accent))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", role: .destructive) { pendingPermanentDelete = note.id }
                            .tint(.red)
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
            Text("This cannot be undone. Archive keeps a restorable copy; delete removes the note from your library.")
        }
    }
}

struct StudyArchivedCollectionsView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: CollectionsStore
    @State private var search = ""
    @State private var searchPresented = false
    @State private var sort = "Modified"

    private var collections: [StudyCollection] {
        store.archivedCollections.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.detail.localizedCaseInsensitiveContains(search)
        }.sorted {
            if sort == "Name", $0.name != $1.name { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return ($0.archivedAt ?? $0.modifiedAt) > ($1.archivedAt ?? $1.modifiedAt)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            archiveCommandBar(title: "Archived collections", searchPresented: $searchPresented, search: $search, prompt: "Search archived collections") {
                Menu {
                    Picker("Sort", selection: $sort) {
                        Text("Modified").tag("Modified")
                        Text("Name").tag("Name")
                    }
                } label: {
                    LibraryHeaderIcon(systemImage: "line.3.horizontal.decrease")
                }
            }
            if collections.isEmpty {
                ContentUnavailableView("No archived collections", systemImage: "archivebox")
            } else {
                List(collections) { collection in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.name).font(.headline)
                        Text(collection.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Restore") { store.unarchiveCollection(id: collection.id) }
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
    }
}

struct StudyArchivedConversationsView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var session: CompanionSession
    @State private var search = ""
    @State private var searchPresented = false

    private var conversations: [CompanionConversation] {
        session.archivedConversations.filter {
            search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            archiveCommandBar(title: "Archived conversations", searchPresented: $searchPresented, search: $search, prompt: "Search conversations") {
                EmptyView()
            }
            if conversations.isEmpty {
                ContentUnavailableView("No archived conversations", systemImage: "archivebox")
            } else {
                List(conversations) { conversation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conversation.title).font(.headline)
                        Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Restore") { session.unarchiveConversation(conversation.id) }
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
    }
}

@ViewBuilder
private func archiveCommandBar<Filter: View>(
    title: String,
    searchPresented: Binding<Bool>,
    search: Binding<String>,
    prompt: String,
    @ViewBuilder filter: () -> Filter
) -> some View {
    HStack(spacing: 4) {
        Text(title).font(.title2.weight(.semibold))
        Spacer(minLength: 12)
        if searchPresented.wrappedValue {
            LibrarySearchField(text: search, prompt: prompt, accessibilityIdentifier: "archive.search", dismiss: { searchPresented.wrappedValue = false })
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
