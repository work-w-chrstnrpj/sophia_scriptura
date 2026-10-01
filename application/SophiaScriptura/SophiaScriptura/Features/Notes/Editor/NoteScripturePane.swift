import SwiftUI

/// Uses the same content, navigation and licensed-access boundary as the Scripture tab.
struct NoteScripturePane: View {
    @Bindable var reader: ReaderSession
    let notes: NotesSession
    @State private var pickBook = false
    @State private var pickVersion = false
    @State private var verse: Int?
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(reader.title) { pickBook = true }.lineLimit(1).accessibilityIdentifier("notes.reader.book")
                Spacer(minLength: 4)
                Button(reader.abbreviation) { pickVersion = true }.accessibilityIdentifier("notes.reader.version")
            }.font(.subheadline).padding(.horizontal).padding(.top, 8)
            if let document = reader.document {
                ReaderTextSurface(document: document, preferences: reader.preferences,
                    targetVerse: reader.targetVerse, navigationID: reader.navigationID,
                    restorationLocation: reader.restorationLocation,
                    onVerse: { verse = $0 }, onVisibleLocation: { v, b, o in if notes.active { reader.visibleLocation(v, blockID: b, utf16Offset: o) } },
                    onChapterSwipe: { delta in Task { await reader.stepChapter(delta) } },
                    authorizeQuote: reader.authorizeQuote,
                    saveToNote: { selection in Task { _ = await notes.saveSelection(selection, reader: reader, newNote: false) } })
                HStack {
                    Button("Previous", systemImage: "chevron.left") { Task { await reader.stepChapter(-1) } }
                    Spacer()
                    Button("Next", systemImage: "chevron.right") { Task { await reader.stepChapter(1) } }
                }.labelStyle(.iconOnly).padding()
            } else {
                ContentUnavailableView("Scripture unavailable", systemImage: "book.closed", description: Text(reader.error ?? "Loading Scripture…"))
                Button("Retry") { Task { await reader.start() } }
            }
            if let notice = reader.notice { Text(notice).font(.caption).foregroundStyle(.secondary).padding(.horizontal) }
        }
        .sheet(isPresented: $pickBook) {
            ScripturePassagePicker(session: reader) { book, chapter, verse in
                pickBook = false; Task { await reader.navigate(book: book, chapter: chapter, verse: verse) }
            }
        }
        .sheet(isPresented: $pickVersion) { ScriptureVersionsView(session: reader) }
        .confirmationDialog("Add passage to this note", isPresented: Binding(get: { verse != nil }, set: { if !$0 { verse = nil } }), titleVisibility: .visible) {
            Button("Insert verse and citation") {
                if let verse, let document = reader.document {
                    let map = ChapterTextMap(document: document), ranges = ChapterTextMap(document: document).focusRanges(for: verse)
                    if let first = ranges.first, let last = ranges.last {
                        let selection = map.selection(in: NSUnionRange(first, last))
                        Task { _ = await notes.saveSelection(selection, reader: reader, newNote: false) }
                    }
                }
                verse = nil
            }
            Button("Cancel", role: .cancel) { verse = nil }
        }
    }
}
