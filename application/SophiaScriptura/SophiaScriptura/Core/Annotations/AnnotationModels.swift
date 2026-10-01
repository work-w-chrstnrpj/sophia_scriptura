import Foundation

struct AnnotationSource: Codable, Equatable, Hashable, Sendable {
    let editionID: String
    let contentRevision: String
    let referenceSystemID: String
    let book: String
    let chapter: Int
    init(_ document: ChapterDocument) {
        editionID = document.editionID; contentRevision = document.contentRevision
        referenceSystemID = document.referenceSystemID; book = document.book; chapter = document.chapter
    }
}

struct AnnotationLayout: Codable, Equatable, Sendable {
    var algorithm = "continuous-textkit1-v1"
    let fontName: String
    let fontResourceHash: String
    let fontSize: Double
    let width: Double
    let textWidth: Double
    let height: Double
    let inset: Double
    let marginStart: Double
    let lineSpacing: Double
    let paragraphSpacing: Double
    let signature: String
    var surroundingSpace: Bool { algorithm == "continuous-textkit1-surround-v2" }
}

struct AnnotationLayer: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var createdAt = Date()
    var updatedAt = Date()
    var deletedAt: Date?
    var revision = 0
    var drawing: Data
    // Optional for archives written before layouts and appearance belonged to each layer.
    var layout: AnnotationLayout?
    var appearance: AnnotationLayerAppearance?
}

struct AnnotationLayerAppearance: Codable, Equatable, Sendable {
    let presetID: String?
    let typeface: String
    let sizeStep: Int
    init(_ preferences: ReaderPreferences) {
        presetID = preferences.appearancePreset
        typeface = preferences.typeface
        sizeStep = preferences.sizeStep
    }
    func applying(to current: ReaderPreferences) -> ReaderPreferences {
        var value = current
        value.appearancePreset = presetID
        value.typeface = typeface
        value.sizeStep = sizeStep
        return value
    }
}

struct AnnotationGroup: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    let source: AnnotationSource
    let layout: AnnotationLayout
    var layers: [AnnotationLayer] = []
    var selectedLayerID: UUID?
}

struct AnnotationSnapshot: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var revision = 0
    var groups: [AnnotationGroup] = []
}

struct AnnotationLoad: Sendable {
    let snapshot: AnnotationSnapshot
    let recovered: Bool
}

enum AnnotationError: LocalizedError {
    case invalid, unsupported, stale, damaged, tooLarge, interrupted
    var errorDescription: String? {
        switch self {
        case .invalid: "Invalid annotation data. The existing store is unchanged."
        case .unsupported: "This annotation format is not supported. Original files are retained."
        case .stale: "Annotation data changed during saving. Reopen before replacing it."
        case .damaged: "Annotations could not be opened. Original files are retained; restore a backup."
        case .tooLarge: "Annotation data exceeds the supported backup or drawing size."
        case .interrupted: "Annotation save was interrupted. Retry saving."
        }
    }
}

protocol AnnotationRepository: Sendable {
    func load() async throws -> AnnotationLoad
    func save(_ snapshot: AnnotationSnapshot, expectedRevision: Int) async throws -> AnnotationSnapshot
    func exportArchive() async throws -> Data
    func exportPreRestoreArchive() async throws -> Data
    func restoreArchive(_ data: Data, expectedRevision: Int) async throws -> AnnotationSnapshot
}
