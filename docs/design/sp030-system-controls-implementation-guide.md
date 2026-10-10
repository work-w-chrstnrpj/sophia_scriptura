# SP-030 implementation contract — system music and Activity controls

Status: normative planning guidance; no implementation or feasibility evidence. Updated 2026-10-10.
Parent: [SP-030](../../tickets/SP-030-background-music-and-activity-system-controls.md).

## Read first and execution boundary

Read the parent ticket, AGENTS.md, current MusicSession/BackgroundMusicEngine, ActivityStore/ActivityModels, RootTabView, project.pbxproj, compatibility policy and current deployment/test instructions before editing. Source paths in the parent were inspected on 2026-10-10; revalidate changes made since then. Preserve unrelated incoming work. Do not rewrite modules merely to match proposed names.

Priority: owner instructions > parent confirmed scope > this guide > proposed defaults. If they conflict, record the conflict and resolve it before dependent implementation. This guide narrows engineering choices; it does not authorize code, install, account changes or publication. Once implementation is selected, carry out necessary scoped work without repeated approval, except the unresolved product/platform decision at G0.

Only Home/Lock Screen presentation is requested. Above-other-apps display and a custom in-app pill are excluded. Audio/timing continuity while another app is active remains required. No persistent custom notch is promised. Two separate Apple-owned surfaces are the proposed implementation, subject to G0 owner acceptance.

## G0 — feasibility decision record

Complete this table with evidence before implementing the full feature. Unknown is not Passed.

| Question | Required evidence | Failure disposition |
| --- | --- | --- |
| Actual device/OS and signing team? | Owner iPad model, installed OS, Xcode version and existing team identity; no credential output | Keep device acceptance blocked until known |
| What displays on Home? | Signed minimal sample screenshot plus exact interaction to reveal it | If no suitable Home surface, explicitly ask owner whether Lock Screen-only is acceptable; do not silently redefine scope |
| What displays when locked? | Signed sample screenshot with no private data | Resolve unavailable/disabled support or record fallback |
| Is separate Music + Activity accepted? | Owner accepts observed native surfaces; parent currently proposes them | Do not claim combined capsule parity |
| Can Personal Team sign/embed extension? | Successful signed app+extension build/install with existing account | Stop affected extension work; offer documented fallback, do not change account/capability silently |
| Which OS API availability guards are required? | Current official docs and installed SDK declarations; runtime and build check | Keep app 17+, availability-gate extension features |
| Can local-only updates satisfy timer? | Sample running/paused display with app backgrounded and no audio | No server, fake audio or continuous background execution workaround |

Use Apple links in the parent ticket. Record date, observed OS, surface locations, authorization state, evidence paths and owner decision. A simulator can validate layout and logic, but cannot satisfy signing/physical placement. If device is unavailable, implement only independently authorized work; mark G0 unresolved and do not mark SP-030 complete.

## Ownership and proposed file boundaries

Paths relative to `application/SophiaScriptura/`:

| File/area | Responsibility | Must not own |
| --- | --- | --- |
| `SophiaScriptura/Infrastructure/Music/BackgroundMusicEngine.swift` | Actual AVAudioPlayer state, read-only finite timing, resume existing prepared player | Activity timing or widget state |
| `SophiaScriptura/Features/Music/MusicSession.swift` | Sole music commands, queue, phase and metadata projection trigger | Second player or Activity save |
| `SophiaScriptura/Infrastructure/Music/MusicNowPlayingCoordinator.swift` (new) | Register/remove remote targets once; publish/clear owned Now Playing metadata | Independent queue or playback persistence |
| `SophiaScriptura/Core/Activity/ActivitySystemProjection.swift` (new) | Pure safe timer projection and revision/draft identity | ActivityKit import, private titles, disk writes |
| `SophiaScriptura/Infrastructure/Activity/ActivityLiveActivityCoordinator.swift` (new) | Serialize system requests, availability/auth, reconcile current activities | Study record mutation or analytics |
| `SophiaScriptura/Features/Activity/ActivityStore.swift` | Successful committed projection publication and existing timer commands | Live Activity drawing |
| `SophiaScriptura/RootTabView.swift` | Own coordinator lifetime, observe committed projection, foreground/deep-link reconciliation | Per-second publication or repeated command registration |
| `StudyActivityWidget/` (new sibling source directory) | Widget extension entry, ActivityConfiguration, shared projection presentation | Study repositories, BYOK keys, background network |
| Shared attributes source with app+extension target membership | Small Codable ActivityAttributes and content state | SwiftUI sessions or arbitrary dictionaries |
| `SophiaScripturaTests/` | Deterministic projection, command, persistence/race tests | Real audio/device claims |

