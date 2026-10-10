import Foundation
import CryptoKit

actor SophyFileRepository {
    struct LoadResult<Value: Codable & Sendable>: Sendable {
        var value: Value
        var recovered: Bool
        var mutationsDisabled: Bool
    }

    private struct Envelope: Codable {
        var schemaVersion = 1
        var payload: Data
        var checksum: String
    }

    let directory: URL
    private var historyDisabled = false
    private var journalDisabled = false

    init(directory: URL) { self.directory = directory }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString: value) {
            return base.appendingPathComponent("Sophy-test-" + id.uuidString, isDirectory: true)
        }
        #endif
        return base.appendingPathComponent("Sophy-v1", isDirectory: true)
    }

    func loadHistory() throws -> LoadResult<[SophyHistoryEntry]> {
        try load([SophyHistoryEntry].self, folder: "history", disabled: &historyDisabled, empty: [])
    }

    func saveHistory(_ entries: [SophyHistoryEntry]) throws {
        try Self.validateHistory(entries)
        try save(entries, folder: "history", disabled: historyDisabled)
    }

    func appendSummary(_ entry: SophyHistoryEntry) throws -> [SophyHistoryEntry] {
        let loaded = try loadHistory()
        guard !loaded.mutationsDisabled else { throw SophySafeError.writeFailed }
        var entries = loaded.value
        entries.append(entry)
        try saveHistory(entries)
        return entries
    }

    func loadJournal() throws -> LoadResult<[SophyJournalEntry]> {
        try load([SophyJournalEntry].self, folder: "journal", disabled: &journalDisabled, empty: [])
    }

    func saveJournal(_ entries: [SophyJournalEntry]) throws {
        try validateJournal(entries)
        try save(entries, folder: "journal", disabled: journalDisabled)
    }

    func deleteAll() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        historyDisabled = false
        journalDisabled = false
    }

    private func load<Value: Codable>(
        _ type: Value.Type,
        folder: String,
        disabled: inout Bool,
        empty: Value
    ) throws -> LoadResult<Value> {
        let base = directory.appendingPathComponent(folder, isDirectory: true)
        let current = base.appendingPathComponent("current.json")
        let previous = base.appendingPathComponent("previous.json")
        if !FileManager.default.fileExists(atPath: current.path), !FileManager.default.fileExists(atPath: previous.path) {
            disabled = false
            return LoadResult(value: empty, recovered: false, mutationsDisabled: false)
        }
        if let value = try? decode(type, url: current) {
            disabled = false
            return LoadResult(value: value, recovered: false, mutationsDisabled: false)
        }
        if let value = try? decode(type, url: previous) {
            disabled = false
            return LoadResult(value: value, recovered: true, mutationsDisabled: false)
        }
        let damaged = base.appendingPathComponent("damaged-" + UUID().uuidString + ".json")
        try? FileManager.default.copyItem(at: current, to: damaged)
        disabled = true
        return LoadResult(value: empty, recovered: false, mutationsDisabled: true)
    }

    private func save<Value: Codable>(_ value: Value, folder: String, disabled: Bool) throws {
        if disabled { throw SophySafeError.writeFailed }
        let base = directory.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let payload = try JSONEncoder().encode(value)
        guard payload.count <= 8 * 1024 * 1024 else { throw SophySafeError.writeFailed }
        let envelope = Envelope(payload: payload, checksum: digest(payload))
        let current = base.appendingPathComponent("current.json")
        let previous = base.appendingPathComponent("previous.json")
        if FileManager.default.fileExists(atPath: current.path) {
            if (try? decode(Value.self, url: current)) != nil {
                // Preserve the last validated generation, even if a later atomic write fails.
                try Data(contentsOf: current).write(to: previous, options: .atomic)
            } else {
                guard (try? decode(Value.self, url: previous)) != nil else { throw SophySafeError.writeFailed }
                let damaged = base.appendingPathComponent("damaged-" + UUID().uuidString + ".json")
                try FileManager.default.copyItem(at: current, to: damaged)
            }
        }
        let encoded = try JSONEncoder().encode(envelope)
        guard encoded.count <= 8 * 1024 * 1024 else { throw SophySafeError.writeFailed }
        try encoded.write(to: current, options: .atomic)
    }

    private func decode<Value: Codable>(_ type: Value.Type, url: URL) throws -> Value {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? Int ?? .max) <= 8 * 1024 * 1024 else { throw SophySafeError.writeFailed }
        let raw = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(Envelope.self, from: raw)
        guard envelope.schemaVersion == 1, envelope.checksum == digest(envelope.payload), envelope.payload.count <= 8 * 1024 * 1024 else {
            throw SophySafeError.writeFailed
        }
        let value = try JSONDecoder().decode(Value.self, from: envelope.payload)
        if let history = value as? [SophyHistoryEntry] { try Self.validateHistory(history) }
        if let journal = value as? [SophyJournalEntry] { try validateJournal(journal) }
        return value
    }

    nonisolated static func validateHistory(_ entries: [SophyHistoryEntry]) throws {
        guard Set(entries.map(\.id)).count == entries.count else { throw SophySafeError.writeFailed }
        let statuses: Set<String> = ["committed", "rejected", "uncertain", "saved", "notScheduled"]
        let types: Set<String> = ["createFolders", "createReminder", "createActivity", "lookup", "insights", "enhance", "music", "openQuiz", "openContemplation", "openChat"]
        guard entries.allSatisfy({ types.contains($0.actionType) && statuses.contains($0.status) && $0.resultCount == $0.resultIDs.count && $0.resultCount <= 120 && Set($0.resultIDs).count == $0.resultIDs.count && $0.createdAt.timeIntervalSince1970.isFinite }) else {
            throw SophySafeError.writeFailed
        }
    }

    private func validateJournal(_ entries: [SophyJournalEntry]) throws {
        guard Set(entries.map(\.id)).count == entries.count else { throw SophySafeError.writeFailed }
        let types: Set<String> = ["createFolders", "createReminder", "createActivity"]
        guard entries.allSatisfy({ types.contains($0.actionType) && $0.resultIDs.count <= 120 }) else { throw SophySafeError.writeFailed }
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
