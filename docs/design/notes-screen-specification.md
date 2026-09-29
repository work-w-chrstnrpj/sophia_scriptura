# Notes Library and Expandable Canvas Specification

Status: design proposal for owner review; implementation is not authorized by this
document. This specification turns the accepted expandable-canvas direction into a
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
│ Notes                                      [Search] [Sort] [New Note]  │
│ [All] [Tagged] [Recent]                         [Cards ▣] [List ≡]   │
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

- **New Note** creates a blank note immediately, gives it a temporary title such as
  `Untitled Note`, and opens the canvas. The first title edit is optional; the user can
  begin writing without completing a form.
- **Cards** show title, one or two tags, modified date, linked passage summary when one
  exists, and a calm content preview. A preview is a rendering aid, not a second copy of
  note content.
- **List** shows the same metadata in a denser, accessible row layout. Switching views
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
10. Use VoiceOver, larger text, keyboard and reduced motion. Library and canvas actions
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
