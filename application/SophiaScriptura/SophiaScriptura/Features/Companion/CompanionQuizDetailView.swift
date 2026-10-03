import SwiftUI

struct CompanionQuizDetailView: View {
    @ObservedObject var session: CompanionSession
    let quizID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var confirmingDelete = false

    private var quiz: QuizSession? { session.quizSessions.first { $0.id == quizID } }
    private var questions: [QuizQuestionRecord] { session.quizQuestions(for: quizID) }
    private var attempts: [QuizAttemptRecord] { session.quizAttempts(for: quizID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if let quiz {
                        summaryCard(quiz)
                    }
                    ForEach(questions) { question in
                        questionCard(question, attempt: attempts.first { $0.questionID == question.id })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(theme.palette.paper).ignoresSafeArea())
            .navigationTitle("Quiz history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(theme.palette.paper), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Archive") {
                        session.archiveQuizSession(quizID)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive) { confirmingDelete = true }
                }
            }
            .studyCenteredConfirmation(
                isPresented: $confirmingDelete,
                title: "Delete this quiz?",
                message: "The quiz session and its answers are removed from history.",
                confirmLabel: "Delete Quiz"
            ) {
                session.deleteQuizSession(quizID)
                dismiss()
            }
        }
    }

    private func summaryCard(_ quiz: QuizSession) -> some View {
        let percentage = QuizResultSummary.percentage(earned: quiz.scoreEarned, available: max(quiz.scoreAvailable, 1))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(quiz.scoreEarned)/\(quiz.scoreAvailable)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                Text("· \(percentage)%")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                Label(quiz.difficulty.title, systemImage: "gauge.with.dots.needle.33percent")
                Label(quiz.timed ? "Timed" : "Untimed", systemImage: quiz.timed ? "timer" : "timer.slash")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text((quiz.completedAt ?? quiz.createdAt).formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(theme.palette.rule).opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func questionCard(_ question: QuizQuestionRecord, attempt: QuizAttemptRecord?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Q\(question.index + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(question.type.quizTitle)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(theme.palette.accent).opacity(0.12), in: Capsule())
                Spacer()
                if let attempt {
                    Text(attempt.result.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(attempt.result.color)
                }
            }
            Text(question.prompt)
                .font(.system(.body, design: .serif))
            if let attempt {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You").font(.caption2).foregroundStyle(.secondary)
                        Text(displayAnswer(attempt, question: question)).font(.subheadline)
                    }
                    if attempt.result == .incorrect || attempt.result == .unanswered {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Answer").font(.caption2).foregroundStyle(.secondary)
                            Text(question.correctAnswerDisplay)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            if !question.explanation.isEmpty {
                Text(question.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(theme.palette.rule).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func displayAnswer(_ attempt: QuizAttemptRecord, question: QuizQuestionRecord) -> String {
        if !attempt.ownerAnswer.isEmpty { return attempt.ownerAnswer }
        if let index = attempt.choiceIndex, question.choices.indices.contains(index) {
            return question.choices[index]
        }
        return "—"
    }
}

private extension QuizAnswerResult {
    var title: String {
        switch self {
        case .correct: return "Correct"
        case .nearlyCorrect: return "Nearly correct"
        case .incorrect: return "Incorrect"
        case .unanswered: return "Unanswered"
        }
    }

    var color: Color {
        switch self {
        case .correct: return .green
        case .nearlyCorrect: return .orange
        case .incorrect: return .red
        case .unanswered: return .secondary
        }
    }
}
