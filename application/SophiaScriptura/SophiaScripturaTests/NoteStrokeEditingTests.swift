import XCTest
import PencilKit
@testable import SophiaScriptura

final class NoteStrokeEditingTests: XCTestCase {
    private func stroke(x: CGFloat, y: CGFloat, date: Double = 1) -> PKStroke {
        let points = [CGPoint(x: x, y: y), CGPoint(x: x + 20, y: y), CGPoint(x: x + 40, y: y)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: date)))
    }
    private func objects(_ strokes: [PKStroke]) -> [NoteObject] {
        (try! NoteCanvasInk(objects: [])).objects(after: PKDrawing(strokes: strokes), replacing: [])
    }
    private func scene(_ objects: [NoteObject]) throws -> NoteCanvasInk { try NoteCanvasInk(objects: objects) }
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SP025-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    func testThousandsOfStrokesStayOneRegionAndZOrderControlsExtension() throws {
        let original = objects((0..<1001).map { stroke(x: CGFloat($0 % 20) * 80 + 20, y: CGFloat($0 / 20) * 80 + 20, date: Double($0)) })
        XCTAssertEqual(original.count, 1)
        let first = try XCTUnwrap(original.first)
        let scene = try scene(original)
        let appended = scene.objects(after: PKDrawing(strokes: scene.drawing.strokes + [stroke(x: 60, y: 60, date: 2000)]), replacing: original,
                                     extending: NoteCanvasInk.extensionOwner(in: original, selection: []))
        XCTAssertEqual(appended.count, 1); XCTAssertEqual(appended[0].strokeIDs?.count, 1002)
        XCTAssertEqual(appended[0].id, first.id)
        let shape = NoteObject(kind: .shape)
        XCTAssertNil(NoteCanvasInk.extensionOwner(in: original + [shape], selection: []))
        XCTAssertEqual(NoteCanvasInk.extensionOwner(in: original + [shape], selection: [first.id]), first.id)
        var locked = first; locked.positionLocked = true
        XCTAssertNil(NoteCanvasInk.extensionOwner(in: [locked], selection: []))
    }
    func testCapacitySpillPreservesNewStrokeAndLayerOrder() throws {
        let original = objects((0..<10000).map { stroke(x: 100, y: 100, date: Double($0)) })
        let scene = try self.scene(original)
        let shape = NoteObject(kind: .shape)
        let result = scene.objects(after: PKDrawing(strokes: scene.drawing.strokes + [stroke(x: 300, y: 300, date: 20000)]),
                                   replacing: original + [shape], extending: original[0].id)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.last?.id, shape.id)
        XCTAssertEqual(result[0].id, original[0].id)
        XCTAssertEqual(try PKDrawing(data: result[0].payload).strokes.count, 10000)
        XCTAssertEqual(try PKDrawing(data: result[1].payload).strokes.count, 1)
        XCTAssertEqual(try self.scene(result).drawing.strokes.count, 10001)
        XCTAssertEqual(result[0].strokeIDs, original[0].strokeIDs)
    }
    func testSubsetMoveColorDeletePreservesOtherStrokesAndIdentity() throws {
        let original = objects([stroke(x: 100, y: 100), stroke(x: 100, y: 200, date: 2)])
        let scene = try scene(original)
        let first = try XCTUnwrap(scene.strokeIndex.hit(at: CGPoint(x: 120, y: 100)))
        let other = try XCTUnwrap(scene.strokeIndex.hit(at: CGPoint(x: 120, y: 200)))
        let moved = scene.editing([first], in: original, operation: .move(CGSize(width: 300, height: 50)))
        let next = try self.scene(moved)
        XCTAssertNil(next.strokeIndex.hit(at: CGPoint(x: 120, y: 100)))
        XCTAssertEqual(next.strokeIndex.hit(at: CGPoint(x: 420, y: 150)), first)
        XCTAssertEqual(next.strokeIndex.hit(at: CGPoint(x: 120, y: 200)), other)
        let colored = next.editing([first], in: moved, operation: .color(.red))
        XCTAssertEqual(try self.scene(colored).drawing.strokes[0].ink.color, UIColor.red)
        XCTAssertEqual(try self.scene(colored).drawing.strokes[1].ink.color, scene.drawing.strokes[1].ink.color)
        let deleted = try self.scene(colored).editing([first], in: colored, operation: .delete)
        XCTAssertEqual(try self.scene(deleted).drawing.strokes.count, 1)
        XCTAssertEqual(try self.scene(deleted).strokeIndex.hit(at: CGPoint(x: 120, y: 200)), other)
    }
    func testLegacyDuplicateDatesCopyAndSplitHaveIndependentIDs() throws {
        let drawing = PKDrawing(strokes: [stroke(x: 100, y: 100), stroke(x: 200, y: 100)])
        let legacy = NoteObject(kind: .ink, payload: drawing.dataRepresentation())
        var copy = legacy; copy.id = UUID(); copy.frame.origin.y += 400
        let original = [legacy, copy]
        let scene = try scene(original)
        XCTAssertEqual(Set(scene.strokeIndex.entries.map(\.reference)).count, 4)
        XCTAssertEqual(scene.objects(after: scene.drawing, replacing: original), original)
        XCTAssertEqual(try self.scene(original).strokeIndex.entries.map(\.reference), scene.strokeIndex.entries.map(\.reference))
        let parent = scene.strokeIndex.entries[0].reference
        var fragment = scene.drawing.strokes[0]
        fragment.transform = fragment.transform.concatenating(CGAffineTransform(translationX: 10, y: 0))
        let split = scene.objects(after: PKDrawing(strokes: [scene.drawing.strokes[0], fragment] + Array(scene.drawing.strokes.dropFirst())), replacing: original)
        let refs = try self.scene(split).strokeIndex.entries.map(\.reference)
        XCTAssertTrue(refs.contains(parent)); XCTAssertEqual(Set(refs).count, 5)
        let copied = scene.copying([parent])
        XCTAssertEqual(copied.count, 1); XCTAssertNotEqual(copied[0].id, parent.objectID)
        XCTAssertNotEqual(copied[0].strokeIDs?.first, parent.strokeID)
        let locked = original.map { item -> NoteObject in var item = item; item.positionLocked = true; return item }
        XCTAssertEqual(try self.scene(locked).editing([parent], in: locked, operation: .move(CGSize(width: 50, height: 0))), locked)
    }
    func testDuplicateExtremeCreationDatesGetBoundedUniqueSceneTokens() throws {
        var value = stroke(x: 100, y: 100)
        value.path = PKStrokePath(controlPoints: value.path, creationDate: .distantPast)
        let legacy = NoteObject(kind: .ink, payload: PKDrawing(strokes: [value, value]).dataRepresentation())
        let scene = try self.scene([legacy])
        XCTAssertEqual(Set(scene.drawing.strokes.map { $0.path.creationDate }).count, 2)
        XCTAssertEqual(scene.objects(after: scene.drawing, replacing: [legacy]), [legacy])
        let index = NoteInkStrokeIndex(entries: scene.strokeIndex.entries)
        XCTAssertTrue(index.candidates(in: CGRect(x: 1e30, y: 1e30, width: 100, height: 100)).isEmpty)
    }
    func testGridMatchesReferenceWithTransformsMasksAndCrossRegionLasso() throws {
        var ink = stroke(x: 20, y: 20)
        ink.mask = UIBezierPath(rect: CGRect(x: 20, y: 15, width: 20, height: 10))
        ink.transform = CGAffineTransform(scaleX: 2, y: 3).concatenating(CGAffineTransform(translationX: 100, y: 100))
        let first = objects([ink])[0]
        var second = objects([stroke(x: 220, y: 160)])[0]
        second.id = UUID()
        let scene = try scene([first, second])
        XCTAssertNotNil(scene.strokeIndex.hit(at: CGPoint(x: 150, y: 160), tolerance: 0))
        XCTAssertNil(scene.strokeIndex.hit(at: CGPoint(x: 200, y: 160), tolerance: 0))
        for x in stride(from: 100, through: 280, by: 4) {
            let point = CGPoint(x: x, y: 160)
            let reference = scene.strokeIndex.entries.reversed().first { NoteInkStrokeIndex.hits($0.stroke, at: point, tolerance: 2) }?.reference
            XCTAssertEqual(scene.strokeIndex.hit(at: point, tolerance: 2), reference)
        }
        let selected = scene.strokeIndex.selected(inside: [CGPoint(x: 130, y: 140), CGPoint(x: 280, y: 140), CGPoint(x: 280, y: 180), CGPoint(x: 130, y: 180)])
        XCTAssertEqual(selected.count, 2)
        XCTAssertTrue(scene.strokeIndex.selected(inside: [CGPoint(x: 130, y: 140), CGPoint(x: 145, y: 140), CGPoint(x: 145, y: 180), CGPoint(x: 130, y: 180)]).isEmpty)
    }
    func testSparseIndexReducesCandidatesWithoutMissingHits() throws {
        let scene = try scene(objects((0..<1000).map { stroke(x: CGFloat($0 % 25) * 300 + 20, y: CGFloat($0 / 25) * 200 + 20, date: Double($0)) }))
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertLessThan(scene.strokeIndex.candidates(in: rect).count, 10)
        XCTAssertNotNil(scene.strokeIndex.hit(at: CGPoint(x: 40, y: 20)))
        XCTAssertNil(scene.strokeIndex.hit(at: CGPoint(x: 170, y: 80)))
    }
    @MainActor func testSessionUndoRedoCopyAndBackupRetainEditableIDs() async throws {
        let store = NotesFileRepository(directory: try folder()), session = NotesSession(repository: store)
        await session.load(); session.create(kind: .canvas)
        let original = objects([stroke(x: 100, y: 100), stroke(x: 100, y: 200, date: 2)])
        session.edit { $0.objects = original }
        let id = try XCTUnwrap(try scene(original).strokeIndex.hit(at: CGPoint(x: 120, y: 100)))
        session.strokeSelection = [id]; session.move(CGSize(width: 250, height: 30))
        let moved = try XCTUnwrap(session.note?.objects)
        session.undo(); XCTAssertEqual(session.note?.objects, original)
        session.redo(); XCTAssertEqual(session.note?.objects, moved)
        session.strokeSelection = [id]; session.copySelection()
        XCTAssertEqual(session.canvasClipboard.count, 1)
        XCTAssertEqual(try scene(session.canvasClipboard).drawing.strokes.count, 1)
        session.duplicateSelection(); XCTAssertEqual(session.note?.objects.count, 2)
        session.undo(); XCTAssertEqual(session.note?.objects, moved)
        await session.save()
        let exported = try await session.export()
        let restored = NotesSession(repository: NotesFileRepository(directory: try folder()))
        await restored.load(); await restored.restore(exported)
        let reopened = try XCTUnwrap(restored.snapshot.notes.first)
        XCTAssertEqual(reopened.objects, moved)
        XCTAssertEqual(try scene(reopened.objects).strokeIndex.hit(at: CGPoint(x: 370, y: 130)), id)
    }
    @MainActor func testRejectedInkRecoverySurvivesRelaunchWithoutChangingSavedNote() async throws {
        let directory = try folder(), repository = NotesFileRepository(directory: directory)
        let session = NotesSession(repository: repository)
        await session.load(); let id = try XCTUnwrap(session.create(kind: .canvas))
        let original = objects([stroke(x: 100, y: 100)])
        session.edit { $0.objects = original }; await session.save()
        let draft = PKDrawing(strokes: [stroke(x: 100, y: 100), stroke(x: 300, y: 100, date: 2)]).dataRepresentation()
        session.retainRejectedInk(draft); await session.loadRejectedInk()
        let restarted = NotesSession(repository: NotesFileRepository(directory: directory))
        await restarted.load(); restarted.open(id); await restarted.loadRejectedInk()
        XCTAssertEqual(restarted.rejectedInk, draft)
        XCTAssertEqual(restarted.note?.objects, original)
        await restarted.recoverRejectedInk()
        XCTAssertEqual(restarted.snapshot.notes.count, 2)
        XCTAssertEqual(restarted.note?.title, "Recovered drawing")
        XCTAssertEqual(try scene(try XCTUnwrap(restarted.note?.objects)).drawing.strokes.count, 2)
        XCTAssertEqual(restarted.snapshot.notes.first { $0.id == id }?.objects, original)
        let retained = try await repository.rejectedInk(noteID: id)
        XCTAssertNil(retained)
        do { try await repository.retainRejectedInk(Data("invalid".utf8), noteID: id); XCTFail("Invalid draft accepted") }
        catch { }
    }
    @MainActor func testInvalidMetadataAndStrokeCapacityRejectWithoutDroppingSavedInk() async throws {
        let session = NotesSession(repository: NotesFileRepository(directory: try folder()))
        await session.load(); session.create(kind: .canvas)
        let original = objects([stroke(x: 100, y: 100)])
        session.edit { $0.objects = original }
        var invalid = original; invalid[0].strokeIDs = [UUID(), UUID()]
        session.edit { $0.objects = invalid }; XCTAssertEqual(session.note?.objects, original)
        XCTAssertThrowsError(try scene(invalid))
        let tooMany = [NoteObject(kind: .ink, payload: PKDrawing(strokes: (0..<10001).map { stroke(x: 100, y: 100, date: Double($0)) }).dataRepresentation())]
        session.edit { $0.objects = tooMany }; XCTAssertEqual(session.note?.objects, original)
        let repository = NotesFileRepository(directory: try folder())
        var note = NoteDocument(); note.objects = invalid
        do { _ = try await repository.save(NotesSnapshot(notes: [note]), expectedRevision: 0); XCTFail("Invalid metadata saved") }
        catch { }
    }
}
