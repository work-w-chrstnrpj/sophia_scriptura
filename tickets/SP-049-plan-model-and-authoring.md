# SP-049 — Plan domain, persistence and Collections authoring

Status: **implemented; simulator verified; physical authoring/accessibility acceptance open** (2026-10-20).
Type: feature implementation and acceptance tracking.
Milestone: post-baseline **Collection Plans**; no release/version assigned.
Owner: Frontend UI/UX Developer; Backend & Database Engineer for persistence; System Architect for boundaries.
Authorization: owner requested “Implement now” and then “continue”; SP-049 execution
was announced as the first dependency slice. No other ticket, release or install selected.

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

Existing Collections membership/generation/protection behavior (SP-015, SP-026–028,
SP-045–047). No prior Plan implementation. SP-050/051 depend on this contract.


### Resolved implementation contracts

[Selected D1–D5 contract](../docs/data/collection-plans-contract.md) closes the former
schema, transaction, access and lifecycle design gates.

D1 selects Collections v4, Notes v5 and version-gated reader/archive foundations; D2
selects CollectionsStore.submit as the only serialized writer and typed target results.
D3 specifies access values and note/link creation; D5 selects a backup mutation lease,
full-backup v2 and typed/checkpointed recovery foundations. No separate Plan writer.
Implement these interfaces, activation/fallback tests and existing writer-call-site routing
in this ticket. Annotation Plan-layer writes remain disabled until SP-051. Basic Start/Resume is owner-authorized in the 2026-10-20 correction below. Existing flush/created-ID callbacks are not receipts.

## Visible outcome

Collections → Add Study Material → New Plan. Create and manage ordered configurable
sections containing Scripture, notes and links, with checkboxes, reset and recoverable Trash.
Plans appear in material lists/cards, filters, search and No Folder using existing patterns.
Opening a Plan shows contents; Edit is explicit and basic Start/Resume uses the existing reader.

## Implementation sequence and failure handling

1. Establish stable Plan/section/item identities, tagged payloads, edition/reference policy,
   completion/cursor representation and draft validation from the shared design. Model ink
   association and pending attachment/rename intents now so later tickets do not invent an
   incompatible parallel store. Define explicit access dependencies for managed ink.
2. Add validated additive decoding using D1 Collections v4/Notes v5, including their
   wrapper/pointer/fallback activation rules; update every affected store/backup reader.
   Do not assume adding optional keys alone
   prevents older builds from dropping Plans. Preserve previous valid generations.
3. Implement PlanCommandService delegating immutable typed intents to the sole
   CollectionsStore.submit executor, with D2 receipts/revisions/access checks. Route all
   existing direct Collections writers through that executor; no second mutable Plan store.
4. Build Plan detail/editor, batch passage picker, configurable/custom section labels,
   note/link pickers and existing creation handoffs. Resolve Scripture bounds through the
   current repository; split cross-chapter input without copied text.
5. Add edit/reorder/move, checkbox, duplicate section/Plan, scoped reset, archive/Trash,
   restore and expiry behavior. Preserve linked material/ink. Do not silently deprotect
   ink when membership changes; define a guard/detach handoff with SP-051.
6. Extend full-backup payload validation/round-trip immediately, including legacy no-Plan
   archives. Keep future ink bindings representable and validate dangling references.
7. Verify selected 100-Plan/200-section/2,000-item limits with boundary/representative fixtures
   and the authoritative D1 byte budget; changing them requires explicit scoped
   documentation and test evidence rather than silent limit expansion.

## Module ownership and dependency direction

All source paths below are relative to application/SophiaScriptura/SophiaScriptura/.
Existing files: Features/Collections/CollectionModels.swift, CollectionsStore.swift,
CollectionDetailView.swift and related list/filter/add-material surfaces;
Infrastructure/Collections/CollectionsFileRepository.swift;
Infrastructure/Backup/StudyBackupService.swift; Features/Notes/NotesSession.swift,
Core/Notes/NoteDocument.swift and Infrastructure/Notes/NotesFileRepository.swift;
Core/Annotations/AnnotationModels.swift
for selected typed ownership/read compatibility; DesignSystem/StudyNoteDestinationPicker.swift.
Proposed modules, not current files: Core/Plans/ for pure values/validation and
Features/Plans/ for editor/detail and Plan commands. Keep UIKit/provider access out of
domain values. Selected future file names/interfaces are in D1–D5; read exact existing callers before editing.

