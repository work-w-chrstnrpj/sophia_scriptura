# SP-024 — v0.2.2 Collections and Canvas fixes

Status: implemented and simulator verified; physical draft acceptance pending. Owner selected on 2026-10-07. Milestones: M3/M4/M5/M6 follow-up.
Owner authorized v0.2.2 commit, merge and release on 2026-10-07 after simulator verification.
Physical iPad acceptance remains pending; installation is a separate request.

## Selected scope

1. Exclude archived, trashed or missing notes/conversations from Collection material,
   picker choices and visible item counts. Preserve memberships for recovery.
2. Address Canvas drawing object exhaustion and repeated rejected-edit churn. Batch new
   strokes in groups of up to 64, raise combined objects/attachments to 1,000, cache the
   composed scene until its ink objects change, and restore saved drawing after rejection.
3. Render editor Delete actions in red.
4. Add New Note/New Conversation to Add Study Material, assign new material to the
   current folder, then open its editor. Conversation creation keeps existing provider requirements.
5. Add Canvas image sharing and correctly colored, selected-state palette swatches.
6. Route the Pencil selection tool to object taps and a visible freehand selection loop.
   Enclosed object centers select the object and its explicit group; text objects enter
   text editing on a second tap, where UIKit supports character selection.

Item 7: owner clarified N/A. Full Freeform/Miro feature parity and unrestricted capacity
are excluded. Selecting individual strokes within a saved ink object is not included;
ink batches are movable objects. Existing drawings are preserved without conversion.

## Files and boundaries

Collections store/query, material picker/detail/library, Companion collection-sync lifecycle,
Root callbacks, Notes values/session/controller/palette/editor and their tests. Core owns
capacity and selection geometry; the UIKit controller owns Pencil gestures and sharing.
No schema-version changes, destructive operations or provider calls. Older builds may
reject notes containing more than their former 200-object cap; keep a backup before downgrading.

## Verification and acceptance

- Full unit suite, including inactive cached artifact exclusion, archive/trash/restore
  conversation sync, 1,000-object boundary, grouped-object selection and 300-stroke save/reopen.
- Focused UI test: create and open a Note from a Collection; verify folder membership.
- Simulator UI/visual inspection for share and palette where possible.
- Owner physical Pencil gate: sustained drawing, lasso object/text selection, movement,
  erasure, undo, zoom, save/reopen and responsiveness on realistic notes.
- Preserve ignored evidence in `build/v022/`; document failures and unrun physical scope.

## Drawing limits

Canvas: 1,000 objects, 16 MiB per object. New unselected drawing batches up to 64 strokes
per object; explicitly selecting existing ink allows extension. Page/Journal/Prayer: one
16 MiB ink payload, up to 1,000 combined attachments/legacy objects, 100,000 body characters,
500 citations, 12,000-point extent. Scripture: 32 MiB per drawing, 128 MiB annotation archive.
Notes: 200 notes and 128 MiB archive with an additional aggregate media bound (~42 MiB).
These are safety bounds, not measured device capacity. Notes drawings also have a
10,000-stroke bound per payload; Scripture has no separate stroke-count bound and allows
64 MiB aggregate drawing data.

## Owner-approved performance follow-up — 2026-10-07

The owner selected physical profiling, reduced ink/image processing, object-view culling,
and background image preparation. Existing serialized data and PencilKit input remain unchanged.
`NoteCanvasSurface` now mounts Canvas objects intersecting a 256-point viewport margin,
plus selected/edited objects. Scroll/zoom remounts visible objects without dropping document data.
Ink and image rasters use a 64-entry/32 MiB cost-bounded cache (including retained payload cost);
theme and document changes invalidate appropriate entries. The live ink scene is reused until
its objects change. `NoteImagePreparation` serializes ImageIO import/downsampling/JPEG encoding
and displayed-image decoding away from the main actor. Obsolete imports cannot insert into
another document or restored editor generation. Sharing temporarily mounts the full document,
awaits image preparation, checks the document revision, then restores viewport culling.

No SwiftUI Canvas rewrite, schema migration or unrestricted capacity is included. Physical
profiling is attempted against the installed v0.2.1 baseline; no device performance improvement
is claimed without a successful comparable trace. Physical Pencil acceptance remains open.

## Evidence — 2026-10-07

- `build/v022/cache-final.xcresult`: 216 unit tests and Canvas color/share UI test passed.
- `build/v022/acceptance-simulator.xcresult`: 216 unit tests and both focused UI tests
  passed (Collection create/assign/open, Canvas color menu/share sheet).
- Culling regression verifies off-screen views are removed, selected objects remain mounted,
  panning remounts views, and document objects remain intact. Image regression verifies
  4,096 × 1,024 input becomes 2,048 × 512, decoded dimensions match, and invalid input is rejected.
- The 300-stroke persistence regression checks cached scenes match fresh reconstruction.
- Simulator screenshot shows colored swatches and red editor Delete. Saved under
  `build/v022/ui-attachments/`; no physical visual acceptance is inferred.
- Physical installed v0.2.1 baseline: 30-second Time Profiler capture in
  `build/v022/ipad-usb-baseline.trace`, exported profile and summary in the same directory.
  10,610 Sophia running samples represent 10.61 seconds of sampled CPU weight across threads,
  including 6.604 seconds on the main thread. These statistical CPU samples do not measure
  frame rate, hang duration, or memory, and do not attribute a confirmed cause to a specific function.
  Initial PID-targeted attempts failed; recording all processes by device name succeeded.
  Available local debug symbols did not match the trace, so function attribution remains unresolved.
- `git diff --check` passed. No release, tag, push, commit or draft iPad installation occurred.

Remaining gate: sustained Pencil drawing, object/text selection, erase/undo/zoom/reopen,
and responsiveness on the optimized build on the owner's iPad. Selection acts on whole
ink objects, not individual strokes; UIKit text editing supports character selection.

## Release authorization — 2026-10-07

Owner requested `release v0.2.2`. Version 0.2.2/build 19 and release notes are prepared
for the existing gated main-branch Release workflow. Earlier withheld-release statements
above record the original draft scope. Physical acceptance remains open after source release.
