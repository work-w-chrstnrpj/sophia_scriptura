# SP-025 — v0.3.0 compound ink and stroke editing

Status: implemented; simulator verification recorded below; physical Pencil/performance acceptance pending.
Owner selected implementation 2026-10-07 and authorized v0.3.0 publication 2026-10-09. Current source was installed in place and launched on the owner iPad; physical feature acceptance remains pending.
Type: bugfix + architecture refactor + feature. Priority: high.
Affected version: v0.2.*. Fix version: v0.3.0.
Milestone: M4 follow-up. Owners: System Architect, Frontend, storage and SQA.
Requirements: REQ-008/009; owner-requested stroke editing. Dependencies: SP-013/014/024.
Design: [Notes](../docs/design/notes-screen-specification.md), [interactions](../docs/design/canvas-interactions.md).
Contract: [Notes](../docs/data/notes-contract.md). Release: [v0.3.0 release](../docs/releases/v0.3.0.md).

## Problem and source evidence

Owner reports a “300 object limit” and handwriting selection that selects an entire
batch. Confirm the installed affected version and reproduce before diagnosing a framework
limit. Current `Core/Notes/NoteDocument.swift` defines `objectLimit = 1000`;
`Features/Notes/Editor/NoteCanvasInk.swift` stores PKDrawing payloads, maps strokes to
object owners using creation dates, and starts new unselected ink objects after 64 strokes.
SP-024 tests 300 strokes; that test count is not an object limit. The current implementation
already has compound ink payloads, but selection in `NoteCanvasSurface.swift` acts on whole
objects. The issue is the arbitrary batching boundary and missing internal selection.

Expected: handwriting consumes ink-region objects, while individual strokes remain editable.
Actual: continued writing creates more ink objects and a stroke tap/lasso selects a whole batch.
No evidence establishes a PencilKit/framework-imposed 300-object ceiling.

## Target architecture and boundaries

Keep a real ink region as one top-level NoteObject with transform, z-order and a PKDrawing
payload; strokes are internal primitives, never separate NoteObjects or ordinary group
children. Reuse the existing ink kind where possible rather than inventing a parallel model.
A drawing session/region can hold thousands of strokes within explicit byte/stroke limits.
Do not create another region merely because stroke 65 was added. Define deliberate region
creation and capacity behavior before implementation; preserve interleaving with text/images
and existing object z-order. Do not merge all ink into one layer if that changes overlap.

Provide object-selection and drawing-edit modes. Object mode moves/resizes a region.
Drawing-edit mode tap/lasso selects stable stroke IDs inside it; move, delete, recolor,
copy and undo affect those strokes only. Define whether lasso means intersection or full
containment, and test thin strokes, overlaps and zoom. Empty space inside a region's bounds
must not prevent selecting another visible object. Resolve topmost visible geometry first.

Retain native PencilKit ink/pressure/masks and shared SP-014 refinement. Store stable stroke
identity metadata with the drawing if needed; creation dates alone are not a sufficient
identity contract for duplicate/paste, partial erasure, splitting and restore. Define ID
lineage for splits and duplicates and validate metadata/payload consistency.

Index stroke bounds in document coordinates (grid, quadtree or equivalent); query nearby
candidates, then precisely test visible stroke geometry including transforms, width and
masks. Rebuild/invalidate after edits, region transforms, undo and restore. Use PKCanvasView
or bounded region/tile rendering without one UIView/CALayer/SwiftUI node per stroke.
Preserve viewport culling, cached scenes and bounded caches from SP-024.

Excluded: unlimited ink, full Freeform parity, a Metal rewrite without profiling evidence,
Scripture annotation architecture changes, authentication locks (SP-026–028).
Existing positionLocked is an object movement setting, separate from privacy locking.

## Implementation sequence and compatibility

1. Reproduce reported failure; record object count, stroke count, payload bytes, app version
   and physical-device baseline. Separate validation rejection from memory/input failures.
2. Record an architecture decision for region ownership, stroke IDs, two selection modes,
   hit testing, z-order and history; prototype the riskiest PencilKit identity/edit behavior.
3. Extend the existing model/decoder only as needed. Preserve legacy single-stroke objects,
   64-stroke batches, groups, IDs, bounds, transforms, colors and z-order on read. Legacy
   batches must immediately support internal editing; automatic consolidation is optional
   only where it preserves every observable property. Never rewrite user data destructively.
4. Implement internal selection/edit/undo and indexed geometry; remove the automatic
   64-stroke split for new handwriting. Keep ordinary grouping distinct from ink containment.
5. Integrate save/reopen, export/share, backup/restore and caches. Validate before writes;
   preserve prior generations and dirty data on failures. Document old-build compatibility.
6. Profile realistic writing and editing on the owner's iPad, then update contracts/tests.

Keep existing 16 MiB ink payload, 10,000 strokes/drawing, 1,000 object and aggregate/archive
bounds unless independently measured and explicitly revised. A 10,000-stroke region consumes
one object only when its payload fits. 20,000 strokes is an illustrative scaling case,
not acceptance for one payload under the current 10,000-stroke bound. If exceeding region
capacity, provide an actionable new-region path without losing the in-progress edit.

