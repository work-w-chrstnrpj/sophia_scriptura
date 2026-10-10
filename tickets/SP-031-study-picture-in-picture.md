# SP-031 — Floating music and Activity Picture in Picture

Selected for implementation by owner on 2026-10-10. Status: in progress; installed and physical PiP activation verified; sustained/combined background acceptance pending. Post-M8 follow-up; release unassigned. Supersedes SP-030's PiP exclusion for this explicitly requested companion feature only. Existing Live Activity/Now Playing functionality remains.

## Confirmed outcome and controls

Owner selected an AVKit PiP floating panel outside Sophia after the requested permanent notch proved unavailable. Owner approved one system Play/Pause control: controls music whenever a music item is in use, otherwise the current Activity. Return to App opens full controls. Two separately tappable sections are not promised. PiP is system-owned, movable/resizable within system limits; neither screen-top pinning nor a precise notch size is promised. It may remain visible over other apps as inherent OS PiP behavior; no separate above-app overlay is implemented. Lock Screen continues to use native music/Activity system surfaces rather than a floating PiP window.

Show music track/status and/or generic Activity elapsed/status. Hide inactive sections; stop PiP when neither exists. Paused services stay represented. Activity timing stays independent of music. Closing PiP never stops/finishes either service. No silent audio, downloaded dummy video, fake call API, private controlStyle or second music player.

## Implementation

- `Features/SystemPlayer/StudyPiPPlayer.swift`: immutable presentation state, sample-buffer renderer, AVPictureInPictureController lifecycle/playback delegate and explicit preview/start UI. One-second rendering only while inline preview or PiP is active; it is display work, not timer accounting.
- RootTabView retains coordinator, syncs committed Activity and music snapshots, and provides Floating Player action in shell while a service is in use. Explicit start from visible preview precedes Home transition; no surprise auto-start on every launch.
- Existing MusicSession and ActivityStore remain sole command owners. The approved system Play/Pause mapping delegates there. Pausing Activity retains existing successful-save projection behavior.
- BackgroundMusicEngine retains the shared playback session while PiP is active; closing PiP releases it only if music is idle. Preserve music offset and queue logic.
- MusicCommand adopts Equatable for incoming SP-030 command tests.

## Acceptance and limitations

1. Neither service: launcher hidden; no PiP rendering. One service: one column; both: two columns. Generic Activity label excludes private title/notes.
2. Explicit PiP opens on signed iPad and remains visible after Home. Timer-only elapsed updates for five minutes without silent audio or restarting a timer; compared with canonical stored intervals. Until physically tested this is not accepted.
3. System Play/Pause controls music when present, otherwise Activity. Music pause does not pause Activity. No fake seek/next control; return to Sophia for separate full commands.
4. Closing PiP leaves study/music state intact; finish/clear both removes content. Restore opens full Sophia UI. Start failure/unsupported OS produces a truthful notice, with study data unaffected.
5. Native Lock Screen surfaces continue independently. Screen lock, interruptions, route removal, paused PiP, resizing, source-sheet dismissal and foreground restoration require physical validation. Force-close continuity is excluded.
6. No study schema or bundle/signing identity changes. No unsupported permanent-notch claim or automatic success after installation.

## Verification

Tests: StudyPiPStateTests (empty, music priority with running Activity, paused timing, single-column, invalid numeric bounds); existing ActivitySystemProjectionTests and MusicNowPlayingTests; ActivityWorkflowUITests.testFloatingPlayerPreviewForActivity. A signed build/physical PiP session is additionally required. Evidence appended below. No broad release acceptance inferred from these checks.

Usage: start music or Activity → tap shell Floating Player icon → Open Picture in Picture → return Home. Use system Return to App for full controls. OS can stop or suspend presentation; no indefinite background execution guarantee.

### Simulator evidence — 2026-10-10

`build/build-repair-20261010/pip-tests-r3.xcresult`: **8 focused unit tests and 1 UI preview test passed**, iPad A16 simulator on iOS 27.0. The preview screenshot was visually inspected: upright timer content, readable controls and working PiP start availability. Music+Activity two-column state/control priority is covered by the new state tests. Physical activation/Home/background and combined real playback remain separate acceptance checks.

Earlier `pip-tests.xcresult` could not run because the previous iOS 26.5 simulator UUID no longer existed. The next test build found the incoming MusicCommand Equatable mismatch, corrected before this passing run. No failed run is counted as success.

### Physical-device evidence — 2026-10-10

`pip-device-r2.xcresult`: signed iPad build and all **8 focused unit tests passed** on the owner's iPad. UI automation failed before PiP during unrelated workflow Settings setup; that prerequisite was removed from the PiP test. `pip-device-r3.xcresult` then exposed tab navigation failing in a 375-point iPad window before opening Activity. The tab label now uses a rectangular content shape so its complete layout is tappable. This change still needs its device rerun.

