import SwiftUI

enum StudyNoteSaveContent: Equatable {
    case scriptureQuote(NoteQuote)
    case companionResponse(text: String, anchor: CompanionPassageAnchor?)
}

struct StudyNoteDestinationPicker: View {
    @ObservedObject private var protection = ItemProtectionSession.shared
    let content: StudyNoteSaveContent
    let notes: NotesSession
    let openNote: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    private var availableNotes: [NoteDocument] {
        notes.snapshot.notes.filter(\.isActiveInLibrary).sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("New note") {
                    Button { create(.page) } label: { Label("New Page", systemImage: "doc.text") }
                        .accessibilityIdentifier("study.saveNote.newPage")
                    Button { create(.canvas) } label: { Label("New Canvas", systemImage: "rectangle.dashed") }
                        .accessibilityIdentifier("study.saveNote.newCanvas")
                    Button { create(.prayer) } label: { Label("New Prayer", systemImage: "hands.and.sparkles") }
                        .accessibilityIdentifier("study.saveNote.newPrayer")
                    Button { create(.journal) } label: { Label("New Journal", systemImage: "book.pages") }
                        .accessibilityIdentifier("study.saveNote.newJournal")
                }
                Section("Existing note") {
                    if availableNotes.isEmpty {
                        Text("Create a note first, then you can add content to it.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableNotes) { note in
                            Button { add(to: note) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(note.title)
                                    Text(notes.isLocked(note) ? "Locked · Unlock Notes before adding content" : note.kind.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(notes.isLocked(note))
                            .accessibilityIdentifier("study.saveNote.existing.\(note.id.uuidString)")
                        }
                    }
                }
            }
            .navigationTitle("Save to note")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
    }

    private func create(_ kind: NoteKind) {
        guard let id = notes.create(kind: kind, saveContent: content) else { return }
        dismiss()
        openNote(id)
    }

    private func add(to note: NoteDocument) {
        guard !notes.isLocked(note) else { return }
        notes.open(note.id)
        guard notes.selectedNoteID == note.id, notes.note != nil else { return }
        notes.append(saveContent: content)
        dismiss()
        openNote(note.id)
    }
}

/// Creates a note; presentation matches `CollectionEditorSheet` (full sheet, form, Cancel / Create).
struct NoteCreatorSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let notes: NotesSession
    var onCreated: (UUID) -> Void = { _ in }

    @State private var kind: NoteKind = .page
    @State private var color: CollectionAccent = .preset
    @State private var title = ""
    @FocusState private var titleFocused: Bool

    private var previewTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return "Untitled \(kind.displayName)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: NoteKindSymbols.glyph(kind))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(theme.palette.paper))
                            .frame(width: 52, height: 52)
                            .background(color.resolvedColor(in: theme), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(previewTitle)
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(Color(theme.palette.ink))
                            Text(kind.displayName)
                                .font(.caption)
                                .foregroundStyle(Color(theme.palette.secondary))
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(Color(theme.palette.soft))

                Section("Title") {
                    TextField("Note title", text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("notes.new.title")
                }
                .listRowBackground(Color(theme.palette.soft))

                Section("Type") {
                    kindButton(.page, title: "Page", systemImage: "doc.text", id: "notes.new.page")
                    kindButton(.canvas, title: "Canvas", systemImage: "square.on.square", id: "notes.new.canvas")
                    kindButton(.prayer, title: "Prayer", systemImage: "hands.and.sparkles", id: "notes.new.prayer")
                    kindButton(.journal, title: "Journal", systemImage: "book.pages", id: "notes.new.journal")
                }
                .listRowBackground(Color(theme.palette.soft))

                Section {
                    NoteColorGrid(selection: $color)
                } header: {
                    Text("Color")
                } footer: {
                    Text("Colors the note in the library. The editor background follows your appearance preset and light or dark theme.")
                }
                .listRowBackground(Color(theme.palette.soft))
            }
            .appSurface()
            .navigationTitle("New note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("notes.new.create")
                }
            }
        }
        .accessibilityIdentifier("notes.new.sheet")
    }

    @ViewBuilder
    private func kindButton(_ value: NoteKind, title: String, systemImage: String, id: String) -> some View {
        Button {
            kind = value
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if kind == value {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color(theme.palette.ink))
                }
            }
        }
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(kind == value ? .isSelected : [])
    }

    private func create() {
        guard let id = notes.create(kind: kind, color: color, title: title) else { return }
        onCreated(id)
        dismiss()
    }
}

