import XCTest
@testable import SophiaScriptura

final class ScriptureNarrationTests: XCTestCase {
    func testValidateRejectsCountMismatch() {
        let result = ScriptureNarrationTimingValidation.validate(
            startTimes: [0, 5],
            verseNumbers: [1, 2, 3],
            duration: 30
        )
        guard case .failure(.countMismatch(expected: 3, actual: 2)) = result else {
            return XCTFail("Expected count mismatch")
        }
    }

    func testValidateRejectsNonMonotonicTimestamps() {
        let result = ScriptureNarrationTimingValidation.validate(
            startTimes: [0, 10, 8],
            verseNumbers: [1, 2, 3],
            duration: 30
        )
        guard case .failure(.nonMonotonicTimestamps) = result else {
            return XCTFail("Expected non-monotonic failure")
        }
    }

    func testValidateAcceptsMonotonicTimings() throws {
        let validated = try ScriptureNarrationTimingValidation.validate(
            startTimes: [4.2, 8.3, 18.7],
            verseNumbers: [1, 2, 3],
            duration: 30
        ).get()
        XCTAssertEqual(validated.verseStarts.count, 3)
    }

    func testHighlightedVerseBeforeFirstStartIsNil() throws {
        let validated = try ScriptureNarrationTimingValidation.validate(
            startTimes: [5, 10],
            verseNumbers: [1, 2],
            duration: 20
        ).get()
        XCTAssertNil(ScriptureNarrationTimingValidation.highlightedVerse(at: 2, in: validated, duration: 20))
    }

    func testHighlightedVerseTracksLastStart() throws {
        let validated = try ScriptureNarrationTimingValidation.validate(
            startTimes: [5, 10, 16],
            verseNumbers: [1, 2, 3],
            duration: 30
        ).get()
        XCTAssertEqual(ScriptureNarrationTimingValidation.highlightedVerse(at: 12, in: validated, duration: 30), 2)
        XCTAssertEqual(ScriptureNarrationTimingValidation.highlightedVerse(at: 16, in: validated, duration: 30), 3)
    }

    func testValidateRejectsStartBeyondDuration() {
        let result = ScriptureNarrationTimingValidation.validate(
            startTimes: [0, 35],
            verseNumbers: [1, 2],
            duration: 30
        )
        guard case .failure(.exceedsDuration(30)) = result else {
            return XCTFail("Expected exceeds duration")
        }
    }

    func testNarrationPreferencesDefaultOff() {
        let priorContinuous = UserDefaults.standard.object(forKey: "narration.continuousChapters") as? Bool
        let priorFollow = UserDefaults.standard.object(forKey: "narration.followAudio") as? Bool
        defer {
            if let priorContinuous { UserDefaults.standard.set(priorContinuous, forKey: "narration.continuousChapters") }
            else { UserDefaults.standard.removeObject(forKey: "narration.continuousChapters") }
            if let priorFollow { UserDefaults.standard.set(priorFollow, forKey: "narration.followAudio") }
            else { UserDefaults.standard.removeObject(forKey: "narration.followAudio") }
        }
        UserDefaults.standard.removeObject(forKey: "narration.continuousChapters")
        UserDefaults.standard.removeObject(forKey: "narration.followAudio")
        let loaded = ScriptureNarrationPreferencesStore.load()
        XCTAssertFalse(loaded.continuousChapters)
        XCTAssertFalse(loaded.followAudio)
    }

    func testAdjacentVerseNavigation() throws {
        let validated = try ScriptureNarrationTimingValidation.validate(
            startTimes: [0, 5, 12],
            verseNumbers: [1, 2, 3],
            duration: 30
        ).get()
        XCTAssertEqual(ScriptureNarrationTimingValidation.nextVerse(after: nil, in: validated), 1)
        XCTAssertEqual(ScriptureNarrationTimingValidation.nextVerse(after: 2, in: validated), 3)
        XCTAssertNil(ScriptureNarrationTimingValidation.nextVerse(after: 3, in: validated))
        XCTAssertEqual(ScriptureNarrationTimingValidation.previousVerse(before: 2, in: validated), 1)
        XCTAssertEqual(ScriptureNarrationTimingValidation.startTime(forVerse: 2, in: validated), 5)
    }

    func testLocalAudioMigratesLegacyFilename() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("narration-" + UUID().uuidString, isDirectory: true)
        let store = ScriptureNarrationMediaStore(root: root)
        let chapterRoot = root
            .appendingPathComponent("BSB", isDirectory: true)
            .appendingPathComponent("hays", isDirectory: true)
            .appendingPathComponent("GEN", isDirectory: true)
            .appendingPathComponent("1", isDirectory: true)
        try? FileManager.default.createDirectory(at: chapterRoot, withIntermediateDirectories: true)
        let legacy = chapterRoot.appendingPathComponent("narration.audio")
        try? Data([0x49, 0x44, 0x33] + Array(repeating: 0, count: 64)).write(to: legacy)
        let manifest = ScriptureNarrationStoredChapter(
            bookID: "GEN",
            chapter: 1,
            narratorID: "hays",
            aoTranslationID: "BSB",
            recordingRevision: "rev",
            audioFileName: "narration.audio",
            timingStartTimes: [0, 5],
            nextChapterPath: nil,
            previousChapterPath: nil,
            downloadedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(manifest) {
            try? data.write(to: chapterRoot.appendingPathComponent("chapter.json"))
        }
        let resolved = await store.localAudioURL(
            aoTranslationID: "BSB",
            narratorID: "hays",
            bookID: "GEN",
            chapter: 1
        )
        XCTAssertEqual(resolved?.lastPathComponent, "narration.mp3")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
    }

    func testPlaybackSpeedLabels() {
        XCTAssertEqual(ScriptureNarrationPlaybackSpeed.normal.label, "1×")
        XCTAssertEqual(ScriptureNarrationPlaybackSpeed.closest(to: 1.24), .oneAndQuarter)
    }

    func testSleepTimerDurations() {
        XCTAssertNil(ScriptureNarrationSleepTimer.off.duration)
        XCTAssertEqual(ScriptureNarrationSleepTimer.minutes(15).duration, 900)
        XCTAssertEqual(ScriptureNarrationSleepTimer.oneHour.duration, 3600)
    }

    func testDeliveryModeDefaultsToSaveForOffline() {
        let prior = UserDefaults.standard.string(forKey: "narration.deliveryMode")
        defer {
            if let prior { UserDefaults.standard.set(prior, forKey: "narration.deliveryMode") }
            else { UserDefaults.standard.removeObject(forKey: "narration.deliveryMode") }
        }
        UserDefaults.standard.removeObject(forKey: "narration.deliveryMode")
        XCTAssertEqual(ScriptureNarrationPreferencesStore.load().deliveryMode, .saveForOffline)
    }
}
