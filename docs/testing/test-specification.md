# Test specification — Sophia Scriptura

Documentation source review: **2026-10-18**. The dated runs below are historical evidence,
not tests rerun during documentation maintenance. The SP-048 record
is at the end of this page; released v1.3.1 evidence is in its
[release notes](../releases/v1.3.1.md). Device/provider/accessibility gaps remain open
where recorded. Use an installed iPad simulator and the native commands below.

## Notes bulk-delete confirmation — 2026-10-05

`NotesUITests.testBulkDeleteConfirmsCancelsAndPersistsOnlySelectedNotes` passed on
iPad (A16) Simulator and the physical `iPad ni Paj`: **1 passed, 0 failures** per run.
It creates three temporary notes, selects two, cancels the portrait confirmation,
confirms in landscape, and checks that only the unselected note remains after relaunch.
Results: `build/notes-bulk-delete/after.xcresult` and `ipad-after.xcresult`.
The tests use an isolated `SP009_TEST_STORE`, without deleting personal notes.
The original portrait flow also passed on both devices (`before.xcresult` and
`ipad-before.xcresult`); the owner's missing-dialog symptom was not reproduced.
The fix scopes the confirmation to the Delete button and captures IDs at tap time.
Owner acceptance of the original failing interaction remains pending.

## v0.2.0 Notes writing — 2026-10-05

Final build 16 release gate: **210 unit tests passed, 0 failures**, including 34 Notes
tests, on the iPad (A16) simulator below. Result: `build/v020-release/final.xcresult`;
log: `build/v020-release/final-tests.log`. New compatibility coverage removes the three
new editor keys from historical object payloads and verifies defaults and round trips.
The first attempt failed to compile a new sanitization fixture because its initializer
arguments were out of order; the fixture and assertions were corrected before this pass.
UI tests and final-build physical Pencil acceptance were not run.

Earlier build 2 evidence:

Focused `SophiaScripturaTests/NotesTests` on iPad (A16) simulator
`523DDB8A-9EF6-44ED-A4F8-F8059ECB7725`: **29 passed, 0 failed**. Result:
`build/v020-notes.xcresult`. The signed device build installed in place; see
[deployment](../deployment/deployment.md). Notes UI cases for the Page/Journal toolbar
and the Old Paper preset title were updated and not executed in this pass. Physical
Pencil feel remains an owner check.

## Release CI repair — 2026-10-04

Run `37206541180` on `main` reproduced an Xcode 16.4 compiler timeout in
`NotesSession.Edit.bytes`. The equivalent calculation is now split into typed page,
attachment and object subtotals; no history limits or persistence formats changed.
The prayer-count test now uses `@MainActor`, async repository loading and public note
creation rather than an unsupported initializer and private setters. It additionally
checks that the count and same-day guard survive saving/reopening. Hosted verification
also exposed equivalent compiler-complexity failures in note search text and the
Collections detail view. These now use smaller expressions/view boundaries without
changing behavior. Two stale tests were corrected: the legacy v2 fixture explicitly
constructs Page content, and No Folder expects its fixed neutral accent. The workflow
selects an available iPad using `simctl` JSON and waits for boot instead of relying on
`grep`/`head` output parsing under `pipefail`.

Local final app-code verification: **202 passed, 0 failed, 0 skipped**, recorded in
`build/ci-repair-complete-20261004.xcresult`. Hosted run `37207083125` is the final
workflow verification: **passed**, including simulator build and unit tests. Its
publish job confirmed the existing tag and skipped release creation. Existing `v0.1.0` remains unchanged; fixes on main are newer
than that immutable release snapshot.

## M9 integrated closure — 2026-10-04

**Owner verification:** The owner tested the app on a physical iPad and reported **all pass**
for personal daily use. That gate covers cross-tab study flows, Pencil behavior, data
persistence and feature integration. It does not replace automated regression below.

**M7 Scripture audio:** Abandoned; listening steps in manual journeys are **Not Run**.

**Automated regression (full scheme):** Run every `SophiaScripturaTests` and
`SophiaScripturaUITests` target on iPad (A16) Simulator:

```sh
mkdir -p build/m9-full-suite
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project application/SophiaScriptura/SophiaScriptura.xcodeproj \
  -scheme SophiaScriptura \
  -destination 'platform=iOS Simulator,id=523DDB8A-9EF6-44ED-A4F8-F8059ECB7725' \
  -derivedDataPath build/m9-full-suite/DerivedData \
  -resultBundlePath build/m9-full-suite/results.xcresult \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
```

Evidence bundle: `build/m9-full-suite/results.xcresult`. Summarize with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcresulttool get test-results summary \
  --path build/m9-full-suite/results.xcresult
