import Foundation

/// On-screen study companions share one Sophy session and provider route; each has distinct presentation.
enum StudyCompanionCharacter: String, CaseIterable, Codable, Sendable, Identifiable {
    case sophy
    case sol
    case sabinus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sophy: "Sophy"
        case .sol: "Sol"
        case .sabinus: "Sabinus"
        }
    }

    var subtitle: String {
        switch self {
        case .sophy: "Lady Wisdom · Proverbs"
        case .sol: "The Preacher · Ecclesiastes"
        case .sabinus: "The Old Man · Job"
        }
    }

    var assetPrefix: String {
        switch self {
        case .sophy: "Sophy"
        case .sol: "Sol"
        case .sabinus: "Sabinus"
        }
    }

    var welcomeGreeting: String {
        "Hi, I'm \(displayName), how can I help you today?"
    }

    var accessibilityHint: String {
        switch self {
        case .sophy: "Lady Wisdom, your study companion"
        case .sol: "Sol, the preacher from Ecclesiastes"
        case .sabinus: "Sabinus, a companion from Job"
        }
    }

    static func stored(_ raw: String?) -> StudyCompanionCharacter {
        StudyCompanionCharacter(rawValue: raw ?? "") ?? .sophy
    }
}

struct StudyCompanionIdleQuote: Equatable, Sendable {
    var reference: String
    var text: String
}
