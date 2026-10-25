import Foundation

struct StudyPlan: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var materialsFolderID: UUID?
    var folderOwnershipConfirmed: Bool?
    var revision = 0
    var title: String
    var detail = ""
    var sectionPrefix = "Day"
    var preferredEditionID: String
    var referenceSystemID: String
    var sections: [PlanSection] = []
    var cursor: PlanCursor?
    var access = StudyAccessRequirements()
    var createdAt = Date()
    var modifiedAt = Date()
    var archivedAt: Date?
    var trashedAt: Date?
    var isActive: Bool { archivedAt == nil && trashedAt == nil }
    var items: [PlanItem] { sections.flatMap(\.items) }
    var completedSectionCount: Int { sections.filter { !$0.items.isEmpty && $0.items.allSatisfy { $0.completedAt != nil } }.count }
    var completedCount: Int { items.filter { $0.completedAt != nil }.count }
    var isComplete: Bool { !sections.isEmpty && completedSectionCount == sections.count }
    func sectionTitle(_ index: Int) -> String { sections[index].title ?? "\(sectionPrefix) \(index + 1)" }
    func validate() throws {
        guard revision >= 0, title == title.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty, title.count <= 80, detail.count <= 4000,
              !sectionPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              sectionPrefix.count <= 40, !preferredEditionID.isEmpty, !referenceSystemID.isEmpty,
              sections.count <= 200, items.count <= 2000 else { throw StudyMutationFailure.invalid }
        var ids: Set<UUID> = [id]
        for section in sections {
            guard ids.insert(section.id).inserted,
                  section.title.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 120 }) ?? true else { throw StudyMutationFailure.invalid }
            for item in section.items {
                guard ids.insert(item.id).inserted else { throw StudyMutationFailure.invalid }
                try item.payload.validate()
            }
        }
        if let cursor {
            switch cursor.kind {
            case .item:
                guard let section = sections.first(where: { $0.id == cursor.sectionID }),
                      section.items.contains(where: { $0.id == cursor.itemID }), cursor.editionID != nil else { throw StudyMutationFailure.invalid }
            case .sectionSummary:
                guard sections.contains(where: { $0.id == cursor.sectionID }) else { throw StudyMutationFailure.invalid }
            case .planSummary: break
            }
        }
    }
    mutating func reset(sectionID: UUID? = nil) {
        for s in sections.indices where sectionID == nil || sections[s].id == sectionID {
            for i in sections[s].items.indices { sections[s].items[i].completedAt = nil }
        }
        if sectionID == nil || cursor?.sectionID == sectionID { cursor = nil }
    }
    func duplicated() -> Self {
        var copy = self; copy.id = UUID(); copy.materialsFolderID = nil; copy.folderOwnershipConfirmed = nil; copy.revision = 0; copy.cursor = nil
        copy.title = String(title.prefix(73)) + " (Copy)"; copy.createdAt = Date(); copy.modifiedAt = copy.createdAt
        copy.archivedAt = nil; copy.trashedAt = nil
        for s in copy.sections.indices {
            copy.sections[s].id = UUID(); copy.sections[s].materialsFolderID = nil
            for i in copy.sections[s].items.indices {
                copy.sections[s].items[i].id = UUID(); copy.sections[s].items[i].completedAt = nil
                copy.sections[s].items[i].operationID = nil
            }
        }
        return copy
    }
}
struct PlanSection: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var materialsFolderID: UUID?
    var title: String?
    var items: [PlanItem] = []
}
struct PlanItem: Codable, Equatable, Identifiable, Sendable {
    enum Origin: String, Codable, Sendable { case assignment, reflection }
    var id = UUID()
    var payload: PlanItemPayload
    var completedAt: Date?
    var origin: Origin = .assignment
    var createdAt = Date()
    var operationID: UUID?
}
/// Explicit stable tag/keys, rather than Swift's synthesized associated-enum encoding.
struct PlanItemPayload: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case scripture, note, link }
    enum Selection: String, Codable, Sendable { case wholeChapter, verseRange }
    var kind: Kind
    var referenceSystemID: String?
    var book: String?
    var chapter: Int?
    var selection: Selection?
    var startVerse: Int?
    var endVerse: Int?
    var targetID: UUID?
    static func scripture(referenceSystemID: String, book: String, chapter: Int, start: Int? = nil, end: Int? = nil) -> Self {
        .init(kind: .scripture, referenceSystemID: referenceSystemID, book: book, chapter: chapter,
              selection: start == nil ? .wholeChapter : .verseRange, startVerse: start, endVerse: end ?? start)
    }
    func validate() throws {
        switch kind {
        case .note, .link:
            guard targetID != nil, book == nil, chapter == nil, referenceSystemID == nil,
                  selection == nil, startVerse == nil, endVerse == nil else { throw StudyMutationFailure.invalid }
        case .scripture:
            guard targetID == nil, let book, book.count == 3, book.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
                  let chapter, (1...150).contains(chapter), let referenceSystemID, !referenceSystemID.isEmpty else { throw StudyMutationFailure.invalid }
            switch selection {
            case .wholeChapter:
                guard startVerse == nil, endVerse == nil else { throw StudyMutationFailure.invalid }
            case .verseRange:
                guard let startVerse, let endVerse, startVerse > 0, endVerse >= startVerse, endVerse <= 176 else { throw StudyMutationFailure.invalid }
            case nil: throw StudyMutationFailure.invalid
            }
        }
    }
    func referenceLabel(bookTitle: String) -> String {
        guard let book, !book.isEmpty else { return referenceLabel }
        return bookTitle + referenceLabel.dropFirst(book.count)
    }
    var referenceLabel: String {
        guard kind == .scripture else { return kind == .note ? "Note" : "Link" }
        let base = "\(book ?? "") \(chapter ?? 1)"
        guard selection == .verseRange, let startVerse, let endVerse else { return base }
        return base + (startVerse == endVerse ? ":\(startVerse)" : ":\(startVerse)–\(endVerse)")
    }
}
struct PlanCursor: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case item, sectionSummary, planSummary }
    var kind: Kind
    var sectionID: UUID?
    var itemID: UUID?
    var location: ReadingLocation?
    var editionID: String?
}
struct RetainedPlanAccess: Codable, Equatable, Sendable {
    var planID: UUID
    var lastTitle: String
    var access: StudyAccessRequirements
    var detachedAt: Date?
}
