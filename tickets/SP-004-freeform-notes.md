# SP-004 — Freeform Notes design

- Type: design. Status: in_progress. Owner: Frontend UI/UX Developer.
- Requirements: REQ-008, REQ-009, REQ-016, REQ-017.
- Dependencies: expandable canvas and explicit grouping accepted; growth/navigation, detailed selection/resize, and export remain open. Can proceed independently of Bible provider access.
- Design: [canvas comparison](../docs/design/ux-specification.md#freeform-canvas-alternatives),
  [TDD §7](../docs/tdd/tdd.md#7-data-model).
- Affected later modules: NoteCanvas, user persistence, media/drawing files, export/import.

## Purpose and scope

Design genuine freely positioned content. Linear blocks with separate handwriting
sections do not satisfy the owner. Expandable canvas is the selected direction.

## Work

1. Completed: compare the same study example in both layouts and record expandable canvas selection.
2. Review extent, zoom/navigation, exports, and moving text beneath ink with the owner.
3. Specify object selection, grouping, stacking, resizing, keyboard/drawing modes, and undo.
4. Define document coordinates separately from viewport coordinates and identify payloads
   for text, ink, images, quotes, tables, links, shapes, and lists.
5. Plan a minimal native experiment with text, ink, and one image on the actual iPad.

Drafted: [Interaction proposal 02](../docs/design/canvas-interactions.md) and bounded
[SP-006 native experiment](SP-006-native-canvas-experiment.md). Explicit grouping is
accepted and the bounded experiment is ready; detailed interaction proposals and native
verification remain outstanding.

## Acceptance and verification

- Owner canvas choice and tradeoffs are recorded; unresolved interaction details remain explicit.
- The selected design preserves free object placement and does not imply automatic ink/text grouping.
- Future experiment verifies place → edit → move → zoom → save → reopen, plus export/restore.
- Accessible reading order and navigation to off-screen content are specified.
- Rich objects remain tracked even if deferred from the first experiment.
- No claim of smooth iPad performance without measured device evidence.

## Outputs and boundaries

Update UX and TDD; create a ready prototype ticket after choices settle. Do not implement
both editor modes speculatively or finalize a SwiftData schema before geometry decisions.

## Execution contract

Planning work only in the current stage. No implementation completion is implied by
this ticket. Record unresolved items explicitly. Do not create provider accounts,
accept agreements, purchase access, or obtain credentials on the owner's behalf.

## Evidence

2026-09-14: delivered the first interactive comparison of identical study content in
expandable and fixed-page layouts. See [Review 01](../docs/design/notes-canvas-review.md)
for the walkthrough and limitations. It includes bounded sample movement/grouping,
extension, overview navigation, undo, and an illustrative export layout. The fragment
was read back and checked for JavaScript syntax; no native/device behavior was tested.

2026-09-14: owner selected expandable canvas after the comparison. The product
specification, TDD, and UX review record the decision. Grouping, canvas growth limits,
and export policy remain open. Free editing, persistence, and exact export geometry
remain unverified. Keep this ticket in_progress until its remaining editor,
accessibility, persistence, and native-experiment planning requirements are addressed.

2026-09-14: added a second interactive concept for object selection, pointer movement,
explicit grouping, text-title editing, pan/zoom, and in-memory undo/redo. Documented
proposed native behavior and sample limitations in Interaction proposal 02. No PencilKit,
disk persistence, or device-performance result is implied.

2026-09-14: owner accepted explicit grouping after the interaction concept. SP-006 is
ready as the next bounded feasibility experiment; execution has not started. Remaining
selection/resize rules, production persistence, export, and accessibility keep SP-004
in progress. The earlier pending-grouping entry records the state before this decision.

2026-09-15: SP-006 native implementation now exists with shared document coordinates,
explicit grouping, PencilKit and a disposable fixture store. Simulator unit tests pass;
UI and physical-device evidence remain in progress. Production selection/resize, scale,
export and accessibility decisions remain open. See SP-006 for current execution evidence.

2026-09-17: drafted the [Notes library and expandable canvas specification](../docs/design/notes-screen-specification.md).
It defines the library cards/list, blank-note flow, editing modes, object vocabulary,
explicit grouping and stacking, passage links, autosave/recovery, accessibility gates and
design-review acceptance scenarios. Native lasso, rich-object slicing, growth limits,
revision retention and PDF export remain open. No production editor code was authorized or
changed; SP-004 remains in_progress pending owner review and native feasibility decisions.

## SP-006 closure handoff

Owner approved closing SP-006 as a bounded experiment. Its findings support separate
geometry, session, rendering and storage responsibilities; the prototype is not the
production editor. Inherit VoiceOver/large-text, exact window-resize, canceled-drag and
direct-drag/zoom verification into production editor tickets, alongside native Pencil
palette and direct text editing. These deferred checks are not passed; avoid reopening
the prototype solely to complete them.

## M4 implementation handoff — 2026-09-29

Owner requested M4 implementation. SP-013 records the production scope and ownership;
`docs/data/notes-contract.md` resolves initial bounded geometry, flat whole-object grouping
versus native per-object lasso, recovery and retention. Initial safety limits are not
measured capacity. Rich object/Pencil/VoiceOver acceptance and PDF pagination remain
explicit review items; SP-006 is not promoted or migrated into production.
