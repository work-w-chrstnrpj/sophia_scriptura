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

## v0.3.0 SP-025 — compound Canvas ink

Canvas continues the topmost unlocked, ungrouped ink region until a real safety boundary,
not 64 strokes. An explicitly selected region can be extended below other objects; inserting
non-ink content establishes a new automatic region boundary. Note options → New drawing
region starts one deliberately. Region overflow at 10,000 strokes or 16 MiB creates adjacent
regions preserving ink and object z-order. Existing batches/groups are not consolidated.

Ink objects optionally persist `strokeIDs: [UUID]`, parallel to native PKDrawing strokes.
Legacy IDs are derived deterministically from object ID and stroke ordinal without changing
original bytes/frames. A changed region persists its IDs; duplicate/paste gets fresh IDs.
The live composition assigns unique creation-date tokens for ownership, including duplicate
legacy dates within/across objects. Transforms/recolor retain IDs; erasure removes IDs, and
fragments sharing one source token retain the parent ID for the first fragment and acquire
new IDs for subsequent fragments. Session history retains these values. The archive stays
v3 with an optional field: older builds can read drawings, but editing them there drops ID
metadata; future IDs are regenerated. No reset or destructive load-time migration occurs.

Drawing-edit mode selects internal references `(objectID, strokeID)` across regions. A
128-point grid indexes transformed stroke bounds, with a bounded-cell fallback for large
strokes. Candidate taps test sampled PencilKit geometry, width, transforms and masks; empty
region bounds do not block objects behind them. Lasso requires full containment of sampled
visible centerlines (3-point sampling), rather than intersecting a bounding rectangle. It
is geometric selection, not handwriting/word recognition or an exact private Freeform algorithm.
Index rebuilding follows changed scenes, undo/restoration and theme changes.

Object mode retains grouping, movement and resizing. Position locking prevents stroke
movement and automatic region extension, without acting as a privacy lock. Stroke palettes
provide recolor/copy/duplicate/delete and return to drawing selection; copied material is
pasted from Note options. Viewport-cropped ink rasters are snapped to 256-point boundaries,
with a 128-point margin, maximum 2,048-pixel dimensions and the existing cost-bounded cache.
Whole-Canvas sharing temporarily renders complete regions and excludes selection outlines.

If overall note limits reject a live drawing, the saved scene is restored and the rejected
native drawing is retained atomically as `rejected-ink-<note UUID>.drawing` in that Notes
repository. It is separately bounded to 128 MiB and validated on read, never silently inserted
into saved content or included in the normal Notes archive. Note options → Recover unsaved
drawing creates a new Canvas note; the source note stays unchanged. The recovery file is
removed only after successful save. Write failures retain the in-memory drawing and show an
error; no crash-durability claim applies when the recovery write fails. A Notes-only backup
therefore still needs successful recovery first. Existing archive, aggregate-media and note
count bounds remain enforced; physical sustained Pencil/performance acceptance remains open.

## Journal reflection fields

A Journal stores two optional values on `JournalContent`: `emotionalState` and `mentalState`. Either may be absent. Older journals decode with both empty, and an unrecognized stored name is ignored so the rest of the entry remains. Writing a journal that leaves both empty omits the keys. There is no schema change. Page and object edits keep the chosen values. Body undo does not revert them.

Emotional state uses Apple Journal’s State of Mind feelings (`HKStateOfMind.Label`) plus Neutral: Amazed, Amused, Angry, Anxious, Ashamed, Brave, Calm, Content, Disappointed, Discouraged, Disgusted, Embarrassed, Excited, Frustrated, Grateful, Guilty, Happy, Hopeless, Irritated, Jealous, Joyful, Lonely, Passionate, Peaceful, Proud, Relieved, Sad, Scared, Stressed, Surprised, Worried, Annoyed, Confident, Drained, Hopeful, Indifferent, Overwhelmed, Satisfied, and Neutral.

Mental state, from thriving through Neutral, then Challenged, then toward distress: Thriving, Confident, Content, At ease, Even-minded, Neutral, Challenged, Uncertain, Doubtful, Uneasy, Concerned, Worried, Overthinking, Pressured, Tense, Stressed, Anxious, Overstimulated, Ruminating, Overwhelmed, and Distressed. Each value keeps the owner’s short meaning. Challenged means “Facing something difficult and working through it.” Library cards show the chosen labels and still omit the journal body. Search includes the labels and the mental-state meaning.

## v0.3.0 whole-note protection

`NoteDocument.protectionID: UUID?` is additive, defaults to nil, and binds an app access lock to a device-only credential. It is separate from Canvas position locks and stroke IDs. Protected libraries persist schema 4 (accepted schemas 1–4); plain libraries retain schema 3. Existing atomic generations and paths are retained. Notes-only export and restoration require access to protected current records; pre-restore exports inspect their own bindings. A legacy restore retains current bindings for matching IDs. Restored foreign/missing credentials fail closed. Content remains unencrypted under the owner-selected v0.3.0 policy.

The complete access, privacy, lifecycle, backup and recovery contract is [item protection](../security/item-protection.md). A note whose collection is locked, including a note filed only in a nested subfolder at any depth, is omitted from the Notes library. Body undo does not change protection. Save/flush-before-conceal preserves accepted edits; locked metadata/body commands are denied while archive/delete continue working.
