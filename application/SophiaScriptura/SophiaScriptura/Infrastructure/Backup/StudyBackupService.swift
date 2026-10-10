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
    /// Visible Sophy summaries only. Absence keeps the device's current history. Never an execution journal.
    var sophyHistory: [SophyHistoryEntry]? = nil
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
        companion: CompanionSession,
        sophyHistory: [SophyHistoryEntry]? = nil
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
            companion: companion.backupSnapshot(),
            sophyHistory: sophyHistory
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
        readerDocument: ChapterDocument?,
        sophyRepository: SophyFileRepository? = nil
    ) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(StudyFullBackupEnvelope.self, from: data)
        guard envelope.schemaVersion == 1 else { throw StudyBackupError.unsupported }
        if let history = envelope.sophyHistory { try SophyFileRepository.validateHistory(history) }
        let previousSophyHistory: [SophyHistoryEntry]?
        if envelope.sophyHistory != nil, let sophyRepository {
            let previous = try await sophyRepository.loadHistory()
            guard !previous.mutationsDisabled else { throw StudyBackupError.invalid }
            previousSophyHistory = previous.value
        } else { previousSophyHistory = nil }
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
        if let sophyHistory = envelope.sophyHistory, let sophyRepository {
            if let previousSophyHistory, !previousSophyHistory.isEmpty {
                let archive = await sophyRepository.directory.appendingPathComponent("history-before-restore.json")
                try JSONEncoder().encode(previousSophyHistory).write(to: archive, options: .atomic)
            }
            try await sophyRepository.saveHistory(sophyHistory)
        }
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
