import AVKit
import XCTest
@testable import SophiaScriptura

final class StudyPiPStateTests: XCTestCase {
    func testNeitherServiceHasNoPanel() {
        XCTAssertFalse(StudyPiPState().hasContent)
        XCTAssertFalse(StudyPiPState().isPlaying)
    }
    func testMusicTakesControlPriorityWithoutChangingTimer() {
        let timer = ActivitySystemProjection(draftID: UUID(), revision: 1, accumulatedSeconds: 120, runningSince: Date(timeIntervalSince1970: 100))
        let state = StudyPiPState(musicTitle: "Track", musicPlaying: false, activity: timer)
        XCTAssertTrue(state.hasContent)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.controlLabel, "Play/Pause controls music")
        XCTAssertEqual(state.columns(at: Date(timeIntervalSince1970: 160)).count, 2)
        XCTAssertEqual(state.columns(at: Date(timeIntervalSince1970: 160))[1].1, "00:03:00")
    }
    func testActivityOnlyUsesTimerStateAndExcludesPausedTime() {
        let state = StudyPiPState(activity: ActivitySystemProjection(draftID: UUID(), revision: 2, accumulatedSeconds: 120, runningSince: nil))
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.controlLabel, "Play/Pause controls Activity")
        XCTAssertEqual(state.columns(at: Date(timeIntervalSince1970: 99999))[0].1, "00:02:00")
    }
    func testMusicOnlyHasOneColumn() {
        let state = StudyPiPState(musicTitle: "Track", musicPlaying: true)
        XCTAssertTrue(state.isPlaying)
        XCTAssertEqual(state.columns(at: Date()).count, 1)
        XCTAssertEqual(state.columns(at: Date())[0].1, "Track")
    }
    func testNonfiniteElapsedDoesNotCrashDisplay() {
        let state = StudyPiPState(activity: ActivitySystemProjection(draftID: UUID(), revision: 1, accumulatedSeconds: .infinity, runningSince: nil))
        XCTAssertEqual(state.columns(at: Date())[0].1, "00:00:00")
    }
    @MainActor
    func testSystemPlaybackCommandsReachOwnerWithoutSeeking() {
        let player = StudyPiPPlayer()
        let controller = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: player.surface.displayLayer, playbackDelegate: player))
        var commands: [Bool] = []
        player.update(StudyPiPState(musicTitle: "Track", musicPlaying: false)) { commands.append($0) }
        XCTAssertTrue(player.pictureInPictureControllerIsPlaybackPaused(controller))
        player.pictureInPictureController(controller, setPlaying: true)
        player.pictureInPictureController(controller, setPlaying: false)
        XCTAssertEqual(commands, [true, false])
        var completed = false
        player.pictureInPictureController(controller, skipByInterval: CMTime(seconds: 10, preferredTimescale: 600)) { completed = true }
        XCTAssertTrue(completed)
        XCTAssertEqual(commands, [true, false], "A seek must not alter music or Activity commands")
    }

    @MainActor
    func testReturnToAppReportsWhetherRestoreHandlerExists() {
        let player = StudyPiPPlayer()
        let controller = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: player.surface.displayLayer, playbackDelegate: player))
        var result: Bool?
        player.pictureInPictureController(controller, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: { result = $0 })
        XCTAssertEqual(result, false)
        var restored = false
        player.restore = { restored = true }
        player.pictureInPictureController(controller, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: { result = $0 })
        XCTAssertTrue(restored)
        XCTAssertEqual(result, true)
    }
    func testPiPPreferenceDefaultsAndSurvivesReload() throws {
        let suite = "PiP-preferences-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(ShellPreferencesStore.load(defaults: defaults).allowPictureInPicture)
        var preferences = ShellPreferencesStore.load(defaults: defaults)
        preferences.allowPictureInPicture = false
        ShellPreferencesStore.save(preferences, defaults: defaults)
        XCTAssertFalse(ShellPreferencesStore.load(defaults: defaults).allowPictureInPicture)
        XCTAssertTrue(ShellPreferencesStore.load(defaults: defaults).showTabActionButtons)
        preferences.allowPictureInPicture = true
        ShellPreferencesStore.save(preferences, defaults: defaults)
        XCTAssertTrue(ShellPreferencesStore.load(defaults: defaults).allowPictureInPicture)
    }

    @MainActor
    func testDisabledPiPRejectsEntryAndLateCommands() {
        let player = StudyPiPPlayer()
        let controller = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: AVSampleBufferDisplayLayer(), playbackDelegate: player))
        var commands: [Bool] = []
        player.update(StudyPiPState(musicTitle: "Track", musicPlaying: true)) { commands.append($0) }
        player.setEnabled(false)
        player.start()
        XCTAssertEqual(player.notice, "Picture in Picture is turned off in Settings.")
        player.pictureInPictureController(controller, setPlaying: false)
        XCTAssertTrue(commands.isEmpty, "Disabling PiP must leave its underlying services unchanged")
        var restored = false
        player.restore = { restored = true }
        player.pictureInPictureController(controller, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler: { XCTAssertFalse($0) })
        XCTAssertFalse(restored)
        player.setEnabled(true)
        player.pictureInPictureController(controller, setPlaying: false)
        XCTAssertEqual(commands, [false])
    }
}
