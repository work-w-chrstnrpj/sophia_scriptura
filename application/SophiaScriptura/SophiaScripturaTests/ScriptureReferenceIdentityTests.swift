import XCTest
@testable import SophiaScriptura

final class ScriptureReferenceIdentityTests: XCTestCase {
    func testLegacyBundledEditionIdentity() throws {
        let legacyJSON = """
        {"schemaVersion":1,"editionID":"web.engwebp","contentRevision":"fixture-rev","book":"GEN","chapter":1,"blocks":[]}
        """
        let decoded = try JSONDecoder().decode(ChapterDocument.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(decoded.storedReferenceSystemID)
        XCTAssertEqual(decoded.referenceSystemID, ScriptureReferenceIdentity.bundledReferenceSystemID)
        XCTAssertEqual(decoded.verse(1).referenceSystemID, ScriptureReferenceIdentity.bundledReferenceSystemID)

        let roundTrip = try JSONEncoder().encode(decoded)
        let reopened = try JSONDecoder().decode(ChapterDocument.self, from: roundTrip)
        XCTAssertEqual(reopened.referenceSystemID, decoded.referenceSystemID)
        XCTAssertEqual(reopened.editionID, "web.engwebp")
    }

    func testLegacyAPIBibleEditionIdentity() throws {
        let editionID = "api.bible.\(LicensedTranslation.approved[0].id)"
        let expectedReference = "org.sophia." + editionID
        let legacyJSON = """
        {"schemaVersion":1,"editionID":"\(editionID)","contentRevision":"fixture-rev","book":"JHN","chapter":3,"blocks":[]}
        """
        let decoded = try JSONDecoder().decode(ChapterDocument.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(decoded.storedReferenceSystemID)
        XCTAssertEqual(decoded.referenceSystemID, expectedReference)
        XCTAssertTrue(decoded.isLicensed)
        XCTAssertTrue(decoded.requiresLicensedQuoteAuthorization)

        let explicitJSON = """
        {"schemaVersion":1,"editionID":"\(editionID)","referenceSystemID":"\(expectedReference)","contentRevision":"fixture-rev","book":"JHN","chapter":3,"blocks":[]}
        """
        let explicit = try JSONDecoder().decode(ChapterDocument.self, from: Data(explicitJSON.utf8))
        XCTAssertEqual(explicit.referenceSystemID, expectedReference)
    }

    func testHelloAOIdentityWithoutGenericWEBFallback() {
        let editionID = "helloao.eng_kjv"
        XCTAssertEqual(
            ScriptureReferenceIdentity.referenceSystemID(forEditionID: editionID),
            "org.sophia.helloao.eng_kjv"
        )
        XCTAssertNil(ScriptureReferenceIdentity.referenceSystemID(forEditionID: "unknown.edition"))
        let document = ChapterDocument(
            schemaVersion: 1,
            editionID: "unknown.edition",
            contentRevision: "test",
            book: "GEN",
            chapter: 1,
            blocks: []
        )
        XCTAssertEqual(document.referenceSystemID, "")
        XCTAssertFalse(document.isLicensed)
    }

    func testExplicitIdentityMismatchFailsClosed() {
        XCTAssertThrowsError(
            try ScriptureReferenceIdentity.resolvedReferenceSystemID(
                editionID: "web.engwebp",
                stored: "org.sophia.api.bible.mismatch"
            )
        )
    }

    func testTranslationSourcePolicyRouting() {
        XCTAssertEqual(
            TranslationRightsPolicyResolver.policy(forEditionID: "web.engwebp"),
            .bundledPublicDomain
        )
        XCTAssertEqual(
            TranslationRightsPolicyResolver.policy(forEditionID: "api.bible.example")?.copy,
            .needsReview
        )
        XCTAssertEqual(
            TranslationRightsPolicyResolver.policy(forEditionID: "helloao.eng_kjv")?.offlineRead,
            .allowed
        )
    }
}
