# SP-012 — Persistent Scripture annotation layers

- Type: implementation. Status: in_progress; owner selected implementation 2026-09-29.
- Milestone: M3. Owner: Frontend UI/UX Developer; Infrastructure owns repository commits.
- Requirements: REQ-004/005/006/007/016; recovery obligations from SP-005.
- Dependencies: M2 owner closure, accepted SP-008 physical validation, specified
  [annotation contract](../docs/data/scripture-annotation-contract.md).
- Design: [TDD §10](../docs/tdd/tdd.md#10-annotation-layer-design),
  [rendering decision](../docs/design/scripture-rendering-decision.md).

## Visible outcome and boundaries

Write in the actual Scripture reader, manage multiple named layers, revisit handwriting
without misalignment, and export/restore an annotation backup. Start with bundled WEBP;
available licensed editions use the same identity/availability boundary without new sync
behavior. Provide Read Hidden, Read Visible and Draw; one selected layer visible; native
Pencil palette, finger pan/zoom and blank surrounding writing space.
Keep selection/verse actions in reading modes; disable them and chapter swipe gestures
while drawing. Explicit chapter controls transition only after the stroke and save finish.

Includes autosave/error/retry, independent in-session layer undo, recoverable deletion,
missing-layout states and annotation-only Files export/replacement restore. Excludes Notes,
Collections, cross-edition ink conversion, full-app backups, audio implementation, provider
changes, experiment migration and further tab-shell polish. VoiceOver is waived, not passed.
No actual M3 implementation or acceptance is claimed by this ticket's creation.

## Source ownership and sequence

Existing integration: `Features/Scripture/ScriptureView.swift`, `ReaderSession.swift`,
`ReaderTextSurface.swift`; keep existing reader identity, selection, progress and quote
permissions intact. Reuse learned gesture/geometry behavior from `LayoutValidation/`,
not its DEBUG session/storage. Implemented ownership: `Core/Annotations/` domain values
and repository interface, `Infrastructure/Annotations/` versioned file repository/archive,
and `Features/Scripture/Annotations/` session, controls and shared TextKit/PencilKit viewport.
Repository maps now include these modules.

1. Implement validated identity/layout types and versioned repository with interruption,
   corruption, concurrency and tombstone fixtures (ANN-01/03/04/06).
2. Integrate fixed-layout rendering and layer controls into the real reader, preserving
   ordinary M2 reading and licensed availability boundaries (ANN-02/05/06).
3. Implement annotation-only Files export and explicit replacement restore with rollback
   and hostile/corrupt input validation (ANN-07/08).
4. Build/test on an installed iPad simulator; install in place on the owner's iPad and
   verify real writing, reopen, backgrounding, font/viewport transitions and dense long
   chapters (ANN-02/05/09). Record sample dimensions, font resources, size limits and results.

## Acceptance and verification

All ANN-01–09 in the linked contract require evidence. Also regress reader selection,
verse hub, chapter/version navigation, progress restoration and shell/footer clearance.
No overwrite of real study data for tests: use injected temporary stores. Use current
commands from [test specification](../docs/testing/test-specification.md) and signing from
[deployment](../docs/deployment/deployment.md); artifacts remain in ignored `build/sp012/`.
A failed integrity/recovery check blocks daily-use completion. Physical performance or
Pencil failures must be fixed or explicitly scoped with the owner, not reported as passed.

Update TDD, data contract, project maps, testing/deployment evidence and roadmap at closure.
M3 closes only after actual-reader device acceptance and successful annotation restore.

## Planning evidence — 2026-09-29

Owner selected the immediate next planning step after SP-008. SP-005's annotation slice
and this implementation scope are now documented. No native tests run for this doc-only
step; no app/source/user-data changes. Next owner selection is SP-012 implementation.

## Implementation and verification — 2026-09-29

Implemented persistent layer CRUD/tombstone recovery, fixed chapter layouts, native
Pencil-only canvas/palette, shared pan/zoom, independent layer undo/redo, autosave with
stroke/navigation guards, visible save failure/retry, original-layout availability checks,
and ink-only Files export/replace/restore with pre-import recovery. Ordinary reader mode
retains existing selection, verse hub, chapter/version controls and progress state.

Evidence:
- `build/sp012/checks-r4.xcresult`: 12 unit/component tests and 3 simulator UI tests passed
  (layer lifecycle/reopen, font reading-view return, continuous scrolling/chapter swipes).
- Reader navigation/settings/progress relaunch regression also passed in `checks-r2.xcresult`.
- `build/sp012/ipad-r1.xcresult`: both actual-reader layer UI journeys passed on the paired
  physical iPad A16; test stores were UUID-isolated. These tests use empty layers, not Pencil input.
- Retained simulator and physical landscape screenshots reviewed: text, margin and layer
  controls visible, footer content unobscured. Initial UI failures were resolved: mode
  observation/palette visibility, text-input test interaction and duplicate menu-label query.
- Dense simulator fixture: WEB Psalm 119, 176 verses, 820 × 16,825 points, 2,000 strokes,
  311,887 drawing bytes; save/reopen verified. This is not physical Pencil/performance acceptance.
- `build/sp012/contrast-r6.xcresult`: added default-ink contrast test for dark themes.
  Newly opened canvases use the reader ink color; user-selected stroke colors remain literal.
- Signed device build/test install and normal CoreDevice launch passed. Final color adjustment
  delivery is recorded in `device-final-build.log`, `device-final-install.log` and `normal-final-launch.log`.

Repository uses immutable generations with current/previous/pre-restore pointers;
manifest/payload checksums, schema/size/path validation and injected commit interruptions
are covered. Damaged originals are retained, and unsupported schemas are not rewritten.
Archive format is JSON rather than zip: generated UUID-only IDs remove imported path traversal.
No Notes/Collections/provider/reader-state migration. Existing workspace edits preserved.

Remaining gate: [actual iPad Pencil and Files walkthrough](../docs/testing/sp012-ipad-guide.md),
including palm rejection, real ink alignment/undo, background/relaunch, archive round trip
through Files and representative dense-chapter responsiveness. These are pending, not passed.
SP-012 and M3 remain in progress until owner acceptance. VoiceOver is waived.

Final restore safety check: `build/sp012/restore-r7.xcresult` passed backup canvas
invalidation and dark default-ink contrast. Restore increments a surface generation before
publishing the restored snapshot; dismantling an old canvas cannot flush stale ink over
it. Unique passing checks: 14 annotation unit/component tests, 4 simulator UI journeys
(including the two existing reader regressions), and 2 physical-iPad UI journeys.
Actual Pencil and Files acceptance remain pending. No unperformed case is counted passed.

## Owner feedback revision — 2026-09-29

Owner rejected the ruled right-hand margin, left-positioned annotated column, altered
Hidden appearance and annotation-control placement; requested autosave and palette closure
while writing. Revised within SP-012: centered controls, normal reader in Read Hidden,
v2 centered text with blank surrounding space and shared viewport zoom/crop; no rule lines.
Legacy v1 groups/ink retained unchanged; new layers on v1 start a v2 group. Stroke begin
closes the native palette; Tools reopens it; completed strokes autosave. Autosave no longer
disables drawing or forces the palette open. Revised Pencil feel remains owner acceptance.

Revision verification: `build/sp012/revision/final-sim.xcresult` passed 16 annotation
unit/component tests, three annotation UI journeys and two reader UI regressions. Reviewed
portrait screenshots show centered controls, blank space without rules, and the ordinary
reader in Read Hidden. The signed device build and reinstall succeeded; after the owner
accidentally deleted the prior app, a fresh reinstall and normal launch succeeded
(`device-final-build.log`, `device-reinstall.log`, `reinstall-launch.log`). Deletion may have
removed previous local study data; no preservation or recovery is claimed. The revised
physical Pencil, autosave, and backup/restore walkthrough is still pending owner results.

## Layer-owned appearance revision — 2026-09-29

The owner selected a further SP-012 interaction change: new layers capture their own
layout, preset/typeface and text-size step. Layers are listed across legacy groups in one
picker; the selected layer name is blue and checked, with muted appearance and point-size
detail. The toolbar layer button keeps the standard control appearance. Selecting a layer
restores its saved reader settings. Deliberately changing type
or size in Read Visible or Draw recaptures only the selected layer's geometry. Its ink
bytes remain unchanged and a warning explains that existing marks may need adjustment;
other layers retain their settings. Read Hidden uses the ordinary reader, hides Margin,
and keeps independent reading-size changes until annotation is re-entered. The separate
Preserved layouts and larger-text reading actions are gone. Clear Ink is red and undoable.

Draw starts with the picker minimized behind a compact affordance; that affordance can
collapse to an edge tab or expand the native picker. A Pencil stroke minimizes it again.
On iPadOS 26 the PencilKit responder keeps its picker active while offscreen; earlier
supported iPadOS versions use the compact app affordance to reopen it. Older archives
decode through group layout fallback without rewriting or converting their ink.

Verification for this revision: `build/sp012/revision/layer-unit.xcresult` passed 17
annotation unit/component tests; `layer-final.xcresult` passed 17 annotation tests,
three annotation UI journeys and four reader regressions. The final compact/edge-tab
control has a separate focused run in `palette-final.xcresult`. Physical Pencil feel,
palette behavior, alignment after deliberate font changes and backup/restore still
require owner acceptance; SP-012 and M3 remain in progress.

`layer-device-build.log` and `layer-device-install.log` record a signed build and
in-place install on the paired iPad. The first launch was denied pending device trust;
the owner trusted the Personal Team profile and reported Sophia opened. A subsequent
normal CoreDevice launch passed (`layer-device-launch-retry.log`). Installation and
launch do not establish the physical Pencil and recovery walkthrough.

Selected-layer color refinement: the toolbar layer button now uses the same plain
appearance as adjacent controls. Inside the layer picker, only the selected name and
checkmark are blue; there is no selected-row background. A focused iPad A16 simulator
UI journey passed (1/1, `build/sp012/revision/layer-color-final.xcresult`), and its
retained screenshot confirms the final colors and toolbar appearance. Physical owner
acceptance for the wider SP-012 workflow remains pending. The signed update built,
installed over the existing app, and launched on the paired iPad
(`layer-color-device-build.log`, `layer-color-device-install.log`,
`layer-color-device-launch.log`).

Hidden-reader responsiveness and control refinement: a hidden annotation canvas now
skips full layout validation on unrelated updates, while visible layouts are validated
once per saved signature. This removes redundant annotation work from the ordinary
reader's verse-to-Hub path. The layer picker separates New, Rename and Delete into
distinct icon buttons (plus, pencil, red trash), and modes use dark-pupil eye,
hollow-pupil eye and pencil icons for Read Visible, Read Hidden and Draw respectively. A focused
simulator journey passed for create → Read Hidden → verse tap → Verse Hub; its retained
timing was 1.6 seconds from automated tap to visible Hub. The existing layer
management journey passed after waiting for the delete confirmation to dismiss.
The final `hub-controls-acceptance.xcresult` passed all four annotation UI journeys;
the retained picker screenshot shows white New text and red Delete icon/text, and
the hidden Verse Hub timing was 1.6 seconds in the simulator.
Physical latency and visual feel still need owner observation; SP-012 remains in progress.

Final mode icons use a custom eye outline with a dark or hollow pupil, since the
standard outline eye still fills its pupil. `hollow-eye-acceptance.xcresult` passed
all four annotation UI journeys; the hidden-mode screenshot was visually reviewed.
The final signed build, in-place install and normal iPad launch succeeded
(`hollow-eye-device-build.log`, `hollow-eye-device-install.log`,
`hollow-eye-device-launch.log`). Actual Pencil, physical responsiveness and Files
restore acceptance are still pending owner results.
