import XCTest
import PencilKit
@testable import SophiaScriptura

@MainActor final class AnnotationTests: XCTestCase {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func document() async throws -> ChapterDocument {
        try await BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self)).chapter(book: "JHN", number: 3)
    }
    private func drawing() -> Data {
        let points = [CGPoint(x: 42, y: 58), CGPoint(x: 142, y: 58)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 2, height: 2), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))]).dataRepresentation()
    }
    private func fixture() async throws -> AnnotationSnapshot {
        let doc = try await document()
        var group = AnnotationGroup(source: AnnotationSource(doc), layout: AnnotationRenderer.measure(doc, preferences: ReaderPreferences(), width: 820))
        let layer = AnnotationLayer(name: "Study", drawing: drawing())
        group.layers = [layer]; group.selectedLayerID = layer.id
        return AnnotationSnapshot(groups: [group])
    }
    func testCommitReopenAndIsolation() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let repo = AnnotationFileRepository(directory: dir)
        var snapshot = try await fixture()
        var second = snapshot.groups[0]; second.id = UUID()
        second.layers = [AnnotationLayer(name: "Study", drawing: PKDrawing().dataRepresentation())]
        second.selectedLayerID = second.layers[0].id
        snapshot.groups.append(second)
        let saved = try await repo.save(snapshot, expectedRevision: 0)
        let reopened = try await AnnotationFileRepository(directory: dir).load()
        XCTAssertEqual(reopened.snapshot, saved)
        XCTAssertNotEqual(saved.groups[0].layers[0].id, saved.groups[1].layers[0].id)
        XCTAssertFalse(reopened.recovered)
    }
    func testInterruptedCommitAtEveryBoundaryKeepsCompleteGeneration() async throws {
        for boundary in AnnotationFileRepository.Boundary.allCases {
            let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
            let original = try await AnnotationFileRepository(directory: dir).save(fixture(), expectedRevision: 0)
            let interrupted = AnnotationFileRepository(directory: dir, interrupt: { if $0 == boundary { throw AnnotationError.interrupted } })
            var newer = original; newer.groups[0].layers[0].name = "New name"
            do { _ = try await interrupted.save(newer, expectedRevision: 1); XCTFail("Expected injected failure") } catch { }
            let reopened = try await AnnotationFileRepository(directory: dir).load().snapshot
            XCTAssertEqual(reopened.groups[0].layers[0].drawing, original.groups[0].layers[0].drawing)
            XCTAssertEqual(reopened.groups[0].layers[0].name, boundary == .committed ? "New name" : "Study")
        }
    }
    func testStaleWriterCannotOverwriteNewRevision() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let first = AnnotationFileRepository(directory: dir), second = AnnotationFileRepository(directory: dir)
        let original = try await fixture(); _ = try await first.save(original, expectedRevision: 0)
        _ = try await second.load()
        _ = try await first.save(original, expectedRevision: 1)
        do { _ = try await second.save(original, expectedRevision: 1); XCTFail("Stale write accepted") }
        catch { XCTAssertTrue(error is AnnotationError) }
        let reopened = try await first.load(); XCTAssertEqual(reopened.snapshot.revision, 2)
    }
    func testCorruptCurrentFallsBackAndDoubleCorruptionRetainsFiles() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let repo = AnnotationFileRepository(directory: dir)
        let original = try await repo.save(fixture(), expectedRevision: 0)
        _ = try await repo.save(original, expectedRevision: 1)
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: dir.appendingPathComponent("current.json"))
        let fallback = try await repo.load()
        XCTAssertTrue(fallback.recovered); XCTAssertEqual(fallback.snapshot.revision, 1)
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("current.json")), corrupt)
        try corrupt.write(to: dir.appendingPathComponent("previous.json"))
        do { _ = try await repo.load(); XCTFail("Expected unavailable store") } catch { }
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("current.json")), corrupt)
    }
    func testArchiveRoundtripTombstonesAndPreRestoreRecovery() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let repo = AnnotationFileRepository(directory: dir)
        var original = try await fixture()
        original.groups[0].layers[0].deletedAt = Date(); original.groups[0].selectedLayerID = nil
        _ = try await repo.save(original, expectedRevision: 0)
        let archive = try await repo.exportArchive()
        let serialized = String(decoding: archive, as: UTF8.self)
        XCTAssertFalse(serialized.contains("For God so loved")); XCTAssertFalse(serialized.contains("credential"))
        var empty = AnnotationSnapshot(); empty.revision = 1
        _ = try await repo.save(empty, expectedRevision: 1)
        let restored = try await repo.restoreArchive(archive, expectedRevision: 2)
        XCTAssertEqual(restored.groups, original.groups)
        let preRestore = try await repo.exportPreRestoreArchive()
        let recovered = try await repo.restoreArchive(preRestore, expectedRevision: 3)
        XCTAssertTrue(recovered.groups.isEmpty)
    }
    func testRejectedArchivesAndUnknownSchemaLeaveLiveDataUnchanged() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let repo = AnnotationFileRepository(directory: dir)
        _ = try await repo.save(fixture(), expectedRevision: 0)
        let archive = try await repo.exportArchive(), pointer = try Data(contentsOf: dir.appendingPathComponent("current.json"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: archive) as? [String: Any])
        json["schemaVersion"] = 99
        let future = try JSONSerialization.data(withJSONObject: json)
        json["schemaVersion"] = 1
        var entries = try XCTUnwrap(json["entries"] as? [[String: Any]])
        entries[0]["id"] = "../../outside"; json["entries"] = entries
        let traversal = try JSONSerialization.data(withJSONObject: json)
        for bad in [Data("broken".utf8), future, traversal, Data(repeating: 0, count: AnnotationFileRepository.archiveLimit + 1)] {
            do { _ = try await repo.restoreArchive(bad, expectedRevision: 1); XCTFail("Invalid archive accepted") } catch { }
            XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent("current.json")), pointer)
        }
    }
    func testLayoutViewportAndFontIsolation() async throws {
        let doc = try await document(), group = try await fixture().groups[0]
        XCTAssertTrue(AnnotationRenderer.matches(group, document: doc))
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let repo = AnnotationFileRepository(directory: dir)
        let annotations = AnnotationSession(repository: repo)
        _ = try await repo.save(AnnotationSnapshot(groups: [group]), expectedRevision: 0)
        await annotations.open(doc)
        let reader = ReaderSession(content: BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self)), state: nil)
        await reader.start(); await reader.navigate(book: "JHN", chapter: 3)
        let controller = AnnotationController(document: doc, preferences: reader.preferences, reader: reader, session: annotations)
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 820, height: 1000); controller.viewDidLayoutSubviews()
        let scroll = try XCTUnwrap(controller.view.subviews.first as? UIScrollView)
        let stage = try XCTUnwrap(scroll.subviews.first)
        let paper = try XCTUnwrap(stage.subviews.first)
        let text = try XCTUnwrap(paper.subviews.first as? UITextView)
        let frame = text.frame, bytes = annotations.selected?.drawing
        scroll.zoomScale = 1.4; controller.view.frame.size = CGSize(width: 400, height: 700); controller.viewDidLayoutSubviews()
        annotations.marginExpanded = true; controller.apply()
        XCTAssertEqual(text.frame, frame); XCTAssertEqual(annotations.selected?.drawing, bytes)
        var bigger = reader.preferences; bigger.sizeStep = 8; controller.preferences = bigger; controller.apply()
        XCTAssertEqual(text.frame, frame); XCTAssertEqual(annotations.group?.layout, group.layout)
    }
    func testLayerDeleteRestoreAndDeferredStrokeTransition() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let session = AnnotationSession(repository: AnnotationFileRepository(directory: dir)), doc = try await document()
        await session.open(doc); await session.create(document: doc, preferences: ReaderPreferences(), width: 820)
        let id = try XCTUnwrap(session.selected?.id)
        session.updateDrawing(drawing(), layerID: id); await session.save()
        let data = session.selected?.drawing
        await session.deleteSelected(); XCTAssertNil(session.selected)
        await session.restoreLayer(id); XCTAssertEqual(session.selected?.drawing, data)
        session.usingTool = true
        var transitioned = false
        let pending = Task { await session.transition { transitioned = true } }
        await Task.yield(); XCTAssertFalse(transitioned)
        session.finishStroke(); await pending.value
        XCTAssertTrue(transitioned)
        await session.create(document: doc, preferences: ReaderPreferences(), width: 820)
        XCTAssertEqual(session.liveLayers.count, 2); XCTAssertNotEqual(session.selected?.id, id)
        await session.select(id); XCTAssertEqual(session.selected?.drawing, data)
    }
    func testFailedSaveRetainsDirtyInkAndRetryReopensAcknowledgedSave() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let backing = AnnotationFileRepository(directory: dir)
        let original = try await backing.save(fixture(), expectedRevision: 0)
        let failing = FailingAnnotationRepository(backing: backing)
        let session = AnnotationSession(repository: failing), doc = try await document()
        await session.open(doc)
        let id = try XCTUnwrap(session.selected?.id)
        session.updateDrawing(PKDrawing().dataRepresentation(), layerID: id)
        let dirtyData = session.selected?.drawing
        await failing.failSave(); await session.save()
        XCTAssertTrue(session.dirty); XCTAssertTrue(session.failed); XCTAssertFalse(session.canTransition)
        XCTAssertEqual(session.selected?.drawing, dirtyData)
        let unchanged = try await backing.load().snapshot
        XCTAssertEqual(unchanged, original)
        await session.save()
        XCTAssertFalse(session.dirty); XCTAssertFalse(session.failed)
        let reopened = try await backing.load().snapshot
        XCTAssertEqual(reopened.groups[0].layers[0].drawing, dirtyData)
    }
    func testIndependentUndoAndClearRestoresOnlySelectedLayer() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let backing = AnnotationFileRepository(directory: dir)
        let original = try await backing.save(fixture(), expectedRevision: 0)
        let session = AnnotationSession(repository: backing), doc = try await document()
        await session.open(doc)
        let reader = ReaderSession(content: BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self)), state: nil)
        await reader.start(); await reader.navigate(book: "JHN", chapter: 3)
        let controller = AnnotationController(document: doc, preferences: reader.preferences, reader: reader, session: session)
        controller.loadViewIfNeeded()
        session.clear?(); XCTAssertEqual(try PKDrawing(data: XCTUnwrap(session.selected?.drawing)).strokes.count, 0)
        await session.save()
        await session.create(document: doc, preferences: reader.preferences, width: 820); controller.apply()
        session.undo?()
        XCTAssertEqual(try PKDrawing(data: XCTUnwrap(session.selected?.drawing)).strokes.count, 0)
        await session.select(original.groups[0].layers[0].id); controller.apply(); session.undo?()
        XCTAssertEqual(try PKDrawing(data: XCTUnwrap(session.selected?.drawing)).strokes.count, 1)
    }
    func testCorruptDrawingFallbackAndExplicitBackupRepairPreservesOriginal() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let repo = AnnotationFileRepository(directory: dir)
        let original = try await repo.save(fixture(), expectedRevision: 0)
        let archive = try await repo.exportArchive()
        _ = try await repo.save(original, expectedRevision: 1)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent("current.json"))) as? [String: Any])
        let generation = try XCTUnwrap(json["generation"] as? String)
        try Data("broken drawing".utf8).write(to: dir.appendingPathComponent(generation).appendingPathComponent(original.groups[0].layers[0].id.uuidString + ".drawing"))
        let fallback = try await repo.load(); XCTAssertTrue(fallback.recovered)
        try Data("broken".utf8).write(to: dir.appendingPathComponent("previous.json"))
        let repaired = try await repo.restoreArchive(archive, expectedRevision: 0)
        XCTAssertEqual(repaired.groups, original.groups)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent(generation).path))
        // Repair copies use this repository's sibling; remove only the copy created by this test.
        let siblings = try FileManager.default.contentsOfDirectory(at: dir.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        for copy in siblings where copy.lastPathComponent.hasPrefix("Annotation-recovery-") {
            if FileManager.default.fileExists(atPath: copy.appendingPathComponent(generation).path) { try FileManager.default.removeItem(at: copy) }
        }
    }
    func testBackupRestoreInvalidatesOldCanvasBeforeItCanFlushOverRestoredInk() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let backing = AnnotationFileRepository(directory: dir)
        _ = try await backing.save(fixture(), expectedRevision: 0)
        let session = AnnotationSession(repository: backing), doc = try await document()
        await session.open(doc)
        let archive = try await session.export(), original = session.selected?.drawing
        let reader = ReaderSession(content: BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self)), state: nil)
        await reader.start()
        let controller = AnnotationController(document: doc, preferences: reader.preferences, reader: reader, session: session)
        controller.loadViewIfNeeded(); session.clear?(); await session.save()
        XCTAssertNotEqual(session.selected?.drawing, original)
        await session.restore(archive, document: doc)
        controller.dispose() // Simulates SwiftUI dismantling the old surface after restore.
        XCTAssertEqual(session.selected?.drawing, original)
        XCTAssertFalse(session.dirty)
        await session.save()
        let reopened = try await backing.load().snapshot
        XCTAssertEqual(reopened.groups[0].layers[0].drawing, original)
    }
    func testSurroundingSpacePaletteDismissalAndAutomaticSave() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let backing = AnnotationFileRepository(directory: dir)
        let session = AnnotationSession(repository: backing), doc = try await document()
        await session.open(doc); await session.create(document: doc, preferences: ReaderPreferences(), width: 820)
        let layout = try XCTUnwrap(session.group?.layout)
        XCTAssertTrue(layout.surroundingSpace)
        XCTAssertEqual(layout.width - layout.textWidth, layout.inset * 2)
        let reader = ReaderSession(content: BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self)), state: nil)
        await reader.start()
        let controller = AnnotationController(document: doc, preferences: reader.preferences, reader: reader, session: session)
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 820, height: 900); controller.viewDidLayoutSubviews()
        let viewport = try XCTUnwrap(controller.view.subviews.first as? UIScrollView)
        let stage = try XCTUnwrap(viewport.subviews.first), paper = try XCTUnwrap(stage.subviews.first)
        let text = try XCTUnwrap(paper.subviews.first as? UITextView)
        XCTAssertEqual(stage.bounds.width, layout.textWidth + 56)
        XCTAssertEqual(stage.frame.midX, viewport.bounds.midX, accuracy: 0.01)
        let frame = text.frame
        session.marginExpanded = true; controller.apply()
        XCTAssertEqual(stage.bounds.width, layout.width); XCTAssertEqual(text.frame, frame)
        XCTAssertEqual(viewport.contentOffset.y, 0, accuracy: 1, "Opening Margin at the start exposes blank space above Scripture")
        XCTAssertFalse(paper.layer.sublayers?.contains { $0 is CAShapeLayer } ?? false)
        let canvas = try XCTUnwrap(paper.subviews.compactMap { $0 as? PKCanvasView }.first)
        controller.canvasViewDidBeginUsingTool(canvas)
        XCTAssertFalse(session.toolsVisible)
        XCTAssertTrue(canvas.isUserInteractionEnabled)
        canvas.drawing = try PKDrawing(data: drawing())
        controller.canvasViewDrawingDidChange(canvas)
        controller.canvasViewDidEndUsingTool(canvas)
        let saved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !session.dirty && !session.saving }, object: nil)
        await fulfillment(of: [saved], timeout: 5)
        let reopened = try await backing.load().snapshot
        XCTAssertEqual(try PKDrawing(data: reopened.groups[0].layers[0].drawing).strokes.count, 1)
        XCTAssertFalse(session.toolsVisible, "Autosave must not reopen the palette")
        session.marginExpanded = false; controller.apply()
        XCTAssertEqual(stage.frame.midX, viewport.bounds.midX, accuracy: 0.01)
        XCTAssertEqual(text.frame, frame)
    }
    func testLegacyLayoutRetainedButNewLayerUsesSurroundingSpace() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let backing = AnnotationFileRepository(directory: dir), doc = try await document()
        let font = ScriptureFonts.font("Georgia", size: 23)
        let legacy = AnnotationRenderer.layout(doc, font: font, width: 800, textWidth: 540)
        let old = AnnotationGroup(source: AnnotationSource(doc), layout: legacy, layers: [AnnotationLayer(name: "Old", drawing: drawing())])
        _ = try await backing.save(AnnotationSnapshot(groups: [old]), expectedRevision: 0)
        let session = AnnotationSession(repository: backing); await session.open(doc)
        XCTAssertTrue(session.layoutAvailable)
        await session.create(document: doc, preferences: ReaderPreferences(), width: 820)
        XCTAssertTrue(session.group?.layout.surroundingSpace ?? false)
        XCTAssertEqual(session.snapshot.groups.first, old)
    }
    func testEachLayerCapturesAndRestoresAppearanceWithoutChangingOtherInk() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let backing = AnnotationFileRepository(directory: dir), doc = try await document()
        let reader = ReaderSession(content: BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self)), state: nil)
        await reader.start()
        let session = AnnotationSession(repository: backing)
        await session.open(doc)
        await session.create(document: doc, preferences: reader.preferences, width: 820)
        let firstID = try XCTUnwrap(session.selected?.id)
        let firstLayout = try XCTUnwrap(session.selectedLayout)
        session.updateDrawing(drawing(), layerID: firstID); await session.save()
        let originalInk = session.selected?.drawing

        var sage = reader.preferences
        sage.appearancePreset = ScriptureAppearance.quietSage.rawValue; sage.sizeStep = 4
        reader.updatePreferences(sage)
        await session.create(document: doc, preferences: sage, width: 820)
        let secondID = try XCTUnwrap(session.selected?.id)
        let secondLayout = try XCTUnwrap(session.selectedLayout)
        XCTAssertNotEqual(firstLayout, secondLayout)
        XCTAssertEqual(session.layers(for: doc).count, 2)
        let firstChoice = try XCTUnwrap(session.layers(for: doc).first { $0.id == firstID })
        await session.select(firstChoice, document: doc, reader: reader)
        XCTAssertEqual(reader.preferences.appearancePreset, nil)
        XCTAssertEqual(reader.preferences.sizeStep, 2)
        XCTAssertEqual(session.selectedLayout, firstLayout)
        XCTAssertEqual(session.selected?.drawing, originalInk)

        var changed = reader.preferences
        changed.appearancePreset = ScriptureAppearance.springLeaf.rawValue; changed.sizeStep = 5
        reader.updatePreferences(changed)
        await session.appearanceChanged(to: changed, document: doc, width: 820)
        XCTAssertEqual(session.selected?.appearance, AnnotationLayerAppearance(changed))
        XCTAssertNotEqual(session.selectedLayout, firstLayout)
        XCTAssertEqual(session.selected?.drawing, originalInk)
        XCTAssertTrue(AnnotationRenderer.matches(try XCTUnwrap(session.selectedLayout), source: AnnotationSource(doc), document: doc))
        let reopened = try await backing.load().snapshot
        let layers = reopened.groups.flatMap(\.layers)
        XCTAssertEqual(layers.first { $0.id == firstID }?.drawing, originalInk)
        XCTAssertEqual(layers.first { $0.id == secondID }?.layout, secondLayout)
        XCTAssertEqual(layers.first { $0.id == secondID }?.appearance, AnnotationLayerAppearance(sage))
    }
    func testDarkThemeNewCanvasStartsWithVisibleInk() async throws {
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let backing = AnnotationFileRepository(directory: dir)
        _ = try await backing.save(fixture(), expectedRevision: 0)
        let session = AnnotationSession(repository: backing), doc = try await document()
        await session.open(doc)
        let reader = ReaderSession(content: BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self)), state: nil)
        await reader.start()
        var preferences = reader.preferences; preferences.theme = "dark"
        let controller = AnnotationController(document: doc, preferences: preferences, reader: reader, session: session)
        controller.loadViewIfNeeded()
        let viewport = try XCTUnwrap(controller.view.subviews.first as? UIScrollView)
        let stage = try XCTUnwrap(viewport.subviews.first)
        let paper = try XCTUnwrap(stage.subviews.first)
        let canvas = try XCTUnwrap(paper.subviews.compactMap { $0 as? PKCanvasView }.first)
        let tool = try XCTUnwrap(canvas.tool as? PKInkingTool)
        XCTAssertEqual(tool.color, preferences.appearance.palette(dark: true).ink)
    }
    func testLongestBundledChapterGeometryAndDenseDrawing() async throws {
        let doc = try await BundledScriptureRepository(bundle: Bundle(for: ReaderSession.self)).chapter(book: "PSA", number: 119)
        let layout = AnnotationRenderer.measure(doc, preferences: ReaderPreferences(), width: 820)
        XCTAssertGreaterThan(layout.height, 10_000); XCTAssertLessThan(layout.height, 200_000)
        let stroke = try PKDrawing(data: drawing()).strokes[0]
        let dense = PKDrawing(strokes: (0..<2000).map { _ in stroke }).dataRepresentation()
        XCTAssertLessThan(dense.count, AnnotationFileRepository.drawingLimit)
        let dir = directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let group = AnnotationGroup(source: AnnotationSource(doc), layout: layout, layers: [AnnotationLayer(name: "Dense", drawing: dense)])
        let repo = AnnotationFileRepository(directory: dir)
        _ = try await repo.save(AnnotationSnapshot(groups: [group]), expectedRevision: 0)
        let reopened = try await repo.load().snapshot
        XCTAssertEqual(try PKDrawing(data: reopened.groups[0].layers[0].drawing).strokes.count, 2000)
        print("SP012 Psalm 119: \(doc.verseNumbers.count) verses, \(Int(layout.width)) × \(Int(layout.height)) pt; 2000 strokes, \(dense.count) bytes")
    }

}


private actor FailingAnnotationRepository: AnnotationRepository {
    let backing: AnnotationFileRepository
    var fail = false
    init(backing: AnnotationFileRepository) { self.backing = backing }
    func failSave() { fail = true }
    func load() async throws -> AnnotationLoad { try await backing.load() }
    func save(_ snapshot: AnnotationSnapshot, expectedRevision: Int) async throws -> AnnotationSnapshot {
        if fail { fail = false; throw AnnotationError.interrupted }
        return try await backing.save(snapshot, expectedRevision: expectedRevision)
    }
    func exportArchive() async throws -> Data { try await backing.exportArchive() }
    func exportPreRestoreArchive() async throws -> Data { try await backing.exportPreRestoreArchive() }
    func restoreArchive(_ data: Data, expectedRevision: Int) async throws -> AnnotationSnapshot {
        try await backing.restoreArchive(data, expectedRevision: expectedRevision)
    }
}