```

### Recorded evidence — M9 automated runs (2026-10-04)

**Unit tests (`SophiaScripturaTests` only):** **181 passed, 0 failed, 0 skipped** on iPad
(A16) Simulator / iOS 26.5. Result bundle: `build/m9-unit-suite/results.xcresult`.
**TEST SUCCEEDED.**

**Full scheme (unit + UI):** **200 passed, 23 failed, 1 skipped** on the same destination.
Result bundle: `build/m9-full-suite/results.xcresult`. Failures are confined to
`SophiaScripturaUITests` (landscape timing, dock visibility, scroll/hittable flakes after
feature growth). Failing classes on 2026-10-04: `AnnotationUITests` (2),
`CanvasExperimentUITests` (4), `CollectionsUITests` (2), `NotesUITests` (4),
`PencilShapeUITests` (1), `ScriptureReaderUITests` (2), `ShellNavigationUITests` (5),
`ThemeWorkspaceUITests` (3). **TEST FAILED** for the combined scheme; M9 closure treats
owner physical verification as authoritative for UI while unit automation stays green.

Re-run unit gate only:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project application/SophiaScriptura/SophiaScriptura.xcodeproj \
  -scheme SophiaScriptura \
  -destination 'platform=iOS Simulator,id=523DDB8A-9EF6-44ED-A4F8-F8059ECB7725' \
  -derivedDataPath build/m9-unit-suite/DerivedData \
  -resultBundlePath build/m9-unit-suite/results.xcresult \
  -only-testing:SophiaScripturaTests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

## Current implemented coverage

SP-006 has hosted XCTest model/store/session tests and XCUITest interaction tests under
`application/SophiaScriptura/SophiaScripturaTests/` and `SophiaScripturaUITests/`.
The shared SophiaScriptura scheme includes both. Unit coverage includes independent and
grouped geometry, clamping, zoom conversion, undo/redo, validation, real drawing/image
round trips, corrupt-file preservation, delayed ink updates, and autosave ordering.
UI checks cover movement, Undo, grouping, text edit, save/reopen, relaunch, rotation and
finger-generated PencilKit input. Tests use a DEBUG-only UUID-scoped fixture directory
so their disposable data does not overwrite the owner's normal experiment sample.

## M8 Activity and planned background-music coverage

Automated `MusicTests` validate the bundled catalog digests, next-track wrapping, preferences persistence, and the narration stub coordinator. Physical background, lock-screen, and interruption checks remain iPad-only.

The Activity cases below are SP-020 acceptance targets; background music remains
unimplemented. Automated cases and the iPad walkthrough cover different parts of these targets:

- Timer active duration equals wall-clock elapsed time minus every pause interval; background,
  lock and relaunch preserve state without accumulating paused time.
- Reading start selection routes to the chosen edition/reference, the focus highlight fades,
  and finish requires a valid end reference. Cross-chapter and cross-book ranges remain
  continuous; a disconnected range creates another record.
- Manual records enforce title, mode, date and duration; optional start/end clock times
  derive duration; editing and correction preserve valid records.
- Ten active minutes is the default daily goal/streak threshold. Timer/manual records count.
  Custom modes qualify under the SP-020 implementation default. Goal progress and
  day/week/month/mode analytics agree with saved records. Midnight and overlap rules
  require owner acceptance on the iPad.
- The Now Active cluster appears only for in-use timer/music services, preserves paused
  controls, disappears after stop/save, and does not obscure the tab dock or active workspace.
- Music does not autoplay; it changes/pauses/plays on request and survives background/screen
  lock. Starting narration pauses music; choosing Play on music pauses narration; Activity
  elapsed time remains unaffected.
- Every bundled track has retained source, human composer/performer, composition and
  recording license evidence, retrieval date and digest.

## M6 Companion and Quiz Me coverage

SP-023 response/source/control-row follow-up (2026-10-04):
`build/companion-source-repair-r3-20261004.xcresult` records **56 passed, 0 failed,
0 skipped** across CompanionTests, ScriptureHubTests, CompanionSourcesTests and
CompanionAdapterConformanceTests on iPad (A16) Simulator / iOS 26.5. Coverage verifies
source URL normalization/rejection, publisher passage links, lookup for missing URLs,
no false retrieval flags from bibliographies, draft-artifact failure with retained raw
attempts, curated model fallback, new manual Ask model correction and unchanged OLA
selection. Earlier request/persistence/Markdown regressions passed. No real provider
response quality is established by fixtures. On device, start a new Ask, check the Model
selection, open Sources links, and verify Chapter appears in the annotation/actions row.

SP-023 Chapter Hub and contextual Ask (2026-10-04):
`build/chapter-hub-ask-final-20261004.xcresult` records **60 passed, 0 failed, 0 skipped**
on iPad (A16) Simulator / iOS 26.5 across CompanionTests, ScriptureHubTests and
ScriptureReaderTests. Tests capture Session-to-provider requests, verify the serialized
Groq-compatible user turn carries reference/translation and full authorized verse context,
and cover blank drafts, retry/edit-resend, reference/local-only exclusion, selected focus,
chapter persistence/separation, old optional-field decoding, edition filtering, verse-order
aggregation, range deduplication and request character budget. Existing OLA coverage passed.
The first run had two new fixture failures because Quiz Me background warmup was captured
as chat traffic; the fixture now separates chat requests without disabling app lifecycle.

Reproduce with the documented simulator command and
`-only-testing:SophiaScripturaTests/CompanionTests`,
`-only-testing:SophiaScripturaTests/ScriptureHubTests`, and
`-only-testing:SophiaScripturaTests/ScriptureReaderTests`.
No real provider credentials or calls are used. Follow the [SP-023 iPad cases](../../tickets/SP-023-chapter-hub-and-contextual-ask.md)
for physical hub routing, rotation/narrow widths, real-model explanation quality and
chapter/verse conversation reopen acceptance. Automated request correctness does not
guarantee factual accuracy or model compliance.

Manual Ask composer follow-up (2026-10-04): `build/ask-blank-composer-20261004.xcresult`
records **40 passed, 0 failed, 0 skipped** in CompanionTests on iPad (A16) Simulator /
iOS 26.5. New checks cover a blank composer with no automatic/empty send, save/reopen,
the exact owner question plus separately attached verse context, and reference-only Ask
without restricted text. OLA regression tests passed unchanged. On device, start a new
Ask from Scripture, confirm the blank question box and verse attachment, type your own
question and send; verify OLA still follows its existing auto-send analysis behavior.

OLA selection-aware follow-up (2026-10-04): `build/ola-selection-20261004.xcresult`
records **52 passed, 0 failed, 0 skipped** across Companion and Scripture reader tests on
iPad (A16) Simulator / iOS 26.5. Coverage includes word/phrase classification, translation
and context prompt contracts, OLA title/provider-content/attachment save and reopen,
restricted-text exclusion, unchanged ordinary Ask, and full involved verse expansion with
split/bridged bodies, Unicode and excluded headings/footnotes.

Owner acceptance for this follow-up: start a new OLA request from one word and another
from a phrase or multi-verse selection. Check the `OLA:` title, selected wording, active
translation and complete verse attachment; inspect whether the real model analyzes the
actual target, keeps the correct book/reference, distinguishes senses from contextual
meaning, and cites genuine same-lemma usages. Independently check original forms and
references against a trustworthy text/lexicon. Prompt-contract tests do not verify model
claims or establish exhaustive concordance coverage.

SP-019 adds focused checks for cache schema round trip, warm start without a provider
request, local duplicate rejection, 20/10/6 refill targets, exact deficit replacement,
and completion/quit refill requests without duplicate Reviewing links.
`build/sp019-two-quiz-cache-final-r3.xcresult` records 26 passed, 0 failed, 0 skipped
on iPad (A16) Simulator / iOS 26.5 for the SP-019 follow-up.
The first empty-bucket generation and real-provider timing remain owner/device checks;
in-app background work is not guaranteed after iOS suspends the app.
`build/sp019-cache-final-r2.xcresult` records 25 passed, 0 failed, 0 skipped across
`CompanionTests` and `QuizMeTimerTests` on iPad (A16) Simulator / iOS 26.5.

SP-018 refinement evidence: `build/m6-ai-quiz-r3/results.xcresult` records 21 focused
`CompanionTests` and `QuizMeTimerTests` passing on iPad (A16) Simulator / iOS 26.5.
Automated coverage includes serialized persistence, last-10 per-type exclusion context,
difficulty rubric construction, duplicate rejection, structured generated questions and
local correct-answer repositioning across all four ordinary multiple-choice positions.
Real-provider factual quality, semantic near-duplicates, perceived difficulty, Notes date
appearance and physical-device launch behavior remain manual acceptance checks.

SP-016 also defines broader targets. Each selected implementation ticket must convert its
relevant targets into executable unit/integration/UI tests and retain provider fixtures
without real keys or private responses:

- Every adapter passes the same normalized streaming event, cancellation, refusal, partial
  reply, retry-idempotency and malformed-response contract while advertising differences.
- Multiple Keychain configurations remain isolated; replacement/deletion works; keys,
  authorization data and private request bodies never enter logs, records or exports.
- Conversations pin provider/model/capability/preset snapshots, remain isolated, preserve
  panel/tab/relaunch state and branch explicitly when the provider changes.
- Context-budget trimming, explicit attachments, unauthorized Scripture blocking and
  deletion-driven summary invalidation are deterministic and inspectable.
- Retrieval evidence renders as normalized sources; unavailable or unsupported retrieval is
  never presented as a completed search or verified citation.
- Checksummed generation publication, previous-generation recovery, corrupt preservation,
  migration, import rollback and permitted backup round trips preserve conversations/quizzes.
- All four presets have reviewed evaluation cases for attribution, uncertain evidence,
  contested views, fabricated-source avoidance, original-language claims and pastoral tone.
- Quiz tests cover every answer control, generated-response validation, recent-question
  exclusions, ambiguous speaker exclusions, timeout/background pause, score/history,
  Christian History provenance, deletion and Reviewing linkage without duplicated answers.
- Context-building tests assert the Markdown response contract and the structured Original
  Language Analysis prompt. Quiz tests assert that Identify the Reference is not selectable,
  Bible Quiz and Bible or False are selectable, and generated sets decode with the exact
  count and type sequence required by the selected difficulty.

## Commands

The accepted reader contract specifies `READER-DATA-01` through `READER-DATA-12` in
[Scripture reader data contract](../data/scripture-reader-contract.md). SP-009 must add
and execute them with importer/repository/state implementations. All are currently Not Run.

SP-003 cases LAYOUT-01–03 move into SP-009 so the actual product reader proves passage
selection, hit testing and source mapping. Annotation cases LAYOUT-04–09 remain in
[SP-008](../../tickets/SP-008-scripture-layout-validation.md) as the selected first M3 validation gate (2026-09-29).
Physical annotation cases LAYOUT-04–09 are owner-reported successful on 2026-09-29; VoiceOver is waived for this gate.
See the [SP-008 walkthrough](sp008-ipad-guide.md). Notes tests do not prove Scripture alignment.

SP-002 content/import cases CONTENT-01–10 are specified in
[Scripture content feasibility](../integrations/scripture-content.md). They are planned,
not executed. Research validates a source/license candidate, not an imported Bible.

Latest Collections evidence (2026-10-01, SP-015): `build/sp015-final.xcresult` on iPad
(A16) Simulator / iOS 26.5 passed all 108 unit tests, all four `CollectionsUITests`
(folder nesting/color/deletion, filing a note, saving a bookmark to a new collection then
moving it and opening a centered card, gleaning Edit/Save/Clear) and the four
`AnnotationUITests`. Collections now persist through `CollectionsFileRepository`. UI
tests use the `SP009_TEST_STORE` directory, so they never touch personal data. The two
Collections shell-navigation tests create their own folder instead of using the removed
demo data. `testAppearancePresetPersistsAcrossRelaunch` and the Settings final-row test
fail with Settings content off-screen; the first was reproduced on unmodified `HEAD`.
See [SP-015](../../tickets/SP-015-collections-and-save-flow.md).

Earlier SP-007 prototype evidence (2026-09-21): `build/sp007-20260921-r2.xcresult` reports
**9 passed, 0 failed, 0 skipped** on iPad A16 Simulator / iPadOS 27.0, destination
`709D6F70-328D-4458-8F8A-B2C47A945A80`. This includes seven store tests and two UI tests.
`build/sp007-device-20260921.xcresult` reports **2 passed, 0 failed, 0 skipped** for
both Collections UI journeys on the physical iPad A16 / iPadOS 27.0. The native menu
explanation is exposed as a disabled button on this OS; the test now matches its exact
label without assuming StaticText. No runtime code changed. SP-007 is closed within its
prototype scope. The earlier physical Canvas text-editing assertion failure remains
unresolved and was not rerun here; these results are not a full-suite pass. Both runs
emitted an all-orientations Info.plist warning for later app-shell work.

For the Collections prototype, select the same installed iPad destination and use:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project application/SophiaScriptura/SophiaScriptura.xcodeproj \
  -scheme SophiaScriptura \
  -destination 'platform=iOS Simulator,id=523DDB8A-9EF6-44ED-A4F8-F8059ECB7725' \
  -derivedDataPath build/sp007-simulator \
  -resultBundlePath build/sp007-next-run.xcresult \
  -only-testing:SophiaScripturaTests/CollectionsStoreTests \
  -only-testing:SophiaScripturaUITests/CollectionsUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Use a fresh result path. Collections fixtures are in memory and never read/write personal
notes. Unit tests cover shared/direct/descendant memberships, safe folder deletion and
invalid targets. UI tests cover creation, membership changes, child navigation, filters,
sorting, search and child promotion. These checks do not prove production persistence,
VoiceOver or physical-device performance. Build/test commands need Xcode service access;
sandbox denials must not be diagnosed as a broken simulator installation.

Select an installed iPad simulator from `xcrun simctl list devices available`.
On this Mac the verified destination is iPad (A16), iOS 26.5:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project application/SophiaScriptura/SophiaScriptura.xcodeproj \
  -scheme SophiaScriptura \
  -destination 'platform=iOS Simulator,id=523DDB8A-9EF6-44ED-A4F8-F8059ECB7725' \
  -derivedDataPath build/sp006-verification/DerivedData \
  -resultBundlePath build/sp006-verification/new-run.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

Create `build/sp006-verification/` first. Use a new result path per run.
Keep reports in this ignored project folder; earlier `/private/tmp` reports were removed
between sessions and cannot serve as retained evidence. Open the xcresult in Xcode for failures and attachments.
Simulator access may require host permissions; no source tests run in a browser.

## Recorded evidence — 2026-09-15

- Native simulator build passed.
- Run 01: 12 unit tests passed.
- Run 02: 13 unit tests passed, two UI tests failed (Undo movement and finger ink).
- Run 03: 13 unit tests and the move/group/edit/relaunch UI test passed; the finger
  drawing check still failed. Runs 04–05 isolated the switch interaction. Run 06 passed
  the drawing/save/reopen test after giving the toggle an explicit control-sized layout.
  Run 07 was started but its temporary report was lost before final verification; no
  full-suite success is claimed from that run.
- Signed physical-device build and installation passed. The owner subsequently opened and tried the canvas, reporting broad operation and a missing native Pencil palette. Detailed physical checks remain pending.

## Device evidence and remaining coverage

Use the [SP-006 iPad walkthrough](sp006-ipad-guide.md). Pencil latency, palm rejection,
physical memory, VoiceOver, window resizing and canceled gestures require explicit
observations. No production reader/provider/Companion behavior exists to test yet.
Full Notes/ink/media recovery and production performance contracts remain SP-005 work.

## Retained suite verified — 2026-09-17
Read the retained
`build/sp006-verification/final-20260915.xcresult` using `xcresulttool get test-results summary`:
15 tests passed, zero failed, zero skipped, on iPad A16 Simulator / iOS 26.5. This is
simulator evidence only. The eleven physical walkthrough checks remain unverified;
guided execution starts with independent object movement.

2026-09-17 final hang-fix verification: `select-hang-20260917.xcresult` reports
15 passed, zero failed, zero skipped on iPad A16 Simulator / iOS 26.5. Signed physical
build and installation succeeded; owner passed three Pencil Draw → Select cycles
with movement/Undo and intact handwriting. Treat the reported hang as fixed for this
verified scenario; continue the remaining physical walkthrough. Xcode emitted debugger
metadata and diagnostic-collection warnings, but the test result itself is Passed.

## Automated grouping check — 2026-09-17

Owner requested automation of the explicit-grouping walkthrough. Added
`CanvasExperimentUITests.testGroupingUngroupingPreservesIndependentObjects` using
an isolated UUID fixture. At 50% zoom, it checks text/ink frames before grouping,
after two right moves, after ungrouping, and after deselecting ink and moving only
text. It also checks unchanged image geometry, text content and ink stroke count.
A screenshot is retained in the result bundle. This does not compare ink bytes or
replace physical Pencil, palm-rejection, viewport or accessibility observations.

Verification: targeted `xcodebuild test` using the documented simulator command with
`-only-testing:SophiaScripturaUITests/CanvasExperimentUITests/testGroupingUngroupingPreservesIndependentObjects`
and `-resultBundlePath build/sp006-verification/grouping-20260917.xcresult`.
Result: **1 passed, 0 failed, 0 skipped**, iPad A16 Simulator / iOS 26.5. Prior
15-test suite remains separately recorded; the expanded full suite was not rerun.
Only UI test source and documentation changed for this task.

## Automated text editing — 2026-09-17

Added `CanvasExperimentUITests.testTextEditingSavesCancelsAndPreservesGroupedInk`.
The isolated fixture test lengthens grouped text with Done, discards a different
draft with Cancel, checks unchanged text/ink/image geometry and ink stroke count,
checks grouped movement and Undo, then verifies saved text and grouping after reopen.
Ink-byte equality and physical Pencil quality are not asserted by this UI test.

First run failed because the test deselected the whole group before Edit text.
Corrected that test setup without changing runtime code. Targeted rerun via the
documented simulator command with
`-only-testing:SophiaScripturaUITests/CanvasExperimentUITests/testTextEditingSavesCancelsAndPreservesGroupedInk`
and result `build/sp006-verification/text-editing-20260917-r2.xcresult`:
**1 passed, 0 failed, 0 skipped**, iPad A16 Simulator / iOS 26.5. Screenshot retained.
The full expanded suite was not rerun. Documentation whitespace checks passed.
Next: owner-guided physical Pencil responsiveness and palm-rejection observations;
these remain Not Run until reported. SP-006 remains in progress.

## Physical Pencil/palm result — 2026-09-17

Owner completed the guided Pencil responsiveness and palm-rejection check on the
installed hang-fix build and reported no lag, missing strokes, palm marks or unexpected
freezing. Record the guided check as **Pass (owner-reported)**. Pencil described as
Type-C and non-Pro; exact model unconfirmed. This is qualitative small-sample evidence,
not measured latency, verified hardware identification, or production-scale performance.
Next physical case: input modes (Pencil-only finger pan, finger drawing/two-finger pan,
Select object drag, and Pan navigation). SP-006 remains in progress.

## Acceptance evidence reconciliation — 2026-09-17

Owner reports Undo/Redo works, objects stay aligned, and work is preserved. Record
these observations without claiming every zoom/resize/canceled-drag or relaunch
substep was individually described. Recovery has existing passing evidence in
`select-hang-20260917.xcresult`: model/store checks reject corrupt/future fixtures
and preserve saved bytes; the UI test checks damaged-restore rejection. No manual
file corruption or duplicate recovery run is needed. This is not full production backup.
Accessibility and physical memory observations remain outstanding. Exact viewport
and cancellation coverage must be reconciled before final experiment closure.

## Physical memory observation completed — 2026-09-17

Instruments could not attach; LLDB attachment was slow and its reconnect crashed
in the debugger. The app launched successfully through CoreDevice. These were tooling
failures, not evidence that Sophia had a memory fault. A DEBUG-only `CanvasMemoryProbe`
provided the bounded measurement directly in the physical process. It requires both
`SP006_MEMORY_PROBE=1` and a valid `SP006_UI_TEST_FIXTURE` UUID; it opens the experiment
directly and uses isolated synthetic data, leaving the normal fixture separate.

Environment: physical iPad A16, iPadOS 27.0, Debug build from Xcode 26.6.
Metric: successful `task_info(TASK_VM_INFO)` physical footprint in bytes; values below
are MiB (1,048,576 bytes). All 65 samples returned KERN_SUCCESS. The probe observes
UIKit memory-warning notifications and save results, and writes only numeric metrics
and phase labels, not text, image or drawing content.

| Sample | Time (s) | Footprint (MiB) | Strokes |
| --- | --- | --- | --- |
| Baseline | 5.33 | 37.58 | 1 |
| Cycle 1 idle | 36.33 | 40.28 | 21 |
| Cycle 2 idle | 67.33 | 41.05 | 41 |
| Cycle 3 idle | 98.87 | 40.42 | 61 |
| Final idle | 114.51 | 40.02 | 61 |

Highest sampled footprint: 51.72 MiB. Baseline-to-final increase: 2.44 MiB.
Three cycles each add 20 synthetic 61-point strokes, move the selected text, Undo/Redo
that move, vary zoom across 50/100/200%, save, and idle. Final idle lasts 15 seconds
after the cycle-three idle. All saves succeeded; zero memory-warning notifications;
report completed normally. Rotation and actual Pencil events were not part of this
workload. Sampling can miss between-sample peaks; probe/report overhead is included.

Disposition: **bounded memory-observation criterion satisfied**. Idle footprint did
not increase monotonically across cycles. This is not a leak audit, a production memory
budget, or large-document performance validation. No memory optimization is justified
by this small run alone.

Evidence: `build/sp006-verification/memory-probe-completed.json` (ignored raw numeric
report). Report on device: `Library/Application Support/SP006/Diagnostics/` plus the
fixture UUID and `.json`. Device build/install and normal relaunch with probe disabled
succeeded. Existing unit/model tests and normal-launch/edit/reopen UI regression:
**14 passed, 0 failed, 0 skipped**, `memory-probe-regression.xcresult`. The two other
UI scenarios were not rerun for this probe change. No production schema changed.

## SP-009 / M2 reader — 2026-09-22

See [reader acceptance evidence](sp009-reader-evidence.md) for content provenance, importer,
unit/UI results and remaining physical cases. Simulator commands use the installed iPad A16:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project application/SophiaScriptura/SophiaScriptura.xcodeproj \
  -scheme SophiaScriptura \
  -destination 'platform=iOS Simulator,id=523DDB8A-9EF6-44ED-A4F8-F8059ECB7725' \
  -derivedDataPath build/sp009/DerivedData \
  -resultBundlePath build/sp009/reader-verification.xcresult \
  -only-testing:SophiaScripturaTests/ScriptureReaderTests \
  -only-testing:SophiaScripturaUITests/ScriptureReaderUITests \
  CODE_SIGNING_ALLOWED=NO
```