Views → Plan coordinator/commands → owning feature sessions/repositories. Domain values
must not import UI/provider services. No new backend or replacement shared database.
Read exact current sources before editing; proposed directories are not implemented paths.

## Acceptance criteria

- PA-01: Create/save/relaunch a two-section Plan matching the owner's example; title,
  order, labels, canonical references and checks remain identical.
- PA-02: Legacy Collections schemas 1/2/3 and backups load with no Plans; new Plan data
  round-trips and unsupported versions fail without overwriting valid files.
- PA-03: Whole chapters, single verses, ranges, repeated references and cross-chapter
  selections validate; invalid/unmapped input cannot become a falsely playable item.
- PA-04: Reorder/move keeps item identity and progress; target replacement resets only
  that item. Duplicates use new IDs and unchecked progress; linked material remains shared.
- PA-05: Reset item/section/all confirms scope and preserves notes, links and ink. Empty
  drafts save but cannot claim completion. Collection copies reuse Plan memberships.
- PA-06: Removal/Trash/restore/expiry affect only the intended Plan or membership; known
  annotation references are retained for safe detachment rather than cascade deletion.
- PA-07: Denied/expired access and failed saves publish no successful command or partial
  edit; old completion/cursor remains recoverable. No locked preview leaks through search.
- PA-08: Full-backup legacy/current round-trip preserves order, IDs, progress and protection;
  invalid graph/unknown tags/duplicate IDs/oversized payloads preserve original data.

- PA-09: Interleave Plan Next/reset, link/folder updates, Companion projection and Sophy
  writes across suspended saves; one serialized writer preserves all successful intents.
  Failure/rollback cannot erase a later command or publish a false committed checkbox.
- PA-10: Titles at 80 Unicode Characters create exact layer-compatible names; 81 is
  rejected consistently on create/rename, without silent truncation.
- PA-11: Deleted-link/missing-note targets survive save/backup as unavailable steps.
  Target rename/content edit preserves checks; replacement resets only that item.
- PA-12: Export is a coherent revision cut; imported incomplete operations are inert and
  cannot create material, send messages or mutate annotation bindings on restore.

- PA-13: D1 Collections v4/Notes v5 wrappers, sticky activation and both automatic fallback
  generations reject unsupported downgrade; legacy current/previous/explicit restore cases
  preserve bodies, ink references and required access. No user-data reset.
- PA-14: D2 command ID/hash/revision receipt tests cover retries, 256-receipt eviction,
  128-operation capacity, uncertain publication readback and all existing direct writers.
- PA-15: D3 target Notes access exists before first durable creation; a missing/deleted
  folder or failed attachment cannot make a protected orphan public. Fresh grants remain
  independent by domain; unknown credential UUIDs fail closed.
- PA-16: D5 backup v2 carries feature hashes/revisions and inert recovery records; local
  checkpoint phase-result failures pause recovery. Activity without a revision counter
  uses a verified normalized hash; imported receipts cannot authorize mutation/removal.

## Exclusions

No schedules/dates/reminders/streaks, imported/public Plans, sharing format, AI-generated
Plans, automatic narration advancement, automatic Activity metrics, new provider, unrelated
refactor, release/version bump, signing/install, secret changes or destructive migration.
The other Plan tickets own their separate outcomes; starting this ticket does not select them.

## Verification and evidence

Use [current native test instructions](../docs/testing/test-specification.md) and
[device guidance](../docs/deployment/deployment.md). Plan tests should verify user-observable
invariants, compatibility and fault boundaries; no tests are run for ticket authoring.
During implementation retain result bundles/logs in ignored build/sp-049/.
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

## Implementation checkpoint — 2026-10-19

Plan domain/validation, Collections material/filter/projection and editor/assignment picker
are implemented locally. Authoring supports configurable section labels, Scripture ranges/
whole chapters, existing/new notes and links, reorder/move/replace, checkboxes, section/all
reset, duplication, archive and recoverable Trash. Basic Start/Resume was added by the owner correction below.
The editor owns its unsaved draft; the Collections writer owns durable revisions/receipts.

Collections v4 and Notes v5 activate their v2 wrappers/pointers with protected fallback
copies. Typed Plan/target save results, idempotent creation/readback and shared access
requirements preserve Notes/Collections grants. Existing synchronous Collections UI wrappers
retain their optimistic view state but submit private value deltas to the sole executor;
that projection is distinct from its committed snapshot and Plan commit receipts. Existing
Sophy/folder/restore direct writer paths now use that same queue. No Plan repository exists.

