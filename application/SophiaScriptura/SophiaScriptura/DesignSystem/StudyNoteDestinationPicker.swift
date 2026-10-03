import SwiftUI

enum StudyNoteSaveContent: Equatable {
    case scriptureQuote(NoteQuote)
    case companionResponse(text: String, anchor: CompanionPassageAnchor?)
}

struct StudyNoteDestinationPicker: View {
    let content: StudyNoteSaveContent
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
                    Button { create(.page) } label: { Label("New Page", systemImage: "doc.text") }
                        .accessibilityIdentifier("study.saveNote.newPage")
                    Button { create(.canvas) } label: { Label("New Canvas", systemImage: "rectangle.dashed") }
                        .accessibilityIdentifier("study.saveNote.newCanvas")
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
                                    Text(note.kind == .page ? "Page" : "Canvas")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
        notes.open(note.id)
        notes.append(saveContent: content)
        dismiss()
        openNote(note.id)
    }
}

struct StudyNoteKindPicker: View {
    let notes: NotesSession
    let onCancel: () -> Void
    let onCreated: (UUID) -> Void

    var body: some View {
        StudyCenteredActionOverlay(
            title: "New note",
            actions: [
                .init(id: "notes.new.page", title: "Page", systemImage: "doc.text") {
                    guard let id = notes.create(kind: .page) else { return }
                    onCreated(id)
                },
                .init(id: "notes.new.canvas", title: "Canvas", systemImage: "square.on.square") {
                    guard let id = notes.create(kind: .canvas) else { return }
                    onCreated(id)
                },
            ],
            onCancel: onCancel
        )
    }
}

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
