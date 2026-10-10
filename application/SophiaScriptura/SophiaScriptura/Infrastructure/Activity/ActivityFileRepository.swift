import Foundation
import CryptoKit

actor ActivityFileRepository {
    private struct Envelope: Codable {
        var schemaVersion = 1
        var payload: Data
        var checksum: String
    }

    let directory: URL
    private var recovered = false

    init(directory: URL = ActivityFileRepository.defaultDirectory()) { self.directory = directory }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString: value) {
            return base.appendingPathComponent("Activity-test-" + id.uuidString)
        }
        #endif
        return base.appendingPathComponent("Activity-v1")
    }

    func didRecoverOlderGeneration() -> Bool { recovered }

    func load() throws -> ActivitySnapshot {
        let current = directory.appendingPathComponent("current.json")
        let previous = directory.appendingPathComponent("previous.json")
        if !FileManager.default.fileExists(atPath: current.path) {
            if FileManager.default.fileExists(atPath: previous.path) {
                let snapshot = try decode(previous)
                recovered = true
                return snapshot
            }
            return ActivitySnapshot()
        }
        do { recovered = false; return try decode(current) }
        catch {
            guard FileManager.default.fileExists(atPath: previous.path) else { throw error }
            let snapshot = try decode(previous)
            recovered = true
            return snapshot
        }
    }

    func save(_ snapshot: ActivitySnapshot) throws {
        var snapshot = snapshot
        try validate(snapshot)
        snapshot.migrateBuiltInModes()
        try validate(snapshot)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = try JSONEncoder().encode(snapshot)
        let envelope = Envelope(payload: payload, checksum: digest(payload))
        let current = directory.appendingPathComponent("current.json")
        let previous = directory.appendingPathComponent("previous.json")
        if recovered, FileManager.default.fileExists(atPath: current.path) {
            let damaged = directory.appendingPathComponent("damaged-" + UUID().uuidString + ".json")
            try FileManager.default.moveItem(at: current, to: damaged)
            recovered = false
        } else if FileManager.default.fileExists(atPath: current.path) {
            try? FileManager.default.removeItem(at: previous)
            try FileManager.default.copyItem(at: current, to: previous)
        }
        try JSONEncoder().encode(envelope).write(to: current, options: .atomic)
        recovered = false
    }

    func exportArchive() throws -> Data {
        let snapshot = try load()
        let payload = try JSONEncoder().encode(snapshot)
        return try JSONEncoder().encode(Envelope(payload: payload, checksum: digest(payload)))
    }

    func restoreArchive(_ data: Data) throws -> ActivitySnapshot {
        guard data.count <= 8 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.schemaVersion == 1, envelope.checksum == digest(envelope.payload) else { throw CocoaError(.coderInvalidValue) }
        var snapshot = try JSONDecoder().decode(ActivitySnapshot.self, from: envelope.payload)
        try validate(snapshot)
        snapshot.migrateBuiltInModes()
        try validate(snapshot)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let old = try? exportArchive() {
            try old.write(to: directory.appendingPathComponent("pre-restore.json"), options: .atomic)
        }
        try save(snapshot)
        return snapshot
    }

    private func decode(_ url: URL) throws -> ActivitySnapshot {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard (attributes[.size] as? Int ?? 0) <= 8 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url))
        guard envelope.schemaVersion == 1, envelope.checksum == digest(envelope.payload) else { throw CocoaError(.coderInvalidValue) }
        var snapshot = try JSONDecoder().decode(ActivitySnapshot.self, from: envelope.payload)
        try validate(snapshot)
        snapshot.migrateBuiltInModes()
        try validate(snapshot)
        return snapshot
    }

    private func validate(_ snapshot: ActivitySnapshot) throws {
        guard snapshot.schemaVersion == 1, (1...1440).contains(snapshot.dailyGoalMinutes),
              snapshot.records.count <= 100_000, snapshot.customModes.count <= 1_000,
              (snapshot.reminders?.count ?? 0) <= 100,
              Set(snapshot.records.map(\.id)).count == snapshot.records.count else { throw CocoaError(.coderInvalidValue) }
        if let goals = snapshot.dailyGoalMinutesByMode {
            let activeModeIDs = Set(ActivityModeID.allCases.map(\.id) + ["reviewing"]
                + snapshot.customModes.filter { !$0.archived }.map(\.id))
            guard goals.count <= 1_006, goals.allSatisfy({ !$0.key.isEmpty && (0...1440).contains($0.value) }),
                  goals.keys.allSatisfy({ activeModeIDs.contains($0) }),
                  (1...1440).contains(goals.values.reduce(0, +)),
                  goals.values.reduce(0, +) == snapshot.dailyGoalMinutes else { throw CocoaError(.coderInvalidValue) }
        }
        guard Set((snapshot.reminders ?? []).map(\.id)).count == (snapshot.reminders?.count ?? 0),
              (snapshot.reminders ?? []).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && !$0.modeID.isEmpty && !$0.modeLabel.isEmpty }) else { throw CocoaError(.coderInvalidValue) }
        for record in snapshot.records {
            guard !record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !record.modeID.isEmpty, !record.modeLabel.isEmpty,
                  record.activeSeconds.isFinite, record.activeSeconds > 0,
                  record.activeSeconds <= 366 * 24 * 3600,
                  record.intervals.allSatisfy({ $0.start <= $0.end }) else { throw CocoaError(.coderInvalidValue) }
        }
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
