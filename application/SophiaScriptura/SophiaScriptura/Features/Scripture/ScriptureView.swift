import SwiftUI

struct ScriptureView: View {
    @Bindable var session: ReaderSession
    @Bindable var annotations: AnnotationSession
    var notes: NotesSession
    @ObservedObject var collections: CollectionsStore
    var openNote: (UUID) -> Void
    var active: Bool = true
    @State private var contentWidth = 760.0
    @State private var picker: ReaderPicker?
    @State private var pendingQuote: PendingQuote?
    @State private var passageCard: UUID?
    @State private var passageDraft: SavedPassage?
    @State private var wideLayout = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    enum ReaderPicker: String, Identifiable { case book, version; var id: String { rawValue } }
    private var appearance: ScriptureAppearance { session.preferences.appearance }
    private var palette: ReaderPalette { session.preferences.palette(for:appearance,colorScheme:colorScheme) }
    var body: some View {
        ZStack {
            VStack(spacing:0) {
            HStack(spacing:16) {
                if wideLayout {
                    VStack(alignment:.leading,spacing:4) {
                        Text("Sophia Scriptura").font(.custom("Georgia",size:22,relativeTo:.title2))
                        Text("READ · REFLECT · REMEMBER").font(.caption2).tracking(2)
                            .foregroundStyle(Color(palette.secondary))
                    }
                    Spacer(minLength:16)
                }
                HStack(spacing:0) {
                Button { picker = .book } label: {
                    Text(session.currentBook?.title ?? session.title)
                        .lineLimit(1)
                        .frame(minWidth:110,minHeight:44)
                }.accessibilityIdentifier("reader.book")
                    .accessibilityLabel("Book, \(session.title)")
                    .accessibilityValue(session.title)
                    .disabled(session.document == nil)
                Rectangle().fill(Color(palette.rule)).frame(width:1,height:22)
                Button { picker = .version } label: {
                    Text(session.abbreviation)
                        .frame(minWidth:82,minHeight:44)
                }.accessibilityIdentifier("reader.version")
                    .accessibilityLabel("Version, \(session.abbreviation)")
                }
                .background(Color(palette.paper),in:Capsule())
                .overlay(Capsule().stroke(Color(palette.rule),lineWidth:1))
                .shadow(color:Color.black.opacity(0.04),radius:8,y:3)
                if !wideLayout { Spacer(minLength:0) }
            }.font(ScriptureFonts.interface(appearance))
                .buttonStyle(.plain).padding(.horizontal,24).padding(.vertical,10)
            if let notice = session.notice {
                Text(notice).font(.caption).foregroundStyle(.secondary).padding(10).accessibilityIdentifier("reader.notice")
            }
            if let error = session.error {
                ContentUnavailableView {
                    Label("Reader unavailable",systemImage:"book.closed")
                } description: { Text(error) } actions: {
                    Button("Retry") { Task { await session.start() } }
                }
            } else if let document = session.document {
                VStack(spacing:6) {
                    Text(session.title).font(Font(UIFontMetrics(forTextStyle:.largeTitle).scaledFont(for:ScriptureFonts.font(appearance.headingFamily,size:36))))
                        .accessibilityAddTraits(.isHeader)
                    Text(session.edition?.name ?? session.abbreviation)
                        .font(ScriptureFonts.interface(appearance,size:13)).foregroundStyle(Color(palette.secondary))
                }.padding(.top,10).padding(.horizontal,24)
                AnnotationControls(annotations: annotations, reader: session, width: contentWidth)
                if let group = annotations.group {
                    if annotations.layoutAvailable && group.source == AnnotationSource(document) {
                        annotatedReader(document, group: group)
                    } else if annotations.mode == .hidden {
                        ordinaryReader(document)
                    } else {
                        ContentUnavailableView("Annotated layout unavailable", systemImage: "square.3.layers.3d",
                            description: Text("Handwriting is retained. Select a layer with an available layout or return to its original Scripture edition."))
                    }
                } else { ordinaryReader(document) }
                HStack {
                    Button { Task { await session.stepChapter(-1) } } label: {
                        Image(systemName:"chevron.left")
                            .frame(width:44,height:44)
                            .background(Color(palette.ink).opacity(0.08),in:Circle())
                    }
                    .accessibilityLabel("Previous chapter")
                    .disabled(document.book == "GEN" && document.chapter == 1)
                    Spacer()
                    Button { Task { await session.stepChapter(1) } } label: {
                        Image(systemName:"chevron.right")
                            .frame(width:44,height:44)
                            .background(Color(palette.ink).opacity(0.08),in:Circle())
                    }
                    .accessibilityLabel("Next chapter")
                    .disabled(document.book == "REV" && document.chapter == 22)
                }.padding(.horizontal,24).padding(.vertical,12)
            } else {
                Spacer(); ProgressView("Opening your Bible…"); Spacer()
            }
            }
            .foregroundStyle(Color(palette.ink))
            .tint(Color(palette.accent))

            if picker != nil {
                Rectangle()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.05 : 0.025))
                    .background(.ultraThinMaterial)
                    .opacity(0.58)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .background(Color(palette.paper).ignoresSafeArea())
        .animation(.easeOut(duration:0.18),value:picker != nil)
        .task {
            session.beforeNavigation = { [weak annotations] in
                guard let annotations else { return true }
                if !annotations.loaded { return true }
                return await annotations.prepareForNavigation()
            }
            await session.start()
            await session.resume()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for:.seconds(60))
                guard !Task.isCancelled else { return }
                await session.checkAccess()
            }
        }
        .task(id: session.document.map { AnnotationSource($0) }) {
            await annotations.open(session.document)
            annotations.restoreSelectedAppearance(reader: session)
        }
        .onChange(of: session.preferences) { old, new in
            if annotations.selected != nil && annotations.mode != .hidden &&
               (old.typeface != new.typeface || old.sizeStep != new.sizeStep || old.appearancePreset != new.appearancePreset),
               let document = session.document {
                Task { await annotations.appearanceChanged(to: new, document: document, width: contentWidth) }
            }
        }
        .onChange(of:scenePhase) { _, phase in
            if phase != .active { Task { await annotations.save() }; session.suspendLicensedContent() }
            else { Task { await session.resume() } }
        }
        .sheet(item:$picker) { item in pickerSheet(item) }
        .background(GeometryReader { geometry in
            Color.clear.onAppear { wideLayout = geometry.size.width > 900; contentWidth = geometry.size.width }
                .onChange(of:geometry.size) { _, size in wideLayout = size.width > 900; contentWidth = size.width }
        })
        .sheet(item:hubBinding(wide:false)) { hub($0) }
        .popover(item:hubBinding(wide:true),arrowEdge:.top) { hub($0).frame(width:440,height:600) }
        .sheet(item: $pendingQuote) { pending in
            ScriptureNoteDestinationPicker(quote: pending.quote, notes: notes, openNote: openNote)
        }
        .sheet(item: passageCardBinding) { card in
            PassageCardSheet(store: collections, passageID: card.id) { passage in
                Task { await session.navigate(book: passage.bookID, chapter: passage.chapter, verse: passage.startVerse, spans: passage.spans) }
            }
        }
        .sheet(item: $passageDraft) { draft in
            PassageSaveSheet(store: collections, draft: draft)
        }
    }

    private func annotatedReader(_ document: ChapterDocument, group: AnnotationGroup) -> some View {
        let stateToken = "\(annotations.mode.rawValue)|\(annotations.marginExpanded)|\(annotations.toolsVisible)|\(annotations.active)|\(annotations.saving)|\(annotations.group?.selectedLayerID?.uuidString ?? "")"
        let identity = "\(group.id)|\(annotations.selectedLayout?.signature ?? "")|\(annotations.reopenGeneration)"

        return ZStack {
            AnnotationSurface(
                document: document,
                preferences: session.preferences,
                reader: session,
                session: annotations,
                stateToken: stateToken,
                saveToNote: saveToNote,
                saveBookmark: { saveExcerpt($0, kind: .bookmark) },
                saveGleaning: { saveExcerpt($0, kind: .gleaning) }
            )
            .id(identity)
            .opacity(annotations.mode == .hidden ? 0 : 1)
            .allowsHitTesting(annotations.mode != .hidden)
            .accessibilityHidden(annotations.mode == .hidden)

            if annotations.mode == .draw && !annotations.toolsVisible {
                minimizedPalette
            }
            if annotations.mode == .hidden {
                ordinaryReader(document)
            }
        }
    }

    private var minimizedPalette: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    if annotations.paletteCollapsed {
                        Button { annotations.paletteCollapsed = false } label: {
                            Image(systemName: "chevron.left").frame(width: 26, height: 44)
                        }
                        .accessibilityLabel("Restore minimized palette")
                        .accessibilityIdentifier("annotation.paletteCollapsed")
                    } else {
                        Button { annotations.toolsVisible = true } label: {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 19, weight: .medium))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Expand drawing palette")
                        .accessibilityIdentifier("annotation.paletteMinimized")
                        Button { annotations.paletteCollapsed = true } label: {
                            Image(systemName: "chevron.right").frame(width: 26, height: 44)
                        }
                        .accessibilityLabel("Collapse minimized palette")
                        .accessibilityIdentifier("annotation.paletteCollapse")
                    }
                }
                .background(.regularMaterial, in: Capsule())
            }
            Spacer()
        }
        .padding(12)
    }

    private func ordinaryReader(_ document: ChapterDocument) -> some View {
        ReaderTextSurface(document:document,preferences:session.preferences,targetVerse:session.targetVerse,
                                  navigationID:session.navigationID,restorationLocation:session.restorationLocation,onVerse:{ session.hubVerse = document.verse($0) },
                                  onVisibleLocation: { v, b, o in if active { session.visibleLocation(v, blockID: b, utf16Offset: o) } },onChapterSwipe:{ step in Task { await session.stepChapter(step) } },authorizeQuote:session.authorizeQuote, saveToNote: saveToNote,
                                  saveBookmark: { saveExcerpt($0, kind: .bookmark) }, saveGleaning: { saveExcerpt($0, kind: .gleaning) },
                                  emphasisVerses: session.emphasisVerses, emphasisSpans: session.emphasisSpans)
                    .frame(maxWidth:760).frame(maxWidth:.infinity)
    }
    private func hubBinding(wide: Bool) -> Binding<VerseID?> {
        Binding(get:{ wideLayout == wide ? session.hubVerse : nil },set:{ session.hubVerse = $0 })
    }
    private func hub(_ verse: VerseID) -> some View {
            NavigationStack {
                List {
                    Section("\(session.currentBook?.title ?? verse.book) \(verse.chapter):\(verse.verse) · \(session.abbreviation)") {
                        Text(session.document?.body(for:verse.verse) ?? "").font(.system(.title3,design:.serif))
                        Button("Copy verse") {
                            guard let document = session.document else { return }
                            let map = ChapterTextMap(document:document)
                            let ranges = map.focusRanges(for:verse.verse)
                            guard let first = ranges.first, let last = ranges.last else { return }
                            let selection = map.selection(in:NSUnionRange(first,last))
                            Task {
                                if let text = await session.authorizeQuote(selection) {
                                    UIPasteboard.general.string = text
                                }
                            }
                        }
                        Text("Select text in the reader to share a passage.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Save") {
                        Button("Bookmark", systemImage: CollectionArtifactKind.bookmark.symbolName) { saveVerse(verse, kind: .bookmark) }
                            .accessibilityIdentifier("scripture.bookmark")
                        Button("Gleaning", systemImage: CollectionArtifactKind.gleaning.symbolName) { saveVerse(verse, kind: .gleaning) }
                            .accessibilityIdentifier("scripture.gleaning")
                    }
                    Section("Notes") {
                        Button("Save verse to note") {
                            guard let document = session.document else { return }
                            let map = ChapterTextMap(document: document)
                            let ranges = map.focusRanges(for: verse.verse)
                            guard let first = ranges.first, let last = ranges.last else { return }
                            let selected = map.selection(in: NSUnionRange(first, last))
                            session.hubVerse = nil
                            saveToNote(selected)
                        }.disabled(!notes.loaded)
                        ForEach(notes.snapshot.notes.filter { note in
                            note.deletedAt == nil && (note.objects.contains { $0.quote?.verse == verse } || note.page?.citations.contains { $0.quote.verse == verse } == true)
                        }) { note in
                            Button(note.title) { session.hubVerse = nil; openNote(note.id) }
                        }
                    }
                    Section("Collections") {
                        let attached = collections.passages.filter {
                            $0.matches(bookID: verse.book, chapter: verse.chapter, verse: verse.verse, editionID: session.edition?.id ?? "")
                        }
                        if attached.isEmpty {
                            Text("No bookmarks or gleanings for this verse.").foregroundStyle(.secondary)
                        } else {
                            ForEach(attached) { item in
                                Button {
                                    session.hubVerse = nil
                                    Task {
                                        try? await Task.sleep(for: .milliseconds(350))
                                        passageCard = item.id
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        CollectionItemGlyph(kind: item.kind == .gleaning ? .gleaning : .bookmark, accent: collections.accent(for: item.id), size: 30)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.referenceLabel).foregroundStyle(.primary)
                                            if item.kind == .gleaning && !item.insight.isEmpty {
                                                Text(item.insight).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ForEach(["Conversations","Links"],id:\.self) { name in
                        Section(name) { Text("No \(name.lowercased()) attached to this verse.").foregroundStyle(.secondary) }
                    }
                }.navigationTitle("Verse hub").toolbar { Button("Done") { session.hubVerse = nil } }
            }.presentationDetents([.medium,.large])
    }
    private var passageCardBinding: Binding<PassageCardID?> {
        Binding(get: { passageCard.map(PassageCardID.init) }, set: { passageCard = $0?.id })
    }
    private func saveVerse(_ verse: VerseID, kind: SavedPassageKind) {
        guard let document = session.document else { return }
        let map = ChapterTextMap(document: document)
        let ranges = map.focusRanges(for: verse.verse)
        guard let first = ranges.first, let last = ranges.last else { return }
        session.hubVerse = nil
        saveExcerpt(NSUnionRange(first, last), kind: kind, after: .milliseconds(350))
    }
    /// Builds a draft only; PassageSaveSheet stores it once the owner chooses where it goes.
    private func saveExcerpt(_ range: NSRange, kind: SavedPassageKind, after delay: Duration = .zero) {
        guard let document = session.document else { return }
        let map = ChapterTextMap(document: document)
        guard let excerpt = map.excerpt(in: range) else { return }
        let selection = map.selection(in: range)
        Task {
            guard await session.authorizeQuote(selection) != nil else { return }
            let passage = SavedPassage(
                id: UUID(),
                bookID: document.book,
                bookTitle: session.currentBook?.title ?? document.book,
                chapter: document.chapter,
                startVerse: excerpt.startVerse,
                endVerse: excerpt.endVerse,
                editionID: document.editionID,
                versionAbbreviation: session.abbreviation,
                passageText: excerpt.text,
                insight: "",
                kind: kind,
                createdAt: Date(),
                spans: excerpt.ranges.map { PassageSpan(location: $0.location, length: $0.length) }
            )
            if delay > .zero { try? await Task.sleep(for: delay) }
            passageDraft = passage
        }
    }
    private func saveToNote(_ selection: ChapterTextMap.Selection) {
        Task {
            guard let quote = await notes.quote(for: selection, reader: session) else { return }
            if let note = notes.note, note.deletedAt == nil {
                notes.appendQuote(quote)
                openNote(note.id)
            } else {
                pendingQuote = PendingQuote(quote: quote)
            }
        }
    }
    @ViewBuilder private func pickerSheet(_ item: ReaderPicker) -> some View {
        switch item {
        case .book:
            ScripturePassagePicker(session:session) { book, chapter, verse in
                picker = nil
                Task { await session.navigate(book:book,chapter:chapter,verse:verse) }
            }
            .presentationBackground(Color(palette.paper))
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
        case .version:
            ScriptureVersionsView(session:session)
                .presentationBackground(Color(palette.paper))
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
    }
}

private struct PendingQuote: Identifiable {
    let id = UUID()
    let quote: NoteQuote
}

private struct ScriptureNoteDestinationPicker: View {
    let quote: NoteQuote
    let notes: NotesSession
    let openNote: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    private var availableNotes: [NoteDocument] {
        notes.snapshot.notes.filter { $0.deletedAt == nil }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("New note") {
                    Button {
                        create(.page)
                    } label: {
                        Label("New Page", systemImage: "doc.text")
                    }
                    .accessibilityIdentifier("scripture.saveNote.newPage")
                    Button {
                        create(.canvas)
                    } label: {
                        Label("New Canvas", systemImage: "rectangle.dashed")
                    }
                    .accessibilityIdentifier("scripture.saveNote.newCanvas")
                }
                Section("Existing note") {
                    if availableNotes.isEmpty {
                        Text("Create a note first, then you can add passages to it.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableNotes) { note in
                            Button {
                                add(to: note)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(note.title)
                                    Text(note.kind == .page ? "Page" : "Canvas")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("scripture.saveNote.existing.\(note.id.uuidString)")
                        }
                    }
                }
            }
            .navigationTitle("Save to note")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
    }

    private func create(_ kind: NoteKind) {
        guard let id = notes.create(kind: kind, quote: quote) else { return }
        dismiss()
        openNote(id)
    }

    private func add(to note: NoteDocument) {
        notes.open(note.id)
        notes.appendQuote(quote)
        dismiss()
        openNote(note.id)
    }
}