All-data backup v2 carries a revision/hash vector and inert recovery records. Restore
preflights supported archives and uses typed feature results, local staged inputs and phase
checkpoints; Settings exposes Resume recovery and Restore previous study state. Accepted
buffer capture, mutation gates and semantic hash comparison protect interrupted recovery.
Ink v2/Plan layers and complete managed-layer/access-removal tools remain SP-051 work.
No provider call, signing/install, user-store migration/reset or publication was performed.

Verification so far: initial simulator build passed; focused r4 passed 153 tests (13 Plan,
33 Collections, 45 Notes, 36 protection, 26 Sophy acceptance). Earlier runs exposed an async
XCTest assertion, Plan access-boundary omission and regressions in duplicate-folder/stale
Sophy/link metadata handling; corrected before final verification. Full/unit/UI evidence
and final acceptance disposition are recorded below when complete. These interim counts
are not final-source proof. Bundles/logs: build/sp-049/.

## Final verification — 2026-10-20

- Final source simulator build and **434 native unit tests passed**, zero failures/skips,
  on iPad (A16), iOS 27.0, Xcode 27.0. Command: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  xcodebuild test -project application/SophiaScriptura/SophiaScriptura.xcodeproj -scheme
  SophiaScriptura -destination 'platform=iOS Simulator,id=709D6F70-328D-4458-8F8A-B2C47A945A80'
  -derivedDataPath build/sp-049/DerivedData -resultBundlePath build/sp-049/final-regression.xcresult
  -only-testing:SophiaScripturaTests -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO.
  Log: build/sp-049/final-regression.log. Includes **18 PlanTests and two PlanBackupTests**.
- **One focused native UI journey passed** in build/sp-049/ui-r4.xcresult:
  New Plan → title → add whole-chapter assignment → Save → reopen → app terminate/relaunch
  → reopen the same persisted assignment; Start remains unavailable. Screenshot exported
  to build/sp-049/ui-final-attachments/ and visually inspected (title/assignment retained,
  controls visible, no overlap). Earlier UI failures exposed editor draft lifetime loss;
  the presenting route now retains PlanEditorDraft across store publications. A compiler
  typo during that refactor was fixed before the passing run.
- Backup integration separately passed **2/2** in build/sp-049/backup-integration.xcresult
  and is included again in final-regression: Plan IDs/order/checks/summary cursor survive
  all-data export/restore; an injected annotation restore interruption stops subsequent
  phases, blocks dependent writes, then explicit resume preserves the already committed
  Notes revision and completes restoration. Original staged prior inputs are retained.
- Domain/failure checks cover title/UUID/reference validation, legacy/default decoding,
  v4 fallback after corrupt current pointer, Notes v5 access retention through legacy
  restore, idempotent commands/target creation, pre-/post-publication failures, stale edits,
  concurrent suspended Plan save plus folder/link edits, unknown credentials, unavailable
  linked material and inert recovery access validation. Existing Collections, Notes,
  protection, annotation, Companion, Activity and Sophy regressions pass in the full suite.
- Final source after the passing authoring UI run additionally tightens recovery-only
  command/Settings guards; those changes are included in final native unit regression.
  The specific authoring controls/draft flow are unchanged by those recovery guards.
- Local documentation links/anchors/source paths and git diff --check are validated in
  the final documentation pass. Native evidence stays ignored under build/sp-049/.

## Acceptance disposition and handoff

Authoring and its schema/transaction/access/backup foundations are implemented and
simulator-verified. This is not complete Collection Plans feature acceptance: SP-050
reader lease/focus/Next/summaries and SP-051 Plan-named ink/embedded tools/managed access
removal remain ready and unselected. Basic Start/Resume is enabled independently of the remaining workspace/tool scope.

Remaining owner/device gates: physical keyboard/touch/reordering feel, large text/VoiceOver,
Split View/themes and owner-data upgrade/backup walkthrough. Representative maximum-size
and exhaustive interruption-boundary testing remain later integrated SP-052 evidence;
the final suite is not a claim that every limit/fault permutation or physical case ran.
No user-store reset, provider call, commit/push/merge or release was performed.
On 2026-10-20, the repository installer passed dry-run, signed Debug build, strict
signature/bundle identity checks, in-place installation and normal launch on `iPad ni Paj`
(version 1.3.2/build 27, `com.personal.SophiaScriptura`). No uninstall/reset was used.
Evidence: `build/sp-049/ipad-install.log` and the timestamped installer logs under
`build/ipad-install/logs/`. Installation/launch does not close the physical feature gates. Unrelated Bravado files are retained. Return to owner before SP-050.

