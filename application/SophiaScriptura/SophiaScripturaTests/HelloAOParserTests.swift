import XCTest
@testable import SophiaScriptura

final class HelloAOParserTests: XCTestCase {
    func testBundledEligibilityManifestLoadsSelectedEditions() {
        XCTAssertEqual(HelloAOEligibility.manifest.editions.count, 5)
        XCTAssertNotNil(HelloAOEligibility.edition(providerID: "BSB"))
    }

    private let fixtureJSON = """
    {
      "translation": {
        "id": "BSB",
        "name": "Berean Standard Bible",
        "shortName": "BSB",
        "sha256": "fixture-sha"
      },
      "book": {
        "id": "GEN",
        "name": "Genesis",
        "commonName": "Genesis",
        "order": 1,
        "numberOfChapters": 50
      },
      "chapter": {
        "number": 1,
        "content": [
          { "type": "heading", "content": ["The Creation"] },
          { "type": "line_break" },
          { "type": "verse", "number": 1, "content": ["In the beginning God created the heavens and the earth."] },
          { "type": "verse", "number": 3, "content": ["And God said, \\"Let there be light,\\"", {"noteId": 0}, "and there was light."] },
          { "type": "verse", "number": 5, "content": [{"text": "Blessed line.", "wordsOfJesus": true}] }
        ],
        "footnotes": [
          { "noteId": 0, "caller": "+", "text": "Sample footnote.", "reference": { "chapter": 1, "verse": 3 } }
        ]
      }
    }
    """

    func testParseGenesisIdentityAndVerses() throws {
        guard let eligible = HelloAOEligibility.edition(providerID: "BSB") else {
            XCTFail("Missing bundled eligibility fixture for BSB")
            return
        }
        let wire = try JSONDecoder().decode(HelloAOChapterWire.self, from: Data(fixtureJSON.utf8))
        let document = try HelloAOChapterParser.parse(wire, eligible: eligible)

        XCTAssertEqual(document.editionID, "helloao.BSB")
        XCTAssertEqual(document.referenceSystemID, "org.sophia.helloao.BSB")
        XCTAssertEqual(document.book, "GEN")
        XCTAssertEqual(document.chapter, 1)
        XCTAssertEqual(document.verseNumbers, [1, 3, 5])
        XCTAssertTrue(document.blocks.contains { $0.kind == "heading" && $0.text == "The Creation" })
        XCTAssertTrue(document.blocks.contains { $0.kind == "body" && $0.text.contains("In the beginning") })
        XCTAssertTrue(document.blocks.contains { $0.kind == "note" && $0.sourceNoteID == "0" && $0.sourceCaller == "+" })
        XCTAssertTrue(document.blocks.contains { $0.kind == "body" && $0.wordsOfJesus == true })
    }

    func testParseHebrewSubtitleInPsalms() throws {
        let json = """
        {
          "translation": { "id": "BSB", "name": "BSB", "shortName": "BSB", "sha256": "fixture-sha" },
          "book": { "id": "PSA", "name": "Psalms", "commonName": "Psalms", "order": 19, "numberOfChapters": 150 },
          "chapter": {
            "number": 3,
            "content": [
              { "type": "hebrew_subtitle", "content": ["A Psalm of David, when he fled from his son Absalom."] },
              { "type": "verse", "number": 1, "content": ["O LORD, how my foes have increased!"] }
            ]
          }
        }
        """
        guard let eligible = HelloAOEligibility.edition(providerID: "BSB") else {
            XCTFail("Missing bundled eligibility fixture for BSB")
            return
        }
        let wire = try JSONDecoder().decode(HelloAOChapterWire.self, from: Data(json.utf8))
        let document = try HelloAOChapterParser.parse(wire, eligible: eligible)
        XCTAssertTrue(document.blocks.contains { $0.kind == "heading" && $0.text.contains("Absalom") })
        XCTAssertEqual(document.verseNumbers, [1])
    }

    func testWEBUTestamentMappingIncludesDeuterocanon() throws {
        let ids = ["GEN", "MAT", "TOB", "DAG"]
        let testaments = ids.enumerated().map { index, id in
            HelloAOBooks.testament(bookIndex: index == 0 ? 0 : index == 1 ? 39 : index == 2 ? 66 : 80, totalBooks: 81, bookID: id)
        }
        XCTAssertEqual(testaments, ["OT", "NT", "DC", "DC"])
    }
}
