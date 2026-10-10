# SP-030 — Background music and Activity system controls

Status: in progress (2026-10-10). G1–G5 code landed: Now Playing coordinator, music resume fix, committed Activity projection, Live Activity widget extension, deep link. **G0 physical placement evidence and AC1–AC10 device acceptance remain open.**
Change mode: feature. Milestone: post-M8 follow-up; release assignment undecided. Owners: Frontend UI/UX + System Architect; supporting SQA, DevOps/signing and documentation.

## Later owner selection — PiP follow-up

On 2026-10-10 the owner selected [SP-031](SP-031-study-picture-in-picture.md) to add a
public-API sample-buffer PiP music/Activity display, approving music-first system
Play/Pause mapping. SP-030's original PiP exclusion does not prohibit that separately
selected follow-up. Native Lock Screen/Now Playing work and its acceptance remain
independent. PiP placement is system-controlled, not a permanent Home-screen notch.

## Execution guide

The [normative implementation contract](../docs/design/sp030-system-controls-implementation-guide.md) defines G0–G6 checkpoints, exact ownership, music and timer state transitions, save acknowledgment, race handling, privacy, presentation, deep links and deterministic test fixtures. Read it before implementation. No model should substitute guessed platform behavior for G0 evidence.

## Confirmed scope and usable outcome

Owner clarified: the display is **outside Sophia on iPad**, on the **Home Screen and Lock Screen**. Display above other open apps is explicitly out of scope. Force-closing from the app switcher is excluded. Music continues audibly; the current Activity continues accounting for elapsed time. Available Home/Lock Screen system surfaces expose accurate status and let the owner return to Sophia or control music. Playback and elapsed-time accounting continue while another app is foregrounded, but no visible overlay over that app is required.

The original concept is `(Music Player | Activity)`, shrinking to the service in use and hidden when neither is in use. Outside-app placement and width are system-controlled: **do not promise an app-drawn notch, a combined system capsule, or a persistent iPad menu-bar item.** Recommended supported interpretation: native Now Playing for music plus an ActivityKit Live Activity for the timer. A combined custom surface is not required or accepted as a substitute without owner selection.

Proposed defaults below are implementation guidance, not additional owner-confirmed choices: paused sessions stay visible and say Paused; private titles/descriptions are not disclosed; external Activity controls open Sophia rather than mutating the store from an extension.

## Exclusions

- Custom in-app top pill or redesign of the existing Now Active cluster.
- Any display above other open apps, including overlay/notch placement or an always-visible panel while another app is foregrounded; fake video/PiP, silent audio to keep a timer alive, private APIs, or continuous background CPU for elapsed time.
- Force-quit/reboot audio persistence, automatic music playback on cold launch, server/APNs infrastructure, paid Developer membership changes, iPhone product expansion.
- New activity schema, duplicate timer store, cloud sync, reminders redesign, narration implementation, or changes to SP-029 Sophy acceptance.
- Changing the app's iPadOS 17 minimum merely to gain a new system surface.

## Source-grounded baseline (2026-10-10)

Paths below are relative to `application/SophiaScriptura/` unless stated otherwise. Re-read exact files before editing; incoming worktree changes must be preserved.

| Area | Current implementation and implication |
| --- | --- |
| `SophiaScriptura/Infrastructure/Music/BackgroundMusicEngine.swift` | AVAudioPlayer with `currentTime`/`duration`, resume-friendly prepare, interruption/route handling. |
| `SophiaScriptura/Infrastructure/Music/MusicNowPlayingCoordinator.swift` | One-time `MPRemoteCommandCenter` registration; metadata and Play/Pause/Toggle/Next routed to `MusicSession`. |
| `SophiaScriptura/Features/Music/MusicSession.swift` | Sole music commands; no Now Playing claim until explicit play; pause→play resumes same prepared file. |
| `StudyActivityWidgetExtension/` + `AppInfoSupplement.plist` | WidgetKit Live Activity target embedded in app; `NSSupportsLiveActivities`, `UIBackgroundModes = audio`, `sophiascriptura://activity`. Extension bundle: `com.personal.SophiaScriptura.StudyActivityWidget`. |
| `SophiaScriptura/Core/Activity/ActivitySystemProjection.swift` | Pure timer projection from draft intervals + `runningSince`; not persisted as study data. |
| `SophiaScriptura/Infrastructure/Activity/ActivityLiveActivityCoordinator.swift` | ActivityKit start/update/end from committed projection; foreground reconciliation. |
| `SophiaScriptura/Features/Activity/ActivityStore.swift` | `committedProjection`/`committedRevision` published only after successful `repository.save`. |
| `SophiaScriptura/RootTabView.swift` | Owns `ActivityLiveActivityCoordinator`; reconciles on load, committed projection, scene phase, and deep link. |
| `SophiaScriptura/AppShell/StudyAudioCoordinator.swift` | Unchanged arbitration boundary; music does not pause Activity. |

