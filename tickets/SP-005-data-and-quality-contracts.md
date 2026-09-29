# SP-005 — Data, recovery, and quality contracts

- Type: planning. Status: in progress — reader slice complete; remaining feature slices blocked. Owner: System Architect.
- Requirements: REQ-004, REQ-007, REQ-008, REQ-017, REQ-018, REQ-019.
- Dependencies: SP-002 content policy and SP-003 layout identity are complete for the
  reader slice. SP-004 note geometry and later feature decisions still block the
  remaining Notes/ink/media, collection, recovery and export contracts.
- Design: [TDD §7 and §14–16](../docs/tdd/tdd.md#7-data-model),
  [development plan](../docs/development-plan/development-plan.md).
- Affected later modules: stores, passage queries, backup/import, test fixtures.

## Purpose and scope

Make the first daily-use milestone safe to implement with explicit contracts and
verification. Early outlines can proceed while dependent choices remain unresolved.

## Work

1. Define passage/chapter/range identity, source edition/versification, overlap queries,
   collection membership, deletion, and missing-target behavior.
2. Define note/page/object geometry, file references, metadata/file save recovery,
   schema versions, migration policy, and attachment cleanup.
3. Define export manifest, content-policy exclusions, secrets exclusion, integrity checks,
   damaged/unsupported imports, and rollback without replacing good data prematurely.
4. Specify automated fixtures, manual device cases, and actual Xcode/simulator selection.
5. Derive small implementation tickets linked to all required contracts and tests.

## Acceptance and verification

- Every persisted entity has ownership, identity, relationships, and deletion/recovery rules.
- Export/restore tests cover notes, ink, images, links, collections, and source references;
  restricted content and secrets are handled explicitly.
- Tests cover corrupt archives, interrupted saves, and failed import preservation.
- Ready implementation tickets have no unresolved dependencies hidden as assumptions.
- Tests are planned here; passing results require later executable implementations.

## Outputs and boundaries

Create a data/recovery contract when its inputs stabilize, update the existing testing
and deployment guides, record architecture
choices and necessary relationship/flow diagrams, then update the TDD and ticket index.
No migrations or user-data mutation are part of this planning ticket.

## Execution contract

Planning work only in the current stage. No implementation completion is implied by
this ticket. Record unresolved items explicitly. Do not create provider accounts,
accept agreements, purchase access, or obtain credentials on the owner's behalf.

## Reader-slice evidence — 2026-09-22

The accepted [Scripture reader data contract](../docs/data/scripture-reader-contract.md)
defines edition/revision/reference identities, bridge and omission mappings, range
overlap, bundled read-only SQLite ownership, reader progress/preferences, explicit
restore fallback, typed repository failures and twelve planned contract cases.
[SP-009](SP-009-first-offline-scripture-reader.md) is the resulting ready product ticket.

This evidence completes only the reader portion of SP-005. The twelve checks are planned,
not passed, until SP-009 supplies executable implementations. Notes/ink/media atomic
commits, collection membership/deletion, complete Files export/restore, migrations and
representative-scale recovery remain unresolved. Unperformed checks stay unperformed.

## SP-006 closure input

The owner closed SP-006 with limitations. Its JSON roundtrip/damaged-restore evidence
and bounded physical memory observation inform contracts but do not prove full backup,
large-note capacity or final migrations. Production contracts and implementation tickets
must include integrity/recovery and representative-scale checks for actual supported data.
