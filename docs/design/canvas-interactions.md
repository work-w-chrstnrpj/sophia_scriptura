# Expandable Canvas — Interaction Proposal 02

Status: explicit grouping accepted; remaining detailed interactions proposed, 2026-09-14.
Expandable canvas itself is confirmed in
[Review 01](notes-canvas-review.md). Work: [SP-004](../../tickets/SP-004-freeform-notes.md).
Requirements: REQ-008, REQ-009, REQ-016, REQ-017. Technical intent: [TDD §7](../tdd/tdd.md#7-data-model).

## Proposed defaults

1. Text, ink, and images are independent until deliberately grouped. Drawing over text
   does not silently attach the strokes to that text box.
2. A tap selects an object; editing text is a separate action. Moving a selected object
   changes position, not its content. Objects remain individually editable after grouping.
3. Grouping makes a selection move as a unit. Ungrouping preserves every member's current
   position and content. It neither erases nor flattens handwriting.
4. Pan and zoom change the viewport only. They do not rewrite document coordinates or
   create content-undo steps. A visible Return to study control recovers a lost position.
5. Completed edits participate in document undo/redo and autosave. A canceled gesture
   restores its starting state. Saving must never claim success before persistence succeeds.

The owner accepted explicit grouping after trying the concept and answering the question
about keeping text and handwriting independent until deliberately grouped. This confirms
the grouping policy, not every detailed gesture, resize, storage, or export proposal.
Visual overlap alone will not create an implicit attachment.

## Input and editing states

| State | Touch/Pencil proposal | Keyboard/accessibility alternative | Exit |
| --- | --- | --- | --- |
| Select | Tap a target; drag its selection to move; use a visible multi-select action or object list | Labeled object list, add/remove selection, movement commands; arrow keys when selection has focus | Blank-space tap clears selection; choose another mode |
| Edit text | Enter through Edit text or deliberate double tap; insertion and text selection belong to the editor | Standard text navigation; accessible text field | Done commits; Cancel discards draft; leaving explicitly commits or cancels before changing canvas mode |
| Draw | Pencil makes strokes; finger navigation remains distinct; no reliance on Pencil Pro controls | Typed text alternative and labeled drawing tools | Switch tool/mode; completed stroke enters undo history |
| Pan | Drag surface to navigate without moving any object | Return to study, object-list focus, navigation controls | Select or Draw |

Two-finger pinch/pan and one-finger drawing preferences must be validated with UIKit/
PencilKit in the native experiment. This is proposed interaction policy, not a claim
that a particular gesture combination already works. Drawing is absent from the web concept.

## Selection, overlap, and grouping

- Native hit testing should target visible strokes and object content, with a usable
  touch tolerance; an ink object's empty bounding area must not consume all text taps.
- When overlap is ambiguous, the object list offers direct named selection. Drawing
  does not need to be hidden merely to find or select the underlying text object.
- Multi-selection is explicit and visible. Native lasso selection is a candidate, not
  required for the initial experiment; the object list must make the same work possible.
- Group/ungroup commands operate on existing IDs. Selecting a member selects the group
  for movement. Edit text targets the text member without dissolving its group.
- Grouping already grouped items should either merge the selection into one flat group
  or be disabled with a clear reason; the initial proposal favors flat groups, no nesting.
- A group selection may move without scaling. Keep resize behavior distinct from move.
- Proposed text resizing changes text-box width and reflows text; image resizing keeps
  aspect ratio by default. Group scaling and ink resizing are deferred until their
  semantics are reviewed, rather than implicitly applying text reflow to ink geometry.
- Propose explicit Bring forward / Send backward controls with stable order. Semantic
  accessible reading order is separate from visual stacking and needs its own policy.

## Important consequence of grouping

Grouping preserves relative positions when moving. It does not attach each stroke to
particular words. Editing or resizing a text box can change line wrapping while an ink
circle stays in its original position. Do not promise automatic handwriting reflow.
The initial design should preserve the ink, allow undo, and make repositioning possible.
Word-anchored handwriting is separate, more complex work and is not assumed here.

## Coordinates, navigation, and growth

- Store object identity, geometry, content, stacking, group membership, and passage links
  in document coordinates. Viewport translation and zoom are separate state.
- Convert pointer movement into document movement using the active zoom. Group members
  receive the same document-space delta; inverse movement restores their positions.
- Grow usable space as content extends outward, without shifting existing objects or
  allocating an enormous bitmap. Exact growth directions, bounds, and limits need testing.
- Keep a visible zoom value, zoom controls, and a way to center a named object. A later
  overview can summarize larger notes; do not require navigating manually back to origin.
- Rotation and window resizing preserve document geometry and adjust only the viewport.
  They must not automatically rearrange content as a responsive web page would.
- Selected-object centering and accessible object navigation remain usable when overview
  zoom would make text too small to read. Final zoom limits follow device measurements.

## Undo, saving, and recovery

| Operation | Proposed undo boundary | Persistence intent |
| --- | --- | --- |
| Drag/move | One completed gesture, not every pointer sample | Commit object/group positions together |
| Keyboard movement | Consistent movement transaction; decide key-repeat coalescing in native work | Commit final positions |
| Group/ungroup | One reversible membership change | Preserve IDs and world positions |
| Typed edits | Native text-editor coalescing; integrate across canvas/text history deliberately | Save content without losing other object edits |
| Drawing | PencilKit-supported stroke actions integrated with document history | Save a recoverable drawing revision with metadata |
| Pan/zoom/selection | No document undo entry | Optional viewport restoration is separate |

Preserve unsaved changes during backgrounding and after an interrupted metadata/file
write. The data contract must define a recoverable revision/manifest strategy and
failure behavior before daily use. Save/reopen and export/restore are different tests;
neither can be inferred from a smooth visual demonstration.

## Interactive concept walkthrough

The conversation presents `sophia-canvas-interactions`, using the observation, handwriting,
and sample image from Review 01. It starts with the Observation selected.

1. Use the right arrow: only text moves; handwriting stays put. Undo restores the move.
2. Add Handwriting to the selection using its object button, choose Group, then move.
   Both objects keep their relative positions. The group outline makes membership visible.
3. Ungroup, select one member, and move it independently. Membership changes are undoable.
4. Switch to Pan and drag. Zoom in/out, then Return to study. Object geometry stays fixed.
5. Select the text and choose Edit text. Change its title, then Done or Cancel. Observe
   that grouping does not reflow handwriting around edited words.
6. Select Image in the object list to bring an off-screen sample into view on a narrow surface.

These browser interactions are functional demonstrations of proposed behavior, not a
native app implementation. The sample has three objects, one flat group model, pointer
dragging, keyboard/button nudges, editing one title, and in-memory undo/redo. It does not
save to disk. It has no stroke capture, arbitrary insertion, native lasso, resizing,
pinch zoom, edge auto-pan, PDF generation, or real metadata/file recovery. Ink selection
uses a bounding rectangle here; native hit testing still needs the stroke-aware behavior
specified above. Narrow screens deliberately show a portion of the canvas, with the
object list providing access to off-screen content.

## Next evidence

Explicit grouping is now accepted. Use
[SP-006](../../tickets/SP-006-native-canvas-experiment.md) to test the proposed input
and coordinate model on the actual iPad. Export pagination and performance budgets
remain separate decisions. No native testing or persistence pass is claimed by this document.

## SP-025 native stroke editing — v0.3.0

The Canvas Pencil lasso tool selects strokes inside real ink regions. Tap one stroke or
loop around multiple strokes across regions; drag a selected stroke to move the selection.
The floating stroke palette recolors, copies, duplicates or deletes just those strokes.
Select drawing returns to whole-region selection. Note options → Selection offers Objects
and Strokes explicitly; Objects keeps group and region movement/resizing semantics.
The native lasso initially chooses Strokes; selecting Objects afterward enables the
existing whole-object loop. Empty space inside a drawing's bounds passes through to other
objects. Drawing-edit lasso uses full containment of sampled visible centerlines, including
masks; it does not recognize words or automatically select a complete handwritten word.

Note options → New drawing region chooses fresh ink ownership, and Paste inserts copied
material with fresh object/stroke identities. Ordinary handwriting has no 64-stroke boundary.
Safety-bound spill remains adjacent to its source to preserve overlaps. No automatic
merge/separate drawing commands or unlimited canvas extent are included. Full geometry and
Pencil gesture feel still require physical acceptance.