## Acceptance and verification

- [ ] More than 300 and 1,000 normal handwriting strokes stay in one new region, within
  safety bounds; stroke 65 creates no extra top-level object. Mixed non-ink capacity remains enforced.
- [ ] Tap/lasso selects one/subset of strokes; moving, recoloring, deleting and undo/redo
  leave other strokes unchanged. Object mode still selects/transforms the region.
- [ ] Stable identity and visible geometry survive copy, partial erasure, split, transforms,
  duplicate legacy creation dates, undo/redo, save/reopen and backup/restore.
- [ ] Old v0.2.* fixture documents retain layout, grouping, layer order and editable ink.
  Invalid/oversized payloads fail safely with recoverable data; downgrade behavior is documented.
- [ ] Index results match a precise reference implementation on transformed/masked drawings;
  sparse high-count scenes demonstrate candidate reduction without missed hits.
- [ ] UI regression covers overlapping image/text/ink selection, zoom/pan, themes and sharing.
- [ ] Physical Pencil acceptance covers sustained writing, palm rejection, lasso, erase,
  shape refinement, undo, region transitions and relaunch on realistic notes. Compare baseline
  and new traces on the same device/document; record latency/frame responsiveness, memory,
  hit-test candidate counts and save durations. Set measured performance targets before closure.

Stop if conversion changes legacy rendering, stroke identity cannot be preserved, edits
are lost, or profiling shows unacceptable regression. Simulator tests alone do not close
physical acceptance. Implementation and automated evidence are recorded below.

## Documentation and references

Update Notes contract, Notes/canvas design, physical guide, test specification, TDD and
release notes with final decisions and evidence during implementation.
Apple documents grouped Freeform strokes with selectable drawing portions, not private
storage or spatial-index internals: [Freeform drawing](https://support.apple.com/guide/iphone/draw-or-handwrite-iphe749c1957/ios).
Native compound ink: [PKDrawing](https://developer.apple.com/documentation/pencilkit/pkdrawing).

## Implementation decisions and evidence — 2026-10-07

- Retained the existing ink kind/PKDrawing store, adding optional parallel `strokeIDs`.
  No destructive conversion or archive version bump; legacy bytes/geometry/groups remain.
- Default extension follows the eligible topmost ink region; inserting non-ink content
  creates a z-order boundary, and New drawing region is deliberate. Real 10,000-stroke/
  16 MiB overflow spills adjacent to its source rather than discarding the new stroke.
- Pencil lasso defaults to Strokes. Note options exposes Objects/Strokes. Internal tap and
  cross-region lasso use a grid plus sampled transformed/masked geometry; lasso requires
  full containment of visible centerlines. It is not handwriting word recognition.
- Stroke palettes implement recolor/copy/duplicate/delete and whole-drawing selection;
  selected strokes drag by Pencil/finger. Paste is available in Note options. Undo/redo,
  history byte budgets, Notes save/export/restore and legacy duplicate dates retain identity.
- Ink raster crops follow a snapped viewport, retaining existing object culling and cache
  limits. Sharing includes complete off-screen content and excludes transient outlines.
- Overall note rejection retains a bounded atomic native-drawing recovery file. Explicit
  Recover unsaved drawing creates a new Canvas note, preserving the saved original.
- `build/sp025/focused-3.xcresult`: 45 focused tests passed.
- `build/sp025/final-regression.xcresult`: 225 unit tests and two Canvas UI checks passed:
  select/copy/delete one stroke, paste/undo, and existing palette color/share behavior.
- `build/sp025/verified-unit.xcresult`: final source snapshot passed 226 unit tests after
  position-lock semantics/history accounting review and bounded collision-token fixes.
- Simulator screenshot of copied/pasted ink inspected in `build/sp025/ui-attachments/`.
  No physical drawing trace, stylus selection/erasure pass or measured speed improvement claimed.

Native partial-erasure behavior, sustained Pencil feel, palm rejection, geometry at varied
zoom, theme/export visual quality and comparable device performance are **Not Run** for this
implementation. The installed-build “300 limit” was not reproduced on the owner's device;
source and automated tests establish 1,000 object safety bounds and no 64-stroke split.
The old SP-024 device trace remains historical baseline evidence, not SP-025 profiling.
Explicit merge/separate drawing commands and full Freeform parity are excluded.

Affected source: `Core/Notes/NoteDocument.swift`, `NotesSession`, `NoteCanvasInk`,
`NoteInkStrokeIndex`, `NoteCanvasSurface`, `NoteEditorView`, `CanvasObjectPaletteBuilder`,
`NotesFileRepository`, plus `NoteStrokeEditingTests`, Notes tests and focused Notes UI tests.
Contracts/design/TDD, structure, roadmap, ticket index, release plan and device guide updated.
Owner physical acceptance is required before marking the ticket done.
