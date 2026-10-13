import SwiftUI
import Combine

struct QuizSessionView: View {
    @ObservedObject var session: CompanionSession
    let quizID: UUID
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme
    @State private var questionIndex = 0
    @State private var phase: Phase = .answering
    @State private var answerText = ""
    @State private var choiceIndex: Int?
    @State private var questionTimer: QuizQuestionTimer?
    @State private var examSessionTimer: QuizQuestionTimer?
    @State private var questionTimeStartedAt: Date?
    @State private var questionElapsedSeconds: TimeInterval = 0
    @State private var timerTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var loadingNextRound = false
    @State private var roundNotice: String?

    private enum Phase: Equatable {
        case answering
        case feedback(QuizAnswerResult, QuizQuestionRecord)
        case summary
    }

    private var quiz: QuizSession? { session.quizSessions.first { $0.id == quizID } }
    private var questions: [QuizQuestionRecord] {
        session.quizQuestions.filter { $0.sessionID == quizID }.sorted { $0.index < $1.index }
    }
    private var current: QuizQuestionRecord? {
        questions.indices.contains(questionIndex) ? questions[questionIndex] : nil
    }
    private var attempts: [QuizAttemptRecord] {
        let questionIDs = Set(questions.map(\.id))
        return session.quizAttempts.filter { questionIDs.contains($0.questionID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let quiz, phase != .summary {
                QuizProgressStrip(
                    current: progressIndex,
                    total: questions.count,
                    scoreEarned: quiz.scoreEarned,
                    scoreAvailable: quiz.scoreAvailable,
                    accent: Color(theme.palette.accent),
                    rule: Color(theme.palette.rule)
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch phase {
                    case .answering:
                        answeringContent
                    case .feedback(let result, let question):
                        feedbackContent(result: result, question: question)
                    case .summary:
                        summaryContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(theme.palette.paper).ignoresSafeArea())
        .foregroundStyle(Color(theme.palette.ink))
        .navigationTitle(quiz?.mode == .exam ? "Exam" : "Quiz Me")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(theme.palette.paper), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .onReceive(timerTick) { _ in tickTimer() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { pauseTimerTracking() }
            else if case .answering = phase { questionTimeStartedAt = Date() }
        }
        .onAppear { resetTimerForCurrentQuestion() }
        .onDisappear { pauseTimerTracking() }
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch phase {
        case .answering:
            if current != nil {
                QuizBottomBar {
                    Button("Submit answer") { submitCurrent(timedOut: false) }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Color(theme.palette.paper))
                        .tint(Color(theme.palette.accent))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .disabled(submitDisabled)
                        .accessibilityIdentifier("quiz.submit")
                }
            }
        case .feedback:
            QuizBottomBar {
                Button("Continue") { advanceAfterFeedback() }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color(theme.palette.paper))
                    .tint(Color(theme.palette.accent))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        case .summary:
            QuizBottomBar {
                VStack(spacing: 10) {
                    if showsQuizAgain {
                        Button {
                            Task { await startAnotherRound() }
                        } label: {
                            Label(loadingNextRound ? "Preparing next round…" : "Quiz again", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(theme.palette.accent))
                        .disabled(loadingNextRound)
                        .accessibilityIdentifier("quiz.again")
                    }
                    Button("Done") { session.finishQuiz(sessionID: quizID, intentional: true) }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(Color(theme.palette.paper))
                        .tint(Color(theme.palette.accent))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    private var progressIndex: Int {
        switch phase {
        case .answering: return questionIndex + 1
        case .feedback: return questionIndex + 1
        case .summary: return questions.count
        }
    }

    private var showsQuizAgain: Bool {
        quiz?.mode == .standard
    }

    private var submitDisabled: Bool {
        guard let question = current else { return true }
        switch question.type {
        case .completeVerse:
            return answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return choiceIndex == nil
        }
    }

    @ViewBuilder
    private var answeringContent: some View {
        if let question = current {
            questionBadge(question.type.quizTitle)
            Text(question.prompt)
                .font(.system(.title3, design: .serif))
                .fixedSize(horizontal: false, vertical: true)

            if quiz?.mode == .exam, quiz?.timed == true, let examSessionTimer, phase != .summary {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text(examTimerLabel(examSessionTimer.remainingSeconds))
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(Color(theme.palette.accent))
                .accessibilityIdentifier("quiz.examTimer")
            } else if quiz?.mode != .exam, quiz?.timed == true, let questionTimer {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("\(questionTimer.remainingSeconds)s")
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(Color(theme.palette.accent))
                .accessibilityIdentifier("quiz.timer")
            }

            questionControls(question)
        } else {
            Color.clear
                .frame(height: 1)
                .onAppear { phase = .summary }
        }
    }

    private func feedbackContent(result: QuizAnswerResult, question: QuizQuestionRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: result.feedbackSymbol)
                    .font(.largeTitle)
                    .foregroundStyle(result.color)
                Text(result.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(result.color)
            }
            if !question.explanation.isEmpty {
                Text(question.explanation)
                    .font(.body)
            }
            if let reference = question.answerKey.referenceLabel, !reference.isEmpty {
                callout(title: "Reference", body: reference)
            }
            Text("AI-generated question and answer key. Verify the cited reference if anything seems uncertain.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if result == .incorrect || result == .unanswered {
                callout(title: "Correct answer", body: question.correctAnswerDisplay)
            } else if result == .nearlyCorrect, let text = question.answerKey.canonicalText {
                callout(title: "Edition wording", body: text)
            }
            if question.type == .christianHistory {
                ForEach(session.sources(for: question)) { source in
                    callout(
                        title: source.title,
                        body: source.authorOrPublisher ?? "Source"
                    )
                }
            }
        }
    }

    private var summaryContent: some View {
        let counts = QuizResultSummary.counts(for: attempts)
        let earned = quiz?.scoreEarned ?? 0
        let available = quiz?.scoreAvailable ?? 1
        let percentage = QuizResultSummary.percentage(earned: earned, available: available)
        return VStack(alignment: .leading, spacing: 20) {
            Text((quiz?.roundCount ?? 1) > 1 ? "Round \(quiz?.roundCount ?? 1) complete" : "Quiz complete")
                .font(.title.weight(.semibold))
            if showsQuizAgain {
                Text("Want another round? Your time stays on one Quiz Me activity until you tap Done.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let roundNotice {
                Text(roundNotice)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(earned)/\(available)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                Text("points · \(percentage)%")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                summaryStat("Correct", counts.correct)
                summaryStat("Nearly correct", counts.nearly)
                summaryStat("Incorrect", counts.incorrect)
                summaryStat("Unanswered", counts.unanswered)
            }
            .font(.subheadline)
        }
        .padding(.top, 8)
    }

    private func summaryStat(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text("\(value)").monospacedDigit()
        }
    }

    private func questionBadge(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(theme.palette.accent).opacity(0.14), in: Capsule())
            .foregroundStyle(Color(theme.palette.accent))
    }

    private func callout(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(body)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(theme.palette.rule).opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func questionControls(_ question: QuizQuestionRecord) -> some View {
        switch question.type {
        case .completeVerse:
            TextField("Complete the verse", text: $answerText, axis: .vertical)
                .lineLimit(3...8)
                .padding(12)
                .background(Color(theme.palette.rule).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(theme.palette.rule).opacity(0.45)))
                .accessibilityIdentifier("quiz.completeVerse")
        case .scriptureOrCap:
            VStack(spacing: 10) {
                QuizChoiceRow(title: "Scripture", selected: choiceIndex == 0, accent: Color(theme.palette.accent), rule: Color(theme.palette.rule), ink: Color(theme.palette.ink)) {
                    choiceIndex = 0
                }
                QuizChoiceRow(title: "Cap", selected: choiceIndex == 1, accent: Color(theme.palette.accent), rule: Color(theme.palette.rule), ink: Color(theme.palette.ink)) {
                    choiceIndex = 1
                }
            }
        case .bibleOrFalse:
            VStack(spacing: 10) {
                QuizChoiceRow(title: "True", selected: choiceIndex == 0, accent: Color(theme.palette.accent), rule: Color(theme.palette.rule), ink: Color(theme.palette.ink)) {
                    choiceIndex = 0
                }
                QuizChoiceRow(title: "False", selected: choiceIndex == 1, accent: Color(theme.palette.accent), rule: Color(theme.palette.rule), ink: Color(theme.palette.ink)) {
                    choiceIndex = 1
                }
            }
        default:
            VStack(spacing: 10) {
                ForEach(question.choices.indices, id: \.self) { index in
                    QuizChoiceRow(
                        title: question.choices[index],
                        selected: choiceIndex == index,
                        accent: Color(theme.palette.accent),
                        rule: Color(theme.palette.rule),
                        ink: Color(theme.palette.ink)
                    ) {
                        choiceIndex = index
                    }
                }
            }
        }
    }

    private func submitCurrent(timedOut: Bool) {
        guard let question = current else { return }
        submit(question, timedOut: timedOut)
    }

    private func tickTimer() {
        guard quiz?.timed == true, scenePhase == .active else { return }
        if quiz?.mode == .exam, var examTimer = examSessionTimer {
            examTimer.tick()
            examSessionTimer = examTimer
            if examTimer.isExpired {
                expireExamSession()
            }
            return
        }
        guard case .answering = phase,
              var timer = questionTimer,
              let question = current else { return }
        timer.tick()
        questionTimer = timer
        if timer.isExpired {
            submit(question, timedOut: true)
        }
    }

    private func examTimerLabel(_ remainingSeconds: Int) -> String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d remaining", minutes, seconds)
    }

    private func expireExamSession() {
        pauseTimerTracking()
        examSessionTimer = nil
        if case .answering = phase, let question = current {
            submit(question, timedOut: true)
        }
        questionIndex = questions.count
        phase = .summary
    }

    private func pauseTimerTracking() {
        if let questionTimeStartedAt {
            questionElapsedSeconds += max(0, Date().timeIntervalSince(questionTimeStartedAt))
            self.questionTimeStartedAt = nil
        }
    }

    private func resetTimerForCurrentQuestion() {
        questionElapsedSeconds = 0
        questionTimeStartedAt = scenePhase == .active ? Date() : nil
        guard let quiz, quiz.timed else {
            questionTimer = nil
            examSessionTimer = nil
            return
        }
        if quiz.mode == .exam, let limit = quiz.sessionTimeLimitSeconds {
            if examSessionTimer == nil {
                examSessionTimer = QuizQuestionTimer(limitSeconds: limit)
            }
            questionTimer = nil
        } else {
            examSessionTimer = nil
            questionTimer = QuizQuestionTimer(limitSeconds: quiz.difficulty.timerSeconds)
        }
    }

    private func recordTimerConsumption() {
        pauseTimerTracking()
        session.addQuizQuestionActiveTime(sessionID: quizID, seconds: max(1, Int(questionElapsedSeconds.rounded())))
    }

    private func submit(_ question: QuizQuestionRecord, timedOut: Bool) {
        recordTimerConsumption()
        let answer: String
        let selected: Int?
        if timedOut {
            answer = ""
            selected = nil
        } else if question.type == .completeVerse {
            answer = answerText
            selected = nil
        } else if question.type == .scriptureOrCap {
            answer = choiceIndex == 0 ? "Scripture" : (choiceIndex == 1 ? "Cap" : "")
            selected = choiceIndex
        } else if question.type == .bibleOrFalse {
            answer = choiceIndex == 0 ? "True" : (choiceIndex == 1 ? "False" : "")
            selected = choiceIndex
        } else {
            selected = choiceIndex
            answer = choiceIndex.map { question.choices[$0] } ?? ""
        }
        session.submitQuizAnswer(sessionID: quizID, questionID: question.id, answer: answer, choiceIndex: selected)
        let attempt = session.quizAttempts.last { $0.questionID == question.id }
        let result = attempt?.result ?? .unanswered
        answerText = ""
        choiceIndex = nil
        questionTimer = nil
        phase = .feedback(result, question)
    }

    private func advanceAfterFeedback() {
        questionIndex += 1
        if questionIndex >= questions.count {
            phase = .summary
        } else {
            phase = .answering
            resetTimerForCurrentQuestion()
        }
    }

    private func startAnotherRound() async {
        guard !loadingNextRound else { return }
        loadingNextRound = true
        roundNotice = nil
        defer { loadingNextRound = false }
        let previousCount = questions.count
        do {
            try await session.appendQuizRound(sessionID: quizID)
            questionIndex = previousCount
            phase = .answering
            answerText = ""
            choiceIndex = nil
            resetTimerForCurrentQuestion()
        } catch {
            roundNotice = (error as? LocalizedError)?.errorDescription ?? "Could not start another round."
        }
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

    var feedbackSymbol: String {
        switch self {
        case .correct: return "checkmark.circle.fill"
        case .nearlyCorrect: return "minus.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        case .unanswered: return "questionmark.circle.fill"
        }
    }
}

extension CompanionSession {
    func sources(for question: QuizQuestionRecord) -> [CompanionSource] {
        question.sourceIDs.compactMap { id in sources.first { $0.id == id } }
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return state
    }
}
