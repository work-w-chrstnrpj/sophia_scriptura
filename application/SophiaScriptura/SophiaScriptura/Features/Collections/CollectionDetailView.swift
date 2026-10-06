import SwiftUI

struct CollectionDetailView: View {
    private struct Organize: Identifiable {
        let artifact: CollectionArtifact
        let mode: CollectionDestinationPicker.Mode
        var id: String { "\(artifact.id)-\(mode == .assign ? "assign" : "move")" }
    }

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    let collectionID: UUID
    var notes: NotesSession
    var openNote: (UUID) -> Void
    var openPassage: (SavedPassage) -> Void
    var openCompanion: () -> Void = {}
    var createConversation: () -> UUID? = { nil }

    @State private var filter: CollectionArtifactFilter = .all
    @State private var sort: CollectionArtifactSort = .modified
    @State private var includeDescendants = false
    @State private var showingPicker = false
    @State private var showingSubfolderEditor = false
    @State private var showingEditor = false
    @State private var showingDeleteAlert = false
    @State private var passageCard: UUID?
    @State private var linkCard: UUID?
    @State private var conversationCard: UUID?
    @State private var organizing: Organize?
    @State private var pendingDeletion: CollectionArtifact?
    @State private var editingSubfolder: StudyCollection?
    @State private var deletingSubfolder: StudyCollection?

    private var currentCollection: StudyCollection? { store.collection(id: collectionID) }
    private var isUnfiled: Bool { currentCollection?.isUnfiled == true }

    private func displayAccent(for collection: StudyCollection) -> CollectionAccent {
        collection.isUnfiled ? .noFolder : collection.accent
    }

    private var visibleArtifacts: [CollectionArtifact] {
        let kind = filter.kind
        let filtered = store.presentedArtifacts(
            for: collectionID,
            includingDescendants: includeDescendants,
            notes: notes.snapshot.notes
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
                collectionDetail(collection)
            } else {
                ContentUnavailableView("Collection unavailable", systemImage: "folder.badge.questionmark")
            }
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
                .sheet(isPresented: $showingPicker) {
                    CollectionArtifactPicker(store: store, collectionID: collectionID, notes: notes, openNote: openNote, openCompanion: openCompanion, createConversation: createConversation)
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
                .sheet(item: Binding(get: { passageCard.map(PassageCardID.init) }, set: { passageCard = $0?.id })) { card in
                    PassageCardSheet(store: store, passageID: card.id, seeChapter: openPassage)
                }
                .sheet(item: Binding(get: { linkCard.map(StudyLinkID.init) }, set: { linkCard = $0?.id })) { card in
                    if let link = store.link(id: card.id) {
                        StudyLinkSheet(link: link)
                    }
                }
                .sheet(item: Binding(get: { conversationCard.map(StudyConversationID.init) }, set: { conversationCard = $0?.id })) { card in
                    if let conversation = store.conversation(id: card.id) {
                        StudyConversationSheet(conversation: conversation, seeCompanion: openCompanion)
                    }
                }
                .sheet(item: $organizing) { item in
                    CollectionDestinationPicker(store: store, artifact: item.artifact, mode: item.mode, notes: notes)
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
                            title: "Delete \(item.title)?",
                            message: "It is removed from every collection.",
                            confirmLabel: "Delete",
                            onConfirm: {
                                if item.kind == .link { store.deleteLink(item.id) }
                                else { store.deletePassage(item.id) }
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
                    Button("Edit Collection…", systemImage: "pencil") { showingEditor = true }
                    Button("Archive Collection", systemImage: "archivebox") {
                        store.archiveCollection(id: collectionID)
                    }
                    Divider()
                    Button("Delete Collection", systemImage: "trash", role: .destructive) {
                        showingDeleteAlert = true
                    }
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
            : store.membershipCount(for: collectionID, notes: notes.snapshot.notes)
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
        let children = store.children(of: collectionID)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Subfolders")
                Spacer()
                Button {
                    showingSubfolderEditor = true
                } label: {
                    Label("New Subfolder", systemImage: "plus")
                }
                .buttonStyle(CollectionSecondaryButtonStyle())
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
                                openCompanion: openCompanion
                            )
                        } label: {
                            subfolderTile(child)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit Collection", systemImage: "pencil") { editingSubfolder = child }
                            Button("Delete Collection", systemImage: "trash", role: .destructive) { deletingSubfolder = child }
                        }
                        .accessibilityIdentifier("collections.folder.\(child.name)")
                    }
                }
            }
        }
    }

    private func subfolderTile(_ child: StudyCollection) -> some View {
        HStack(spacing: 12) {
            CollectionFolderGlyph(accent: child.accent, icon: child.icon ?? .folder, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.ink))
                    .lineLimit(1)
                Text(CollectionCount.items(store.membershipCount(for: child.id, includingDescendants: true, notes: notes.snapshot.notes)))
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
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(theme.palette.secondary))
                }
                .accessibilityLabel("Study material view options")
                .accessibilityIdentifier("collections.filter")
                if !collection.isUnfiled {
                    Button {
                        showingPicker = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .accessibilityIdentifier("collections.addMaterial")
                }
            }

            if visibleArtifacts.isEmpty {
                emptyMaterial(collection)
            } else {
                List {
                    ForEach(visibleArtifacts) { artifact in
                        row(artifact, in: collection)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(visibleArtifacts.count) * 88 + 8)
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
            accent: collection.isUnfiled ? .noFolder : (placement == .subfolder ? store.accent(for: artifact.id) : collection.accent),
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
            deletePassage: { pendingDeletion = artifact }
        )
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

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: .serif).weight(.semibold))
            .foregroundStyle(Color(theme.palette.ink))
    }

    private func open(_ artifact: CollectionArtifact) {
        switch artifact.kind {
        case .note:
            openNote(artifact.id)
        case .bookmark, .gleaning:
            passageCard = artifact.id
        case .link:
            linkCard = artifact.id
        case .conversation:
            conversationCard = artifact.id
        case .scripture:
            break
        }
    }
}
