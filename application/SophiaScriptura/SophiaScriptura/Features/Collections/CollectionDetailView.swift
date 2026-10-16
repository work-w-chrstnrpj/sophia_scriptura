import SwiftUI

struct CollectionDetailView: View {
    private struct Organize: Identifiable {
        let artifact: CollectionArtifact
        let mode: CollectionDestinationPicker.Mode
        var id: String { "\(artifact.id)-\(mode == .assign ? "assign" : "move")" }
    }

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var protection = ItemProtectionSession.shared
    @ObservedObject var store: CollectionsStore
    let collectionID: UUID
    var notes: NotesSession
    var openNote: (UUID, UUID) -> Void
    var openPassage: (SavedPassage) -> Void
    var openAnnotation: (SavedAnnotation) -> Void = { _ in }
    var annotationSnapshot: AnnotationSnapshot?
    var bookTitleForCode: (String) -> String = { $0 }
    var openCompanion: () -> Void = {}
    var createConversation: () -> UUID? = { nil }
    var exploreQuestion: (String) -> UUID? = { _ in nil }
    var trashConversation: (UUID) -> Void = { _ in }
    var books: [ScriptureBook] = []

    @AppStorage("collections.subfolder.arrange") private var arrangeStore = ""

    @AppStorage("collections.material.cardFolders") private var cardFolderIDs = ""
    private var cards: Bool { cardFolderIDs.split(separator: ",").contains(Substring(collectionID.uuidString)) }
    private func setCards(_ enabled: Bool) {
        var ids = Set(cardFolderIDs.split(separator: ",").map(String.init))
        if enabled { ids.insert(collectionID.uuidString) } else { ids.remove(collectionID.uuidString) }
        cardFolderIDs = ids.sorted().joined(separator: ",")
    }

    @State private var filter: CollectionArtifactFilter = .all
    @State private var sort: CollectionArtifactSort = .modified
    @State private var includeDescendants = false
    @State private var showingPicker = false
    @State private var showingSubfolderEditor = false
    @State private var showingEditor = false
    @State private var showingDeleteAlert = false
    @State private var pointCard: PointToPonder?
    @State private var passageCard: UUID?
    @State private var editingLink: SavedLink?
    @State private var linkCard: UUID?
    @State private var conversationCard: UUID?
    @State private var organizing: Organize?
    @State private var pendingDeletion: CollectionArtifact?
    @State private var duplicatingCollection: StudyCollection?
    @State private var editingSubfolder: StudyCollection?
    @State private var movingSubfolder: StudyCollection?
    @State private var deletingSubfolder: StudyCollection?
    @State private var libraryJournalField: LibraryJournalFieldContext?

    private var currentCollection: StudyCollection? { store.collection(id: collectionID) }
    private var isUnfiled: Bool { currentCollection?.isUnfiled == true }

    private func displayAccent(for collection: StudyCollection) -> CollectionAccent {
        store.isLocked(collection.id) ? .stone : collection.accent
    }

