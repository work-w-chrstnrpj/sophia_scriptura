import SwiftUI

/// A Plan opens as study content. Editing is a separate, explicit action.
struct PlanDetailView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var music: MusicSession
    @EnvironmentObject private var activity: ActivityStore
    @EnvironmentObject private var companion: CompanionSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var store: CollectionsStore
    @ObservedObject private var protection = ItemProtectionSession.shared
    let notes: NotesSession
    let reader: ReaderSession?
    let collectionID: UUID
    let planID: UUID
    var openNote: (UUID) -> Void
    @State private var scriptureEdit: PlanScriptureEditTarget?
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
    @State private var showingConversation = false
    @State private var showingCompletion = false
    @State private var showingMusic = false
    @State private var showingMusicLibrary = false

    private var playback: PlanPlaybackService { .init(store: store, activity: activity) }
    private var plan: StudyPlan? { store.plans.first { $0.id == planID && $0.trashedAt == nil } }
    private var permitted: Bool { plan.map { store.planAccessAllowed($0) } ?? false }
    private var cursor: PlanCursor? { plan?.cursor }
    private var item: PlanItem? { plan?.items.first { $0.id == cursor?.itemID } }

    private var assignmentReady: Bool {
        guard let item, cursor?.kind == .item else { return true }
        switch item.payload.kind {
        case .scripture:
            return reader?.document?.book == item.payload.book && reader?.document?.chapter == item.payload.chapter
                && reader?.document?.editionID == plan?.preferredEditionID && reader?.error == nil
        case .note:
            guard let id = item.payload.targetID, let note = notes.snapshot.notes.first(where: { $0.id == id }) else { return false }
            return note.isActiveInLibrary && !notes.isLocked(note) && !store.concealsNote(id)
        case .link: return item.payload.targetID.flatMap { readableLink($0) } != nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if let plan, permitted {
                    if let editing {
                        PlanEditorView(store: store, notes: notes, reader: reader, collectionID: collectionID,
                            model: editing, embedded: true, onFinish: {
                                self.editing = nil
                                if store.plans.first(where: { $0.id == planID })?.trashedAt != nil { dismiss() }
                            })
                            .accessibilityIdentifier("plans.inlineEditor")
                    } else if reading { readingContent(plan) } else { contents(plan) }
                } else {
                    ContentUnavailableView("Plan unavailable", systemImage: "lock", description: Text("Unlock Collections to view this Plan."))
                }
            }
            .appSurface()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let message { Text(message).font(.callout).foregroundStyle(.red).padding() }
                    if reading, permitted, let plan { readingControls(plan) }
                }.background(Color(theme.palette.paper))
            }
            .sheet(isPresented: $showingConversation) {
                CompanionView(session: companion, openNote: { id in
                    showingConversation = false; previewNote(id)
                })
                .safeAreaInset(edge: .top) {
                    HStack { Text("Plan conversation").font(.headline); Spacer(); Button("Back to Plan") { showingConversation = false } }
                        .padding().background(Color(theme.palette.paper))
                }
            }
            .sheet(isPresented: $showingCompletion, onDismiss: { Task { await closePlan() } }) {
                completionContent
            }
            .sheet(item: $scriptureEdit) { target in
                PlanScriptureAssignmentEditor(store: store, notes: notes, reader: reader, target: target)
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
                    NoteEditorView(session: notes, reader: reader, collections: store, includesScripturePane: false)
                        .toolbar(.visible, for: .navigationBar)
                        .navigationBarBackButtonHidden()
                        .toolbar { ToolbarItem(placement: .cancellationAction) {
                            Button("Back to Plan") { closeNotePreview() }.accessibilityIdentifier("plans.note.back")
                        } }
                        .onDisappear { notes.flushSurface?(); Task { await notes.save() } }
                } else { ContentUnavailableView("Note unavailable", systemImage: "lock") }
            }
            .onAppear { notes.planPresentationActive = true; music.load() }
            .task { await activity.load(); await reader?.start() }
            .onChange(of: activity.draft?.id) { _, _ in
                guard reading, !transitioning else { return }
                Task { await reconcileActivityEnd() }
            }
            .onChange(of: permitted) { _, allowed in
                if !allowed {
                    notes.flushSurface?(); notes.selectedNoteID = nil; notes.active = false
                    Task { _ = await playback.pause(planID) }
                    showingCompletion = false; showingConversation = false
                    reading = false; editing = nil; scriptureEdit = nil; linkID = nil; reflection = nil; previewNoteID = nil; showingMusic = false
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { notes.flushSurface?(); Task { await notes.save(); _ = await playback.pause(planID) }; reading = false; linkID = nil; showingMusic = false; showingConversation = false }
            }
        }
        .interactiveDismissDisabled()
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button { Task { await closePlan() } } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .buttonStyle(CollectionSecondaryButtonStyle()).accessibilityLabel("Exit Plan").accessibilityIdentifier("plans.exit")
            VStack(alignment: .leading, spacing: 3) {
                Text("READ · REFLECT · REMEMBER").font(.caption2).tracking(2).foregroundStyle(Color(theme.palette.secondary))
                Text(permitted ? plan?.title ?? "Plan" : "Plan").font(.system(.title2, design: .serif).weight(.semibold)).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let editing, permitted {
                Text(editing.saveStatus).font(.caption).foregroundStyle(Color(theme.palette.secondary))
                    .accessibilityIdentifier("plans.headerSaveStatus")
                Button("Done", systemImage: "checkmark") { Task { await finishEditing() } }
                    .buttonStyle(CollectionSecondaryButtonStyle()).disabled(saving || editing.saving)
                    .accessibilityIdentifier("plans.finishEditing")
            } else if permitted, !reading, let plan {
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
                                assignmentRow(item)
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
    private func assignmentRow(_ item: PlanItem) -> some View {
        Button {
            switch item.payload.kind {
            case .note: if let id = item.payload.targetID { previewNote(id) }
            case .link: linkID = item.payload.targetID
            case .scripture: scriptureEdit = .resolve(itemID: item.id, store: store)
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
                Image(systemName: item.payload.kind == .scripture ? "pencil" : "chevron.right")
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
                if item?.payload.kind == .scripture { Text(reader?.edition?.name ?? "").font(.caption).foregroundStyle(Color(theme.palette.secondary)) }
            }.padding(.top, 20).padding(.horizontal)
            if loading { ProgressView("Loading assignment…").frame(maxHeight: .infinity) }
            else if cursor?.kind == .sectionSummary {
                ContentUnavailableView("Section complete", systemImage: "checkmark.circle", description: Text("Finish this day to save its activity and exit."))
            } else if cursor?.kind == .planSummary {
                ContentUnavailableView("Plan complete", systemImage: "checkmark.seal", description: Text("Your progress is saved."))
            } else if let item {
                switch item.payload.kind {
                case .scripture:
                    if let reader, let document = reader.document,
                       document.book == item.payload.book, document.chapter == item.payload.chapter,
                       document.editionID == plan.preferredEditionID, reader.error == nil {
                        ReaderTextSurface(document: document, preferences: reader.preferences,
                            targetVerse: reader.targetVerse, navigationID: reader.navigationID,
                            restorationLocation: nil, onVerse: { _ in }, onVisibleLocation: { _, _, _ in },
                            onChapterSwipe: { _ in }, authorizeQuote: reader.authorizeQuote,
                            planFocusVerses: item.payload.selection == .verseRange ? reader.emphasisVerses : nil,
                            emphasisVerses: reader.emphasisVerses)
                            .frame(maxWidth: 960).frame(maxWidth: .infinity)
                    } else {
                        ContentUnavailableView("Scripture unavailable", systemImage: "book.closed", description: Text(reader?.error ?? "Download this Plan’s translation before reading."))
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
            Button("New conversation", systemImage: "bubble.left.and.bubble.right") {
                Task {
                    await companion.load()
                    if companion.createConversation() != nil { showingConversation = true }
                    else {
                        message = companion.notice
                        // The mounted Companion tab observes this shared notice. Keep
                        // a Plan creation failure local so its alert cannot replace
                        // the fullscreen Plan presentation.
                        companion.clearNotice()
                    }
                }
            }.accessibilityIdentifier("plans.newConversation")
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
    private func readableLink(_ id: UUID) -> SavedLink? {
        guard !store.collectionIDs(containing: id).contains(where: store.isLocked) else { return nil }
        return store.link(id: id)
    }
    private func previewNote(_ id: UUID) {
        guard permitted, readableNote(id) != nil else { return }
        notes.open(id); notes.active = true; previewNoteID = id
    }
    private func closeNotePreview() {
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
        if let editing, permitted {
            guard await editing.persist(store: store, collectionID: collectionID) else { return }
            self.editing = nil
        }
        notes.flushSurface?(); await notes.save()
        guard !notes.dirty else { message = "The note could not be saved. Retry before exiting."; return }
        guard await playback.pause(planID) else { message = activity.errorMessage; return }
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
        if let noteID = notes.selectedNoteID, item?.payload.kind == .note {
            let result = await notes.commitPlanEdits(noteID: noteID, operationID: UUID())
            guard case .committed = result else { message = "Save the note before finishing this day."; return }
        }
        do {
            if try await playback.reconcileFinishedActivity(planID) {
                notes.flushSurface?(); await notes.save()
                reading = false; showingConversation = false; showingCompletion = true
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
        if let noteID = notes.selectedNoteID, item?.payload.kind == .note {
            let result = await notes.commitPlanEdits(noteID: noteID, operationID: UUID())
            guard case .committed = result else { message = "Save the note before continuing."; return }
        }
        do {
            let completed = try await playback.advance(plan.id)
            message = nil
            if completed { reading = false; showingCompletion = true }
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
        if let noteID = notes.selectedNoteID, item?.payload.kind == .note {
            let result = await notes.commitPlanEdits(noteID: noteID, operationID: UUID())
            guard case .committed = result else { message = "Save the note before continuing."; return }
        }
        guard let target = previousCursor(plan) else { return }
        if await commit(plan, cursor: target) { await loadAssignment() }
    }
    private func loadAssignment() async {
        guard permitted, reading, cursor?.kind == .item, let item, let plan else { return }
        loading = true; defer { loading = false }
        if item.payload.kind == .note {
            if let id = item.payload.targetID, readableNote(id) != nil { notes.open(id); notes.active = true }
            return
        }
        notes.flushSurface?(); await notes.save(); notes.active = false
        guard item.payload.kind == .scripture, let reader else { return }
        await reader.start()
        guard permitted, reading, !Task.isCancelled else { return }
        if reader.edition?.id != plan.preferredEditionID { await reader.selectEdition(plan.preferredEditionID) }
        guard reader.edition?.id == plan.preferredEditionID, permitted, reading, !Task.isCancelled else { return }
        let verses = item.payload.selection == .verseRange ? Array((item.payload.startVerse ?? 1)...(item.payload.endVerse ?? 1)) : []
        await reader.navigate(book: item.payload.book ?? "", chapter: item.payload.chapter ?? 1,
                              verse: item.payload.startVerse ?? 1, emphasis: verses)
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
