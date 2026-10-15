# Notes Canvas and Page — SP-013 design and implementation plan

Bulk-delete follow-up (2026-10-05): Notes selection captures the chosen note IDs when
Delete is tapped and presents its confirmation on that button. Cancel preserves the
selection; Move to Trash hides only those notes, retaining 30-day recovery in Settings.

Status: owner selected implementation on 2026-10-01. Canvas/Page creation, typed storage,
Page attachments, Canvas ink objects and Scripture visibility are implemented. Verification
and physical acceptance are recorded in [SP-013](../../tickets/SP-013-freeform-notes.md).
The previous build's reported Pencil failures are not considered resolved on hardware
until the owner repeats the Scribble on/off checks.

Journal and reference notes remain ungrouped and need no Collection. New-note creation
offers **Canvas** and **Page**. They share library metadata, persistence, search,
backup/recovery, verse identity and optional Scripture-pane visibility, but use separate
content and editing rules.

## Implemented types

### Canvas

- An open, zoomable workspace. Text boxes, drawings, image/media items, tables, shapes,
  stickers and link cards are independent objects with document-space geometry.
- A Pencil stroke creates or extends a Canvas ink object. Finger input selects, pans,
  pinches, moves and resizes objects. Editing text requires an explicit finger action;
  Pencil input never enters handwriting-to-text mode.
- Canvas ink can move, resize and participate in explicit grouping because it is an
  object. This deliberately changes the earlier rule that all note ink stays fixed.
- A link is a preview card. Scripture can be inserted as a quoted passage object that
  retains edition, revision, attribution and canonical reference metadata.

### Page

- A flowing, growing text document with a fixed-width reading column. Typing and editing
  feel like a word-processing page, while one transparent Pencil layer stays above text
  and all attachments. Pencil ink is page-positioned and cannot be selected, moved or
  resized. Typing text above it does not move old ink.
- Pencil always draws, whether iPad Scribble is on or off. Finger taps and a keyboard
  place the text cursor. Pencil touch must be routed to PencilKit before any text-input
  handwriting recognition can claim it. Beginning a Pencil stroke dismisses typing and restores drawing; no Done typing control is required.
- Web links are inline, tappable links instead of cards. Scripture quotations have an
  inline reference and preserve source/edition metadata.
- New floating text boxes, shapes and stickers are Canvas-only. Page images, tables and
  audio clips are inline attachments that flow with text. Existing v2 Page floating objects are
  preserved at their original positions and remain editable for compatibility.
- Page and Journal use a fixed 100% scale. Finger input scrolls vertically. Horizontal
  adjustment is available only while the Scripture pane is open. Pinch zoom remains Canvas-only.
- Canvas, Page, and Journal share one navigation-toolbar row. Insertion and format controls use the same system toolbar-button chrome as Undo and Redo. Archive and Delete live in More. Prayer keeps its own toolbar.
- The Page and Journal controls on that row are Pencil, text format, checkbox, table, and attach.
  Attach uses a paperclip. Its Link action keeps the chain icon, along with photo, document or text scan, and recorded or imported audio.
- A Journal shows Emotional state and Mental state on that same icon row as Pencil, format, Undo, and More. Both toolbar controls are glyphs only: the feeling’s face emoji, and the mind-set’s icon. Neither shows its name on the row. Both start empty and can be cleared. Each chooser is one list: the glyph followed by the name, and a chosen row is tinted. Mental state lists the named mind-sets with their short meanings,
  with Challenged directly under Neutral; Thriving uses a wheat icon and the other mind-sets have their own icons. A chosen mind-set is tinted in that state’s color on the toolbar and in the list. A library card shows the title, note type, created date, and last modified date, with no content preview. Every card is 176 points tall. The title is one line and ends in an ellipsis when it does not fit. The note type stays under the title, and the created and last-modified dates sit on the bottom of the card, aligned to its left edge.

### Shared Scripture pane

A visible-by-default button shows or hides the Scripture pane without destroying its
`ReaderSession`; passage and edition remain where the owner left them. Selecting a note
citation while the pane is hidden reveals it and navigates to that passage. The toggle
is a persisted UserDefaults preference, outside the note archive.

## Workspace refinement — owner selected 2026-10-01

- Compact icon insertion bar; tap the note title to rename. More contains paper, note color, metadata
  and save/retry status. No footer, Objects list or Done typing button.
- Notes editing extends through the bottom safe area. The shell tab dock floats over all
  tabs and hides on the existing idle timer; no reserved footer remains. Hide Scripture
  for the widest writing area. Shared theme paper/ink colors cover the header and body.