## Owner correction — 2026-10-20

Owner requested content-first Plan opening, removal of the misleading Start dependency,
working basic playback without a separate app mode, and another in-place iPad install.
PlanDetailView now shows sections/assignments/checks; Edit opens the existing editor.
Start/Resume uses the existing ReaderSession/ReaderTextSurface with assignment emphasis.
Next commits completion and cursor before advancing, pauses at section summaries, and
finishes at the Plan summary. Previous preserves checks. Unavailable/locked assignments
cannot be checked by Next. Locked Plans conceal content and close subordinate sheets.
No schema changes. This is a bounded SP-049 correction/basic SP-050 entry slice; the full
D4 reader lease/normal-position restoration, focus contrast, embedded tools and Plan ink
remain separate acceptance work. Ordinary shared-reader position changes are retained.

Verification: 21 focused Plan/backup unit tests passed (19 PlanTests including the new
summary-cursor regression; 2 PlanBackupTests), zero failures, in
`build/sp-049/plan-detail-final.xcresult`. That run's UI check failed after relaunch because
its helper tapped an offscreen Collections folder while the dock was collapsed. The helper
now waits for hittable tabs/folders. Final UI run `build/sp-049/plan-detail-ui-r3.xcresult`
passed the complete create/content/Start/Next/section-summary/relaunch/completion/Resume/
Plan-summary/explicit-Edit journey. The section-summary screenshot from the final-source
run was visually reviewed. No runtime code changed for the UI helper rerun. The earlier
`plan-detail-ui.xcresult` failure exposed inherited accessibility identifiers, also fixed.
`git diff --check` and new view/ticket path/whitespace checks passed.

Installer preview, final signed Debug build, strict signature/identity checks and in-place
iPad install passed (`build/sp-049/plan-detail-install-final.log`). Launch initially failed
because the iPad was locked; after the owner unlocked it, normal launch succeeded
(`build/sp-049/plan-detail-launch-retry.log`). Device: iPad ni Paj; version 1.3.2/build 27;
identity `com.personal.SophiaScriptura`. No uninstall/reset, source publication or version
bump. Physical feature/accessibility and remaining full workspace/tool acceptance stay open.

## Owner fullscreen/styling/tools correction — 2026-10-20

Owner rejected the floating/default-styled Plan UI and requested fullscreen pages,
full book names, actual note previews, dimmed unassigned Scripture and the agreed
Previous / Add Note / Add Link / Background Music / Next icons. These select the
SP-050 presentation and SP-051 note/link/music slices, with Plan-named Pencil and
complete lifecycle/tool acceptance remaining separate.

Implementation follows the shared theme and existing reader/Notes/music owners.
PlanReflectionDraft writes target material before checking/attaching its item; Notes
uses its existing type/color creation workflow and full editor. Multiple reflections
retain creation order; already checked timestamps are preserved during traversal.
New reflection memberships are part of the same Plan save. No schema or version bump.

Verification: `build/sp-049/plan-fullscreen-final.xcresult` passed **441 unit tests plus
one expanded native UI journey**, zero failures/skips. It covers real Page content
creation/edit/return, range focus, full labels, all five controls, checked ordered
reflections, summary pauses, persistence and note preview after relaunch. After the
owner's additional picker request, `build/sp-049/plan-assignment-tabs-ui.xcresult`
passed the same journey plus Notes/Links/Scripture tab isolation. The only later
non-documentation change is clearer failure-message wording in the shared New Note UI;
the final signed build compiles it. Earlier attempts and their fixed test access/toggle
issues remain under build/sp-049 and are not counted as passing evidence.

Visual review: `build/sp-049/plan-fullscreen-reviewed/53E1D03C-185A-4A6C-921B-4FE4BE296904.png`
shows fullscreen reading, full title, gray surrounding verses and the complete icon bar.
`build/sp-049/plan-new-link-visual.png` shows the existing-style creation handoff over
that page. Whitespace and 398 local links across 23 changed/new docs passed. Full
physical appearance, large text/VoiceOver, Pencil and provider acceptance remain open.
Deployment: the repository installer passed signed Debug build, strict signature/identity
checks and in-place install on iPad ni Paj, version 1.3.2/build 27. Evidence:
`build/sp-049/plan-fullscreen-install.log`; preview:
`build/sp-049/plan-fullscreen-install-preview.log`. No uninstall/reset, version bump,
commit/push/merge or release was performed. Initial launch was blocked by the locked device. After the owner unlocked it, normal
launch succeeded (`build/sp-049/plan-fullscreen-launch-unlocked.log`). Installation and
launch are complete; physical feature acceptance remains separate. Final source/doc whitespace checks passed
for 63 files and 398 local Markdown paths.

