import SwiftUI

enum JournalFieldSheet: String, Identifiable {
    case emotional, mental
    var id: String { rawValue }
}

enum JournalMark: Equatable {
    case symbol(String)
    case emoji(String)
}

struct JournalStateAppearance: Equatable {
    var mark: JournalMark
    var tint: Color

    static func emotional(_ state: JournalEmotionalState) -> JournalStateAppearance {
        switch state {
        case .amazed: return .init(mark: .emoji("😲"), tint: Color(red: 0.55, green: 0.28, blue: 0.86))
        case .amused: return .init(mark: .emoji("😄"), tint: Color(red: 0.95, green: 0.55, blue: 0.10))
        case .angry: return .init(mark: .emoji("😠"), tint: Color(red: 0.86, green: 0.18, blue: 0.18))
        case .anxious: return .init(mark: .emoji("😰"), tint: Color(red: 0.90, green: 0.42, blue: 0.12))
        case .ashamed: return .init(mark: .emoji("🫣"), tint: Color(red: 0.78, green: 0.32, blue: 0.52))
        case .brave: return .init(mark: .emoji("🫡"), tint: Color(red: 0.36, green: 0.28, blue: 0.78))
        case .calm: return .init(mark: .emoji("😌"), tint: Color(red: 0.16, green: 0.58, blue: 0.58))
        case .content: return .init(mark: .emoji("🙂"), tint: Color(red: 0.22, green: 0.58, blue: 0.34))
        case .disappointed: return .init(mark: .emoji("😞"), tint: Color(red: 0.38, green: 0.46, blue: 0.62))
        case .discouraged: return .init(mark: .emoji("😔"), tint: Color(red: 0.42, green: 0.48, blue: 0.58))
        case .disgusted: return .init(mark: .emoji("🤢"), tint: Color(red: 0.42, green: 0.55, blue: 0.18))
        case .embarrassed: return .init(mark: .emoji("😳"), tint: Color(red: 0.86, green: 0.36, blue: 0.48))
        case .excited: return .init(mark: .emoji("🤩"), tint: Color(red: 0.92, green: 0.62, blue: 0.08))
        case .frustrated: return .init(mark: .emoji("😣"), tint: Color(red: 0.78, green: 0.28, blue: 0.16))
        case .grateful: return .init(mark: .emoji("🥰"), tint: Color(red: 0.84, green: 0.48, blue: 0.18))
        case .guilty: return .init(mark: .emoji("😖"), tint: Color(red: 0.55, green: 0.36, blue: 0.22))
        case .happy: return .init(mark: .emoji("😊"), tint: Color(red: 0.90, green: 0.68, blue: 0.08))
        case .hopeless: return .init(mark: .emoji("😩"), tint: Color(red: 0.36, green: 0.40, blue: 0.52))
        case .irritated: return .init(mark: .emoji("😑"), tint: Color(red: 0.78, green: 0.40, blue: 0.12))
        case .jealous: return .init(mark: .emoji("😒"), tint: Color(red: 0.28, green: 0.52, blue: 0.28))
        case .joyful: return .init(mark: .emoji("😁"), tint: Color(red: 0.95, green: 0.72, blue: 0.05))
        case .lonely: return .init(mark: .emoji("🥺"), tint: Color(red: 0.28, green: 0.45, blue: 0.72))
        case .passionate: return .init(mark: .emoji("😍"), tint: Color(red: 0.78, green: 0.16, blue: 0.32))
        case .peaceful: return .init(mark: .emoji("😇"), tint: Color(red: 0.20, green: 0.62, blue: 0.50))
        case .proud: return .init(mark: .emoji("😏"), tint: Color(red: 0.48, green: 0.28, blue: 0.72))
        case .relieved: return .init(mark: .emoji("😅"), tint: Color(red: 0.12, green: 0.58, blue: 0.68))
        case .sad: return .init(mark: .emoji("😢"), tint: Color(red: 0.22, green: 0.42, blue: 0.78))
        case .scared: return .init(mark: .emoji("😨"), tint: Color(red: 0.40, green: 0.28, blue: 0.70))
        case .stressed: return .init(mark: .emoji("😫"), tint: Color(red: 0.74, green: 0.22, blue: 0.22))
        case .surprised: return .init(mark: .emoji("😮"), tint: Color(red: 0.86, green: 0.55, blue: 0.12))
        case .worried: return .init(mark: .emoji("😟"), tint: Color(red: 0.36, green: 0.38, blue: 0.68))
        case .annoyed: return .init(mark: .emoji("😤"), tint: Color(red: 0.80, green: 0.34, blue: 0.10))
        case .confident: return .init(mark: .emoji("😎"), tint: Color(red: 0.12, green: 0.48, blue: 0.36))
        case .drained: return .init(mark: .emoji("😮‍💨"), tint: Color(red: 0.45, green: 0.48, blue: 0.52))
        case .hopeful: return .init(mark: .emoji("🥹"), tint: Color(red: 0.20, green: 0.55, blue: 0.78))
        case .indifferent: return .init(mark: .emoji("😐"), tint: Color(red: 0.45, green: 0.45, blue: 0.48))
        case .overwhelmed: return .init(mark: .emoji("😵‍💫"), tint: Color(red: 0.62, green: 0.22, blue: 0.62))
        case .satisfied: return .init(mark: .emoji("😋"), tint: Color(red: 0.18, green: 0.55, blue: 0.28))
        case .neutral: return .init(mark: .emoji("😶"), tint: Color(red: 0.40, green: 0.44, blue: 0.50))
        }
    }

