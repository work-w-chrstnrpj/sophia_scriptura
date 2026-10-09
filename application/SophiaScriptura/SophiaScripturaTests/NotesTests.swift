import XCTest
import PencilKit
import CryptoKit
@testable import SophiaScriptura

final class NotesTests: XCTestCase {
    @MainActor func testCanvasCullsViewsAndKeepsSelectedObjectMounted() async throws {
        let session = NotesSession(repository: NotesFileRepository(directory: try folder()))
        await session.load(); _ = session.create(kind: .canvas)
        let near = NoteObject(kind: .shape, frame: CGRect(x: 100, y: 100, width: 80, height: 80))
        let far = NoteObject(kind: .shape, frame: CGRect(x: 9000, y: 9000, width: 80, height: 80))
        session.edit { $0.objects = [near, far] }; session.selection = []
        let controller = NoteCanvasController(session: session, openCitation: { _ in })
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 800, height: 1000)
        controller.viewDidLayoutSubviews(); controller.apply()
        let scroll = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIScrollView }.first { $0.accessibilityIdentifier == "notes.viewport" })
        scroll.setZoomScale(1, animated: false); scroll.contentOffset = .zero; controller.apply()
        let paper = try XCTUnwrap(scroll.subviews.first { $0.bounds.width == NoteDocument.extent })
        XCTAssertEqual(paper.subviews.filter { $0.accessibilityIdentifier == "notes.object.shape" }.count, 1)
        session.selection = [far.id]; controller.apply()
        XCTAssertEqual(paper.subviews.filter { $0.accessibilityIdentifier == "notes.object.shape" }.count, 2)
        session.selection = []; scroll.contentOffset = CGPoint(x: 8800, y: 8800); controller.apply()
        XCTAssertEqual(paper.subviews.filter { $0.accessibilityIdentifier == "notes.object.shape" }.count, 1)
        XCTAssertEqual(session.note?.objects.count, 2)
        controller.close()
    }

    @MainActor func testImagePreparationDownsamplesAndRejectsInvalidInput() async throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let input = UIGraphicsImageRenderer(size: CGSize(width: 4096, height: 1024), format: format).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 4096, height: 1024))
        }
        let prepared = await NoteImagePreparation.prepare(input)
        let output = try XCTUnwrap(prepared)
        XCTAssertEqual(output.size, CGSize(width: 2048, height: 512))
        XCTAssertNotNil(UIImage(data: output.data))
        let decoded = await NoteImagePreparation.decode(output.data)
        XCTAssertEqual(decoded?.image.width, 2048)
        XCTAssertEqual(decoded?.image.height, 512)
        let invalid = await NoteImagePreparation.prepare(Data("invalid".utf8))
        XCTAssertNil(invalid)
    }

    func testCanvasCapacityAndPencilSelectionPreserveGroups() throws {
        var note = NoteDocument()
        note.objects = (0..<1000).map { _ in NoteObject(kind: .text, text: "Content") }
        try note.validate()
        note.objects.append(NoteObject(kind: .text))
        XCTAssertThrowsError(try note.validate())
        let group = UUID()
        let first = NoteObject(kind: .text, frame: CGRect(x: 10, y: 10, width: 40, height: 40), group: group, text: "Inside")
        let second = NoteObject(kind: .shape, frame: CGRect(x: 500, y: 500, width: 40, height: 40), group: group)
        let outside = NoteObject(kind: .text, frame: CGRect(x: 200, y: 200, width: 40, height: 40))
        note.objects = [first, second, outside]
        XCTAssertEqual(note.objectsInside([CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100), CGPoint(x: 0, y: 100)]), [first.id, second.id])
        XCTAssertTrue(note.objectsInside([]).isEmpty)
    }

    func testHundredsOfPencilStrokesUseBoundedObjectsAndReopen() async throws {
        var objects: [NoteObject] = []
        let template = try PKDrawing(data: drawing()).strokes[0]
        var previous: NoteCanvasInk?
        for index in 0..<300 {
            let scene = try NoteCanvasInk(objects: objects, previous: previous)
            previous = scene
            XCTAssertTrue(NoteCanvasInk.equivalent(scene.drawing, try NoteCanvasInk(objects: objects).drawing))
            var stroke = template
            stroke.path = PKStrokePath(controlPoints: template.path, creationDate: Date(timeIntervalSince1970: Double(index + 1)))
            let edited = PKDrawing(strokes: scene.drawing.strokes + [stroke])
            objects = scene.objects(after: edited, replacing: objects, extending: NoteCanvasInk.extensionOwner(in: objects, selection: []))
        }
        XCTAssertEqual(objects.count, 1)
        XCTAssertEqual(try NoteCanvasInk(objects: objects).drawing.strokes.count, 300)
        let store = NotesFileRepository(directory: try folder())
        var note = NoteDocument()
        note.objects = objects
        let saved = try await store.save(NotesSnapshot(notes: [note]), expectedRevision: 0)
        let reopened = try await store.load()
        XCTAssertEqual(reopened.snapshot, saved)
        XCTAssertEqual(try NoteCanvasInk(objects: reopened.snapshot.notes[0].objects).drawing.strokes.count, 300)
    }

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Notes-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func sample() -> NotesSnapshot {
        var note = NoteDocument()
        note.objects = [NoteObject(kind: .text, text: "Study"), NoteObject(kind: .ink, payload: PKDrawing().dataRepresentation())]
        return NotesSnapshot(notes: [note])
    }
    func testGroupingClampAndUngroupPreserveGeometry() throws {
        var note = sample().notes[0]
        note.objects[1] = NoteObject(kind: .shape)
        let ids = Set(note.objects.map(\.id))
        note.group(ids)
        note.move([note.objects[0].id], by: CGSize(width: -1000, height: 80))
        XCTAssertEqual(note.objects[0].frame.minX, 0)
        XCTAssertEqual(note.objects[1].frame.minX, 0)
        let frames = note.objects.map(\.frame)
        note.ungroup([note.objects[0].id])
        XCTAssertEqual(frames, note.objects.map(\.frame)); XCTAssertTrue(note.objects.allSatisfy { $0.group == nil })
        try note.validate()
    }
    func testValidationRejectsNonfiniteGeometryDuplicatesAndUnsafeLinks() {
        var note = sample().notes[0]
        note.objects[0].frame.origin.x = .infinity
        XCTAssertThrowsError(try note.validate())
        note = sample().notes[0]; note.objects.append(note.objects[0])
        XCTAssertThrowsError(try note.validate())
        note = NoteDocument(objects: [NoteObject(kind: .link, url: "javascript:alert(1)")])
        XCTAssertThrowsError(try note.validate())
    }
    @MainActor func testPrayerNoteTracksDailyPrayerCount() async throws {
        let repository = NotesFileRepository(directory: try folder())
        let session = NotesSession(repository: repository)
        await session.load()
        let id = try XCTUnwrap(session.create(kind: .prayer))
        session.open(id)
        XCTAssertTrue(session.recordPrayerTap())
        XCTAssertEqual(session.note?.prayerContent?.prayerCount, 1)
        XCTAssertFalse(session.recordPrayerTap())
        XCTAssertEqual(session.note?.prayerContent?.prayerCount, 1)
        await session.save()
        let reopened = NotesSession(repository: repository)
        await reopened.load()
        reopened.open(id)
        XCTAssertEqual(reopened.note?.prayerContent?.prayerCount, 1)
        XCTAssertFalse(reopened.recordPrayerTap())
    }

    func testLicensedSourceQuoteCanBeSavedWithAttribution() async throws {
        let verse = VerseID(referenceSystemID: "org.sophia.api.bible.example", book: "JHN", chapter: 3, verse: 16)
        let quote = NoteQuote(verse: verse, editionID: "api.bible.example", contentRevision: "fixture", attribution: "Fixture", source: "Licensed fixture text")
        var note = NoteDocument()
        note.objects = [NoteObject(kind: .quote, quote: quote)]
        try note.validate()
        let store = NotesFileRepository(directory: try folder())
        let saved = try await store.save(NotesSnapshot(notes: [note]), expectedRevision: 0)
        let load = try await store.load()
        XCTAssertEqual(load.snapshot.notes[0].objects[0].quote, quote)
        XCTAssertEqual(saved.schemaVersion, 3)
        note.objects[0].kind = .text
        XCTAssertThrowsError(try note.validate())
    }
    func testInterruptedCommitRetainsPriorRevision() async throws {
        for boundary in NotesFileRepository.Boundary.allCases {
            let directory = try folder(), normal = NotesFileRepository(directory: directory)
            let first = try await normal.save(sample(), expectedRevision: 0)
            let interrupted = NotesFileRepository(directory: directory) { reached in
                if reached == boundary { throw NotesError.invalid }
            }
            var next = first; next.notes[0].title = "Interrupted"
            do { _ = try await interrupted.save(next, expectedRevision: first.revision); XCTFail("Expected interruption") } catch {}
            let reopened = try await normal.load()
            XCTAssertEqual(reopened.snapshot, first)
        }
    }
    func testCorruptionRecoversPreviousAndUnknownSchemaIsPreserved() async throws {
        let directory = try folder(), store = NotesFileRepository(directory: directory)
        let first = try await store.save(sample(), expectedRevision: 0)
        var second = first; second.notes[0].title = "Second"
        _ = try await store.save(second, expectedRevision: 1)
        let current = directory.appendingPathComponent("current.json")
        let pointer = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: current)) as? [String: Any])
        let id = try XCTUnwrap(pointer["id"] as? String)
        try Data("damaged".utf8).write(to: directory.appendingPathComponent(id + ".notes"))
        let result = try await store.load()
        XCTAssertTrue(result.recovered); XCTAssertEqual(result.snapshot, first)
        try Data("{\"schemaVersion\":99,\"id\":\"\(UUID().uuidString)\"}".utf8).write(to: current)
        do { _ = try await store.load(); XCTFail("Unknown format must not fall back") } catch NotesError.unsupported {} catch { XCTFail("\(error)") }
    }
    func testArchiveMixedObjectsRestoreAndPreRestoreRecovery() async throws {
        let store = NotesFileRepository(directory: try folder())
        var source = sample()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).jpegData(withCompressionQuality: 0.8) { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 16, height: 16)) }
        source.notes[0].objects += [NoteObject(kind: .image, payload: image), NoteObject(kind: .table, cells: [["A", "B"]]), NoteObject(kind: .link, url: "https://example.com")]
        let first = try await store.save(source, expectedRevision: 0)
        let archive = try await store.exportArchive()
        var changed = first; changed.notes[0].title = "Before restore"
        let second = try await store.save(changed, expectedRevision: first.revision)
        let restored = try await store.restore(archive, expectedRevision: second.revision)
        XCTAssertEqual(restored.notes, first.notes)
        let previous = try await store.preRestoreArchive()
        let recovered = try await store.restore(previous, expectedRevision: restored.revision)
        XCTAssertEqual(recovered.notes, second.notes)
        do { _ = try await store.restore(Data("bad".utf8), expectedRevision: recovered.revision); XCTFail() } catch {}
        let unchanged = try await store.load(); XCTAssertEqual(unchanged.snapshot, recovered)
    }
    func testStaleWriteAndInvalidMediaDoNotReplaceGoodData() async throws {
        let store = NotesFileRepository(directory: try folder())
        let first = try await store.save(sample(), expectedRevision: 0)
        do { _ = try await store.save(sample(), expectedRevision: 0); XCTFail() } catch NotesError.stale {} catch { XCTFail() }
        var bad = first; bad.notes[0].objects.append(NoteObject(kind: .image, payload: Data("not image".utf8)))
        do { _ = try await store.save(bad, expectedRevision: first.revision); XCTFail() } catch {}
        let actual = try await store.load(); XCTAssertEqual(actual.snapshot, first)
    }
    @MainActor func testSessionArbitraryObjectsUndoDeleteAndReopen() async throws {
        let repository = NotesFileRepository(directory: try folder())
        // Use a shared repository for the reopen boundary.
        let editor = NotesSession(repository: repository)
        await editor.load(); XCTAssertNotNil(editor.create(kind: .canvas))
        editor.insert(.text); editor.insert(.link, url: "https://example.com"); editor.insert(.table); editor.insert(.shape)
        XCTAssertEqual(editor.note?.objects.count, 4)
        editor.selection = Set(editor.note!.objects.prefix(2).map(\.id)); editor.group()
        let before = editor.note!.objects.map(\.frame)
        editor.move(CGSize(width: 120, height: 60)); editor.undo()
        XCTAssertEqual(editor.note!.objects.map(\.frame), before)
        editor.redo(); XCTAssertNotEqual(editor.note!.objects.map(\.frame), before)
        let id = editor.selectedNoteID!
        await editor.save(); XCTAssertFalse(editor.dirty)
        editor.archive(id); await editor.save()
        let reopened = NotesSession(repository: repository); await reopened.load()
        XCTAssertTrue(reopened.snapshot.notes.first?.isArchived == true)
        reopened.unarchive(id); reopened.open(id)
        XCTAssertEqual(reopened.note?.objects.count, 4)
    }
    func testRealInkAndSourceQuoteRoundTrip() async throws {
        let points = [CGPoint(x: 15, y: 15), CGPoint(x: 90, y: 50), CGPoint(x: 140, y: 35)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
        let drawing = PKDrawing(strokes: [stroke]).dataRepresentation()
        let quote = NoteQuote(verse: VerseID(book: "JHN", chapter: 3, verse: 16), editionID: "web.engwebp", contentRevision: "fixture", attribution: "WEB", source: "Fixture source text")
        var value = sample(); value.notes[0].objects[1].payload = drawing
        value.notes[0].objects.append(NoteObject(kind: .quote, text: "My commentary", quote: quote))
        let store = NotesFileRepository(directory: try folder())
        _ = try await store.save(value, expectedRevision: 0)
        let archive = try await store.exportArchive()
        let other = NotesFileRepository(directory: try folder())
        let restored = try await other.restore(archive, expectedRevision: 0)
        XCTAssertEqual(restored.notes[0].objects[1].payload, drawing)
        XCTAssertEqual(try PKDrawing(data: restored.notes[0].objects[1].payload).strokes.count, 1)
        XCTAssertEqual(restored.notes[0].objects[2].quote, quote)
        XCTAssertEqual(restored.notes[0].objects[2].text, "My commentary")
    }
    @MainActor func testFailedAutosaveKeepsDirtyEditsAndRetryPersists() async throws {
        let repository = FailOnceNotesRepository(base: NotesFileRepository(directory: try folder()))
        let session = NotesSession(repository: repository)
        await session.load(); session.create(kind: .canvas); session.insert(.text)
        let id = try XCTUnwrap(session.selection.first)
        session.update(id) { $0.text = "Keep this edit" }
        await session.save()
        XCTAssertTrue(session.dirty); XCTAssertNotNil(session.notice)
        XCTAssertEqual(session.note?.objects.first?.text, "Keep this edit")
        await session.save(); XCTAssertFalse(session.dirty)
        let reopened = try await repository.load()
        XCTAssertEqual(reopened.snapshot.notes.first?.objects.first?.text, "Keep this edit")
    }

    func testCitationRangesFollowTypingWithoutChangingInkOrObjects() throws {
        let quote = NoteQuote(verse: VerseID(book: "JHN", chapter: 3, verse: 16), editionID: "web.engwebp", contentRevision: "fixture", attribution: "WEB", source: "Fixture Scripture")
        var page = NotePage(); page.insert(quote, at: 0)
        let first = page.citations[0]
        page.replace(NSRange(location: 0, length: 0), with: "My reflection 🙂\n")
        XCTAssertEqual(page.citations[0].location, first.location + "My reflection 🙂\n".utf16.count)
        let reference = (page.body as NSString).substring(with: NSRange(location: page.citations[0].location, length: page.citations[0].length))
        XCTAssertEqual(reference, "JHN 3:16 · WEB")
        page.replace(NSRange(location: page.citations[0].location + 1, length: 1), with: "x")
        XCTAssertTrue(page.citations.isEmpty)
    }
    @MainActor func testFixedPageInkAndObjectsSurviveBodyEditsAndReopen() async throws {
        let store = NotesFileRepository(directory: try folder())
        let editor = NotesSession(repository: store)
        await editor.load(); let id = try XCTUnwrap(editor.create())
        editor.replaceBody(NSRange(location: 0, length: 0), with: "My study\n")
        let ink = drawing(outsideOldBox: true)
        editor.updatePageInk(ink)
        editor.edit { $0.objects.append(NoteObject(kind: .shape)) }; editor.selection = [editor.note!.objects[0].id]; let objectID = try XCTUnwrap(editor.selection.first)
        let frame = editor.note!.objects[0].frame
        editor.replaceBody(NSRange(location: 0, length: 0), with: "Added above\n")
        XCTAssertEqual(editor.note!.page!.ink, ink)
        XCTAssertEqual(editor.note!.objects[0].frame, frame)
        editor.move(CGSize(width: 80, height: 40))
        XCTAssertEqual(editor.note!.page!.ink, ink)
        XCTAssertEqual(editor.note!.page!.width, 1200)
        editor.undo(); XCTAssertEqual(editor.note!.objects[0].frame, frame)
        editor.selection = [objectID]; editor.resize(objectID, width: 400, height: 280)
        XCTAssertEqual(editor.note!.page!.body, "Added above\nMy study\n")
        await editor.save(); XCTAssertFalse(editor.dirty)
        let reopened = NotesSession(repository: store); await reopened.load(); reopened.open(id)
        XCTAssertEqual(reopened.note!.page, editor.note!.page)
        XCTAssertEqual(reopened.note!.objects, editor.note!.objects)
    }
    private func drawing(outsideOldBox: Bool = false) -> Data {
        let points = [CGPoint(x: 15, y: 15), CGPoint(x: 90, y: 50), CGPoint(x: outsideOldBox ? 1000 : 140, y: outsideOldBox ? 800 : 35)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))]).dataRepresentation()
    }
    func testInkBeyondFormerHandwritingBoxSavesAndRoundTrips() async throws {
        var value = sample(); value.notes[0].objects[1].payload = drawing(outsideOldBox: true)
        let store = NotesFileRepository(directory: try folder())
        let saved = try await store.save(value, expectedRevision: 0)
        let loaded = try await store.load()
        XCTAssertEqual(saved, loaded.snapshot)
    }
    @MainActor func testLegacyCanvasRemainsCanvasWithoutChangingInkOrGeometry() async throws {
        let store = NotesFileRepository(directory: try folder())
        var value = sample(); value.notes[0].objects[1].payload = drawing(outsideOldBox: true)
        _ = try await store.save(value, expectedRevision: 0)
        let editor = NotesSession(repository: store); await editor.load(); editor.open(value.notes[0].id)
        XCTAssertEqual(editor.note?.kind, .canvas)
        XCTAssertNil(editor.note?.page)
        XCTAssertEqual(editor.note?.objects, value.notes[0].objects)
        XCTAssertFalse(editor.dirty, "Opening a Canvas must not convert or autosave it")
    }
    func testOriginalLegacyGenerationsRetainedBeforeV3Save() async throws {
        for version in [1, 2] {
            let directory = try folder(), id = UUID()
            var source = sample(); source.schemaVersion = version
            if version == 2 {
                let legacyObjects = source.notes[0].objects.filter { $0.kind != .ink }
                source.notes[0].content = .page(PageContent(page: NotePage(), legacyObjects: legacyObjects))
            }
            // Encode the historical wire shape, not today's tagged model.
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source)) as? [String: Any])
            var notes = try XCTUnwrap(json["notes"] as? [[String: Any]])
            notes[0].removeValue(forKey: "content")
            notes[0]["objects"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(source.notes[0].objects))
            if let page = source.notes[0].page { notes[0]["page"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(page)) }
            json["notes"] = notes
            let payload = try JSONSerialization.data(withJSONObject: json)
            let original = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "payload": payload.base64EncodedString(), "checksum": SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()])
            try original.write(to: directory.appendingPathComponent(id.uuidString + ".notes"))
            try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "id": id.uuidString]).write(to: directory.appendingPathComponent("current.json"))
            let olderBackup = Data("already retained v1".utf8)
            try olderBackup.write(to: directory.appendingPathComponent("before-study-page.notes"))
            let store = NotesFileRepository(directory: directory)
            let loaded = try await store.load()
            XCTAssertEqual(loaded.snapshot.notes, source.notes)
            let saved = try await store.save(loaded.snapshot, expectedRevision: 0)
            XCTAssertEqual(saved.schemaVersion, 3)
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("before-note-types.notes")), original)
            XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("before-study-page.notes")), olderBackup)
            XCTAssertEqual(saved.notes[0].kind, version == 1 ? .canvas : .page)
        }
    }
    func testCanvasInkMovesGroupsResizesAndErasesWithStableIdentity() throws {
        var note = sample().notes[0]
        note.objects[1].payload = drawing()
        let old = note.objects[1]
        note.group(Set(note.objects.map(\.id)))
        XCTAssertNotNil(note.objects[1].group)
        note.move([old.id], by: CGSize(width: 200, height: 100))
        XCTAssertEqual(note.objects[1].frame.minX, old.frame.minX + 200)
        let scene = try NoteCanvasInk(objects: note.objects)
        XCTAssertEqual(scene.objects(after: scene.drawing, replacing: note.objects), note.objects)
        let erased = scene.objects(after: PKDrawing(), replacing: note.objects)
        XCTAssertEqual(erased.count, 1); XCTAssertNil(erased[0].group)
        let created = try NoteCanvasInk(objects: []).objects(after: PKDrawing(data: drawing()), replacing: [])
        XCTAssertEqual(created.count, 1)
        var resized = created; resized[0].frame.size.width *= 2; resized[0].frame.size.height *= 2
        let before = try NoteCanvasInk(objects: created).drawing.bounds
        let after = try NoteCanvasInk(objects: resized).drawing.bounds
        XCTAssertEqual(after.width, before.width * 2, accuracy: 3) // Render bounds round outward to pixels.
        XCTAssertEqual(after.height, before.height * 2, accuracy: 3)
    }
    func testDuplicateLegacyDrawingsKeepIndependentOwnership() throws {
        let ink = drawing()
        let first = NoteObject(kind: .ink, payload: ink)
        var second = NoteObject(kind: .ink, payload: ink); second.frame.origin.x += 400
        let scene = try NoteCanvasInk(objects: [first, second])
        XCTAssertEqual(scene.objects(after: scene.drawing, replacing: [first, second]), [first, second])
        let erased = PKDrawing(strokes: [scene.drawing.strokes[1]])
        XCTAssertEqual(scene.objects(after: erased, replacing: [first, second]), [second])
    }

    @MainActor func testPageInlineAttachmentsLinksUndoAndReopen() async throws {
        let store = NotesFileRepository(directory: try folder()), session = NotesSession(repository: NotesFileRepository(directory: try folder()))
        await session.load(); session.create(kind: .page)
        session.insert(.table)
        XCTAssertEqual(session.note?.page?.attachments.count, 1); XCTAssertTrue(session.note!.objects.isEmpty)
        session.replaceBody(NSRange(location: 0, length: 0), with: "Reflection 🙂\n")
        XCTAssertEqual(session.note?.page?.attachments[0].location, "Reflection 🙂\n".utf16.count)
        let table = try XCTUnwrap(session.note?.page?.attachments.first)
        session.update(table.id) { $0.cells[0][0] = "Faith" }
        session.bodySelection = NSRange(location: session.note!.page!.body.utf16.count, length: 0)
        session.insert(.link, url: "https://example.com")
        XCTAssertTrue(session.note!.page!.body.contains("https://example.com"))
        XCTAssertTrue(session.note!.objects.isEmpty)
        session.insert(.shape); XCTAssertTrue(session.note!.objects.isEmpty)
        session.selection = [table.id]; session.remove()
        XCTAssertTrue(session.note!.page!.attachments.isEmpty)
        session.undo(); XCTAssertEqual(session.note!.page!.attachments.first?.object.cells[0][0], "Faith")
        let saved = try await store.save(session.snapshot, expectedRevision: 0)
        let loaded = try await store.load(); XCTAssertEqual(loaded.snapshot, saved)
        var bad = saved.notes[0]; bad.objects.append(NoteObject(kind: .ink))
        XCTAssertThrowsError(try bad.validate())
        bad = saved.notes[0]; bad.page!.attachments[0].location = 99999
        XCTAssertThrowsError(try bad.validate())
    }
    @MainActor func testCanvasQuoteIsObjectPageQuoteIsInlineAndArchiveContainsOnePayload() async throws {
        let quote = NoteQuote(verse: VerseID(book: "JHN", chapter: 3, verse: 16), editionID: "web.engwebp", contentRevision: "fixture", attribution: "WEB", source: "Fixture")
        let session = NotesSession(repository: NotesFileRepository(directory: try folder()))
        await session.load(); session.create(kind: .canvas); session.appendQuote(quote)
        XCTAssertEqual(session.note?.objects.first?.quote, quote); XCTAssertNil(session.note?.page)
        session.create(kind: .page); session.appendQuote(quote)
        XCTAssertEqual(session.note?.page?.citations.first?.quote, quote); XCTAssertTrue(session.note!.objects.isEmpty)
        for note in session.snapshot.notes {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as? [String: Any])
            XCTAssertNil(json["objects"]); XCTAssertNil(json["page"])
            let content = try XCTUnwrap(json["content"] as? [String: Any])
            XCTAssertEqual(content["kind"] as? String, note.kind.rawValue)
            XCTAssertEqual(content.count, 2)
        }
    }
    @MainActor func testQuoteCanBeAddedToAnExplicitExistingNote() async throws {
        let quote = NoteQuote(verse: VerseID(book: "ROM", chapter: 8, verse: 1), editionID: "web.engwebp", contentRevision: "fixture", attribution: "WEB", source: "Fixture")
        let session = NotesSession(repository: NotesFileRepository(directory: try folder()))
        await session.load()
        let pageID = try XCTUnwrap(session.create(kind: .page))
        let canvasID = try XCTUnwrap(session.create(kind: .canvas))

        session.open(pageID)
        session.appendQuote(quote)

        XCTAssertEqual(session.selectedNoteID, pageID)
        XCTAssertEqual(session.snapshot.notes.count, 2)
        XCTAssertEqual(session.snapshot.notes.first { $0.id == pageID }?.page?.citations.first?.quote, quote)
        XCTAssertTrue(session.snapshot.notes.first { $0.id == canvasID }?.objects.isEmpty == true)
    }
    @MainActor func testPageQuoteAppendsAfterExistingBodyWhenThereIsNoActiveCaret() async throws {
        let quote = NoteQuote(verse: VerseID(book: "ROM", chapter: 8, verse: 1), editionID: "web.engwebp", contentRevision: "fixture", attribution: "WEB", source: "Fixture")
        let session = NotesSession(repository: NotesFileRepository(directory: try folder()))
        await session.load()
        _ = session.create(kind: .page)
        session.replaceBody(NSRange(location: 0, length: 0), with: "Existing reflection\n")
        session.open(try XCTUnwrap(session.selectedNoteID))

        session.appendQuote(quote)

        let page = try XCTUnwrap(session.note?.page)
        XCTAssertTrue(page.body.hasPrefix("Existing reflection\n"))
        XCTAssertEqual(page.citations.first?.location,
                       "Existing reflection\n\n\nFixture\n".utf16.count)
    }

    func testSemanticInkAdaptsWithoutChangingGeometryOrUneditedPayload() throws {
        var original = try PKDrawing(data: drawing())
        original.strokes = original.strokes.map { value in var stroke = value; stroke.ink = PKInk(.pen, color: .white); return stroke }
        let light = NoteInkAppearance.canonicalDrawing(original)
        let dark = NoteInkAppearance.canonicalDrawing(original)
        XCTAssertEqual(light.bounds, original.bounds); XCTAssertEqual(dark.bounds, original.bounds)
        XCTAssertEqual(light.strokes[0].ink.color, dark.strokes[0].ink.color) // PencilKit performs appearance adaptation.
        let object = NoteObject(kind: .ink, payload: original.dataRepresentation())
        let scene = try NoteCanvasInk(objects: [object], traits: UITraitCollection(userInterfaceStyle: .light))
        XCTAssertEqual(scene.objects(after: scene.drawing, replacing: [object]), [object])
        original.strokes = original.strokes.map { value in var stroke = value; stroke.ink = PKInk(.pen, color: .systemRed); return stroke }
        XCTAssertEqual(NoteInkAppearance.canonicalDrawing(original).strokes[0].ink.color, original.strokes[0].ink.color)
    }
    @MainActor func testInkPixelsRemainReadableAcrossDarkLightDark() throws {
        var source = try PKDrawing(data: drawing())
        source.strokes = source.strokes.map { value in var stroke = value; stroke.ink = PKInk(.pen, color: .white); return stroke }
        let saved = source.dataRepresentation()
        for style: UIUserInterfaceStyle in [.dark, .light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let rendered = NoteInkAppearance.image(source, from: source.bounds, scale: 2, traits: traits)
            let image = try XCTUnwrap(rendered.cgImage)
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = try XCTUnwrap(CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let solid = stride(from: 0, to: pixels.count, by: 4).filter { pixels[$0 + 3] > 200 }
            XCTAssertFalse(solid.isEmpty)
            let brightness = solid.reduce(0.0) { $0 + Double(pixels[$1]) / Double(pixels[$1 + 3]) } / Double(max(1, solid.count))
            if style == .dark { XCTAssertGreaterThan(brightness, 0.75, "Dark-mode ink must render light") }
            else { XCTAssertLessThan(brightness, 0.25, "Light-mode ink must render dark") }
        }
        XCTAssertEqual(source.dataRepresentation(), saved)
    }
    @MainActor func testStyledObjectsDuplicateUndoAndArchive() async throws {
        let store = NotesFileRepository(directory: try folder())
        let session = NotesSession(repository: store); await session.load(); session.create(kind: .canvas)
        session.insertionPoint = CGPoint(x: 2200, y: 3400)
        session.insert(.shape, shape: .star, tint: .purple)
        let original = try XCTUnwrap(session.note?.objects.first)
        XCTAssertEqual(original.frame.midX, 2200); XCTAssertEqual(original.frame.midY, 3400)
        session.duplicateSelection(); XCTAssertEqual(session.note?.objects.count, 2)
        XCTAssertNotEqual(session.note?.objects[1].id, original.id)
        XCTAssertEqual(session.note?.objects[1].shape, .star)
        session.undo(); XCTAssertEqual(session.note?.objects, [original])
        session.redo(); XCTAssertEqual(session.note?.objects.count, 2)
        session.insert(.sticker, sticker: "🌿")
        session.metadata(title: "Study", tags: "", paper: .dotted)
        session.setColor(.sage)
        await session.save()
        let reopened = try await store.load()
        XCTAssertEqual(reopened.snapshot.notes.first, session.note)
        XCTAssertEqual(reopened.snapshot.notes.first?.color, .sage)
        XCTAssertEqual(reopened.snapshot.notes.first?.objects.last?.text, "🌿")
    }
    @MainActor func testCachedLinkThumbnailValidationAndRoundTrip() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.systemBlue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }.pngData()!
        let store = NotesFileRepository(directory: try folder())
        let note = NoteDocument(objects: [NoteObject(kind: .link, text: "Saved preview", url: "https://example.com", payload: image)])
        let saved = try await store.save(NotesSnapshot(notes: [note]), expectedRevision: 0)
        let reopened = try await store.load(); XCTAssertEqual(reopened.snapshot, saved)
        var invalid = saved; invalid.notes[0].objects[0].payload = Data("not an image".utf8)
        do { _ = try await store.save(invalid, expectedRevision: saved.revision); XCTFail("Invalid thumbnail accepted") } catch {}
    }

    func testLegacyObjectsDecodeWithoutNewEditorFields() throws {
        for kind in [NoteObject.Kind.text, .ink, .image, .table, .link] {
            let original = NoteObject(kind: kind, text: "Existing content", payload: Data([1, 2, 3]))
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
            for key in ["monospaced", "positionLocked", "details"] { json.removeValue(forKey: key) }
            let decoded = try JSONDecoder().decode(NoteObject.self, from: JSONSerialization.data(withJSONObject: json))
            XCTAssertEqual(decoded, original)
            var edited = decoded
            edited.monospaced = true
            edited.positionLocked = true
            edited.details = "Saved details"
            XCTAssertEqual(try JSONDecoder().decode(NoteObject.self, from: JSONEncoder().encode(edited)), edited)
        }
    }

    func testPageFormattingSurvivesEditsAndOmitsEmptySpans() throws {
        var page = NotePage()
        page.body = "Faith and hope"
        page.formatting = NoteTextFormatting.changing([], range: NSRange(location: 0, length: 5), change: .bold)
        XCTAssertEqual(page.formatting, [NoteTextSpan(location: 0, length: 5, bold: true)])
        page.replace(NSRange(location: 5, length: 0), with: "ful")
        XCTAssertEqual(page.formatting.first?.length, 8)
        page.formatting = NoteTextFormatting.changing(page.formatting, range: NSRange(location: 0, length: 8), change: .bold)
        XCTAssertTrue(page.formatting.isEmpty)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(page)) as? [String: Any]
        XCTAssertNil(encoded?["formatting"])
        page.body = "Title"
        page.formatting = [NoteTextSpan(location: 0, length: 5, level: 1)]
        let roundTrip = try JSONDecoder().decode(NotePage.self, from: JSONEncoder().encode(page))
        XCTAssertEqual(roundTrip.formatting, page.formatting)
        try NoteDocument(kind: .page, page: page).validate()
    }

    func testSanitizeRepairsInvalidFormattingAndGroups() throws {
        var page = NotePage()
        page.body = "Hello"
        page.formatting = [
            NoteTextSpan(location: 0, length: 5, bold: true, colorIndex: 99, colorHex: "BAD"),
            NoteTextSpan(location: 0, length: 5, colorIndex: 3, colorHex: "AABBCC"),
        ]
        var note = NoteDocument(kind: .page, page: page)
        note.objects = [
            NoteObject(kind: .text, text: "A", fontSize: 200, details: String(repeating: "x", count: 600)),
            NoteObject(kind: .text, group: UUID(), text: "B"),
        ]
        var snapshot = NotesSnapshot(notes: [note])
        snapshot.sanitize()
        try snapshot.validate()
        XCTAssertEqual(snapshot.notes[0].page?.formatting.count, 2)
        XCTAssertEqual(snapshot.notes[0].page?.formatting.first?.bold, true)
        XCTAssertNil(snapshot.notes[0].page?.formatting.first?.colorIndex)
        XCTAssertNil(snapshot.notes[0].page?.formatting.first?.colorHex)
        XCTAssertEqual(snapshot.notes[0].page?.formatting.last?.colorIndex, 3)
        XCTAssertNil(snapshot.notes[0].objects[1].group)
        XCTAssertEqual(snapshot.notes[0].objects[0].fontSize, 72)
    }

    func testActiveFormattingStateReflectsSelection() {
        var page = NotePage()
        page.body = "Bold plain"
        page.formatting = [NoteTextSpan(location: 0, length: 4, bold: true)]
        let boldRange = NoteTextFormatting.activeState(formatting: page.formatting, body: page.body, selection: NSRange(location: 0, length: 4))
        XCTAssertTrue(boldRange.bold)
        XCTAssertFalse(boldRange.strikethrough)
        page.formatting[0].strikethrough = true
        let strike = NoteTextFormatting.activeState(formatting: page.formatting, body: page.body, selection: NSRange(location: 1, length: 1))
        XCTAssertTrue(strike.bold)
        XCTAssertTrue(strike.strikethrough)
        let plain = NoteTextFormatting.activeState(formatting: page.formatting, body: page.body, selection: NSRange(location: 5, length: 5))
        XCTAssertFalse(plain.bold)
    }

    func testColorAndBlockQuoteFormatting() throws {
        var page = NotePage()
        page.body = "Quoted line"
        page.formatting = NoteTextFormatting.changing([], range: NSRange(location: 0, length: 7), change: .inkColor(.preset(3)))
        XCTAssertEqual(page.formatting.first?.colorIndex, 3)
        page.formatting = NoteTextFormatting.changing(page.formatting, range: NSRange(location: 0, length: 7), change: .inkColor(.hex("112233")))
        XCTAssertEqual(page.formatting.first?.colorHex, "112233")
        page.formatting = NoteTextFormatting.changing(page.formatting, range: NSRange(location: 0, length: 7), change: .inkColor(.default))
        XCTAssertTrue(page.formatting.isEmpty)
        page.formatting = NoteTextFormatting.changing([], range: NSRange(location: 0, length: 11), change: .blockQuote)
        XCTAssertEqual(page.formatting.first?.blockQuote, true)
        page.formatting = NoteTextFormatting.changing(page.formatting, range: NSRange(location: 0, length: 11), change: .blockQuote)
        XCTAssertTrue(page.formatting.isEmpty)
        try NoteDocument(kind: .page, page: page).validate()
    }

    func testListAndIndentEditCurrentLine() {
        var page = NotePage()
        page.body = "First\nSecond"
        let bullet = NoteTextFormatting.listEdit(in: page.body, line: NSRange(location: 0, length: 5), kind: .bullet)!
        page.replace(bullet.0, with: bullet.1)
        XCTAssertEqual(page.body, "• First\nSecond")
        let numbered = NoteTextFormatting.listEdit(in: page.body, line: NSRange(location: 8, length: 6), kind: .numbered)!
        page.replace(numbered.0, with: numbered.1)
        XCTAssertEqual(page.body, "• First\n1. Second")
        let indent = NoteTextFormatting.indentEdit(in: page.body, line: NSRange(location: 8, length: 9), outdent: false)!
        page.replace(indent.0, with: indent.1)
        XCTAssertEqual(page.body, "• First\n\t1. Second")
        let outdent = NoteTextFormatting.indentEdit(in: page.body, line: NSRange(location: 8, length: 10), outdent: true)!
        page.replace(outdent.0, with: outdent.1)
        XCTAssertEqual(page.body, "• First\n1. Second")
    }

    func testCheckboxTogglesTheCurrentLine() {
        var page = NotePage()
        page.body = "Remember"
        let inserted = NoteTextFormatting.checkboxEdit(in: page.body, caret: 3)
        page.replace(inserted.0, with: inserted.1)
        XCTAssertEqual(page.body, "☐ Remember")
        let checked = NoteTextFormatting.checkboxEdit(in: page.body, caret: 4)
        page.replace(checked.0, with: checked.1)
        XCTAssertTrue(page.body.hasPrefix("☑ "))
    }

    @MainActor func testAudioAttachmentRemainsInline() async throws {
        let session = NotesSession(repository: NotesFileRepository(directory: try folder()))
        await session.load()
        session.create(kind: .journal)
        session.insertAudio(Data("audio".utf8), name: "Prayer")
        let attachment = try XCTUnwrap(session.note?.page?.attachments.first)
        XCTAssertEqual(attachment.object.kind, .audio)
        XCTAssertEqual(attachment.object.text, "Prayer")
        XCTAssertEqual(session.note?.objects.isEmpty, true)
        try session.note?.validate()
    }

    @MainActor func testJournalReflectionFieldsStayOptional() async throws {
        var note = NoteDocument(kind: .journal)
        XCTAssertNil(note.journalContent?.emotionalState)
        XCTAssertNil(note.journalContent?.mentalState)
        guard case .journal(var content) = note.content else { return XCTFail("Expected a journal") }
        content.emotionalState = .happy
        content.mentalState = .atEase
        note.content = .journal(content)
        var page = note.page ?? NotePage()
        page.body = "kept"
        note.page = page
        note.objects = []
        XCTAssertEqual(note.journalContent?.emotionalState, .happy)
        XCTAssertEqual(note.journalContent?.mentalState, .atEase)
        XCTAssertEqual(note.page?.body, "kept")

        let decoded = try JSONDecoder().decode(NoteDocument.self, from: JSONEncoder().encode(note))
        XCTAssertEqual(decoded.journalContent?.emotionalState, .happy)
        XCTAssertEqual(decoded.journalContent?.mentalState, .atEase)

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(NoteDocument(kind: .journal))) as? [String: Any])
        var contentJSON = try XCTUnwrap(object["content"] as? [String: Any])
        var journal = try XCTUnwrap(contentJSON["journal"] as? [String: Any])
        XCTAssertNil(journal["emotionalState"])
        XCTAssertNil(journal["mentalState"])

        object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(note)) as? [String: Any])
        contentJSON = try XCTUnwrap(object["content"] as? [String: Any])
        journal = try XCTUnwrap(contentJSON["journal"] as? [String: Any])
        journal.removeValue(forKey: "emotionalState")
        journal.removeValue(forKey: "mentalState")
        contentJSON["journal"] = journal
        object["content"] = contentJSON
        let legacy = try JSONDecoder().decode(NoteDocument.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(legacy.journalContent?.emotionalState)
        XCTAssertNil(legacy.journalContent?.mentalState)
        XCTAssertEqual(legacy.page?.body, "kept")

        journal["emotionalState"] = "not-a-feeling"
        journal["mentalState"] = JournalMentalState.challenged.rawValue
        contentJSON["journal"] = journal
        object["content"] = contentJSON
        let unknown = try JSONDecoder().decode(NoteDocument.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(unknown.journalContent?.emotionalState)
        XCTAssertEqual(unknown.journalContent?.mentalState, .challenged)
        XCTAssertEqual(unknown.journalContent?.mentalState?.meaning, "Facing something difficult and working through it.")

        XCTAssertEqual(JournalEmotionalState.allCases.count, 39)
        XCTAssertTrue(JournalEmotionalState.allCases.contains(.neutral))
        XCTAssertEqual(JournalMentalState.allCases.count, 21)
        XCTAssertEqual(JournalMentalState.allCases.last, .challenged)

        let session = NotesSession(repository: NotesFileRepository(directory: try folder()))
        await session.load()
        session.create(kind: .journal)
        session.setJournalEmotionalState(.guilty)
        session.setJournalMentalState(.thriving)
        XCTAssertEqual(session.note?.journalContent?.emotionalState, .guilty)
        XCTAssertEqual(session.note?.journalContent?.mentalState, .thriving)
        XCTAssertTrue(session.note?.searchableText.localizedCaseInsensitiveContains("Guilty") == true)
        XCTAssertTrue(session.note?.searchableText.localizedCaseInsensitiveContains("energized") == true)
        session.setJournalEmotionalState(nil)
        session.setJournalMentalState(nil)
        XCTAssertNil(session.note?.journalContent?.emotionalState)
        XCTAssertNil(session.note?.journalContent?.mentalState)
        try session.note?.validate()
    }

}

private actor FailOnceNotesRepository: NotesRepository {
    let base: NotesFileRepository
    var shouldFail = true
    init(base: NotesFileRepository) { self.base = base }
    func load() async throws -> NotesLoad { try await base.load() }
    func save(_ value: NotesSnapshot, expectedRevision: Int) async throws -> NotesSnapshot {
        if shouldFail { shouldFail = false; throw NotesError.invalid }
        return try await base.save(value, expectedRevision: expectedRevision)
    }
    func exportArchive() async throws -> Data { try await base.exportArchive() }
    func restore(_ data: Data, expectedRevision: Int) async throws -> NotesSnapshot { try await base.restore(data, expectedRevision: expectedRevision) }
    func preRestoreArchive() async throws -> Data { try await base.preRestoreArchive() }
    func resetStorage() async throws { try await base.resetStorage() }
}
