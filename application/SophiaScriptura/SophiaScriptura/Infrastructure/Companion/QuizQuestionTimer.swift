import Foundation

/// Per-question countdown for timed Quiz Me. Feedback and pauses do not consume limit time.
struct QuizQuestionTimer: Equatable {
    let limitSeconds: Int
    private(set) var remainingSeconds: Int

    init(limitSeconds: Int) {
        self.limitSeconds = limitSeconds
        self.remainingSeconds = limitSeconds
    }

    var isExpired: Bool { remainingSeconds <= 0 }

    var consumedSeconds: Int { max(0, limitSeconds - remainingSeconds) }

    mutating func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
    }

    mutating func expire() {
        remainingSeconds = 0
    }
}

enum QuizResultSummary {
    static func counts(for attempts: [QuizAttemptRecord]) -> (correct: Int, nearly: Int, incorrect: Int, unanswered: Int) {
        var correct = 0, nearly = 0, incorrect = 0, unanswered = 0
        for attempt in attempts {
            switch attempt.result {
            case .correct: correct += 1
            case .nearlyCorrect: nearly += 1
            case .incorrect: incorrect += 1
            case .unanswered: unanswered += 1
            }
        }
        return (correct, nearly, incorrect, unanswered)
    }

    static func percentage(earned: Int, available: Int) -> Int {
        guard available > 0 else { return 0 }
        return Int((Double(earned) / Double(available) * 100).rounded())
    }
}
