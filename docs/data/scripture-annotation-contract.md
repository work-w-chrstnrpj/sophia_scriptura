# Scripture annotation data and recovery contract — SP-005

Decision date: 2026-09-29. Status: implemented in SP-012; automated verification recorded in its ticket,
actual-reader physical acceptance pending. Complements the [reader contract](scripture-reader-contract.md)
and [SP-008 evidence](../../tickets/SP-008-scripture-layout-validation.md).

## Ownership and identity

Use a separate local annotation repository; it must not replace the bundled Scripture
SQLite, reader SwiftData state, licensed-content store, or disposable experiment data.
Domain owns identities and validation; Infrastructure owns files, integrity and commits;
the Scripture feature owns PencilKit rendering and input. No runtime backend is involved.

Each chapter/layout group records schema version, stable UUID, edition ID, content
revision, reference-system ID, USFM book and chapter. Each layer has a stable UUID,
name, ordering, created/updated timestamps, deletion tombstone and drawing revision.
Layer numbers and names are never storage identities. Selection is separate from mode;
only one layer is visible. Empty groups start without ink; creating a layer is explicit.
Never migrate or copy ink across editions implicitly. No experiment-data migration.

## Layer-owned spatial layout

Capture a layout descriptor with each new layer: renderer/layout
algorithm version, exact font identifiers and resource versions, font sizes/metrics,
paragraph spacing, text-column bounds, chapter dimensions and reserved margin bounds.
Use the current reader appearance for that layer; dimensions are determined and
recorded by the renderer, not copied blindly from the 800-point SP-008 experiment.
Store a deterministic layout signature including source revision and actual block/line
geometry. Persist numeric geometry without Scripture text or attributed-text payloads.
Validate finite positive dimensions and valid chapter/source identities before use.

Rotation, window/panel resizing, margin expansion/cropping and zoom change viewport
transforms only. Read Hidden uses the ordinary reader while the drawing surface stays
mounted, preserving its undo history. New layers capture the current preset/theme,
typeface and size step. Selecting a layer restores those settings. A deliberate font or
size change in Read Visible or Draw recaptures only that selected layer's layout; existing drawing bytes remain
unchanged, and the UI warns that marks may need adjustment. Other layers retain their
own layout and appearance. Read Hidden keeps independent ordinary-reader font changes;
returning to annotation restores the selected layer's appearance. Group layouts remain as a decoding fallback for older
backups; layer layouts and appearance metadata are optional only for that compatibility.
If the exact content, font resources or measured signature cannot be reproduced, retain
ink and show an unavailable-layout state; do not overlay it on approximate text. Missing
or locked licensed content never deletes ink or triggers a provider download.

## Versioned local commits and saving

Store under Application Support/Annotations, using generated UUID-only relative paths.
A versioned root manifest references immutable generation directories containing group
metadata, layout descriptors and native PKDrawing payloads, with byte counts and SHA-256
checksums. The repository implements this format; root pointers also checksum the generation manifest.

Serialize repository writes. Write a complete next generation to staging, validate all
metadata/checksums and drawing decoding, publish its immutable directory, then atomically
replace the root manifest pointer. Keep the previous validated manifest/generation for
fallback. No committed metadata may reference an absent or partially written drawing.
After interruption, reopen either the previous or new complete generation. Unreferenced
staging/generations may be cleaned only after a validated commit and never while pinned
by export or recovery. Do not claim power-loss durability from atomic rename alone.

Autosave after completed drawing changes with a short debounce; flush on layer/mode,
chapter, edition or tab transitions and backgrounding. During a stroke, defer transitions
until PencilKit finishes and captures the final drawing. Serialize revisions so a stale
save cannot overwrite newer ink. Show saving/saved/failed state; a failed save keeps dirty
ink in memory, provides Retry and blocks navigation that would discard it. Abrupt process
termination can lose the unsaved active stroke; completed acknowledged saves must reopen.
Keep one independent undo history per loaded layer; clear that layer's history on reopen
and disclose this. Undo/redo must never apply edits to another layer.

Validate the root, referenced files and drawing decoding before publishing restored state.
On damage, offer the last validated generation with a visible recovery notice and retain
the damaged files for diagnosis/recovery. If both generations fail, report unavailable;
never replace them with a fresh empty store silently. Reject unknown schema versions
without rewriting files. Future migrations must stage, validate and retain their source.

## Deletion and recovery

Deleting a layer creates a persisted tombstone and removes it from normal selection;
its drawing and layout remain recoverable through a Recently Deleted action. Restore
keeps original UUIDs. No automatic expiry or permanent purge in SP-012. A deleted selected
layer selects the next live layer or enters Read Hidden if none remain. Clear drawing is
an undoable drawing edit, distinct from deleting its layer. Confirm deletion in the UI.

## Files export and restore