/// Edits library metadata for an existing note; matches `CollectionEditorSheet` presentation.
struct NoteEditorSheet: View {
    @ObservedObject private var protection = ItemProtectionSession.shared
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let noteID: UUID
    @Bindable var session: NotesSession

    @State private var title = ""
    @State private var tags = ""
    @State private var paper = NoteDocument.Paper.plain
    @State private var color: CollectionAccent = .preset
    @FocusState private var titleFocused: Bool

    private var note: NoteDocument? { session.snapshot.notes.first { $0.id == noteID && !session.isLocked($0) } }
    private var kind: NoteKind { note?.kind ?? .page }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: NoteKindSymbols.glyph(kind))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(theme.palette.paper))
                            .frame(width: 52, height: 52)
                            .background(color.resolvedColor(in: theme), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(trimmedTitle.isEmpty ? defaultPreviewTitle : trimmedTitle)
                                .font(.system(.headline, design: .serif))
                                .foregroundStyle(trimmedTitle.isEmpty ? Color(theme.palette.secondary) : Color(theme.palette.ink))
                            Text(kind.displayName)
                                .font(.caption)
                                .foregroundStyle(Color(theme.palette.secondary))
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(Color(theme.palette.soft))

                Section("Details") {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .accessibilityIdentifier("notes.edit.title")
                    TextField("Tags, separated by commas", text: $tags)
                    Picker("Paper", selection: $paper) {
                        ForEach(NoteDocument.Paper.allCases, id: \.self) { style in
                            Text(style.rawValue.capitalized).tag(style)
                        }
                    }
                }
                .listRowBackground(Color(theme.palette.soft))

                Section {
                    NoteColorGrid(selection: $color)
                } header: {
                    Text("Color")
                } footer: {
                    Text("Colors the note in the library. The editor background follows your appearance preset and light or dark theme.")
                }
                .listRowBackground(Color(theme.palette.soft))
            }
            .appSurface()
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("notes.edit.save")
                }
            }
        }
        .accessibilityIdentifier("notes.edit.sheet")
        .overlay { if note == nil { Color(uiColor: .systemBackground).ignoresSafeArea().overlay { ContentUnavailableView("Note unavailable or locked", systemImage: "lock.fill") } } }
        .onAppear(perform: loadFromStore)
        .onChange(of: protection.unlocked) { _, _ in if note == nil { dismiss() } }
    }

    private var defaultPreviewTitle: String {
        switch kind {
        case .prayer: "Untitled Prayer"
        case .journal: "Untitled Journal"
        default: "Untitled Note"
        }
    }

    private func loadFromStore() {
        guard let note else { return }
        title = note.title
        tags = note.tags.joined(separator: ", ")
        paper = note.paper
        color = note.color
        titleFocused = true
    }

    private func save() {
        session.updateNote(id: noteID, title: title, tags: tags, paper: paper, color: color)
        Task { await session.save() }
        dismiss()
    }
}

enum NoteKindSymbols {
    static func glyph(_ kind: NoteKind) -> String {
        switch kind {
        case .page: "doc.text.fill"
        case .canvas: "square.on.square.dashed"
        case .prayer: "hands.and.sparkles.fill"
        case .journal: "book.pages.fill"
        }
    }
}

/// Backward-compatible name for call sites migrating from the centered overlay picker.
typealias StudyNoteKindPicker = NoteCreatorSheet

struct TransientBannerNotice: View {
    let message: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(theme.palette.paper))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(theme.palette.ink).opacity(0.88), in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .accessibilityIdentifier("transient.notice")
    }
}
