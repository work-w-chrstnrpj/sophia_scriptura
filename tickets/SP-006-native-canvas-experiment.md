# SP-006 — Native expandable-canvas experiment

- Type: prototype/spike. Status: done (bounded experiment; owner-approved revised acceptance). Owner: Frontend UI/UX Developer.
- Requirements: REQ-008, REQ-016, REQ-017.
- Inputs: expandable canvas and explicit grouping accepted through SP-004. Environment
  verification is the first execution step. Remaining gesture/storage choices are
  questions this experiment investigates, not assumed production decisions. Coordinate
  fixture format is experimental and must not be used as the production data schema.
- Design: [Interaction proposal 02](../docs/design/canvas-interactions.md),
  [TDD §7](../docs/tdd/tdd.md#7-data-model).

## Closure and revised acceptance

Owner approved closing the experiment with documented limitations after reviewing the
value and cost of further testing. This revises the original full walkthrough gate;
it does not turn unperformed checks into passes. Historical entries below are retained
as evidence and are superseded by this closure for current status.

Accepted evidence: native shared-coordinate canvas with independent objects and explicit
grouping; automated edit/cancel, persistence and damaged-restore checks; owner Pencil/palm,
input-mode, Undo/Redo, alignment and work-preservation observations; fixed Draw → Select
hang with owner retest; bounded physical memory run (37.58 MiB baseline, 51.72 MiB sampled
peak, 40.02 MiB final idle, zero memory warnings). Test runs and their limits are below.

Deferred, not passed: full VoiceOver/large-text walkthrough; exact window-resize and
canceled-drag cases; exhaustive direct-drag/zoom combinations; production-scale memory,
rich-object editing and integrated backup. SP-004 owns editor interaction/accessibility
follow-up and SP-005 owns persistence/recovery contracts and scaled verification.
Before a production editor implementation ticket is ready, it must inherit the relevant
checks and explicit acceptance criteria. Native Pencil palette remains planned, unbuilt.

Conclusion: shared document coordinates, independent object identity and explicit grouping
are a viable starting point. Keep session, rendering and storage responsibilities separate.
Do not adopt the three-object JSON envelope, fixed whole-ink rectangle or snapshot history
as the production schema/editor design by default. The experiment is complete; M1 and the
Notes feature are not complete. No further coding is authorized by closure.

## Purpose

Prove that the selected expandable-canvas approach can preserve typed text, Pencil ink,
and an image through movement, grouping, viewport changes, and a small fixture round
trip on the owner's iPad A16. Surface integration problems before choosing production
storage and editor architecture.

## Scope and ownership

Own an isolated experiment under the app's feature/experiment structure, with the exact
file list established by reading the current Xcode project when execution is requested.
Do not replace the six-tab scaffold or implement unrelated Scripture/provider features.
Use disposable synthetic notes and local fixtures; never migrate personal study data.

## Work after the ticket is ready and execution is requested

1. Verify the current scheme, signing path, and actual device compatibility; record build
   results. Confirm the Pencil model if a tested capability depends on it.
2. Implement one text object, one PencilKit drawing representation, and one image,
   using stable document coordinates and a distinct viewport transform.
3. Implement select/move, explicit group/ungroup, text editing, and basic navigation.
   Investigate UIKit/PencilKit gesture ownership, stroke selection, and undo integration.
4. Round-trip a versioned disposable fixture containing geometry, group membership,
   text, drawing bytes, and image references. Keep this separate from final SwiftData models.
5. Demonstrate on iPad, record observed limits, and recommend an architecture with evidence.

## Acceptance and verification

- Moving text alone leaves independent ink unchanged; grouped movement applies the same
  delta to all members; ungrouping preserves positions and content.
- Pan, zoom, rotation, and window resize preserve document coordinates. Movement at two
  zoom levels has the correct document-space delta; a canceled drag restores its start.
- Text edits preserve ink and group membership without falsely reflowing existing strokes.
- A completed move/group operation is reversible. Report any unresolved integration
  between native text undo, PencilKit undo, and canvas history rather than hiding it.
- Relaunch restores fixture text, ink, image, object positions, and groups. A corrupted
  fixture is rejected without overwriting a valid fixture. This does not prove full backup.
- Labeled selection/navigation controls provide alternatives to precision gestures.
- Record Pencil responsiveness and memory observations on the iPad with the fixture;
  a small sample is not proof that large production notes are performant.
- No network access, content-provider credentials, paid services, or user-data migration.

## Outputs and boundaries

Prototype source, meaningful coordinate/round-trip checks, manual iPad evidence, and an
architecture recommendation. Update SP-004, TDD, data-contract planning, and testing notes.
Full rich text, tables, shapes, nested groups, PDF export, production backup, search,
and a polished general-purpose editor remain outside this bounded experiment.

## Readiness and evidence

Execution authorized by the owner. Native source is under
`application/SophiaScriptura/SophiaScriptura/Features/Notes/CanvasExperiment/`;
XCTest targets are `SophiaScripturaTests` and `SophiaScripturaUITests`.

2026-09-15: simulator build succeeded with Xcode 26.6. Thirteen model/store/session tests
passed on iPad A16 Simulator (iOS 26.5). Initial UI checks exposed an Undo integration
failure and a drawing interaction failure; fixes and rerun evidence are tracked in the
[test specification](../docs/testing/test-specification.md).

The owner's physical iPad A16/iPadOS 26.6.2 is paired with Developer Mode enabled.
Personal Team build and installation succeeded. After the earlier trust failure, the
owner subsequently reported opening and testing the canvas: it broadly works, but the
expected Apple Notes-style Pencil palette is missing. Treat this as owner feedback, not
proof of every walkthrough case. Detailed Pencil, palm rejection, memory and viewport
observations remain outstanding. The tool picker is not implemented; a follow-up scope
must be presented for owner selection before coding. SP-006 stays in_progress.

Provisional recommendation: retain a shared document coordinate surface and separate
session/store ownership for the next experiment. Do not adopt the single ink rectangle,
snapshot history, or JSON envelope as the production editor architecture without scale
and device evidence. See the TDD checkpoint for bounded implementation limits.

2026-09-17: owner selected resuming SP-006 completion. Read the retained
`build/sp006-verification/final-20260915.xcresult` using `xcresulttool get test-results summary`:
15 tests passed, zero failed, zero skipped, on iPad A16 Simulator / iOS 26.5. This is
simulator evidence only. The eleven physical walkthrough checks remain unverified;
guided execution starts with independent object movement.

2026-09-17 physical update: owner confirmed the guided independent-text movement and
Undo check worked after restarting. Record that case as pass on retry. The owner also
reported a crash upon tapping Select; this is an unresolved failure, not cleared by
restart. Ten other physical cases remain unverified.

### Select crash — initial investigation

- Summary / symptoms: one owner-reported crash on Select, then successful retry.
- Facts / observations: no crash stack obtained; no matching Sophia report found in
  the Mac's local diagnostic/crash folders. Device enumeration failed to connect to
  CoreDevice service, so device connectivity has not been established.
- Suspected boundary: canvas mode transition in `CanvasExperimentSurface.swift`,
  where `applySession()` toggles PencilKit interaction and gesture recognizers.
- Primary investigator: Frontend UI/UX role; supporting role: SQA for reproduction.
- Hypotheses: gesture/PencilKit transition failure is plausible from the reported
  trigger, but unconfirmed. OS termination or another app failure coinciding with
  the tap also remains possible. No exception, termination reason or stack supports
  either hypothesis yet; successful retry does not discriminate between them.
- Evidence: owner report and exact mode-transition source inspection; existing
  simulator passes do not reproduce or resolve this physical failure.
- Most likely root cause: not yet determined. Confidence: low.
- Recommended fixes: none yet; obtain device crash report and prior mode/Pencil
  activity before selecting a code change.
- Open questions: prior mode, recent stroke, approximate crash time, device connection.
- RCA needed: no formal RCA at this stage; retain the investigation in this ticket.

### Draw → Select hang — device evidence and bounded fix

Owner clarified the symptom: the interface freezes on Select after Draw; it does
not immediately close. The connected iPad was confirmed available. Retrieved
`build/sp006-verification/select-crash-20260917.ips` (ignored, raw device diagnostic).
Main-thread frames show `CanvasSurfaceController.applySession()` called from
`updateUIViewController`, then `setUserInteractionEnabled`, first-responder resignation,
SwiftUI responder graph evaluation and `AG::Graph::print_cycle`. Termination is a
FrontBoard watchdog process-exit timeout. This supersedes the initial lack of evidence.

Most likely cause: changing PencilKit interaction synchronously inside SwiftUI's
representable update re-enters its responder graph. Confidence: high for the failing
path, pending physical verification of the remedy. The narrow SP-006 change schedules
and coalesces representable-driven updates on the main queue after the current update
returns, using current session state and a weak controller reference. UI regression
coverage exercises repeated Draw → Select, movement, Undo and retained stroke count.
No schema, sample data, or unrelated feature changes. Automated run and physical retest
remain pending at this checkpoint; do not declare the hang resolved yet.

The corrected signed device build succeeded and was installed over the existing app
on 2026-09-17 without uninstalling. Owner was asked to repeat Pencil Draw → Select
three times, test movement/Undo, and check retained handwriting. Physical response
is pending. Simulator run: `build/sp006-verification/select-hang-20260917.xcresult`.

Owner answered “Yes” to the corrected-build three-cycle Pencil Draw → Select retest:
responsive controls, movement/Undo and intact handwriting. Focused physical regression
passes. The full input-modes case and other outstanding walkthrough rows remain unverified.

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

## Input-mode observations — 2026-09-17

Owner confirmed all three guided checks behaved as expected: one-finger panning
without ink with Finger drawing off; one-finger drawing and two-finger panning with
it on; and Pan navigation without edits. These substeps pass by owner report. The
Select direct-drag substep remains unverified. Six other walkthrough rows remain
pending (Undo/redo, Viewport, Relaunch, Recovery, Accessibility, Memory), with existing
automated evidence overlapping some of them. Reconcile that evidence before asking
for repeat manual work; no new requirement or blanket acceptance is implied.

## Acceptance evidence reconciliation — 2026-09-17

Owner reports Undo/Redo works, objects stay aligned, and work is preserved. Record
these observations without claiming every zoom/resize/canceled-drag or relaunch
substep was individually described. Recovery has existing passing evidence in
`select-hang-20260917.xcresult`: model/store checks reject corrupt/future fixtures
and preserve saved bytes; the UI test checks damaged-restore rejection. No manual
file corruption or duplicate recovery run is needed. This is not full production backup.
Accessibility and physical memory observations remain outstanding. Exact viewport
and cancellation coverage must be reconciled before final experiment closure.

## Physical memory profiling attempt

Owner requested agent-operated measurement. CoreDevice confirms the paired physical
iPad is wired, developer services available and Sophia running (PID 1877 at inspection).
Current device OS is 27.0, changed from the earlier 26.6.2 test environment; Xcode is
26.6 (17F113). Instruments initially listed the iPad offline, then online after
developer-service reconnection. An Activity Monitor attach by exact device UDID
timed out with “Timed out waiting for device to boot” before any baseline was verified.
Lock-state inspection reports passcodeRequired false and unlockedSinceBoot true.
The attempted output was `build/sp006-verification/memory-baseline-r2.trace`; it is
not valid measurement evidence. Cause of profiler connection failure is unconfirmed;
version compatibility is a possibility, not an established diagnosis.

Memory observation status: Blocked by profiling connection, not an app failure.
Next step: launch the physical device from Xcode with Command-R and inspect any
debugger/device-support error or the Memory gauge if it succeeds. No app source changed.

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
