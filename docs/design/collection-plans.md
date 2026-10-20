# Collection Plans — proposed feature contract

Status: **SP-049 implemented and simulator verified; SP-050–052 ready and unselected**.
Implementation began 2026-10-19; simulator verification passed 2026-10-20; physical acceptance remains open. Selected [D1–D5 implementation contract](../data/collection-plans-contract.md) settles schemas,
transactions, access bindings and reader lifecycle. SP-049 now has local authoring/foundation code; playback/Pencil/tools remain unimplemented.
Milestone: proposed post-baseline **Collection Plans** outcome; no release/version assigned.
Review: [source-grounded gaps and resolutions](collection-plans-review.md).
Canonical technical intent: [TDD](../tdd/tdd.md#collection-plans--planning-baseline-sp-049052).
Delivery: [SP-049](../../tickets/SP-049-plan-model-and-authoring.md) →
[SP-050](../../tickets/SP-050-plan-reading-and-progress.md) →
[SP-051](../../tickets/SP-051-plan-annotations-and-study-tools.md) →
[SP-052](../../tickets/SP-052-plan-integrated-acceptance.md).

## Decisions and recommendation status

Owner requirements: Plan is a new Collections material; configurable section labels;
ordered verses/ranges/whole chapters, notes and links; focused Scripture reading;
Previous/Next, background music, Add Note, Add Link and Companion; no tab navigation;
manage/reset the whole Plan or sections/items.

Owner confirmed on 2026-10-19:

- Notes and links successfully added while reading start **checked**.
- Pause at a **section summary**, rather than automatically starting the next section.
- Allow Pencil annotations using a **new layer named after the Plan**.

The remaining behavior uses selected planning defaults under the owner's request to resolve
the design. Explicit owner product decisions remain distinguished above. D1–D5 overrides
earlier open recommendations. Design readiness does not authorize app edits.

## Structure, identity and validation

Plan: stable UUID, nonempty editable title (**80-character limit**, matching
the existing annotation layer-name validator), optional description, preferred edition/reference-system identity,
ordered sections, archive/Trash timestamps and revision. Use existing Collections
membership semantics: one Plan can be filed in multiple folders, with one shared progress
record. No Folder includes Plans without active folder membership under existing rules.

Section: stable UUID, ordered items, optional custom title. Plan-level prefix defaults
to Day; allow Section, Session or custom text. Untitled sections display prefix plus
current ordinal; reordering renumbers the display without changing identity/progress.

Item: stable UUID, tagged payload (Scripture reference, note ID or saved-link ID),
completion timestamp and creation origin (editor assignment or reading reflection).
Store canonical reference-system/book/chapter/verse identities, not chapter text.
Whole chapter is an explicit reference intent resolved through the active edition.
Multi-chapter input becomes ordered chapter-sized items; disjoint selections become
separate items. Validate book/chapter/verse bounds; never fabricate a verse mapping.
Repeated references/items are allowed and have independent completion identities.

Save empty Plans/sections as drafts. Start is unavailable until a playable item exists;
empty sections are labelled Empty and excluded from completion totals, never falsely
celebrated as completed reading. A Plan is complete only with at least one item and all
items checked. Unknown tags, duplicate IDs and invalid references fail validation with
original data preserved. Selected bounds: 100 retained Plans, 200 sections and 2,000 items per Plan, subject to
the existing 8 MiB Collections file ceiling. Verify these bounds during implementation;
capacity failures must be explicit rather than silently expanding limits.

## Authoring and organization

Collections → Add Study Material → New Plan opens title/description, section-label and
preferred-translation controls, followed by an ordered outline editor. Support selecting
multiple Scripture entries, whole chapters, existing notes/links and newly created notes/links.
Existing material is referenced, not cloned; new material uses the owning feature's workflow.
Editor-created assignments start unchecked, including notes and links.

Support edit, add, remove, reorder and move items between sections; rename/reorder/duplicate
sections; duplicate a Plan; manual checkbox changes; reset item/section/all. Section copies
get new item IDs and unchecked progress. Plan copies get new Plan/section/item IDs, unchecked
progress and no ink bindings; notes/links remain shared references. Folder duplication
follows the existing reuse-membership semantics and does not silently clone a Plan.

Removing a reference does not delete the referenced material. Plan deletion uses recoverable
Trash and the normal retention policy; restore retains memberships/progress. Reset asks for
confirmation with its exact scope, clears completion and scoped resume state, and retains
all notes, links and ink. Standalone Plan delete never cascades into those feature stores.
Permanent delete is separately confirmed. Editing content preserves completion for retained
item IDs; replacing an item's reference/target makes that item unfinished. Structural edits
recompute derived totals and preserve other completed items.

## Reading workspace and progress state machine

Start / Resume Plan opens a dedicated fullscreen workspace; one active Plan at a time.
Top: ×, title, section, active reference and item count. The progress control opens an
outline with checkboxes and section navigation. Hide and disable underlying tab navigation,
including accessibility focus and programmatic routes from embedded tools.
Bottom icons: Previous, Next, background-music Play/Pause, Add Note, Add Link, Companion.
Use accessible action labels, generous touch targets and disabled-state explanations.
On the final item expose the semantic action Finish section/Finish Plan even if the visual
control remains an icon. Restore the prior tab/reader/annotation presentation on exit.

States: inactive, loading item, presenting item, saving transition, section summary,
Plan summary, unavailable/error. Serialize commands; do not accept repeated Next actions
while a save/navigation is pending. Async results carry session/Plan/item/revision identity;
ignore stale results after exit, reset, edit, relock or another launch.

| Action | Recommended durable result |
| --- | --- |
| Next on unfinished item | Flush accepted edits/ink; save completion and next cursor, then navigate |
| Next on completed item | Advance without altering its original completion timestamp |
| Previous | Navigate backward without changing checks; disabled at first item |
| Outline jump | Navigate without completing intervening items |
| Checkbox | Explicitly check/uncheck only that item; do not advance |
| Section boundary | Persist summary state; require Continue to enter the next nonempty section |
| Last item | Persist Plan summary; offer Review or Exit; restarting requires explicit Reset |
| × or background/relaunch | Save current position and pending accepted work; do not auto-check the item |

Persist cursor by item UUID plus reader position, and persist summary state so relaunch does
not bypass the pause. A jump/reset may leave earlier items unfinished; a section summary
must say how many remain rather than claim section completion. Final navigation with gaps
shows a review summary and Go to first unfinished; only all-checked Plans get completion.
If the current item is removed, choose the next unfinished surviving item in order, then
previous unfinished, then a review summary. Reset the active section/whole Plan moves to
its first item. Reset outside the current section keeps the current cursor.

Opening or scrolling a note/link never auto-completes it; Next or an explicit checkbox does.
External destinations open explicitly through the normal validated link workflow; returning
preserves the Plan workspace. No automatic web requests merely to complete a link.

## Scripture focus, translations and ink geometry

Reuse the current reader/content authorization pipeline. Active verses get normal reading
contrast plus a subtle focus marker; surrounding chapter text is muted but readable.
Provide Show context without changing checks. Preserve line wrapping, fonts, columns and
chapter geometry while changing colors: focus styling must not displace Pencil ink.
Focus, text selection and narration emphasis are distinct render states. Retain Copy,
Save and contextual Ask with existing rights checks. Do not allow chapter swipes to
silently navigate outside the current assignment; Prev/Next control Plan progression.

Preferred edition is Plan-wide, with an explicit session override; changing it does not
change completion or copy annotations. Resolve via canonical identities and existing
reference mappings. For unavailable/expired/restricted text show Retry, explicit eligible
edition choice, or outline navigation. Do not silently substitute text, fetch/download,
authorize a provider or mark an unreadable item complete. References remain intact.
The owner can explicitly mark an unavailable assignment complete from the outline.

## Plan-named Pencil layers

Existing ink groups are edition/revision/reference-system/book/chapter scoped. Therefore
create a dedicated layer lazily on the first Draw action in each visited source group,
with the exact current Plan title as its display name. Re-entering the same chapter for
the same Plan reuses that bound layer, including across sections. Separate Plans with the
same title have separate layer UUIDs. Names never identify storage or select an existing
unrelated layer. Ordinary preexisting annotation layers remain unchanged.

Persist Plan ownership and copied access on annotation v2 layers, indexed by Plan UUID
and exact group source; the annotation owner is authoritative for layer UUIDs. D1/D2
specifies encoding and idempotent operation tags; Plans have no competing binding list. Renaming a Plan updates managed layer labels
through an idempotent rename intent; retry interrupted updates without losing ink or
creating extra layers. Managed labels follow the Plan title; arbitrary independent rename
requires an explicit detach action outside first-version scope. Plan progress reset never
clears, deletes or replaces a layer. Plan duplication starts with no bindings/ink copies.

Changing translation creates/reuses a separate source-bound layer; never remap/copy ink
implicitly. Deleted/damaged/missing layers show a recovery state; restore or explicitly
create a replacement instead of silently discarding recoverable drawings. Flush completed
strokes before any transition; defer navigation during a live stroke. Preserve per-layer
undo, viewport/layout ownership and appearance rules from the annotation contract.

Plan Trash hides Plan playback but retains its ink. Permanent Plan deletion retains ink
as ordinary annotation layers with their last labels, using an explicit guarded detach
that preserves access restrictions. Reset and removal must never purge ink. Keep enough
association/access metadata for interrupted deletion/recovery; do not drop protection when
a Plan disappears. Bound layers obey source Collection access at every entry point,
including ordinary reader layer pickers and annotation export. This is an extension to
current annotation behavior, not an existing guarantee. Do not ship a route that exposes
protected Plan labels/ink through an unguarded annotation picker or archive.

## Notes, links, Companion and music

Add Note: serially present existing note-kind creation → editor → return. Anchor to the
current passage through existing citation/quote authorization, with an editable title.
Successful accepted note save inserts one checked reference immediately after the current
item, then returns to that item/position; the passage is not marked complete. Add Link
uses the same position/completion rule after URL validation and successful owner save.
Cancel creates no Plan item. Multiple reflections retain creation order after the passage.

The two stores cannot be assumed atomic. Use an idempotent pending attachment operation:
if material saves but Plan attachment fails, preserve it in its owning library, show Retry
attachment, and reuse its ID on retry. Never delete a saved note as rollback. If Plan access
expires during creation, conceal the workspace, retain permitted saved material and require
revalidation before attachment. Flush on return/exit, and show failures without dismissing
accepted unsaved editor input.

Companion is a sheet/side panel inside the workspace with the normal provider/model/preset,
streaming and error handling. Selected text or current passage uses existing context/rights
review; no automatic upload of the whole Plan, linked notes or ink. Closing/retrying chat
preserves progress and viewport. Conversations stay owned by Companion, outside the item
sequence. Existing controls that normally expand into the Companion tab must adapt to this
workspace. Protected material remains excluded by the current AI disclosure policy.

Music controls the existing background-music session; absent tracks show the existing
chooser/empty state. No duplicate audio engine or automatic narration playback. Enter/exit
does not auto-start/stop shared music. No automatic Activity timer or reading records;
manual existing Activity sessions remain independent. Existing AO narration remains an
independent audio capability; no automatic advance from narration completion in this scope.

## Access, backups and compatibility

All Plan commands revalidate current folder/ancestor protection and existing membership
visibility rules. Do not copy private note previews into Plan data. Shared notes need their
own Notes grants. Relock synchronously captures accepted native buffers and immediately conceals note,
Plan and ink routes; disk retries continue without keeping private UI visible.
Late async results cannot reopen them. Removing/changing protected membership must not
silently deprotect retained ink; retain a durable binding or require guarded detachment.
Unknown protection bindings fail closed. App access locks remain distinct from encryption.

Recommended storage: Plans and their progress live in the existing Collections checked
generations, with domain values extracted into a focused proposed Core/Plans module and
commands in a dedicated Plan owner. Avoid putting playback/state-machine logic into
CollectionsStore or RootTabView. Annotations keep drawing bytes and Notes keep documents.
D1 selects Collections 4, Notes 5, annotations 2 and full-backup 2 with gated wrapper/
pointer versions. Legacy payloads load with no Plans, and older apps reject required data. No reset/destructive migration.

Extend all-data export/restore validation from the first data-bearing ticket. Include Plan
IDs/order/progress/cursor plus annotation associations and ink through
the annotation archive. Export only inert reconciliation records for incomplete attachments;
exclude executable retry journals. Restore never replays create/send/rename/detach commands. Exclude Scripture text and provider keys. Preflight schemas, graph
references and category access before mutations; retain pre-restore copies. Existing full
restore is sequential, so do not claim cross-store atomicity: specify recovery for interrupted
restore and reconcile missing references without silently generating completion or layers.
Legacy and annotations-only backups retain drawing recovery even without Plan records;
source ownership metadata must fail closed if required access cannot be reconstructed.

## First-version boundary and acceptance

Include authoring, all four item kinds, focus/progress/resume/summaries, Pencil layers,
study tools, lifecycle, schema compatibility and backups. Exclude calendar dates, schedules,
notifications, streaks, imported/public Plans, sharing formats, AI Plan generation, automatic
narration advancement, automatic Activity metrics and new release/install work.

Each implementation ticket requires its own source review, scoped tests and documentation.
Final physical acceptance includes real Pencil alignment/palm rejection/undo, portrait and
landscape, Split View, Dynamic Type, VoiceOver, Reduce Motion, light/dark themes, relocking,
background/relaunch and failure recovery. Simulator/build/install evidence does not close
those gates. SP-052 owns integrated acceptance, not a repeat implementation feature.

## Review addendum — execution contracts (2026-10-19)

These refinements supersede ambiguous wording above and are now resolved by D1–D5.
They describe selected future contracts, not runtime changes. Owner-confirmed checked reflections, section pauses and Plan-named ink are retained.

### One writer and observable durability

CollectionsStore remains the **only writer** to Collections generations. A dedicated Plan
command service builds typed intents; CollectionsStore reduces them against its latest
committed snapshot through the D2 submit API; it must not own a second mutable snapshot,
revision counter, repository connection or queue. Plan, link, folder, Companion projection
and Sophy commands share this boundary. Preserve unrelated concurrent edits across awaits;
commit results identify the intent/item/revision, rather than use global notice strings.
A rejected transaction must not roll back another command's successful work.

Existing Collections flush only waits for a queue whose errors become notice text, and
NoteCreatorSheet returns a created ID before durable save. Neither is a commit receipt.
Add typed awaited committed/rejected/uncertain results where Plan correctness needs them.
Stage uncommitted Plan edits outside the published committed projection; hold Plan UI dirty
state on failure. Do not rewrite unrelated command behavior as part of this scope.

Persist completion and next cursor/summary in one Collections transaction **after** source
buffers commit. If loading the next target subsequently fails, the previous item's check
remains saved; Retry only reloads that target. Distinguish save failure (no check committed)
from load failure (check already committed). A crash cannot infer a check from the cursor.

### Reader and shell ownership

Use the current reader/content pipeline with an explicit scoped Plan reading context:
route position writes to Plan progress while leaving the ordinary ReaderStateRepository
location unchanged. Do not create a second repository-backed ReaderSession or bind two
interactive surfaces to the same AnnotationSession/native flush/undo callbacks. Save/restore
transient selection, appearance, edition and active annotation selection with an ownership
token; do not replay an obsolete snapshot over later legitimate settings or source changes.
Existing layer-selected appearance rules still apply inside the scoped context.

Root owns an exclusive workspace route (normal/Plan/meditation), plus at most one embedded
tool destination. Before Plan entry finish pending saves and pause active Scripture narration
without auto-resuming it on exit; its shared reader binding must not scroll the Plan. Music
continues through its current owner. Reject a competing meditation/Plan launch with guidance.
Defer Activity deep links and other tab-opening routes until explicit Plan exit; do not lose
an active Activity timer. Adapt Sophy source/quiz jumps, Companion expand/open-note and Notes
Scripture-pane navigation: stay embedded, or require Exit Plan first. Suppress duplicate
Sophy/music/Activity chrome and scope keyboard/accessibility focus to the workspace.
Set Notes/annotations active by workspace ownership and scene phase, not just tab selection.
Shared Companion has one selected conversation/draft/stream owner: an active unrelated stream
is preserved, and opening contextual chat cannot silently replace or send its draft.

### Limits, source revisions and protected generations

Keep the existing annotation ceilings (128 groups total including retained groups; 256
layers per group including tombstones; 32 MiB per drawing; 64 MiB combined drawings) for
this scope. The selected 2,000-item Plan capacity is a reference capacity, not a promise of
ink in every chapter. Check capacity before first Draw, show which limit was reached, and
allow reading/progress to continue. Never evict existing ink or silently raise limits.
Use the same trimmed nonempty, at-most-80-Swift-Character title for Plan creation/rename
and exact managed layer labels, including Unicode boundary tests. Show the bound title in
layer information when same-name layers exist; UUIDs remain the only identities.

When content revision/layout no longer matches, retain the old layer as unavailable and
require explicit Create layer for current source; never draw old ink over changed text.
A replacement gets a new binding for that exact source; old bindings/drawings survive for
recovery. Plan-managed layer rename/delete controls route through the managed owner, not
unrestricted ordinary-layer commands. Existing non-Plan layer behavior remains unchanged.

New required Plan protection/association metadata must be understood or rejected in **all**
annotation snapshots, archives, generation readers and recovery paths. Merely adding optional
fields to schema 1 lets older apps ignore them. Use D1's sticky format activation/version gates and protected current/previous
generations; no fallback to an earlier unprotected generation. Plan purge must durably detach/sanitize its
incomplete operations without erasing the retained ink's protection binding. Missing owner
records are unavailable/locked, never evidence that a layer is public. Backup graph checks
must accept deliberate missing/deleted material and unavailable sources as recoverable
states, while rejecting structurally invalid IDs, cycles or cross-owner substitutions.

### Linked-material lifecycle and privacy

For a Plan filed in several folders, any locked membership/ancestor conceals its projections
and commands, consistent with existing note concealment. Referencing a note also requires
its own Notes grant and its existing Collections access; a Plan reference is not a grant.
Use D3 StudyAccessRequirements on Plan-derived ink, retaining the per-domain credential
union across moves/unfile/purge; explicitly authenticated management is needed to remove it.
Do not leave protection dependent solely on a deletable folder UUID.

New reading reflections inherit accessible Plan folder memberships before being advertised
as attached; do not unexpectedly add an existing note/link to more folders merely because
it is referenced. If a protected Plan's note survives an attachment failure, it must retain
an equivalent access binding/concealment in Notes, not appear publicly in No Folder. D2/D3 specifies the typed privacy-preserving creation/filing operation and
recovery when one owner commits before the other. Creation succeeds durably before its Plan checkbox is published.

A target renamed/edited keeps its Plan item ID/check and resolves its current accessible
title on demand. Target replacement resets the check. Missing/archived/trashed notes or
permanently deleted links leave an unavailable item with Replace/Remove or eligible Restore;
do not invalidate the entire Plan/archive or silently delete/complete that step. Existing
saved-link deletion is permanent, so Restore is offered only when a recoverable target exists.
Settings bulk deletion and retention cleanup must account for Plan and ink dependencies.
No Plan-to-Plan nesting or conversation items are introduced.

After creating a checked reflection, remain on the current item. Next traverses the next
**ordered** item, including already checked reflections; outline offers deliberate jumps.
Previously checked assigned notes/links require no second check. If all items were checked
manually, Start offers Review; Reset and start again is separate. Save the active section
explicitly for summaries. Add Note/Link is disabled on summaries; while viewing a non-Scripture
item it creates an unanchored reflection, unless the user explicitly chooses a reference.
Never attach an unrelated stale chapter from the ordinary reader. Section/Plan archival or
Trash during playback exits/conceals that workspace after accepted buffers are captured.

### Backup and recovery ordering

Before export/restore, freeze Plan mutations and flush committed generations, or compare
all participating revisions and retry to avoid mixed-time Plan/ink graphs. Preflight both
incoming payloads and current access before replacing data. Use typed results from each
feature restore; stop on the first failure rather than checking localized notice strings
or proceeding after a void annotation restore failed. Keep independent pre-restore archives
and a durable restore checkpoint describing completed phases; offer Resume recovery or
explicit restoration of prior generations. Do not claim an all-store atomic transaction.
On restore, quarantine old pending writes and only reconcile references against restored
IDs/source/protection metadata. Never automatically create notes/layers, send chat messages,
rename or detach ink from an imported pending operation. Missing cross-store dependencies
stay unavailable until validated; annotations-only restore cannot grant access through an
absent Plan. Limit backup hardening to these Plan-dependent boundaries rather than a general
rewrite of Activity/Companion restore behavior.

### Ticket and readiness boundary

SP-049 provides authoring and transactional schema support; SP-050 provides internal reading
acceptance; SP-051 completes the requested tools and access-safe ink. Owner correction (2026-10-20): basic Start/Resume does not require a new app mode or
SP-051 tools. Open a Plan to view its contents; Edit is explicit. Basic playback uses the
existing reader, persisted Next completion and section summaries. Full workspace/tool
acceptance remains separate. SP-052 tests integration and records owner gates.
The [D1–D5 implementation contract](../data/collection-plans-contract.md) now records the
concrete versions, writer/target APIs, access matrix and reader/recovery transitions.
SP-049 is owner-selected; later tickets remain ready with ordered implementation
prerequisites and are unselected.
These design decisions do not prove runtime or physical acceptance.

### Fullscreen presentation correction — 2026-10-20

Plans occupy the full screen rather than a floating sheet. Content uses Sophia's
shared appearance paper/soft/ink/accent palette and serif section headings. Book
labels show full reader titles (for example Genesis 1:7–14); storage retains GEN.
Note rows offer previews that use the full Notes editor inside the Plan. Reading
uses the persistent icon order Previous, Add Note, Add Link, Background Music, Next,
with accessible labels and 48-point targets. Music opens shared play/pause and library
controls. Range assignments retain readable selected ink and dim other chapter text
to gray. Whole chapters retain ordinary ink. Layout/drawing geometry is unchanged.
Checked reading reflections remain in creation order and are traversable in order.

Owner addition (2026-10-20): Add assignment is separated into Scripture, Notes and
Links tabs. Only the selected type's fields, creation action and existing-material list
are rendered; input drafts survive switching tabs. Scripture is the initial tab.
