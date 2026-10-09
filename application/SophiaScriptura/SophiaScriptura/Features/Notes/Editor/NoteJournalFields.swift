import SwiftUI

/// Optional emotional and mental state for a Journal note. Both may stay empty.
struct NoteJournalFields: View {
    @Environment(\.appTheme) private var theme
    @Bindable var session: NotesSession
    @State private var sheet: JournalFieldSheet?

    private var journal: JournalContent? { session.note?.journalContent }

    var body: some View {
        HStack(spacing: 20) {
            fieldButton(
                title: "Emotional state",
                value: journal?.emotionalState?.label,
                emptyTitle: "Emotion",
                systemImage: "face.smiling",
                identifier: "notes.journal.emotional",
                field: .emotional
            )
            fieldButton(
                title: "Mental state",
                value: journal?.mentalState?.label,
                emptyTitle: "Mind",
                systemImage: "brain",
                identifier: "notes.journal.mental",
                field: .mental
            )
        }
        .sheet(item: $sheet) { field in
            JournalFieldPicker(field: field, journal: journal, session: session)
        }
    }

    private func fieldButton(title: String, value: String?, emptyTitle: String, systemImage: String, identifier: String, field: JournalFieldSheet) -> some View {
        Button { sheet = field } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(value ?? emptyTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(theme.palette.ink))
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(value ?? "Not set")
    }
}

private enum JournalFieldSheet: String, Identifiable {
    case emotional, mental
    var id: String { rawValue }
}

private struct JournalFieldPicker: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let field: JournalFieldSheet
    let journal: JournalContent?
    var session: NotesSession

    var body: some View {
        NavigationStack {
            List {
                Button {
                    switch field {
                    case .emotional: session.setJournalEmotionalState(nil)
                    case .mental: session.setJournalMentalState(nil)
                    }
                    dismiss()
                } label: {
                    choiceRow(title: "Not set", detail: nil, selected: currentIsEmpty)
                }
                .accessibilityIdentifier(field == .emotional ? "notes.journal.emotional.none" : "notes.journal.mental.none")

                switch field {
                case .emotional:
                    ForEach(JournalEmotionalState.allCases.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }, id: \.self) { state in
                        Button {
                            session.setJournalEmotionalState(state)
                            dismiss()
                        } label: {
                            choiceRow(title: state.label, detail: nil, selected: journal?.emotionalState == state)
                        }
                        .accessibilityIdentifier("notes.journal.emotional.\(state.rawValue)")
                    }
                case .mental:
                    ForEach(JournalMentalState.allCases, id: \.self) { state in
                        Button {
                            session.setJournalMentalState(state)
                            dismiss()
                        } label: {
                            choiceRow(title: state.label, detail: state.meaning, selected: journal?.mentalState == state)
                        }
                        .accessibilityIdentifier("notes.journal.mental.\(state.rawValue)")
                    }
                }
            }
            .navigationTitle(field == .emotional ? "Emotional state" : "Mental state")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var currentIsEmpty: Bool {
        switch field {
        case .emotional: journal?.emotionalState == nil
        case .mental: journal?.mentalState == nil
        }
    }

    private func choiceRow(title: String, detail: String?, selected: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color(theme.palette.ink))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color(theme.palette.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color(theme.palette.accent))
            }
        }
    }
}
