import XCTest
@testable import SophiaScriptura

final class ScriptureVerseTextTests: XCTestCase {
    func testBodyJoinsSplitFragmentsWithMissingSpaces() {
        let document = ChapterDocument(
            schemaVersion: 1,
            editionID: "bundled",
            contentRevision: "1",
            book: "GEN",
            chapter: 1,
            blocks: [
                ScriptureBlock(id: "1", kind: "body", text: "riches;", label: "", verses: [1], style: "p"),
                ScriptureBlock(id: "2", kind: "body", text: "favor is", label: "", verses: [1], style: "p"),
            ]
        )
        XCTAssertEqual(document.body(for: 1), "riches; favor is")
    }
}
