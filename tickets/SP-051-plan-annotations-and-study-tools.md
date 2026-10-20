# SP-051 — Plan Pencil layers and embedded study tools

Status: **note/link/music controls owner-selected; Plan-named ink and complete tool acceptance remain open** (2026-10-20).
Type: feature implementation and acceptance tracking.
Milestone: post-baseline **Collection Plans**; no release/version assigned.
Owner: Frontend UI/UX Developer; Backend & Database Engineer for reconciliation; Security Engineer for access routes.
Authorization: owner selected note preview/creation, link creation and background music
controls in the 2026-10-20 presentation correction. Plan-named ink, Companion embedding
and remaining managed-access work stay outside that selected slice.

## Intent and requirements

Deliver the bounded outcome below toward the offline-first personal study goal.
Requirements: owner's Plan request and confirmed 2026-10-19 decisions; PA/PR/PT/PI IDs
below are ticket acceptance IDs, not invented product-specification requirement numbers.
Shared behavior: [Collection Plans design](../docs/design/collection-plans.md).
Technical intent: [TDD](../docs/tdd/tdd.md#collection-plans--planning-baseline-sp-049052).
Related: [Collections design](../docs/design/collections-screen-specification.md),
[annotation contract](../docs/data/scripture-annotation-contract.md),
[Notes contract](../docs/data/notes-contract.md),
[item protection](../docs/security/item-protection.md),
[compatibility](../docs/guidelines/backward-compatibility.md).

## Dependencies

SP-049 domain/durability and SP-050 workspace. Reuse SP-012/014 annotations,
SP-013 Notes, SP-023 Companion context and SP-021 music; no replacement stores/engines.


### Resolved implementation contracts

[Selected D1–D5 contract](../docs/data/collection-plans-contract.md) closes the former
schema, transaction, access and lifecycle design gates.

D1 selects annotation snapshot/archive/pointer v2 with owned-layer source/operation tags.
D2 selects target commit/reconciliation APIs; D3 chooses copied per-domain access capsules,
propagation barriers and fresh authenticated removal. D4 defines modal/native ownership;
D5 defines graph/access restore phases. Implement these selected contracts and existing
annotation limits; do not add a second reader, layer-binding database or audio engine.
SP-049/050 are ordered implementation prerequisites; no schema/access/lifecycle choice
is deferred to this ticket.

## Visible outcome

Draw on a dedicated Plan-named layer for each source chapter. Create checked notes/links
while reading and return to the passage. Open Companion inside the workspace and control
existing background music without exposing the tab dock.

## Implementation sequence and failure handling

1. Implement Plan ↔ group/layer association through the existing AnnotationSession owner.
   First Draw creates a new layer named exactly after the Plan; repeat chapter visits
   reuse UUID bindings, never a name match. Preserve source/layout/undo ownership.
2. Journal layer creation/binding and label rename intents so interruption between the
   annotation save and Plan save can reconcile without duplicate layers or data loss.
   Handle two same-named Plans, revision changes, deleted/damaged layers and unavailable
   editions. No implicit ink copying across translations.
3. Implement managed Plan-name updates, reset-with-ink-retention, duplicate-without-ink,
   and recoverable Plan deletion/detachment. Defer transitions until live strokes end;
   await accepted drawing commits before Next, exit, relock and note/tool presentation.
4. Extend annotation ownership/access metadata as needed and review every reader-layer,
   picker, export/recovery and backup route. Existing annotations do not currently carry
   Plan protection; never treat hiding the Plan UI alone as sufficient access enforcement.
5. Adapt the existing note creation/editor workflow for an embedded return route, and
   saved-link creation for the same modal sequence. Insert successful reflections checked
   immediately after the current item in creation order, leaving that item unchanged.
6. Persist idempotent attachment operations across stores. A saved note/link with failed
   Plan attachment remains in its library; Retry reuses its ID, never clones or deletes it.
   Cancel before creation makes no material/item; after creation, normal save rules apply.
7. Embed Companion with normal selected-passage context, preset/provider/BYOK checks and
   streaming cancellation. Adapt expand-to-tab routes to the embedded workspace. Never
   transmit Plan contents, private notes or ink automatically.
8. Wire Music to the shared session and existing chooser. Do not automatically control
   narration/Activity or change music playback merely on entering/exiting Plan mode.
9. Complete graph-aware all-data export/restore and annotations-only recovery behavior.
   Preflight before mutation, retain pre-restore copies and recover partial sequential
   restores without exposing orphaned protected ink or recreating completed items.

## Module ownership and dependency direction

All source paths below are relative to application/SophiaScriptura/SophiaScriptura/.
Existing files: Features/Scripture/Annotations/AnnotationSession.swift,
AnnotationSurface.swift, AnnotationControls.swift and AnnotationRenderer.swift;
Core/Annotations/AnnotationModels.swift; Infrastructure/Annotations/;
DesignSystem/StudyNoteDestinationPicker.swift; Features/Notes/NotesSession.swift and
Editor/; Features/Companion/CompanionSession.swift and context/panel views;
Features/Music/ and Features/Protection/; Infrastructure/Backup/StudyBackupService.swift.
Proposed Plan integration adapters coordinate commands; feature sessions remain sole
owners of documents, drawing bytes, authentication, provider requests and audio engines.

Views → Plan coordinator/commands → owning feature sessions/repositories. Domain values
must not import UI/provider services. No new backend or replacement shared database.
Read exact current sources before editing; proposed directories are not implemented paths.

## Acceptance criteria

- PT-01: Real strokes belong to a new Plan-named layer. Returning to the same chapter
  reuses it across sections; another Plan with the same title gets a distinct layer.
- PT-02: Plan rename updates managed labels idempotently. Reset preserves exact drawing
  bytes; duplication has no copied bindings; edition switching never remaps source ink.
- PT-03: Inject failures between layer/binding/rename writes; retry/relaunch creates no
  duplicate or lost ink. Missing/tombstoned/damaged layers offer explicit recovery.
- PT-04: Next/exit/modal entry during a live stroke defers safely; viewport/font/context
  changes preserve declared layout behavior. Undo never modifies another layer.
- PT-05: Saved reading notes/links appear checked after the passage, in creation order;
  cancel adds no item and does not check the passage. Existing note kinds open correctly.
- PT-06: Material save then attachment failure is recoverable after relaunch with one
  material ID/item. Relock, edits and removed current items invalidate stale callbacks.
- PT-07: Companion opens/closes without progress loss or tab escape; requests use only
  authorized context. Missing keys, failed streaming and retries use existing behavior.
- PT-08: Music controls target the existing engine; no tracks, active narration, interruption
  and exit do not create an extra audio owner or automatic Plan advancement.
- PT-09: Locked Plan labels/ink cannot be exposed through ordinary Scripture pickers,
  full/annotation exports, recovery, deleted Plan bindings or changed memberships.
  Notes require their independent grant; unknown credentials fail closed.
- PT-10: Legacy/current backups, Plan Trash/permanent deletion and interrupted restore
  preserve referenced documents/drawings and safe access bindings. No silent deprotection.

- PT-11: At 128 groups, 256 layers including tombstones, or drawing byte limits, Draw
  fails before publishing a new binding with actionable guidance; reading and completion
  still work, existing ink stays intact and limits are not silently expanded.
- PT-12: Content/layout revision changes retain old ink as unavailable and require explicit
  new-source layer creation. Ordinary layer rename/delete routes cannot bypass managed
  ownership; old apps reject required new access metadata across archives and recovery.
- PT-13: Protected Plan reflection creation followed by attachment failure retains its
  source access restrictions in Notes/No Folder. Multiple memberships use any-locked
  concealment; moves/folder deletion/Plan purge cannot silently release retained ink.
- PT-14: Concurrent export/restore and attachment/rename operations produce a coherent
  graph or explicit retry. A failing annotation restore stops dependent restore phases
  with typed failure and a recovery checkpoint; imported retry records never execute writes.
- PT-15: Relock immediately conceals native surfaces/selection, while accepted dirty ink
  remains retryable. Existing snapshot/fallback generations cannot strip new protection.

- PT-16: D1 Plan+exact-source ownership and fixed operation IDs find the same durable
  layer after a crash; rename revisions and detached access survive receipt pruning,
  same-name Plans, duplicate-note creation tags and annotations-only restore.
- PT-17: D3 protect/reparent/file/removal barriers propagate to Notes/links/ink and safe
  fallback generations before success; fault each phase. A restrictive union remains
  effective on error, purge or restore, and imported metadata never relaxes access.
- PT-18: D5 failed phase/readback reconciliation resumes only from validated local staged
  input; Restore previous study state is typed/checkpointed too. Missing Plan owners and
  absent independently required grants leave retained drawing access unchanged.

## Exclusions

No schedules/dates/reminders/streaks, imported/public Plans, sharing format, AI-generated
Plans, automatic narration advancement, automatic Activity metrics, new provider, unrelated
refactor, release/version bump, signing/install, secret changes or destructive migration.
The other Plan tickets own their separate outcomes; starting this ticket does not select them.

## Verification and evidence

Use [current native test instructions](../docs/testing/test-specification.md) and
[device guidance](../docs/deployment/deployment.md). Plan tests should verify user-observable
invariants, compatibility and fault boundaries; no tests are run for ticket authoring.
During implementation retain result bundles/logs in ignored build/sp-051/.
Run focused unit/integration tests for the criteria, UI journeys for changed flows and
physical cases where required. Record exact commands, source revision, environment and
counts; retain known failures/gaps. No user-store wipes or unlicensed content fixtures.

## Documentation and handoff

Update the canonical TDD, shared Plan design, Collections/reader/annotation/Notes data or
screen docs as affected, protection/backup behavior, source map, testing evidence,
this ticket, ticket index and development tracker. Reconcile the selected D1–D5 schema contract with actual code/evidence
without presenting the ready design as already implemented behavior.
Handoff includes criteria met/unmet, evidence, compatibility/access risks and remaining
physical/provider gates. Return to owner before selecting another ticket.

## Evidence and current gaps

Planning only, 2026-10-19. Current Collections, reader emphasis, annotation source/layer,
root composition, note-creator, backup and protection boundaries inspected. No app edits,
native tests, schema migration, provider request, signing, installation or release.
Owner-confirmed behavior is retained; D1–D5 records selected future implementation
choices under the owner's design-resolution request. No runtime behavior is claimed.

## Planning review — 2026-10-19

Reviewed against exact current writer/session/schema/backup/lifecycle source. Findings and
recommended resolutions: [Plan review](../docs/design/collection-plans-review.md).
Additional criteria above cover concrete failure/boundary cases. All behavior remains a
proposal; no code, native tests, provider request, migration, installation or release.
The subsequent D1–D5 design resolution closes the architecture design gates. This ticket
is ready with ordered implementation prerequisites; no execution has been selected.

## Readiness resolution — 2026-10-19

D1–D5 is the selected future contract, with explicit fields, versions, command/result shapes,
access propagation/removal, reader lifecycle and recovery ordering. Design prerequisites
are resolved. Implementation prerequisites execute in ticket order; verification evidence
remains unproduced. Ready does not authorize implementation, migration, release or install.

## Owner control/preview correction — 2026-10-20

Owner requested restoration of the agreed Previous / Add Note / Add Link / Music /
Next icon bar, real note previews and fullscreen presentation. PlanDetailView hosts
these controls and previews Page/Canvas/Prayer/Journal content with the existing
Notes editor, returning to the Plan without leaving it. The shared New Note workflow
accepts an optional async creation override; ordinary callers retain their existing path.
PlanReflectionDraft saves target material before its checked reflection item, retains
stable IDs for retries, and inserts multiple reflections in creation order. New note
creation records an attachNote operation and finishes it after the Plan commit. Link
creation uses its existing typed save receipt. Failed/stale attachments retain saved
material and report the failure instead of inserting phantom checked items. Newly
attached reflections inherit Plan folder memberships atomically in the Plan commit.
The shared Notes session has one transient Plan-presentation owner so offscreen Notes
and Collections hosts do not mount a second editor. Accepted edits flush before
Next/Previous/exit. Music reuses Root's existing MusicSession and library/play/pause
commands; no new audio engine or playback owner is created.

This slice does not implement Plan-owned Pencil layers, Companion embedding,
access-removal/ink propagation or all D4 lifecycle cases. Those acceptance gates stay open.
Final verification/install evidence is recorded in SP-049.