New names are proposed, but responsibilities are mandatory. Keep system clients behind small injectable protocols so tests do not require a real Lock Screen. Do not import the whole app into the extension. Avoid a new package/module unless target membership cannot express the shared types cleanly.

## Music state and command contract

Use existing `MusicSession.handle` commands as the single entry. Observe actual engine success before publishing playing. The current `play(takeover:)` prepares a new player every time, which resets position; this is an identified integration defect to fix narrowly so Pause→Play resumes the same prepared track. Also inspect advanceTrack/completion: the current source can call play twice after autoplay selection. Ensure exactly one prepare/play per transition, without changing queue/loop policy.

| Event | Playback result | System metadata/commands |
| --- | --- | --- |
| Cold load with selected track | Idle, no autoplay | No Sophia Now Playing claim until explicit successful play |
| Successful explicit Play | Start selected file or resume retained paused file | Title/duration/current time/rate 1; Pause and valid Next enabled |
| Play fails/missing file | Error; never claim playing | If no prior valid owned item, publish nothing; otherwise paused actual state/rate 0; no bogus duration |
| Pause | Existing player retained at current time | Rate 0; Play enabled only if file is valid |
| Interruption/headphones removed | Existing interruption policy; no automatic resume | Rate 0, valid paused metadata; Activity unaffected |
| Resume same selected file | Continue same offset, do not prepare again | Actual current time/rate 1 |
| Next while playing | One valid queue advancement and one play | New title/duration/time after engine preparation succeeds |
| Next while paused | Existing queue selection semantics preserved; no autoplay | Metadata must describe newly selected item truthfully; rate 0 |
| End with next/loop target | Advance once and play once | Publish new item once |
| End without next | Existing end/paused behavior | Rate 0, elapsed clamped to duration; no nonexistent Next |
| Stop/clear/delete active file | Stop player | Clear only metadata owned by this coordinator, disable owned commands |
| Home/lock/inactive scene | No playback mutation | Keep current accurate state |

Remote command mapping: Play→`.play`, Pause→`.pause`, Toggle→`.togglePlayPause`, Next→`.next`. Enable only applicable commands. Unsupported previous/seek/rating/bookmark commands stay disabled. Handler must not return success merely because an asynchronous Task was enqueued: use synchronous MainActor dispatch where supported, or a documented command bridge returning accepted/unavailable truthfully; keep feedback consistent with actual session failure. Never block the main thread waiting on itself.

Metadata: actual title, duration in seconds, elapsed seconds and playback rate; optional licensed artwork only. Clamp finite timing to [0,duration] when duration is positive; no NaN/infinity. Do not supply false artist/album/artwork. Use OS progress extrapolation; no background one-second metadata loop. User-imported filenames/titles are user media metadata and can appear in Now Playing, as with the current library; never attach study text. Audio session activation remains explicit Play, not launch or metadata publication. Register exact remote targets once and remove those exact tokens; do not remove all handlers globally.

## Activity projection data contract

Proposed pure value, Equatable and Sendable, not persisted as study data:

```swift
struct ActivitySystemProjection {
    let draftID: UUID
    let revision: UInt64 // process-local monotonically increasing commit sequence
    let accumulatedSeconds: TimeInterval // sum of completed intervals
    let runningSince: Date? // nil means paused
}
```

ActivityAttributes fixed identity: draftID only. Content state: accumulatedSeconds, runningSince, revision; no title, mode text, description, references, excerpts or provider data. If an SDK requires an extra presentation field, document why and keep it non-sensitive. Validate finite nonnegative seconds. A missing/invalid projection disables system presentation without deleting the draft.

For running display at instant t:
`elapsed = accumulatedSeconds + max(0, t - runningSince)`.
For paused display: `elapsed = accumulatedSeconds`.
Effective timer origin is `runningSince - accumulatedSeconds`; system-rendered timer text must agree with the canonical algorithm. Future runningSince/clock rollback requires clamping: do not let an effective-origin shortcut accrue completed intervals prematurely. Test this case; use fixed accumulated display until the running segment can validly advance if necessary. Keep existing wall-clock timing semantics; do not redesign clock correction in SP-030.

