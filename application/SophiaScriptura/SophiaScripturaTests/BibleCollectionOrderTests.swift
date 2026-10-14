import XCTest
@testable import SophiaScriptura

final class BibleCollectionOrderTests: XCTestCase {
    func testOldTestamentFoldersFollowReadingOrderInsteadOfTheAlphabet() {
        let names = ["Amos", "Genesis", "Exodus", "Psalms", "Song of Songs", "I Samuel", "Malachi"]
        XCTAssertTrue(BibleCollectionOrder.prefersScriptureOrder(parentName: "Old Testament", childNames: names))
        XCTAssertEqual(
            BibleCollectionOrder.sorted(names, name: { $0 }),
            ["Genesis", "Exodus", "I Samuel", "Psalms", "Song of Songs", "Amos", "Malachi"]
        )
    }

    func testTestamentFoldersStayInCanonOrder() {
        let names = ["New Testament", "Old Testament"]
        XCTAssertTrue(BibleCollectionOrder.prefersScriptureOrder(parentName: "Bible", childNames: names))
        XCTAssertEqual(BibleCollectionOrder.sorted(names, name: { $0 }), ["Old Testament", "New Testament"])
    }

    func testNumberedNewTestamentBooksStayInReadingOrder() {
        let names = ["3 John", "1 Corinthians", "Revelation", "Matthew", "II Timothy"]
        XCTAssertEqual(
            BibleCollectionOrder.sorted(names, name: { $0 }),
            ["Matthew", "1 Corinthians", "II Timothy", "3 John", "Revelation"]
        )
    }

    func testUnrecognizedFoldersStayAlphabeticalAfterTheBooks() {
        let names = ["Prayer", "Genesis", "Exodus", "Grace"]
        XCTAssertTrue(BibleCollectionOrder.prefersScriptureOrder(parentName: "Study", childNames: names))
        XCTAssertEqual(BibleCollectionOrder.sorted(names, name: { $0 }), ["Genesis", "Exodus", "Grace", "Prayer"])
    }

    func testOrdinaryFoldersStayAlphabetical() {
        let names = ["Grace", "Hope", "Prayer"]
        XCTAssertFalse(BibleCollectionOrder.prefersScriptureOrder(parentName: "Study Review", childNames: names))
        XCTAssertEqual(BibleCollectionOrder.sorted(names, name: { $0 }), ["Grace", "Hope", "Prayer"])
    }

    func testOneBookAmongTopicsDoesNotReorderTheFolder() {
        XCTAssertFalse(BibleCollectionOrder.prefersScriptureOrder(parentName: "Topics", childNames: ["Genesis", "Prayer", "Hope"]))
    }

    func testLoadedEditionOrderOverridesTheBuiltInSequence() {
        let books = [
            ScriptureBook(id: "MAT", title: "Matthew", testament: "NT", order: 1, chapterCount: 28),
            ScriptureBook(id: "GEN", title: "Genesis", testament: "OT", order: 2, chapterCount: 50)
        ]
        XCTAssertEqual(
            BibleCollectionOrder.sorted(["Genesis", "Matthew"], name: { $0 }, books: books),
            ["Matthew", "Genesis"]
        )
    }

    func testSmartOrderPutsNumberedNamesInNumericOrder() {
        let names = ["Chapter 10", "Chapter 2", "Chapter 1", "Session 3"]
        XCTAssertTrue(BibleCollectionOrder.prefersNumberOrder(names))
        XCTAssertEqual(
            BibleCollectionOrder.sorted(names, name: { $0 }, scripture: false),
            ["Chapter 1", "Chapter 2", "Chapter 10", "Session 3"]
        )
    }

    func testStoredBibleChoiceIsSmartOrder() {
        XCTAssertEqual(CollectionSubfolderArrange.stored("bible"), .smart)
        XCTAssertEqual(CollectionSubfolderArrange.smart.title, "Smart Order")
    }

    func testDeuterocanonicalNamesSitBetweenMalachiAndMatthew() {
        let names = ["Matthew", "Tobit", "Malachi", "Wisdom"]
        XCTAssertEqual(
            BibleCollectionOrder.sorted(names, name: { $0 }),
            ["Malachi", "Tobit", "Wisdom", "Matthew"]
        )
    }
}
