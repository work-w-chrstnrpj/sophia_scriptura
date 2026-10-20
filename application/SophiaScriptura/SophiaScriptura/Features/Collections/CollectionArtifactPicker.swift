import SwiftUI

struct CollectionArtifactPicker: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: CollectionsStore
    let collectionID: UUID
    var notes: NotesSession
    var reader: ReaderSession? = nil
    @State private var creatingPlan: PlanEditorDraft?
    var annotationSnapshot: AnnotationSnapshot?
    var bookTitleForCode: (String) -> String = { $0 }
    var openNote: (UUID) -> Void = { _ in }
    var openCompanion: () -> Void = {}
    var createConversation: () -> UUID? = { nil }
    @State private var creatingNote = false
    @State private var creatingPoint = false

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var addingLink = false
    @State private var linkTitle = ""
    @State private var linkURL = "https://"
    @State private var linkRejected = false

    private var accent: CollectionAccent { store.collection(id: collectionID)?.accent ?? .slate }

    private var catalog: [CollectionArtifact] {
        if let annotationSnapshot {
            return store.pickableArtifacts(
                notes: notes.snapshot.notes,
                annotationSnapshot: annotationSnapshot,
                bookTitleForCode: bookTitleForCode
            )
        }
        return store.presentedArtifacts(notes: notes.snapshot.notes, annotationSnapshot: annotationSnapshot)
    }

    private var filteredArtifacts: [CollectionArtifact] {
        catalog.filter { artifact in
            searchText.isEmpty ||
                artifact.title.localizedCaseInsensitiveContains(searchText) ||
                artifact.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("New Plan", systemImage: "list.bullet.rectangle") {
                        creatingPlan = PlanEditorDraft(plan: StudyPlan(title: "", preferredEditionID: reader?.edition?.id ?? ScriptureReferenceIdentity.bundledEditionID,
                            referenceSystemID: reader?.edition?.referenceSystemID ?? "org.sophia.web.engwebp", sections: [.init()]))
                    }
                        .accessibilityIdentifier("collections.newPlan")
                    Button("New Point to Ponder", systemImage: "questionmark.bubble") { creatingPoint = true }
                        .accessibilityIdentifier("collections.newPoint")
                    Button("New Note", systemImage: "square.and.pencil") { creatingNote = true }
                        .accessibilityIdentifier("collections.newNote")
                    Button("New Conversation", systemImage: "bubble.left.and.bubble.right") {
                        guard let id = createConversation() else { dismiss(); openCompanion(); return }
                        store.addMembership(artifactID: id, collectionID: collectionID)
                        dismiss()
                        openCompanion()
                    }
                    .accessibilityIdentifier("collections.newConversation")
                    if addingLink {
                        TextField("Title", text: $linkTitle)
                            .accessibilityIdentifier("collections.newLink.title")
                        TextField("https://", text: $linkURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("collections.newLink.url")
                        if linkRejected {
                            Text("Use a full http or https address.")
                                .font(.caption)
                                .foregroundStyle(Color(theme.palette.secondary))
                        }
                        Button("Save Link", action: createLink)
                            .disabled(linkURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("collections.newLink.create")
                    } else {
                        Button {
                            addingLink = true
                        } label: {
                            Label("New Link", systemImage: "link.badge.plus")
                                .foregroundStyle(Color(theme.palette.accent))
                        }
                        .accessibilityIdentifier("collections.newLink")
                    }
                }                 footer: {
                    Text(collectionID == StudyCollection.unfiledID ? "Create material here without filing it into a folder." : "Include notes, points to ponder, conversations, bookmarks, gleanings, links, and Scripture annotation layers.")
                }
                .listRowBackground(Color(theme.palette.soft))

                ForEach(collectionID == StudyCollection.unfiledID ? [] : filteredArtifacts) { artifact in
                let included = store.contains(artifact.id, in: collectionID)
                Button {
                    store.link(notes: notes.snapshot.notes)
                    if artifact.kind == .annotation, let annotationSnapshot {
                        registerAnnotationLayer(artifactID: artifact.id, snapshot: annotationSnapshot)
                    }
                    store.toggleMembership(artifactID: artifact.id, collectionID: collectionID)
                } label: {
                    HStack(spacing: 12) {
                        CollectionItemGlyph(kind: artifact.kind, accent: included ? accent : store.accent(for: artifact.id), size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(artifact.title)
                                .foregroundStyle(Color(theme.palette.ink))
                            Text(artifact.kind == .bookmark ? "Bookmark" : artifact.kind == .gleaning ? "Gleaning" : artifact.kind == .annotation ? "Annotation layer" : artifact.subtitle)
                                .font(.caption)
                                .foregroundStyle(Color(theme.palette.secondary))
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: included ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(included ? accent.resolvedColor(in: theme) : Color(theme.palette.rule))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color(theme.palette.soft))
                .accessibilityIdentifier("collections.pick.\(artifact.title)")
                .accessibilityValue(included ? "Included" : "Not included")
                }
            }
            .sheet(item: $creatingPlan) { model in
                PlanEditorView(store: store, notes: notes, reader: reader, collectionID: collectionID, model: model)
            }
            .sheet(isPresented: $creatingPoint) {
                PointToPonderCreatorSheet(store: store, collectionID: collectionID)
            }
            .sheet(isPresented: $creatingNote) {
                NoteCreatorSheet(notes: notes) { id in
                    store.link(notes: notes.snapshot.notes)
                    store.addMembership(artifactID: id, collectionID: collectionID)
                    dismiss()
                    openNote(id)
                }
            }
            .appSurface()
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search saved items")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func registerAnnotationLayer(artifactID: UUID, snapshot: AnnotationSnapshot) {
        guard let resolved = AnnotationCollectionCatalog.resolveLayer(layerID: artifactID, in: snapshot) else { return }
        let group = snapshot.groups.first { $0.id == resolved.groupID }
        guard let source = group?.source else { return }
        store.registerAnnotation(
            layerID: artifactID,
            groupID: resolved.groupID,
            source: source,
            bookTitle: bookTitleForCode(source.book),
            layerName: resolved.layer.name
        )
    }

    private func createLink() {
        guard let id = store.addLink(title: linkTitle, url: linkURL) else {
            linkRejected = true
            return
        }
        store.link(notes: notes.snapshot.notes)
        if !store.contains(id, in: collectionID) {
            store.toggleMembership(artifactID: id, collectionID: collectionID)
        }
        linkTitle = ""
        linkURL = "https://"
        linkRejected = false
        addingLink = false
    }
}