Owner addition (2026-10-20): Add assignment is separated into Scripture, Notes and
Links tabs. Only the selected type's fields, creation action and existing-material list
are rendered; input drafts survive switching tabs. Scripture is the initial tab.

### Owner-reported section deletion crash — 2026-10-20

Selected outcome: stop the app abort when removing a day/section and broaden Plan
structural stability checks. Exclusions: no new Plan feature, schema migration,
reader lease or Pencil acceptance. Affected modules: Plan editor/draft, assignment
picker, native unit/UI regressions and aligned documentation.

The original native reproduction reached Remove section and aborted with Swift
exclusive-access conflict (`section-delete-before-r3.xcresult`, reduced crash summary
`build/sp-049/section-delete-crash-summary.json`). Earlier successful journeys did
not cover deletion. Details and hypothesis evidence:
[section-deletion investigation](../docs/testing/sp049-plan-stability-investigation.md).

Correction: PlanEditorView renders value snapshots; PlanEditorDraft resolves stable
UUIDs before mutation. Deleted-row bindings/callbacks cannot address a surviving row.
Reorder snapshots are validated, removed targets clear invalid cursor/picker/reset
state, and save/capacity guards apply to structural commands. Assignment menus expose
removal; section menu hit targets cover the row. Cancel replacement clears state;
batch replacement retains every chapter. Dependent chapter bounds reset/clamp before
switching to a shorter book. No persistence schema changed and no owner data was reset.

Focused verification: `build/sp-049/section-stability-focused.xcresult` passed 12 unit
regressions and the native only-section deletion/save/relaunch case. The final full
suite and expanded populated journey are recorded below after completion.

Final verification: `build/sp-049/plan-stability-final.xcresult` passed **453 unit tests
and both Plan UI journeys (455 total), zero failures/skips**, on iPad (A16) iOS 27.0
simulator. `plan-stability-final-summary.json` retains the xcresult summary. Coverage
includes populated duplication/item deletion/section deletion/reset with preserved
reflection note content, and only-section deletion/readd/save/relaunch/empty Start.
The new 12 unit tests include 400 mixed edits and repository reopen, stable identity,
stale callbacks and bounds. The signed Debug build also passed
(`section-stability-signed-build.log`). These checks cover the reported crash and
related Plan editor paths; they do not claim exhaustive stability or physical/Pencil/
accessibility acceptance. Status: implemented and simulator verified; physical use
remains an owner acceptance gate.

Deployment: installer dry-run and signed build/signature/identity checks passed.
The first device install encountered a remote connection error; retry with the paired
UDID succeeded in place (`section-stability-install-retry.log`). Bundle identity is
`com.personal.SophiaScriptura`, version 1.3.2/build 27. Owner data was preserved;
no uninstall/reset, commit, push or release. Launch result is recorded separately.

Physical launch verification is pending unlock: iPadOS explicitly rejected launch
with `FBSOpenApplicationErrorDomain` code 7 / Locked
(`build/sp-049/section-stability-launch.log`). This is a device lock gate after
successful installation, not another reproduced app crash. The owner was asked to
unlock so normal launch can be retried.

Documentation validation: `git diff --check` passed; 404 local Markdown paths across
24 changed/new documentation files resolve. Test bundles and crash evidence remain
in ignored build storage.

### Owner action presentation follow-up — 2026-10-20

Assignment ellipsis menus include Remove assignment (retained from the stability fix),
now with a red trash label. It removes the Plan assignment while preserving its source
material. Plan lifecycle rows now show reset (`arrow.counterclockwise`), duplicate
(`doc.on.doc`), archive (`archivebox`)/unarchive (`tray.and.arrow.up`) and trash icons.
Move Plan to Trash retains its destructive role and explicitly renders its label/icon
red, avoiding inherited app tint. No command or schema semantics changed.

