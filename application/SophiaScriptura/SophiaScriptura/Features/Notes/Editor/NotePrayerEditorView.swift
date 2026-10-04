import SwiftUI

struct NotePrayerEditorView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: NotesSession
    var reader: ReaderSession
    @State private var rename = false
    @State private var title = ""
    @State private var newUpdate = ""
    @State private var editingUpdate: PrayerUpdate?
    @State private var editingUpdateBody = ""
    @State private var confirmClear = false
    @State private var confirmArchive = false
    @State private var confirmDelete = false
    @State private var confirmDeleteUpdate: PrayerUpdate?
    @State private var showWritingPage = false
    private var prayer: PrayerContent? { session.note?.prayerContent }

    /// 1.5 inches at 72 pt per inch (matches typographic inch margins).
    private static let horizontalMargin: CGFloat = 108

    var body: some View {
        VStack(spacing: 0) {
            pencilToolbar
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
        .alert("Archive prayer?", isPresented: $confirmArchive) {
            Button("Archive") {
                session.archiveCurrentNote()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Moves this prayer to Archive. You can restore it later from Settings or Notes.")
        }
        .alert("Delete prayer permanently?", isPresented: $confirmDelete) {
            Button("Delete Permanently", role: .destructive) {
                session.permanentlyDeleteCurrentNote()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the prayer from your library and cannot be undone.")
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
        "\(session.renderRevision)|\(session.surfaceGeneration)|\(session.active)|\(session.toolsVisible)|\(session.toolsRequest)|\(showWritingPage)"
    }

    private var previewWritingHeight: CGFloat {
        guard let page = session.note?.page else { return 280 }
        let textBlock = NotePageTypography.height(of: page)
        return min(360, max(220, textBlock + 120))
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

    private var pencilToolbar: some View {
        HStack(spacing: 20) {
            Button(session.toolsVisible ? "Hide Pencil tools" : "Pencil tools", systemImage: session.toolsVisible ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle") {
                session.toolsVisible.toggle()
                session.toolsRequest = UUID()
            }
            .accessibilityIdentifier("notes.prayer.tools")
            Spacer(minLength: 0)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.system(size: 20))
        .frame(height: 44)
        .padding(.horizontal, Self.horizontalMargin)
        .background(Color(theme.palette.paper))
    }

    private var mainPrayerPost: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            HStack(spacing: 8) {
                Text("Write or annotate")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(theme.palette.secondary))
                Spacer(minLength: 8)
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

            if !showWritingPage {
                NotePageSurface(session: session, active: session.active, stateToken: surfaceToken, openCitation: { _ in })
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

                    Button { confirmArchive = true } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .accessibilityIdentifier("notes.prayer.archive")

                    Button { confirmDelete = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(CollectionSecondaryButtonStyle())
                    .accessibilityIdentifier("notes.prayer.delete")
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
                    .lineLimit(1...4)
                    .padding(12)
                    .background(Color(theme.palette.paper), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(theme.palette.rule), lineWidth: 1))
                Button("Share") {
                    session.addPrayerUpdate(newUpdate)
                    newUpdate = ""
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
                ForEach(prayer?.updates ?? []) { update in
                    PrayerUpdateRow(
                        update: update,
                        theme: theme,
                        onEdit: {
                            editingUpdate = update
                            editingUpdateBody = update.body
                        },
                        onDelete: { confirmDeleteUpdate = update }
                    )
                }
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
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
            VStack(spacing: 10) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(Color(theme.palette.paper), in: Circle())
                        .overlay(Circle().stroke(Color(theme.palette.rule), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit update")
                .accessibilityIdentifier("notes.prayer.update.edit")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .background(Color(theme.palette.paper), in: Circle())
                        .overlay(Circle().stroke(Color(theme.palette.rule), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete update")
                .accessibilityIdentifier("notes.prayer.update.delete")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(theme.palette.rule), lineWidth: 1))
    }
}
