import SwiftUI

struct ScriptureView: View {
    @Bindable var session: ReaderSession
    @Bindable var annotations: AnnotationSession
    var notes: NotesSession
    @ObservedObject var collections: CollectionsStore
    @ObservedObject var companion: CompanionSession
    var openNote: (UUID) -> Void
    var openCompanion: () -> Void = {}
    var active: Bool = true
    @State private var contentWidth = 760.0
    @State private var picker: ReaderPicker?
    @State private var pendingQuote: PendingQuote?
    @State private var passageCard: UUID?
    @State private var passageDraft: SavedPassage?
    @State private var hubLinkCard: UUID?
    @State private var addingHubLink = false
    @State private var hubLinkTitle = ""
    @State private var hubLinkURL = "https://"
    @State private var hubMessage: String?
    @State private var hubShare: HubShare?
    @State private var hubChapter: CompanionChapterAnchor?
    @State private var wideLayout = false
    @State private var landscapeLayout = false
    @State private var confirmDeleteLayer = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    enum ReaderPicker: String, Identifiable { case book, version; var id: String { rawValue } }
    private var appearance: ScriptureAppearance { session.preferences.appearance }
    private var palette: ReaderPalette { session.preferences.palette(for:appearance,colorScheme:colorScheme) }
    private var bookButtonWidth: CGFloat { wideLayout ? 190 : 150 }
    private var selectedBookTitle: String { session.currentBook?.title ?? session.title }
    var body: some View {
        ZStack {
            VStack(spacing:0) {
            Group {
                if landscapeLayout {
                    HStack(spacing: 16) {
                        if wideLayout {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sophia Scriptura").font(.custom("Georgia", size: 22, relativeTo: .title2))
                                Text("READ · REFLECT · REMEMBER").font(.caption2).tracking(2)
                                    .foregroundStyle(Color(palette.secondary))
                            }
                            Spacer(minLength: 16)
                        }
                        readerBookVersionPicker
                        if !wideLayout { Spacer(minLength: 0) }
                    }
                    .padding(.horizontal, 24)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if wideLayout {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sophia Scriptura").font(.custom("Georgia", size: 22, relativeTo: .title2))
                                Text("READ · REFLECT · REMEMBER").font(.caption2).tracking(2)
                                    .foregroundStyle(Color(palette.secondary))
                            }
                            .padding(.horizontal, 24)
                        }
                        HStack(spacing: 16) {
                            readerBookVersionPicker
                            if !wideLayout { Spacer(minLength: 0) }
                        }
                        .shellTabDockLeadingAlignment()
                    }
                }
            }
            .font(ScriptureFonts.interface(appearance))
            .buttonStyle(.plain)
            .padding(.vertical, 10)
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
                AnnotationControls(annotations: annotations, reader: session, width: contentWidth,
                                   confirmDeleteLayer: $confirmDeleteLayer, openChapterHub: {
                    hubChapter = CompanionChapterAnchor(
                        bookID: document.book, chapter: document.chapter, editionID: document.editionID,
                        referenceLabel: "\(session.currentBook?.title ?? document.book) Chapter \(document.chapter) (\(session.abbreviation))"
                    )
                })
                if let group = annotations.group {
                    if annotations.layoutAvailable && group.source == AnnotationSource(document) {
                        annotatedReader(document, group: group)
                    } else if annotations.mode == .hidden {
                        ordinaryReader(document)
                    } else {
                        ContentUnavailableView("Annotated layout unavailable", systemImage: "square.3.layers.3d",
                            description: Text("Handwriting is retained. Select a layer with an available layout or return to its original Scripture edition."))
                    }
                } else { readerWithOptionalCompanionPanel(document) }
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

