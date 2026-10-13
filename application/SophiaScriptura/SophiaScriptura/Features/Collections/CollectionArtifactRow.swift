import SwiftUI

struct CollectionArtifactRow: View {
    enum Placement {
        case folder
        case unfiled
        case subfolder
    }

    @Environment(\.appTheme) private var theme
    @Environment(\.noteCardsActive) private var noteCardsActive
    let artifact: CollectionArtifact
    let accent: CollectionAccent
    let placement: Placement
    let open: () -> Void
    var move: () -> Void = {}
    var assign: () -> Void = {}
    var remove: () -> Void = {}
    var deletePassage: () -> Void = {}
    var notes: NotesSession? = nil
    var onJournalField: ((JournalFieldSheet) -> Void)? = nil
    var cards = false
    static let listHeight: CGFloat = 80
    static let cardHeight: CGFloat = 176

    private var isPassage: Bool { artifact.kind == .bookmark || artifact.kind == .gleaning }

    private var deleteTitle: String {
        switch artifact.kind {
        case .gleaning: return "Delete Gleaning"
        case .link: return "Delete Link"
        default: return "Delete Bookmark"
        }
    }

    private var caption: String {
        let base: String
        switch artifact.kind {
        case .bookmark: base = "Bookmark"
        case .gleaning: base = artifact.insight.isEmpty ? "Gleaning" : "Gleaning"
        default: base = artifact.subtitle
        }
        return placement == .subfolder ? "In a subfolder · \(base)" : base
    }

    private var gleaningPreview: String? {
        guard artifact.kind == .gleaning, !artifact.insight.isEmpty else { return nil }
        return StudyPreviewText.truncatedInsight(artifact.insight)
    }

    var body: some View {
        Group {
            if cards, artifact.kind == .note, let notes,
               let note = notes.snapshot.notes.first(where: { $0.id == artifact.id }) {
                NoteLibraryCard(note: note, locked: notes.isLocked(note), isActive: noteCardsActive, open: open)
            } else {
                standardRecord
            }
        }
        .accessibilityIdentifier("collections.open.\(artifact.title)")
        .contextMenu { actions }
    }

    private var standardRecord: some View {
        Button(action: open) {
            Group {
                if cards {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 12) {
                            CollectionItemGlyph(kind: artifact.kind, accent: accent, size: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(artifact.title)
                                    .font(.system(.headline, design: .serif).weight(.semibold))
                                    .foregroundStyle(Color(theme.palette.ink))
                                    .lineLimit(2)
                                Text(caption).font(.caption)
                                    .foregroundStyle(Color(theme.palette.secondary)).lineLimit(1)
                            }
                        }
                        if let gleaningPreview {
                            Text(gleaningPreview).font(.footnote)
                                .foregroundStyle(Color(theme.palette.secondary)).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Text(artifact.modifiedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(accent.resolvedColor(in: theme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
            HStack(alignment: .center, spacing: 14) {
                CollectionItemGlyph(kind: artifact.kind, accent: accent, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(artifact.title)
                        .font(isPassage ? .system(.body, design: .serif).weight(.semibold) : .body.weight(.semibold))
                        .foregroundStyle(Color(theme.palette.ink))
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    if let gleaningPreview {
                        Text(gleaningPreview)
                            .font(.subheadline)
                            .foregroundStyle(Color(theme.palette.ink))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(Color(theme.palette.secondary))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(theme.palette.secondary))
            }
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: cards ? Self.cardHeight : Self.listHeight)
            .clipped()
            .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(theme.palette.rule), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if placement != .subfolder && (isPassage || artifact.kind == .link) {
                Button(role: .destructive, action: deletePassage) {
                    Label(deleteTitle, systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            switch placement {
            case .unfiled:
                Button(action: assign) { Label("Add to Collection", systemImage: "folder.badge.plus") }
                    .tint(Color(theme.palette.accent))
            case .folder:
                Button(action: move) { Label("Move", systemImage: "folder") }
                    .tint(Color(theme.palette.accent))
                Button(action: assign) { Label("Add to…", systemImage: "folder.badge.plus") }
                    .tint(.orange)
                Button(action: remove) { Label("Remove", systemImage: "minus.circle") }
                    .tint(.gray)
            case .subfolder:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if artifact.kind == .note, let notes,
           let note = notes.snapshot.notes.first(where: { $0.id == artifact.id }),
           !notes.isLocked(note), notes.collections?.concealsNote(note.id) != true {
            NoteStatusContextMenu(note: note, session: notes, onJournalField: onJournalField)
        }
        switch placement {
        case .subfolder:
            Text("Open its subfolder to organize this item.")
        case .unfiled:
            Button("Add to Collection…", systemImage: "folder.badge.plus", action: assign)
        case .folder:
            Button("Move to…", systemImage: "folder", action: move)
            Button("Add to Another Collection…", systemImage: "folder.badge.plus", action: assign)
            Divider()
            Button("Remove from This Collection", systemImage: "minus.circle", action: remove)
        }
        if placement != .subfolder && (isPassage || artifact.kind == .link) {
            Divider()
            Button(deleteTitle, systemImage: "trash", role: .destructive, action: deletePassage)
        }
    }
}
