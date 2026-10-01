import Foundation
import CryptoKit
import PencilKit

/// Serialized immutable-generation commits. Neither Scripture text nor credentials enter this store.
actor AnnotationFileRepository: AnnotationRepository {
    static let archiveLimit = 128 * 1024 * 1024
    static let drawingLimit = 32 * 1024 * 1024
    enum Boundary: CaseIterable { case staged, published, fallback, committed }
    let directory: URL
    private let interrupt: (@Sendable (Boundary) throws -> Void)?
    private var validPointer: Pointer?
    private var repairing = false
    private struct Pointer: Codable { var schemaVersion = 1; let generation: UUID; let revision: Int; let manifestHash: String }
    private struct Entry: Codable { let id: UUID; let count: Int; let checksum: String }
    private struct Manifest: Codable { let snapshot: AnnotationSnapshot; let entries: [Entry] }
    private struct Archive: Codable { var schemaVersion = 1; let snapshot: AnnotationSnapshot; let entries: [Entry] }
    init(directory: URL, interrupt: (@Sendable (Boundary) throws -> Void)? = nil) {
        self.directory = directory; self.interrupt = interrupt
    }
    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["SP009_TEST_STORE"], let id = UUID(uuidString: raw) {
            return base.appendingPathComponent("Annotations-test-" + id.uuidString)
        }
        #endif
        return base.appendingPathComponent("Annotations")
    }
    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func read(_ url: URL, limit: Int = AnnotationFileRepository.archiveLimit) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true, let size = values.fileSize, size <= limit else { throw AnnotationError.tooLarge }
        return try Data(contentsOf: url)
    }
    private func validate(_ value: AnnotationSnapshot) throws {
        guard value.schemaVersion == 1 else { throw AnnotationError.unsupported }
        guard value.revision >= 0, value.groups.count <= 128 else { throw AnnotationError.invalid }
        var groupIDs = Set<UUID>(), layerIDs = Set<UUID>(), total = 0
        for group in value.groups {
            guard groupIDs.insert(group.id).inserted, group.layers.count <= 256,
                  !group.source.editionID.isEmpty, !group.source.contentRevision.isEmpty,
                  !group.source.referenceSystemID.isEmpty, group.source.book.count == 3,
                  group.source.book.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
                  (1...150).contains(group.source.chapter) else { throw AnnotationError.invalid }
            for layout in [group.layout] + group.layers.compactMap(\.layout) {
            guard ["continuous-textkit1-v1", "continuous-textkit1-surround-v2"].contains(layout.algorithm), !layout.fontName.isEmpty,
                  layout.fontResourceHash.count == 64, layout.signature.count == 64,
                  [layout.fontSize, layout.width, layout.textWidth, layout.height, layout.inset,
                   layout.marginStart, layout.lineSpacing, layout.paragraphSpacing].allSatisfy({ $0.isFinite && $0 > 0 }),
                  layout.fontSize <= 100, layout.width <= 2000, layout.height <= 200_000,
                  layout.height > layout.inset * 2 else { throw AnnotationError.invalid }
            if layout.surroundingSpace {
                guard abs(layout.width - layout.textWidth - layout.inset * 2) < 0.01,
                      layout.marginStart == layout.width - layout.inset else { throw AnnotationError.invalid }
            } else {
                guard layout.textWidth + layout.inset < layout.marginStart,
                      layout.marginStart < layout.width - layout.inset else { throw AnnotationError.invalid }
            }
            }
            if let id = group.selectedLayerID {
                guard group.layers.contains(where: { $0.id == id && $0.deletedAt == nil }) else { throw AnnotationError.invalid }
            }
            for layer in group.layers {
                guard layerIDs.insert(layer.id).inserted, !layer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      layer.name.count <= 80, layer.revision >= 0 else { throw AnnotationError.invalid }
                if let appearance = layer.appearance {
                    guard ReaderPreferences.typefaces.contains(appearance.typeface), (0...8).contains(appearance.sizeStep),
                          appearance.presetID.map({ ScriptureAppearance(rawValue: $0) != nil }) ?? true else { throw AnnotationError.invalid }
                }
                guard layer.drawing.count <= Self.drawingLimit else { throw AnnotationError.tooLarge }
                total += layer.drawing.count
                guard total <= Self.archiveLimit / 2 else { throw AnnotationError.tooLarge }
                _ = try PKDrawing(data: layer.drawing)
            }
        }
    }
    private func entries(_ snapshot: AnnotationSnapshot) -> [Entry] {
        snapshot.groups.flatMap(\.layers).map { Entry(id: $0.id, count: $0.drawing.count, checksum: Self.digest($0.drawing)) }
    }
    private func check(_ snapshot: AnnotationSnapshot, entries: [Entry]) throws {
        guard snapshot.groups.count <= 128, snapshot.groups.allSatisfy({ $0.layers.count <= 256 }) else { throw AnnotationError.invalid }
        let layers = snapshot.groups.flatMap(\.layers)
        guard entries.count == layers.count, Set(entries.map(\.id)).count == entries.count else { throw AnnotationError.invalid }
        let index = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for layer in layers {
            guard let entry = index[layer.id], entry.count == layer.drawing.count,
                  entry.checksum == Self.digest(layer.drawing) else { throw AnnotationError.invalid }
        }
        try validate(snapshot)
    }
    private func decodePointer(_ name: String) throws -> Pointer {
        let pointer = try JSONDecoder().decode(Pointer.self, from: read(directory.appendingPathComponent(name), limit: 4096))
        guard pointer.schemaVersion == 1 else { throw AnnotationError.unsupported }
        return pointer
    }
    private func generation(_ pointer: Pointer) throws -> AnnotationSnapshot {
        let folder = directory.appendingPathComponent(pointer.generation.uuidString)
        guard try folder.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw AnnotationError.invalid }
        let bytes = try read(folder.appendingPathComponent("manifest.json"))
        guard Self.digest(bytes) == pointer.manifestHash else { throw AnnotationError.invalid }
        let manifest = try JSONDecoder().decode(Manifest.self, from: bytes)
        var snapshot = manifest.snapshot
        guard snapshot.schemaVersion == 1 else { throw AnnotationError.unsupported }
        guard snapshot.revision == pointer.revision, snapshot.groups.count <= 128, snapshot.groups.allSatisfy({ $0.layers.count <= 256 }),
              manifest.entries.count <= 128 * 256 else { throw AnnotationError.invalid }
        for g in snapshot.groups.indices {
            for l in snapshot.groups[g].layers.indices {
                let id = snapshot.groups[g].layers[l].id
                snapshot.groups[g].layers[l].drawing = try read(folder.appendingPathComponent(id.uuidString + ".drawing"), limit: Self.drawingLimit)
            }
        }
        try check(snapshot, entries: manifest.entries)
        return snapshot
    }
    func load() throws -> AnnotationLoad {
        let root = directory.appendingPathComponent("current.json")
        if !FileManager.default.fileExists(atPath: root.path), !FileManager.default.fileExists(atPath: directory.appendingPathComponent("previous.json").path) {
            validPointer = nil
            return AnnotationLoad(snapshot: AnnotationSnapshot(), recovered: false)
        }
        do {
            let pointer = try decodePointer("current.json")
            let snapshot = try generation(pointer)
            validPointer = pointer
            return AnnotationLoad(snapshot: snapshot, recovered: false)
        } catch AnnotationError.unsupported { throw AnnotationError.unsupported }
        catch {
            do {
                let pointer = try decodePointer("previous.json")
                let snapshot = try generation(pointer)
                validPointer = pointer
                // Keep damaged generations and manifests even after a successful recovery save.
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if let bytes = try? read(root) {
                    try bytes.write(to: directory.appendingPathComponent("damaged-" + UUID().uuidString + ".json"), options: .atomic)
                }
                try Data().write(to: directory.appendingPathComponent("recovery-retention"), options: .atomic)
                return AnnotationLoad(snapshot: snapshot, recovered: true)
            } catch { throw AnnotationError.damaged }
        }
    }
    func save(_ snapshot: AnnotationSnapshot, expectedRevision: Int) throws -> AnnotationSnapshot {
        if !repairing { _ = try load() }
        guard (validPointer?.revision ?? 0) == expectedRevision else { throw AnnotationError.stale }
        var next = snapshot; next.revision = expectedRevision + 1
        try validate(next)
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID(), staging = directory.appendingPathComponent("staging-" + UUID().uuidString)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        var metadata = next
        for g in next.groups.indices {
            for l in next.groups[g].layers.indices {
                let layer = next.groups[g].layers[l]
                try layer.drawing.write(to: staging.appendingPathComponent(layer.id.uuidString + ".drawing"), options: .atomic)
                metadata.groups[g].layers[l].drawing = Data()
            }
        }
        let manifest = Manifest(snapshot: metadata, entries: entries(next))
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
        try interrupt?(.staged)
        try fm.moveItem(at: staging, to: directory.appendingPathComponent(id.uuidString))
        let pointer = Pointer(generation: id, revision: next.revision, manifestHash: Self.digest(manifestData))
        _ = try generation(pointer)
        try interrupt?(.published)
        if let previous = validPointer {
            try JSONEncoder().encode(previous).write(to: directory.appendingPathComponent("previous.json"), options: .atomic)
        }
        try interrupt?(.fallback)
        try JSONEncoder().encode(pointer).write(to: directory.appendingPathComponent("current.json"), options: .atomic)
        validPointer = pointer
        try interrupt?(.committed)
        cleanup()
        return next
    }
    private func cleanup() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: directory.appendingPathComponent("recovery-retention").path),
              let current = try? decodePointer("current.json"), (try? generation(current)) != nil else { return }
        let pinned = Set([current.generation, (try? decodePointer("previous.json"))?.generation,
                          (try? decodePointer("pre-restore.json"))?.generation].compactMap { $0 })
        // Export and restore run inside this actor without suspension; no concurrent reader pins.
        for url in (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey])) ?? [] {
            guard let id = UUID(uuidString: url.lastPathComponent), !pinned.contains(id),
                  (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == false else { continue }
            try? fm.removeItem(at: url)
        }
    }
    func exportArchive() throws -> Data {
        let snapshot = try load().snapshot
        let data = try JSONEncoder().encode(Archive(snapshot: snapshot, entries: entries(snapshot)))
        guard data.count <= Self.archiveLimit else { throw AnnotationError.tooLarge }
        return data
    }
    func exportPreRestoreArchive() throws -> Data {
        let snapshot = try generation(decodePointer("pre-restore.json"))
        return try JSONEncoder().encode(Archive(snapshot: snapshot, entries: entries(snapshot)))
    }
    func restoreArchive(_ data: Data, expectedRevision: Int) throws -> AnnotationSnapshot {
        guard data.count <= Self.archiveLimit else { throw AnnotationError.tooLarge }
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        guard archive.schemaVersion == 1 else { throw AnnotationError.unsupported }
        try check(archive.snapshot, entries: archive.entries)
        // A full validated pre-restore generation remains independent of normal fallback.
        let old: AnnotationSnapshot
        do { old = try load().snapshot }
        catch AnnotationError.damaged {
            // Explicit restore may repair a damaged store, after retaining the entire original.
            // Keep the live pointers untouched until the normal atomic commit succeeds.
            let copy = directory.deletingLastPathComponent().appendingPathComponent("Annotation-recovery-" + UUID().uuidString)
            try FileManager.default.copyItem(at: directory, to: copy)
            try Data().write(to: directory.appendingPathComponent("recovery-retention"), options: .atomic)
            validPointer = nil; repairing = true
            defer { repairing = false }
            return try save(archive.snapshot, expectedRevision: 0)
        }
        guard old.revision == expectedRevision else { throw AnnotationError.stale }
        if let pointer = validPointer {
            try JSONEncoder().encode(pointer).write(to: directory.appendingPathComponent("pre-restore.json"), options: .atomic)
        }
        return try save(archive.snapshot, expectedRevision: expectedRevision)
    }
}
