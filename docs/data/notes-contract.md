# Notes content and recovery contract — SP-013

## Typed content — implemented 2026-10-01

Each `NoteDocument` stores shared UUID/title/tags/timestamps/deletion/paper metadata plus
one tagged `NoteContent`: `{kind: canvas, canvas: ...}` or `{kind: page, page: ...}`.
Unknown kinds are unsupported-format errors; two payloads in one content value are invalid.
Canvas owns an ordered object list, including local PencilKit bytes and framed drawings.
Page owns its flowing body, UTF-16 citations, inline image/table attachments, page width/
height and a single fixed PencilKit overlay. Page cannot store movable ink objects.

New Pages have no floating objects. `PageContent.legacyObjects` preserves positioned items
from existing v2 Pages without changing their geometry or silently converting their type.
Inline attachments use a U+FFFC character and UTF-16 offset; edits before them shift the
offset and deleting the character removes the attachment. They count toward the same
1,000-object limit as legacy items. Images/tables flow with text; Page ink never does.

Page body width is fixed at 680 points within a 1,200-point page. Height grows to the existing
12,000-point bound. Wider legacy pages retain their width. Canvas ink has optional `inkSize`
reference dimensions for rendering frame resizing; older drawing bytes and frames remain
unchanged on load. Drawing/erasing/lasso edits reconcile scene strokes by creation date back
into framed objects. Normal finger transforms use the same flat grouping as other objects.
Page ink never participates in selection, grouping or resizing.

Scripture visibility is a visible-by-default UserDefaults preference, outside the archive;
hiding the pane keeps the shared ReaderSession. A citation reveals it and navigates.
Metadata overhead is small relative to image/ink bytes; physical storage/memory capacity
has not been benchmarked. No data is duplicated into a second editor model.

Inline citations retain original quote text, edition, content revision, attribution and
canonical start/end verse. Body edits adjust UTF-16 ranges; overlapping edits remove the
citation link. Saved source metadata remains separate from editable body text. The owner
confirmed personal-noting permission for existing translations; the former WEB-only
restriction is superseded. Reader authorization still applies before capturing licensed
selections. No provider keys or full translation downloads enter Notes archives.

Links allow only HTTP(S). Canvas cards fetch LinkPresentation metadata on explicit insertion
or refresh, with a 12-second metadata timeout. Optional thumbnail bytes use the existing
payload field; they are decoded and validated like images, count toward all media limits,
and are cached/exported offline. Thumbnail imports are downsampled to 1,024 pixels. A
missing preview retains the domain/URL card. Page links remain text, without preview fetches.
Optional `shape` and `tint` enums preserve decoding of earlier v3 objects with missing styles.
Object fields `monospaced`, `positionLocked`, and `details` decode missing values as
`false`, `false`, and empty text, preserving existing objects across the v0.2.0 upgrade.
Audio objects require v0.2.0; older builds do not recognize that object kind.
Dotted paper is an additional paper value. Stickers use editable emoji text; tables retain
the 20 × 10 bound. Page and Journal bodies may store optional character spans (bold, italic,
underline, strikethrough, and title/heading/subheading/monospaced). Empty spans are omitted
from the archive. Older notes decode with plain text. Audio attachments use the same inline
object path as images; tapping one plays it. System sticker integration remains excluded.
Neutral black/white ink resolves to the current theme for presentation. Opening or changing
theme does not rewrite original drawing bytes; unchanged Canvas strokes retain their
original payloads through scene reconciliation. Subsequent drawing edits may persist a
canonical black neutral color. PencilKit itself adapts that neutral ink on display; raster
previews run under the selected light/dark traits. Pre-resolving to white before PencilKit
rendering is forbidden because it causes double inversion. Chromatic ink is unchanged.

## Compatibility and generation storage

Snapshot schema v3 writes typed content. v1/v2 notes with a `page` decode as Page;
object-only notes decode as Canvas, preserving IDs, frames and local drawing bytes.
Opening a note does not convert it or dirty the library. Before publishing over a legacy
generation, retain its exact bytes as `before-note-types.notes`. Cleanup never removes that
file or the earlier `before-study-page.notes`. Unknown schemas fail visibly rather than
being interpreted as empty notes. No Canvas/Page conversion command is provided.

All commits validate and checksum the complete snapshot before publishing pointers.
Current/previous/pre-restore generations remain. Backup/export covers Notes only and
includes quotations, ink and images; it is neither PDF nor full-app backup. Restore
validates input first and retains pre-restore data. Failed writes retain dirty state and
Retry. Drawing validation checks decoding, finite bounds and capacity, rather than
rejecting normal PencilKit stroke bounds for extending outside a former handwriting box.

Safety bounds: 200 notes, 1,000 combined objects/inline attachments per note, 100,000 body characters, 500 citations,
20,000 characters/floating text, 16 MiB/asset, 10,000 strokes/drawing, about 42 MiB aggregate
media and 128 MiB serialized archive. Actual page fit can constrain body length earlier.
These are explicit limits, not measured physical-device capacity claims.
History retains changed object values and page states under an 80-entry/24-MiB budget.
Swift value storage shares unchanged ink bytes; large edits can shorten available history.

See [study-page design](../design/notes-screen-specification.md) and
[physical acceptance](../testing/sp013-ipad-guide.md). No SP-006 fixture migration occurs.


The live PencilKit canvas matches the note scroll view's zoom, content size, inset, and
offset. While the Pencil is down, that sync is frozen so the in-progress stroke is not
stretched by scroll updates; sync resumes when the stroke ends. Persisted ink and framed
Canvas objects remain in document coordinates. Page and Journal stay at 100% scale:
vertical scrolling remains, horizontal scrolling is available only while the Scripture
pane is open, and pinch zoom stays on Canvas. No schema change or migration.

## v0.2.2 — Canvas capacity and selection

New unselected Canvas strokes reuse the latest unlocked, ungrouped ink object up to 64
strokes. Explicitly selected ink can be extended. Prior objects retain IDs, payloads and
geometry. The scene cache is invalidated by ink-object changes, surface restoration or theme
changes. A rejected edit restores the saved scene to avoid repeat alerts on refresh.
Pencil selection encloses object centers and includes explicit group members; it selects
whole ink objects. Page/Journal/Prayer retain one 16 MiB ink payload. Scripture uses its
separate 32 MiB drawing limit. No storage migration occurs; older builds may reject notes
exceeding the previous 200-object bound.
