import XCTest
@testable import SophiaScriptura

final class MusicTests: XCTestCase {
    func testBundledCatalogLoadsEmptyManifest() throws {
        let catalog = try MusicCatalog.bundled()
        XCTAssertTrue(catalog.tracks.isEmpty)
    }

    func testNextTrackWrapsWhenLoopAllEnabled() {
        let tracks = [
            MusicTrackDefinition(id: "a", title: "A", composer: "C", performer: "P", resourceName: "a", fileExtension: "mp3", fileDigest: "d", licenseID: "l", licenseURL: "u", sourceURL: "s", evidenceCapturedOn: "2026-01-01", attributionRequired: false, attributionText: nil, ownerApproved: true, reviewStatus: "test"),
            MusicTrackDefinition(id: "b", title: "B", composer: "C", performer: "P", resourceName: "b", fileExtension: "mp3", fileDigest: "d", licenseID: "l", licenseURL: "u", sourceURL: "s", evidenceCapturedOn: "2026-01-01", attributionRequired: false, attributionText: nil, ownerApproved: true, reviewStatus: "test")
        ]
        XCTAssertEqual(MusicTrackDefinition.nextTrackID(in: tracks, after: "b", loopAll: true), "a")
    }

    func testNextTrackStopsAtEndWhenLoopAllDisabled() {
        let tracks = [
            MusicTrackDefinition(id: "a", title: "A", composer: "C", performer: "P", resourceName: "a", fileExtension: "mp3", fileDigest: "d", licenseID: "l", licenseURL: "u", sourceURL: "s", evidenceCapturedOn: "2026-01-01", attributionRequired: false, attributionText: nil, ownerApproved: true, reviewStatus: "test")
        ]
        XCTAssertNil(MusicTrackDefinition.nextTrackID(in: tracks, after: "a", loopAll: false))
    }

    func testPreferencesPersistSelectedTrackAndLoop() {
        let prior = MusicPreferencesStore.load()
        defer { MusicPreferencesStore.save(prior) }
        MusicPreferencesStore.save(MusicPreferences(selectedTrackID: "study-haze", loopAll: false, showFloatingControl: true))
        let loaded = MusicPreferencesStore.load()
        XCTAssertEqual(loaded.selectedTrackID, "study-haze")
        XCTAssertFalse(loaded.loopAll)
    }

    func testNarrationStubAllowsMusicPlayCommand() {
        let narration = NullScriptureNarrationController()
        let coordinator = StudyAudioCoordinator(narration: narration)
        coordinator.willStartMusic(takeover: true)
        XCTAssertFalse(narration.isNarrationActive)
    }

    func testMusicImportAcceptsMp3Extension() {
        let url = URL(fileURLWithPath: "/tmp/Downloads/test-track.mp3")
        XCTAssertTrue(MusicImportContentTypes.isSupportedFile(url))
        XCTAssertFalse(MusicImportContentTypes.pickerTypes.isEmpty)
    }

    func testUserMusicImportPersistsInLibrary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.wav")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("RIFFtest".utf8).write(to: source)

        let store = UserMusicLibraryStore(directory: directory.appendingPathComponent("library"))
        let track = try store.importFile(from: source)
        XCTAssertEqual(track.title, "source")
        XCTAssertTrue(track.isUserLibrary)
        XCTAssertNotNil(store.fileURL(for: track.id))
        XCTAssertEqual(try store.loadTracks().count, 1)
    }
}