Intent references: [SP-020](SP-020-activity-tracking.md), [SP-021](SP-021-background-music.md), [TDD](../docs/tdd/tdd.md), [compatibility policy](../docs/guidelines/backward-compatibility.md), [deployment](../docs/deployment/deployment.md), [test specification](../docs/testing/test-specification.md).

## Platform contract and feasibility gate — do first

1. Record owner's actual iPad model, installed iPadOS, Xcode and Personal Team signing constraints. Do not assume simulator support establishes physical availability.
2. Verify current Apple documentation and local SDK availability for ActivityKit/WidgetKit on the supported iPad versions. Implement availability checks and graceful fallback; app deployment remains 17+.
3. Verify whether a widget/Live Activity extension can be built, embedded, signed and installed with the owner's existing free account. Do not switch teams, buy membership or introduce entitlements without owner agreement. Avoid App Groups if not necessary.
4. Prepare a disposable preview/minimal feasibility experiment only after implementation authorization. On the signed iPad record where the Live Activity is actually shown when Home is open and when locked. Verify audio Now Playing separately.
5. **Stop before broad implementation** if the owner requires a permanent Home-screen top notch/menu-bar capsule and public APIs cannot supply it. Present actual system surfaces and obtain a scope choice. Do not report a Lock Screen card as fulfillment of a Home-screen notch.
6. Record disabled Live Activities, unsupported OS and system dismissal behavior. These affect presentation only; they must not stop playback or delete the underlying Activity.