Verification: `build/sp-049/plan-action-icons.xcresult` passed the expanded native Plan
journey, including actual assignment removal, section deletion, reset and note-content
preservation. Screenshot `plan-action-icons-attachments/2A793260-411D-42A3-9CF0-335FCBC5875F.png`
was visually reviewed: all four lifecycle rows have icons and Trash text/icon are red.
The prior 455-test stability baseline remains recorded above; it was not rerun for
this presentation-only change. Signed build/signature/identity passed; install by name
hit a connection error, then in-place install using paired UDID succeeded
(`plan-action-icons-install-retry.log`). Normal launch succeeded
(`plan-action-icons-launch.log`). Version remains 1.3.2/build 27, data preserved.
`git diff --check` passed. Status: implemented, native UI/visual verified, installed
and launched; owner physical appearance acceptance remains separate.

Owner wording follow-up (2026-10-20): Collections now uses “Items” for its section
heading and “Add Items” for actions/picker title. Accessibility and search labels use
the same terminology; existing identifiers and behavior remain unchanged.
Verification for wording: Debug simulator build passed
(`build/sp-049/items-labels-build.log`); `git diff --check` passed and source search
found no remaining Study Material labels in Collections. No behavior tests were
added/rerun for this copy-only update. Not committed or installed in this follow-up.

### Completed Plan stamp — 2026-10-20

Owner selected a COMPLETED stamp for finished Plans. A shared passive green outlined
stamp appears in Collection list/card records and the Plan contents page. It follows
StudyPlan.isComplete (nonempty/all checked), including reset and new unfinished items;
there is no separate persisted status or schema change. CollectionArtifact carries
only a derived display flag. Existing Items wording changes remain in this worktree.
Verification: `build/sp-049/plan-completed-stamp.xcresult` passed 19 Plan unit tests and
the expanded native UI journey (20 tests, zero failures). The UI asserts the stamp
exists after completed Plan relaunch and is absent after reset; deletion and retained
note checks also pass. `git diff --check` passed. List/card placement is source-verified;
physical appearance and accessibility acceptance remain open. No commit or device
installation was performed for this follow-up.

Owner-requested deployment of Items wording and completed stamp: signed build,
strict signature/identity checks, in-place install and normal launch succeeded on
iPad ni Paj (`build/sp-049/plan-completed-stamp-install.log`). Version remains
1.3.2/build 27; existing data preserved. Physical feature acceptance remains separate.

### Owner stamp consistency correction — 2026-10-20

The first COMPLETED badge did not match Notes' lettering, scale or treatment. It is
replaced with a COMPLETED vector wordmark generated from the same locally licensed
Rubber Stamp font and exact existing glyph generator. PlanCompletedStamp delegates
to NoteCardStatusStamp's new completed mark: same 210×55 face, 12-point padding,
3-point outline, green tint, stable identity tilt, impression animation and Reduce
Motion behavior. Collection cards use Notes' centered overlay placement; compact
80-point list rows scale the same component to 65% to fit. The contents page uses
full size. Visibility activation follows the existing note-card environment.
No new completion state or schema changes. Font provenance/generator now include
COMPLETED; original Notes assets are preserved.

Verification: final `build/sp-049/plan-notes-stamp-final.xcresult` passed the expanded
native Plan journey (completion after relaunch, reset removes image, deletion and
retained note content). The first run retained the previous StaticText selector and
failed there; the final test correctly queries the shared image stamp. Screenshot
`plan-notes-stamp-final-review/4A76D140-15DA-4900-850E-481FCAFEA616.png` was visually
reviewed: matching distressed lettering, full-size frame, tilt and green Notes treatment.
No app runtime edits followed the installed build. The installer initially rejected
an incrementally generated Assets.car signature mismatch and installed nothing;
cleaning only generated device build products resolved it. Fresh signed build,
strict signature checks, in-place install and normal launch all passed
(`build/sp-049/plan-notes-stamp-install-retry.log`). Owner data preserved; version
1.3.2/build 27. `git diff --check` passed. Not committed; physical owner review remains open.

Owner placement correction: COMPLETED appears only on the outside Collection
list/card record. The Plan contents page does not display a stamp.

Placement follow-up verification is being run with the reader relaunch regression;
Plan UI now requires no stamp inside the contents page. Outside card/list rendering
continues using the shared Notes component without completion-state changes.

Outside-only verification: `build/sp-049/reader-restore-and-stamp.xcresult` passed both
the Plan contents/no-stamp journey and ordinary Scripture navigation/relaunch journey.
Signed build, signature/identity, in-place install and launch succeeded
(`build/sp-049/reader-position-outside-stamp-install.log`); this build also contains
the SP-009 startup hydration guard. Existing owner data preserved, version 1.3.2/build 27.