    private var visibleArtifacts: [CollectionArtifact] {
        let kind = filter.kind
        let filtered = store.presentedArtifacts(
            for: collectionID,
            includingDescendants: includeDescendants,
            notes: notes.snapshot.notes,
            annotationSnapshot: annotationSnapshot
        )
        .filter { kind == nil || $0.kind == kind }

        switch sort {
        case .modified:
            return filtered.sorted { $0.modifiedAt > $1.modifiedAt }
        case .title:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    var body: some View {
        Group {
            if let collection = currentCollection {
                if store.isLocked(collectionID) {
                    VStack(spacing: 20) {
                        ContentUnavailableView("Locked Collection", systemImage: "lock.fill", description: Text("Unlock Collections to view this folder."))
                        Button("Unlock Collection") { Task { await store.requestAccess(collectionID) } }
                    }.navigationTitle(collection.name)
                } else { collectionDetail(collection) }
            } else {
                ContentUnavailableView("Collection unavailable", systemImage: "folder.badge.questionmark")
            }
        }
        .task { if store.isLocked(collectionID) { await store.requestAccess(collectionID) } }
        .onChange(of: protection.unlocked) { _, _ in
            if store.isLocked(collectionID) { showingPicker = false; showingEditor = false; showingSubfolderEditor = false; pointCard = nil; passageCard = nil; linkCard = nil; editingLink = nil; conversationCard = nil; organizing = nil; editingSubfolder = nil }
        }
    }

    private func collectionContent(_ collection: StudyCollection) -> some View {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        header(collection)
                        if !collection.isUnfiled { subfolders(collection) }
                        studyMaterial(collection)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("collections.detailContent")
                .appSurface()
                .navigationTitle(collection.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar(collection) }
    }

    private func collectionSheets(_ collection: StudyCollection) -> some View {
                collectionContent(collection)
                .sheet(item: $movingSubfolder) { folder in
                    CollectionFolderMoveSheet(store: store, folderID: folder.id)
                }
                .sheet(isPresented: $showingPicker) {
                    CollectionArtifactPicker(
                        store: store,
                        collectionID: collectionID,
                        notes: notes,
                        annotationSnapshot: annotationSnapshot,
                        bookTitleForCode: bookTitleForCode,
                        openNote: { openNote($0, collectionID) },
                        openCompanion: openCompanion,
                        createConversation: createConversation
                    )
                }
                .sheet(item: $duplicatingCollection) { folder in
                    CollectionDuplicateSheet(store: store, folderID: folder.id)
                }
                .sheet(isPresented: $showingEditor) {
                    CollectionEditorSheet(store: store, parentID: collection.parentID, editingID: collectionID)
                }
                .sheet(isPresented: $showingSubfolderEditor) {
                    CollectionEditorSheet(store: store, parentID: collectionID)
                }
                .sheet(item: $editingSubfolder) { subfolder in
                    CollectionEditorSheet(store: store, parentID: subfolder.parentID, editingID: subfolder.id)
                }
                .modifier(PointToPonderFlow(store: store, notes: notes, point: pointCard, collectionID: collectionID,
                    openNote: { openNote($0, collectionID) }, exploreQuestion: exploreQuestion, close: { pointCard = nil }))
                .sheet(item: Binding(get: { passageCard.map(PassageCardID.init) }, set: { passageCard = $0?.id })) { card in
                    PassageCardSheet(store: store, passageID: card.id, seeChapter: openPassage, notes: notes, openNote: { openNote($0, collectionID) })
                }
                .sheet(item: Binding(get: { linkCard.map(StudyLinkID.init) }, set: { linkCard = $0?.id })) { card in
                    if store.link(id: card.id) != nil {
                        StudyLinkSheet(store: store, linkID: card.id, collectionID: collectionID)
                    }
                }
                .sheet(item: Binding(get: { conversationCard.map(StudyConversationID.init) }, set: { conversationCard = $0?.id })) { card in
                    if let conversation = store.conversation(id: card.id) {
                        StudyConversationSheet(conversation: conversation, seeCompanion: openCompanion)
                    }
                }
                .sheet(item: $editingLink) { link in
                    StudyLinkEditorSheet(store: store, linkID: link.id, collectionID: collectionID)
                }
                .sheet(item: $organizing) { item in
                    CollectionDestinationPicker(store: store, artifact: item.artifact, mode: item.mode, notes: notes)
                }
                .sheet(item: $libraryJournalField) { context in
                    if let note = notes.snapshot.notes.first(where: { $0.id == context.noteID }) {
                        JournalFieldPicker(
                            field: context.field,
                            journal: note.journalContent,
                            session: notes,
                            libraryNoteID: context.noteID
                        )
                    }
                }
    }

    private func collectionDetail(_ collection: StudyCollection) -> some View {
                collectionSheets(collection)
                .studyCenteredConfirmation(
                    isPresented: $showingDeleteAlert,
                    title: "Delete \(collection.name)?",
                    message: "Subfolders move up one level. Anything that is not in another collection moves to No Folder. Nothing is deleted.",
                    confirmLabel: "Delete Collection"
                ) {
                    store.deleteCollection(id: collectionID)
                    dismiss()
                }
                .overlay {
                    if let subfolder = deletingSubfolder {
                        StudyCenteredConfirmationOverlay(
                            title: "Delete \(subfolder.name)?",
                            message: "Subfolders move up one level. Anything that is not in another collection moves to No Folder. Nothing is deleted.",
                            confirmLabel: "Delete Collection",
                            onConfirm: {
                                store.deleteCollection(id: subfolder.id)
                                deletingSubfolder = nil
                            },
                            onCancel: { deletingSubfolder = nil }
                        )
                    }
                }
                .animation(.easeOut(duration: 0.18), value: deletingSubfolder != nil)
                .overlay {
                    if let item = pendingDeletion {
                        StudyCenteredConfirmationOverlay(
                            title: deleteArtifactTitle(item),
                            message: deleteArtifactMessage(item),
                            confirmLabel: "Delete",
                            confirmAccessibilityIdentifier: "collections.delete.confirm",
                            onConfirm: {
                                confirmDeleteArtifact(item)
                                pendingDeletion = nil
                            },
                            onCancel: { pendingDeletion = nil }
                        )
                    }
                }
                .animation(.easeOut(duration: 0.18), value: pendingDeletion != nil)
    }

    @ToolbarContentBuilder
    private func toolbar(_ collection: StudyCollection) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if !collection.isUnfiled {
                    Button("Add Study Material", systemImage: "plus") { showingPicker = true }
                    Button("New Subfolder", systemImage: "folder.badge.plus") { showingSubfolderEditor = true }
                    Button("Duplicate Collection", systemImage: "doc.on.doc") { duplicatingCollection = collection }
                        .accessibilityIdentifier("collections.duplicate")
                    Button("Edit Collection…", systemImage: "pencil") { showingEditor = true }
                    if collection.protectionID == nil {
                        Button("Protect Collection", systemImage: "lock") { Task { await store.setProtected(collection.id, enabled: true) } }
                            .accessibilityIdentifier("collections.actions.protect")
                    } else {
                        Button("Lock Collection", systemImage: "lock") { store.protection.lock([.collections]) }
                            .accessibilityIdentifier("collections.actions.lock")
                        Button("Remove Collection Protection", systemImage: "lock.slash") { Task { await store.setProtected(collection.id, enabled: false) } }
                            .accessibilityIdentifier("collections.actions.removeProtection")
                    }
                    Button("Archive Collection", systemImage: "archivebox") {
                        store.archiveCollection(id: collectionID)
                    }
                    Divider()
                    Button("Delete Collection", systemImage: "trash", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } else {
                    Button("Edit No Folder Color…", systemImage: "paintpalette") { showingEditor = true }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Collection actions")
        }
    }

    private func header(_ collection: StudyCollection) -> some View {
        let itemCount = collection.isUnfiled
            ? store.unfiledCount(notes: notes.snapshot.notes)
            : store.membershipCount(for: collectionID, notes: notes.snapshot.notes, annotationSnapshot: annotationSnapshot)
        let subfolderCount = store.children(of: collectionID).count
        let detail = collection.isUnfiled ? StudyCollection.unfiled(accent: collection.accent, modifiedAt: .now).detail : collection.detail

        let accent = displayAccent(for: collection)
        return HStack(alignment: .top, spacing: 18) {
            CollectionFolderGlyph(accent: accent, unfiled: collection.isUnfiled, icon: collection.icon ?? .folder, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if collection.isUnfiled {
                        Text(collection.name)
                            .font(.system(.largeTitle, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                    } else {
                        Button { showingEditor = true } label: {
                            HStack(spacing: 7) {
                                Text(collection.name)
                                    .font(.system(.largeTitle, design: .serif).weight(.semibold))
                                Image(systemName: "pencil")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(Color(theme.palette.ink))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit collection \(collection.name)")
                        .accessibilityIdentifier("collections.editTitle")
                    }
                }
                if !detail.isEmpty {
                    Text(detail)
                        .font(.body)
                        .foregroundStyle(Color(theme.palette.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    Text(CollectionCount.items(itemCount))
                    if !collection.isUnfiled {
                        Text("·")
                        Text(CollectionCount.subfolders(subfolderCount))
                    }
                }
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(accent.resolvedColor(in: theme))
                .padding(.top, 2)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("collections.detail.counts")
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func subfolders(_ collection: StudyCollection) -> some View {
        let source = store.children(of: collectionID)
        let children = arrangedSubfolders(source, parent: collection)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    sectionTitle("Subfolders")
                    if subfolderArrange(for: collection, children: source) == .smart {
                        Text("Smart Order")
                            .font(.caption)
                            .foregroundStyle(Color(theme.palette.secondary))
                            .accessibilityIdentifier("collections.subfolder.smartOrder")
                    }
                }
                Spacer()
                if !source.isEmpty {
                    subfolderArrangeMenu(collection, children: source)
                }
                Button {
                    showingSubfolderEditor = true
                } label: {
                    Label("New Subfolder", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .frame(width: 16, height: 44)
                }
                .buttonStyle(CollectionSecondaryButtonStyle())
                .accessibilityLabel("New Subfolder")
                .accessibilityIdentifier("collections.newSubfolder")
            }
            if children.isEmpty {
                Text("Divide this collection into smaller topics with subfolders.")
                    .font(.subheadline)
                    .foregroundStyle(Color(theme.palette.secondary))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(children) { child in
                        NavigationLink {
                            CollectionDetailView(
                                store: store,
                                collectionID: child.id,
                                notes: notes,
                                openNote: openNote,
                                openPassage: openPassage,
                                openAnnotation: openAnnotation,
                                annotationSnapshot: annotationSnapshot,
                                bookTitleForCode: bookTitleForCode,
                                openCompanion: openCompanion,
                                createConversation: createConversation,
                                exploreQuestion: exploreQuestion,
                                trashConversation: trashConversation,
                                books: books
                            )
                        } label: {
                            subfolderTile(child)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if !store.isLocked(child.id) {
                                Button("Duplicate Collection", systemImage: "doc.on.doc") { duplicatingCollection = child }
                                Button("Edit Collection", systemImage: "pencil") { editingSubfolder = child }
                                Button("Move Collection", systemImage: "folder") { movingSubfolder = child }
                            }
                            ItemProtectionContextActions(
                                noun: "Collection",
                                protectionID: child.protectionID,
                                locked: store.isLocked(child.id),
                                protect: { Task { await store.setProtected(child.id, enabled: true) } },
                                lock: { store.protection.lock([.collections]) },
                                unlock: { Task { await store.requestAccess(child.id) } },
                                remove: { Task { await store.setProtected(child.id, enabled: false) } }
                            )
                            Button("Archive Collection", systemImage: "archivebox") { store.archiveCollection(id: child.id) }
                            Button("Delete Collection", systemImage: "trash", role: .destructive) { deletingSubfolder = child }
                        }
                        .collectionFolderDragAndDrop(child, store: store)
                        .accessibilityIdentifier("collections.folder.\(child.name)")
                    }
                }
            }
        }
    }

    private func subfolderTile(_ child: StudyCollection) -> some View {
        HStack(spacing: 12) {
            if child.protectionID != nil { Image(systemName: store.isLocked(child.id) ? "lock.fill" : "lock.open.fill").foregroundStyle(.secondary) }
            CollectionFolderGlyph(accent: store.isLocked(child.id) ? .stone : child.accent, icon: child.icon ?? .folder, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                    .lineLimit(1)
                Text(subfolderSummary(child))
                    .accessibilityIdentifier("collections.subfolder.counts.\(child.name)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color(theme.palette.secondary))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(theme.palette.secondary))
        }
        .padding(12)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func studyMaterial(_ collection: StudyCollection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                sectionTitle("Study Material")
                Spacer()
                Menu {
                    Picker("Layout", selection: Binding(get: { cards }, set: setCards)) {
                        Label("List View", systemImage: "list.bullet").tag(false)
                        Label("Card View", systemImage: "square.grid.2x2").tag(true)
                    }
                    Picker("Show", selection: $filter) {
                        ForEach(CollectionArtifactFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    Picker("Sort", selection: $sort) {
                        ForEach(CollectionArtifactSort.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    if !collection.isUnfiled {
                        Toggle("Include Subfolders", isOn: $includeDescendants)
                    }
                } label: {
                    Label(filter == .all ? "View" : filter.title, systemImage: "line.3.horizontal.decrease.circle")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(theme.palette.secondary))
                }
                .accessibilityLabel("Study material view options")
                .accessibilityIdentifier("collections.filter")
                Button {
                    showingPicker = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .labelStyle(.iconOnly)
                        .frame(width: 16, height: 44)
                }
                .buttonStyle(CollectionSecondaryButtonStyle())
                .accessibilityLabel("Add Study Material")
                .accessibilityIdentifier("collections.addMaterial")
            }

            if visibleArtifacts.isEmpty {
                emptyMaterial(collection)
            } else if cards {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)], spacing: 16) {
                    ForEach(visibleArtifacts) { artifact in
                        row(artifact, in: collection)
                    }
                }
                .accessibilityIdentifier("collections.material.cards")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(visibleArtifacts) { artifact in
                        row(artifact, in: collection)
                    }
                }
                .accessibilityIdentifier("collections.material.list")
            }
        }
    }

    private func row(_ artifact: CollectionArtifact, in collection: StudyCollection) -> some View {
        let placement: CollectionArtifactRow.Placement
        if collection.isUnfiled {
            placement = .unfiled
        } else if includeDescendants && !store.contains(artifact.id, in: collectionID) {
            placement = .subfolder
        } else {
            placement = .folder
        }
        return CollectionArtifactRow(
            artifact: artifact,
            accent: placement == .subfolder ? store.accent(for: artifact.id) : collection.accent,
            placement: placement,
            open: { open(artifact) },
            move: {
                store.link(notes: notes.snapshot.notes)
                organizing = Organize(artifact: artifact, mode: .move(from: collectionID))
            },
            assign: {
                store.link(notes: notes.snapshot.notes)
                organizing = Organize(artifact: artifact, mode: .assign)
            },
            remove: { store.removeArtifact(artifact.id, from: collectionID) },
            deleteArtifact: { pendingDeletion = artifact },
            archiveNote: artifact.kind == .note ? { notes.archive(artifact.id) } : nil,
            notes: notes,
            onJournalField: { field in
                libraryJournalField = LibraryJournalFieldContext(noteID: artifact.id, field: field)
            },
            editLink: artifact.kind == .link ? { editingLink = store.link(id: artifact.id) } : nil,
            cards: cards
        )
        .collectionStudyMaterialDrag(artifact.id, sourceID: collectionID, store: store, enabled: placement != .subfolder) { store.link(notes: notes.snapshot.notes) }
    }

    private func emptyMaterial(_ collection: StudyCollection) -> some View {
        VStack(spacing: 12) {
            Image(systemName: collection.isUnfiled ? "tray" : "square.stack")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(displayAccent(for: collection).resolvedColor(in: theme))
            Text(collection.isUnfiled ? "Everything is filed" : (filter == .all ? "Nothing here yet" : "No \(filter.title.lowercased()) here"))
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color(theme.palette.ink))
            Text(collection.isUnfiled
                 ? "New bookmarks, gleanings, and notes appear here until you add them to a collection."
                 : "Save a bookmark or gleaning from Scripture, or add notes you already have.")
                .font(.subheadline)
                .foregroundStyle(Color(theme.palette.secondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            if !collection.isUnfiled {
                Button("Add Study Material") { showingPicker = true }
                    .buttonStyle(CollectionProminentButtonStyle())
                    .padding(.top, 4)
                    .accessibilityIdentifier("collections.addMaterialEmpty")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(theme.palette.rule), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        )
    }

    private func savedArrange(for id: UUID) -> CollectionSubfolderArrange {
        let prefix = id.uuidString + "="
        guard let entry = arrangeStore.split(separator: ",").first(where: { $0.hasPrefix(prefix) }) else { return .automatic }
        return CollectionSubfolderArrange.stored(String(entry.dropFirst(prefix.count)))
    }

    private func setArrange(_ arrange: CollectionSubfolderArrange, for id: UUID) {
        var entries = arrangeStore.split(separator: ",").map(String.init).filter { !$0.hasPrefix(id.uuidString + "=") }
        if arrange != .automatic {
            entries.append("\(id.uuidString)=\(arrange.rawValue)")
        }
        arrangeStore = entries.sorted().joined(separator: ",")
    }

    private func subfolderArrange(for collection: StudyCollection, children: [StudyCollection]) -> CollectionSubfolderArrange {
        let names = children.map(\.name)
        switch savedArrange(for: collection.id) {
        case .automatic:
            if BibleCollectionOrder.prefersScriptureOrder(parentName: collection.name, childNames: names, books: books) { return .smart }
            if BibleCollectionOrder.prefersNumberOrder(names) { return .smart }
            return .name
        case .smart: return .smart
        case .name: return .name
        case .modified: return .modified
        }
    }

    private func arrangedSubfolders(_ children: [StudyCollection], parent: StudyCollection) -> [StudyCollection] {
        switch subfolderArrange(for: parent, children: children) {
        case .smart:
            let forced = savedArrange(for: parent.id) == .smart
            let scripture = forced || BibleCollectionOrder.prefersScriptureOrder(
                parentName: parent.name,
                childNames: children.map(\.name),
                books: books
            )
            return BibleCollectionOrder.sorted(children, name: \.name, books: books, scripture: scripture)
        case .modified:
            return children.sorted { $0.modifiedAt > $1.modifiedAt }
        case .name, .automatic:
            return children.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private func subfolderSummary(_ child: StudyCollection) -> String {
        guard !store.isLocked(child.id) else { return "Locked" }
        let items = store.membershipCount(for: child.id, includingDescendants: true,
                                          notes: notes.snapshot.notes, annotationSnapshot: annotationSnapshot)
        let folders = store.children(of: child.id).count
        return "\(CollectionCount.items(items)) · \(CollectionCount.subfolders(folders))"
    }

    private func subfolderArrangeMenu(_ collection: StudyCollection, children: [StudyCollection]) -> some View {
        let selected = savedArrange(for: collection.id)
        return Menu {
            ForEach(CollectionSubfolderArrange.allCases) { option in
                Button {
                    setArrange(option, for: collection.id)
                } label: {
                    if option == selected {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
                .accessibilityIdentifier("collections.subfolder.arrange.\(option.rawValue)")
            }
        } label: {
            Label("Arrange", systemImage: "arrow.up.arrow.down")
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(theme.palette.secondary))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Arrange subfolders")
        .accessibilityIdentifier("collections.subfolder.arrange")
        .disabled(children.isEmpty)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: .serif).weight(.semibold))
            .foregroundStyle(Color(theme.palette.ink))
    }

    private func deleteArtifactTitle(_ item: CollectionArtifact) -> String {
        switch item.kind {
        case .pointToPonder: return "Move this question to Trash?"
        case .note: return "Move \"\(item.title)\" to Trash?"
        case .conversation: return "Delete \"\(item.title)\"?"
        default: return "Delete \(item.title)?"
        }
    }

    private func deleteArtifactMessage(_ item: CollectionArtifact) -> String {
        switch item.kind {
        case .pointToPonder:
            return "Restore it from Settings → Trash → Points to Ponder."
        case .annotation:
            return "Only the saved Collections reference is removed. The annotation ink is not changed."
        case .note:
            return "Trash keeps the note for \(TrashRetention.dayCount) days. Restore it from Settings → Trash, or delete it permanently there."
        case .conversation:
            return "The conversation moves to Trash in Companion and is removed from Collections. Restore it from Settings → Trash."
        default:
            return "It is removed from every collection."
        }
    }

    private func confirmDeleteArtifact(_ item: CollectionArtifact) {
        switch item.kind {
        case .pointToPonder: store.trashPoint(item.id)
        case .annotation: store.deleteAnnotationReference(item.id)
        case .link: store.deleteLink(item.id)
        case .bookmark, .gleaning: store.deletePassage(item.id)
        case .conversation: trashConversation(item.id)
        case .note: notes.moveToTrash(item.id)
        default: break
        }
    }

    private func open(_ artifact: CollectionArtifact) {
        switch artifact.kind {
        case .pointToPonder:
            pointCard = store.pointsToPonder.first { $0.id == artifact.id && $0.trashedAt == nil }
        case .note:
            openNote(artifact.id, collectionID)
        case .bookmark, .gleaning:
            passageCard = artifact.id
        case .link:
            linkCard = artifact.id
        case .conversation:
            conversationCard = artifact.id
        case .scripture:
            break
        case .annotation:
            if let saved = store.savedAnnotation(id: artifact.id) {
                openAnnotation(saved)
            }
        }
    }
}
