import SwiftUI

/// A Plan opens as study content. Editing is a separate, explicit action.
struct PlanDetailView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var music: MusicSession
    @EnvironmentObject private var activity: ActivityStore
    @EnvironmentObject private var companion: CompanionSession
    @Environment(AnnotationSession.self) private var annotations
    @EnvironmentObject private var sophy: SophySession
    @State private var recorderEngagedUntil = Date.distantPast
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var store: CollectionsStore
    @ObservedObject private var protection = ItemProtectionSession.shared
    let notes: NotesSession
    let reader: ReaderSession?
    let collectionID: UUID
    let planID: UUID
    var openNote: (UUID) -> Void
    enum InitialRoute {
        case detail, edit, review(UUID)
    }
    var initialRoute: InitialRoute = .detail
    @State private var usedInitialRoute = false
    @State private var reviewCursor: PlanCursor?
    @State private var passageReader: ReaderSession?
    @State private var planConversationID: UUID?
    @State private var priorConversationID: UUID?
    /// True when the overlay shows a conversation saved as a Plan assignment, not a new study question.
    @State private var resumedConversation = false
    @State private var priorCompanionDraft = ""
    @State private var editing: PlanEditorDraft?
    @State private var reading = false
    @State private var loading = false
    @State private var saving = false
    @State private var transitioning = false
    @State private var message: String?
    @State private var linkID: UUID?
    @State private var reflection: PlanReflectionDraft?
    @State private var pendingNoteID: UUID?
    @State private var previewNoteID: UUID?
    @State private var showingCompletion = false
    @State private var showingMusic = false
    @State private var showingMusicLibrary = false

    private var playback: PlanPlaybackService { .init(store: store, activity: activity) }
    private var plan: StudyPlan? { store.plans.first { $0.id == planID && $0.trashedAt == nil } }
    private var permitted: Bool { plan.map { store.planAccessAllowed($0) } ?? false }
    private var cursor: PlanCursor? { reviewCursor ?? plan?.cursor }
    private var item: PlanItem? { plan?.items.first { $0.id == cursor?.itemID } }

    private var assignmentReady: Bool {
        guard let item, cursor?.kind == .item else { return true }
        switch item.payload.kind {
        case .scripture:
            return passageReader?.document?.book == item.payload.book && passageReader?.document?.chapter == item.payload.chapter
                && passageReader?.document?.editionID == plan?.preferredEditionID && passageReader?.error == nil
        case .note:
            guard let id = item.payload.targetID, let note = notes.snapshot.notes.first(where: { $0.id == id }) else { return false }
            return note.isActiveInLibrary && !notes.isLocked(note) && !store.concealsNote(id)
        case .link: return item.payload.targetID.flatMap { readableLink($0) } != nil
        case .conversation: return item.payload.targetID.flatMap { readableConversation($0) } != nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ZStack {
                    Group {
                        if let plan, permitted {
                            if let editing {
                                PlanEditorView(store: store, notes: notes, reader: reader, collectionID: collectionID,
                                    model: editing, embedded: true, onFinish: {
                                        self.editing = nil
                                        if store.plans.first(where: { $0.id == planID })?.trashedAt != nil { dismiss() }
                                    })
                                    .accessibilityIdentifier("plans.inlineEditor")
                            } else if reading || reviewCursor != nil { readingContent(plan) } else { contents(plan) }
                        } else {
                            ContentUnavailableView("Plan unavailable", systemImage: "lock", description: Text("Unlock Collections to view this Plan."))
                        }
                    }
                    .accessibilityHidden(planConversationID != nil)
                    .allowsHitTesting(planConversationID == nil)
                    if previewNoteID == nil { conversationOverlay }
                }
            }
            .appSurface()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let message { Text(message).font(.callout).foregroundStyle(.red).padding() }
                    if reading, permitted, let plan { readingControls(plan) }
                    if reviewCursor != nil, permitted {
                        conversationButton(item: item, noteID: nil)
                            .labelStyle(.iconOnly).buttonStyle(PlanControlStyle()).padding(12)
                            .disabled(loading || transitioning)
                    }
                }
                .background(Color(theme.palette.paper))
                .disabled(planConversationID != nil)
                .accessibilityHidden(planConversationID != nil)
            }
            .sheet(isPresented: $showingCompletion, onDismiss: { Task { await closePlan() } }) {
                completionContent
            }
            .sheet(isPresented: Binding(get: { linkID != nil }, set: { if !$0 { linkID = nil } })) {
                if let linkID, permitted, store.link(id: linkID) != nil {
                    StudyLinkSheet(store: store, linkID: linkID, collectionID: collectionID)
                }
            }
            .sheet(item: $reflection, onDismiss: {
                if let id = pendingNoteID { pendingNoteID = nil; previewNote(id) }
            }) { draft in
                if draft.kind == .note {
                    NoteCreatorSheet(notes: notes, createOverride: { kind, color, title in
                        await draft.createNote(kind: kind, color: color, title: title, notes: notes, store: store, collectionID: collectionID)
                    }) { id in pendingNoteID = id }
                } else { PlanNewLinkView(store: store, collectionID: collectionID, draft: draft) }
            }
            .navigationDestination(isPresented: Binding(get: { previewNoteID != nil }, set: { if !$0 { closeNotePreview() } })) {
                if permitted, let id = previewNoteID, readableNote(id) != nil, let reader {
                    ZStack {
                        NoteEditorView(session: notes, reader: reader, collections: store, includesScripturePane: false)
                            .accessibilityHidden(planConversationID != nil)
                            .allowsHitTesting(planConversationID == nil)
                        conversationOverlay
                    }
                        .toolbar(.visible, for: .navigationBar)
                        .navigationBarBackButtonHidden()
                        .toolbar { ToolbarItem(placement: .cancellationAction) {
                            Button("Back to Plan") { closeNotePreview() }.accessibilityIdentifier("plans.note.back")
                        } }
                        .toolbar { ToolbarItem(placement: .primaryAction) {
                            conversationButton(item: nil, noteID: id)
                        } }
                        .onDisappear { notes.flushSurface?(); Task { await notes.save() } }
                } else { ContentUnavailableView("Note unavailable", systemImage: "lock") }
            }
            .onAppear { notes.planPresentationActive = true; music.load() }
            .task {
                await activity.load(); await reader?.start()
                guard !usedInitialRoute, permitted, let plan else { return }
                usedInitialRoute = true
                switch initialRoute {
                case .detail: break
                case .edit: editing = PlanEditorDraft(plan: plan, isExisting: true)
                case .review(let id): await review(plan, itemID: id)
                }
            }
            .task(id: passageReader?.navigationID) {
                guard let passageReader else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { return }
                    await passageReader.checkAccess()
                }
            }
            .onChange(of: activity.draft?.id) { _, _ in
                guard reading, !transitioning else { return }
                Task { await reconcileActivityEnd() }
            }
            .onChange(of: planContextIsReadable) { _, readable in
                if !readable { clearPlanConversation() }
            }
            .onChange(of: permitted) { _, allowed in
                if !allowed {
                    notes.flushSurface?(); notes.selectedNoteID = nil; notes.active = false
                    Task { _ = await playback.pause(planID) }
                    showingCompletion = false
                    clearPlanConversation()
                    concealPassage()
                    reading = false; editing = nil; linkID = nil; reflection = nil; previewNoteID = nil; showingMusic = false
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    clearPlanConversation(); concealPassage(); notes.flushSurface?()
                    Task { await notes.save(); _ = await playback.pause(planID) }
                    reading = false; linkID = nil; showingMusic = false
                }
            }
        }
        .overlay {
            if planConversationID == nil, let reader {
                SophyChrome(sophy: sophy, companion: companion, collections: store, activity: activity,
                    music: music, notes: notes, books: reader.books,
                    referenceSystemID: reader.edition?.referenceSystemID ?? "org.sophia.web.engwebp",
                    editionID: reader.edition?.id, editionCatalog: "",
                    scriptureRepositoryProvider: { id in try await reader.contentRepository(editionID: id) }, planToShare: editing == nil ? plan : nil)
            }
        }
        .overlay {
            if planConversationID == nil, let draft = activity.draft {
                ActivityFloatingRecorder(draft: draft, fabEngagedUntil: $recorderEngagedUntil,
                    pauseOrResume: { if activity.draft?.runningSince == nil { activity.resume() } else { activity.pause() } },
                    finish: { Task {
                        await closePlan()
                        if !notes.planPresentationActive { sophy.onOpenActivity?(); activity.requestFinish() }
                    } })
            }
        }
        .onChange(of: store.plans) { _, _ in sophy.privacyChanged(collections: store, notes: notes) }
        .onChange(of: cursor) { old, new in
            clearPlanConversation()
            if reading, old?.kind == .sectionSummary, new?.kind == .item { Task { await loadAssignment() } }
        }
        .onDisappear {
            clearPlanConversation(); concealPassage()
            if sophy.sharedPlan?.id == planID { sophy.detachPlan() }
        }
        .interactiveDismissDisabled()
    }

    private var header: some View {
        let returningToPlan = planConversationID != nil || reviewCursor != nil
        return HStack(spacing: 16) {
            Button {
                Task {
                    if planConversationID != nil { clearPlanConversation() }
                    else if reviewCursor != nil { await closeReview() }
                    else { await closePlan() }
                }
            } label: { Image(systemName: returningToPlan ? "chevron.left" : "xmark").frame(width: 44, height: 44) }
                .buttonStyle(CollectionSecondaryButtonStyle()).accessibilityLabel(returningToPlan ? "Back to Plan" : "Exit Plan").accessibilityIdentifier("plans.exit")
            VStack(alignment: .leading, spacing: 3) {
                Text("READ · REFLECT · REMEMBER").font(.caption2).tracking(2).foregroundStyle(Color(theme.palette.secondary))
                Text(permitted ? plan?.title ?? "Plan" : "Plan").font(.system(.title2, design: .serif).weight(.semibold)).lineLimit(1)
            }
            Spacer(minLength: 4)
            if planConversationID == nil, permitted, editing == nil, let plan, sophy.preferences.enabled {
                Button("Share with " + sophy.character.displayName, systemImage: "bubble.left.and.bubble.right") {
                    sophy.syncRoute(companion)
                    sophy.sharePlan(plan, collections: store)
                }.labelStyle(.iconOnly).buttonStyle(CollectionSecondaryButtonStyle())
                    .disabled(!store.sophyCanSharePlan(plan) || sophy.isWorking)
                    .accessibilityIdentifier("plans.shareWithSophy")
            }
            if let editing, permitted {
                Text(editing.saveStatus).font(.caption).foregroundStyle(Color(theme.palette.secondary))
                    .accessibilityIdentifier("plans.headerSaveStatus")
                Button("Done", systemImage: "checkmark") { Task { await finishEditing() } }
                    .buttonStyle(CollectionSecondaryButtonStyle()).disabled(saving || editing.saving)
                    .accessibilityIdentifier("plans.finishEditing")
            } else if permitted, !reading, reviewCursor == nil, let plan {
                Button("Edit", systemImage: "pencil") { editing = PlanEditorDraft(plan: plan, isExisting: true) }
                    .buttonStyle(CollectionSecondaryButtonStyle()).accessibilityIdentifier("plans.edit")
            }
        }.padding(.horizontal, 24).padding(.vertical, 14)
            .background(Color(theme.palette.paper))
            .overlay(alignment: .bottom) { Rectangle().fill(Color(theme.palette.rule)).frame(height: 1) }
    }

    private func contents(_ plan: StudyPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(plan.title).font(.system(.largeTitle, design: .serif).weight(.semibold))
                    if !plan.detail.isEmpty { Text(plan.detail).foregroundStyle(Color(theme.palette.secondary)) }
                    HStack {
                        Text("\(plan.completedSectionCount) of \(plan.sections.count) completed").font(.subheadline).foregroundStyle(Color(theme.palette.secondary))
                        Spacer()
                        Button(plan.cursor == nil ? "Start" : "Resume", systemImage: "play.fill") { Task { await start(plan) } }
                            .buttonStyle(CollectionProminentButtonStyle())
                            .disabled((plan.playbackStartCursor == nil && !(plan.cursor?.kind == .sectionSummary && plan.cursor?.activitySessionID != nil && activity.draft?.id == plan.cursor?.activitySessionID)) || reader == nil || saving || transitioning || plan.archivedAt != nil)
                            .accessibilityIdentifier("plans.start")
                    }
                    ProgressView(value: Double(plan.completedSectionCount), total: Double(max(1, plan.sections.count))).tint(Color(theme.palette.accent))
                }
                ForEach(Array(plan.sections.enumerated()), id: \.element.id) { index, section in
                    VStack(alignment: .leading, spacing: 14) {
                        Button { Task { await start(plan, sectionID: section.id) } } label: {
                            Text(plan.sectionTitle(index)).font(.system(.title2, design: .serif).weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .disabled(section.items.isEmpty || reader == nil || saving || transitioning || plan.archivedAt != nil)
                            .accessibilityHint("Start or resume this day")
                            .accessibilityIdentifier("plans.playDay.\(index + 1)")
                        VStack(spacing: 0) {
                            if section.items.isEmpty { Text("No assignments").foregroundStyle(Color(theme.palette.secondary)).padding(20) }
                            ForEach(section.items) { item in
                                assignmentRow(item, plan: plan)
                                if item.id != section.items.last?.id { Divider().padding(.leading, 56) }
                            }
                        }.background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 22))
                            .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color(theme.palette.rule), lineWidth: 1) }
                        if let caption = plan.scheduleCaption(for: index) {
                            Text(caption).font(.caption).foregroundStyle(Color(theme.palette.secondary))
                                .accessibilityIdentifier("plans.dayDates.\(index + 1)")
                        }
                    }
                }
            }.padding(28).frame(maxWidth: 960).frame(maxWidth: .infinity, alignment: .top)
        }
    }
    private func assignmentRow(_ item: PlanItem, plan: StudyPlan) -> some View {
        Button {
            switch item.payload.kind {
            case .note: if let id = item.payload.targetID { previewNote(id) }
            case .link: linkID = item.payload.targetID
            case .conversation: if let id = item.payload.targetID { Task { await resumeConversation(id) } }
            case .scripture: Task { await review(plan, itemID: item.id) }
            }
        } label: {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: item.completedAt == nil ? "circle" : "checkmark.circle.fill").font(.title3)
                    .foregroundStyle(Color(item.completedAt == nil ? theme.palette.secondary : theme.palette.accent))
                VStack(alignment: .leading, spacing: 6) {
                    Text(title(item)).font(.system(.headline, design: .serif)).foregroundStyle(Color(theme.palette.ink))
                    if item.payload.kind == .note, let id = item.payload.targetID, let note = readableNote(id) {
                        Text(note.kind.displayName).font(.caption).foregroundStyle(Color(theme.palette.accent))
                        if let body = note.page?.body, !body.isEmpty {
                            Text(String(body.replacingOccurrences(of: "\u{FFFC}", with: "").prefix(240))).font(.subheadline).lineLimit(3).foregroundStyle(Color(theme.palette.secondary))
                        }
                        Text("Preview note").font(.caption).foregroundStyle(Color(theme.palette.accent))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color(theme.palette.secondary))
            }.padding(20).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("plans.assignment.\(item.id)")
            .accessibilityValue(item.completedAt == nil ? "Not completed" : "Completed")
    }

    @ViewBuilder private func readingContent(_ plan: StudyPlan) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                if let index = plan.sections.firstIndex(where: { $0.id == cursor?.sectionID }) {
                    Text(plan.sectionTitle(index)).font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(Color(theme.palette.secondary))
                }
                if let item { Text(title(item)).font(.system(.title, design: .serif).weight(.semibold)) }
                if item?.payload.kind == .scripture { Text(passageReader?.edition?.name ?? "").font(.caption).foregroundStyle(Color(theme.palette.secondary)) }
            }.padding(.top, 20).padding(.horizontal)
            if loading { ProgressView("Loading assignment…").frame(maxHeight: .infinity) }
            else if cursor?.kind == .sectionSummary {
                ContentUnavailableView("Section complete", systemImage: "checkmark.circle", description: Text("Finish this day to save its activity and exit."))
            } else if cursor?.kind == .planSummary {
                ContentUnavailableView("Plan complete", systemImage: "checkmark.seal", description: Text("Your progress is saved."))
            } else if let item {
                switch item.payload.kind {
                case .scripture:
                    if let reader = passageReader, let document = reader.document,
                       assignmentReady, let scope = annotationScope, let name = layerName(in: plan) {
                        PlanPassageReader(reader: reader, document: document, annotations: annotations,
                            scope: scope, layerName: name,
                            focus: item.payload.selection == .verseRange ? reader.emphasisVerses : nil)
                            .allowsHitTesting(!transitioning || annotations.usingTool)
                        if annotations.planScope != scope {
                            Button("Retry opening Pencil layer") { Task { await loadAssignment() } }
                        }
                    } else {
                        ContentUnavailableView("Scripture unavailable", systemImage: "book.closed", description: Text(passageReader?.error ?? "Download this Plan’s translation before reading."))
                        Button("Retry") { Task { await loadAssignment() } }
                    }
                case .note:
                    if let id = item.payload.targetID, readableNote(id) != nil, let reader, notes.selectedNoteID == id {
                        NoteEditorView(session: notes, reader: reader, collections: store, includesScripturePane: false)
                    } else { ContentUnavailableView("Note unavailable", systemImage: "lock") }
                case .link:
                    if let id = item.payload.targetID, let link = readableLink(id) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Image(systemName: "link").font(.largeTitle).foregroundStyle(Color(theme.palette.accent))
                                Text(link.url).textSelection(.enabled).foregroundStyle(Color(theme.palette.secondary))
                                Button("Open link", systemImage: "safari") { linkID = id }.buttonStyle(CollectionProminentButtonStyle())
                            }.padding(28).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
                        }
                    } else { ContentUnavailableView("Link unavailable", systemImage: "lock") }
                case .conversation:
                    if let id = item.payload.targetID, let conversation = readableConversation(id) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                Image(systemName: "bubble.left.and.bubble.right").font(.largeTitle).foregroundStyle(Color(theme.palette.accent))
                                Text(conversation.title).font(.system(.title3, design: .serif)).foregroundStyle(Color(theme.palette.secondary))
                                Button("Open conversation", systemImage: "bubble.left.and.text.bubble.right") { Task { await resumeConversation(id) } }
                                    .buttonStyle(CollectionProminentButtonStyle())
                                    .accessibilityIdentifier("plans.conversation.open")
                            }.padding(28).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
                        }
                    } else { ContentUnavailableView("Conversation unavailable", systemImage: "lock") }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func readingControls(_ plan: StudyPlan) -> some View {
        HStack(spacing: 12) {
            Button("Previous", systemImage: "chevron.left") { Task { await previous(plan) } }
                .disabled(previousCursor(plan) == nil).accessibilityIdentifier("plans.previous")
            Spacer(minLength: 0)
            Button("Add new note", systemImage: "square.and.pencil") { beginReflection(.note, plan: plan) }.disabled(cursor?.sectionID == nil).accessibilityIdentifier("plans.addNote")
            Button("Add new link", systemImage: "link.badge.plus") { beginReflection(.link, plan: plan) }.disabled(cursor?.sectionID == nil).accessibilityIdentifier("plans.addLink")
            conversationButton(item: item, noteID: nil)
            Button("Background music", systemImage: "music.note") { showingMusic = true }.accessibilityIdentifier("plans.music")
                .popover(isPresented: $showingMusic) {
                    NavigationStack {
                        VStack(spacing: 20) {
                            Text(music.currentTrack?.title ?? "Background music").font(.system(.title3, design: .serif))
                            Button(music.snapshot.phase == .playing ? "Pause" : "Play", systemImage: music.snapshot.phase == .playing ? "pause.fill" : "play.fill") {
                                music.handle(.togglePlayPause)
                            }.buttonStyle(CollectionProminentButtonStyle()).disabled(music.currentTrack == nil).accessibilityIdentifier("plans.music.toggle")
                            Button("Choose music", systemImage: "music.note.list") { showingMusicLibrary = true }.buttonStyle(CollectionSecondaryButtonStyle())
                        }.padding(28).frame(minWidth: 300).appSurface()
                        .navigationDestination(isPresented: $showingMusicLibrary) { BackgroundMusicLibraryView(session: music).appSurface() }
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingMusic = false } } }
                    }.frame(width: 380, height: 460).presentationCompactAdaptation(.popover)
                }
            Spacer(minLength: 0)
            Button(cursor?.kind == .sectionSummary ? "Finish day" : "Next", systemImage: cursor?.kind == .sectionSummary ? "checkmark" : "chevron.right") { Task { await next(plan) } }
                .disabled(!assignmentReady).accessibilityIdentifier("plans.next")
        }
        .labelStyle(.iconOnly).buttonStyle(PlanControlStyle())
        .padding(.horizontal, 24).padding(.vertical, 12)
        .frame(maxWidth: 960).frame(maxWidth: .infinity)
        .background(Color(theme.palette.paper))
        .overlay(alignment: .top) { Rectangle().fill(Color(theme.palette.rule)).frame(height: 1) }
        .disabled(saving || loading || transitioning)
    }
    private func beginReflection(_ kind: PlanReflectionDraft.Kind, plan: StudyPlan) {
        guard permitted, let sectionID = cursor?.sectionID else { return }
        reflection = .init(kind: kind, plan: plan, sectionID: sectionID, anchorID: cursor?.itemID)
    }
    private func readableNote(_ id: UUID) -> NoteDocument? {
        notes.snapshot.notes.first { $0.id == id && $0.isActiveInLibrary && !notes.isLocked($0) && !store.concealsNote($0.id) }
    }
    private func readableConversation(_ id: UUID) -> CompanionConversation? {
        guard !store.collectionIDs(containing: id).contains(where: store.isLocked) else { return nil }
        return companion.conversations.first { $0.id == id && $0.state != .archived && !$0.isTrashed }
    }
    private func readableLink(_ id: UUID) -> SavedLink? {
        guard !store.collectionIDs(containing: id).contains(where: store.isLocked) else { return nil }
        return store.link(id: id)
    }
    private func previewNote(_ id: UUID) {
        guard permitted, readableNote(id) != nil else { return }
        notes.open(id); notes.active = true; previewNoteID = id
    }
    private func closeNotePreview() {
        clearPlanConversation()
        notes.flushSurface?(); previewNoteID = nil; notes.selectedNoteID = nil; notes.active = false
        Task { await notes.save(); if reading { await loadAssignment() } }
    }
    private func finishEditing() async {
        guard let editing, !saving else { return }
        saving = true; defer { saving = false }
        guard await editing.persist(store: store, collectionID: collectionID) else { return }
        self.editing = nil
    }
    private func closePlan() async {
        guard !saving, !transitioning, reflection?.saving != true else { return }
        transitioning = true; defer { transitioning = false }
        guard await savePlanInk() else { return }
        if let editing, permitted {
            guard await editing.persist(store: store, collectionID: collectionID) else { return }
            self.editing = nil
        }
        notes.flushSurface?(); await notes.save()
        guard !notes.dirty else { message = "The note could not be saved. Retry before exiting."; return }
        guard await playback.pause(planID) else { message = activity.errorMessage; return }
        clearPlanConversation()
        concealPassage()
        notes.planPresentationActive = false
        notes.selectedNoteID = nil; notes.active = false; reading = false; dismiss()
    }

    private func title(_ item: PlanItem) -> String {
        switch item.payload.kind {
        case .scripture: return item.payload.referenceLabel(bookTitle: reader?.books.first(where: { $0.id == item.payload.book })?.title ?? item.payload.book ?? "Scripture")
        case .note:
            guard let note = notes.snapshot.notes.first(where: { $0.id == item.payload.targetID }), note.isActiveInLibrary else { return "Note unavailable" }
            return notes.isLocked(note) || store.concealsNote(note.id) ? "Locked note" : note.title
        case .link:
            guard let id = item.payload.targetID, let link = readableLink(id) else { return "Link unavailable" }
            return link.title
        case .conversation:
            guard let id = item.payload.targetID else { return "Conversation unavailable" }
            if store.collectionIDs(containing: id).contains(where: store.isLocked) { return "Locked conversation" }
            return companion.conversations.first(where: { $0.id == id && !$0.isTrashed })?.title
                ?? store.conversation(id: id)?.title ?? "Conversation unavailable"
        }
    }
    private func itemCursor(_ plan: StudyPlan, _ section: PlanSection, _ item: PlanItem) -> PlanCursor {
        .init(kind: .item, sectionID: section.id, itemID: item.id, editionID: plan.preferredEditionID)
    }
    private func start(_ plan: StudyPlan, sectionID: UUID? = nil) async {
        guard !transitioning, permitted else { return }; transitioning = true; defer { transitioning = false }
        do {
            let started = try await playback.start(plan.id, sectionID: sectionID)
            message = nil
            if started {
                guard permitted, scenePhase == .active else { _ = await playback.pause(planID); return }
                reading = true; await loadAssignment()
            }
            else { reading = false; showingCompletion = true }
        } catch { message = error.localizedDescription }
    }
    private func reconcileActivityEnd() async {
        guard !transitioning, permitted else { return }; transitioning = true; defer { transitioning = false }
        guard await savePlanInk() else { return }
        if let noteID = notes.selectedNoteID, item?.payload.kind == .note {
            let result = await notes.commitPlanEdits(noteID: noteID, operationID: UUID())
            guard case .committed = result else { message = "Save the note before finishing this day."; return }
        }
        do {
            if try await playback.reconcileFinishedActivity(planID) {
                notes.flushSurface?(); await notes.save()
                clearPlanConversation(); concealPassage(); reading = false; showingCompletion = true
            }
        } catch { message = error.localizedDescription }
    }
    private var completionContent: some View {
        VStack(spacing: 20) {
            Image(systemName: plan?.isComplete == true ? "checkmark.seal.fill" : "sun.max.fill")
                .font(.system(size: 64)).foregroundStyle(Color(theme.palette.accent))
            Text("Congratulations!").font(.system(.largeTitle, design: .serif).weight(.semibold))
            Text(plan?.isComplete == true ? "Plan complete" : "Section complete")
                .font(.title2.weight(.semibold))
            if let plan, let s = plan.sections.firstIndex(where: { $0.id == cursor?.sectionID }) {
                Text("\(plan.title) — \(plan.sectionTitle(s))").font(.headline)
            }
            Text("Your progress and activity are saved. Take a moment to carry what you have learned into your day.")
                .multilineTextAlignment(.center).foregroundStyle(Color(theme.palette.secondary))
            Button("Done", systemImage: "checkmark") { showingCompletion = false }
                .buttonStyle(CollectionProminentButtonStyle()).accessibilityIdentifier("plans.completion.done")
        }.padding(36).frame(maxWidth: .infinity, maxHeight: .infinity).appSurface()
            .presentationDetents([.height(540)]).interactiveDismissDisabled()
    }
    private func commit(_ original: StudyPlan, cursor: PlanCursor?, completing: UUID? = nil) async -> Bool {
        guard permitted, !saving else { return false }
        saving = true; defer { saving = false }
        var updated = original; updated.cursor = cursor
        if let completing {
            for s in updated.sections.indices {
                if let i = updated.sections[s].items.firstIndex(where: { $0.id == completing }), updated.sections[s].items[i].completedAt == nil { updated.sections[s].items[i].completedAt = Date() }
            }
        }
        let result = await store.submit(.init(expectedPlanRevision: original.revision, intent: .savePlan(updated, collectionID: collectionID)))
        message = result.message
        return result.receipt != nil
    }
    private func next(_ plan: StudyPlan) async {
        guard !transitioning else { return }; transitioning = true; defer { transitioning = false }
        guard await savePlanInk() else { return }
        if let noteID = notes.selectedNoteID, item?.payload.kind == .note {
            let result = await notes.commitPlanEdits(noteID: noteID, operationID: UUID())
            guard case .committed = result else { message = "Save the note before continuing."; return }
        }
        do {
            let completed = try await playback.advance(plan.id)
            message = nil
            if completed { concealPassage(); reading = false; showingCompletion = true }
            else { await loadAssignment() }
        } catch { message = error.localizedDescription }
    }
    private func previousCursor(_ plan: StudyPlan) -> PlanCursor? {
        guard let section = plan.sections.first(where: { $0.id == cursor?.sectionID }),
              cursor?.kind == .item,
              let i = section.items.firstIndex(where: { $0.id == cursor?.itemID }), i > 0 else { return nil }
        var target = itemCursor(plan, section, section.items[i - 1])
        target.activitySessionID = cursor?.activitySessionID
        return target
    }
    private func previous(_ plan: StudyPlan) async {
        guard !transitioning else { return }; transitioning = true; defer { transitioning = false }
        guard await savePlanInk() else { return }
        if let noteID = notes.selectedNoteID, item?.payload.kind == .note {
            let result = await notes.commitPlanEdits(noteID: noteID, operationID: UUID())
            guard case .committed = result else { message = "Save the note before continuing."; return }
        }
        guard let target = previousCursor(plan) else { return }
        if await commit(plan, cursor: target) { await loadAssignment() }
    }
    private var annotationScope: PlanAnnotationScope? {
        cursor?.sectionID.map { PlanAnnotationScope(planID: planID, sectionID: $0) }
    }

    private func layerName(in plan: StudyPlan) -> String? {
        guard let index = plan.sections.firstIndex(where: { $0.id == cursor?.sectionID }) else { return nil }
        let suffix = " · \(plan.sectionPrefix) \(index + 1)"
        return String(plan.title.prefix(80 - suffix.count)) + suffix
    }

    private func savePlanInk() async -> Bool {
        guard annotations.planScope?.planID == planID else { return true }
        if await annotations.prepareForNavigation() { return true }
        message = "The Pencil layer could not be saved. Retry before leaving this passage."
        return false
    }

    private func concealPassage() {
        if annotations.planScope?.planID == planID {
            annotations.closePlanChapter()
            Task { await annotations.save() }
        }
        passageReader = nil
        reviewCursor = nil
    }

    private func review(_ plan: StudyPlan, itemID: UUID) async {
        guard permitted, !transitioning, !reading, reader != nil,
              let section = plan.sections.first(where: { $0.items.contains(where: { $0.id == itemID }) }),
              let item = section.items.first(where: { $0.id == itemID && $0.payload.kind == .scripture }) else { return }
        transitioning = true; defer { transitioning = false }
        reviewCursor = itemCursor(plan, section, item)
        await loadAssignment()
    }

    private func closeReview() async {
        guard !transitioning else { return }
        transitioning = true; defer { transitioning = false }
        guard await savePlanInk() else { return }
        concealPassage()
        message = nil
    }

    private func conversationButton(item: PlanItem?, noteID: UUID?) -> some View {
        Button("New conversation", systemImage: "bubble.left.and.bubble.right") {
            Task { await openConversation(item: item, noteID: noteID) }
        }
        .accessibilityIdentifier("plans.newConversation")
        .disabled(noteID == nil && (!assignmentReady || (item?.payload.kind != .note && item?.payload.kind != .scripture)))
    }

    @ViewBuilder private var conversationOverlay: some View {
        if let id = planConversationID, planContextIsReadable {
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    Color(theme.palette.ink).opacity(0.12).accessibilityHidden(true)
                    PlanCompanionPanel(session: companion, conversationID: id, notes: notes,
                        close: clearPlanConversation, openNote: { noteID in
                            clearPlanConversation()
                            previewNote(noteID)
                        })
                        .frame(width: min(geometry.size.width, 520))
                }
            }
        }
    }

    private func openConversation(item: PlanItem?, noteID: UUID?) async {
        guard permitted, scenePhase == .active, !transitioning, planConversationID == nil else { return }
        transitioning = true; defer { transitioning = false }
        guard await savePlanInk() else { return }
        await companion.load()
        guard permitted, scenePhase == .active, !companion.isSending else { return }
        let context: PlanQuestionContext
        var privateContext = !store.accessForPlan(planID).isEmpty
        let canSend: () -> Bool
        if let noteID = noteID ?? item?.payload.targetID, noteID == previewNoteID || item?.payload.kind == .note {
            notes.flushSurface?()
            guard let note = readableNote(noteID) else { return }
            context = .note(note)
            privateContext = privateContext || note.protectionID != nil || !note.access.isEmpty
                || store.collectionIDs(containing: noteID).contains(where: store.sophyFolderIsProtected)
            canSend = { permitted && readableNote(noteID) != nil && (noteID == previewNoteID || self.item?.id == item?.id) }
        } else if let item, item.id == self.item?.id, assignmentReady,
                  let passageReader, let document = passageReader.document {
            await passageReader.checkAccess()
            guard permitted, assignmentReady, passageReader.document?.contentRevision == document.contentRevision else { return }
            context = .scripture(document, assignment: item.payload,
                label: title(item) + " (\(passageReader.abbreviation))")
            canSend = { permitted && assignmentReady && self.item?.id == item.id }
        } else { return }
        guard permitted, scenePhase == .active, canSend() else { return }
        let previousID = companion.selectedConversationID
        let previousDraft = companion.composerText
        let conversationTitle: String
        if privateContext {
            conversationTitle = context.isScripture ? "Plan Scripture study" : "Plan note study"
        } else if !context.isScripture, context.label == "Untitled Note", let plan {
            conversationTitle = CompanionConversationTitle.fromQuestion("Note study · \(plan.title)")
        } else {
            conversationTitle = context.label
        }
        guard let id = companion.createConversation(title: conversationTitle) else {
            message = companion.notice
            companion.clearNotice()
            return
        }
        priorConversationID = previousID
        priorCompanionDraft = previousDraft
        companion.attachPlanContext(context, to: id, canSend: canSend)
        planConversationID = id
        message = nil
        await assignConversation(id, item: item, noteID: noteID)
    }

    /// Records a conversation started in the Plan as a completed assignment after its source item.
    private func assignConversation(_ id: UUID, item: PlanItem?, noteID: UUID?) async {
        guard let plan, permitted else { return }
        let anchor: PlanItem?
        if let item { anchor = item }
        else if let noteID { anchor = plan.items.first { $0.payload.kind == .note && $0.payload.targetID == noteID } }
        else { anchor = nil }
        guard let sectionID = anchor.flatMap({ anchor in plan.sections.first { $0.items.contains { $0.id == anchor.id } }?.id })
                ?? cursor?.sectionID ?? plan.sections.first?.id else { return }
        let draft = PlanReflectionDraft(kind: .conversation, plan: plan, sectionID: sectionID, anchorID: anchor?.id, targetID: id)
        if !(await draft.attachConversation(store: store, collectionID: collectionID)) { message = draft.message }
    }

    private func resumeConversation(_ id: UUID) async {
        guard permitted, scenePhase == .active, !transitioning, planConversationID == nil else { return }
        transitioning = true; defer { transitioning = false }
        guard await savePlanInk() else { return }
        await companion.load()
        guard permitted, readableConversation(id) != nil else { message = "This conversation is unavailable."; return }
        priorConversationID = companion.selectedConversationID
        priorCompanionDraft = companion.composerText
        companion.selectConversation(id)
        resumedConversation = true
        planConversationID = id
        message = nil
    }

    private var planContextIsReadable: Bool {
        if resumedConversation, let id = planConversationID { return permitted && readableConversation(id) != nil }
        if let noteID = previewNoteID ?? item?.payload.targetID, previewNoteID != nil || item?.payload.kind == .note {
            return permitted && readableNote(noteID) != nil
        }
        return permitted && assignmentReady
    }

    private func clearPlanConversation() {
        guard let id = planConversationID else { return }
        companion.closePlanConversation(id)
        if companion.selectedConversationID == id {
            companion.selectConversation(priorConversationID)
            companion.composerText = priorCompanionDraft
        }
        planConversationID = nil
        resumedConversation = false
        priorConversationID = nil
        priorCompanionDraft = ""
    }

    private func loadAssignment() async {
        guard permitted, reading || reviewCursor != nil else { return }
        guard cursor?.kind == .item, let item, let plan else {
            concealPassage()
            return
        }
        loading = true; defer { loading = false }
        let expectedCursor = cursor
        if item.payload.kind != .scripture {
            if annotations.planScope?.planID == planID { annotations.closePlanChapter() }
            passageReader = nil
            if item.payload.kind == .note, let id = item.payload.targetID, readableNote(id) != nil {
                notes.open(id); notes.active = true
            }
            return
        }
        notes.flushSurface?(); await notes.save(); notes.active = false
        guard let reader, let book = item.payload.book, let chapter = item.payload.chapter else { return }
        let session = reader.makePlanReader()
        let isRange = item.payload.selection == .verseRange
        await session.openPlanPassage(editionID: plan.preferredEditionID, book: book, chapter: chapter,
            verse: isRange ? item.payload.startVerse : nil, endVerse: isRange ? item.payload.endVerse : nil)
        guard permitted, scenePhase == .active, cursor == expectedCursor, reading || reviewCursor != nil, !Task.isCancelled else { return }
        passageReader = session
        guard let document = session.document, let scope = annotationScope, let name = layerName(in: plan) else { return }
        let prepared = await annotations.preparePlanChapter()
        guard permitted, scenePhase == .active, cursor == expectedCursor, reading || reviewCursor != nil, !Task.isCancelled else { return }
        if prepared {
            annotations.openPlanChapter(document, scope: scope, name: name)
            message = nil
        } else {
            message = "Pencil layers are unavailable. Retry opening this passage to enable drawing."
        }
    }
}

private struct PlanControlStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 21, weight: .medium))
            .frame(width: 48, height: 48)
            .foregroundStyle(Color(theme.palette.accent))
            .background(Color(theme.palette.soft), in: Circle())
            .overlay { Circle().stroke(Color(theme.palette.rule), lineWidth: 1) }
            .opacity(enabled ? (configuration.isPressed ? 0.65 : 1) : 0.3)
    }
}

/// A presentation-only mark derived from checked assignments, never a separate saved status.
struct PlanCompletedStamp: View {
    let planID: UUID
    var isActive = true
    var body: some View {
        NoteCardStatusStamp(mark: .completed, noteID: planID, isActive: isActive)
    }
}