Numeric fixture: run 10:00→10:02 = 120s; pause until 10:07 remains 120s; resume 10:07→10:08 = 180s. At 10:08 canonical elapsed and system projection must agree. On cold load reconstruct projection from repository snapshot, not an in-memory counter or ActivityKit ID.

## Save acknowledgment and race contract

Do not observe optimistic `snapshot.draft` as durable truth. Add an in-memory `@Published private(set)` committed projection and revision (or equivalent typed event). Publish only after `repository.save(candidate)` succeeds or a validated repository load/restore succeeds. A nil committed draft is a real successful no-draft state, not a failure sentinel. Distinguish `notLoaded` from `loadedWithoutDraft`.

Every queued save captures its immutable candidate and sequence. Update the committed projection from that candidate after success. Do not reread the newer mutable snapshot in a completion handler. Serialize saves using the existing chain; revision guards prevent older acknowledgments replacing newer successful state. On failure retain the last committed projection, expose the existing save error and issue no fake success event. A later successful full snapshot becomes the new truth even if an earlier save failed.

Audit all repository.save/load/restore paths, including Sophy actions, reminder saves, mode edits, backup restore and delete-data, so a committed snapshot can never be bypassed. Prefer one helper to publish successful repository state. Do not add a new disk revision or rewrite archives. Existing UI optimistic behavior stays unchanged unless a necessary scoped fix is explained and tested. `flush()` is not a proof of success because current implementation catches errors internally.

System operations must be serialized independently of disk saves. Hold latest desired committed projection, request generation, foreground/auth status, and existing system activity identity. After each awaited request/update/end, reread generation and desired draft. If a start returns after desired=nil or a different draft, end that returned activity immediately; never reattach it. Catch errors explicitly; no retry loop.

| Input/state | Coordinator action | Canonical Activity effect |
| --- | --- | --- |
| Not loaded | Wait; do not end potentially valid system item yet | None |
| Committed running draft, foreground, allowed | Reuse matching item or request one if eligible | None |
| Committed paused draft | Update same item with fixed elapsed/Paused | None |
| Commit failed | Keep prior committed projection; surface save error in app | None beyond existing optimistic UI |
| Committed nil | End all Sophia timer items | None |
| Different draft committed | End old item, then consider new request | None |
| Foreground after background | Enumerate/reconcile matching draft ID; remove orphan duplicates | None |
| Background with no system item | Do not illegally request new item; defer until foreground | None |
| System permission denied/request fails | Record bounded presentation status; keep app controls | None |
| User dismisses timer item | Suppress recreation for that draft during this process | None |
| OS expiry/end | Mark presentation ended; no same-draft automatic restart loop | None |
| Restore succeeds | Invalidate generation, reconcile restored committed snapshot | Restore only through existing owner |
| Restore fails | Keep current desired projection | Existing restore failure semantics |

Suppressions are ephemeral; do not silently add persistence. Across process restart system dismissal history may be unavailable: a matching active draft may be offered again on deliberate foreground reconciliation. Document this limitation and verify owner tolerance at G0. Do not claim permanent dismissal memory.

At most one non-ended timer Live Activity per app draft. If duplicates exist, keep one deterministic match (for example oldest creation date, ID tie-break), end the others. Avoid ending another feature's ActivityKit type. Subscribe to relevant system lifecycle changes with cancellation on teardown. Retry request/update only on a new committed revision, authorization change or foreground reconciliation; bound to one attempt per trigger. Never retry after same-draft dismissal/expiry within the process. Eight-hour system expiry does not cap study duration or create a completed record.

## Presentation specification

Apple owns surface dimensions, corner shape, ordering, visibility and final placement. No hardcoded screen coordinates, safe-area overrides or synthetic notch. No combined layout requirement unless G0 proves an available supported surface and owner selects it.

Timer Lock Screen content: left timer symbol + “Study activity”; right “Running” or “Paused”; elapsed duration below or alongside as space permits. Elapsed uses monospaced digits, hours when needed and no negative values. Paused duration is static. Whole card taps to open Activity. No external pause/resume/finish/discard buttons in v1. App-only completion requirements are preserved.