    static func mental(_ state: JournalMentalState) -> JournalStateAppearance {
        switch state {
        case .thriving: return .init(mark: .emoji("🌾"), tint: Color(red: 0.78, green: 0.58, blue: 0.10))
        case .confident: return .init(mark: .symbol("checkmark.seal"), tint: Color(red: 0.12, green: 0.52, blue: 0.32))
        case .content: return .init(mark: .symbol("sun.max"), tint: Color(red: 0.86, green: 0.62, blue: 0.08))
        case .atEase: return .init(mark: .symbol("leaf"), tint: Color(red: 0.28, green: 0.58, blue: 0.36))
        case .evenMinded: return .init(mark: .symbol("scale.3d"), tint: Color(red: 0.22, green: 0.48, blue: 0.58))
        case .neutral: return .init(mark: .symbol("minus"), tint: Color(red: 0.42, green: 0.44, blue: 0.48))
        case .challenged: return .init(mark: .symbol("mountain.2"), tint: Color(red: 0.72, green: 0.40, blue: 0.12))
        case .uncertain: return .init(mark: .symbol("questionmark"), tint: Color(red: 0.46, green: 0.32, blue: 0.72))
        case .doubtful: return .init(mark: .symbol("questionmark.circle"), tint: Color(red: 0.36, green: 0.28, blue: 0.64))
        case .uneasy: return .init(mark: .symbol("exclamationmark.triangle"), tint: Color(red: 0.78, green: 0.48, blue: 0.10))
        case .concerned: return .init(mark: .symbol("eye"), tint: Color(red: 0.22, green: 0.40, blue: 0.68))
        case .worried: return .init(mark: .symbol("cloud"), tint: Color(red: 0.38, green: 0.44, blue: 0.55))
        case .overthinking: return .init(mark: .symbol("brain"), tint: Color(red: 0.48, green: 0.28, blue: 0.70))
        case .pressured: return .init(mark: .symbol("gauge.with.dots.needle.67percent"), tint: Color(red: 0.80, green: 0.38, blue: 0.12))
        case .tense: return .init(mark: .symbol("bolt"), tint: Color(red: 0.86, green: 0.58, blue: 0.08))
        case .stressed: return .init(mark: .symbol("hurricane"), tint: Color(red: 0.74, green: 0.24, blue: 0.18))
        case .anxious: return .init(mark: .symbol("waveform.path.ecg"), tint: Color(red: 0.86, green: 0.36, blue: 0.16))
        case .overstimulated: return .init(mark: .symbol("rays"), tint: Color(red: 0.70, green: 0.22, blue: 0.55))
        case .ruminating: return .init(mark: .symbol("arrow.triangle.2.circlepath"), tint: Color(red: 0.50, green: 0.34, blue: 0.22))
        case .overwhelmed: return .init(mark: .symbol("tornado"), tint: Color(red: 0.70, green: 0.18, blue: 0.22))
        case .distressed: return .init(mark: .symbol("cloud.bolt.rain"), tint: Color(red: 0.55, green: 0.16, blue: 0.22))
        }
    }
}

struct JournalMarkIcon: View {
    let mark: JournalMark
    var width: CGFloat = 28

    var body: some View {
        Group {
            switch mark {
            case .symbol(let name):
                Image(systemName: name)
            case .emoji(let value):
                Text(value)
            }
        }
        .frame(width: width, alignment: .center)
        .accessibilityHidden(true)
    }
}

struct JournalFieldPicker: View {
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
                    choiceRow(title: "Not set", detail: nil, mark: nil, tint: nil, selected: currentIsEmpty)
                }
                .listRowBackground(Color(theme.palette.soft))
                .accessibilityIdentifier(field == .emotional ? "notes.journal.emotional.none" : "notes.journal.mental.none")

                switch field {
                case .emotional:
                    ForEach(JournalEmotionalState.allCases.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }, id: \.self) { state in
                        let appearance = JournalStateAppearance.emotional(state)
                        let selected = journal?.emotionalState == state
                        Button {
                            session.setJournalEmotionalState(state)
                            dismiss()
                        } label: {
                            choiceRow(title: state.label, detail: nil, mark: appearance.mark, tint: appearance.tint, selected: selected)
                        }
                        .listRowBackground(selected ? appearance.tint.opacity(0.20) : Color(theme.palette.soft))
                        .accessibilityIdentifier("notes.journal.emotional.\(state.rawValue)")
                    }
                case .mental:
                    ForEach(JournalMentalState.allCases, id: \.self) { state in
                        let appearance = JournalStateAppearance.mental(state)
                        let selected = journal?.mentalState == state
                        Button {
                            session.setJournalMentalState(state)
                            dismiss()
                        } label: {
                            choiceRow(title: state.label, detail: state.meaning, mark: appearance.mark, tint: appearance.tint, selected: selected)
                        }
                        .listRowBackground(selected ? appearance.tint.opacity(0.20) : Color(theme.palette.soft))
                        .accessibilityIdentifier("notes.journal.mental.\(state.rawValue)")
                    }
                }
            }
            .appSurface()
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

    private func choiceRow(title: String, detail: String?, mark: JournalMark?, tint: Color?, selected: Bool) -> some View {
        let color = selected ? (tint ?? Color(theme.palette.accent)) : Color(theme.palette.ink)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let mark {
                JournalMarkIcon(mark: mark)
                    .foregroundStyle(selected ? color : Color(theme.palette.secondary))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(color)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(selected ? color.opacity(0.85) : Color(theme.palette.secondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(color)
            }
        }
    }
}
