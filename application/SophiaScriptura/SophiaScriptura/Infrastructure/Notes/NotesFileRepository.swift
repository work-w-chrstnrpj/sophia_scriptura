import Foundation
import CryptoKit
import PencilKit
import ImageIO

actor NotesFileRepository: NotesRepository {
    static let archiveLimit = 128 * 1024 * 1024
    enum Boundary: CaseIterable { case staged, published, fallback }
    private struct Envelope: Codable { var schemaVersion = 1; let payload: Data; let checksum: String }
    private struct Pointer: Codable { var schemaVersion = 1; let id: UUID }
    let directory: URL
    private let interrupt: (@Sendable (Boundary) throws -> Void)?
    init(directory: URL, interrupt: (@Sendable (Boundary) throws -> Void)? = nil) {
        self.directory = directory; self.interrupt = interrupt
    }
    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString: value) {
            return base.appendingPathComponent("Notes-test-" + id.uuidString)
        }
        #endif
        return base.appendingPathComponent("Notes-v1")
    }
    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func read(_ url: URL, limit: Int = NotesFileRepository.archiveLimit) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true, let size = values.fileSize, size <= limit else { throw NotesError.limit }
        return try Data(contentsOf: url)
    }
    private func validate(_ snapshot: NotesSnapshot) throws {
        var copy = snapshot
        copy.sanitize()
        try copy.validate()
        var bytes = 0
        func validateInk(_ data: Data) throws {
            if data.isEmpty { return }
            let drawing = try PKDrawing(data: data)
            guard drawing.strokes.count <= 10_000 else { throw NotesError.limit }
            if !drawing.strokes.isEmpty {
                let bounds = drawing.bounds
                guard [bounds.minX, bounds.minY, bounds.width, bounds.height].allSatisfy(\.isFinite),
                      bounds.width <= NoteDocument.extent * 2, bounds.height <= NoteDocument.extent * 2 else { throw NotesError.invalid }
            }
        }
        for note in snapshot.notes {
            if let page = note.page { bytes += page.ink.count; try validateInk(page.ink) }
            guard bytes <= Self.archiveLimit / 3 else { throw NotesError.limit }
            for object in note.allObjects {
                bytes += object.payload.count
                guard bytes <= Self.archiveLimit / 3 else { throw NotesError.limit }
                if object.kind == .ink {
                    try validateInk(object.payload)
                }
                if object.kind == .image || (object.kind == .link && !object.payload.isEmpty) {
                    guard let source = CGImageSourceCreateWithData(object.payload as CFData, nil),
                          let info = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                          let width = info[kCGImagePropertyPixelWidth] as? Int,
                          let height = info[kCGImagePropertyPixelHeight] as? Int,
                          (1...4096).contains(width), (1...4096).contains(height),
                          CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else { throw NotesError.invalid }
                }
            }
        }
    }
    private func encode(_ snapshot: NotesSnapshot) throws -> Data {
        try validate(snapshot)
        let payload = try JSONEncoder().encode(snapshot)
        let data = try JSONEncoder().encode(Envelope(payload: payload, checksum: digest(payload)))
        guard data.count <= Self.archiveLimit else { throw NotesError.limit }
        return data
    }
    private func decode(_ data: Data) throws -> NotesSnapshot {
        guard data.count <= Self.archiveLimit else { throw NotesError.limit }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.schemaVersion == 1 else { throw NotesError.unsupported }
        guard digest(envelope.payload) == envelope.checksum else { throw NotesError.invalid }
        var snapshot = try JSONDecoder().decode(NotesSnapshot.self, from: envelope.payload)
        snapshot.sanitize()
        try validate(snapshot)
        return snapshot
    }
    private func pointer(_ name: String) throws -> Pointer {
        let value = try JSONDecoder().decode(Pointer.self, from: read(directory.appendingPathComponent(name), limit: 4096))
        guard value.schemaVersion == 1 else { throw NotesError.unsupported }
        return value
    }
    private func url(_ pointer: Pointer) -> URL { directory.appendingPathComponent(pointer.id.uuidString + ".notes") }
    private func resolved() throws -> (NotesSnapshot, Pointer?, Bool) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.appendingPathComponent("current.json").path),
           !fm.fileExists(atPath: directory.appendingPathComponent("previous.json").path) { return (NotesSnapshot(), nil, false) }
        do {
            let p = try pointer("current.json")
            return (try decode(read(url(p))), p, false)
        } catch NotesError.unsupported { throw NotesError.unsupported }
        catch {
            do {
                let p = try pointer("previous.json")
                return (try decode(read(url(p))), p, true)
            } catch NotesError.unsupported { throw NotesError.unsupported }
            catch { throw NotesError.damaged }
        }
    }
    func load() throws -> NotesLoad {
        let (snapshot, _, recovered) = try resolved()
        return NotesLoad(snapshot: snapshot, recovered: recovered)
    }
    func save(_ snapshot: NotesSnapshot, expectedRevision: Int) throws -> NotesSnapshot {
        let (old, previous, recovered) = try resolved()
        guard old.revision == expectedRevision else { throw NotesError.stale }
        return try commit(snapshot, revision: old.revision + 1, previous: previous, recovered: recovered)
    }
    private func commit(_ snapshot: NotesSnapshot, revision: Int, previous: Pointer?, recovered: Bool) throws -> NotesSnapshot {
        var next = snapshot; next.revision = revision; next.schemaVersion = 3
        let data = try encode(next), fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if let previous, try decode(read(url(previous))).schemaVersion < 3 {
            let backup = directory.appendingPathComponent("before-note-types.notes")
            if !fm.fileExists(atPath: backup.path) { try read(url(previous)).write(to: backup, options: .atomic) }
        }
        if recovered {
            try Data().write(to: directory.appendingPathComponent("preserve-damaged"), options: .atomic)
            if let raw = try? read(directory.appendingPathComponent("current.json")) {
                try raw.write(to: directory.appendingPathComponent("damaged-" + UUID().uuidString + ".json"), options: .atomic)
            }
        }
        let p = Pointer(id: UUID())
        try data.write(to: url(p), options: .atomic)
        try interrupt?(.staged)
        _ = try decode(read(url(p)))
        try interrupt?(.published)
        if let previous { try JSONEncoder().encode(previous).write(to: directory.appendingPathComponent("previous.json"), options: .atomic) }
        try interrupt?(.fallback)
        try JSONEncoder().encode(p).write(to: directory.appendingPathComponent("current.json"), options: .atomic)
        cleanup(current: p)
        return next
    }
    private func cleanup(current: Pointer) {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: directory.appendingPathComponent("preserve-damaged").path) else { return }
        let retained = Set([current.id, (try? pointer("previous.json"))?.id, (try? pointer("pre-restore.json"))?.id].compactMap { $0 })
        for file in (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            guard file.pathExtension == "notes", let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent), !retained.contains(id) else { continue }
            try? fm.removeItem(at: file)
        }
    }
    func exportArchive() throws -> Data {
        var value = try resolved().0; value.schemaVersion = 3
        return try encode(value)
    }
    func preRestoreArchive() throws -> Data { try read(url(pointer("pre-restore.json"))) }
    func resetStorage() async throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: directory.path) {
            try fm.removeItem(at: directory)
        }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func restore(_ data: Data, expectedRevision: Int) throws -> NotesSnapshot {
        let imported = try decode(data)
        do {
            let (old, previous, recovered) = try resolved()
            guard old.revision == expectedRevision else { throw NotesError.stale }
            if let previous { try JSONEncoder().encode(previous).write(to: directory.appendingPathComponent("pre-restore.json"), options: .atomic) }
            return try commit(imported, revision: old.revision + 1, previous: previous, recovered: recovered)
        } catch NotesError.damaged {
            // Explicit validated restore only; retain the damaged store in place.
            return try commit(imported, revision: expectedRevision + 1, previous: nil, recovered: true)
        }
    }
}
