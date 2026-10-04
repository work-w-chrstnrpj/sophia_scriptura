import XCTest
import UIKit
@testable import SophiaScriptura

final class ScriptureReaderTests: XCTestCase {
    private func repository() -> BundledScriptureRepository { BundledScriptureRepository(bundle:Bundle(for:ReaderSession.self)) }
    func testEveryBookFirstAndLastChapterAndPassageResolution() async throws {
        let repository = repository()
        let books = try await repository.books()
        XCTAssertEqual(books.count,66)
        for book in books {
            for chapter in Set([1,book.chapterCount]) {
                let document = try await repository.chapter(book:book.id,number:chapter)
                XCTAssertFalse(document.verseNumbers.isEmpty)
                XCTAssertTrue(document.blocks.contains { $0.kind == "body" })
                let verse = document.verse(document.verseNumbers[0])
                let resolved = try await repository.resolve(PassageRange(start:verse,end:verse))
                XCTAssertFalse(resolved.isEmpty)
            }
        }
        let range = PassageRange(start:VerseID(book:"GEN",chapter:1,verse:31),end:VerseID(book:"GEN",chapter:2,verse:2))
        let resolved = try await repository.resolve(range)
        XCTAssertTrue(resolved.contains { $0.id.hasPrefix("GEN.1.") })
        XCTAssertTrue(resolved.contains { $0.id.hasPrefix("GEN.2.") })
    }
    func testCorruptMissingAndFutureArtifactsAreRejected() async throws {
        let bundle = Bundle(for:ReaderSession.self)
        let database = try XCTUnwrap(bundle.url(forResource:"web-engwebp",withExtension:"sqlite"))
        let manifest = try XCTUnwrap(bundle.url(forResource:"web-engwebp.manifest",withExtension:"json"))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let corrupt = folder.appendingPathComponent("corrupt.sqlite")
        try Data("bad".utf8).write(to:corrupt)
        let future = folder.appendingPathComponent("future.json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:manifest)) as? [String:Any])
        object["schemaVersion"] = 2
        try JSONSerialization.data(withJSONObject:object).write(to:future)
        let cases: [(URL?,URL?,ScriptureError)] = [(nil,manifest,.artifactMissing),(corrupt,manifest,.integrityMismatch),(database,future,.incompatibleSchema)]
        for (db,meta,expected) in cases {
            do { _ = try await BundledScriptureRepository(databaseURL:db,manifestURL:meta).books(); XCTFail("Accepted invalid artifact") }
            catch { XCTAssertEqual(error as? ScriptureError,expected) }
        }
    }
    func testRangeOverlapUsesCanonOrderAndRejectsReversedRanges() throws {
        let order = ["GEN":1,"EXO":2]
        let a = PassageRange(start:VerseID(book:"GEN",chapter:50,verse:26),end:VerseID(book:"EXO",chapter:1,verse:5))
        let b = PassageRange(start:VerseID(book:"EXO",chapter:1,verse:1),end:VerseID(book:"EXO",chapter:1,verse:3))
        XCTAssertTrue(try a.overlaps(b,bookOrder:order))
        XCTAssertThrowsError(try PassageRange(start:a.end,end:a.start).overlaps(b,bookOrder:order))
    }
    func testPartialUnicodeAndRepeatedSelectionExcludesLabelsNotesHeadings() throws {
        let blocks = [
            ScriptureBlock(id:"h",kind:"heading",text:"Heading",label:"",verses:[],style:"d"),
            ScriptureBlock(id:"l1",kind:"label",text:"1",label:"1",verses:[1],style:"p"),
            ScriptureBlock(id:"a",kind:"body",text:"Same é 👋 text.",label:"1",verses:[1],style:"p"),
            ScriptureBlock(id:"n",kind:"note",text:"Footnote",label:"1",verses:[1],style:"f"),
            ScriptureBlock(id:"l2",kind:"label",text:"3-4",label:"3-4",verses:[3,4],style:"p"),
            ScriptureBlock(id:"b",kind:"body",text:"Same é 👋 text.",label:"3-4",verses:[3,4],style:"p")]
        let doc = ChapterDocument(schemaVersion:1,editionID:"web.engwebp",contentRevision:"test",book:"GEN",chapter:1,blocks:blocks)
        let map = ChapterTextMap(document:doc)
        let whole = map.selection(in:NSRange(location:0,length:map.text.utf16.count))
        XCTAssertEqual(whole.text,"Same é 👋 text. Same é 👋 text.")
        XCTAssertEqual(whole.passages.map(\.start.verse),[1,3,4])
        let body = try XCTUnwrap(map.runs.last)
        let selection = map.selection(in:NSRange(location:body.range.location+5,length:5))
        XCTAssertEqual(selection.text,"é 👋")
        XCTAssertEqual(selection.passages.map(\.start.verse),[3,4])
    }
    func testOLAExpandsWordAndPhraseToFullInvolvedVersesWithoutNotesOrHeadings() throws {
        let blocks = [
            ScriptureBlock(id: "h", kind: "heading", text: "Heading", label: "", verses: [], style: "d"),
            ScriptureBlock(id: "l1", kind: "label", text: "1", label: "1", verses: [1], style: "p"),
            ScriptureBlock(id: "a", kind: "body", text: "First target line.", label: "1", verses: [1], style: "p"),
            ScriptureBlock(id: "n", kind: "note", text: "Private footnote", label: "1", verses: [1], style: "f"),
            ScriptureBlock(id: "br", kind: "break", text: "", label: "1", verses: [1], style: "p"),
            ScriptureBlock(id: "b", kind: "body", text: "Second line.", label: "1", verses: [1], style: "p"),
            ScriptureBlock(id: "l2", kind: "label", text: "2–3", label: "2–3", verses: [2, 3], style: "p"),
            ScriptureBlock(id: "c", kind: "body", text: "Bridged é words.", label: "2–3", verses: [2, 3], style: "p"),
            ScriptureBlock(id: "l4", kind: "label", text: "4", label: "4", verses: [4], style: "p"),
            ScriptureBlock(id: "d", kind: "body", text: "Unrelated next verse.", label: "4", verses: [4], style: "p")
        ]
        let map = ChapterTextMap(document: ChapterDocument(
            schemaVersion: 1, editionID: "web.engwebp", contentRevision: "test", book: "GEN", chapter: 1, blocks: blocks
        ))
        let source = map.text as NSString
        let word = map.selection(in: source.range(of: "target"))
        XCTAssertEqual(word.text, "target")
        let wordContext = try XCTUnwrap(map.fullVerseSelection(for: word))
        XCTAssertEqual(wordContext.text, "First target line.\nSecond line.")
        XCTAssertEqual(wordContext.passages.map(\.start.verse), [1])
        let phraseRange = NSRange(location: source.range(of: "target").location,
                                  length: NSMaxRange(source.range(of: "é words")) - source.range(of: "target").location)
        let phrase = map.selection(in: phraseRange)
        let phraseContext = try XCTUnwrap(map.fullVerseSelection(for: phrase))
        XCTAssertEqual(phraseContext.text, "First target line.\nSecond line. Bridged é words.")
        XCTAssertEqual(phraseContext.passages.map(\.start.verse), [1, 2, 3])
        XCTAssertFalse(phraseContext.text.contains("Heading"))
        XCTAssertFalse(phraseContext.text.contains("footnote"))
        XCTAssertFalse(phraseContext.text.contains("Unrelated"))
        let stale = ChapterTextMap.Selection(
            text: word.text, editionID: "other", contentRevision: "test",
            sourceLabels: word.sourceLabels, passages: word.passages
        )
        XCTAssertNil(map.fullVerseSelection(for: stale))
        let empty = map.selection(in: source.range(of: "Heading"))
        XCTAssertNil(map.fullVerseSelection(for: empty))
    }

    @MainActor func testWholeVerseFocusExcludesNotesAndClearsAfterRapidJumps() async throws {
        let blocks = [
            ScriptureBlock(id:"l",kind:"label",text:"1",label:"1",verses:[1],style:"p"),
            ScriptureBlock(id:"a",kind:"body",text:"é 👋 First line.",label:"1",verses:[1],style:"q1"),
            ScriptureBlock(id:"n",kind:"note",text:"Note",label:"1",verses:[1],style:"f"),
            ScriptureBlock(id:"b",kind:"body",text:"Second line.",label:"1",verses:[1],style:"q2"),
            ScriptureBlock(id:"c",kind:"body",text:"Next verse.",label:"2-3",verses:[2,3],style:"p")]
        let map = ChapterTextMap(document:ChapterDocument(schemaVersion:1,editionID:"web.engwebp",contentRevision:"test",book:"GEN",chapter:1,blocks:blocks))
        XCTAssertEqual(map.focusRanges(for:1),[map.runs[0].range,map.runs[1].range,map.runs[3].range])
        XCTAssertEqual(map.focusRanges(for:2),map.focusRanges(for:3))
        let view = ContinuousReaderTextView()
        view.map = map
        view.attributedText = NSAttributedString(string:map.text)
        view.focus(verse:1)
        for run in map.runs {
            let colored = view.textStorage.attribute(.backgroundColor,at:run.range.location,effectiveRange:nil) != nil
            XCTAssertEqual(colored,["l","a","b"].contains(run.block.id))
        }
        view.focus(verse:2)
        XCTAssertNil(view.textStorage.attribute(.backgroundColor,at:map.runs[1].range.location,effectiveRange:nil))
        XCTAssertNotNil(view.textStorage.attribute(.backgroundColor,at:map.runs[4].range.location,effectiveRange:nil))
        try await Task.sleep(for:.seconds(1.8))
        XCTAssertNil(view.textStorage.attribute(.backgroundColor,at:map.runs[4].range.location,effectiveRange:nil))
        XCTAssertEqual(view.text,map.text)
    }

    func testPartialHighlightKeepsEllipsesInsteadOfTheWholeVerse() {
        let blocks = [
            ScriptureBlock(id: "l2", kind: "label", text: "2", label: "2", verses: [2], style: "p"),
            ScriptureBlock(id: "b2", kind: "body", text: "Before sample verse etc.", label: "2", verses: [2], style: "p"),
            ScriptureBlock(id: "l3", kind: "label", text: "3", label: "3", verses: [3], style: "p"),
            ScriptureBlock(id: "b3", kind: "body", text: "And it was continue until night.", label: "3", verses: [3], style: "p")
        ]
        let map = ChapterTextMap(document: ChapterDocument(schemaVersion: 1, editionID: "web.engwebp", contentRevision: "test", book: "GEN", chapter: 1, blocks: blocks))
        let source = map.text as NSString
        let start = source.range(of: "sample").location
        let end = source.range(of: "continue")
        let range = NSRange(location: start, length: NSMaxRange(end) - start)
        let excerpt = map.excerpt(in: range)
        XCTAssertEqual(excerpt?.text, "2...sample verse etc. 3 And it was continue...")
        XCTAssertEqual(excerpt?.startVerse, 2)
        XCTAssertEqual(excerpt?.endVerse, 3)
        let whole = map.focusRanges(for: 2)
        let covered = NSUnionRange(whole.first!, whole.last!)
        XCTAssertEqual(map.excerpt(in: covered)?.text.hasPrefix("2 Before"), true)
        XCTAssertFalse(map.excerpt(in: covered)?.text.contains("...") == true)
    }
    @MainActor func testPickerPreviewDoesNotSaveOrNavigate() async throws {
        let store = MemoryReaderState()
        let session = ReaderSession(content:repository(),state:store)
        await session.start()
        let saved = store.snapshot.location
        let saves = store.saves
        let verses = try await session.availableVerses(book:"GEN",chapter:1)
        XCTAssertEqual(verses.last,31)
        _ = try await session.availableVerses(book:"ROM",chapter:8)
        XCTAssertEqual(session.document?.book,"GEN")
        XCTAssertEqual(store.snapshot.location,saved)
        XCTAssertEqual(store.saves,saves)
    }

    @MainActor func testSwiftDataRoundTripAndPreferenceFallback() throws {
        let store = try ReaderStateStore(inMemory:true)
        var snapshot = ReaderSnapshot()
        snapshot.location = ReadingLocation(editionID:"web.engwebp",contentRevision:"revision",verse:VerseID(book:"ROM",chapter:8,verse:1))
        snapshot.preferences.typeface = "Unknown"
        snapshot.preferences.sizeStep = 100
        snapshot.preferences.theme = "unknown"
        try store.save(snapshot)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.location,snapshot.location)
        XCTAssertEqual(loaded.preferences.typeface,"Unknown")
        XCTAssertEqual(loaded.preferences.validated,ReaderPreferences())
        XCTAssertEqual(try store.load()?.preferences.sizeStep,100)
    }
    @MainActor func testSessionRecoversRevisionAndMissingVerseAndSurvivesSaveFailure() async throws {
        let store = MemoryReaderState()
        store.snapshot.location = ReadingLocation(editionID:"web.engwebp",contentRevision:"old",verse:VerseID(book:"GEN",chapter:1,verse:999),blockID:"invalid",utf16Offset:999)
        let session = ReaderSession(content:repository(),state:store)
        await session.start()
        XCTAssertEqual(session.document?.book,"GEN")
        XCTAssertEqual(session.targetVerse,31)
        XCTAssertNotNil(session.notice)
        let previous = store.snapshot.location
        store.failSave = true
        await session.navigate(book:"ROM",chapter:8)
        XCTAssertEqual(session.document?.book,"ROM")
        XCTAssertEqual(store.snapshot.location,previous)
        XCTAssertTrue(session.notice?.contains("not saved") == true)
    }
    @MainActor func testUnavailableEditionAndCorruptStateAreNeverOverwritten() async {
        let store = MemoryReaderState()
        store.snapshot.location = ReadingLocation(editionID:"missing",contentRevision:"old",verse:VerseID(book:"ROM",chapter:8,verse:1))
        let session = ReaderSession(content:repository(),state:store)
        await session.start()
        XCTAssertNil(session.document)
        XCTAssertNotNil(session.error)
        XCTAssertEqual(store.saves,0)
        store.failLoad = true
        let recovery = ReaderSession(content:repository(),state:store)
        await recovery.start()
        XCTAssertNotNil(recovery.document)
        XCTAssertEqual(store.saves,0)
    }
    @MainActor func testContinuousChapterSelectionCopyAndVerseReveal() async throws {
        let doc = try await repository().chapter(book:"PSA",number:119)
        let view = ContinuousReaderTextView()
        view.frame = CGRect(x:0,y:0,width:600,height:800)
        let map = ChapterTextMap(document:doc)
        view.map = map
        view.attributedText = NSAttributedString(string:map.text,attributes:[.font:UIFont.systemFont(ofSize:24)])
        view.layoutIfNeeded()
        view.layoutManager.ensureLayout(for:view.textContainer)
        XCTAssertEqual(view.layoutManager.textContainers.count,1)
        XCTAssertGreaterThan(view.contentSize.height,900)
        XCTAssertTrue(view.textContainer.exclusionPaths.isEmpty)
        let start = try XCTUnwrap(map.range(for:10))
        let end = try XCTUnwrap(map.range(for:15))
        view.selectedRange = NSUnionRange(start,end)
        view.copy(nil)
        XCTAssertEqual(UIPasteboard.general.string,map.selection(in:view.selectedRange).text)
        XCTAssertGreaterThan(map.selection(in:view.selectedRange).passages.count,1)
        let target = try XCTUnwrap(map.range(for:88))
        view.reveal(target)
        let glyphs = view.layoutManager.glyphRange(forCharacterRange:target,actualCharacterRange:nil)
        let targetRect = view.layoutManager.boundingRect(forGlyphRange:glyphs,in:view.textContainer)
        XCTAssertEqual(targetRect.minY + view.textContainerInset.top - view.contentOffset.y,20,accuracy:2)
    }
    @MainActor func testChapterSwipeIgnoresVerticalShortAndSelectionGestures() {
        let none = NSRange(location:0,length:0)
        XCTAssertEqual(ContinuousReaderTextView.chapterStep(translation:CGPoint(x:-160,y:10),selection:none),1)
        XCTAssertEqual(ContinuousReaderTextView.chapterStep(translation:CGPoint(x:160,y:10),selection:none),-1)
        XCTAssertNil(ContinuousReaderTextView.chapterStep(translation:CGPoint(x:30,y:2),selection:none))
        XCTAssertNil(ContinuousReaderTextView.chapterStep(translation:CGPoint(x:90,y:200),selection:none))
        XCTAssertNil(ContinuousReaderTextView.chapterStep(translation:CGPoint(x:-160,y:0),selection:NSRange(location:5,length:10)))
    }
    @MainActor func testChapterSwipeCrossesBooksAndStopsAtCanonEdges() async {
        let session = ReaderSession(content:repository(),state:MemoryReaderState())
        await session.start()
        await session.stepChapter(-1)
        XCTAssertEqual(session.document?.book,"GEN")
        XCTAssertEqual(session.document?.chapter,1)
        await session.navigate(book:"GEN",chapter:50)
        await session.stepChapter(1)
        XCTAssertEqual(session.document?.book,"EXO")
        XCTAssertEqual(session.document?.chapter,1)
        await session.stepChapter(-1)
        XCTAssertEqual(session.document?.book,"GEN")
        XCTAssertEqual(session.document?.chapter,50)
        await session.navigate(book:"REV",chapter:22)
        await session.stepChapter(1)
        XCTAssertEqual(session.document?.book,"REV")
        XCTAssertEqual(session.document?.chapter,22)
    }

}

@MainActor private final class MemoryReaderState: ReaderStateRepository {
    var snapshot = ReaderSnapshot()
    var failSave = false
    var failLoad = false
    var saves = 0
    func load() throws -> ReaderSnapshot? { if failLoad { throw ScriptureError.persistence }; return snapshot }
    func save(_ snapshot:ReaderSnapshot) throws {
        if failSave { throw ScriptureError.persistence }
        self.snapshot = snapshot; saves += 1
    }
}