Use a fresh result-bundle path per run. Reader UI tests set a valid UUID in
`SP009_TEST_STORE`; only DEBUG builds recognize it, keeping normal progress separate.

### SP-009 continuous-reader feedback regression — 2026-09-22

Owner requested continuous chapters, chapter swipes and removal of the top location title
after reporting bottom-scroll bouncing. Ten reader unit tests and two reader UI tests
passed in `build/sp009/continuous-reader-r2.xcresult`. Use the SP-009 command above with a
fresh result path. The new UI case checks fixed viewport geometry while scrolling to the
end repeatedly and native chapter swipes. It does not claim the owner's physical symptom
resolved until they retest. The prior paginated-selection test is superseded by continuous
selection/Copy/verse-reveal coverage under the explicit owner design revision.

### SP-009 compact passage navigation regression — 2026-09-22

Twelve reader unit tests and three UI tests passed in `build/sp009/passage-picker.xcresult`.
The same scoped command above now covers sequential book/chapter/verse navigation,
Back/cancel without navigation, Read chapter, Genesis 1:31 availability, full-verse transient
focus including Unicode/multipart mappings, and automatic clearing after rapid jumps.
Portrait/landscape screenshots were inspected. Physical and accessibility gaps remain in
[reader evidence](sp009-reader-evidence.md); M2 remains in progress.

