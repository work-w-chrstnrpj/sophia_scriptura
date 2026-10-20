import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Full-device study backup excluding user music files and Keychain provider secrets.
struct StudyFullBackupEnvelope: Codable, Sendable {
    var schemaVersion = 2
    var exportedAt: Date
    var notes: Data
    var annotations: Data
    var activity: Data
    var collections: CollectionsSnapshot
    var companion: CompanionSnapshot
    /// Visible Sophy summaries only. Absence keeps the device's current history. Never an execution journal.
    var sophyHistory: [SophyHistoryEntry]? = nil
    var revisionVector: [StudyBackupRevision]? = nil
    var planRecoveryRecords: [PlanRecoveryRecord]? = nil
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
    private static var busy = false
    static func export(
        notes: NotesSession,
        annotations: AnnotationSession,
        activity: ActivityStore,
        collections: CollectionsStore,
        companion: CompanionSession,
        sophyHistory: [SophyHistoryEntry]? = nil
    ) async throws -> Data {
        guard !busy, !companion.isSending else { throw StudyMutationFailure.busy }
        busy = true; defer { busy = false }
        try await notes.protection.authorize(notes.noteAccessRequirements(notes.snapshot.notes))
        try await collections.protection.authorize([.collections: collections.collections.map(\.protectionID)])
        await collections.flush(); await companion.writeChain?.value
        notes.flushSurface?(); await notes.save(); await annotations.save()
        guard !notes.dirty, !notes.saving, !annotations.dirty, !annotations.saving else { throw StudyMutationFailure.busy }
        collections.studyMutationBlocked = true; notes.backupLeaseHeld = true
        activity.backupLeaseHeld = true; companion.backupLeaseHeld = true
        defer {
            collections.studyMutationBlocked = false; notes.backupLeaseHeld = false
            activity.backupLeaseHeld = false; companion.backupLeaseHeld = false
        }
        let initialCollections = try collections.exportBackupSnapshot()
        let notesData = try await notes.export()
        let annotationsData = try await annotations.export()
        guard let activityData = await activity.exportArchive() else { throw StudyBackupError.invalid }
        var envelope = StudyFullBackupEnvelope(
            exportedAt: Date(),
            notes: notesData,
            annotations: annotationsData,
            activity: activityData,
            collections: try collections.exportBackupSnapshot(),
            companion: companion.backupSnapshot(),
            sophyHistory: sophyHistory
        )
        let after = try collections.exportBackupSnapshot()
        let savedNotes = try NotesFileRepository.inspectArchive(notesData)
        let savedInk = try await AnnotationFileRepository(directory: StudyRestoreJournal.root()).inspectArchive(annotationsData)
        guard initialCollections.revision == after.revision, savedNotes.revision == notes.snapshot.revision,
              savedInk.revision == annotations.snapshot.revision, !notes.dirty, !notes.saving,
              !annotations.dirty, !annotations.saving, !companion.isSending else { throw StudyMutationFailure.busy }
        envelope.planRecoveryRecords = envelope.collections.planOperations.map {
            PlanRecoveryRecord(operationID: $0.id, planID: $0.planID, targetIDs: $0.targetIDs, access: $0.access)
        }
        envelope.collections.planOperations = []; envelope.collections.commandReceipts = []
        envelope.revisionVector = try revisionVector(envelope)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try notes.requireNoteAccess(notes.snapshot.notes)
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
        guard data.count <= 384 * 1024 * 1024 else { throw StudyBackupError.invalid }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(StudyFullBackupEnvelope.self, from: data)
        guard (1...2).contains(envelope.schemaVersion) else { throw StudyBackupError.unsupported }
        guard !busy, !companion.isSending else { throw StudyMutationFailure.busy }
        busy = true; defer { busy = false }
        try envelope.collections.validatePlans()
        guard (1...3).contains(envelope.companion.schemaVersion) else { throw StudyBackupError.unsupported }
        let inspectedNotes = try NotesFileRepository.inspectArchive(envelope.notes)
        try validateRecoveryRecords(envelope.planRecoveryRecords ?? [], notes: inspectedNotes.notes, links: envelope.collections.links)
        _ = try await AnnotationFileRepository(directory: StudyRestoreJournal.root()).inspectArchive(envelope.annotations)
        _ = try await ActivityFileRepository(directory: StudyRestoreJournal.root()).inspectArchive(envelope.activity)
        if envelope.schemaVersion == 2 {
            guard let vector = envelope.revisionVector, envelope.planRecoveryRecords != nil,
                  vector == (try revisionVector(envelope)) else { throw StudyBackupError.invalid }
        }
        if let history = envelope.sophyHistory { try SophyFileRepository.validateHistory(history) }
        let previousSophyHistory: [SophyHistoryEntry]?
        if envelope.sophyHistory != nil, let sophyRepository {
            let previous = try await sophyRepository.loadHistory()
            guard !previous.mutationsDisabled else { throw StudyBackupError.invalid }
            previousSophyHistory = previous.value
        } else { previousSophyHistory = nil }
        let incomingNotes = try NotesFileRepository.inspectArchive(envelope.notes)
        var requirements = notes.noteAccessRequirements(notes.snapshot.notes + incomingNotes.notes)
        requirements[.collections, default: []] += collections.collections.map(\.protectionID) + envelope.collections.collections.map(\.protectionID)
        for plan in envelope.collections.plans {
            requirements[.collections, default: []] += plan.access.collectionsCredentialIDs.map(Optional.some)
            requirements[.notes, default: []] += plan.access.notesCredentialIDs.map(Optional.some)
        }
        try await notes.protection.authorize(requirements)
        try notes.requireNoteAccess(notes.snapshot.notes)
        try collections.protection.require(collections.collections.map(\.protectionID), in: .collections)
        _ = try NotesFileRepository.inspectArchive(envelope.notes)
        guard (1...4).contains(envelope.collections.schemaVersion) else { throw StudyBackupError.unsupported }
        // Save immutable pre-restore inputs before the first feature write. Imported intents are inert.
        if !companion.backupLeaseHeld { await companion.writeChain?.value }
        await collections.flush()
        let previous = try await captureCurrent(notes: notes, annotations: annotations, activity: activity, collections: collections, companion: companion, history: previousSophyHistory)
        collections.studyMutationBlocked = true; notes.backupLeaseHeld = true
        activity.backupLeaseHeld = true; companion.backupLeaseHeld = true
        var finished = false
        defer {
            collections.studyMutationBlocked = !finished; notes.backupLeaseHeld = !finished
            activity.backupLeaseHeld = !finished; companion.backupLeaseHeld = !finished
        }
        let journal = try StudyRestoreJournal(input: data, previous: previous)
        let checkpoint = try journal.load()
        guard checkpoint.importedHash == StudyRestoreJournal.digest(data) else { throw StudyBackupError.invalid }
        var desiredNotes = incomingNotes
        desiredNotes.planFormatActivated = desiredNotes.planFormatActivated || notes.snapshot.planFormatActivated
        for i in desiredNotes.notes.indices {
            if let old = notes.snapshot.notes.first(where: { $0.id == desiredNotes.notes[i].id }) {
                desiredNotes.notes[i].access = desiredNotes.notes[i].access.union(old.access)
                desiredNotes.notes[i].planOrigin = desiredNotes.notes[i].planOrigin ?? old.planOrigin
                desiredNotes.notes[i].protectionID = desiredNotes.notes[i].protectionID ?? old.protectionID
            }
        }
        desiredNotes.schemaVersion = desiredNotes.requiredSchemaVersion
        let noteHash = try StudyRestoreJournal.semanticHash(desiredNotes)
        try journal.prepare("notes", targetHash: noteHash)
        if try StudyRestoreJournal.semanticHash(notes.snapshot) != noteHash {
            guard await notes.restore(envelope.notes) else { throw StudyBackupError.invalid }
        }
        try journal.completed("notes", hash: try StudyRestoreJournal.semanticHash(notes.snapshot))
        let desiredInk = try await AnnotationFileRepository(directory: StudyRestoreJournal.root()).inspectArchive(envelope.annotations)
        let inkHash = try StudyRestoreJournal.semanticHash(desiredInk)
        try journal.prepare("annotations", targetHash: inkHash)
        if try StudyRestoreJournal.semanticHash(annotations.snapshot) != inkHash {
            guard await annotations.restore(envelope.annotations, document: readerDocument) else { throw StudyBackupError.invalid }
        }
        try journal.completed("annotations", hash: try StudyRestoreJournal.semanticHash(annotations.snapshot))
        let desiredActivity = try await ActivityFileRepository(directory: StudyRestoreJournal.root()).inspectArchive(envelope.activity)
        let activityHash = try StudyRestoreJournal.semanticHash(desiredActivity)
        try journal.prepare("activity", targetHash: activityHash)
        if try StudyRestoreJournal.semanticHash(activity.snapshot) != activityHash {
            guard await activity.restoreArchive(envelope.activity) else { throw StudyBackupError.invalid }
        }
        try journal.completed("activity", hash: try StudyRestoreJournal.semanticHash(activity.snapshot))
        var safeCollections = envelope.collections
        safeCollections.planOperations = []; safeCollections.commandReceipts = []
        safeCollections.preservePlanAccess(from: try collections.exportBackupSnapshot())
        for record in envelope.planRecoveryRecords ?? [] {
            if let id = record.planID, let index = safeCollections.plans.firstIndex(where: { $0.id == id }) {
                safeCollections.plans[index].access = safeCollections.plans[index].access.union(record.access)
            }
        }
        let collectionsHash = try StudyRestoreJournal.semanticHash(safeCollections)
        try journal.prepare("collections", targetHash: collectionsHash)
        if try StudyRestoreJournal.semanticHash(collections.exportBackupSnapshot()) != collectionsHash {
            guard await collections.restoreBackupSnapshot(safeCollections) else { throw StudyBackupError.invalid }
        }
        try journal.completed("collections", hash: collectionsHash)
        let companionHash = try StudyRestoreJournal.semanticHash(envelope.companion)
        try journal.prepare("companion", targetHash: companionHash)
        if try StudyRestoreJournal.semanticHash(companion.backupSnapshot()) != companionHash {
            guard await companion.restoreBackupSnapshot(envelope.companion) else { throw StudyBackupError.invalid }
        }
        try journal.completed("companion", hash: companionHash)
        if let sophyHistory = envelope.sophyHistory, let sophyRepository {
            if let previousSophyHistory, !previousSophyHistory.isEmpty {
                let archive = await sophyRepository.directory.appendingPathComponent("history-before-restore.json")
                try JSONEncoder().encode(previousSophyHistory).write(to: archive, options: .atomic)
            }
            try await sophyRepository.saveHistory(sophyHistory)
        }
        try journal.finish(); finished = true
        notes.protection.lock([.notes, .collections])
    }
    private static func captureCurrent(notes: NotesSession, annotations: AnnotationSession, activity: ActivityStore,
                                       collections: CollectionsStore, companion: CompanionSession, history: [SophyHistoryEntry]? = nil) async throws -> Data {
        guard let activityData = await activity.exportArchive() else { throw StudyBackupError.invalid }
        var envelope = StudyFullBackupEnvelope(exportedAt: Date(), notes: try await notes.export(),
            annotations: try await annotations.export(), activity: activityData,
            collections: try collections.exportBackupSnapshot(), companion: companion.backupSnapshot(), sophyHistory: history)
        envelope.planRecoveryRecords = envelope.collections.planOperations.map {
            .init(operationID: $0.id, planID: $0.planID, targetIDs: $0.targetIDs, access: $0.access)
        }
        envelope.collections.planOperations = []; envelope.collections.commandReceipts = []
        envelope.revisionVector = try revisionVector(envelope)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(envelope)
    }
    static func validateRecoveryRecords(_ records: [PlanRecoveryRecord], notes: [NoteDocument], links: [SavedLink]) throws {
        guard records.count <= 128, Set(records.map(\.operationID)).count == records.count else { throw StudyBackupError.invalid }
        for record in records {
            let access = record.access
            for note in notes where record.targetIDs.contains(note.id) || (record.planID != nil && note.planOrigin?.planID == record.planID) {
                guard note.access.union(access) == note.access else { throw StudyBackupError.invalid }
            }
            for link in links where record.targetIDs.contains(link.id) || (record.planID != nil && link.planOrigin?.planID == record.planID) {
                guard link.access.union(access) == link.access else { throw StudyBackupError.invalid }
            }
        }
    }
    static func revisionVector(_ envelope: StudyFullBackupEnvelope) throws -> [StudyBackupRevision] {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        let note = try NotesFileRepository.inspectArchive(envelope.notes)
        return [
            .init(feature: "notes", schemaVersion: note.schemaVersion, revision: note.revision, payloadHash: StudyRestoreJournal.digest(envelope.notes)),
            .init(feature: "annotations", schemaVersion: 1, revision: nil, payloadHash: StudyRestoreJournal.digest(envelope.annotations)),
            .init(feature: "activity", schemaVersion: 1, revision: nil, payloadHash: StudyRestoreJournal.digest(envelope.activity)),
            .init(feature: "collections", schemaVersion: envelope.collections.schemaVersion, revision: envelope.collections.revision,
                  payloadHash: StudyRestoreJournal.digest(try encoder.encode(envelope.collections))),
            .init(feature: "companion", schemaVersion: envelope.companion.schemaVersion, revision: envelope.companion.revision,
                  payloadHash: StudyRestoreJournal.digest(try encoder.encode(envelope.companion)))
        ]
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
