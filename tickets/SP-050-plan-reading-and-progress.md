# SP-050 — Plan reading workspace and durable progress

Status: **basic entry/progress slice owner-selected and implemented; full workspace acceptance remains open** (2026-10-20).
Type: feature implementation and acceptance tracking.
Milestone: post-baseline **Collection Plans**; no release/version assigned.
Owner: Frontend UI/UX Developer; System Architect for session/state boundaries.
Authorization: owner selected basic playback and the fullscreen presentation/focus correction
on 2026-10-20. Full remaining D4 lifecycle acceptance stays outside this correction.

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

SP-049 accepted schema/editor/commands. SP-051 is required before the complete
owner-requested Plan feature is accepted; this slice cannot claim Pencil/tool completion.


### Resolved implementation contracts

[Selected D1–D5 contract](../docs/data/collection-plans-contract.md) closes the former
schema, transaction, access and lifecycle design gates.

D4 selects one ReaderSession with PlanReaderLease, a transient working snapshot and
normal/Plan/meditation workspace routing. Use its exact state/event matrix, one native
callback owner, token invalidation, narration pause and immediate privacy concealment.
D2 receipts distinguish progress-save failure from later target-load failure. SP-049 is
an implementation prerequisite, not an unresolved design dependency. Internal acceptance
may exercise playback; ordinary-build Start awaits SP-051 safety criteria.

## Visible outcome

Start/Resume opens fullscreen Scripture with assigned verses emphasized, surrounding
text muted, hidden tab dock and persistent Previous/Next progress. Each section ends at
an explicit summary. Exit returns to the originating Plan detail and prior reader state.

## Implementation sequence and failure handling

1. Implement a dedicated playback coordinator with the states and transition table in
   the shared design. Capture original shell/reader presentation once per session;
   session tokens and revisions reject stale async completions.
2. Resolve the preferred edition/explicit override through the existing content owner.
   Render assigned verses using an explicit focus input, separate from transient selection
   and narration. Show context changes styling only, not layout or progress.
3. Compose a fullscreen workspace with ×, section/reference/progress header, outline,
   Previous/Next controls and slots for SP-051 study controls. Disable underlying tab
   touch, keyboard and accessibility/programmatic navigation while active.
4. Await transition persistence before moving the cursor. On failures preserve position
   and accepted buffers with Retry. Serialize rapid taps and cancel stale loads safely.
5. Persist active item UUID/viewport, section/Plan summary state and edits to completion.
   Handle outline jumps, gaps, empty sections, active item removal, resets and relaunch.
6. Coordinate flush barriers with Notes/annotations before transitions. Backgrounding is
   best effort with foreground reconciliation, never a guarantee of iPadOS execution.
7. Restore underlying reader/tab/annotation presentation on exit, without overwriting
   legitimate progress or globally resetting preferences. Preserve music/Activity state.

## Module ownership and dependency direction

All source paths below are relative to application/SophiaScriptura/SophiaScriptura/.
Existing files: RootTabView.swift; Features/Scripture/ReaderSession.swift,
ReaderTextSurface.swift, ScriptureView.swift; Core/Scripture/ChapterTextMap.swift;
Features/Activity/MeditationJourneyCoordinator.swift and MeditationJourneyView.swift
as reference patterns only. Proposed Features/Plans/ playback coordinator and views own
sequence/cursor; renderer takes presentation values only. Root composes lifetimes and
routes, without embedding Plan business logic or copying the meditation state machine.

Views → Plan coordinator/commands → owning feature sessions/repositories. Domain values
must not import UI/provider services. No new backend or replacement shared database.
Read exact current sources before editing; proposed directories are not implemented paths.

## Acceptance criteria

- PR-01: Start focuses Mark 1:1 in its full chapter; Next saves/checks and loads John
  1:1–3. Previous is initially disabled and never unchecks completed assignments.
- PR-02: Outline jumps do not complete intervening items. Repeated Next taps, slow loads,
  exit/re-entry and cancelled loads cannot complete the wrong item or skip an assignment.
- PR-03: Last item pauses at section summary. Relaunch returns to that summary; Continue
  is explicit. Remaining unchecked items are reported honestly. Only all-checked Plans
  show completion; gaps offer review/first unfinished.