## SP-010 licensed offline translations — 2026-09-23

Focused simulator evidence: 7 passed, 0 failed in
`build/sp010/licensed-r6.xcresult`; the combined reader-plus-SP-010 unit regression passed
19/19 in `build/sp010/m2-unit-r1.xcresult`, both on iPad Pro 13-inch (M5), iOS Simulator
26.5. The suite uses a synthetic provider and in-memory test secure store; no API
credential or licensed Scripture body is used in tests. It verifies AES-GCM ciphertext
does not contain a known payload and fails under a wrong key; typed parser handling for
Unicode, source notes and bridged verses; interrupted staging/resume; relaunch; 30-day
lease boundary and rollback; revoked-token locking; unbounded personal copy authorization;
reader edition restore; and the existing reader regression cases.

Physical download evidence, 2026-09-28: the signed app launched on the paired iPad and
completed 1,189 of 1,189 chapters for NIV11, NLT and NKJV. The per-edition device-local
diagnostics contained only edition ID, chapter counts and `complete` state. Sophia was
then relaunched normally without the transient DEBUG credential environment. Physical
acceptance still requires confirming that each edition opens after airplane-mode relaunch,
then confirming expired-lock and renewal flows. Do not put an API key in XCTest launch
arguments or source.
The separate `ScriptureReaderUITests` attempt did not create a valid result bundle after
the simulator's debugger-launch warning, so it is inconclusive and is not recorded as a
UI pass for SP-010.

