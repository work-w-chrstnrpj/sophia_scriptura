import Foundation
import CryptoKit

struct StudyBackupRevision: Codable, Equatable, Sendable {
    var feature: String
    var schemaVersion: Int
    var revision: Int?
    var payloadHash: String
}
struct PlanRecoveryRecord: Codable, Equatable, Sendable {
    var operationID: UUID
    var planID: UUID?
    var targetIDs: [UUID]
    var access: StudyAccessRequirements
}
struct StudyRestoreCheckpoint: Codable, Sendable {
    var schemaVersion = 1
    var id = UUID()
    var importedHash: String
    var completedPhases: [String] = []
    var phaseHashes: [String: String] = [:]
    var complete = false
}

/// Local immutable inputs and phase markers. Never included in study exports.
struct StudyRestoreJournal {
    let directory: URL
    static func root() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString: raw) {
            return base.appendingPathComponent("StudyRecovery-test-" + id.uuidString)
        }
        #endif
        return base.appendingPathComponent("StudyRecovery")
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    init(input: Data, previous: Data) throws {
        let root = Self.root()
        directory = root.appendingPathComponent(Self.digest(input))
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        for (name, data) in [("input.json", input), ("previous.json", previous)] {
            let url = directory.appendingPathComponent(name)
            if !fm.fileExists(atPath: url.path) { try data.write(to: url, options: [.atomic, .completeFileProtection]) }
        }
        if !fm.fileExists(atPath: directory.appendingPathComponent("checkpoint.json").path) {
            try write(.init(importedHash: Self.digest(input)))
        }
    }
    func load() throws -> StudyRestoreCheckpoint {
        let url = directory.appendingPathComponent("checkpoint.json")
        guard try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey]).isSymbolicLink != true else { throw StudyBackupError.invalid }
        let data = try Data(contentsOf: url)
        guard data.count <= 64 * 1024 else { throw StudyBackupError.invalid }
        let value = try JSONDecoder().decode(StudyRestoreCheckpoint.self, from: data)
        guard value.schemaVersion == 1 else { throw StudyBackupError.unsupported }
        return value
    }
    func write(_ value: StudyRestoreCheckpoint) throws {
        try JSONEncoder().encode(value).write(to: directory.appendingPathComponent("checkpoint.json"), options: [.atomic, .completeFileProtection])
    }
    func completed(_ feature: String, hash: String) throws {
        var value = try load()
        if !value.completedPhases.contains(feature) { value.completedPhases.append(feature) }
        value.phaseHashes[feature] = hash; try write(value)
    }
    static func pending() -> [URL] {
        let fm = FileManager.default
        return ((try? fm.contentsOfDirectory(at: root(), includingPropertiesForKeys: [.isSymbolicLinkKey])) ?? []).filter { folder in
            guard folder.lastPathComponent.count == 64, (try? folder.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == false else { return false }
            let journal = StudyRestoreJournal(directory: folder)
            return (try? journal.load().complete) != true
        }
    }
    private init(directory: URL) { self.directory = directory }
    static func resolve(directory: URL) throws {
        guard directory.deletingLastPathComponent().standardizedFileURL == root().standardizedFileURL else { throw StudyBackupError.invalid }
        let journal = StudyRestoreJournal(directory: directory)
        if (try? journal.load()) == nil {
            let damaged = directory.appendingPathComponent("checkpoint.json")
            if let bytes = try? Data(contentsOf: damaged) {
                try bytes.write(to: directory.appendingPathComponent("damaged-" + UUID().uuidString + ".json"), options: .atomic)
            }
            var complete = StudyRestoreCheckpoint(importedHash: directory.lastPathComponent); complete.complete = true
            try journal.write(complete)
        } else { try journal.finish() }
    }
    static func recoveryData(directory: URL, previous: Bool) throws -> Data {
        guard directory.deletingLastPathComponent().standardizedFileURL == root().standardizedFileURL,
              directory.lastPathComponent.count == 64 else { throw StudyBackupError.invalid }
        let url = directory.appendingPathComponent(previous ? "previous.json" : "input.json")
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
        guard values.isSymbolicLink != true, let size = values.fileSize, size <= 384 * 1024 * 1024 else { throw StudyBackupError.invalid }
        return try Data(contentsOf: url)
    }
    static func semanticHash<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        var object = try JSONSerialization.jsonObject(with: encoder.encode(value))
        if var fields = object as? [String: Any] {
            fields.removeValue(forKey: "revision"); fields.removeValue(forKey: "commandReceipts")
            object = fields
        }
        return digest(try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]))
    }
    func prepare(_ feature: String, targetHash: String) throws {
        var value = try load()
        if value.phaseHashes[feature] == nil { value.phaseHashes[feature] = targetHash; try write(value) }
    }
    func finish() throws { var value = try load(); value.complete = true; try write(value) }
}
