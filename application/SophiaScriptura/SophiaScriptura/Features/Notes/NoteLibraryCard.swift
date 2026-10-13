import SwiftUI

/// Shared presentation for note cards in Notes and Collections; hosts own navigation/actions.
struct NoteLibraryCard: View {
    @Environment(\.appTheme) private var theme
    let note: NoteDocument
    var locked = false
    var isActive = true
    var open: () -> Void
    @State private var visible = false
    private let noteCardHeight: CGFloat = 176

    var body: some View {
        let accent = locked ? CollectionAccent.stone : note.color
        let tint = accent.resolvedColor(in: theme)
        VStack(alignment: .leading, spacing: 10) {
            Button { open() } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 12) {
                        noteGlyph(note, accent: accent, size: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(note.title)
                                    .font(.system(.headline, design: .serif).weight(.semibold))
                                    .foregroundStyle(Color(theme.palette.ink))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if note.protectionID != nil {
                                    Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel(locked ? "Locked note" : "Protected note, unlocked")
                                }
                            }
                            Text(note.kind.displayName)
                                .font(.footnote)
                                .foregroundStyle(Color(theme.palette.secondary))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 16)
                    noteDates(note, accent: accent)
                }
                .frame(maxWidth: .infinity, minHeight: noteCardHeight - 28, maxHeight: noteCardHeight - 28, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: noteCardHeight, maxHeight: noteCardHeight, alignment: .top)
        .background(Color(theme.palette.soft), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(tint)
                .frame(height: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .overlay(alignment: .center) {
            if !locked {
                cardPreview(note)
                    .padding(.horizontal, 14)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }

    @ViewBuilder
    private func cardPreview(_ note: NoteDocument) -> some View {
        if let status = note.prayerContent?.status, status != .waiting {
            NoteCardStatusStamp(mark: status == .answered ? .answered : .redirected, noteID: note.id, isActive: isActive && visible)
        } else if note.pageStatus == .closed {
            NoteCardStatusStamp(mark: .published, noteID: note.id, isActive: isActive && visible)
        } else if let journal = note.journalContent {
            HStack(spacing: 12) {
                journalCardState("Emotional State", value: journal.emotionalState?.label ?? "Not set",
                                 appearance: journal.emotionalState.map(JournalStateAppearance.emotional) ?? .init(mark: .symbol("heart"), tint: .secondary))
                journalCardState("Mental State", value: journal.mentalState?.label ?? "Not set",
                                 appearance: journal.mentalState.map(JournalStateAppearance.mental) ?? .init(mark: .symbol("brain"), tint: .secondary))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("notes.journal.preview")
        } else if note.kind == .page {
            Text(String((note.page?.body ?? "").replacingOccurrences(of: "\u{FFFC}", with: "").prefix(300)))
                .font(.footnote)
                .foregroundStyle(Color(theme.palette.secondary))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("notes.page.preview")
                .allowsHitTesting(false)
        }
    }

    private func journalCardState(_ title: String, value: String, appearance: JournalStateAppearance) -> some View {
        HStack(spacing: 5) {
            JournalMarkIcon(mark: appearance.mark, width: 20)
                .foregroundStyle(appearance.tint)
            Text(value)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .allowsHitTesting(false)
    }

    private func noteGlyph(_ note: NoteDocument, accent: CollectionAccent, size: CGFloat) -> some View {
        let tint = accent.resolvedColor(in: theme)
        return Image(systemName: locked ? "lock.fill" : noteKindSymbol(note.kind))
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }

    private func noteKindSymbol(_ kind: NoteKind) -> String {
        switch kind {
        case .page: "doc.text.fill"
        case .canvas: "square.on.square.dashed"
        case .prayer: "hands.and.sparkles.fill"
        case .journal: "book.pages.fill"
        }
    }

    private func noteDates(_ note: NoteDocument, accent: CollectionAccent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Created \(note.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .accessibilityIdentifier("notes.createdDate.\(note.id.uuidString)")
            Text("Last modified \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .accessibilityIdentifier("notes.modifiedDate.\(note.id.uuidString)")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(accent.resolvedColor(in: theme))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NoteCardsActiveKey: EnvironmentKey {
    static let defaultValue = true
}
extension EnvironmentValues {
    var noteCardsActive: Bool {
        get { self[NoteCardsActiveKey.self] }
        set { self[NoteCardsActiveKey.self] = newValue }
    }
}
