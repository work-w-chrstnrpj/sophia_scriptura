# SP-039 — v1.0.0 Scripture audio player and synchronized verse highlighting

Status: draft; owner requested planning, implementation not selected. Created: 2026-10-10.
Target: v1.0.0. Parent: [SP-033](SP-033-v100-multi-source-translation-release.md).
Dependencies: SP-034/035 source and content contracts, SP-037 reader UI; SP-036 for optional offline media. SP-038 depends on this ticket's selected audio acceptance. Requirements: REQ-014 and REQ-023. Owners: Scripture/audio infrastructure, frontend, security, SQA and documentation.

## Outcome and boundary

Owner requests familiar Bible listening: visible player, play/pause, backward/forward and text highlighting as narration plays. Deliver a source-aware chapter narration player and verse highlighting where verified matching timing data exists. YouVersion is a user-experience reference, not evidence of its internal implementation or permission to copy assets. This reopens a bounded narration feature after historical M7 abandonment, without claiming M7 completed.

Initial candidate is AO BSB narration. Prior live Genesis 1 sample listed david/gilbert/hays/souer, with timing links for david/hays/souer. KJV/ASV/LSV/WEBU sample audio maps were empty; do not conclude complete unavailability or promise narration for every edition. Streaming and downloading rights belong to the recording, not merely its public-domain Scripture text. Audio must retain exact translation identity; never play BSB while labelling it NASB, KJV or WEBU.

Excluded: synthetic speech/TTS, word-by-word highlighting, guessed timings, audio for every selected text edition, automatic full-Bible downloads, account/backend, new PiP narration commands, speed controls/sleep timer unless separately selected. SP-032 ESV remains separate and permission-bounded; reuse shared playback contracts if present, not ESV's policies.

## Owner decisions — approved 2026-10-10

| ID | Question | Owner-approved behavior |
| --- | --- | --- |
| A1 | Meaning of forward/backward | Both ±15 seconds and previous/next chapter controls |
| A2 | Continuous playback and reader movement | Independent Continuous chapters and Follow audio toggles, both initially off |
| A3 | Offline scope | Streaming plus optional manual chapter/book downloads after recording rights review |

The owner explicitly selected all three behaviors above. Readiness still requires source/rights/timing evidence. This selection authorizes planning, not product implementation. Existing no-automatic-text-sync rule remains: explicit playback consent is separate from text downloads and lease renewal. Continuous playback, if selected, authorizes only the visible playback queue, never speculative full-library fetching.

## Source evidence and readiness gate