### SP-010 manual-sync regression — 2026-09-29

`build/sp010/manual-sync-r2.xcresult` reports 8 passed, 0 failed and 0 skipped on iPad
Pro 13-inch (M5), iOS Simulator 26.5. The added regression supplies a translation expiring
within one day, calls reader resume, and verifies that the translation library receives
zero sync calls. The edition-switch test also verifies that the provider's NIV11 edition
is presented as NIV. The first invocation built successfully but exited before producing
a valid result bundle; only the completed second run is counted. The owner separately
reported that the three downloaded editions work in airplane mode. Expiry/renewal testing
is deferred by owner decision; VoiceOver remains unverified.

The combined `ScriptureReaderTests` and `LicensedTranslationTests` regression passed
20/20 in `build/sp010/manual-sync-reader-r1.xcresult`. The signed device build and
installation succeeded, but physical launch is blocked until the Personal Team profile
is trusted again in iPadOS Settings; no physical runtime pass is claimed for this build.

### OldPaper refinement regression — 2026-09-29

16 reader/appearance unit tests and 4 reader UI tests passed. The added
`ScriptureAppearanceTests` verifies schema-1 preference compatibility, preset round trips,
bundled font resolution and primary/accent text contrast. The new UI journey verifies
preset selection across relaunch. See [reader evidence](sp009-reader-evidence.md#oldpaper-reader-and-seven-presets--2026-09-29)
for result paths, simulator/tool limitations and physical deployment evidence.

### SP-010 development-period exception — 2026-09-29

The Xcode Debug test target passed the licensed-translation lease and storage regression,
including the development policy case: an authorized cached copy remains readable after
the normal 30-day boundary while clock rollback still fails closed. Release and Archive
validation must continue to use the standard lease policy. Physical acceptance still
requires an owner-operated offline relaunch with the authorized editions; the written
provider authorization does not replace device, attribution or security checks.

### SP-010 denied-sync cache recovery — 2026-09-29

Nine licensed-translation tests passed in `build/sp010/access-recovery-r1.xcresult`.
The regression publishes encrypted synthetic content, records a denied sync under the
standard policy, then reopens the same store under the development exception and reads
a chapter. The standard-policy denied-access regression still passes. The signed Debug
update launched on the owner's iPad; availability-only diagnostics confirmed NIV11, NLT
and NKJV remain cached and available without redownloading.

## M2 owner closure — 2026-09-29

M2 is closed under revised acceptance: the owner accepts the visual work and reports
expiry/renewal addressed. VoiceOver is waived, not passed. Historical unrun checks above
remain evidence limitations. SP-010 records the Debug cache exception and recovery checks;
this closure does not imply a new physical Release expiry test. SP-008 now owns the first
M3 experiment and physical Pencil gate.

## SP-008 closure and SP-011 shell verification — 2026-09-29

The owner explicitly reported all SP-008 criteria successful. The bounded physical gate
is accepted; the [walkthrough](sp008-ipad-guide.md) records owner evidence separately
from automated tests. Production ink persistence/recovery remains separate.

SP-011 adds `ShellChromeStateTests` for deadline extension and timer cancellation and
`ShellNavigationUITests` for three-second hiding, manual reveal, stable
reader frames, retained Collections navigation and dark/landscape dock appearance.
Affected reader regressions cover chapter swipes, Settings navigation and relaunch
restoration. Result status is maintained in [SP-011](../../tickets/SP-011-tab-shell-motion.md).
The existing reader UI tests now explicitly reveal the dock before tab navigation.

SP-011 final verification: seven distinct focused checks passed across
`build/sp011/shell-r1.xcresult`, `hide-reveal-r2.xcresult` and `landscape-r3.xcresult`.
The first hide assertion was corrected to check touch reachability, and the affected
journey passed on rerun. Exported light/dark/landscape screenshots were reviewed.
Physical build/install/launch succeeded; subjective motion and a device Reduce Motion
walkthrough remain owner review. No full-suite or physical accessibility pass is claimed.

### SP-011 footer reachability regression

The Settings final-row test reproduced footer overlap before the fix in
`build/sp011/footer/baseline-r1.xcresult`. It now checks that the entire experiment row
is above the footer in portrait/landscape and that tapping opens the experiment. The
Collections/Notes landscape case checks their final content above the dock. Retest
reader scrolling/chapter swipes and menu hide/reveal after shared shell layout changes.
Assertions use whole-element bounds, not only tap reachability. See SP-011 for final
result bundles and physical installation evidence.

Footer final results: `build/sp011/footer/fix-r2.xcresult` passed 3/3 simulator cases,
`other-tabs-r5.xcresult` passed the Collections/Notes check, and `ipad-r6.xcresult` passed
the actual iPad Settings test in both orientations, including opening the experiment.
Simulator and physical Settings screenshots were visually reviewed. Early cross-tab/device
queries assumed UIKit container types; corrected queries retain the same final-row bounds
assertions. Normal physical launch passed after the isolated test run.

## SP-012 annotations — 2026-09-29

Owner acceptance update, 2026-10-03: the owner reports successful actual-reader Pencil
writing, text-size alignment, palm rejection, background/relaunch, long-chapter
responsiveness, and annotation export/restore/recovery on the iPad. This closes M3 under
owner-reported physical acceptance. The automated results below remain separate evidence;
no per-case timing, stroke-count or screenshot record was supplied for the owner pass.

Owner-selected actual-reader implementation. Run `SophiaScripturaTests/AnnotationTests`
and `SophiaScripturaUITests/AnnotationUITests` with the existing simulator command, plus
reader navigation and continuous-scroll regressions. Temporary repositories and UUID
SP009_TEST_STORE environments protect the owner stores. Generation corruption, interrupted
commits, stale revisions, dirty-save retry, deletion/undo, archive rejection/restore and
fixed-layout viewport checks are implemented.

`build/sp012/checks-r4.xcresult` passed 12 unit/component + 3 simulator UI tests;
`checks-r2.xcresult` also passed reader navigation/settings/relaunch. Both annotation UI
journeys passed on the actual iPad (`ipad-r1.xcresult`). Dark default-ink contrast has a
separate focused run (`contrast-r6.xcresult`). Reviewed retained landscape screenshots.
Dense fixture: Psalm 119 / 176 verses / 820 × 16,825 pt / 2,000 strokes / 311,887 bytes.
No physical Pencil or long-chapter memory acceptance is inferred. Next gate is the
[SP-012 walkthrough](sp012-ipad-guide.md); ticket contains current status and delivery logs.

Final restore safety check: `build/sp012/restore-r7.xcresult` passed backup canvas
invalidation and dark default-ink contrast. Restore increments a surface generation before
publishing the restored snapshot; dismantling an old canvas cannot flush stale ink over
it. Unique passing checks: 14 annotation unit/component tests, 4 simulator UI journeys
(including the two existing reader regressions), and 2 physical-iPad UI journeys.
Actual Pencil and Files acceptance remain pending. No unperformed case is counted passed.

SP-012 owner-revision verification: `build/sp012/revision/final-sim.xcresult` passed
16 annotation unit/component tests, three annotation UI journeys and two reader UI
regressions. The revised journeys cover centered controls, surrounding blank space,
Hidden returning to the ordinary reader, palette dismissal at stroke start and autosave.
Simulator checks do not establish Pencil feel, palm rejection or device persistence.
The signed revision was installed and launched on the owner's iPad after a fresh reinstall;
physical annotation acceptance remains pending in the [walkthrough](sp012-ipad-guide.md).

Layer-owned appearance revision: `build/sp012/revision/layer-final.xcresult` passed
17 annotation unit/component tests, three annotation UI journeys and four reader UI
regressions. Unit checks cover per-layer geometry/appearance persistence, selection
restoration, unchanged ink bytes and isolation of another layer's layout. UI checks cover
the selected row's preset/size metadata, appearance restoration, hidden Margin and layer
recovery. The compact palette's separate collapse-to-edge state is checked in
`palette-final.xcresult`; physical Pencil and visual acceptance are still pending.
The signed revision installed in place and launched normally after the owner trusted
the Personal Team profile; `build/sp012/revision/layer-device-launch-retry.log` records
the successful CoreDevice retry. This does not pass physical annotation behavior.

## SP-013 production Notes — 2026-09-29

`build/sp013/seventh.xcresult` passed 15 selected tests (9 Notes model/recovery,
4 Notes UI journeys, 2 shell regressions) on iPad A16 / iOS 26.5. Production fixtures
use UUID-scoped Notes stores through `SP009_TEST_STORE`. The DEBUG-only
`SP013_FINGER_INK=1` switch permits synthetic simulator drawing; real use stays Pencil-only.
This flag does not prove physical Pencil acceptance. Run:

`build/sp013/final.xcresult` subsequently passed 9 Notes model/recovery tests and
5 Notes UI journeys, including ink reopening after tab change and relaunch. The later
`build/sp013/quote-policy.xcresult` passed 10 Notes model/recovery tests and the WEB
verse-hub journey after restricting saved source quotes to WEB. The earlier selected
shell checks remain 2/2 in `seventh.xcresult`. These runs do not establish physical
Pencil, VoiceOver, Files picker restore or representative-capacity acceptance.
The focused `landscape-visual.xcresult` passed object/group/rotation interaction, but
simulator captures disagree about orientation framing, so landscape visual acceptance
remains in the physical guide.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project application/SophiaScriptura/SophiaScriptura.xcodeproj \
  -scheme SophiaScriptura \
  -destination 'platform=iOS Simulator,id=523DDB8A-9EF6-44ED-A4F8-F8059ECB7725' \
  -derivedDataPath build/sp013/DerivedData \
  -resultBundlePath build/sp013/next-run.xcresult \
  -only-testing:SophiaScripturaTests/NotesTests \
  -only-testing:SophiaScripturaUITests/NotesUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Use a fresh result path. See [SP-013](../../tickets/SP-013-freeform-notes.md) for exact
checks/fixes and the [iPad guide](sp013-ipad-guide.md) for unrun Pencil, Files,
VoiceOver, narrow-window and representative-capacity acceptance. M3 acceptance is separate.

### Study-page redesign verification — 2026-09-30

The earlier WEB-only and object-ink behavior above is historical. The owner-approved
study page supports authorized translation quotations, a fixed central body, one fixed
ink overlay and floating objects. `build/sp013/redesign/final.xcresult` passed 16 Notes
model/recovery checks and five of six UI journeys. After correcting touch-down targeting
for corner drags, `build/sp013/redesign/resize-fix.xcresult` passed the remaining direct
move/resize journey. All 22 selected checks therefore passed across those runs.
The successful portrait object-editing screenshot was visually inspected.
The signed iOS build was installed and launched on the paired iPad. On 2026-10-01 the
owner reported Pencil-to-text input, trouble exiting typing, an incomplete tool palette,
and Pencil input failing with Scribble disabled. These are owner-reported failures pending
reproduction and correction on hardware. The Canvas/Page source implementation now adds
typed v3 storage, inline Page attachments, Canvas ink transforms and a Scripture toggle;
its current verification is recorded in SP-013 and the updated physical guide. These checks do not establish the cause
or resolution of the original unsupported-data/crash report. The signed build was
subsequently installed and launched on the physical iPad.


### SP-013 Canvas/Page verification — 2026-10-01

19 Notes model/recovery tests and nine distinct UI journeys passed across
`build/sp013/two-types/acceptance.xcresult` and `final-ui.xcresult` (28 unique selected
checks). The first suite had one new Canvas test target error; the corrected workspace
input and all five affected UI retests passed. Coverage includes legacy type inference
and exact-generation retention, independent/duplicate drawing identity, Canvas transforms
and reopen, Page attachment/citation offsets, typing/ink persistence, pane visibility,
hidden-pane citation navigation and the existing quote/experiment journeys.

Xcode 27.0 signed build and normal-access signature validation passed. Installation over
the existing app and launch on the paired iPad succeeded. Final Canvas screenshot inspected;
document links and whitespace checked. Physical Pencil with Scribble on/off, palm rejection,
Files recovery, dense-note performance and the original crash remain unverified. Follow
[the current iPad guide](sp013-ipad-guide.md); M4 remains in progress pending owner acceptance.

### SP-013 workspace refinement checks

`NotesTests` covers neutral-ink appearance without geometry/raw-payload changes, styled
object insertion/duplicate/undo/archive and validated cached thumbnails in addition to
existing migration, citation and recovery cases. `NotesUITests` now uses contextual actions
instead of the removed Objects list, and covers direct title rename, dotted paper, shape
and sticker galleries, full-height viewport, finger transforms, rotation and ink reopening.

`testCanvasWebsitePreviewLoadsAndReopens` and `testCanvasYouTubePreviewLoadsAndReopens`
are live metadata integration checks requiring internet access. They verify a real cached
thumbnail, insertion Undo/Redo and reopening. For an intentionally offline regression run,
exclude those two with `-skip-testing:SophiaScripturaUITests/NotesUITests/<testName>`;
the cached-thumbnail model/repository test remains network-independent. Site metadata
availability is outside the app's control; a failed fetch must retain a usable domain card.
See SP-013 for recorded result bundles and the iPad guide for physical acceptance.


### Theme and full-height workspace regression

`NotesTests.testInkPixelsRemainReadableAcrossDarkLightDark` checks actual PencilKit
raster pixels through both appearance transitions and preserves original drawing bytes.
`ThemeWorkspaceUITests` checks Canvas/Page ink pixels across Dark → Light → Dark,
Notes viewport alignment with the bottom screen edge, and Spring Leaf status/body edge
colors across all six tabs. Its DEBUG-only neutral-pen setting avoids inheriting a
simulator's previously selected colored pen. Existing shell tests cover dock deadlines,
stable reader geometry, retained navigation and final-row reachability in both orientations.
Evidence and remaining physical acceptance are recorded in SP-013.


`NotesUITests.testCanvasRepeatedInkUsesViewportAndActivePenIndicator` asserts live ink
view bounds equal the editor viewport, checks the pen's accessible active/hidden state,
draws twenty strokes and checks their persistence after relaunch. An earlier diagnostic
run recorded application memory during repeated drawing; the retained evidence is in
SP-013. Physical test stores are isolated by `SP009_TEST_STORE`; launch normally afterward
to restore owner data.

## SP-014 Pencil shapes and app icon

`PencilStrokeRefinementTests` verifies conservative last-stroke refinement for line,
single-stroke arrow, ellipse, rectangle, triangle, diamond, pentagon, hexagon and star;
it also rejects short and clearly curved input and checks retained Pencil appearance.
`build/sp014-shapes-r3.xcresult` records **6 passed, 0 failed, 0 skipped** on iPad (A16)
Simulator / iOS 26.5. That run compiled the default/dark/tinted AppIcon catalog.
`build/sp014-regression.xcresult` records **48 passed, 0 failed, 0 skipped** on the same
destination for `PencilStrokeRefinementTests`, `NotesTests`, and `AnnotationTests`.
`build/sp014-ui-r7.xcresult` records **9 passed, 0 failed, 0 skipped** on that destination:
the shape unit tests, including an endpoint pause distinct from a moving stroke, plus
`PencilShapeUITests` for the Notes ruler and the installed SophiaScriptura Home Screen icon.

An XCUITest drag that pauses at the end does draw in Notes, but PencilKit does not keep
the stationary samples a real Pencil pause leaves in the stroke. The simulator therefore
cannot prove endpoint snap, Undo/Redo of that snap, or palm rejection. Those checks, and
the dark and tinted Home Screen treatments, remain physical iPad acceptance.

## SP-015 Notes and Collections minimal-header refinement — 2026-10-02

`ShellNavigationUITests.testLibraryHeadersUsePresetTitleAndExpandableSearch` checks the
shared landscape hierarchy: the tab name leads; Search begins as a symbol and expands into
an inline field when tapped; the remaining symbol-only controls follow on the same baseline;
and no duplicate navigation title appears. The test also retains screenshots for visual
inspection. Font-family selection is source-driven by the active appearance preset and is
part of light/dark/preset visual review rather than an accessibility-tree assertion.

`build/sp015-library-header-r3.xcresult` records the focused test passing. The follow-up
`build/sp015-library-header-regression-r1.xcresult` records **5 passed, 0 failed, 0
skipped**, covering the new geometry plus note creation/relaunch, Notes backup access,
collection creation/deletion and navigation retention. Compact-width wrapping, larger
Dynamic Type, VoiceOver order and final light/dark appearance remain physical review items.

## SP-020 Activity verification

Run `SophiaScripturaTests/ActivityTests` on the installed iPad simulator for pause-aware
duration, persistence, midnight totals, Reviewing idempotence, manual overlap and recovery.
The 2026-10-03 focused result `build/sp020-activity-install-r2.xcresult` passed 6/6 on
iPad (A16), iPadOS 26.5. The signed app was installed and launched on the paired physical
iPad, but the Activity UI and device behavior have not been observed yet.
The physical Activity walkthrough is in [sp020-ipad-guide.md](sp020-ipad-guide.md).
Background/lock behavior, visual placement and Pencil coexistence require the owner's iPad.

## SP-024 v0.2.2 draft verification — 2026-10-07

`build/v022/cache-final.xcresult` passed 216 unit tests plus the Canvas palette/share UI test.
`build/v022/acceptance-simulator.xcresult` also passed Collection create/assign/open.
Coverage includes inactive material exclusion, conversation archive/trash/restore,
1,000-object boundary, 300-stroke batching/save/reopen and cached-scene equivalence,
viewport culling/selection pinning/remounting, image downsampling/decoding, and invalid input.
The retained palette screenshot confirms colored swatches and red editor Delete on simulator.

A 30-second physical v0.2.1 baseline was captured with Time Profiler, all processes,
device name `iPad ni Paj`. Evidence: `build/v022/ipad-usb-baseline.trace` and exported profile.
Sophia recorded 10.61 seconds sampled CPU weight, 6.604 seconds on its main thread.
This establishes baseline activity, not a measured improvement or a confirmed lag cause.
No draft installation/release was performed. The optimized build still requires physical
Pencil, erase/undo, selection, pan/zoom, persistence and responsiveness acceptance.
See [SP-024](../../tickets/SP-024-v022-study-material-and-canvas-fixes.md).

## SP-025 compound Canvas ink verification — 2026-10-07

Owner selected implementation. `build/sp025/verified-unit.xcresult` passed **226 unit tests**
on iPad (A16), iPadOS 26.5, with code signing disabled. `build/sp025/final-regression.xcresult`
passed the prior 225-unit snapshot plus two focused Canvas UI checks: select/copy/delete
one of two strokes, Paste/Undo, and existing palette color/share behavior. Final unit
review adds extreme legacy-date collision and grid-coordinate safety coverage; UI paths
were unchanged by those final geometry/history/position-lock refinements.

Focused `NoteStrokeEditingTests` verifies 1,002 strokes in one region, 10,001-stroke
safety spill with layer-order preservation, subset move/color/delete, stable IDs for legacy
duplicates and split fragments, masks/transforms, cross-region lasso, sparse candidate
reduction, undo/redo/copy/export/restore and rejected-ink recovery after session restart.
Existing Notes regressions verify v1/v2 compatibility, corruption recovery, geometry and
culling. Screenshot attachments are retained under `build/sp025/ui-attachments/`.

Initial checks exposed a fixture compile omission, color-space equality mismatch and
DEBUG accessibility-count targeting; those were fixed before the successful runs. Xcode
reported a simulator diagnostic-collection warning about `simctl` discovery after one
successful run; the `.xcresult` and test summaries confirm test success. No hosted CI
or signed build/install was performed. No measured device speed improvement is claimed.

Physical gates: [SP-025](../../tickets/SP-025-v030-compound-ink-and-stroke-editing.md) and
[Canvas walkthrough](sp013-ipad-guide.md#sp-025-physical-canvas-acceptance--v030). Actual
Pencil/mask erasure behavior, palm rejection, varied-zoom/theme visual acceptance and
performance remain **Not Run** on the owner device.

## SP-026–028 protection verification

`ItemProtectionTests` covers salted password verification, category/combined grants and cancellation, idle deadlines, restart/background expiry, late password and biometric callbacks, persisted attempt backoff, credential-write failure, foreign credentials, metadata/body/membership command guards, accepted-buffer flush before concealment, legacy decoding, protected schemas, restoration preserving bindings, protection removal and password changes. It also covers Settings control availability, category-scoped cancellation when a note is archived or deleted, clearing every collection without revoking the Notes session, and hiding a note from the Notes library while any of its collections is locked, including a note filed only in a nested subfolder at any depth. `ItemProtectionUITests` covers real app password setup, card/menu concealment, independent Collection opening, combined Settings unlock, relaunch locking and password change. Existing Notes editing and Collection-created-note UI flows are regression gates.

2026-10-08 simulator evidence on iPad (A16) `523DDB8A-9EF6-44ED-A4F8-F8059ECB7725`:

- `ItemProtectionTests`: **27 passed, 0 failed**. Result: `build/sp026-028/unit.xcresult`. This run used `CODE_SIGNING_ALLOWED=NO` because the suite injects an in-memory credential vault.
- `ItemProtectionUITests`: **1 passed, 0 failed** in 146.7 seconds. Result: `build/sp026-028/ui-signed.xcresult`. Automatic signing was required. An earlier unsigned run, `build/sp026-028/ui.xcresult`, failed before the password sheet appeared and showed “The original lock credential is unavailable,” because the simulator Keychain rejected the unsigned app.

Owner iPad gates (Not Run by simulator): actual Touch ID success/cancel/failure/lockout and fallback; ten-minute per-category idle while the other category/music is active; force lock while Page/Canvas/Prayer/Journal has unsaved native edits; lock removal and password change on device; opening the app does not show a Sophia Protected screen; quit/relaunch on device; VoiceOver, keyboard, Dynamic Type, appearance and Pencil continuity. Verify backups on the original device and missing/foreign credentials remain locked. See [the protection contract](../security/item-protection.md).

### v0.3.0 protection review regressions

- A note shared with a locked folder stays hidden in Notes but opens through an unlocked collection route. Its own Notes lock still requires authentication. Relocking or removing the originating route conceals the editor and blocks further edits; accepted buffers are flushed first.
- Collection-origin authorization is rechecked after awaiting Notes authentication, including a folder deleted during the prompt.
- Filing may change unlocked memberships while retaining unchanged locked memberships. Removing/adding a locked edge fails atomically and returns a failure; the picker stays open with an explanation. A no-op succeeds without changing memberships.
- Trash permits title search, restore and deletion for collection-hidden notes, while hiding private tags and body search matches. Active notes do not contribute Trash tag suggestions.
- The protection UI flow waits for the Settings scroll surface and scrolls to combined controls/password actions before asserting visibility. Settings layout order is not a test readiness condition.

Review-fix verification on 2026-10-08: 51 focused protection/collection tests passed, then the final source snapshot passed 263 unit tests and all three selected simulator UI flows (collection note creation, lock controls/relaunch/password change, and shared-note opening/filing with a locked membership retained). Evidence: `build/sp026-028/review-fixes-focused.xcresult` and `build/sp026-028/review-fixes-acceptance.xcresult`. Real-device biometric, Pencil/idle and accessibility acceptance remains pending.

### Activity workflow choices — 2026-10-08

- Legacy Activity envelopes lacking workflow flags preserve automatic Reading/Contemplation defaults. Flags persist through relaunch and backups; switching them does not launch or alter a running workflow.
- With Reading off, start and finish a timer without choosing Scripture or an ending verse. With Reading on, choose the initial passage, navigate to Scripture and finish with the ending verse.
- Start from the separate Scripture Contemplation section. Off starts only a timer; on retains the specific/seven-passage guided journey, exit and recorder behavior.
- Quiz Me imports idempotently into Studying. Restore an actual legacy Reviewing envelope with records, an active draft, reminders and mode goals; retain durations, IDs, links and the total goal while combining Studying/Reviewing goals. Reviewing must not appear as a built-in choice.

Verification completed 2026-10-09 on iPad (A16): 60 focused Activity/Companion tests passed in `build/activity-workflows/focused.xcresult`; all 265 unit tests passed in `build/activity-workflows/acceptance.xcresult`. That combined run failed its initial UI locator. After correcting the locator, the UI flow exposed automatic List button/link activation in the new Contemplation card; explicit bordered Start and borderless History styles fixed it. The journey exit locator uses its accessible label because SwiftUI inherits the overlay identifier on that button.

The final `ActivityWorkflowUITests` flow passed 1/1 in 110.170 seconds in `build/activity-workflows/ui-complete.xcresult`: independent preferences persist through relaunch, plain Reading and Contemplation stay in Activity, Start does not also open history, filtered history excludes Reading, guided Reading opens Scripture, guided Contemplation opens its journey, and exit keeps the timer active until Finish/Save. The final card fix was verified by this UI rerun; the prior full unit result predates only those button-style changes. `git diff --check` and relative file-link checks passed. Xcode reported its existing orientation and simulator diagnostic-collection warnings after successful testing.

Physical iPad, specific-passage journey navigation, audio, VoiceOver, keyboard, Dynamic Type and appearance checks remain pending for the owner follow-up. No release or physical installation was performed.

Subsequent owner polish, 2026-10-09: remove the Contemplation section's Today duration line and use **Contemplating** as the activity type while retaining **Scripture Contemplation** for the section. The existing 19 Activity tests passed with updated label/migration expectations in `build/activity-workflows/contemplating-label.xcresult`; `git diff --check` passed. The existing workflow UI assertions were updated for the recorder label; that UI suite was not rerun for this text/layout change.

## v0.3.0 release snapshot — 2026-10-09

Owner authorized commit, push, merge and release. App version 0.3.0/build 20 passed all **265 unit tests** and **four selected UI flows**, zero failures, in `build/v030/release-acceptance.xcresult` (log: `build/v030/release-acceptance.log`). The Activity UI test was rerun here with the final Contemplating label and section layout. Other flows cover independent and combined protection controls, relaunch/password change, shared-note opening/filing retaining a locked membership, and selecting/copying/deleting/pasting one ink stroke with undo. UI duration was 395.559 seconds; unit duration was 23.306 seconds.

The release snapshot was staged and audited before verification. Subsequent changes only align release documentation and evidence. No generated build artifacts, credentials or private study data are staged. `git diff --cached --check` and relative documentation file-link validation pass. Existing orientation and simulator diagnostic-collection warnings did not change the successful test result. Physical Pencil/performance, actual biometrics/idle, full workflows and accessibility remain pending; the authorized personal source release does not mark those gates passed. Local recovery refs/bundle and staged patch are retained under `build/v030/` and the pre-release recovery branch.

## v0.4.0 release snapshot — 2026-10-10

Version 0.4.0/build 21: **341 unit tests passed, zero failures** in
`build/v040/release-final.xcresult`. The combined run had two UI containment failures;
diagnostics established XCTest's first Window had an empty frame while application bounds
were valid. Corrected tests retain full containment using the application frame.
`build/v040/ui-final.xcresult` passes character relaunch and enhancement; the chat setup
had an intermittent toggle-tap failure and is rerun separately after an explicit state wait.
The release notes record the final chat result and physical/provider acceptance boundaries.
Signed release-version installation and normal launch passed in `build/v040/install-release.log`.

Final chat rerun `build/v040/chat-final.xcresult`: **1 passed, zero failures**. Together
with relaunch and enhancement in `ui-final.xcresult`, all three selected Sophy UI flows
have passing final evidence. This does not imply the prior combined run passed or that
all app UI tests were run. Only test synchronization and docs changed after 341-unit
app-code verification and final signed iPad installation.

## SP-048 Quiz Me lifecycle — 2026-10-18

`build/sp048/all-unit-r3.xcresult`: all **414 unit tests passed**, zero failures.
Provider-routing test teardown now drains its background refill before replacing
the shared HTTP stub, fixing the cross-test interference found in the first full run.

`build/sp048/final.xcresult`: 58 focused Companion/QuizBankLifecycle/QuizMeTimer tests
passed. Tests gate provider replies to verify ready standard/Again/exam starts and
refill while active, scope/capacity, serialized save before next batch, repeated load
and restart preservation, exact cold-exam deficit and round/Activity compatibility.
Hosted-view portrait/landscape summary screenshots were reviewed for matching actions.
No live-provider latency, factual-quality or background-execution claim follows.
See [SP-048](../../tickets/SP-048-quiz-bank-lifecycle-and-summary-actions.md) for
full-unit/device evidence and remaining acceptance.

## v1.3.2 release verification — 2026-10-18

Final version 1.3.2/build 27 passed simulator build and **414 unit tests, zero failures,
zero skipped** on iPad (A16) / iOS 27.0 using Xcode 27.0. Command used the SophiaScriptura
scheme, `-only-testing:SophiaScripturaTests`, `-parallel-testing-enabled NO` and
`CODE_SIGNING_ALLOWED=NO`. Result: `build/v132-release/verification.xcresult`;
log: `build/v132-release/verification.log`; structured summary: `build/v132-release/summary.json`.
The QuizBankLifecycleTests hosted-view summary attachments were exported to
`build/v132-release/attachments/` and reviewed in portrait/landscape for matching actions.
All local links in release-scope Markdown and `git diff --check` passed. No full XCUITest
suite, live-provider checks or version 1.3.2 physical installation was performed;
prior SP-048 installation remains version 1.3.1/build 26 evidence.
