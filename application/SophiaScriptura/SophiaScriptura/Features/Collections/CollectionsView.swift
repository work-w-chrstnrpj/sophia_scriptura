import SwiftUI

/// Topic folders for notes, bookmarks, and gleanings. No Folder holds whatever has no topic.
struct CollectionsView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject private var protection = ItemProtectionSession.shared
    @ObservedObject var store: CollectionsStore
    var notes: NotesSession
    var reader: ReaderSession? = nil
    var isTabActive = true
    var openNote: (UUID, UUID) -> Void
    var openPassage: (SavedPassage) -> Void
    var openAnnotation: (SavedAnnotation) -> Void = { _ in }
    var annotationSnapshot: AnnotationSnapshot?
    var bookTitleForCode: (String) -> String = { $0 }
    var openCompanion: () -> Void = {}
    var createConversation: () -> UUID? = { nil }
    @State private var sophyFolder: StudyCollection?
    @State private var searchText = ""
    @State private var searchPresented = false
    @State private var sort: CollectionLibrarySort = .modified
    @State private var showingNewCollection = false
    @State private var editingCollection: StudyCollection?
    @State private var movingCollection: StudyCollection?
    @State private var deletingCollection: StudyCollection?
    @State private var showArchivedCollections = false

    private var unfiled: StudyCollection? { store.collection(id: StudyCollection.unfiledID) }

    private var topics: [StudyCollection] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = store.collections.filter { collection in
            guard !collection.isUnfiled, collection.archivedAt == nil else { return false }
            if !trimmed.isEmpty {
                return collection.name.localizedCaseInsensitiveContains(trimmed) ||
                    (!store.isLocked(collection.id) && collection.detail.localizedCaseInsensitiveContains(trimmed))
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
                store.membershipCount(for: $0.id, includingDescendants: true, notes: notes.snapshot.notes, annotationSnapshot: annotationSnapshot) >
                    store.membershipCount(for: $1.id, includingDescendants: true, notes: notes.snapshot.notes, annotationSnapshot: annotationSnapshot)
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
                                            itemCount: store.membershipCount(for: collection.id, includingDescendants: true, notes: notes.snapshot.notes, annotationSnapshot: annotationSnapshot),
                                            subfolderCount: store.children(of: collection.id).count,
                                            kindHints: store.membershipKindHints(
                                                for: collection.id,
                                                notes: notes.snapshot.notes,
                                                annotationSnapshot: annotationSnapshot
                                            ),
                                            inheritedLocked: store.isLocked(collection.id)
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
            .sheet(item: $movingCollection) { collection in
                CollectionFolderMoveSheet(store: store, folderID: collection.id)
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
            .fullScreenCover(isPresented: Binding(
                get: { reader != nil && notes.selectedNoteID != nil && notes.openingCollectionID != nil },
                set: { if !$0 { notes.flushSurface?(); notes.selectedNoteID = nil } }
            )) {
                if let reader {
                    NavigationStack {
                        NoteEditorView(session: notes, reader: reader, collections: store)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Back") { notes.flushSurface?(); notes.selectedNoteID = nil }
                                        .accessibilityIdentifier("collections.note.back")
                                }
                            }
                    }
                }
            }
            .navigationDestination(item: $sophyFolder) { folder in
                CollectionDetailView(
                    store: store,
                    collectionID: folder.id,
                    notes: notes,
                    openNote: openNote,
                    openPassage: openPassage,
                    openAnnotation: openAnnotation,
                    annotationSnapshot: annotationSnapshot,
                    bookTitleForCode: bookTitleForCode,
                    openCompanion: openCompanion,
                    createConversation: createConversation
                )
            }
            .onChange(of: store.sophyOpenCollectionID) { _, id in
                guard let id, !store.sophyFolderIsProtected(id), let folder = store.collection(id: id), folder.isActiveInLibrary else { return }
                sophyFolder = folder; store.sophyOpenCollectionID = nil
            }
            .navigationDestination(isPresented: $showArchivedCollections) {
                StudyArchivedCollectionsView(store: store)
                    .toolbar(.visible, for: .navigationBar)
            }
        }
        .onChange(of: protection.unlocked) { _, _ in
            if let collection = editingCollection, store.isLocked(collection.id) { editingCollection = nil }
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
                openAnnotation: openAnnotation,
                annotationSnapshot: annotationSnapshot,
                bookTitleForCode: bookTitleForCode,
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
                if !store.isLocked(collection.id) {
                    Button("Edit Collection", systemImage: "pencil") { editingCollection = collection }
                    Button("Move Collection", systemImage: "folder") { movingCollection = collection }
                }
                ItemProtectionContextActions(
                    noun: "Collection",
                    protectionID: collection.protectionID,
                    locked: store.isLocked(collection.id),
                    protect: { Task { await store.setProtected(collection.id, enabled: true) } },
                    lock: { store.protection.lock([.collections]) },
                    unlock: { Task { await store.requestAccess(collection.id) } },
                    remove: { Task { await store.setProtected(collection.id, enabled: false) } }
                )
                Button("Archive Collection", systemImage: "archivebox") {
                    store.archiveCollection(id: collection.id)
                }
                Button("Delete Collection", systemImage: "trash", role: .destructive) {
                    deletingCollection = collection
                }
            }
        }
        .collectionFolderDragAndDrop(collection, store: store)
        .accessibilityIdentifier("collections.folder.\(collection.name)")
    }

    private func noFolderCard(_ collection: StudyCollection) -> some View {
        let count = store.unfiledCount(notes: notes.snapshot.notes, annotationSnapshot: annotationSnapshot)
        let hints = store.membershipKindHints(for: collection.id, notes: notes.snapshot.notes, annotationSnapshot: annotationSnapshot)
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

            ProtectionControls(domains: [.collections], available: store.collections.contains { $0.protectionID != nil && !$0.isUnfiled }).labelStyle(.iconOnly)

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
    CollectionsView(store: .demo(), notes: NotesSession(), openNote: { _, _ in }, openPassage: { _ in })
}
