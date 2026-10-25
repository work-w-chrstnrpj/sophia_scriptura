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
        next.preservePlanAccess(from: current)
        next.revision = current.revision + 1
        next.schemaVersion = next.requiredSchemaVersion
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
        var fallback = previous
        if snapshot.planFormatActivated {
            if let previous {
                let original = try read(url(previous))
                let backup = directory.appendingPathComponent("before-plans.collections")
                if !fm.fileExists(atPath: backup.path) { try original.write(to: backup, options: .atomic) }
                var safe = try decode(original)
                if snapshot.planLifecycleActivated && !safe.planLifecycleActivated {
                    let lifecycleBackup = directory.appendingPathComponent("before-plan-lifecycle.collections")
                    if !fm.fileExists(atPath: lifecycleBackup.path) { try original.write(to: lifecycleBackup, options: .atomic) }
                }
                safe.preservePlanAccess(from: snapshot)
                let pointer = Pointer(schemaVersion: 2, id: UUID())
                try encode(safe).write(to: url(pointer), options: .atomic)
                fallback = pointer
            } else {
                var safe = CollectionsSnapshot(); safe.planFormatActivated = true; safe.planLifecycleActivated = snapshot.planLifecycleActivated; safe.schemaVersion = safe.requiredSchemaVersion
                let pointer = Pointer(schemaVersion: 2, id: UUID())
                try encode(safe).write(to: url(pointer), options: .atomic); fallback = pointer
            }
        }
        if !snapshot.planFormatActivated, let previous {
            let oldBytes = try read(url(previous))
            var protectedFallback = try decode(oldBytes)
            let bindings = Dictionary(uniqueKeysWithValues: snapshot.collections.compactMap { folder in folder.protectionID.map { (folder.id, $0) } })
            var updated = false
            for i in protectedFallback.collections.indices {
                if let binding = bindings[protectedFallback.collections[i].id], protectedFallback.collections[i].protectionID != binding {
                    protectedFallback.collections[i].protectionID = binding; updated = true
                }
            }
            if updated {
                protectedFallback.schemaVersion = protectedFallback.requiredSchemaVersion
                let securePrevious = Pointer(id: UUID())
                try encode(protectedFallback).write(to: url(securePrevious), options: .atomic)
                fallback = securePrevious
            }
        }
        let pointer = Pointer(schemaVersion: snapshot.planFormatActivated ? 2 : 1, id: UUID())
        try data.write(to: url(pointer), options: .atomic)
        if let fallback {
            try JSONEncoder().encode(fallback).write(to: directory.appendingPathComponent("previous.json"), options: .atomic)
        }
        try JSONEncoder().encode(pointer).write(to: directory.appendingPathComponent("current.json"), options: .atomic)
    }

    private func encode(_ snapshot: CollectionsSnapshot) throws -> Data {
        guard (1...5).contains(snapshot.schemaVersion) else { throw CollectionsError.unsupported }
        try snapshot.validatePlans()
        let payload = try JSONEncoder().encode(snapshot)
        let data = try JSONEncoder().encode(Envelope(schemaVersion: snapshot.planFormatActivated ? 2 : 1, payload: payload, checksum: digest(payload)))
        guard data.count <= 8 * 1024 * 1024 else { throw CollectionsError.invalid }
        return data
    }

    private func decode(_ data: Data) throws -> CollectionsSnapshot {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard (1...2).contains(envelope.schemaVersion) else { throw CollectionsError.unsupported }
        guard digest(envelope.payload) == envelope.checksum else { throw CollectionsError.invalid }
        let snapshot = try JSONDecoder().decode(CollectionsSnapshot.self, from: envelope.payload)
        guard (1...5).contains(snapshot.schemaVersion) else { throw CollectionsError.unsupported }
        guard (snapshot.schemaVersion >= 4) == (envelope.schemaVersion == 2) else { throw CollectionsError.invalid }
        try snapshot.validatePlans()
        return snapshot
    }

    private func pointer(_ name: String) throws -> Pointer {
        let value = try JSONDecoder().decode(Pointer.self, from: read(directory.appendingPathComponent(name), limit: 4096))
        guard (1...2).contains(value.schemaVersion) else { throw CollectionsError.unsupported }
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