SP-012 provides a versioned ink-only Files archive: manifest, identity/layout metadata,
live and deleted layers, native drawings and checksums. Exclude Scripture text, licensed
payloads, provider responses, credentials, Keychain state, and Notes/Collections fixtures.
Reference unavailable editions by identity only; restore never fetches or unlocks them.
Warn that this is an annotation backup, not a full-app backup. User handwriting is user
content and may contain private material; exports occur only through explicit Files actions.

Export pins one validated generation. Restore validates in staging: archive/schema,
entry counts and total sizes, UUID/path uniqueness, no traversal/absolute paths/symlinks,
checksums, finite geometry, relationships and decodable drawings. Publish only after all
checks pass. Supported limits: 128 groups, 256 layers/group, 32 MiB/drawing, 64 MiB combined drawing
bytes, 128 MiB archive and 200,000-point chapter height. Archive entries use UUIDs, not
user-supplied filesystem paths; malformed IDs are rejected.
Unsupported, oversized, corrupt or cancelled imports leave the live store untouched.

Initial restore is an explicit replacement of the annotation store, not a merge. Confirm
replacement, first retain a validated pre-restore recovery generation, then commit the
import atomically. Preserve unavailable layouts as unavailable; do not remap editions.
Cancellation or backup failure aborts replacement. The operation does not touch reader
preferences, licensed authorization or other study data.

## Required evidence (results recorded in SP-012)

| ID | Check | Required result |
| --- | --- | --- |
| ANN-01 | Multiple groups/editions/layers with same names | UUID/source isolation, no leakage |
| ANN-02 | Rotation/resize/zoom/surrounding space/font reading-view round trip | Original coordinates and ink bytes preserved |
| ANN-03 | Inject interruption at every commit boundary; stale concurrent save | Complete old/new generation; latest revision wins |
| ANN-04 | Corrupt current manifest/payload; corrupt fallback too | Visible fallback or retained unavailable data |
| ANN-05 | Active stroke, transition, autosave failure/retry, relaunch | No discarded dirty ink; acknowledged save reopens |
| ANN-06 | Delete/restore/undo/switch layers/reopen | Tombstone recovery; no cross-layer undo |
| ANN-07 | Export/replace/restore including unavailable edition and deleted layer | Drawing bytes/IDs/layouts preserved; no restricted text/secrets |
| ANN-08 | Corrupt/unknown/oversized/traversal archive; cancel restore | Existing data unchanged; no out-of-root writes |
| ANN-09 | Longest bundled chapter and dense ink on physical iPad | Record sample size, timings/memory and usable Pencil/scroll behavior |

ANN-01 and ANN-03/04/06/07/08 require automated fixtures. ANN-02/05/09 also require actual
reader/iPad observations; SP-008 is input, not a substitute. VoiceOver remains waived for
this owner-directed M3 work and is never marked passed. Notes, media, collection membership,
full-app archives and their migrations remain separate SP-005 slices.

## Implementation details — 2026-09-29

`AnnotationFileRepository` uses `current.json`, `previous.json`, optional `pre-restore.json`,
UUID generation directories, `manifest.json` and UUID `.drawing` files. The annotation-only
Files archive is JSON with base64 PKDrawing bytes, metadata and checksums; no zip paths or
symlinks are imported. Whole-store writes are serialized in an actor; revision conflicts
reject stale writers. Each loaded canvas has a separate UndoManager. Saved layout dimensions
for the original v1 layout came from a 640–960-point viewport with a side column. The
owner-revised v2 layout uses the normal reader's centered column width plus 200 points
of blank space on every side. No rules are drawn. v1 signatures and drawings remain
supported without conversion; new layers use v2 if the selected group is v1. New layer
layouts are stored on the layer, with the group descriptor retained for legacy decoding.
Colors and viewport cropping do not enter layout identity.

After a validated commit, cleanup removes unreferenced UUID generations while retaining
current/previous/pre-restore generations. Corruption recovery disables automatic cleanup
and retains damaged manifests/generations. Explicit backup repair of a fully damaged store
first copies the original store to a sibling `Annotation-recovery-UUID` directory; an
unsupported schema is never overwritten. No automatic permanent deletion is provided.

Backup restore also invalidates the previous canvas generation before publishing imported
ink; the old surface cannot flush its drawing over restored data. This has an executable
regression test in `AnnotationTests`.

## Owner interaction correction — 2026-09-29

Active renderer identifier: `continuous-textkit1-surround-v2`; schema version remains 1
because the layout discriminator distinguishes preserved v1/v2 geometry. New layout
width equals text width + twice the inset; height includes the same top/bottom inset.
`marginStart` is retained for v1 compatibility and records the right text boundary in v2.
Repository validation accepts both geometry contracts. The native palette minimizes on
stroke begin, can be expanded from the compact affordance, and is not expanded by autosave completion.
Drawing remains enabled while saves run; a newer edit stays dirty until its revision saves.