Apple references (recheck at execution):
- [Live Activities implementation](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Live Activities design](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [Now playable app](https://developer.apple.com/documentation/mediaplayer/becoming-a-now-playable-app)
- [Now Playing information](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)
- [iPad menu bar](https://support.apple.com/en-ie/guide/ipad/ipadb4ede9db/26/ipados/26)

## Implementation sequence after feasibility and owner selection

### A. Music system integration

1. Add a dedicated `Infrastructure/Music/MusicNowPlayingCoordinator.swift` (proposed name) owning metadata and MPRemoteCommandCenter registration tokens. Install once; remove exact targets on teardown. Use MainActor for MusicSession changes.
2. Expose read-only currentTime/duration from the audio engine. Publish actual track title, legitimate artwork if available, duration, elapsed time and playback rate (1 playing, 0 paused). Update on play, pause, next, completion, interruption, route change, delete and stop. Do not publish a fake live stream or fake duration.
3. Support Play/Pause and Next only when valid; unsupported remote commands are disabled. Seek is excluded unless existing playback semantics are extended and separately tested. Never invoke a second player from the command handler.
4. Stop/delete clears Sophia's metadata and command availability. Paused playback may retain metadata; the OS decides its visibility. Do not clear another app's Now Playing on arbitrary launch or steal audio focus before explicit Play.
5. Preserve current takeover, loop, track ordering and interruption policies. Returning Home or locking must not call pause. Do not add auto-resume after interruptions as an incidental change.

### B. Activity Live Activity projection

1. Add a WidgetKit extension target for a minimal Activity Live Activity and a small shared, immutable Codable attributes/content-state type. Share only projection types, never ActivityStore, repository, protected study content or provider keys. Prefer file target membership over duplicating source.
2. Add a coordinator under `Infrastructure/Activity/` that starts/updates/ends one system Live Activity corresponding to the single persisted draft ID. ActivityStore remains the only timer authority. No new storage schema is expected.
3. Derive elapsed presentation from committed accumulated seconds plus runningSince. Use supported system-rendered timer text for running state; fixed duration for paused state. Never depend on one-second extension callbacks or background execution. Test resumed display against activeSeconds(at:).
4. Serialize/coalesce asynchronous projection operations. Generation/draft-ID guards must prevent late start/update calls recreating a finished or replaced session. Reconcile ActivityKit activities after launch/foreground and successful archive restore; end orphan/duplicate presentations.
5. Start while foregrounded when permitted, following durable draft save. Publish pause/resume only after successful save. If necessary expose a narrow save-result/revision signal from ActivityStore while preserving existing mutation behavior; do not infer success merely from flush() returning because current errors are caught internally.
6. On finish/discard/delete-data end the presentation after canonical persistence succeeds. Reading completion that requires an ending reference must open Sophia's existing completion flow; never silently fabricate a record or reference from the system surface.
7. Use a generic public label such as “Study activity,” elapsed duration and Running/Paused. Exclude free-form title, mode labels that may be custom/private, description, verse excerpts, notes and conversations by default. Tapping opens the Activity tab through a validated route, without auto-start or auto-finish.
8. Handle authorization denied, update failure, stale state and the system's Live Activity lifetime (currently eight hours active). Display expiry/dismissal does not finish the timer. Reconcile on next foreground; no background push backend and no automatic restart loop.
9. Provide all presentations required by the SDK/ActivityKit contract, even if iPad is the sole product. Do not claim Dynamic Island/menu-bar support on hardware that does not offer it.

### C. Integration, compatibility and docs

1. Existing in-app controls remain usable. Music only, Activity only, both and neither must remain independent. Sophy-triggered music and existing Activity start paths naturally feed the same owners; add no parallel Sophy implementation.
2. Deep links open the existing relevant screen in the current scene. Validate paths/IDs; never accept arbitrary commands or sensitive payloads from a URL. If no matching draft exists, open Activity safely without creating one.
3. Existing archives/backups remain compatible. Never serialize ActivityKit IDs as canonical study data. Backup restore invalidates old projections and rebuilds from the restored draft after successful restore. No app reset or destructive migration.
4. Update TDD §Activity/audio, Activity design, Activity data contract if save acknowledgment changes, deployment extension-signing steps, testing guide, AGENTS repository map and development-plan status. Mark actual evidence separately from planned behavior.

## Acceptance criteria

- AC1: With valid local music playing, Home/app switching/screen lock continue audible playback; Now Playing shows correct track and functioning Play/Pause/Next. Verify on owner iPad.
- AC2: With only Activity running and audio stopped, elapsed time advances across at least five background/locked minutes without fabricated audio or timer background work; reopening matches existing activeSeconds(at:) within display rounding.
- AC3: Paused Activity does not accrue background time. Resume does not double-count prior intervals. Timer remains independent of music pauses/interruptions.
- AC4: Both services can be used concurrently. Stopping either does not stop the other. No stale music metadata after Stop; no active timer presentation after successful finish/discard.
- AC5: Live Activity uses the actual available system surface established at feasibility; unsupported/denied/dismissed presentation leaves the study draft intact and existing controls usable. Exact outside-app capsule width/placement is not an acceptance promise.
- AC6: Relaunch reconciles the existing draft without duplicate records or duplicate system activities; saved music selection does not autoplay on cold launch. Late async projection operations cannot resurrect ended sessions.
- AC7: Failed save does not advertise a new durable timer state. Presentation failure does not corrupt records, finish a draft or roll back legitimate playback. Retry only on bounded lifecycle/state changes.
- AC8: External timer display leaks no private study text. Tapping opens Activity; any completion requiring input stays in-app.
- AC9: Extension signs/installs using existing Personal Team, all original study data survives in-place install, and the iPadOS 17 app fallback builds.
- AC10: Owner explicitly accepts actual Home/Lock Screen placement; simulator/preview screenshots alone cannot close this criterion.

## Verification plan and evidence requirements

Use current commands in the test specification and an installed iPad simulator; keep unique xcresult bundles under ignored `build/sp030/`.

- Unit: Now Playing metadata for playing/paused/stopped/missing track; remote command registration once and teardown; remote commands invoke existing session once; disabled next; interrupted playback rate zero.
- Unit: timer projection accumulated intervals/runningSince/pause/resume; denied authorization; eight-hour expiry; failed saves; failed starts/updates; finished-draft late task; duplicate/orphan reconciliation; legacy archive restore; deep-link validation.
- Integration: fake system clients and clock; start→pause→resume→finish and save completion reordering. Restoration/deletion while projection work is pending. Ensure a dismissed Live Activity does not mutate Activity data.
- UI: existing Activity and Music workflows; tap system deep link; disabled/unsupported fallback and safe status copy. Widget previews for required layouts, accessibility text size and contrast.
- Physical: music only, Activity only, both, neither; Home, another app and screen lock; verify another-app use for playback/timing continuity only, with no overlay acceptance requirement; five-minute timer check with no audio; pause interval check; headphone disconnect/interruption; lock-screen controls; Live Activities disabled/dismissed; long-session expiry documented; app relaunch and in-place installation data preservation.
- Build Debug and Release including extension; inspect embedded extension, built plist/background audio, availability guards and signing. Run relevant unit regression and cross-feature checks, then broader regression only when justified.

Record exact source revision/worktree scope, OS/device, commands, test counts, screenshots, actual system placement, signing result, remaining gaps and owner feedback. Do not mark complete with only a successful build. No commit/push/deploy is included in planning authorization.

## Owner-requested build repair — 2026-10-10

See the [build investigation](../docs/testing/sp030-build-investigation.md). Incoming implementation compiles on simulator; explicit app audio/extension plist packaging corrected. Signed device build is blocked by missing extension profile and Xcode No Accounts. This repair does not close G0 or physical feature acceptance.
