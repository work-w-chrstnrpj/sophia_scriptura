import SwiftUI

struct NotePrayerEditorView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: NotesSession
    var reader: ReaderSession
    var addToCollection: () -> Void = {}
    @State private var rename = false
    @State private var title = ""
    @State private var newUpdate = ""
    @FocusState private var updateInputFocused: Bool
    @State private var editingUpdate: PrayerUpdate?
    @State private var editingUpdateBody = ""
    @State private var confirmClear = false
    @State private var confirmDelete = false
    @State private var confirmDeleteUpdate: PrayerUpdate?
    @State private var showWritingPage = false
    private var prayer: PrayerContent? { session.note?.prayerContent }

    /// 1.5 inches at 72 pt per inch (matches typographic inch margins).
    private static let horizontalMargin: CGFloat = 108

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    mainPrayerPost
                    updatesSection
                }
                .padding(.horizontal, Self.horizontalMargin)
                .padding(.vertical, 16)
                .padding(.bottom, 32)
            }
        }
        .appSurface()
        .navigationTitle(session.note?.title ?? "Prayer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { titleButton }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Undo", systemImage: "arrow.uturn.backward") { session.undo() }.disabled(!session.canUndo)
                Button("Redo", systemImage: "arrow.uturn.forward") { session.redo() }.disabled(!session.canRedo)
                Menu {
                    Button {
                        session.archiveCurrentNote()
                        dismiss()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .accessibilityIdentifier("notes.prayer.archive")
                    Button("Add to Collection", systemImage: "folder.badge.plus", action: addToCollection)
                        .accessibilityIdentifier("notes.prayer.addToCollection")
                    if session.note?.protectionID == nil {
                        Button("Protect Note", systemImage: "lock") { Task { if let id = session.note?.id { await session.setProtected(id, enabled: true) } } }
                            .accessibilityIdentifier("notes.prayer.protect")
                    } else {
                        Button("Lock Note", systemImage: "lock") { session.protection.lock([.notes]) }
                            .accessibilityIdentifier("notes.prayer.lock")
                        Button("Remove Note Protection", systemImage: "lock.slash") { Task { if let id = session.note?.id { await session.setProtected(id, enabled: false) } } }
                            .accessibilityIdentifier("notes.prayer.removeProtection")
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("notes.prayer.delete")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More actions")
                .accessibilityIdentifier("notes.prayer.more")
            }
        }
        .alert("Rename prayer", isPresented: $rename) {
            TextField("Title", text: $title)
            Button("Save") {
                if let note = session.note {
                    session.metadata(title: title, tags: note.tags.joined(separator: ","), paper: note.paper)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Clear prayer?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) { session.clearPrayerContent() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the prayer text and handwriting. Updates are kept.")
        }
        .alert("Move prayer to Trash?", isPresented: $confirmDelete) {
            Button("Move to Trash", role: .destructive) {
                session.moveCurrentNoteToTrash()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Trash keeps the prayer for \(TrashRetention.dayCount) days. Restore or delete permanently from Settings → Trash.")
        }
        .alert("Delete this update?", isPresented: Binding(
            get: { confirmDeleteUpdate != nil },
            set: { if !$0 { confirmDeleteUpdate = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let update = confirmDeleteUpdate { session.deletePrayerUpdate(id: update.id) }
                confirmDeleteUpdate = nil
            }
            Button("Cancel", role: .cancel) { confirmDeleteUpdate = nil }
        }
        .sheet(item: $editingUpdate) { update in
            NavigationStack {
                Form {
                    TextEditor(text: $editingUpdateBody)
                        .frame(minHeight: 160)
                }
                .navigationTitle("Edit update")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingUpdate = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            session.updatePrayerUpdate(id: update.id, body: editingUpdateBody)
                            editingUpdate = nil
                        }
                    }
                }
            }
            .onAppear { editingUpdateBody = update.body }
        }
        .onAppear {
            session.toolsVisible = true
            session.toolsRequest = UUID()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if session.toolsVisible {
                Color.clear.frame(height: ShellChromeLayout.shellFABBottomPaddingWhenTabsVisible)
            }
        }
        .fullScreenCover(isPresented: $showWritingPage, onDismiss: {
            session.flushSurface?()
            session.surfaceGeneration = UUID()
            Task { await session.save() }
        }) {
            PrayerWritingPage(session: session)
        }
        .onDisappear { session.flushSurface?(); Task { await session.save() } }
    }

    private var surfaceToken: String {
        "\(session.renderRevision)|\(session.surfaceGeneration)|\(session.active)|\(session.toolsVisible)|\(session.toolsRequest)|\(showWritingPage)|\(Int(previewWritingHeight))"
    }

    private static let previewBoardMargin: CGFloat = 16
    private static let previewMinHeight: CGFloat = 360
    private static let previewMaxHeight: CGFloat = 960
    private static let previewExtraVerticalPadding: CGFloat = 96

    private var previewBoardWidth: CGFloat {
        max(280, UIScreen.main.bounds.width - Self.horizontalMargin * 2 - 36)
    }

    private var previewWritingHeight: CGFloat {
        guard let page = session.note?.page else { return Self.previewMinHeight }
        let widthScale = max(0.25, (previewBoardWidth - Self.previewBoardMargin * 2) / NotePage.columnWidth)
        let content = NotePageTypography.prayerBoardContentHeight(for: page, includesInkPadding: true)
        let natural = content * widthScale + Self.previewBoardMargin * 2 + Self.previewExtraVerticalPadding
        return min(Self.previewMaxHeight, max(Self.previewMinHeight, natural))
    }

    private var titleButton: some View {
        Button { title = session.note?.title ?? ""; rename = true } label: {
            HStack(spacing: 5) {
                Text(session.note?.title ?? "Prayer").font(.headline).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("notes.prayer.rename")
    }

    private var prayerPencilToggle: some View {
        Button(session.toolsVisible ? "Hide Pencil tools" : "Pencil tools", systemImage: session.toolsVisible ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle") {
            session.toolsVisible.toggle()
            session.toolsRequest = UUID()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.system(size: 20))
        .accessibilityIdentifier("notes.prayer.tools")
    }

    private var mainPrayerPost: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prayer")
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(theme.palette.accent))
                        .accessibilityIdentifier("notes.prayer.badge")

                    if let note = session.note {
                        Text(note.title)
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(theme.palette.ink))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created \(note.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            Text("Last modified \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        }
                        .font(.caption)
                        .foregroundStyle(Color(theme.palette.secondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("Write or annotate")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(theme.palette.secondary))
                Spacer(minLength: 8)
                HStack(spacing: 12) {
                    prayerPencilToggle
                    Button {
                        session.flushSurface?()
                        showWritingPage = true
                    } label: {
                        Label("Maximize", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .accessibilityIdentifier("notes.prayer.maximize")
                }
            }

            if !showWritingPage {
                NotePageSurface(
                    session: session,
                    active: session.active,
                    stateToken: surfaceToken,
                    prayerPreviewFitsContent: true,
                    prayerPreviewHorizontalMargin: Self.previewBoardMargin,
                    openCitation: { _ in }
                )
                    .frame(height: previewWritingHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                prayerWritingPreviewPlaceholder
            }

            prayerActionRow
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(theme.palette.rule), lineWidth: 1))
    }

    private var prayerWritingPreviewPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "pencil.and.scribble")
                .font(.title2)
                .foregroundStyle(Color(theme.palette.secondary))
            Text("Writing open in full screen")
                .font(.subheadline)
                .foregroundStyle(Color(theme.palette.secondary))
            Button("Return to writing page") { showWritingPage = true }
                .buttonStyle(CollectionSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .frame(height: previewWritingHeight)
        .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(theme.palette.rule), lineWidth: 1))
    }

    private var prayerActionRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        _ = session.recordPrayerTap()
                    } label: {
                        Label("Pray \(prayer?.prayerCount ?? 0)", systemImage: "hands.and.sparkles.fill")
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .disabled(!session.canRecordPrayerTapToday())
                    .accessibilityIdentifier("notes.prayer.react")

                    Menu {
                        Picker("Prayer status", selection: Binding(
                            get: { prayer?.status ?? .waiting },
                            set: { session.setPrayerStatus($0) }
                        )) {
                            ForEach(PrayerStatus.allCases, id: \.self) { status in
                                Text(status.label).tag(status)
                            }
                        }
                    } label: {
                        Label(prayer?.status.label ?? PrayerStatus.waiting.label, systemImage: "flag")
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .accessibilityIdentifier("notes.prayer.status")

                    Button { confirmClear = true } label: {
                        Label("Clear", systemImage: "eraser")
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .accessibilityIdentifier("notes.prayer.clear")
                }
            }

            if !session.canRecordPrayerTapToday() {
                Text("You prayed today. Come back tomorrow to add another count.")
                    .font(.caption)
                    .foregroundStyle(Color(theme.palette.secondary))
            }
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Updates")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color(theme.palette.ink))

            HStack(alignment: .top, spacing: 10) {
                TextField("Share an update…", text: $newUpdate, axis: .vertical)
                    .accessibilityIdentifier("notes.prayer.update.input")
                    .focused($updateInputFocused)
                    .lineLimit(1...4)
                    .padding(12)
                    .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(theme.palette.rule), lineWidth: 1))
                Button("Share") {
                    session.addPrayerUpdate(newUpdate)
                    newUpdate = ""
                    updateInputFocused = false
                }
                .buttonStyle(CollectionProminentButtonStyle())
                .disabled(newUpdate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("notes.prayer.update.share")
            }

            if prayer?.updates.isEmpty != false {
                Text("No updates yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color(theme.palette.secondary))
            } else {
                VStack(spacing: 12) {
                    ForEach(prayer?.updates ?? []) { update in
                        PrayerUpdateRow(update: update, theme: theme)
                            .studySwipeReveal(identifier: "notes.prayer.update.swipe.\(update.id)") {
                                Button("Edit", systemImage: "pencil") {
                                    editingUpdate = update; editingUpdateBody = update.body
                                }
                                .accessibilityIdentifier("notes.prayer.update.swipe.edit")
                                Button("Delete", systemImage: "trash", role: .destructive) { confirmDeleteUpdate = update }
                                    .accessibilityIdentifier("notes.prayer.update.swipe.delete")
                            }
                            .contextMenu {
                                Button {
                                    editingUpdate = update
                                    editingUpdateBody = update.body
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    confirmDeleteUpdate = update
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct PrayerWritingPage: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: NotesSession

    private var surfaceToken: String {
        "\(session.renderRevision)|\(session.surfaceGeneration)|\(session.active)|\(session.toolsVisible)|\(session.toolsRequest)|writing-page"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    Button(session.toolsVisible ? "Hide Pencil tools" : "Pencil tools", systemImage: session.toolsVisible ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle") {
                        session.toolsVisible.toggle()
                        session.toolsRequest = UUID()
                    }
                    .accessibilityIdentifier("notes.prayer.writing.tools")
                    Spacer(minLength: 0)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.system(size: 20))
                .frame(height: 44)
                .padding(.horizontal, 24)
                .background(Color(theme.palette.paper))

                NotePageSurface(session: session, active: session.active, stateToken: surfaceToken, openCitation: { _ in })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .appSurface()
            .navigationTitle("Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        session.flushSurface?()
                        dismiss()
                    } label: {
                        Label("Minimize", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                    .accessibilityIdentifier("notes.prayer.minimize")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Undo", systemImage: "arrow.uturn.backward") { session.undo() }.disabled(!session.canUndo)
                    Button("Redo", systemImage: "arrow.uturn.forward") { session.redo() }.disabled(!session.canRedo)
                }
            }
        }
        .onAppear {
            session.toolsVisible = true
            session.toolsRequest = UUID()
            session.surfaceGeneration = UUID()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if session.toolsVisible {
                Color.clear.frame(height: ShellChromeLayout.shellFABBottomPaddingWhenTabsVisible)
            }
        }
    }
}

private struct PrayerUpdateRow: View {
    let update: PrayerUpdate
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(update.body)
                .font(.body)
                .foregroundStyle(Color(theme.palette.ink))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(update.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(Color(theme.palette.secondary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(theme.palette.rule), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("notes.prayer.update.\(update.id.uuidString)")
    }
}

/// Presentation-only card mark; never part of note text or ink.
struct NoteCardStatusStamp: View {
    enum Mark { case answered, redirected, published }
    let mark: Mark
    let noteID: UUID
    var isActive = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var impression = 0
    // Stable per note across redraws, status changes and launches; never use Swift's randomized hash.
    private var tilt: Double {
        let seed = noteID.uuidString.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        return Double(1 + seed % 15)
    }
    private var asset: String {
        switch mark {
        case .answered: "PrayerAnsweredStamp"
        case .redirected: "PrayerRedirectedStamp"
        case .published: "PagePublishedStamp"
        }
    }
    private var tint: Color { mark == .redirected ? .yellow : .green }
    var body: some View {
        Image(asset)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 210, height: 55)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .foregroundStyle(impression < 2 ? Color.black : tint)
            .background(tint.opacity(impression < 2 ? 0 : 0.04))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(impression < 2 ? Color.black : tint, lineWidth: 3))
            .opacity(impression == 0 ? 0.08 : (impression == 1 ? 0.5 : 1))
            .blur(radius: impression == 0 ? 7 : (impression == 1 ? 3 : 0))
            .scaleEffect(impression == 0 ? 1.12 : (impression == 1 ? 1.04 : 1))
            .rotationEffect(.degrees(tilt))
            .allowsHitTesting(false)
            .accessibilityLabel(mark == .published ? "Page published" : (mark == .answered ? "Prayer answered" : "Prayer redirected"))
            .accessibilityIdentifier(mark == .published ? "notes.page.stamp" : "notes.prayer.stamp")
            .task(id: isActive) {
                guard isActive else { impression = 0; return }
                guard !reduceMotion else { impression = 2; return }
                impression = 0
                do {
                    try await Task.sleep(for: .milliseconds(160))
                    withAnimation(.easeIn(duration: 0.24)) { impression = 1 }
                    try await Task.sleep(for: .milliseconds(280))
                    withAnimation(.easeOut(duration: 0.16)) { impression = 2 }
                } catch { }
            }
    }
}