Use system text styles and semantic colors, visible in light/dark appearance, minimum accessible contrast, no status communicated by color alone. At large text sizes use vertical layout and allow the generic label/status to wrap; timer stays legible. Do not shrink below readable text to mimic a pill. Supply required compact/minimal/expanded representations with generic timer symbol/time/status; device availability is not inferred from supplying a preview. Home presentation is the actual system-approved presentation observed at G0, not a custom overlay.

Fallback inside existing Activity screen: a concise nonblocking status “Live Activity unavailable” or “Live Activities are turned off” when appropriate, without implying the timer stopped. No unsolicited permission prompts at every launch; query authorization and handle disabled state. Existing navigation/dock/floating controls remain intact.

Music UI is native Now Playing; do not recreate it inside a widget. If the OS retains a paused media card or orders cards differently, record actual behavior instead of adding a workaround.

## Deep-link contract

Prefer the existing app URL registration if present; otherwise propose a narrowly scoped `sophiascriptura://activity` route and register it in app configuration. Shared source produces only that constant; no private query parameters or mutable command payloads. Reject unknown schemes/hosts/paths/query actions. Route to existing Activity tab after app readiness. No new timer is started, no draft is finished, and no arbitrary IDs are trusted. If there is no draft, open the normal Activity screen. Verify cold and warm launches, including locked/protected state; do not bypass app protection.

## Ordered work packages and exit gates

| Gate | Deliverable | Must pass before next dependent package |
| --- | --- | --- |
| G0 | Feasibility record and owner placement decision | Actual supported surfaces and signing known; otherwise affected work blocked |
| G1 | Music engine resume/one-play fixes, injectable Now Playing bridge | Metadata/command/resume tests pass; no duplicate player/register |
| G2 | Pure projection and committed-state signal | Time math, failed-save and ordering tests pass with legacy fixtures |
| G3 | Extension target/attributes/presentation | App and extension Debug/Release build, availability and privacy checks |
| G4 | Live Activity coordinator/reconciliation | Delayed start/end, duplicate, auth, dismissal, expiry and restore tests pass |
| G5 | Root/deep link/integration | Existing Music/Activity flows pass; no in-app redesign or provider changes |
| G6 | Signed physical acceptance and docs | Parent AC1–AC10 evidence recorded; no unsupported Home placement claim |

For each package record files touched, behavior changed, exact commands/results and remaining gaps. Do not implement later dependent gates around a failed earlier gate. Independent music/projection tests may proceed if selected; missing physical G0 still blocks claiming final product acceptance. No version/tag/release changes until separately selected.

## Deterministic automated test matrix

Proposed suites: MusicNowPlayingTests, ActivitySystemProjectionTests, ActivityCommittedProjectionTests, ActivityLiveActivityCoordinatorTests, SystemControlsRoutingTests. Use injected player/system clients/repository and controllable clock/await continuations. Do not sleep to reproduce races.

| ID | Setup/action | Required assertion |
| --- | --- | --- |
| M01 | Cold selected-track load | No play, activation or metadata ownership |
| M02 | Play at 0, pause at 37s, resume | Same prepared file, offset 37s, one play per command |
| M03 | Next/completion with loop on/off | Correct existing queue target, one prepare/play, no duplicate callback |
| M04 | Missing/corrupt file | Rate never 1; truthful command result and existing error |
| M05 | Repeated attach/detach | One handler per command, only owned targets removed |
| M06 | Interruption/output removal/Stop | Rates 0; Stop clears owned metadata; Activity unchanged |
| M07 | Remote pause/next at queue end | Actual command eligibility; no hidden autoplay/invalid advancement |
| A01 | 120s completed + 60s resumed | Exactly 180s, paused remains 120s |
| A02 | Future runningSince/clock rollback | Same clamped result as canonical activeSeconds(at:) |
| A03 | Pending start save fails | No new committed projection or system request |
| A04 | Old save completes after newer intent | Candidate/revision truth preserved; no reread of optimistic snapshot |
| A05 | Pause fails then later snapshot succeeds | Previous committed running projection retained until later success |
| A06 | Finish/discard fails | No successful nil event and no premature end |
| A07 | Start system request suspended; finish commits | Returned late item ended; no resurrected card |
| A08 | Draft A update pending then B restore succeeds | A cannot overwrite/recreate B; stale operations ignored/cleaned |
| A09 | Permission off/system update throws | Bounded error/status; canonical draft unchanged; no tight retry |
| A10 | Duplicate/orphan reconciliation | One matching item retained, others ended; no study record created |
| A11 | User dismissal/expiry | No same-process same-draft restart loop; timer still accrues |
| A12 | Legacy load/restore, failed restore, delete data | Correct committed projection; backups unchanged; success-only cleanup |
| R01 | Valid/unknown/malicious/deferred URL | Only Activity navigation; no mutation or protection bypass |
| P01 | Attributes JSON encode | No private fields or text; finite values only |

