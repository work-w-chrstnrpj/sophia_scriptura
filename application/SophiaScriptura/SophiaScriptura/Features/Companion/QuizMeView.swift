import SwiftUI

struct QuizMeView: View {
    @ObservedObject var session: CompanionSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var difficulty: QuizDifficulty
    @State private var timed: Bool
    @State private var selectedTypes: Set<QuizType>
    @State private var examQuestionCount: ExamQuestionCount = .twentyFive
    @State private var examTimed: Bool = false
    @State private var examTimeLimit: ExamTimeLimit = .fiveMinutes
    @State private var errorMessage: String?
    @State private var generating = false

    init(session: CompanionSession, request: SophyQuizRequest? = nil) {
        self.session = session
        let resolved = request ?? SophyQuizRequest(difficulty: .easy, types: [.identifyVerse, .whoSaidIt], timed: false)
        _difficulty = State(initialValue: resolved.difficulty)
        _timed = State(initialValue: resolved.timed)
        _selectedTypes = State(initialValue: Set(resolved.types.isEmpty ? [QuizType.identifyVerse, .whoSaidIt] : resolved.types))
    }

    private let typeColumns = [GridItem(.adaptive(minimum: 168), spacing: 10)]

    private var isExamMode: Bool { session.examModeEnabled }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if isExamMode {
                        examSetupContent
                    } else {
                        standardSetupContent
                    }

                    if readyToStart {
                        Text("Ready to start. Fresh questions replenish automatically while you quiz.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Start when you are ready. Only missing questions need to be prepared; you do not need to fill the whole bank first.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    if session.quizCacheRefilling {
                        Label("Preparing fresh questions in the background", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Color(theme.palette.paper).ignoresSafeArea())
            .navigationTitle(isExamMode ? "Exam" : "Quiz Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(theme.palette.paper), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                QuizBottomBar {
                    Button {
                        Task { await startQuiz() }
                    } label: {
                        if generating {
                            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 14)
                        } else {
                            Text(startButtonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color(theme.palette.paper))
                    .tint(Color(theme.palette.accent))
                    .disabled(startDisabled || generating)
                }
            }
            .task {
                scheduleWarmup()
            }
            .onChange(of: difficulty) { _, _ in scheduleWarmup() }
            .onChange(of: selectedTypes) { _, _ in scheduleWarmup() }
            .onChange(of: examQuestionCount) { _, _ in scheduleWarmup() }
        }
    }

    @ViewBuilder
    private var standardSetupContent: some View {
        sectionHeader("Quiz types", hint: "Pick one or more")
        LazyVGrid(columns: typeColumns, spacing: 10) {
            ForEach(QuizType.quizMeSelectable, id: \.self) { type in
                QuizTypeChip(
                    title: type.quizTitle,
                    symbol: type.quizSymbol,
                    selected: selectedTypes.contains(type),
                    accent: Color(theme.palette.accent),
                    rule: Color(theme.palette.rule),
                    ink: Color(theme.palette.ink)
                ) {
                    toggleType(type)
                }
            }
        }

        sectionHeader("Difficulty")
        Picker("Level", selection: $difficulty) {
            ForEach(QuizDifficulty.allCases, id: \.self) { level in
                Text(level.title).tag(level)
            }
        }
        .pickerStyle(.segmented)

        Text(difficulty.detailLine)
            .font(.caption)
            .foregroundStyle(.secondary)
        if timed {
            Text("\(difficulty.timerSeconds)s per question · pauses on feedback")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Label("Questions and answer keys are generated by your selected AI provider. Check the cited passage when accuracy matters.", systemImage: "sparkles")
            .font(.caption)
            .foregroundStyle(.secondary)

        sectionHeader("Session")
        VStack(spacing: 0) {
            toggleRow("Timed (per question)", isOn: $timed)
        }
        .background(Color(theme.palette.rule).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(theme.palette.rule).opacity(0.4)))
        Text("Completed quizzes automatically add their active question time to Studying in Activity.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var examSetupContent: some View {
        Text("Draw random questions from your prepared pool across all quiz types and difficulty levels.")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        sectionHeader("Number of questions")
        Picker("Count", selection: $examQuestionCount) {
            ForEach(ExamQuestionCount.allCases, id: \.self) { count in
                Text("\(count.rawValue)").tag(count)
            }
        }
        .pickerStyle(.segmented)

        sectionHeader("Timer")
        VStack(spacing: 0) {
            toggleRow("Timed exam", isOn: $examTimed)
            if examTimed {
                Divider().padding(.leading, 16)
                Picker("Duration", selection: $examTimeLimit) {
                    ForEach(ExamTimeLimit.allCases, id: \.self) { limit in
                        Text(limit.label).tag(limit)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(theme.palette.rule).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(theme.palette.rule).opacity(0.4)))

        Label("Exam questions use the same AI-generated cache as Quiz Me. Turn Exam mode off in Settings to return to type and difficulty selection.", systemImage: "sparkles")
            .font(.caption)
            .foregroundStyle(.secondary)

        Text("Completed exams automatically add their active question time to Studying in Activity.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func sectionHeader(_ title: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private func toggleType(_ type: QuizType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    private var startDisabled: Bool {
        if isExamMode { return false }
        return selectedTypes.isEmpty
    }

    private var readyToStart: Bool {
        if isExamMode { return session.hasExamCache(questionCount: examQuestionCount.rawValue, editionID: "web-engwebp") }
        return session.hasCachedQuestions(types: Array(selectedTypes), difficulty: difficulty, editionID: "web-engwebp")
    }

    private var startButtonTitle: String { isExamMode ? "Start exam" : "Start quiz" }

    private func scheduleWarmup() {
        if isExamMode {
            session.scheduleQuizCacheWarmup(prioritizedTypes: QuizType.quizMeSelectable)
        } else {
            session.scheduleQuizCacheWarmup(prioritizedTypes: Array(selectedTypes), prioritizedDifficulty: difficulty)
        }
    }

    @MainActor
    private func startQuiz() async {
        generating = true
        errorMessage = nil
        defer { generating = false }
        do {
            if isExamMode {
                _ = try await session.startExamQuiz(
                    questionCount: examQuestionCount.rawValue,
                    editionID: "web-engwebp",
                    timed: examTimed,
                    sessionTimeLimitSeconds: examTimed ? examTimeLimit.rawValue : nil,
                    recordReviewing: true
                )
            } else {
                _ = try await session.startQuiz(
                    types: Array(selectedTypes),
                    difficulty: difficulty,
                    editionID: "web-engwebp",
                    timed: timed,
                    recordReviewing: true
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension QuizType {
    var quizTitle: String {
        switch self {
        case .identifyVerse: return "Identify the Verse"
        case .completeVerse: return "Complete the Verse"
        case .scriptureOrCap: return "Scripture or Cap"
        case .whoSaidIt: return "Who Said It?"
        case .christianHistory: return "Christian History"
        case .bibleQuiz: return "Bible Quiz"
        case .bibleOrFalse: return "Bible or False"
        case .identifyReference: return "Identify the Reference"
        }
    }
}

extension QuizDifficulty {
    var title: String {
        switch self {
        case .easy: return "Easy"
        case .average: return "Average"
        case .difficult: return "Difficult"
        }
    }
}
