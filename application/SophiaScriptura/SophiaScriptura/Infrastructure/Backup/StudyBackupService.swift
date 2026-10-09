import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Full-device study backup excluding user music files and Keychain provider secrets.
struct StudyFullBackupEnvelope: Codable, Sendable {
    var schemaVersion = 1
    var exportedAt: Date
    var notes: Data
    var annotations: Data
    var activity: Data
    var collections: CollectionsSnapshot
    var companion: CompanionSnapshot
}

enum StudyBackupError: Error, LocalizedError {
    case unsupported
    case invalid

    var errorDescription: String? {
        switch self {
        case .unsupported: return "This backup is from a newer Sophia."
        case .invalid: return "The backup file could not be read."
        }
    }
}

@MainActor
enum StudyBackupService {
    static func export(
        notes: NotesSession,
        annotations: AnnotationSession,
        activity: ActivityStore,
        collections: CollectionsStore,
        companion: CompanionSession
    ) async throws -> Data {
        try await notes.protection.authorize([.notes: notes.snapshot.notes.map(\.protectionID), .collections: collections.collections.map(\.protectionID)])
        let notesData = try await notes.export()
        let annotationsData = try await annotations.export()
        guard let activityData = await activity.exportArchive() else { throw StudyBackupError.invalid }
        let envelope = StudyFullBackupEnvelope(
            exportedAt: Date(),
            notes: notesData,
            annotations: annotationsData,
            activity: activityData,
            collections: try collections.exportBackupSnapshot(),
            companion: companion.backupSnapshot()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try notes.protection.require(notes.snapshot.notes.map(\.protectionID), in: .notes)
        return try encoder.encode(envelope)
    }

    static func restore(
        _ data: Data,
        notes: NotesSession,
        annotations: AnnotationSession,
        activity: ActivityStore,
        collections: CollectionsStore,
        companion: CompanionSession,
        readerDocument: ChapterDocument?
    ) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(StudyFullBackupEnvelope.self, from: data)
        guard envelope.schemaVersion == 1 else { throw StudyBackupError.unsupported }
        try await notes.protection.authorize([.notes: notes.snapshot.notes.map(\.protectionID), .collections: collections.collections.map(\.protectionID)])
        try notes.protection.require(notes.snapshot.notes.map(\.protectionID), in: .notes)
        try collections.protection.require(collections.collections.map(\.protectionID), in: .collections)
        _ = try NotesFileRepository.inspectArchive(envelope.notes)
        guard (1...2).contains(envelope.collections.schemaVersion) else { throw StudyBackupError.unsupported }
        await notes.restore(envelope.notes)
        guard notes.notice == "Notes backup restored. The pre-restore copy is available in Backups." else { throw StudyBackupError.invalid }
        await annotations.restore(envelope.annotations, document: readerDocument)
        await activity.restoreArchive(envelope.activity)
        await collections.restoreBackupSnapshot(envelope.collections)
        guard collections.notice == "Collections restored from backup." else { throw StudyBackupError.invalid }
        await companion.restoreBackupSnapshot(envelope.companion)
    }
}

struct StudyBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw StudyBackupError.invalid }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