`pip-device-r4.log`: signed rebuild completed; Xcode paused launching the UI test with “Unlock iPad ni Paj to Continue.” No physical PiP activation, Home continuity, combined actual music playback, five-minute timer, or Lock Screen result is claimed from these attempts. Ticket remains in progress pending device acceptance. All test launches use an isolated study fixture; restore a normal owner-data launch after testing.

Follow-up: after unlocking, r4 still failed before Activity. r5's explicit wait for tab reveal reached the PiP preview successfully, but PiP eligibility remained false for 15 seconds. The coordinator now prepares the real playback audio session when opening its visible preview, before querying PiP readiness, and releases its hold when dismissing an inactive preview. This is an eligibility fix under verification, not proof of device support. No silent audio is introduced. r6 is the device rerun for that change.

### Successful device activation — 2026-10-10

`build/build-repair-20261010/pip-device-r6.xcresult`: **signed build and physical PiP UI test passed (1 test, 0 failures)** after preparing the playback session before eligibility. Test opens a real Activity, starts PiP, presses Home, captures the screen, reactivates Sophia and verifies its Activity recorder remains. Exported `pip-device-r6-images/AACA7C4F-D064-403E-B28A-B2949919DEDA.png` was visually inspected: a separate system PiP window visibly displays Activity Running and elapsed time over the Home transition. The snapshot catches the app-minimizing animation, so it does not prove sustained Home operation. Xcode reports a diagnostic-collection warning for its own devicectl lookup after tests; the test result itself succeeded.

The current app was then launched normally using devicectl with only `SOPHIA_LAUNCH=user`, restoring the owner's real study store rather than the isolated test fixture. `git diff --check` passed. Implementation is installed; ticket stays in progress for combined actual music+Activity playback, five-minute background timing, system Play/Pause behavior, screen lock/interruption and restore/close acceptance. No release closure is claimed.

### Standard-control follow-up — 2026-10-10

Owner selected the supported command table: music-first Play/Pause, restricted seeking and Return to App for full controls. Existing delegates already forward playback to the owning sessions and ignore seeking while completing its callback. Return to App now dismisses the preview and selects Activity; music-only playback opens the existing music library after sheet dismissal. Both-service sessions expose the existing Activity screen and shell music control. No new custom PiP buttons or persistence changes.

Added delegate regression coverage for playback dispatch, seek completion without service mutations, and truthful restore completion when no handler exists. Physical system-button taps and combined playback remain acceptance gates; earlier activation evidence does not establish those results.

Follow-up verification: final generic simulator app build passed (`pip-controls-final-build.log`). `pip-controls-r3.xcresult` passed all **7 StudyPiPStateTests**, including the new playback/seek/restore delegates, with zero failures. The first test run was interrupted after its host stalled; r2 ran and found an invalid initializer in the new test harness, corrected before r3. `git diff --check` passed. These follow-up changes have not been reinstalled on the physical iPad; hardware command/restore acceptance remains pending.


### Settings opt-out — selected 2026-10-10

Settings → Floating Player → **Allow Picture in Picture** controls access to this mode.
Stored in `ShellPreferencesStore` as additive UserDefaults key `shell.allowPictureInPicture`;
missing values default to true, preserving the existing build's available PiP mode. Older
builds ignore the key; study formats and music preferences are unchanged.

Off hides the Floating Player launcher, dismisses its preview and stops active PiP, releases
its audio-session hold and frame timer, and rejects subsequent start/playback/restore
callbacks. Music and Activity continue independently. On makes the launcher available again
when a service is in use; it never automatically starts PiP. Native Lock Screen and Control
Center functionality is independent. Settings UI identifier: `settings.allowPictureInPicture`.

Verification covers an isolated UserDefaults round trip/default, disabled entry and late
commands, re-enabling, plus existing PiP delegate/state tests. Manual device follow-up:
start both services; switch off; confirm PiP closes, launcher disappears, audio continues and
Activity elapsed increases. Relaunch and confirm off persists; switch on, explicitly start
PiP again. This settings follow-up was installed during the owner-authorized v0.4.0 delivery below.

Settings verification: simulator test build passed and **9 StudyPiPStateTests passed, zero
failures** in `build/build-repair-20261010/pip-settings.xcresult`. `git diff --check` passed.
Device Settings interaction and active-PiP dismissal remain manual acceptance checks.

v0.4.0/build 21 delivery: the Settings follow-up and final code were installed in place and
launched on the owner's iPad (`build/v040/install-release.log`). Full unit regression passed
341 tests. Publication includes these features with the device acceptance gates above still
open; release notes are canonical delivery evidence.
