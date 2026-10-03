import Foundation
import CryptoKit

actor CompanionFileRepository: CompanionRepository {
    struct Envelope: Codable { var schemaVersion = 1; let payload: Data; let checksum: String }
    struct Pointer: Codable { var schemaVersion = 1; let id: UUID }
    let directory: URL

    init(directory: URL) { self.directory = directory }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString: value) {
            return base.appendingPathComponent("Companion-test-" + id.uuidString)
        }
        #endif
        return base.appendingPathComponent("Companion-v1")
    }

    func load() async throws -> CompanionLoad {
        let (snapshot, _, recovered) = try resolved()
        return CompanionLoad(snapshot: snapshot, recovered: recovered)
    }

    func save(_ snapshot: CompanionSnapshot, expectedRevision: Int) async throws -> CompanionSnapshot {
        let (current, currentPointer, recovered) = try resolved()
        guard current.revision == expectedRevision else { throw CompanionPersistenceError.stale }
        var next = snapshot
        next.revision = current.revision + 1
        next.schemaVersion = 3
        try commit(next, previous: currentPointer, recovered: recovered)
        return next
    }

    private func resolved() throws -> (CompanionSnapshot, Pointer?, Bool) {
        let fm = FileManager.default
        let currentURL = directory.appendingPathComponent("current.json")
        let previousURL = directory.appendingPathComponent("previous.json")
        if !fm.fileExists(atPath: currentURL.path), !fm.fileExists(atPath: previousURL.path) {
            return (CompanionSnapshot(), nil, false)
        }
        do {
            let pointer = try pointer("current.json")
            return (try decode(read(url(pointer))), pointer, false)
        } catch CompanionPersistenceError.unsupported {
            throw CompanionPersistenceError.unsupported
        } catch {
            do {
                let pointer = try pointer("previous.json")
                return (try decode(read(url(pointer))), pointer, true)
            } catch CompanionPersistenceError.unsupported {
                throw CompanionPersistenceError.unsupported
            } catch {
                throw CompanionPersistenceError.damaged
            }
        }
    }

    private func commit(_ snapshot: CompanionSnapshot, previous: Pointer?, recovered: Bool) throws {
        let data = try encode(snapshot)
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if recovered {
            try Data().write(to: directory.appendingPathComponent("preserve-damaged"), options: .atomic)
            if let raw = try? read(directory.appendingPathComponent("current.json")) {
                try raw.write(to: directory.appendingPathComponent("damaged-" + UUID().uuidString + ".json"), options: .atomic)
            }
        }
        let pointer = Pointer(id: UUID())
        try data.write(to: url(pointer), options: .atomic)
        if let previous {
            try JSONEncoder().encode(previous).write(to: directory.appendingPathComponent("previous.json"), options: .atomic)
        }
        try JSONEncoder().encode(pointer).write(to: directory.appendingPathComponent("current.json"), options: .atomic)
    }

    private func encode(_ snapshot: CompanionSnapshot) throws -> Data {
        guard (1...3).contains(snapshot.schemaVersion) else { throw CompanionPersistenceError.unsupported }
        var normalized = snapshot
        normalized.schemaVersion = 3
        let payload = try JSONEncoder().encode(normalized)
        return try JSONEncoder().encode(Envelope(payload: payload, checksum: digest(payload)))
    }

    private func decode(_ data: Data) throws -> CompanionSnapshot {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.schemaVersion == 1 else { throw CompanionPersistenceError.unsupported }
        guard digest(envelope.payload) == envelope.checksum else { throw CompanionPersistenceError.invalid }
        let snapshot = try JSONDecoder().decode(CompanionSnapshot.self, from: envelope.payload)
        guard (1...3).contains(snapshot.schemaVersion) else { throw CompanionPersistenceError.unsupported }
        return snapshot
    }

    private func pointer(_ name: String) throws -> Pointer {
        let value = try JSONDecoder().decode(Pointer.self, from: read(directory.appendingPathComponent(name), limit: 4096))
        guard value.schemaVersion == 1 else { throw CompanionPersistenceError.unsupported }
        return value
    }

    private func url(_ pointer: Pointer) -> URL { directory.appendingPathComponent(pointer.id.uuidString + ".json") }

    private func read(_ url: URL, limit: Int? = nil) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        if let limit {
            return handle.readData(ofLength: limit)
        }
        return handle.readDataToEndOfFile()
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