- Canvas is a bounded 12,000 × 12,000-point workspace. New items appear in the visible
  area; the zoom menu offers percentages and Fit content. Dots render only near the viewport.
- Tap an object for a floating palette: edit, duplicate, delete and More. More offers
  front/back ordering, multiple selection, grouping, and applicable color/shape controls.
  Tap a selected text box again to type; blank space ends typing. Drag a selected object
  to move, or its small bottom-right handle to resize. Only selection shows a border.
- Shapes include rectangle, rounded rectangle, circle, triangle, diamond, star, hexagon,
  heart and arrow. Stickers are an emoji gallery, not Apple's system sticker library.
  Insert also offers a sticky-note text box. Existing objects remain editable.
- Canvas link cards show a website thumbnail/title when available, with a domain fallback.
  Inserting/refreshing contacts the site; cached thumbnails survive offline reopening.
- Plain, ruled, grid and dotted paper work in both editors. Each note can persist a neutral,
  rose, amber, sage, blue or lavender paper tint with light/dark variants. Neutral black/white ink follows
  light/dark appearance; colored ink retains its chosen color. Theme-only changes preserve
  stored drawing bytes and geometry.

Interaction references: Apple's [shape formatting](https://support.apple.com/en-euro/guide/ipad/ipadb96d65cb/ipados)
and [text-box editing](https://support.apple.com/guide/ipad/add-text-ipad5a22ec43/ipados).
The implementation borrows their selection-first controls; it does not claim feature parity.

## Implementation plan

Owner selected this plan for execution. Two defaults were announced at implementation:
include Page images/tables inline and remember Scripture visibility across launches.
Implementation uses dedicated `NotePageController`/`NoteCanvasController` types sharing
`NoteSurfaceController` for viewport, input and object gestures rather than duplicating
that tested plumbing. Physical Pencil reproduction is deferred to owner testing; the
simulator exercises the same ancestor drawing recognizer using DEBUG finger input.


1. **Reproduce and isolate Pencil routing.** On the paired iPad, record model/iPadOS,
   Pencil model and Scribble setting. Verify Page ink with Scribble on and off, with the
   text field focused and unfocused. Confirm the PencilKit surface receives the Pencil
   touch and that typing exits reliably. Do not treat simulator finger-ink as proof.
2. **Separate the domain content.** Keep note ID, title, tags, timestamps and deletion
   metadata shared. Represent content as a tagged `NoteContent` value with one case:
   `canvas(CanvasContent)` or `page(PageContent)`. Canvas owns an ordered object list,
   including framed Pencil drawing objects. Page owns its text/citation model, fixed
   annotation drawing and any approved inline attachments. Validate each case with its
   own limits so a Page cannot accidentally persist movable Canvas ink.
3. **Route creation and editing by type.** New Note presents the two choices. The library
   remains shared. Build dedicated Canvas and Page surface controllers while reusing only
   small proven viewport, persistence and media components. Keep text-object editing out
   of Pencil hit testing. Use the full supported native inking/eraser palette; retain
   lasso/object transforms for Canvas and keep fixed Page ink outside object selection.
4. **Preserve Scripture workflows.** Page selections and quotes insert inline citations;
   Canvas selections create a quote object/card. Both call the existing reader quote
   authorization and keep original source, edition, revision, attribution and verse range.
   Add the hide/show control around the existing shared reader session.
5. **Version and migrate Notes safely.** Write an explicit type discriminator in a new
   snapshot schema. Decode prior schemas: a stored `page` means Page; an object-only note
   without a page means Canvas, preserving object frames and local ink bytes. Notes already
   saved by the fixed-page release remain Pages. Preserve the exact prior generation
   before the first new-schema save; keep envelope/pointer formats and unknown-schema
   refusal unchanged. Do not silently convert between types.
6. **Verify each surface, migration and device behavior.** Add focused model/storage tests,
   UI journeys for both creation paths and the Scripture toggle, then repeat Pencil routing
   on the physical iPad with Scribble both ways. Record the original error if it recurs.

This is a feature redesign with a Pencil-routing bug fix. Expected code ownership is Notes
domain/persistence, Frontend editor integration, and SQA physical acceptance; there is no
provider or backend change. Anticipated files are `Core/Notes/NoteDocument.swift`,
`Infrastructure/Notes/NotesFileRepository.swift`, `Features/Notes/NotesSession.swift`,
`Features/Notes/Editor/NoteEditorView.swift`, the existing page surface plus new dedicated
Canvas/Page surfaces, `NoteScripturePane.swift`, `NotesView.swift`, and `RootTabView.swift`.
Automated coverage belongs in `SophiaScripturaTests/NotesTests.swift` and
`SophiaScripturaUITests/NotesUITests.swift`.

The main risks are incorrect legacy type inference, losing framed ink/citations, and
PencilKit/Scribble differences across iPadOS versions. Unit tests decode historical-wire
v1 and v2 fixtures, assert inferred type and byte/geometry preservation, validate that each
content case contains only allowed state, and save/reopen/backup both types. UI tests should
cover chooser, Canvas transforms, Page typing/annotation, citations, pane show/hide and
reopen. Physical acceptance must test the paired iPad with Scribble enabled and disabled;
simulator tests cannot establish Pencil routing or palm rejection.

## Storage and runtime cost

The type tag and type-specific structure add negligible archive overhead. The model should
store one content case, not duplicate Canvas and Page versions of a note. Drawings and
images remain the dominant bytes, as they are today. A Canvas with many visible objects may
use more rendering memory than a Page; retain object/media limits and profile a realistic
Canvas on the iPad before raising them. No storage increase estimate is claimed without
measurement.

## Implementation boundaries

Canvas supports the listed object types within the existing bounded workspace. Link cards
fetch available website titles/thumbnails on insertion or explicit refresh and cache them for offline use. Arbitrary video/files and
PDF export, direct Companion capture, Collection membership and cross-type conversion are
not part of this slice. Page and Journal text styles are optional spans on the existing body. System sticker integration remains excluded. Ink/image payload and realistic Canvas memory still need device
profiling. The native palette follows tools supported by the installed iPadOS version. Hide Pencil
tools dismisses it when it covers the bottom tab controls; Pencil input remains enabled.

## Previous fixed-page implementation (historical)

The following sections describe the 2026-09-30 editor and original design history.
The Canvas/Page behavior above supersedes its single-editor rules.

## Installed Page-style editor (original design; issues reported)

The following rules describe the installed 2026-09-30 build. They are its intended
behavior, not proof of physical Pencil acceptance. The owner reports that Pencil input can
become text, typing is hard to exit, and drawing fails with Scribble disabled. The split
plan above supersedes the one-editor interaction rules after review.

## Installed Page and input rules

- A growing page has a fixed 1,200-point width and a centered 680-point flowing body.
  Rotation, the keyboard and Scripture pane change the viewport, never column width.
- Floating text boxes, images, link cards, tables, shapes and stickers move/resize
  independently above the body. Overlap never wraps or pushes body text.
- One page-coordinate Pencil drawing is intended to render above body and objects.
  Pencil should annotate; finger input scrolls/pans, pinches, selects objects and manipulates them.
  No Insert Handwriting or Draw mode. Ink cannot be moved, grouped or resized.
- Tap body text to type, tap an object to select it, drag a selected object to move,
  and drag its corner handle to resize. Two fingers pinch to zoom. Objects offers
  accessible selection/position/edit alternatives. Pencil tools are directly available.
- Ink stays at its coordinates when body content changes. Adding or removing earlier
  paragraphs can change which words lie underneath old ink; that is an accepted rule.
- The page grows down, including room below handwriting and floating objects. The current
  12,000-point height is a safety bound, not an infinite canvas promise.

## Historical 2026-09-30 study flows

1. Notes → New Note opens a blank body with the full Scripture reader alongside it.
2. Scripture selection → Save to note starts a note with selected text and an inline
   citation. The verse hub still supports Quote verse in new note.
3. The note's reader supports chapter/book/verse and translation navigation. Selecting
   text → Save to note, or tapping a verse → Insert verse and citation, adds to the
   current note at the end of its body. Tapping a citation navigates the reader.
4. Citation metadata retains source, passage range, edition, revision and attribution.
   Editing through a citation removes its link instead of attaching it to unrelated text.
5. Owner confirmed permission for personal note quotations from the existing translations.
   Existing per-edition access/quotation limits remain; WEB-only note restriction is removed.
6. Ordinary clipboard text can be pasted into body or text boxes. Companion response
   provenance and a direct Save-to-note action are future Companion integration, since
   the current Companion is a placeholder. No AI requests are introduced here.

## Historical 2026-09-30 durability and acceptance

See [Notes contract](../data/notes-contract.md), [SP-013](../../tickets/SP-013-freeform-notes.md)
and [iPad walkthrough](../testing/sp013-ipad-guide.md). Old note objects retain coordinates;
old ink is translated into the fixed overlay. Original v1 generation bytes are preserved
before the first v2 save. Existing saved files are never silently reset after a load error.
The owner installed the 2026-09-30 build and launch succeeded; physical interaction checks
and the reported crash/save message remain unconfirmed until reproduced. Removal of
box-bound ink rejection addresses one demonstrated failure boundary, not every possible crash.

## Historical canvas specification

The following describes the earlier object-canvas design. Where it conflicts with the
study-page rules above, the study-page rules supersede it. Retained for prior evidence.

# Notes Library and Expandable Canvas Specification

Status: design baseline; the owner selected bounded implementation in SP-013 on
2026-09-29. See the implementation scope below for shipped controls and outstanding
acceptance. This specification turns the accepted expandable-canvas direction into a
maintainable Notes experience while preserving the shared shell and explicit-grouping
rules.

Related documents: [App shell specification](app-shell-specification.md),
[canvas interaction proposal](canvas-interactions.md), [canvas review](notes-canvas-review.md),
[UX specification](ux-specification.md), [product specification](../product-specification/product-specification.md),
and [SP-004](../../tickets/SP-004-freeform-notes.md).

## Owner decisions carried forward

- Notes use an **expandable canvas**, not fixed paper pages or a linear-only editor.
- Text boxes, handwriting and images can coexist freely on one note.
- Objects remain independent until the owner explicitly groups them.
- Plain is the default canvas background; ruled and grid backgrounds are available choices.
- The library defaults to stacked cards, with a normal list as an alternative.
- Notes can be tagged and sorted by title or date.
- The native Pencil palette is an expected drawing workflow; Pencil Pro-only gestures are
  not required.

## Notes feature boundary

Notes are independent study documents. A note can quote Scripture or link to a passage,
but it does not become an annotation layer and does not rewrite the source passage. A
Scripture quote inserted into a note keeps its reference, translation and source text;
personal commentary remains editable separately.

The Notes feature owns the library, canvas document state, object editing and note-local
metadata. Shared verse identity, collection membership, file persistence and export rules
belong behind Core/Application and Infrastructure contracts rather than inside a view.

## Notes library

The library is the entry point from the Notes tab.

```text
┌───────────────────────────────────────────────────────────────────────┐
│ Notes                           [⌕] [Filter] [More] [＋]             │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐    │
│  │ Love that gives  │  │ Romans 8 study   │  │ Untitled note    │    │
│  │ John 3:16 · 3m   │  │ #assurance       │  │ No preview yet   │    │
│  │ [preview]        │  │ [preview]        │  │ [preview]        │    │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘    │
│                                                                       │
├───────────────────────────────────────────────────────────────────────┤
│ Scripture  Collections  Notes  Companion  Activity  Settings           │
└───────────────────────────────────────────────────────────────────────┘
```

### Library behavior

The root library uses **Notes** as a quiet leading header in the active appearance preset's
heading font. Minimal symbol-only controls sit
at the trailing edge: Search, view/filter, More/Backups and Add. Tapping Search replaces its
symbol with a compact inline field and focuses it; closing the field clears the query and
restores the symbol. Every symbol retains a 44-point target and an explicit accessibility
label. There are no decorative button capsules or duplicated navigation titles.

- **New Note** creates a blank note immediately, gives it a temporary title such as
  `Untitled Note`, and opens the canvas. The first title edit is optional; the user can
  begin writing without completing a form.
- **Cards** show the title, note type, created date, and last modified date. They do not
  preview note text, prayer activity, journal feelings, tags, or linked passages.
- **List** shows the same four fields in a denser, accessible row layout. Switching views
  changes presentation only and never changes document geometry.
- **Search** searches titles, tags, passage references and text content that is available
  locally. Results identify the note and the matching field.
- **Sort** supports Title, Created date and Modified date. Modified date is the default;
  ties use stable creation order so the library does not jump unpredictably.
- **Tags** are owner-created labels. Filtering by multiple tags uses an explicit mode
  shown in the filter bar; empty filters have a direct Clear action.
- **Swipe/context actions** may expose Rename, Tags, Duplicate, Move to Collection,
  Export and Delete. Delete requires confirmation and does not silently delete linked
  Scripture, conversations or collection folders.

### Library states

The library must specify and visually review first use, populated, filtered-empty, search
empty, offline, loading, restore-in-progress and recoverable-error states. An empty Notes
library offers **Create your first note** and a short explanation of the expandable canvas.

## Note canvas

The canvas is a document-coordinate workspace whose extent grows as content moves outward.
It is not an enormous pre-rendered bitmap and it does not reflow like a web page.

```text
┌───────────────────────────────────────────────────────────────────────┐
│ ‹ Notes   Love that gives          [Undo] [Redo] [Objects] [···]      │
├───────────────────────────────────────────────────────────────────────┤
│ [Select] [Text] [Draw] [Image] [Insert +] [Pan]       100% [−] [+]    │
│                                                                       │
│                 ┌───────────────┐                                     │
│                 │ typed thought │       handwritten mark              │
│                 └───────────────┘                 ╲                   │
│                    [quote card]           [image]  ─────              │
│                                                                       │
│                           expandable study surface                   │
└───────────────────────────────────────────────────────────────────────┘
```

The top bar belongs to the canvas and remains visually separate from the shared bottom
tab bar. It shows the note title and save status. The editing bar changes by mode, but the
user can always reach Undo, Redo, Objects and a way back to the library.

### Editing modes

| Mode | Pencil/touch behavior | Primary controls | Exit behavior |
| --- | --- | --- | --- |
| Select | Tap objects; drag selected objects; explicit multi-select | Object list, Group, Ungroup, order, Delete | Tap blank space or choose another mode |
| Text | Create or edit a text box with keyboard and standard text selection | Font role, size, alignment, lists, Done/Cancel | Commit or cancel the current text transaction |
| Draw | Pencil creates ink; native Pencil palette supplies tools; finger navigates according to validated gesture policy | Tool palette, color/width, eraser, undo | Completed strokes enter document history |
| Pan | Finger or Pencil navigation moves the viewport without moving objects | Zoom, Return to study, center selected object | Select or Draw |

The initial implementation should keep mode changes explicit. It must not infer whether a
finger drag means pan or move from ambiguous geometry. The native Pencil palette is a
platform tool surface; Sophia provides the surrounding mode, save, object and accessibility
context. Pencil Pro-specific squeeze or hover behavior is optional.

## Object model and insertion

Every object has a stable ID, document-space frame, z-order, accessibility label, creation
metadata and optional group membership. Objects remain editable after grouping.

| Object | Creation and editing rule | Default behavior |
| --- | --- | --- |
| Text box | Text mode or Insert → Text | Width resize reflows text; content editing is separate from moving |
| Ink | Draw mode with PencilKit | Strokes remain independently selectable where supported; no automatic word anchoring |
| Image | Insert → Photos/Files or paste | Preserve aspect ratio by default; show offline placeholder if source is unavailable |
| Scripture quote | Select Scripture → Save → Note Quote, or Insert → Quote | Source text/reference/translation are preserved; commentary is a separate editable field |
| Link card | Insert → Link or paste a URL | Editable title and URL; metadata failure produces a readable URL card |
| Table | Insert → Table | Cells are editable; table remains one object until a future decision supports cell grouping |
| Shape | Insert → Shape | Move and resize as one object; styling is deliberately restrained |
| List | Text formatting or Insert → List | Ordered and unordered list behavior follows normal text editing conventions |

The Insert menu groups content by purpose: **Writing**, **Study**, **Media** and
**Structure**. It must not present unsupported rich objects as if they already work. The
first implementation may stage object types behind explicit tickets while preserving the
same insertion vocabulary.

## Selection, grouping and stacking

- A visible object can be selected by tapping it or through the Objects panel.
- Multi-select is explicit. The Objects panel is the accessible fallback when overlapping
  ink, text and images make hit testing ambiguous.
- Group moves members as a unit while preserving each member’s relative position and ID.
- Ungroup restores independent selection without changing content or geometry.
- Initial grouping is flat; nested groups are deferred until a real study example proves
  they are needed.
- Bring Forward and Send Backward change visual order only. Accessibility reading order is
  separately defined and must not depend on z-order.
- Resize text and images as distinct operations. Group scaling and automatic ink scaling
  are deferred; ink must not be silently distorted by text reflow.
- Visual overlap never creates an implicit attachment between handwriting and text.

These rules carry forward from the [interaction proposal](canvas-interactions.md) and the
owner-approved grouping decision.

## Navigation, zoom and growth

- Pan and zoom change the viewport, not document coordinates or content undo history.
- Show the current zoom and provide a Return to study action that restores the note’s
  named origin or selected object.
- When content extends beyond the current bounds, grow the usable document region without
  shifting existing objects. Exact growth limits and viewport culling require native
  measurement.
- Rotation, keyboard appearance and a Scripture side panel change the viewport only.
  Existing objects remain at their saved document coordinates.
- The Objects panel can center an off-screen object and announce it to VoiceOver.
- The note canvas can be larger than the viewport; it must not promise unlimited memory or
  invisible content recovery.

## Passage links and collections

A note can link to one or more canonical passage ranges. A quote object preserves the
edition and exact source text; a passage link can point to a range without duplicating the
quote. From a verse hub, opening a linked note selects the relevant note object when that
object is known and otherwise opens the note at its last safe viewport.

Move to Collection changes membership only. It does not copy or relocate the note file.
Deleting a note requires a clear explanation of whether its collection memberships, quote
objects and external links will be removed as references or become missing targets.

## Saving, undo and recovery

The canvas reports a small status such as Saved, Saving or Needs attention. A visual update
is not evidence that the file write succeeded.

| Action | Undo boundary | Recovery requirement |
| --- | --- | --- |
| Move/group/ungroup | One completed transaction | Restore IDs, geometry and membership together |
| Text edit | Native text coalescing, committed on Done | Preserve committed text and recover interrupted draft when possible |
| Ink stroke | Completed PencilKit stroke transaction | Reopen the latest recoverable drawing revision |
| Image/link/table insertion | One insertion or edit transaction | Keep metadata and source reference; show a missing-source state honestly |
| Pan/zoom/selection | No document undo entry | Optionally restore viewport separately |

Autosave should occur after completed transactions and during safe background transitions.
Recovery must use a manifest/revision boundary so a failed metadata write cannot leave a
new drawing without its object record. Files export/import is a separate validation path;
neither is proven by a successful in-memory editor demo.

## Accessibility and premium quality gates

- VoiceOver can enter the library, identify title/tags/date, and activate a note.
- The canvas exposes an Objects panel with a deterministic reading order and actions for
  select, edit, move, group, ungroup, delete and center.
- Every essential Pencil gesture has a visible control or keyboard/accessibility action.
- Dynamic Type applies to library metadata, tool labels and text editing controls without
  hiding Undo, Done, Insert or Return to study.
- Draw mode announces the active tool and does not trap the user in an unlabelled canvas.
- Reduced motion removes ornamental zoom/selection animations while preserving state change.
- Light/dark appearance, portrait/landscape, keyboard, pointer/finger, long notes and
  offline images receive visual and interaction review.

## Proposed ownership map

```text
Features/Notes/
  Presentation/
    NotesLibraryScreen.swift
    NotesLibraryModel.swift
    NoteCanvasScreen.swift
    NoteCanvasToolbar.swift
    NoteObjectsPanel.swift
    NoteInsertMenu.swift
  Domain/
    NoteDocument.swift
    NoteObject.swift
    NoteLayout.swift
    NoteTag.swift
  Application/
    CreateNote.swift
    SaveNoteObject.swift
    GroupNoteObjects.swift
    LinkNoteToPassage.swift
  Infrastructure/
    NoteRepository.swift
    NoteMediaStore.swift
    PencilKitNoteBridge.swift
```

These names are boundaries for review, not a request to create empty folders. The canvas
bridge may use UIKit/PencilKit, but document rules remain testable without SwiftUI or
PencilKit. The library does not load raw files directly, and the object model does not call
the Companion provider.

## Acceptance scenarios for design review

1. Create a blank note from the Notes tab. The canvas opens immediately with a temporary
   title, plain background and Saved/Saving status.
2. Add a text box, Pencil handwriting and an image. Move each independently; no object
   moves because another object overlaps it.
3. Explicitly group the text and handwriting, move the group, ungroup it, and confirm IDs,
   content and relative geometry remain intact.
4. Switch between Select, Text, Draw and Pan. Each mode has clear behavior and an explicit
   exit; the native Pencil palette is available in Draw.
5. Zoom and pan far from the origin, use Return to study, then reopen the note. Document
   geometry and a useful viewport are preserved.
6. Insert a Scripture quote from a selected passage. The quote retains its translation and
   reference while commentary can be edited independently.
7. Tag a note, switch between Cards and List, sort by title and modified date, and search
   by title, tag and passage reference.
8. Open a note from a verse hub and return to Scripture. The source verse and note remain
   connected without duplicating the note.
9. Background and relaunch during a completed edit. The latest recoverable revision opens;
   a failed media or metadata source is identified instead of silently disappearing.
10. Change the note color, save and relaunch. The selected tint remains attached to that
    note while text, ink and rules retain readable contrast in light and dark appearances.
11. Use VoiceOver, larger text, keyboard and reduced motion. Library and canvas actions
    remain reachable without relying on precise Pencil gestures.

## Open decisions before implementation

- Exact library card preview policy and thumbnail generation cost.
- Whether tags are free text only or support a suggested/recent tag list.
- Exact object insertion menu and which rich objects are included in the first Notes slice.
- Native PencilKit lasso behavior versus the Objects panel as the initial selection fallback.
- Text editor formatting scope and whether tables/lists ship together or as separate slices.
- Canvas growth limits, viewport culling and maximum media size after native measurements.
- Autosave interval/revision retention and the user-facing recovery history affordance.
- PDF export scope and pagination policy; export is not implied by expandable canvas.

## SP-013 implementation scope — 2026-09-29

Owner requested M4 execution. The Notes library/editor now implements blank UUID notes,
card/list presentation, title/content/tag/reference search, one-tag filtering, title/date
sorting, recoverable deletion and Files backups. The native surface provides freely
positioned direct text, separate ink objects, local images, bounded tables, HTTP(S) link
cards, shapes, lists and Scripture quotes created through the verse hub. Object inspection
supplies explicit multi-selection, group/ungroup, center, move, size and stacking actions.
The source-text quote action currently uses WEB; licensed editions require separate
saved-quote and backup-export permission before the same action can be enabled.

One tag is selected at a time in this slice; multi-tag filtering remains a design extension.
Tables support up to 20 rows/10 columns, images are imported from Files, and shapes are
rounded rectangles. Lists insert a bullet/next number on Return. These bounds are visible
controls, not claims of a complete word processor. Native lasso edits strokes inside the
selected ink object; grouping moves the entire object. See the Notes contract for initial
size limits, recovery and exclusions. PDF export and nested/group scaling remain outside
this ticket. Physical acceptance is tracked in the SP-013 iPad guide.


### Canvas drawing stability correction — 2026-10-01

Keep the live PencilKit surface bounded to the editor viewport; synchronize its native
scroll/zoom coordinates with the document instead of allocating a document-sized drawable.
The Notes pen button uses the filled circle variant while tools are active, and hollow
when hidden, with an accessible state value. Hiding tools does not turn Pencil into text.

## v0.2.2 follow-up

Canvas Share exports an image with its longest side capped at 2,048 pixels. Object color
menus show actual color swatches and current selection. Delete uses red. The Pencil
selection tool taps objects or draws a loop around their centers; groups stay together.
A second tap on selected text enters text editing for character selection. Drawings are
batched into ink objects; the lasso selects the whole batch. See [SP-024](../../tickets/SP-024-v022-study-material-and-canvas-fixes.md)
for safety bounds, compatibility and physical acceptance.

v0.2.2 performance: Canvas keeps only nearby object views mounted, with a 256-point
margin and selected/edited objects pinned. The complete object model remains available for
selection and persistence. Whole-Canvas sharing temporarily mounts all content and awaits
image decoding. A bounded ink/image cache avoids repeated rendering after scrolling;
ImageIO import and displayed-image decoding use a serial background worker. Physical iPad
profiling and long drawing sessions remain acceptance gates.

## v0.3.0 SP-025 follow-up

Canvas Note options adds Selection (Objects/Strokes), New drawing region and Paste. Note
options and the prayer (…) menu follow the hold-menu states: Protect Note when it has no lock, and Lock Note plus Remove Note Protection when it is unlocked. A locked note’s hold menu offers Unlock Note only. A note filed in a locked collection, or in any subfolder beneath it at any depth, stays out of the Notes library until that collection is unlocked. The Pencil lasso chooses stroke editing; its tap/loop selects internal strokes across regions,
with a stroke palette for Color, Copy, Duplicate, Delete and Select drawing. Selected
strokes drag independently; whole objects retain the existing palette/group/resize behavior.
Continuous writing stays in the latest eligible topmost ink region without 64-stroke batches.
At explicit stroke/payload safety limits, additional ink spills into adjacent regions.

Large regions use bounded viewport-cropped rasters while vectors remain in the document.
Rejected ink is retained separately with Note options → Recover unsaved drawing, producing
a new Canvas note after validation; saved source content is unchanged. See the
[Notes contract](../data/notes-contract.md) for identity, recovery and downgrade details.
This is SP-025 implementation, separate from the planned Notes/Collections authentication locks.

## Journal glyph and Prayer stamp refinement — SP-040

Thriving uses the SF Symbols flower (`camera.macro`) consistently in picker and toolbar.
Unset Emotional state uses an outlined heart in the toolbar and Not set row; chosen
emotions retain face emoji. Answered prayers display a green ANSWERED stamp, Redirected
a yellow REDIRECTED stamp, in Rubber Stamp lettering, enlarged over the card text with stable per-note 1–15° tilt. Locked cards conceal the stamp. The prayer editor has no stamp. Waiting
shows no stamp. Stamps do not intercept input or modify persisted text/ink, and existing
status controls remain available. Physical appearance and accessibility acceptance
remain separate from simulator verification.

The stamp words are scalable PDF outlines generated from the locally licensed Rubber Stamp
font with `scripts/generate-prayer-stamps.swift`. This preserves the requested lettering
on iPadOS without silent system-font fallback or packaging the font file. The two
template image assets inherit green/yellow tint; accessibility exposes the status words.

Page notes also expose a Page status icon on the top editor toolbar, beside the other
editor controls. Its menu lists Unset, Drafting, Revising, Editing, Publishing and Closed
in that order. The icon reflects the chosen status, with an accessible label and value.
This control is absent on Canvas, Journal and Prayer; changing it autosaves the metadata.

## Owner card preview refinement — 2026-10-13

Unlocked Journal cards show Emotional State and Mental State together in one row,
with the existing state glyphs and Not set defaults. Unlocked Page cards show the
opening body text (two lines); Closed Pages replace it with an enlarged green
Rubber Stamp PUBLISHED mark with stable 1–15° tilt, matching prayer stamps. This is a local status mark,
not an external publishing action. Locked cards conceal all previews and stamps.

## Owner rubber stamp styling — 2026-10-13

All three marks now use Rubber Stamp lettering, enlarged to overlap card text,
with a deterministic per-note tilt from 1 through 15 degrees. Tilt stays stable
on redraw/reopen and status changes. Green/yellow status colors, access guards
and tap-through behavior remain. See [font provenance](stamp-font-provenance.md).

Stamps animate from a faint shadow through a dark impression to their status color
on Notes-tab activation, with no motion when Reduce Motion is enabled. A note opened
from Collections opens a full-screen shared editor over the preserved Collections navigation stack; Back returns to the
folder rather than switching to the Notes tab.

## Owner long-press status controls — 2026-10-13

Holding an active, accessible note adds type-specific status menus in Notes cards/list
and Collection note rows: Page Status, Prayer Status, or Emotional State and Mental
State. Existing choices, including Unset/Not set, remain available. Changes persist
without selecting the note or changing editor navigation. The command rechecks
locks, concealed collection ancestry, note kind and active state before committing.

## Shared note card presentation — 2026-10-13

Notes and Collection card mode now render the same NoteLibraryCard: note-selected
accent/top rule, note-kind glyph, title/type, creation and modification dates,
Page opening text/Published mark, Journal states, and Prayer stamps. The shared
stamp sequence runs on card appearance and active-tab entry, cancels while hidden
and respects Reduce Motion. Hosts retain their own selection, context actions and
navigation. Fixed 176pt size and Collection list mode remain. Locked notes conceal
previews and stamps in both hosts. No persistence or protection-policy changes.

## SP-044 record action consistency

Long press retains the complete action menu. Collection material lists and cards no longer
show a permanent ellipsis; swipe left reveals More/Delete where eligible. Notes
cards/lists gain the same swipe rail; Prayer updates reveal Edit/Delete. Rightward
swipe closes actions; no full-swipe commit. Existing confirmations and access
guards apply. Notes multiselect disables swipe. Accessibility Show/Hide actions
and Reduce Motion handling provide alternatives to gestures/settling animation.

SP-044 follow-up: only one record rail is open at a time. Swipe right on the record
body, tap its shifted body, or start vertical finger scrolling to close it. Opening
another record rail or switching tabs also dismisses it. Collection cards retain
the hold menu without a permanent ellipsis. Drag onset/settling are shortened;
record commands and confirmations remain unchanged.

SP-045: the held note menu (also swipe More) offers Duplicate Note for accessible
active notes. The copy is an independent unfiled note titled with `(Copy)`. Page
and Journal expose a chevron to collapse/re-expand Pencil, text-format and insertion
controls. Status, undo/redo and options remain visible; the local expanded preference
is shared between Page and Journal. Journal Type is a separate book-icon menu with
Diaristic Journal and Spiritual Journal, also available in held note status settings.

## SP-046 initial note titles

Points to Ponder → Explore → Turn into a Note opens the existing New note modal with
the question as its editable title. Gleaning → Turn into a Note uses
`Gleaning from "Book Chapter:Verse (Translation)"` and seeds reference, passage text
and insight content. Type/color selection and existing title/capacity limits apply.
Cancellation creates no note; source material remains saved.
