import Foundation
import CryptoKit

protocol CollectionsRepository: Sendable {
    func load() async throws -> CollectionsLoad
    func save(_ snapshot: CollectionsSnapshot, expectedRevision: Int) async throws -> CollectionsSnapshot
}

struct CollectionsLoad: Sendable {
    var snapshot: CollectionsSnapshot
    var recovered: Bool
}

enum CollectionsError: Error, LocalizedError {
    case stale
    case invalid
    case damaged
    case unsupported

    var errorDescription: String? {
        switch self {
        case .stale: return "Collections changed before this save completed."
        case .invalid: return "Collections data is not valid."
        case .damaged: return "Collections data is damaged. The previous revision was kept."
        case .unsupported: return "This Collections file is from a newer Sophia."
        }
    }
}

actor CollectionsFileRepository: CollectionsRepository {
    struct Envelope: Codable { var schemaVersion = 1; let payload: Data; let checksum: String }
    struct Pointer: Codable { var schemaVersion = 1; let id: UUID }
    let directory: URL
    init(directory: URL) { self.directory = directory }

    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString: value) {
            return base.appendingPathComponent("Collections-test-" + id.uuidString)
        }
        #endif
        return base.appendingPathComponent("Collections-v1")
    }

    func load() async throws -> CollectionsLoad {
        let (snapshot, _, recovered) = try resolved()
        return CollectionsLoad(snapshot: snapshot, recovered: recovered)
    }

    func save(_ snapshot: CollectionsSnapshot, expectedRevision: Int) async throws -> CollectionsSnapshot {
        let (current, currentPointer, recovered) = try resolved()
        guard current.revision == expectedRevision else { throw CollectionsError.stale }
        var next = snapshot
        next.revision = current.revision + 1
        next.schemaVersion = 1
        try commit(next, previous: currentPointer, recovered: recovered)
        return next
    }

    private func resolved() throws -> (CollectionsSnapshot, Pointer?, Bool) {
        let fm = FileManager.default
        let currentURL = directory.appendingPathComponent("current.json")
        let previousURL = directory.appendingPathComponent("previous.json")
        if !fm.fileExists(atPath: currentURL.path), !fm.fileExists(atPath: previousURL.path) {
            return (CollectionsSnapshot(), nil, false)
        }
        do {
            let pointer = try pointer("current.json")
            return (try decode(read(url(pointer))), pointer, false)
        } catch CollectionsError.unsupported {
            throw CollectionsError.unsupported
        } catch {
            do {
                let pointer = try pointer("previous.json")
                return (try decode(read(url(pointer))), pointer, true)
            } catch CollectionsError.unsupported {
                throw CollectionsError.unsupported
            } catch {
                throw CollectionsError.damaged
            }
        }
    }

    private func commit(_ snapshot: CollectionsSnapshot, previous: Pointer?, recovered: Bool) throws {
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

    private func encode(_ snapshot: CollectionsSnapshot) throws -> Data {
        guard snapshot.schemaVersion == 1 else { throw CollectionsError.unsupported }
        let payload = try JSONEncoder().encode(snapshot)
        let data = try JSONEncoder().encode(Envelope(payload: payload, checksum: digest(payload)))
        return data
    }

    private func decode(_ data: Data) throws -> CollectionsSnapshot {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.schemaVersion == 1 else { throw CollectionsError.unsupported }
        guard digest(envelope.payload) == envelope.checksum else { throw CollectionsError.invalid }
        let snapshot = try JSONDecoder().decode(CollectionsSnapshot.self, from: envelope.payload)
        guard snapshot.schemaVersion == 1 else { throw CollectionsError.unsupported }
        return snapshot
    }

    private func pointer(_ name: String) throws -> Pointer {
        let value = try JSONDecoder().decode(Pointer.self, from: read(directory.appendingPathComponent(name), limit: 4096))
        guard value.schemaVersion == 1 else { throw CollectionsError.unsupported }
        return value
    }

    private func url(_ pointer: Pointer) -> URL {
        directory.appendingPathComponent(pointer.id.uuidString + ".collections")
    }

    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func read(_ url: URL, limit: Int = 8 * 1024 * 1024) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true, let size = values.fileSize, size <= limit else { throw CollectionsError.invalid }
        return try Data(contentsOf: url)
    }
}