- PR-04: Exit/background does not mark current item complete. Resume retains item and
  viewport; reset/edit/delete while active follows stable identity/revision rules.
- PR-05: Missing/expired edition and unavailable reference show recovery choices without
  silent substitution/download, automatic completion or leaked licensed text.
- PR-06: Focus/show-context preserves line geometry and normal reader behavior outside
  Plan mode; text selection, narration emphasis and appearance changes remain distinct.
- PR-07: Hidden tabs cannot receive VoiceOver focus or embedded tool navigation. Exit
  restores the original workspace; only one Plan can be active.
- PR-08: Persistence failure keeps the current item/unchecked state until retry succeeds;
  relock or stale callbacks cannot reopen hidden content.

- PR-09: After completion saves, failure to load the next target retains that check and
  pending target; Retry reloads without rechecking/recreating anything. Failed completion
  save instead leaves it unfinished. Crash/relaunch preserves the correct distinction.
- PR-10: Plan navigation leaves ordinary persisted reader location unchanged. Settings,
  annotation appearance, native callbacks and reader selection restore with valid ownership
  tokens; no duplicate mounted drawing surface or stale snapshot restoration.
- PR-11: Narration is paused on entry without automatic exit resume; competing meditation,
  Activity links, Sophy routes, Notes Scripture pane and keyboard/VoiceOver routes cannot
  escape the workspace or cancel independent Activity/music. Revalidate routes after exit.
- PR-12: Existing shared Companion draft/stream is retained. Summary Add actions are
  disabled; non-Scripture reflections never inherit an unrelated reader passage. Checked
  inserted reflections traverse in order; completed Plans open Review without implicit reset.
- PR-13: Relock captures accepted buffers then conceals immediately even while a save or
  stroke wait is pending; disk failure cannot keep private UI visible or reopen it later.

- PR-14: D4 navigation/preferences/edition/visible-location/resume/save entry points cannot
  write the ordinary ReaderSnapshot while leased; process relaunch offers Resume at the
  committed item/summary. Invalid source/access on exit falls back safely to Read Hidden.
- PR-15: Exercise every D4 lifecycle row with delayed loads and save failures, native owner
  transfer, background/foreground, competing workspace and queued Activity route. The
  original callback owner cannot reclaim a newer lease or apply an obsolete appearance.

## Exclusions

No schedules/dates/reminders/streaks, imported/public Plans, sharing format, AI-generated
Plans, automatic narration advancement, automatic Activity metrics, new provider, unrelated
refactor, release/version bump, signing/install, secret changes or destructive migration.
The other Plan tickets own their separate outcomes; starting this ticket does not select them.

## Verification and evidence

Use [current native test instructions](../docs/testing/test-specification.md) and
[device guidance](../docs/deployment/deployment.md). Plan tests should verify user-observable
invariants, compatibility and fault boundaries; no tests are run for ticket authoring.
During implementation retain result bundles/logs in ignored build/sp-050/.
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

## Owner correction — 2026-10-20

Basic playback is authorized by the owner without requiring a separate app mode or
SP-051 tool completion. See SP-049 correction evidence. Content-first opening, explicit
Edit, existing-reader Start/Resume, durable Next/Previous and section/Plan summaries
are implemented. Remaining D4 lease, reader-position restoration, focus contrast and
full shell/tool lifecycle requirements remain unimplemented; this is not full PR acceptance.

## Owner presentation correction — 2026-10-20

Owner selected fullscreen, Sophia-styled Plan content/reading, full book names and
muted non-assignment verses. PlanDetailView now occupies the whole screen, uses
AppTheme paper/ink/accent surfaces, serif headings, soft section cards and an icon
control bar. Canonical book codes remain stored; labels resolve reader book titles.
ReaderTextSurface accepts optional Plan-only focus verses, dimming other text while
retaining selected verse ink/geometry; normal reader callers keep their existing style.
Already completed items preserve completion timestamps. Full reader-lease/restore and
physical accessibility/contrast acceptance remain open; this correction is not milestone closure.
Verification/install evidence is recorded in SP-049 after final-source checks.

Owner addition (2026-10-20): Add assignment is separated into Scripture, Notes and
Links tabs. Only the selected type's fields, creation action and existing-material list
are rendered; input drafts survive switching tabs. Scripture is the initial tab.
