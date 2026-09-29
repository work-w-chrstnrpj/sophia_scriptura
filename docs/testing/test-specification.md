# Test specification — Sophia Scriptura

## Current implemented coverage

SP-006 has hosted XCTest model/store/session tests and XCUITest interaction tests under
`application/SophiaScriptura/SophiaScripturaTests/` and `SophiaScripturaUITests/`.
The shared SophiaScriptura scheme includes both. Unit coverage includes independent and
grouped geometry, clamping, zoom conversion, undo/redo, validation, real drawing/image
round trips, corrupt-file preservation, delayed ink updates, and autosave ordering.
UI checks cover movement, Undo, grouping, text edit, save/reopen, relaunch, rotation and
finger-generated PencilKit input. Tests use a DEBUG-only UUID-scoped fixture directory
so their disposable data does not overwrite the owner's normal experiment sample.

## Commands

The accepted reader contract specifies `READER-DATA-01` through `READER-DATA-12` in
[Scripture reader data contract](../data/scripture-reader-contract.md). SP-009 must add
and execute them with importer/repository/state implementations. All are currently Not Run.

SP-003 cases LAYOUT-01–03 move into SP-009 so the actual product reader proves passage
selection, hit testing and source mapping. Annotation cases LAYOUT-04–09 remain in
[SP-008](../../tickets/SP-008-scripture-layout-validation.md) as a later pre-M3 gate.
All are Not Run; Notes tests do not prove Scripture pagination or alignment.

SP-002 content/import cases CONTENT-01–10 are specified in
[Scripture content feasibility](../integrations/scripture-content.md). They are planned,
not executed. Research validates a source/license candidate, not an imported Bible.

Latest Collections evidence (2026-09-21): `build/sp007-20260921-r2.xcresult` reports
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
