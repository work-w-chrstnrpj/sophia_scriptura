import Foundation
import CoreGraphics
import PencilKit
import ImageIO

/// Disposable SP-006 format. No production SwiftData schema or personal notes use this.
struct CanvasFixture: Codable, Equatable {
    static let version = 1
    static let maximumCoordinate: CGFloat = 6_000
    static let maximumFileBytes = 12 * 1_024 * 1_024

    enum ObjectID: String, Codable, CaseIterable, Identifiable {
        case text, ink, image
        var id: String { rawValue }
        var title: String {
            switch self {
            case .text: return "Observation"
            case .ink: return "Handwriting"
            case .image: return "Image"
            }
        }
    }

    struct Object: Codable, Equatable {
        var id: ObjectID
        var frame: CGRect
        var group: UUID?
    }

    var schemaVersion = version
    var objects: [Object]
    var text: String
    var drawing: Data
    var imageAssetID: String
    var assets: [String: Data]

    func object(_ id: ObjectID) -> Object { objects.first { $0.id == id }! }

    func members(of selection: Set<ObjectID>) -> Set<ObjectID> {
        let groups = Set(objects.filter { selection.contains($0.id) }.compactMap(\.group))
        return Set(objects.filter { selection.contains($0.id) || $0.group.map(groups.contains) == true }.map(\.id))
    }

    /// Screen deltas convert once at the boundary. All persisted geometry is in points.
    static func documentDelta(screen: CGSize, zoom: CGFloat) -> CGSize {
        guard zoom.isFinite, zoom > 0 else { return .zero }
        return CGSize(width: screen.width / zoom, height: screen.height / zoom)
    }

    mutating func move(_ selection: Set<ObjectID>, by delta: CGSize) {
        guard delta.width.isFinite, delta.height.isFinite else { return }
        let selected = members(of: selection)
        let frames = objects.filter { selected.contains($0.id) }.map(\.frame)
        guard let first = frames.first else { return }
        let bounds = frames.dropFirst().reduce(first) { $0.union($1) }
        // Clamp the entire selection together: no relative drift at the experiment bounds.
        let dx = min(max(delta.width, -bounds.minX), Self.maximumCoordinate - bounds.maxX)
        let dy = min(max(delta.height, -bounds.minY), Self.maximumCoordinate - bounds.maxY)
        for index in objects.indices where selected.contains(objects[index].id) {
            objects[index].frame = objects[index].frame.offsetBy(dx: dx, dy: dy)
        }
    }

    mutating func group(_ selection: Set<ObjectID>) {
        let selected = members(of: selection)
        guard selected.count > 1 else { return }
        let groupID = UUID()
        for index in objects.indices where selected.contains(objects[index].id) { objects[index].group = groupID }
    }

    mutating func ungroup(_ selection: Set<ObjectID>) {
        let selected = members(of: selection)
        for index in objects.indices where selected.contains(objects[index].id) { objects[index].group = nil }
    }

    var contentSize: CGSize {
        CGSize(width: min(Self.maximumCoordinate, max(1_400, objects.map(\.frame.maxX).max()! + 180)),
               height: min(Self.maximumCoordinate, max(1_000, objects.map(\.frame.maxY).max()! + 180)))
    }

    func validated() throws -> Self {
        guard schemaVersion == Self.version else { throw FixtureError.unsupportedVersion }
        guard objects.count == 3, Set(objects.map(\.id)) == Set(ObjectID.allCases),
              text.count <= 500, drawing.count <= 4 * 1_024 * 1_024,
              assets.count == 1, imageAssetID == "sample-image",
              let image = assets[imageAssetID], image.count <= 4 * 1_024 * 1_024 else {
            throw FixtureError.invalidContent
        }
        for object in objects {
            let f = object.frame
            guard [f.origin.x, f.origin.y, f.width, f.height].allSatisfy(\.isFinite),
                  f.minX >= 0, f.minY >= 0, f.width >= 40, f.height >= 40,
                  f.maxX <= Self.maximumCoordinate, f.maxY <= Self.maximumCoordinate else {
                throw FixtureError.invalidContent
            }
        }
        for group in Set(objects.compactMap(\.group)) {
            guard objects.filter({ $0.group == group }).count >= 2 else { throw FixtureError.invalidContent }
        }
        let ink = try PKDrawing(data: drawing)
        guard ink.strokes.count <= 5_000 else { throw FixtureError.invalidContent }
        if !ink.bounds.isNull {
            let area = CGRect(origin: .zero, size: object(.ink).frame.size).insetBy(dx: -20, dy: -20)
            guard area.contains(ink.bounds) else { throw FixtureError.invalidContent }
        }
        guard let source = CGImageSourceCreateWithData(image as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 2_048, height <= 2_048,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            throw FixtureError.invalidContent
        }
        return self
    }
}

enum FixtureError: LocalizedError {
    case unsupportedVersion, invalidContent, fileTooLarge
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "This sample uses an unsupported fixture version."
        case .invalidContent: return "The sample is damaged or contains unsupported content."
        case .fileTooLarge: return "The sample exceeds the experiment's storage limit."
        }
    }
}

/// Whole-document snapshots keep ink, grouping, geometry and text in one undo transaction.
struct CanvasHistory {
    private(set) var undoStack: [CanvasFixture] = []
    private(set) var redoStack: [CanvasFixture] = []
    mutating func record(_ document: CanvasFixture) {
        undoStack.append(document)
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll()
    }
    mutating func undo(_ current: CanvasFixture) -> CanvasFixture? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }
    mutating func redo(_ current: CanvasFixture) -> CanvasFixture? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }
}
