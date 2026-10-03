import SwiftUI

struct QuizProgressStrip: View {
    let current: Int
    let total: Int
    let scoreEarned: Int
    let scoreAvailable: Int
    let accent: Color
    let rule: Color

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(min(current, total)) / CGFloat(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Question \(min(current, total)) of \(total)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(scoreEarned)/\(scoreAvailable) pts")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(rule).opacity(0.35))
                    Capsule()
                        .fill(Color(accent))
                        .frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 5)
        }
    }
}

struct QuizChoiceRow: View {
    let title: String
    let selected: Bool
    let accent: Color
    let rule: Color
    let ink: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color(ink))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color(accent) : Color(rule).opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color(accent).opacity(0.14) : Color(rule).opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color(accent).opacity(0.55) : Color(rule).opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct QuizBottomBar<Content: View>: View {
    @Environment(\.appTheme) private var theme
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(theme.palette.rule).opacity(0.6))
            content()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
        .background(Color(theme.palette.paper).ignoresSafeArea(edges: .bottom))
    }
}

struct QuizTypeChip: View {
    let title: String
    let symbol: String
    let selected: Bool
    let accent: Color
    let rule: Color
    let ink: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(ink))
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color(accent).opacity(0.16) : Color(rule).opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color(accent).opacity(0.5) : Color(rule).opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

extension QuizType {
    var quizSymbol: String {
        switch self {
        case .identifyVerse, .identifyReference: return "text.quote"
        case .completeVerse: return "text.append"
        case .scriptureOrCap: return "questionmark.circle"
        case .whoSaidIt: return "person.wave.2"
        case .christianHistory: return "building.columns"
        case .bibleQuiz: return "book.pages"
        case .bibleOrFalse: return "checkmark.circle.trianglebadge.exclamationmark"
        }
    }
}

extension QuizDifficulty {
    var detailLine: String {
        "\(questionCount) questions · \(pointsEach) pt each"
    }
}
