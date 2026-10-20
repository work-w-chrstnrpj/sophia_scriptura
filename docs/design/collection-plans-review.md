# Collection Plans — source-grounded planning review

Date: 2026-10-19. Scope: SP-049–052 and their shared design; documentation updates only.
Status: findings addressed **in the proposed contracts**, not fixed or tested in app code.
All tickets became ready after the subsequent D1–D5 design resolution. SP-049 is now
implemented/simulator-verified; SP-050–052 remain unselected. The initial review did not itself establish readiness. The owner-confirmed checked
reflections, section-summary pause and Plan-named Pencil layers remain unchanged.

Review used exact current Collections commands/snapshot/schema, reader and annotation
sessions/renderer/repository, root routes/lifecycle, note creator and full-backup service.
Recommendations and gate checks are consolidated in the
[execution-contract addendum](collection-plans.md#review-addendum--execution-contracts-2026-10-19).
Priority describes implementation risk if the earlier ambiguity were followed.

## PRV-01 — Two Collections writers can overwrite unrelated edits

Priority: High. Evidence: [CollectionsStore.swift](../../application/SophiaScriptura/SophiaScriptura/Features/Collections/CollectionsStore.swift).
enqueueWrite, exportSnapshot, revision and Sophy commands already share mutable state. A second Plan snapshot/repository queue could save stale links/memberships.

Resolution carried into D1–D5: SP-049: one Collections writer, narrow typed transactions and stable intent/revision receipts; no second Plan repository.

## PRV-02 — Optional annotation protection fields would be ignored by older apps

Priority: High. Evidence: [AnnotationFileRepository.swift](../../application/SophiaScriptura/SophiaScriptura/Infrastructure/Annotations/AnnotationFileRepository.swift).
validate currently accepts snapshot schema 1. AnnotationLayer has no protection/owner metadata, and AnnotationSession exposes all source layers.

Resolution carried into D1–D5: SP-049/051: version every affected reader/archive path; preserve restrictions in fallback/detach and fail closed without the Plan.

## PRV-03 — Shared reader and shell callbacks can escape or corrupt Plan state

Priority: High. Evidence: [RootTabView.swift](../../application/SophiaScriptura/SophiaScriptura/RootTabView.swift).
Reader navigation persists normal position; root binds narration to that reader, activates editors by tab, and allows Companion/Sophy/Activity routes to change selection.

Resolution carried into D1–D5: SP-050/051: scoped location persistence and exclusive workspace/one native owner; arbitrate narration, routes, overlays and shared Companion drafts.

## PRV-04 — Creation callback is not proof a reflection was saved

Priority: High. Evidence: [StudyNoteDestinationPicker.swift](../../application/SophiaScriptura/SophiaScriptura/DesignSystem/StudyNoteDestinationPicker.swift).
NoteCreatorSheet.create returns an ID before awaiting Notes durability; Collections.flush waits a queue whose errors become notice text.

Resolution carried into D1–D5: SP-049/051: typed durable results, staged checkboxes and idempotent attachment; preserve access for saved orphan reflections.

## PRV-05 — Restore can proceed after a feature failed and replay stale intent

Priority: High. Evidence: [StudyBackupService.swift](../../application/SophiaScriptura/SophiaScriptura/Infrastructure/Backup/StudyBackupService.swift).
restore is sequential, uses notice strings for some outcomes and does not receive a typed annotation result. Original proposal exported pending operations without a replay boundary.

Resolution carried into D1–D5: SP-049/051: coherent export cut, typed preflight/results, checkpoints, inert imported reconciliation and no automatic mutation replay.

## PRV-06 — Plan title capacity contradicts exact layer naming

Priority: Medium. Evidence: [AnnotationFileRepository.swift](../../application/SophiaScriptura/SophiaScriptura/Infrastructure/Annotations/AnnotationFileRepository.swift).
Layer names are capped at 80 Characters; the original Plan proposal allowed 200. First Draw or rename could fail for a valid Plan.

Resolution carried into D1–D5: SP-049/051: 80-character Plan title/managed name, shared validation and Unicode boundary cases; no silent truncation.

## PRV-07 — Long Plans can exhaust global ink storage

Priority: Medium. Evidence: [AnnotationFileRepository.swift](../../application/SophiaScriptura/SophiaScriptura/Infrastructure/Annotations/AnnotationFileRepository.swift).
128 total groups/256 layers per group, including tombstones, and drawing size limits cannot guarantee annotations for a 2,000-item Plan.

Resolution carried into D1–D5: SP-051/052: capacity preflight and recovery UI; retain reading/checks, never evict drawings or silently expand storage limits.

## PRV-08 — Missing references must not invalidate a whole Plan backup

Priority: Medium. Evidence: [CollectionsStore.swift](../../application/SophiaScriptura/SophiaScriptura/Features/Collections/CollectionsStore.swift).
deleteLink permanently removes the saved link. Plans and backups may legitimately outlive referenced notes/links; strict target-existence validation would reject normal history.

Resolution carried into D1–D5: SP-049/052: distinguish corrupt identity from unavailable target; retain step/check with Replace/Remove/eligible Restore and audit bulk deletes.

## PRV-09 — A revision change cannot reuse old ink on new text

Priority: Medium. Evidence: [AnnotationRenderer.swift](../../application/SophiaScriptura/SophiaScriptura/Features/Scripture/Annotations/AnnotationRenderer.swift).
matches requires exact AnnotationSource and measured layout. Restoring/replacing content can leave a valid old binding that cannot render on the new chapter.

Resolution carried into D1–D5: SP-051: retain old ink unavailable; explicitly create a new current-source layer without remapping drawings.

## PRV-10 — Completion/save/load failure states were underspecified

Priority: Medium. Evidence: [ReaderSession.swift](../../application/SophiaScriptura/SophiaScriptura/Features/Scripture/ReaderSession.swift).
navigate can fail after a completion transaction already saved. Calling both failures unchecked would roll back legitimate progress; checked reflections/summaries also lacked deterministic traversal.

Resolution carried into D1–D5: SP-050: save failure differs from target-load failure; ordered navigation, summary cursor, review-only completed start and no stale implicit anchors.

## PRV-11 — Relock must not wait for disk or a continuing Pencil stroke

Priority: High. Evidence: [RootTabView.swift](../../application/SophiaScriptura/SophiaScriptura/RootTabView.swift).
protection.willLock is synchronous; AnnotationSession.prepareForNavigation can wait for a stroke/save. Deferring concealment through that path could retain private UI.

Resolution carried into D1–D5: SP-050/051: synchronous buffer capture and immediate concealment; retry dirty persistence without extending visibility/grants.

## PRV-12 — Intermediate tickets could expose an incomplete feature

Priority: Medium. Evidence: [CollectionDetailView.swift](../../application/SophiaScriptura/SophiaScriptura/Features/Collections/CollectionDetailView.swift).
SP-050 would add Start before SP-051 delivers requested Pencil/tools and their access guards; the draft readiness label did not state those launch gates.

Resolution carried into D1–D5: SP-049–052: keep all drafts, add per-ticket architecture gates and gate ordinary-build Start until integrated safety prerequisites pass.

## Review disposition and remaining gates

- All twelve findings have explicit design/ticket recommendations and acceptance coverage.
- Concrete schema/version/access representation, writer API, reader lease and restore
  checkpoints are now specified in the [selected implementation contract](../data/collection-plans-contract.md).
  Design gates are resolved; ticket code/evidence dependencies still execute in order.
- Annotation limits remain unchanged; broader store scaling is a separate owner decision.
- No independent Plan runtime database, second shared-session owner or general backup
  rewrite is authorized by these tickets.
- Physical Pencil/privacy/accessibility and real-provider observations remain execution
  gates. This review makes no native build/test/install/feature acceptance claim.

Verification for this review: local Markdown links/anchors, source paths, ticket criterion
identity/coverage and whitespace. See the ticket evidence notes and development tracker.

## Resolution status — ready, not implemented

Owner requested the remaining design choices be resolved. D1–D5 selects exact versions,
fields, transaction/result signatures, copied access requirements, mutation barriers, reader
event transitions, future file ownership and restore checkpoints. SP-049–052 are ready.
PRV findings are resolved at the contract level only; associated PA/PR/PT/PI cases must
prove the implementation later. No runtime defect is claimed fixed by this document.
