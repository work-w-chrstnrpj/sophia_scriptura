import SwiftUI

/// Topic folders for notes, bookmarks, and gleanings. No Folder holds whatever has no topic.
struct CollectionsView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: CollectionsStore
    var notes: NotesSession
    var openNote: (UUID) -> Void
    var openPassage: (SavedPassage) -> Void
    var openCompanion: () -> Void = {}
    var createConversation: () -> UUID? = { nil }
    @State private var searchText = ""
    @State private var searchPresented = false
    @State private var sort: CollectionLibrarySort = .modified
    @State private var showingNewCollection = false
    @State private var editingCollection: StudyCollection?
    @State private var deletingCollection: StudyCollection?
    @State private var showArchivedCollections = false

    private var unfiled: StudyCollection? { store.collection(id: StudyCollection.unfiledID) }

    private var topics: [StudyCollection] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = store.collections.filter { collection in
            guard !collection.isUnfiled, collection.archivedAt == nil else { return false }
            if !trimmed.isEmpty {
                return collection.name.localizedCaseInsensitiveContains(trimmed) ||
                    collection.detail.localizedCaseInsensitiveContains(trimmed)
            }
            return collection.parentID == nil
        }
        switch sort {
        case .modified:
            return candidates.sorted { $0.modifiedAt > $1.modifiedAt }
        case .name:
            return candidates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .itemCount:
            return candidates.sorted {
                store.membershipCount(for: $0.id, includingDescendants: true, notes: notes.snapshot.notes) >
                    store.membershipCount(for: $1.id, includingDescendants: true, notes: notes.snapshot.notes)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    commandBar

                    if let notice = store.notice {
                        Text(notice)
                            .font(.footnote)
                            .foregroundStyle(Color(theme.palette.secondary))
                            .accessibilityIdentifier("collections.notice")
                    }

                    if searchText.isEmpty, let unfiled {
                        folderLink(unfiled) { noFolderCard(unfiled) }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        if topics.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16, alignment: .top)],
                                spacing: 16
                            ) {
                                ForEach(topics) { collection in
                                    folderLink(collection) {
                                        CollectionCard(
                                            collection: collection,
                                            itemCount: store.membershipCount(for: collection.id, includingDescendants: true, notes: notes.snapshot.notes),
                                            subfolderCount: store.children(of: collection.id).count,
                                            kindHints: store.membershipKindHints(
                                                for: collection.id,
                                                notes: notes.snapshot.notes
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityIdentifier("collections.content")
            .appSurface()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewCollection) {
                CollectionEditorSheet(store: store, parentID: nil)
            }
            .sheet(item: $editingCollection) { collection in
                CollectionEditorSheet(store: store, parentID: collection.parentID, editingID: collection.id)
            }
            .overlay {
                if let collection = deletingCollection {
                    StudyCenteredConfirmationOverlay(
                        title: "Delete \(collection.name)?",
                        message: "Subfolders move up one level. Anything that is not in another collection moves to No Folder. Nothing is deleted.",
                        confirmLabel: "Delete Collection",
                        onConfirm: {
                            store.deleteCollection(id: collection.id)
                            deletingCollection = nil
                        },
                        onCancel: { deletingCollection = nil }
                    )
                }
            }
            .animation(.easeOut(duration: 0.18), value: deletingCollection != nil)
            .navigationDestination(isPresented: $showArchivedCollections) {
                StudyArchivedCollectionsView(store: store)
                    .toolbar(.visible, for: .navigationBar)
            }
        }
    }

    private func folderLink<Label: View>(_ collection: StudyCollection, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink {
            CollectionDetailView(
                store: store,
                collectionID: collection.id,
                notes: notes,
                openNote: openNote,
                openPassage: openPassage,
                openCompanion: openCompanion,
                createConversation: createConversation
            )
            .toolbar(.visible, for: .navigationBar)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !collection.isUnfiled {
                Button("Edit Collection", systemImage: "pencil") {
                    editingCollection = collection
                }
                Button("Archive Collection", systemImage: "archivebox") {
                    store.archiveCollection(id: collection.id)
                }
                Button("Delete Collection", systemImage: "trash", role: .destructive) {
                    deletingCollection = collection
                }
            }
        }
        .accessibilityIdentifier("collections.folder.\(collection.name)")
    }

    private func noFolderCard(_ collection: StudyCollection) -> some View {
        let count = store.unfiledCount(notes: notes.snapshot.notes)
        let hints = store.membershipKindHints(for: collection.id, notes: notes.snapshot.notes)
        let subtitle = count == 0
            ? "Everything is filed."
            : "Notes, bookmarks, and gleanings waiting to be filed."
        return CollectionFolderRow(
            accent: .noFolder,
            unfiled: true,
            icon: collection.icon ?? .folder,
            title: "No Folder",
            subtitle: subtitle,
            itemCount: count,
            subfolderCount: 0,
            kindHints: hints
        )
    }

    private var commandBar: some View {
        HStack(spacing: 4) {
            LibraryHeaderTitle(title: "Collections")
                .accessibilityIdentifier("collections.title")

            Spacer(minLength: 12)

            Button { showArchivedCollections = true } label: {
                LibraryHeaderIcon(systemImage: "archivebox")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Archived collections")
            .accessibilityIdentifier("collections.archive")

            if searchPresented {
                searchField
                    .frame(minWidth: 180, idealWidth: 280, maxWidth: 340)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Button { searchPresented = true } label: {
                    LibraryHeaderIcon(systemImage: "magnifyingglass")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search collections")
                .accessibilityIdentifier("collections.searchButton")
            }

            libraryControls
        }
        .animation(.easeInOut(duration: 0.2), value: searchPresented)
    }

    private var searchField: some View {
        LibrarySearchField(
            text: $searchText,
            prompt: "Search collections",
            accessibilityIdentifier: "collections.search",
            dismiss: { searchPresented = false }
        )
    }

    private var libraryControls: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(CollectionLibrarySort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                LibraryHeaderIcon(systemImage: "arrow.up.arrow.down")
            }
            .accessibilityLabel("Sort collections")
            .accessibilityValue(sort.title)
            .accessibilityIdentifier("collections.sort")

            Button {
                showingNewCollection = true
            } label: {
                LibraryHeaderIcon(systemImage: "plus")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Collection")
            .accessibilityIdentifier("collections.newCollection")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: searchText.isEmpty ? "folder.badge.plus" : "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color(theme.palette.secondary))
            Text(searchText.isEmpty ? "Start your first collection" : "No matching collections")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color(theme.palette.ink))
            Text(searchText.isEmpty
                 ? "Gather bookmarks, gleanings, and notes around a theme, book, or question."
                 : "Try a different name or description.")
                .font(.subheadline)
                .foregroundStyle(Color(theme.palette.secondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if searchText.isEmpty {
                Button("New Collection") { showingNewCollection = true }
                    .buttonStyle(CollectionProminentButtonStyle())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color(theme.palette.rule), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        )
    }
}

#Preview {
    CollectionsView(store: .demo(), notes: NotesSession(), openNote: { _ in }, openPassage: { _ in })
}
