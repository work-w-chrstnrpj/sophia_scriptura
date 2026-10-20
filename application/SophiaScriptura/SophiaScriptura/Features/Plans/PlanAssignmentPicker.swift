import SwiftUI

struct PlanAssignmentPicker: View {
    @Environment(\.appTheme) private var theme
    private enum AssignmentTab: String, CaseIterable { case scripture = "Scripture", notes = "Notes", links = "Links" }
    @State private var tab: AssignmentTab = .scripture
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CollectionsStore
    var notes: NotesSession
    var reader: ReaderSession?
    let referenceSystemID: String
    let planID: UUID
    let access: StudyAccessRequirements
    let collectionID: UUID
    @State private var newNoteTitle = ""
    @State private var newNoteKind: NoteKind = .page
    @State private var newLinkTitle = ""
    @State private var newLinkURL = "https://"
    var onAdded: ([PlanItemPayload]) -> Void
    @State private var bookID = "GEN"
    @State private var chapter = 1
    @State private var lastChapter = 1
    @State private var wholeChapter = true
    @State private var firstVerse = 1
    @State private var lastVerse = 1
    @State private var noteOperationID = UUID()
    @State private var createdNoteID = UUID()
    @State private var linkCommandID = UUID()
    @State private var createdLinkID = UUID()
    @State private var loading = false
    @State private var message: String?
    private var chapterCount: Int { max(1, reader?.books.first(where: { $0.id == bookID })?.chapterCount ?? 1) }
    private var bounds: PlanChapterBounds { .init(chapter: chapter, lastChapter: lastChapter, chapterCount: chapterCount) }
    private var selectedBook: Binding<String> {
        Binding(get: { bookID }, set: { value in
            // Reset dependent values before publishing a book with fewer chapters.
            chapter = 1; lastChapter = 1; firstVerse = 1; lastVerse = 1; bookID = value
        })
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Assignment type", selection: $tab) {
                    ForEach(AssignmentTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal, 24).padding(.vertical, 16)
                Form {
                    switch tab {
                    case .scripture: scriptureFields
                    case .notes: noteFields
                    case .links: linkFields
                    }
                    if let message { Section { Text(message).foregroundStyle(.red) } }
                }.scrollContentBackground(.hidden)
            }
            .appSurface().disabled(loading)
            .navigationTitle("Add assignment").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onChange(of: tab) { _, _ in message = nil }
            .onChange(of: chapter) { _, value in lastChapter = max(value, lastChapter) }
            .onChange(of: firstVerse) { _, value in lastVerse = max(value, lastVerse) }
            .interactiveDismissDisabled(loading)
        }
    }
    private var scriptureFields: some View {
        Section("Scripture") {
            if let reader, !reader.books.isEmpty {
                Picker("Book", selection: selectedBook) { ForEach(reader.books) { book in Text(book.title).tag(book.id) } }
                Stepper("Chapter \(bounds.chapter)", value: Binding(get: { bounds.chapter }, set: { chapter = $0 }), in: 1...bounds.chapterCount)
                    .accessibilityIdentifier("plans.assignment.chapter")
                Toggle("Whole chapters", isOn: $wholeChapter).accessibilityIdentifier("plans.wholeChapters")
                if wholeChapter { Stepper("Through chapter \(bounds.lastChapter)", value: Binding(get: { bounds.lastChapter }, set: { lastChapter = $0 }), in: bounds.throughRange) }
                else {
                    Stepper("First verse \(firstVerse)", value: $firstVerse, in: 1...176)
                    Stepper("Last verse \(max(firstVerse, lastVerse))", value: $lastVerse, in: firstVerse...176)
                }
                Button("Add Scripture") { Task { await addScripture(reader) } }
                    .accessibilityIdentifier("plans.addScripture")
            } else { Text("Open Scripture to load the available books, then add readings here.") }
        }.listRowBackground(Color(theme.palette.soft))
    }
    @ViewBuilder private var noteFields: some View {
        Section("New note") {
            TextField("New note title", text: $newNoteTitle).accessibilityIdentifier("plans.assignment.noteTitle")
            Picker("Note type", selection: $newNoteKind) {
                Text("Page").tag(NoteKind.page); Text("Canvas").tag(NoteKind.canvas)
                Text("Prayer").tag(NoteKind.prayer); Text("Journal").tag(NoteKind.journal)
            }
            Button("Create note assignment") { Task { await createNote() } }
                .accessibilityIdentifier("plans.assignment.createNote")
        }.listRowBackground(Color(theme.palette.soft))
        Section("Existing notes") {
            let available = notes.snapshot.notes.filter { $0.isActiveInLibrary && !notes.isLocked($0) && !store.concealsNote($0.id) }
            if available.isEmpty { Text("No available notes").foregroundStyle(Color(theme.palette.secondary)) }
            ForEach(available) { note in
                Button { onAdded([.init(kind: .note, targetID: note.id)]); dismiss() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title).font(.system(.headline, design: .serif))
                        Text(note.kind.displayName).font(.caption).foregroundStyle(Color(theme.palette.secondary))
                    }
                }
            }
        }.listRowBackground(Color(theme.palette.soft))
    }
    @ViewBuilder private var linkFields: some View {
        Section("New link") {
            TextField("Link title", text: $newLinkTitle).accessibilityIdentifier("plans.assignment.linkTitle")
            TextField("https://", text: $newLinkURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
            Button("Create link assignment") { Task { await createLink() } }
                .accessibilityIdentifier("plans.assignment.createLink")
        }.listRowBackground(Color(theme.palette.soft))
        Section("Existing links") {
            let available = store.links.filter { store.accessAllowed($0.access) && !store.collectionIDs(containing: $0.id).contains(where: store.isLocked) }
            if available.isEmpty { Text("No available links").foregroundStyle(Color(theme.palette.secondary)) }
            ForEach(available) { link in
                Button(link.title) { onAdded([.init(kind: .link, targetID: link.id)]); dismiss() }
            }
        }.listRowBackground(Color(theme.palette.soft))
    }
    private func createNote() async {
        loading = true; defer { loading = false }
        let operationID = noteOperationID, noteID = createdNoteID
        let result = await notes.createPlanNote(planID: planID, operationID: operationID, noteID: noteID,
            title: newNoteTitle, kind: newNoteKind, access: access)
        guard case .committed = result else { message = "The note save was not confirmed. Check Notes before retrying."; return }
        store.link(notes: notes.snapshot.notes)
        if collectionID != StudyCollection.unfiledID { store.addMembership(artifactID: noteID, collectionID: collectionID); await store.flush() }
        onAdded([.init(kind: .note, targetID: noteID)]); dismiss()
    }
    private func createLink() async {
        loading = true; defer { loading = false }
        let id = createdLinkID
        let url = newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = newLinkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = SavedLink(access: access, planOrigin: .init(planID: planID), id: id,
                             title: title.isEmpty ? (URL(string: url)?.host ?? "Link") : title, url: url, createdAt: Date())
        let result = await store.submit(.init(commandID: linkCommandID, intent: .saveLink(link, collectionID: collectionID)))
        guard result.receipt != nil else { message = result.message; return }
        onAdded([.init(kind: .link, targetID: id)]); dismiss()
    }
    private func addScripture(_ reader: ReaderSession) async {
        loading = true; defer { loading = false }
        do {
            var payloads: [PlanItemPayload] = []
            for number in bounds.chapter...(wholeChapter ? bounds.lastChapter : bounds.chapter) {
                let verses = try await reader.availableVerses(book: bookID, chapter: number)
                guard !verses.isEmpty, wholeChapter || (firstVerse...max(firstVerse, lastVerse)).allSatisfy(verses.contains) else { throw StudyMutationFailure.invalid }
                payloads.append(.scripture(referenceSystemID: referenceSystemID, book: bookID, chapter: number,
                    start: wholeChapter ? nil : firstVerse, end: wholeChapter ? nil : max(firstVerse, lastVerse)))
            }
            onAdded(payloads); dismiss()
        } catch { message = error.localizedDescription }
    }
}

/// Keeps the view safe even during a transient catalog/book change before state settles.
struct PlanChapterBounds {
    let chapter: Int
    let lastChapter: Int
    let chapterCount: Int
    var throughRange: ClosedRange<Int> { chapter...chapterCount }
    init(chapter: Int, lastChapter: Int, chapterCount: Int) {
        self.chapterCount = max(1, chapterCount)
        self.chapter = min(max(1, chapter), self.chapterCount)
        self.lastChapter = min(max(self.chapter, lastChapter), self.chapterCount)
    }
}
