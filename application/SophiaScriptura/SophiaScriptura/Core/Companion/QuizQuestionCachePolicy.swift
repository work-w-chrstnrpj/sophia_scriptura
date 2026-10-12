import Foundation

/// SP-019 prepared-question pool sizing (per provider/model/edition/type/difficulty bucket).
enum QuizQuestionCachePolicy {
    static let bucketTargetCount = 100
    /// Provider completions are requested in smaller batches to stay within output limits.
    static let refillBatchSize = 10
}

enum ExamQuestionCount: Int, CaseIterable, Sendable {
    case twentyFive = 25
    case fifty = 50
    case hundred = 100
}

enum ExamTimeLimit: Int, CaseIterable, Sendable {
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900

    var label: String {
        switch self {
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        case .fifteenMinutes: return "15 minutes"
        }
    }
}

enum QuizSessionMode: String, Codable, Sendable {
    case standard
    case exam
}