[AO standard chapter/audio timing reference](https://bible.helloao.org/docs/reference/translations/standard.html#get-the-audio-timings-for-a-chapter) documents per-chapter audio links keyed by reader, and optional per-verse start times. AO does not guarantee every chapter/reader has timings.

Before feature readiness, inventory candidate BSB chapters/readers with missing/broken links, available timing files and recording provenance. Record exact recording revision/host, narrator display name, streaming/download permissions, attribution, retention, allowed caching/AI/export and evidence date. Do not infer permission from reachable MP3 or text license. Choose at least one verified BSB recording and matching text/timings for the required release path. Full-Bible narration is not a promise until coverage is audited. If no lawful recording with valid timings can be established, report the blocker; do not silently reduce the owner's highlighting requirement.

Timings must match selected text revision, exact edition/book/chapter and narrator/audio asset. With no publisher version binding, compare representative recording/text passages and document evidence and residual uncertainty; disable highlighting when identity/ordering cannot be established. Source hash is not independent authenticity certification.

## Exact current source and implementation ownership

- `AppShell/StudyAudioCoordinator.swift`: narration protocol plus no-op implementation; music can request narration pause. Replace through a shared owner/arbitration contract, not a second independent audio session.
- `Features/Music/MusicSession.swift` and `Infrastructure/Music/MusicNowPlayingCoordinator.swift`: existing music playback/remote controls. Inspect before changing ownership.
- `Features/SystemPlayer/StudyPiPPlayer.swift`: existing PiP music/Activity command semantics. Narration takeover must not let PiP reclaim music unexpectedly; new narration PiP UI is excluded.
- `Features/Scripture/ReaderSession.swift`, `ReaderTextSurface.swift`, `ScriptureView.swift`, `Annotations/AnnotationRenderer.swift` and `AnnotationSurface.swift`: reader identity, selection/highlight/layout boundaries.
- `Core/Scripture/ScriptureModels.swift`, `ChapterTextMap.swift`: exact source verse identity and body ranges.

Proposed ownership: Core/Scripture narration asset/timing/state values and contracts; Infrastructure/Scripture or a focused Infrastructure/Audio folder owns media transport/cache/AVPlayer; Scripture feature owns observable playback session and player sheet/mini-player; StudyAudioCoordinator owns arbitration. Register concrete files/project membership during implementation, update project structure then. Views never own AVAudioSession, provider transport or file deletion.

## Data and state contracts

AudioAsset identity contains sourceID, editionID, referenceSystemID, textRevision, book/chapter, narratorID, recordingRevision/fingerprint, media URL/approved host and rightsPolicyID. Timing asset binds to that identity; offsets are seconds, not wall-clock timestamps. Do not persist signed expiring URLs as durable identity.

Playback states: idle → loading → playing ↔ paused; playing → buffering → playing; any active state → failed/stopped; ended → next chapter only when A2 permits. Operation epoch invalidates load/seek/completion callbacks after Stop, asset/source change, deletion or credential/policy change. Error retains requested identity and last valid position; it never switches narrator/edition or retries indefinitely. At most one player and one Now Playing owner.

Persist local bookmark only: exact asset identity, position, timestamp and queue preferences; no autoplay on restart/resume. If asset or text revision differs, show saved recording unavailable/changed and require explicit restart. Player sheet shows actual playing translation, narrator, book/chapter, elapsed/duration and loading/error state even if reader browses elsewhere. Closing sheet does not stop playback; explicit Stop releases ownership. Read controls disabled with clear reason where no verified recording exists.

A1 determines seek/chapter controls. Clamp seek to valid duration; seek recomputes highlight immediately from player time. Previous/next chapter follows that edition's validated manifest, including source-only books only when recording exists; unavailable target shows a reason and does not skip silently. Do not use chronological integer assumptions or pretend verse-seeking without timing support.

A2 determines continuous queue/follow controls. Never auto-scroll during an active Pencil stroke, text selection, user scroll, locked content, hidden reader, different displayed edition/chapter or unavailable layout. Suspend follow visibly and expose Return to audio when eligible. Highlight is a transient overlay/attribute; never mutate stored Scripture, reading ink geometry, user selection or annotation bytes. Reader browsing does not silently retarget playback. At source/revision/lease incompatibility, clear highlight and expose actual audio identity; re-check permission before continued playback according to recording/text policy.

## Timing validation and highlighting algorithm

Validate exact timing metadata IDs and audioLink against the chosen asset, finite nonnegative timestamps, monotonic ordering and duration bounds once loaded. AO array positions map verse starts in source verse order. Build a verified explicit ordered verse list from the chapter's actual source mapping; omitted/bridged/non-contiguous labels cannot be inferred as index+1. Require exact unambiguous count/order correspondence; otherwise reject timing for highlighting while keeping independently permitted audio playable with Highlighting unavailable.

Compute current verse as the last verified start <= current player time, until next start; final verse ends at duration. Before first start/intros: no verse highlight. Seek, pause, buffering and interruptions derive highlight from AVPlayer media time, never accumulated timer ticks. Validate duplicate starts deliberately: if several verses share a start, use an explicit supported grouped range with all corresponding mappings or disable that ambiguous timing; do not drop verses. Word highlighting is excluded because verse timing alone cannot identify spoken words.

Use lightweight periodic time observation (proposed 100–250 ms, measurable), binary search timing data and update UI only when verse/state changes. Detach observers on asset replacement/teardown. Use existing text mapping for body ranges and an accessible playback indicator; preserve user selection/emphasis priorities. On annotation surface, render only if exact source/layout matches; any appearance overlay must not cause reflow or persistent layout signature changes.

## Transport, optional offline and safety

HTTPS media hosts are allowlisted from verified source evidence (sample hosts include audio.bible.helloao.org and openbible.com); validate redirects with explicit policy. Never attach API.Bible/ESV/AI keys to AO metadata/media. Respect resource timeouts, bounded retries and cancellation; never log signed URLs, credentials or private study context. Do not send audio to AI.

If A3 selects streaming-only, audit URLSession/AVPlayer intentional disk caching and document actual transient caching; no persistent Download control. If downloads selected, implement chapter-scoped media generations separate from text generation/lease and an explicit selected-book queue. Verify file type, size, playable duration and required rights/asset integrity before commit; handle missing Content-Length and impose bounded bytes while receiving. Resume only verifiable staged assets. Low disk/cancel/crash leaves previous validated media; no partial file advertised offline.

Proposed engineering bounds for owner-reviewed offline mode: one download at a time, 128 MiB per chapter, explicit book batch size estimate or unknown-size notice, free-space reserve 256 MiB plus retained/staging bytes. Measure actual selected recording sizes and adjust with recorded evidence; do not imply a full-Bible size. Download audio and validated timings for the same asset; reading highlight offline also requires corresponding exact text locally. Delete media never deletes text/notes/ink; deleting an in-use asset first stops or obtains a reader lease, then invalidates callbacks. Downloaded recordings excluded from Files backups by default; metadata bookmarks only, subject to rights. Restore never auto-downloads.

## Audio ownership and system behavior

Narration starting pauses music; music starting pauses narration. Neither automatically resumes the other. The active owner alone receives AVAudioSession, Now Playing and remote play/pause/seek/chapter commands; tear down prior handlers before installing new ones. Reconcile interruption, route change/headphone removal, background/lock screen and foreground transitions. Force termination cannot promise continued playback. PiP retains existing music/Activity scope; block stale PiP commands from reclaiming music while narration owns playback. Activity timer state must not change as a side effect of audio arbitration. If SP-032 narration already exists, use one player/session contract with source-specific assets/policies.

## Ordered execution and acceptance

1. Settle A1–A3, audit BSB audio/rights/timing coverage and current audio owners.
2. Implement injected asset/timing/state contracts, parser and mock transport/player/clock; verify mismatch and non-contiguous verse tests first.
3. Implement streaming player and music/system ownership; optionally selected offline media with fault tests.
4. Add Scripture player controls and transient verse highlights; integrate Follow/continuous behavior only as chosen.
5. Verify UI/accessibility, provider/audio-device behavior and documentation; report evidence per case below.

| ID | Required pass evidence |
| --- | --- |
| AU-01 | Verified BSB recording identity, coverage and recording-specific rights; unavailable editions labelled accurately. |
| AU-02 | Play/pause/resume/stop, A1 controls, scrubbing, buffering/error and late callback cancellation; no phantom playback. |
| AU-03 | Timing mismatch/NaN/decreasing/out-of-range/missing/bridged verse fixtures fail safely; valid seek and intro/final verse highlight correctly. |
| AU-04 | A2 continuity/follow behavior, manual scrolling/selection/Pencil suppression and Return to audio; no reflow or stored ink/text mutation. |
| AU-05 | Exact edition/chapter/revision/narrator binding; browsing/switching never highlights another translation or substitutes a recording. |
| AU-06 | Music/narration takeover, remote ownership, headphone/interruption/background/lock screen; existing PiP/Activity regressions pass. |
| AU-07 | A3 offline policy; if selected, cancellation/crash/disk/full/delete/resume/book queue integrity and true airplane-mode playback plus highlight. If streaming-only, no persistent download path. |
| AU-08 | Cold relaunch restores paused bookmark only; no autoplay/download on launch, resume or connectivity recovery; continuous queue network access only with chosen playback consent. |
| AU-09 | Physical iPad real audio + visible verse progression/seek accuracy, touch controls, VoiceOver/Dynamic Type and safe Pencil interaction; observed separately from simulator/mocks. |

SP-038 cannot close audio acceptance merely from a build, audio URL presence or synthetic player tests. Required release path includes real BSB narration with verified synchronized verse highlighting; partial audio coverage is shown explicitly. Offline acceptance depends on A3 and permission evidence, not assumed text rights. Record exact commit, asset, rights evidence, test bundles, device observations and any owner-approved scope change. No native tests performed for this planning-only ticket.

Docs maintained during implementation: TDD/source guide, reader/player screen specification, audio ownership, media data/recovery/rights guide, manual test cases and actual v1.0.0 release notes. Status: draft; A1–A3 approved, recording rights/coverage/timing evidence pending; product implementation not selected.

## Approved playback and download behavior — 2026-10-10

A1: expose separate accessible Back 15 seconds / Forward 15 seconds and Previous chapter / Next chapter controls, plus play/pause and seek bar. Seek remains within current chapter; it does not advance chapters implicitly. Chapter buttons require a verified available target and explain absence.

A2: Continuous chapters and Follow audio are independent persisted preferences, both off on first use. Enabling Continuous permits sequential streaming only for the active chosen edition/narrator queue after explicit playback starts; do not prefetch beyond the next chapter. Stop at missing recording, book/edition end or policy failure; never switch narrator or edition silently. If exact next text is not installed, continuous audio may proceed only with permitted audio identity while highlighting/follow stays unavailable; text requires the separate explicit download path. Following changes visible chapter only after annotation flush succeeds, never during Pencil/selection/manual-scroll suspension. Unchecking Follow does not stop audio or clear a valid in-view highlight. Playback end with Continuous off stays ended with Replay/Next chapter actions. Relaunch retains preferences/bookmark but never resumes playback automatically.

A3: streaming and optional manual chapter or selected-book downloads are included. A Download book action enumerates that source book's verified chapter recordings for the selected narrator, shows available/missing chapters and size estimate/unknown size before confirmation; never represents partial coverage as a complete offline book. Queue progress counts verified chapter assets; Cancel pauses the queue, Resume is explicit. Timing files accompany downloads where available. Complete offline book status requires all declared chapter recordings; mixed streaming/offline playback labels the current asset accurately. No bulk entire-Bible download action. Recording-specific download permission must be documented before enabling either download control. If unavailable, report the permission blocker rather than silently dropping offline scope from v1.0.0.

All AU-01–09 apply, including offline playback/highlighting with networking disabled. Full BSB coverage still requires audit; no recording is assumed present merely because Genesis 1 exists.