            if confirmDeleteLayer {
                StudyCenteredConfirmationOverlay(
                    title: "Delete this layer?",
                    message: "Its handwriting remains recoverable in Recently Deleted.",
                    confirmLabel: "Delete Layer",
                    onConfirm: {
                        confirmDeleteLayer = false
                        Task {
                            await annotations.deleteSelected()
                            annotations.restoreSelectedAppearance(reader: session)
                        }
                    },
                    onCancel: { confirmDeleteLayer = false }
                )
            }
        }
        .animation(.easeOut(duration: 0.18), value: confirmDeleteLayer)
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
            annotations.mode = .hidden
            annotations.marginExpanded = false
            annotations.toolsVisible = false
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
            Color.clear.onAppear {
                wideLayout = geometry.size.width > 900
                landscapeLayout = geometry.size.width > geometry.size.height
                contentWidth = geometry.size.width
            }
            .onChange(of: geometry.size) { _, size in
                wideLayout = size.width > 900
                landscapeLayout = size.width > size.height
                contentWidth = size.width
            }
        })
        .sheet(item:hubBinding(wide:false)) { hub($0) }
        .popover(item:hubBinding(wide:true),arrowEdge:.top) { hub($0).frame(width:440,height:600) }
        .sheet(item: chapterHubBinding(wide: false)) { chapterHub($0) }
        .popover(item: chapterHubBinding(wide: true), arrowEdge: .top) {
            chapterHub($0).frame(width: 440, height: 600)
        }
        .onChange(of: session.navigationID) { _, _ in hubChapter = nil }
        .sheet(item: $pendingQuote) { pending in
            StudyNoteDestinationPicker(content: .scriptureQuote(pending.quote), notes: notes, openNote: openNote)
        }
        .sheet(item: passageCardBinding) { card in
            PassageCardSheet(store: collections, passageID: card.id) { passage in
                Task { await session.navigate(book: passage.bookID, chapter: passage.chapter, verse: passage.startVerse, spans: passage.spans) }
            }
        }
        .sheet(item: $passageDraft) { draft in
            PassageSaveSheet(store: collections, draft: draft)
        }
        .sheet(item: Binding(get: { hubLinkCard.map(StudyLinkID.init) }, set: { hubLinkCard = $0?.id })) { card in
            if let link = collections.link(id: card.id) { StudyLinkSheet(link: link) }
        }
        .sheet(item: $hubShare) { share in ScriptureActivitySheet(text: share.text) }
        .sheet(isPresented: Binding(
            get: { !wideLayout && companion.scripturePanelConversationID != nil },
            set: { _ in }
        )) {
            if let id = companion.scripturePanelConversationID,
               let conversation = companion.conversations.first(where: { $0.id == id }) {
                NavigationStack {
                    CompanionConversationView(session: companion, conversation: conversation, compact: true, pendingNoteSave: .constant(nil), openNote: openNote)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button {
                                    companion.scripturePanelConversationID = nil
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .accessibilityLabel("Close")
                            }
                            ToolbarItem(placement: .primaryAction) {
                                Button("Expand") {
                                    companion.selectedConversationID = id
                                    companion.panelExpandedToTab = true
                                    companion.scripturePanelConversationID = nil
                                    openCompanion()
                                }
                            }
                        }
                }
                .interactiveDismissDisabled(true)
                .appSurface()
            }
        }
    }

    @ViewBuilder
    private func readerWithOptionalCompanionPanel(_ document: ChapterDocument) -> some View {
        if wideLayout, companion.scripturePanelConversationID != nil {
            HStack(alignment: .top, spacing: 0) {
                ordinaryReader(document)
                CompanionScripturePanel(session: companion, expandToTab: openCompanion)
            }
        } else {
            ordinaryReader(document)
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
                                  askCompanion: askCompanion(from:),
                                  analyzeOriginalLanguage: analyzeOriginalLanguage(from:),
                                  emphasisVerses: session.emphasisVerses, emphasisSpans: session.emphasisSpans)
                    .frame(maxWidth:760).frame(maxWidth:.infinity)
    }
    private func hubBinding(wide: Bool) -> Binding<VerseID?> {
        Binding(get:{ wideLayout == wide ? session.hubVerse : nil },set:{ session.hubVerse = $0 })
    }

    private func chapterHubBinding(wide: Bool) -> Binding<CompanionChapterAnchor?> {
        Binding(get: { wideLayout == wide ? hubChapter : nil }, set: { hubChapter = $0 })
    }

    private func chapterHub(_ chapter: CompanionChapterAnchor) -> some View {
        ChapterHubView(
            chapter: chapter, companion: companion, collections: collections,
            onClose: { hubChapter = nil },
            onStartConversation: {
                guard companion.askFromChapter(chapter) != nil else { return }
                hubChapter = nil
                openCompanion()
            },
            onOpenConversation: { id in
                hubChapter = nil
                companion.selectConversation(id)
                companion.scripturePanelConversationID = id
                openCompanion()
            },
            onOpenLink: { id in
                hubChapter = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { hubLinkCard = id }
            }
        )
    }
    private func hub(_ verse: VerseID) -> some View {
            let verseBody = session.document?.body(for: verse.verse) ?? ""
            let reference = "\(session.currentBook?.title ?? verse.book) \(verse.chapter):\(verse.verse) · \(session.abbreviation)"
            return NavigationStack {
                List {
                    Section(reference) {
                        Text(verseBody).font(.system(.title3,design:.serif))
                        Button("Copy verse") {
                            guard let document = session.document else { return }
                            let map = ChapterTextMap(document:document)
                            let ranges = map.focusRanges(for:verse.verse)
                            guard let first = ranges.first, let last = ranges.last else { return }
                            let selection = map.selection(in:NSUnionRange(first,last))
                            Task {
                                if let text = await session.authorizeQuote(selection) {
                                    UIPasteboard.general.string = text
                                    showHubMessage("Verse copied")
                                }
                            }
                        }
                    }
                    Section("Share") {
                        Button {
                            guard let document = session.document else { return }
                            let map = ChapterTextMap(document: document)
                            let ranges = map.focusRanges(for: verse.verse)
                            guard let first = ranges.first, let last = ranges.last else { return }
                            let selection = map.selection(in: NSUnionRange(first, last))
                            Task {
                                if let text = await session.authorizeQuote(selection) { hubShare = HubShare(text: text) }
                            }
                        } label: {
                            Label("Share verse", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("scripture.shareVerse")
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
                                            if item.kind == .gleaning, !item.insight.isEmpty {
                                                Text(StudyPreviewText.truncatedInsight(item.insight))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(2)
                                                Text(item.referenceLabel)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            } else {
                                                Text(item.referenceLabel).foregroundStyle(.primary)
                                            }
                                            let folders = collectionNames(for: item.id)
                                            if !folders.isEmpty {
                                                Text(folders.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Section("Links") {
                        Button("Add Link", systemImage: "link.badge.plus") {
                            hubLinkTitle = ""
                            hubLinkURL = "https://"
                            addingHubLink = true
                        }
                        .accessibilityIdentifier("scripture.addLink")
                        let links = collections.links.filter { $0.verse == verse && $0.editionID == session.edition?.id }
                        ForEach(links) { link in
                            Button {
                                session.hubVerse = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    hubLinkCard = link.id
                                }
                            } label: {
                                Label(link.title, systemImage: CollectionArtifactKind.link.symbolName)
                            }
                        }
                        if links.isEmpty {
                            Text("No links attached to this verse.").foregroundStyle(.secondary)
                        }
                    }
                    Section("Conversations") {
                        Button {
                            session.hubVerse = nil
                            startHubConversation(for: verse)
                        } label: {
                            Label("Start a new conversation for this verse", systemImage: "bubble.left.and.bubble.right")
                        }
                        let attached = companion.anchoredConversations(for: verse, editionID: session.edition?.id ?? "")
                        if attached.isEmpty {
                            Text("No conversations attached to this verse yet.").foregroundStyle(.secondary)
                        } else {
                            ForEach(attached) { conversation in
                                Button(conversation.title) {
                                    session.hubVerse = nil
                                    companion.selectConversation(conversation.id)
                                    companion.scripturePanelConversationID = conversation.id
                                    openCompanion()
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Verse hub")
                .toolbar { Button("Done") { session.hubVerse = nil } }
                .alert("Add Link", isPresented: $addingHubLink) {
                    TextField("Title (optional)", text: $hubLinkTitle)
                    TextField("https://example.com", text: $hubLinkURL).textInputAutocapitalization(.never)
                    Button("Add") {
                        if collections.addLink(title: hubLinkTitle, url: hubLinkURL, verse: verse, editionID: session.edition?.id) != nil {
                            showHubMessage("Link added to No Folder")
                        } else {
                            showHubMessage("Enter a valid web link")
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .overlay(alignment: .top) {
                    if let hubMessage {
                        Text(hubMessage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                            .shadow(radius: 8, y: 3)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .accessibilityIdentifier("scripture.hubMessage")
                    }
                }
            }.presentationDetents([.medium,.large])
    }
    private func collectionNames(for artifactID: UUID) -> [String] {
        collections.collectionIDs(containing: artifactID)
            .compactMap { collections.collection(id: $0)?.name }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    private func showHubMessage(_ message: String) {
        withAnimation { hubMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard hubMessage == message else { return }
            withAnimation { hubMessage = nil }
        }
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
    private func askCompanion(from selection: ChapterTextMap.Selection) {
        openCompanion(from: selection, action: .ask)
    }

    private func analyzeOriginalLanguage(from selection: ChapterTextMap.Selection) {
        openCompanion(from: selection, action: .originalLanguageAnalysis)
    }

    private func openCompanion(
        from selection: ChapterTextMap.Selection,
        action: CompanionSession.ScriptureCompanionAction
    ) {
        guard let document = session.document else { return }
        let verseNumbers = selection.passages.flatMap { passage in
            Array(passage.start.verse...passage.end.verse)
        }
        let start = verseNumbers.min() ?? 1
        let end = verseNumbers.max() ?? start
        let bookTitle = session.currentBook?.title ?? "Scripture"
        let reference = CompanionPassageReference.label(
            bookTitle: bookTitle,
            chapter: document.chapter,
            startVerse: start,
            endVerse: end
        )
        let translationName = session.edition.map { "\($0.name) (\($0.abbreviation))" } ?? session.abbreviation
        let contextSelection = ChapterTextMap(document: document).fullVerseSelection(for: selection)
        Task {
            let text: String?
            let verseContextText: String?
            if action == .originalLanguageAnalysis {
                // Authorize the expanded passage once, before either it or the selection leaves the device.
                verseContextText = if let contextSelection {
                    await session.authorizeQuote(contextSelection)
                } else { nil }
                text = verseContextText == nil ? nil : selection.text
            } else {
                // Ask needs the full involved verse(s), not just the highlighted fragment.
                verseContextText = await session.authorizeQuote(contextSelection ?? selection)
                text = verseContextText == nil ? nil : selection.text
            }
            _ = companion.askFromScripture(
                selection: selection,
                referenceLabel: reference,
                transmittedText: text,
                bookID: document.book,
                chapter: document.chapter,
                startVerse: start,
                endVerse: end,
                action: action,
                translationName: translationName,
                verseContextText: verseContextText
            )
        }
    }

    private func startHubConversation(for verse: VerseID) {
        guard let document = session.document else { return }
        let map = ChapterTextMap(document: document)
        let ranges = map.focusRanges(for: verse.verse)
        guard !ranges.isEmpty else { return }
        let union = ranges.dropFirst().reduce(ranges[0]) { NSUnionRange($0, $1) }
        let selection = map.selection(in: union)
        askCompanion(from: selection)
    }

    private var readerBookVersionPicker: some View {
        HStack(spacing: 0) {
            Button { picker = .book } label: {
                Text(selectedBookTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: bookButtonWidth, height: 44)
            }
            .accessibilityIdentifier("reader.book")
            .accessibilityLabel("Book, \(session.title)")
            .accessibilityValue(session.title)
            .disabled(session.document == nil)
            Rectangle().fill(Color(palette.rule)).frame(width: 1, height: 22)
            Button { picker = .version } label: {
                Text(session.abbreviation)
                    .frame(minWidth: 82, minHeight: 44)
            }
            .accessibilityIdentifier("reader.version")
            .accessibilityLabel("Version, \(session.abbreviation)")
        }
        .background(Color(palette.paper), in: Capsule())
        .overlay(Capsule().stroke(Color(palette.rule), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
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

private struct HubShare: Identifiable {
    let id = UUID()
    let text: String
}

private struct ScriptureActivitySheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct PendingQuote: Identifiable {
    let id = UUID()
    let quote: NoteQuote
}
