# SP-052 — Collection Plans integrated acceptance and recovery

Status: **ready for implementation; implementation unselected** (2026-10-19).
Type: integrated acceptance and verification proposal.
Milestone: proposed post-baseline **Collection Plans**; no release/version assigned.
Owner: SQA Engineer; Technical Documentation Specialist; feature owners fix only scoped findings.
Authorization: documentation/ticket creation only. Before execution, announce this ticket,
visible outcome, exclusions, affected modules and checks; owner selection is required.

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

SP-049, SP-050 and SP-051 implementation evidence, final schemas/access contract,
and an owner-authorized device build if physical execution/install is requested later.
This ticket does not authorize release, installation, unrelated features or data resets.


### Resolved implementation contracts

[Selected D1–D5 contract](../docs/data/collection-plans-contract.md) closes the former
schema, transaction, access and lifecycle design gates.

Trace D1–D5 and PRV-01–12 to PA/PR/PT/PI evidence. The selected schema/API/access/reader
contracts are resolved; implementation of SP-049/050/051 and its evidence remain prerequisites
for executing this verification ticket. A readiness label is not test evidence. Execute
the selected version matrix, concurrent writer, protection, reader lease and restore
checkpoint cases without inventing another architecture phase.

## Visible outcome

A verifiable end-to-end Plan journey covering authoring, focused reading, checked
reflections, section pauses, real Pencil layers, relaunch, protected data and recovery.
Acceptance records distinguish automated, physical and live-provider observations.

## Implementation sequence and failure handling

1. Convert all PA/PR/PT criteria into traceable automated/manual cases with fixtures,
   expected results and isolated store setup. Retain IDs and report Pass/Fail/Blocked/
   Not Run individually; do not infer acceptance from planning documents.
2. Run targeted domain, Collections, Notes, annotations, protection, reader, Companion
   mock and backup tests, then the applicable full native unit suite after fixes.
   Use the current test-specification command/installed simulator, not a hardcoded device.
3. Run focused UI journeys: author → start → draw → create reflection → Companion →
   Next → section summary → Continue → exit/relaunch → reset → restore backup.
4. Exercise deterministic fault injection for save failures, interruption between
   feature commits, stale callbacks, relock, invalid references and partial restore.
5. Prepare and execute physical cases only when device execution is authorized. Include
   real Pencil alignment/palm rejection/undo, portrait/landscape/Split View, light/dark
   presets, large text, VoiceOver, Reduce Motion, link return and background interruptions.
6. Validate actual configured-provider disclosure/response and audio coexistence only
   when explicitly exercised; mock success is not real-provider evidence.
7. Reconcile implemented behavior with TDD/design/data/security/test/source-map docs.
   Record remaining gates and return control to the owner without starting release work.

## Module ownership and dependency direction

Native target paths below are relative to the repository root.
Native targets: application/SophiaScriptura/SophiaScripturaTests/ and
application/SophiaScriptura/SophiaScripturaUITests/. Add focused Plan tests rather than tests mirroring private code.
Proposed docs/testing/collection-plans-ipad-guide.md and an acceptance evidence record
are created with real cases during execution. Feature owners retain implementation
ownership; QA reports concrete failures without silently expanding ticket scope.

Views → Plan coordinator/commands → owning feature sessions/repositories. Domain values
must not import UI/provider services. No new backend or replacement shared database.
Read exact current sources before editing; proposed directories are not implemented paths.

## Acceptance criteria

- PI-01: Every PA/PR/PT criterion maps to evidence or a named unresolved gate. Failing
  safety/durability/access criteria prevent the Collection Plans milestone closing.
- PI-02: Exact owner example works with a checked reflection inserted after Mark 2:4–8;
  repeated passage visits retain the Plan layer and section summary always pauses.
- PI-03: Upgrade from existing no-Plan fixtures preserves all prior material/protection;
  full backup round-trip preserves Plan IDs, progress, summaries and bound drawings.
- PI-04: Representative D1 maximum-size/count/byte-boundary Plans remain usable,
  including batch authoring and outline navigation. Changes to selected limits need
  explicit scoped documentation and tests; no limit decision is left unresolved.
- PI-05: Physical Pencil/accessibility/provider checks each have observed results or
  explicit Not Run/Blocked status. Build/sign/install is never substituted for them.
- PI-06: Documentation links and git diff whitespace checks pass; ticket/index/tracker
  statuses agree. Release/version/install remain unselected until owner authorization.

- PI-07: Run boundary fixtures for 80/81-character Unicode titles, 128/129 groups,
  256/257 layers with tombstones and drawing size ceilings; compare with existing non-Plan
  annotations and verify safe recovery without eviction or unchecked global limit changes.
- PI-08: Exercise concurrent Plan/folder/link/Sophy writes, ordinary reader/narration
  restoration, all shell escape routes and shared Companion draft/stream ownership.
- PI-09: Old/new snapshot/archive/fallback combinations and interrupted restore prove
  required access metadata cannot disappear. Restored pending operations do not execute;
  protected orphan note and missing-layer/Plan references remain safely recoverable.
- PI-10: The review findings PRV-01–12 have a source/test disposition, and ordinary-build
  Basic Start/Resume is enabled by the 2026-10-20 owner correction; full workspace/tool acceptance remains separate.

- PI-11: Validate the full D1 read/write/activation/downgrade/explicit-restore matrix,
  including interrupted pointer activation and schema-required-field rejection. Verify
  count and encoded-byte limits with maximum-size fixtures.
- PI-12: The D2–D5 fault matrix covers every commit/checkpoint phase, loss of access and
  each reader lifecycle transition. Report actual automated/device/provider results
  separately; all four tickets remain unselected until owner execution authorization.

## Exclusions

No schedules/dates/reminders/streaks, imported/public Plans, sharing format, AI-generated
Plans, automatic narration advancement, automatic Activity metrics, new provider, unrelated
refactor, release/version bump, signing/install, secret changes or destructive migration.
The other Plan tickets own their separate outcomes; starting this ticket does not select them.

## Verification and evidence

Use [current native test instructions](../docs/testing/test-specification.md) and
[device guidance](../docs/deployment/deployment.md). Plan tests should verify user-observable
invariants, compatibility and fault boundaries; no tests are run for ticket authoring.
During implementation retain result bundles/logs in ignored build/sp-052/.
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
