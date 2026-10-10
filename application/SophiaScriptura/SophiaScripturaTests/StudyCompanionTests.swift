import XCTest
@testable import SophiaScriptura

final class StudyCompanionTests: XCTestCase {
    func testCharacterPosePrefixAndWelcome() {
        XCTAssertEqual(StudyCompanionCharacter.sol.assetPrefix, "Sol")
        XCTAssertTrue(StudyCompanionCharacter.sabinus.welcomeGreeting.contains("Sabinus"))
    }

    func testQuoteCatalogProvidesBookSpecificSeeds() {
        XCTAssertFalse(CompanionQuoteCatalog.seeds(for: .sophy).isEmpty)
        XCTAssertEqual(CompanionQuoteCatalog.seeds(for: .sol).first?.book, "ECC")
        XCTAssertEqual(CompanionQuoteCatalog.seeds(for: .sabinus).first?.book, "JOB")
    }

    func testPreferencesPersistCharacterAndQuoteInterval() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        var prefs = SophyPreferences.initial
        prefs.enabled = true
        prefs.character = .sol
        prefs.idleDelayBeforeQuoteSeconds = 120
        SophyPreferencesStore.save(prefs, defaults: defaults)
        let loaded = SophyPreferencesStore.load(defaults: defaults)
        XCTAssertEqual(loaded.character, .sol)
        XCTAssertEqual(loaded.idleDelayBeforeQuoteSeconds, 120)
    }
}
