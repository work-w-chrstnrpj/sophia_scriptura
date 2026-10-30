# Collection Plans — implementation contract

Status: **SP-049 implemented and simulator verified; SP-050–052 ready and unselected**, 2026-10-20.
This document specifies the complete target. SP-049 now implements authoring and foundations;
see its ticket for actual evidence and the implementation notes below. Reader lease and
Plan-owned annotation v2 remain future SP-050/051 scope; readiness is not acceptance.
Technical authority: [TDD](../tdd/tdd.md#collection-plans--planning-baseline-sp-049052).
Behavior: [Plan design](../design/collection-plans.md). Review:
[PRV-01–12](../design/collection-plans-review.md). This contract supersedes earlier open
schema/API/access/lifecycle recommendations; unchanged behavior remains in the design.

## D1 — Schema and encoding

Keep the existing feature directories and immutable checked generations. No Plan database.
Version numbers below are chosen after inspection of the current readers (Collections 1–3,
Notes 1–4, annotations 1, full backup 1). New data never masquerades as an old schema.

| Payload | New write version | Read versions | Activation and retention |
| --- | --- | --- | --- |
| CollectionsSnapshot | 5 | 1–5 | Strict Plan ownership / grouped Trash; sticky after activation (legacy Plan format was v4) |
| Collections Pointer / Envelope | 2 / 2 for activated store | 1–2 / 1–2 | Both current/previous point to version-gated Plan payloads; old readers stop on unsupported |
| NotesSnapshot | 5 | 1–5 | First Plan-derived note/access requirement; sticky thereafter |
| Notes Pointer / Envelope (including Notes-only archive envelope) | 2 / 2 for activated store | 1–2 / 1–2 | Prevent old fallback from stripping new Collections-domain requirements |
| AnnotationSnapshot / Archive / Pointer | 2 / 2 / 2 | 1–2 each | First Plan-owned layer/operation/access requirement; sticky thereafter |
| StudyFullBackupEnvelope | 2 | 1–2 | Write v2 in the Plan-capable build; no version-1 export option |
| ReaderSnapshot / Companion / Activity payloads | Existing versions | Existing supported versions | No schema change for this feature |

A sticky store flag `planFormatActivated: true` accompanies new snapshots. Once set, emptying
Plans or restoring legacy data cannot reduce the store version. Legacy snapshots decode it
false. New-schema required arrays/fields must be present (empty is allowed); defaults apply
only to legacy versions. Unknown required kinds/versions reject the payload, preserving bytes.
Keep repository-local Date/Data encoding conventions; full-backup outer JSON uses existing
ISO-8601 dates. Codable keys and tagged kinds below are explicit, not synthesized enum shapes.
Access arrays encode as sorted unique UUIDs; order-bearing sections/items retain array order.

### Collections v4 records

Existing Collections fields remain. Add these required top-level fields:
`planFormatActivated`, `plans: [StudyPlan]`, `planOperations: [PlanOperation]`,
`commandReceipts: [StudyCommandReceipt]`, `retainedPlanAccess: [RetainedPlanAccess]`.

| Record | Fields and meaning |
| --- | --- |
| StudyPlan | `id`, `revision`, `materialsFolderID?`, `folderOwnershipConfirmed?`, `title`, `detail`, `sectionPrefix`, `preferredEditionID`, `referenceSystemID`, `sections`, `cursor?`, `access`, `createdAt`, `modifiedAt`, `archivedAt?`, `trashedAt?` |
| PlanSection | `id`, `materialsFolderID?`, `title?`, `items`; ordinal is derived from array position |
| PlanItem | `id`, `payload`, `completedAt?`, `origin` (`assignment` or `reflection`), `createdAt`, `operationID?` |
| PlanItemPayload | `kind`: `scripture`, `note` or `link`; scripture has `referenceSystemID`, `book`, `chapter`, `selection`; note/link has `targetID` |
| Scripture selection | Tagged `wholeChapter`, or `verseRange` with inclusive `startVerse`/`endVerse`; multi-chapter input is split before commit |
| PlanCursor | Tagged `item(sectionID,itemID,location?,editionID)`, `sectionSummary(sectionID)`, or `planSummary`; no positional array index identity |
| StudyAccessRequirements | `notesCredentialIDs: [UUID]`, `collectionsCredentialIDs: [UUID]`; both arrays required, empty means no inherited requirement |
| StudyCommandReceipt | `commandID`, canonical `intentHash`, `storeRevision`, `planID?`, `planRevision?`, `resultIDs`, `committedAt` |
| PlanOperation | `id`, `kind`, `planID?`, `affectedPlanIDs`, `anchorItemID?`, fixed `targetIDs`, `expectedPlanRevision?`, `access`, tagged `payload`, typed `phase`, `createdAt`; no provider secrets or note body |
| RetainedPlanAccess | `planID`, `lastTitle`, `access`, `detachedAt?`; survives purge while derived objects/unfinished detach depend on it |

PlanOperation kinds are `attachNote`, `createLayer`, `renameLayers`, `propagateAccess`,
`detachPlan`; phases are `prepared`, `targetCommitted`, `attached`, `needsReview` with
kind-specific payloads: attachNote stores section/item/note IDs and its citation reference;
createLayer stores exact source/layer ID/title/title revision; renameLayers stores target
layer IDs/title/title revision; propagateAccess stores source folder intent, affected Plan IDs
and derived target IDs/requirements; detachPlan stores derived target IDs and expected managed
states. All ID/reference fields are checked before a reducer may act. These are local recovery
records, not executable closures. Plan title revision uses the Plan revision of the rename
commit; later cursor/check commits do not imply another title update. A multi-Plan folder
barrier uses affectedPlanIDs; no single-owner assumption truncates its privacy scope.
Links and their Plan insertion share a Collections transaction, so no cross-store attachLink
journal is needed. A source PlanItem and a target NoteDocument never share identity. Derivation lookup uses
PlanOrigin/planOwnership in each feature, not an old journal or current Plan membership:
removing an item does not make orphaned derived objects undiscoverable to access propagation.

Selected validation: title 1–80 Swift Characters after trimming; detail at most 4,000;
sectionPrefix 1–40; custom section title 1–120 when present; at most 100 Plans including
Trash, 200 sections/Plan, 2,000 items/Plan. Collections encoded file remains at most 8 MiB;
byte budget is authoritative even below count limits. At most 128 unfinished operations;
refuse new operations at capacity with recovery guidance. Keep 256 recent receipts;
unresolved operations pin their receipt until resolved. No unbounded journal grows silently.
Plan/section/item UUIDs are unique across the Plan graph; expected IDs, revisions and enum
shapes are validated. Missing note/link or unavailable edition is a valid unavailable target,
not a malformed graph. No Plan nesting. Completion is derived, not another stored boolean.

### Annotation v2 and Notes v5 records

Add required `access: StudyAccessRequirements` and `appliedOperationIDs: [UUID]` to new
annotation layers; add optional tagged `planOwnership` containing `planID`, `creationOperationID`,
`managed` and `planTitleRevision`. The exact source remains AnnotationGroup.source; the
layer's existing layout/appearance/drawing/UUID stay owned by annotations. Collection Plans
query by ownership and exact source, so no second authoritative binding list lives in Plans.
An annotation operation ID remains while the layer is retained, including a deleted layer.
A UUID lookup projection may be cached in memory but never becomes an independent writer.
Retain at most 256 recent applied-operation IDs per layer, pinning unresolved ones; the
creation operation remains in ownership permanently. Rename title revision, access union
and managed-state checks make older resolved operations idempotent after receipt eviction.

A Plan-managed source has one live layer per Plan + exact AnnotationSource. First Draw
allocates operation/layer UUIDs before persistence. A retry queries the annotation owner
by operationID; it must find that layer rather than creating another. Historical source
revisions/deleted layers remain separately recoverable. If duplicate live bindings are
restored, expose recovery and do not choose one silently. Rename updates all managed layers
by Plan ID/title revision; normal layer menus cannot independently rename them. Permanent
Plan removal sets `managed=false`, retains owner identity/access/last label, and records detach.
Standalone explicit layer removal remains a guarded tombstone operation.

Add required `access: StudyAccessRequirements` and optional `planOrigin` to
Notes v5 documents. PlanOrigin contains `planID`, optional `creationOperationID` and
`managed: Bool`; its source ID survives operation-journal pruning. The original note retains
its creationOperationID for idempotent creation; copies clear that field but retain source
Plan ID/managed lineage and access, allowing later protection propagation to find them. Existing `protectionID` keeps its Notes-domain meaning. Legacy docs/layers
migrate with empty access and unchanged ink/body. Copying a Plan-derived note cannot impersonate the original retry target because its
creation-operation tag is cleared as specified above.
Existing note body/content format stays unchanged.
Adding `access` does not change what note.protectionID means or require a Notes grant
for a note with only a copied Collections-domain requirement. Saved links get access requirements and optional PlanOrigin in
Collections v4; existing links migrate empty. Private excerpts/previews are never copied into
Plan records. Validate required access/ownership in all inspect/export/restore entry points.

### Version activation and fallback

Activation is a feature-store operation, not a destructive reset: preserve original bytes
in an explicit pre-Plan recovery archive, stage/verify a converted current and safe previous
generation, then publish v2 previous/current pointers in that order. Prior to final current
publication the old committed generation is authoritative; no new protected feature is
advertised successful. On recovery, detect a partially activated pair and finish or report
repair without treating an old fallback as a public empty store. After publication both
automatic generations use the new format; checksum failure cannot fall back to schema-1
annotations or pre-Plan Notes/Collections. A missing/damaged pointer is not permission to
scan arbitrary historical generations. New readers propagate unsupported errors unchanged.

All subsequent fallback copies carry at least the union of current access requirements for
matching IDs, including retained owner records. Protecting an existing object must update
its safe fallback before publishing success. Legacy explicit restores merge current access
by object/owner ID before commit; they never clear it. Pre-feature archives remain private
historical recovery material, outside automatic fallback. No claim of encrypting these files
or revoking copies already exported by older software is made.

## D2 — Transaction and operation APIs

Proposed signatures below are API contracts to implement, not executable implementation:

```swift
@MainActor
func CollectionsStore.submit(_ request: StudyMutationRequest) async -> StudyCommitResult

struct StudyMutationRequest {
    let commandID: UUID
    let expectedPlanRevision: Int? // mandatory for an existing Plan mutation
    let intent: StudyMutationIntent // typed values, never a captured snapshot/closure
}

enum StudyCommitResult {
    case committed(StudyCommandReceipt)
    case rejected(StudyMutationFailure)
    case uncertain(commandID: UUID)
}

@MainActor
func CollectionsStore.receipt(for commandID: UUID) async -> StudyCommitResult
```

Intent cases: Plan create/edit/replace/reorder/move/check/reset/cursor/archive/Trash/restore/
purge/duplicate; atomic link-create-and-attach; prepare/update/finish recovery operation;
and existing Collections folder/membership/passage/link/conversation/Sophy mutations.
Failure codes: invalid, stale, accessDenied, unavailable, capacity, busy, unsupported,
persistence. A typed command carries fixed IDs and absolute values, never a relative
increment/toggle that changes meaning when repeated. Canonical sorted-key intent JSON
produces the receipt hash; same ID/different hash is rejected as invalid.

CollectionsStore owns one FIFO mutation executor and the sole committed CollectionsSnapshot.
Every repository.save caller (including duplicateCollection and Sophy commits) submits to
this executor. MainActor alone is insufficient because saves suspend. While its head awaits
repository I/O, other intents queue; no other command mutates the committed snapshot or
calls repository.save. At the head: inspect receipt, revalidate current access and affected
IDs, compare expected Plan revision, reduce against latest committed state, validate encoded
bounds, save with expected store revision, then publish the saved state and receipt together.
No success projection precedes durable receipt. Draft editor state stays local to its UI.

The receipt is inside the saved snapshot with the exact next store revision. Store revision
increments once per commit; Plan revision increments once for its content/progress/cursor
change. Journal-only phases do not invalidate an unrelated Plan revision. Automatic viewport
writes are coalesced on scroll idle and flushed before a structural/progress command; never
use them to check an item. A stale command has no side effect and UI may explicitly rebase.
Receipt retries return the original result even if newer Plan revisions exist. Explicit
rebase after a rejected stale intent uses a new commandID and the latest expected revision;
its operationID/target IDs stay fixed. Reducers reject a second attachment of the same
operation even if a receipt was pruned. Once an old
receipt is evicted, its old expected revision/target ID prevents a duplicate mutation;
unresolved-operation receipts cannot be evicted.

On uncertain publication, stop this queue, reload and verify the command receipt/current
revision. If found, return committed; if verified absent, return rejected(persistence); if
reading is inconclusive, remain uncertain/read-only and offer recovery. Do not retry an
ambiguous disk write as a new command or parse localized notices for correctness. Recheck
access after every await before disclosure. An already committed result is retained on
relock but its private UI is concealed; do not undo another successful command.

### Cross-store operations

NotesSession gains `createPlanNote(request) async -> StudyTargetCommitResult` and
`commitPlanEdits(noteID, token) async -> StudyTargetCommitResult`, plus
`applyAccess(request) async -> StudyTargetCommitResult`. AnnotationSession gains
`ensurePlanLayer(request)`, `renamePlanLayers(request)`, `applyAccess(request)` and
`detachPlanLayers(request)` returning the same typed committed/rejected/uncertain result.
Each target request has an operationID, fixed object IDs, source identity and access.
A committed result includes target IDs and feature revision, verified from that owner's
saved generation, never a created-ID callback or UI notice. Target owner serializes its
own writes. Idempotency tags are saved with the target. No Plan code edits target snapshots.

Note flow: (1) Collections durably prepares operation and fixed IDs/access; (2) Notes
creates the initial note and operation tag atomically with access, then editor accepts
changes through normal Notes ownership; (3) after confirmed saved editor return, Collections
attaches one checked item and marks the operation attached in one transaction. Folder
memberships for a new note are included in this final Collections transaction. Failure at
step 2 adds no Plan item; step 3 failure retains an accessible-by-policy orphan in Notes
with Retry attachment using original IDs. Cancelling before step 2 creates no note; closing
after creation preserves that note. Protected cancellation never drops its requirements.

Link flow: editor validates http(s)/host, then submit creates the SavedLink (with access),
folder memberships and checked Plan item in one Collections commit. Existing link selection
only creates a Plan reference. Existing note/link membership is never changed implicitly.

Ink/rename/detach flow: prepare → target-owner idempotent commit → confirm operation receipt
in Collections. On local restart, first reconcile saved tags; foreground Retry revalidates
access before finishing an incomplete action. No provider call is a recovery action. Rename
shows synchronizing/retry until affected layers confirm the new title revision; IDs/ink
remain unchanged. Reset cannot erase recovery or access metadata.

## D3 — Access binding and propagation

Use the existing device-only credential UUID and the independent `notes` / `collections`
grants. No new password, category, encryption or automatic grant is introduced.

| Object/action | Required checks |
| --- | --- |
| Plan projection/open/edit/play | Its persisted `access` plus every current membership/ancestor protection in Collections; any locked requirement conceals it |
| Existing note referenced by Plan | Plan access AND note.protectionID in Notes AND note.access AND note's existing folder concealment |
| Plan-derived note anywhere, even orphan/duplicate/export | note.protectionID in Notes plus note.access; creation copies source Plan collection requirements into note.access before save |
| Plan-owned or detached ink | layer.access plus live Plan requirements when Plan exists; no owner means retain copied requirements and show detached/recovery state, never infer public |
| Plan-created link outside Plan | link.access plus its current folder restrictions; attaching an existing link does not relax that link's own requirements |
| Export/restore/explicit access removal | Union of all participating requirements; authenticate before inspection/disclosure and recheck before return/commit |

Requirements are conjunctions: all UUIDs in both domain arrays must be unlocked in their
named domain. Unknown/deleted/mismatched credential UUID denies access even if another UUID
is unlocked. Empty live Plan membership does not erase persisted access. At Plan/layer/new-reflection
creation, union existing access with current protected Plan
memberships/ancestors. Referencing an existing material only adds the combined access check;
it never mutates that material's access capsule or folder memberships.
Unfiling, moving, archiving, Trash, folder/Plan purge and ordinary duplication do not subtract
it. A preexisting independently locked note remains independently locked; referencing it
does not copy its private contents or automatically require Notes unlock to read unrelated
Scripture steps. Hidden target details remain generic until the relevant grants exist.

Protecting/reparenting/filing a folder that contains Plans invokes a monotone propagation
barrier before publishing success. Persist `propagateAccess` with the union and affected
Plan/derived target IDs in Collections; pending requirements take immediate effect in all
sessions. Union the copied requirements into derived Notes/links/ink and safe fallback
generations, then finalize the folder mutation and finish the operation. If any target
fails, keep the barrier/restrictions active, show Retry and do not claim the folder change
succeeded. Never roll back a stricter access requirement to recover availability. A missing
note/layer stays unavailable; its retained ownership requirements remain in the journal.
Bulk folder operations and Settings lock-removal/cleanup use the same barrier path.

Plan-derived content with no live Plan uses its copied requirement capsule and retained
owner record. Purge sets managed ownership/origin false through owner commands, preserving
the independent access capsule. A still-managed layer whose owner is missing is quarantined
for explicit recovery/detach even with an empty capsule; a valid explicitly detached layer
uses its own capsule. No unlock credential is invented for an empty requirement set; ordinary non-Plan ink is not retroactively governed by Plan rules. A pending
propagation is exported only as inert affected-object/access data; safe restore takes the
union before exposing UI. Unknown or inconsistent association quarantines the dependent
object instead of granting access. Adding new derived content while a barrier is unresolved
is rejected busy. Runtime authenticity is the existing local app boundary; UUID metadata
is not a cryptographic authorization token.

Access removal is a separate fresh-authenticated management command using existing
confirmRemoval for every affected domain. It names the Plan/detached objects and previewed
scope, pauses edits, and updates copied requirements/fallbacks with a recovery operation.
No removal executes if another live protected source still requires that credential; only
source-lock removal or explicit authorized detach resolves that dependency. Until all
phases confirm, the restrictive union remains authoritative. Authorized removal is the
only exception to monotone union: a local typed removal receipt names exact requirements
and targets; rebuild both automatic fallback generations under that fresh grant before
committing the reduction. Imported receipts cannot authorize a reduction. This command is
necessary
maintenance for retained locks, not a new global unlock mode. Unknown credentials cannot
be adopted or cleared through reset. A missing retained owner does not invalidate a valid
independent capsule; missing capsule in a new-schema record is invalid and fails closed.

Relock/scene conceal: synchronously flush accepted native text/ink into owner memory,
invalidate workspace tokens, cover/unmount private views and clear protected selection/undo;
then persist dirty accepted data asynchronously. No disk/stroke await delays concealment.
Previously authorized dirty-save completion may persist accepted buffers without granting
new read/write commands; late callbacks cannot show private content or attach a new item.
Genuine input renews only the applicable current domain deadlines, never background retries.

## D4 — Reader and workspace lifecycle

One ReaderSession, AnnotationSession and current native reader surface remain shared.
Add a `PlanReaderLease` token to ReaderSession; this scopes routing/persistence, not a second
reader instance. Proposed API signatures (not existing source):

```swift
func beginPlanContext(_ request: PlanReaderRequest) async throws -> PlanReaderLease
func navigatePlan(_ target: PlanReaderTarget, lease: PlanReaderLease) async -> PlanLoadResult
func capturePlanLocation(lease: PlanReaderLease) -> ReadingLocation?
func suspendPlanContext(lease: PlanReaderLease, reason: PlanSuspendReason)
func endPlanContext(lease: PlanReaderLease) async -> PlanExitResult
```

PlanReaderRequest carries Plan/item IDs, preferred/session edition ID and resume location.
ReaderSession retains its ordinary committed ReaderSnapshot unchanged and uses a transient
working location/preferences/edition for the lease. `navigate`, `visibleLocation`,
`selectEdition`, `updatePreferences`, `save`, `resume`, annotation appearance and content-
refresh callbacks branch on the lease: Plan locations go only through Plan cursor commands;
Plan-local appearance/translation changes stay in the lease; the ordinary SwiftData snapshot
is not written. Normal Settings changes occur only outside the workspace. A source refresh
may invalidate the lease document but cannot reinstate expired licensed content. Global
preferences/source changes from an external lifecycle event are versioned and win over a
stale restoration copy. Do not call start() to reload the ordinary snapshot into a lease.

Root adds one `StudyWorkspaceRoute`: normal, Plan(sessionID), or meditation. An exclusive
lease acquisition captures origin tab/Plan detail, reader presentation, annotation selection/
mode and native callback owner IDs. Only that workspace's reader surface is mounted; the
ordinary reader and embedded Notes Scripture pane relinquish flush/undo/selection callbacks.
Notes editor in a Plan receives the lease for its optional Scripture pane, not a second
interactive Pencil surface. A modal note with native ink suspends the reader surface.
A single `PlanToolRoute` is none/note/link/Companion/music/outline; dismiss before presenting
another. Existing sessions retain their documents, streaming and audio engine ownership.

| Event | Ordered transition and result |
| --- | --- |
| Start/Resume | Validate Plan access and durable cursor; reject competing workspace; await ordinary Notes/ink flush; pause narration; acquire lease; suspend ordinary surface; load requested item; publish workspace |
| Item load failure | Show unavailable/error for that durable target, keep prior completion; Retry loads, explicit outline controls completion |
| Next | Await accepted target edits/ink with typed success; capture location; submit check + next cursor/summary atomically; only committed receipt triggers load/presentation |
| Previous / outline | Flush accepted edits; persist new cursor without changing checks; then load it |
| Tool open/close | Flush active native owner, transfer callback/input ownership; return only after editor typed save succeeds; never reset current passage/check |
| Relock/background | Capture accepted buffers, immediately conceal/suspend lease and invalidate load/tool tokens; best-effort save cursor without a new completion |
| Foreground | Revalidate grants, operation barriers, source availability and cursor revision; reacquire a fresh token and restore current Plan target/summary without auto-continuing |
| Process relaunch | Load committed Plan cursor into detail with Resume; no automatic protected fullscreen launch; section summary survives subsequent Resume |
| Explicit Exit | Await ordinary editable buffers, persist cursor (no check); if save fails offer Retry or Stay; invalidate lease/load tokens; restore normal reader from latest valid ordinary state and origin detail; do not auto-resume narration |
| Privacy-forced exit / Plan Trash | Conceal immediately; retain dirty accepted owner state for retry; no requirement to expose private UI until disk succeeds |
| Restore/uncertain store | End interactive lease, block writes, recover under backup coordinator; no stale pre-restore callback may resume Plan |

Normal routing while a Plan owns the workspace is centralized: Companion/Notes/links stay
embedded; unsupported Sophy/quiz routes show Exit Plan first; retain the latest Activity
system deep link in memory, then offer Open Activity after exit (no surprise auto-navigation).
A second Plan/meditation launch is rejected busy. Activity timers/music continue; hide their
duplicate floating chrome but keep the bottom music command. PiP/remote audio commands keep
the existing audio owner. Plan narration controls are disabled in v1; entry pauses narration
without changing music's user intent. Companion opens an existing busy conversation read-only
or lets the user explicitly choose a new one once the stream is idle; never replace/send a
draft automatically. Scene flags use workspace ownership and actual phase, not tab alone.

Navigation waits for a live stroke only during user-driven ordinary transitions. Privacy
suspension captures/cancels the native interaction immediately; it never waits for the pen
to lift. On every await check sessionID, leaseID, Plan revision and protection epoch. Exit
restoration checks those tokens too. Restore ordinary annotation mode only if its original
layer/source/access still resolves; otherwise normal Read Hidden with retained ink.

## D5 — Backup cut and sequential restore

SP-049 introduces a shared `StudyBackupLease` mutation barrier: close active editor/Plan
or explicitly finish accepted buffers, block new commands in participating sessions, drain
writer queues and capture immutable revisions. Encode Notes/annotations/Collections/
Activity/Companion from that cut, then recheck all grants before returning bytes. Reject
export preflight as busy while a Companion response is actively streaming, rather
than capture partial output or buffer unbounded deltas. Other bounded writes queue behind
the lease and resume after export. An Activity timer keeps running from its existing start
time; capture its projection at the cut without stopping or fabricating a record. Do not
hold the lease across a system file picker or network request; encode immutable data, release,
then present Files. The bound is local disk encoding; failure releases the gate safely.

Full backup v2 includes `revisionVector` entries with feature ID, schema version,
optional native revision and canonical payload SHA-256 (Activity has no revision counter),
normal existing payloads and inert `planRecoveryRecords`. Sanitize executable local `planOperations`/receipts out of
the exported Collections projection; preserve affected IDs and access unions as inert data.
No command receipt from another backup constitutes a live operation authorization.

Restore pipeline: decode/validate every envelope, checksum, bounds and credential/graph
requirement before mutation → acquire backup lease → save pre-restore archives for all
participating features → durably write local `StudyRestoreCheckpoint` schema 1 → restore
Notes, annotations, Activity, Collections, Companion and optional Sophy history in that
order → verify typed revision results and graph quarantine → commit checkpoint complete.
Feature restore APIs return typed success/failure/revision results; no localized notice
comparison. Keep existing target-specific preservation behavior behind those result APIs.

Checkpoint is local operations metadata under Application Support/StudyRecovery/ (test root
uses SP009_TEST_STORE): checkpoint UUID, imported payload hash, retained staged payload path,
pre-restore paths/hashes, completed feature phases, target revision/hash vector,
mode (`resumeImport` or `restorePrevious`) and phase. Choosing the previous-state path
starts a new checkpoint mode with its own verified per-feature target hashes. Files
are size checked, owned regular files; exclude checkpoint/staged payloads from exported
archives. It is neither a runtime backend nor a second study data source. Atomic file
publication and immutable staged input make Resume recovery idempotent per checkpoint.

On failure stop before the next phase and expose Resume recovery or Restore previous study
state. Both paths require grants and the same lease, and use per-feature typed results.
Do not claim cross-feature atomicity; quarantine inconsistent references and hold dependent
commands until recovery concludes. A crash after a phase commits but before checkpoint
advance is reconciled from its target revision/normalized-target hash, not replayed blindly.
A target hash uses canonical
sorted-key JSON after access merging, excluding only store revisions and restore-generated
metadata, preserving note body/ink/access/content timestamps. Owners without native command
receipts verify that semantic hash on disk before a completed phase is recognized.
Legacy full backup v1 is accepted by normalizing missing Plans/access to empty, then merging
current required access for matching IDs/owners; preserve sticky format versions. New/old
annotations-only and Notes-only restores use the same access union and version checks.
Imported incomplete operations remain inert/needsReview; explicit foreground action may
attach an already saved target after validation, never automatically create/send/rename/
detach. Interrupted access propagation restores its restrictive union before showing UI.


## Selected module interfaces and file ownership

The following are selected **future paths**, not files created by this planning change.
Paths are relative to application/SophiaScriptura/SophiaScriptura/.

| Path | Owner and responsibility |
| --- | --- |
| Core/Plans/StudyPlan.swift | Pure D1 Plan/section/item/cursor and validation values; no UI/storage imports |
| Core/Plans/PlanCommands.swift | Typed intent/request/receipt/operation/result values for D2 |
| Core/Security/StudyAccessRequirements.swift | Shared domain access value used by Notes/annotations/Collections; no Plan UI dependency |
| Features/Plans/PlanCommandService.swift | Build Plan intents; delegate to CollectionsStore.submit, no repository/snapshot ownership |
| Features/Plans/PlanPlaybackCoordinator.swift | D4 cursor/transition/tool state and lease tokens |
| Features/Plans/PlanReaderWorkspace.swift and PlanEditorView.swift | Fullscreen reading/tool shell and authoring views |
| Features/Plans/PlanStudyTools.swift | Typed Notes/annotations/Companion/music adapters with injected owner ports |
| Features/Protection/StudyAccessCoordinator.swift | D3 feature-port propagation/removal orchestration; ItemProtectionSession remains grant owner |
| Infrastructure/Backup/StudyRestoreJournal.swift | D5 local checkpoints/staged-input hashes; no study commands or provider access |

Modify existing CollectionsStore/CollectionsFileRepository and domain snapshot for the
single writer/schema, NotesSession/NotesFileRepository/NoteDocument for typed access-aware
notes, AnnotationSession/AnnotationFileRepository/AnnotationModels for v2 owned layers,
ReaderSession/RootTabView for the lease/workspace, and StudyBackupService for v2 and typed
restore ports. Existing public command wrappers keep their UI-facing behavior while
submitting through the sole executor; test every direct writer call site in SP-049.
No domain type imports Features or Infrastructure. Core/Security is a selected new directory;
its source/agent maps are updated when implementation actually creates it, not now.

## Delivery ownership and readiness

| Ticket | Contract ownership and prerequisite |
| --- | --- |
| SP-049 | D1 Collections v4 and Notes v5 access foundations; D2 sole Collections writer/target commit interfaces; D3 shared access values/note/link creation and propagation interface; D5 backup lease/v2/checkpoint/result foundations. Plan-derived ink targets remain disabled until SP-051. No dependency on a future implementation decision |
| SP-050 | D4 exclusive reader/workspace lifecycle and typed Next save/load sequence using SP-049 receipts; internal acceptance route only until SP-051. Depends on SP-049 implementation |
| SP-051 | D1 annotation v2 activation; D2 target operations/tags; D3 ink/note/link access propagation/removal and all guarded annotation/export routes; embedded study tools using D4; completes D5 graph/access recovery. Depends on SP-049/050 implementation |
| SP-052 | Executes PA/PR/PT/PI and D1–D5 compatibility/concurrency/privacy/lifecycle cases; physical/provider results remain separate. Depends on SP-049/050/051 implementation evidence |

Ready means requirements and design choices are sufficient for implementation planning;
prerequisite implementation tickets still execute in order. It does not mean tests passed,
app code exists, or owner selected execution. SP-049 is now **implemented and simulator verified**; SP-050–052 remain **ready; implementation
unselected**. No schema migration, release/version assignment, signing/install or runtime
change is performed by resolving this contract. Owner correction (2026-10-20) permits basic Start/Resume through the existing reader
before SP-051 tools; overall milestone acceptance belongs to SP-052.

## SP-049 implementation notes — local source, simulator verified

Implemented paths: Core/Plans/StudyPlan.swift and PlanCommands.swift;
Core/Security/StudyAccessRequirements.swift; Features/Plans/PlanCommandService.swift,
PlanEditorView.swift, PlanAssignmentPicker.swift and PlanLifecycleLibrary.swift.
StudyRestoreJournal.swift owns inert local recovery metadata, and existing feature owners
provide typed restore results. No file in this table implies future playback/Pencil exists.

Compatibility adaptation: existing synchronous Collections UI methods keep their optimistic
published view state. A private CollectionsLegacyPatch is a typed value delta encoded as
Data only for the internal mutation request adapter; the sole executor reduces it against
its committed snapshot. Direct Sophy/folder/restore saves are routed through that executor.
Plan editor/target success remains receipt-based. This preserves established UI call sites
and tests without a second writer or replacing feature stores.

The current operation record reserves typed source/section/title/target fields; managed
annotation operation execution/association schemas remain SP-051. Authoring-created notes
and links are unchecked assignments, while checked reading reflections remain future scope.
Access removal/managed ink propagation are not exposed prematurely. Basic Start/Resume is available through the existing reader after the 2026-10-20 owner correction.

Recovery encoding note: the current journal groups immutable imported/prior payloads by
input SHA-256. Choosing previous state restores that immutable prior envelope under its
own input hash, then resolves the original checkpoint. Its prepared/committed semantic
phase hashes, completed-phase list and completion marker provide the local recovery state;
full native revisions/hashes remain in backup revisionVector. Imported active-operation
records never become a live executor journal. Inconsistent copied-access requirements on
present derived targets fail preflight; missing targets remain inert recovery references.

### Owner correction — content-first opening and basic playback (2026-10-20)

PlanDetailView opens Plan contents and keeps Edit separate. Start/Resume uses the existing
ReaderSession and ReaderTextSurface, persisting completion/cursor through revision-checked
Collections commands. Next pauses at section summaries; Previous preserves checks.
Unavailable or locked assignments cannot be completed through Next. No storage version
changes or separate app mode are required. This bounded correction does not implement
the D4 exclusive-reader lease, normal-position restoration, Plan ink or embedded creation
tools; those remain later workspace/tool acceptance. Basic reading updates the shared
reader position as ordinary navigation does. Backgrounding exits the transient reading
view; Resume reloads its persisted assignment.

### Fullscreen tools implementation note — 2026-10-20

PlanReflectionDraft coordinates one retained-ID user creation attempt. Notes targets
commit through createPlanNote using chosen type/color and an attachNote operation;
links commit through saveLink. Only afterward does a revision-checked savePlan insert
a checked reflection, after earlier reflections of the same current item. A failed
attachment leaves the target available for deliberate recovery; no automatic replay
or deletion occurs. Newly inserted reflection target memberships are added from the
Plan's memberships in that same Collections generation. No data version changes.
Shared Notes presentation ownership is transient; the existing editor/file repository
retain content and save ownership. This does not claim all interruption/recovery or
Plan-ink propagation cases are accepted.

### SP-049 editor structural stability correction — 2026-10-20

The editor renders section/item value snapshots and applies structural commands by UUID.
Removed-row title bindings and stale reorder snapshots cannot address another item.
Deleting a target clears its invalid cursor and transient picker/reset route; removing
an assignment keeps the original Note/Link. Canceling replacement clears that route.
A multi-chapter replacement keeps the first assignment identity, clears its completion,
and inserts all additional chapter assignments in order. None of these corrections
changes persisted schemas. See the [investigation](../testing/sp049-plan-stability-investigation.md).

## SP-053 additive editing and optional material filing

`StudyPlan.materialsFolderID: UUID?` defaults to nil when absent. Collections v4,
pointer and backup versions remain unchanged. Copies clear the ID. Ordinary saves
preserve nil; choosing existing assignments or Scripture does not require a folder.
PlanEditorView owns optional existing/new/none choices inside Edit through
PlanLinkedFolderPicker. The content view does not display this configuration.

`createPlanMaterialsFolder` creates/links a folder atomically with a receipt and a Plan
revision update. Automatic calls reuse an existing link; explicit Create and link can
replace it with a newly named folder. `filePlanMaterial` checks target/folder access and
acknowledges note filing after the Notes repository save. Both PlanAssignmentPicker and
PlanReflectionDraft ensure a folder only when creating a new note/link. New links commit
the target and membership together. A new automatic folder uses the Plan title and source
collection as parent (nil for virtual No Folder). Existing folder metadata is untouched.

Plan saves add shared memberships for linked materials and reference-only Scripture
projections. No body is copied. Unlinking clears only the pointer, keeping folders,
materials and memberships; inherited access restrictions are not relaxed. New material
after unlink creates a new folder instead of rediscovering an old one by name. Moves
preserve the UUID link. The previous SP-053 binary's always-create behavior is superseded;
reinstalling that older binary would not honor an intentionally empty link on save.

PlanEditorDraft owns debounced immutable snapshots and drains edits made during writes.
CollectionsStore checks expected revisions and returns receipts. Editor creation callbacks
adopt the checked folder revision before adding the assignment. In-flight folder choices
remain in the next snapshot instead of being replaced by an older write completion.
Failed or invalid saves retain the draft with visible feedback.

SP-053 inline editing: PlanDetailView owns a transient PlanEditorDraft while rendering
the shared PlanEditorView inline. Done and Exit await persist; failure retains edits.
The existing debounce, revisions, receipts, folder behavior and file schemas are unchanged.

### Day/Section hierarchy — SP-053 follow-up

`PlanSection.materialsFolderID: UUID?` decodes nil for previous stores; Collections
v4 and backup versions stay unchanged. The sole writer creates managed children below
the linked root, reusing committed section IDs and folder IDs when still under that
root. New Plan/section copies clear these IDs. Names follow section custom title or
prefix/ordinal. The root holds the same Plan record; section folders hold shared target
IDs or reference-only Scripture PlanItem IDs. No duplicate Plan or study bodies.

On save/ensure, known current assignment edges previously flat at the root are moved
to section folders, preserving unrelated items and other folders. Section moves remove
the prior managed edge only when that target remains assigned elsewhere. Removed
assignments/sections keep prior contents; unlink/relink keeps old trees and inherited
access. Moved-away child folders are retained and a fresh child is created under the
current root. `filePlanMaterial` includes sectionID; note/link creation uses its child's
checked destination, before attachment. Folder mappings and revision changes commit
together. Access preflight validates every affected active folder/ancestor before publish.

Old binaries can decode the optional field but cannot preserve this organization on
subsequent editing. No reset/migration command or content deletion is required.

## Strict ownership and grouped Trash — superseding SP-053 optional-link rules

Collections v5 adds required `planLifecycleActivated: Bool` and
`planTreeTrash: [PlanTreeTrash]`. Activation is sticky through save/restore; v1–4 decode
with no bundles. Repositories and full-backup inspection support v5; envelope/pointer
v2 remain, with fallback payloads promoted and the original pre-lifecycle envelope
retained. Older binaries reject v5 rather than stripping deletion records.

New Plan saves create a dedicated root. Existing root identity becomes immutable; nil
and replacement saves reject. Older records are adopted on save/accessible startup,
with missing/shared roots replaced by dedicated roots. Section organization is retained.
The folder reference is read-only in Edit. SP-055 makes the root name follow the Plan
title; custom descriptions, accent and location remain Collection properties. Main progress uses completedSectionCount; nonempty/all-checked means complete.

`setPlanTreeTrashed` computes the owned subtree, including nested Plan roots. Both
Plan/folder routes use it after confirmation. Shared edges/references outside this group
(including archived/trashed folders and Plans) preserve their target records. Exclusive
links, passages, saved annotation references, conversations and points move to a typed
bundle; note IDs go to Notes-owned Trash. Source scripture and annotation ink stay with
their owning features. The bundle retains IDs, original Collections records, timestamp
and a pending Notes action. Collections commits before Notes mutation; a pending phase
is visible/retriable and reconciles on launch/foreground. A failed first commit never
changes Notes. Idempotent Notes trash/restore preserves newer independent Trash choices.
Companion-owned conversations use the same durable completion boundary when present.

Restore either group side restores retained folders/parents, Plans and exclusive records;
shared records are not overwritten. Permanent purge/expiry removes the Collections group
and retains copied access requirements; Notes uses its independent 30-day retention.
Backup/export and restore check archived link access as well as active material.

A per-Plan optional `folderOwnershipConfirmed` marker distinguishes untouched legacy
records during a multi-Plan upgrade. The writer sets it after adopting a root; subsequent
root replacements/clears reject. This avoids global activation skipping another legacy
Plan that still needs a valid folder. It is reset when duplicating a Plan.

### Scripture assignment edit command — SP-053

PlanScriptureEditTarget resolves an accessible active Plan/section/Scripture item by
stable ID. PlanCommandService.replaceScripture checks its expected revision, target
kind, reference system and capacity, then uses the existing savePlan transaction and
passage validator. First replacement keeps item ID; extra chapters get their own IDs.
Changed completion clears, unchanged selection and unrelated completion remain. Section
folder projections derive updated references from the committed Plan. Errors keep the
editor open; no additional persistence format is introduced.

### Additive playback/schedule values — SP-054

No envelope/schema version changes. StudyPlan adds optional activityModeID (nil → Reading)
and strictSchedule (nil → dates off). PlanSchedule stores optional startDate and timeZoneID;
missing startDate anchors to first Play. Calendar arithmetic uses Gregorian days in that
zone, including DST transitions. PlanSection adds optional dueDate values (legacy manual
values remain readable; SP-055 writes them through Catch up rather than per-section inputs). Completion
dates are derived from item completedAt, so editing/resetting progress cannot leave a stale
saved completion timestamp. Strict off hides all schedule captions, including old overrides.

PlanCursor adds optional activitySessionID. ActivityDraft and ActivityRecord add optional
planID/planSectionID; absent keys remain nil. Existing store/export codecs preserve these
fields on current-source round trips. Older code ignores unknown keys and can lose the new
settings if it rewrites; old mandatory fields and on-disk schemas are unchanged.

PlanPlaybackService writes cursor/progress only through CollectionsStore.submit. It starts,
pauses and finishes through awaited ActivityStore commands. The last assignment first
saves a sectionSummary with session identity, then commits Activity History. Failure
leaves a retriable summary/draft; retry checks the exact History ID before writing. A
Plan activity stopped through ordinary Activity only pauses its draft, without History or
unchecked-item completion. The Plan finish command requires every assignment in its section
to be checked. Reconciliation can recover an already-checked day; legacy partial History
cannot check unfinished assignments. Reset clears the cursor, preventing old History from
replaying completion. Unrelated
drafts reject Play. A completed day never automatically starts another timer or section.

### Catch up and managed root naming — SP-055

Catch up is an explicit optional Edit action available only with a strict schedule and an
overdue unfinished assignment. It assigns today in the stored calendar/time zone to the
first unfinished section and one subsequent calendar day to each remaining unfinished
section, in Plan order. Completed sections retain their dates. Item completedAt, section
identities, assignment order and cursor are unchanged. The existing optional section
dueDate key persists results, so no schema bump, reset or conversion is needed. Merely
opening Edit or checking availability never changes dates. Captions in Edit and contents
share due/completion derivation; partial days have no completion date.

The root folder name is synchronized atomically inside the existing Plan transaction.
Root identity/location and custom descriptions are preserved. Startup/foreground adoption
also submits a checked save for an accessible Plan whose root name differs, repairing
older partial-title roots without replacing folders or materials. Existing History records
are retained; this ticket changes future Plan stop/completion commands, not past records.

### Selected Day playback and retained timers — SP-056

`start(planID, sectionID:)` selects a stable section identity; nil preserves main Play/Resume.
Invalid/empty targets reject before progress/timer mutation. A valid stored item cursor
resumes inside that Day; otherwise its first unfinished item is selected. An explicit
completed-Day selection starts a reread; existing completion timestamps remain. The finish
command still requires all Day assignments to be checked and commits a single History ID.

Activity schema 1 adds optional pausedPlanDrafts (nil in legacy stores). Same-Plan switches
pause/save the outgoing draft and resume/remove the selected retained draft in one awaited
Activity write; there is one running draft. Session/Plan-Day keys must be unique across
active/paused drafts and cannot collide with History. Paused timers have no runningSince.
Current backups retain the optional field; older readers can ignore/drop it on rewrite.
Overlap detection and mode migration include retained drafts; Delete All Activity clears
all drafts. No one-time conversion or schema bump is required.

Plan contents expose one date caption per Day and no aggregate footer. Title labels contain
no dates. Edit keeps the Plan summary and Day captions. These are presentation changes;
schedule and catch-up values are unchanged.
