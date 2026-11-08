import Foundation

/// Explicit, transient context for questions sent from a Plan workspace.
struct PlanQuestionContext: Equatable {
    let label: String
    let text: String?
    let isScripture: Bool

    static func scripture(_ document: ChapterDocument, assignment: PlanItemPayload, label: String) -> Self {
        let allowed = TranslationRightsPolicyResolver.policy(forEditionID: document.editionID)?.aiContext == .allowed
        let map = ChapterTextMap(document: document)
        let ranges: [NSRange]
        if assignment.selection == .verseRange, let first = assignment.startVerse,
           let last = assignment.endVerse, first <= last {
            ranges = document.verseNumbers.filter { (first...last).contains($0) }.flatMap { map.focusRanges(for: $0) }
        } else {
            ranges = [NSRange(location: 0, length: map.text.utf16.count)]
        }
        let range = ranges.reduce(nil as NSRange?) { result, next in
            result.map { NSUnionRange($0, next) } ?? next
        }
        let text = allowed ? range.map { map.selection(in: $0).text } ?? "" : ""
        return .init(label: label, text: bounded(text), isScripture: true)
    }

    static func note(_ note: NoteDocument) -> Self {
        var blocks = [note.page?.body ?? ""]
        let typedKinds: [NoteObject.Kind] = [.text, .bullets, .numbered]
        blocks += note.objects.filter { typedKinds.contains($0.kind) }.map(\.text)
        return .init(label: note.title, text: bounded(blocks.joined(separator: "\n\n")), isScripture: false)
    }

    private static func bounded(_ value: String) -> String? {
        let text = value.replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return text.count <= 12_000 ? text : String(text.prefix(12_000)) + "\n[Excerpt ends here.]"
    }
}