## Verification commands and physical script

Choose installed simulator from `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices available --json`; do not hardcode a previously available device. Substitute its UUID below. Result paths must not already exist.

```sh
mkdir -p build/sp030
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project application/SophiaScriptura/SophiaScriptura.xcodeproj \
  -scheme SophiaScriptura \
  -destination 'platform=iOS Simulator,id=SELECTED_UUID' \
  -resultBundlePath build/sp030/focused-tests.xcresult \
  -only-testing:SophiaScripturaTests/MusicNowPlayingTests \
  -only-testing:SophiaScripturaTests/ActivitySystemProjectionTests \
  -only-testing:SophiaScripturaTests/ActivityCommittedProjectionTests \
  -only-testing:SophiaScripturaTests/ActivityLiveActivityCoordinatorTests \
  -only-testing:SophiaScripturaTests/SystemControlsRoutingTests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

These suite names are planned, not existing test evidence. Verify the executed count is nonzero and all intended tests are included. Then run relevant existing Activity/Music tests and UI workflows identified from exact source. Build Debug and Release for simulator plus signed device with embedded extension using deployment instructions; ensure scheme includes extension as a dependency. Inspect generated app Info.plist for UIBackgroundModes audio, Live Activities support and URL routing; inspect extension Info.plist for WidgetKit extension point. No passing claim from project settings alone.

Physical checklist (each Not Run until executed):
1. Install in place after G0 signing review; record data-preservation checks and selected local test track.
2. Start music only; Home then lock for five minutes. Confirm audible continuity and actual native title/play/pause/next controls. Reopen without restarting track.
3. Stop music. Start Activity only, note timestamp; Home and lock five minutes. Check elapsed at reopen within one-second display rounding and agreed external surface; ensure no audio session kept active for timer.
4. Pause Activity for two minutes, resume for one minute. Paused gap excluded, final total matches canonical intervals.
5. Run both; pause/stop each independently. Use another app only to verify continuity, not overlay display.
6. Dismiss timer presentation and disable authorization; underlying Activity survives and no restart loop appears. Reenable and document intentional next-foreground behavior.
7. Trigger headphone removal/interruption; no automatic unexpected music resume, no timer pause. Clear active track; stale owned metadata removed as system permits.
8. Tap timer card cold/warm. Activity opens; no auto-start/finish. Reading completion still asks for ending reference.
9. Finish/discard in Sophia and verify timer presentation ends. Restore a test archive using isolated fixture data; no duplicate/orphan cards. Never restore destructive fixtures over personal data.
10. Record long-session expiry evidence when practical; otherwise mark that physical case open and retain injected automated coverage. Record screenshots of Home and Lock Screen and owner acceptance of actual placement.

## Review and stopping rules

Reject completion if any of these occur: app minimum raised without selection; fake audio/video/PiP; background per-second loop; ActivityKit treated as timer truth; snapshot observed as save success; new disk schema without necessity; private text in extension; extension writes study data; second music player; duplicate handlers; pause→play resets track; swallowed system errors; live surface unavailable but acceptance claimed; another-app overlay work; physical evidence replaced with simulator pass.

If platform support fails, document supported fallback and stop dependent work for owner choice. If tests fail, repair within scope and rerun affected checks; do not weaken assertions to match incorrect behavior. If source changes materially during execution, reread relevant exact files and update this guide's baseline rather than reverting owner work.

Closeout report: gate statuses G0–G6, AC1–AC10 mapping to evidence, commands/test counts, actual surfaces, signed device result, privacy/compatibility result, remaining owner/device gaps and explicit release status. No “done” while required feasibility/physical gates remain unresolved.
