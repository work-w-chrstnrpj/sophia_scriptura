import Foundation

struct SophyNoteSelection: Equatable {
    var noteID: UUID
    var objectID: UUID?
    var range: NSRange
    var text: String
    var digest: String
    var revision: Date
    var editorRoute: UUID?
    var requiresConsent: Bool
}

enum SophyEnhancementOperation: String, CaseIterable, Identifiable {
    case grammar, tone, organize, expound, rate
    var id: String { rawValue }
    var title: String {
        switch self {
        case .grammar: "Grammar Check"
        case .tone: "Recreate Text Tone"
        case .organize: "Organize Idea"
        case .expound: "Expound"
        case .rate: "Rate"
        }
    }
}
