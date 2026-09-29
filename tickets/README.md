# Sophia Scriptura Tickets

Tickets connect [requirements](../docs/product-specification/product-specification.md)
to [technical intent](../docs/tdd/tdd.md), acceptance criteria, and verification evidence.
Current milestones are M0–M9; feature phases M2–M8 follow the owner's order.
Milestone ordering lives in the [development plan](../docs/development-plan/development-plan.md).

| Ticket | Current status | Work |
| --- | --- | --- |
| [SP-001](SP-001-product-and-device-decisions.md) | in_progress | Full-design reconciliation and owner scope/device decisions |
| [SP-002](SP-002-free-scripture-access.md) | done | WEBP baseline verified; preferred editions conditional; import plan documented |
| [SP-003](SP-003-scripture-ink-layout.md) | done | Renderer/layout decision and native validation plan; no implementation |
| [SP-004](SP-004-freeform-notes.md) | in_progress | Expandable canvas selected; editor interaction design |
| [SP-005](SP-005-data-and-quality-contracts.md) | in progress; reader slice complete | Data, recovery, and testing contracts by feature |
| [SP-006](SP-006-native-canvas-experiment.md) | done | Bounded canvas experiment closed with owner-approved deferred checks |
| [SP-007](SP-007-collections-ui-slice.md) | done | Bounded Collections prototype; simulator and physical UI verification passed |
| [SP-008](SP-008-scripture-layout-validation.md) | split; not selected | Annotation geometry/gesture validation remains; reader selection cases moved to SP-009 |
| [SP-009](SP-009-first-offline-scripture-reader.md) | in progress | First actual product slice: offline WEBP Scripture reader |

## Owner selection

See [How we develop Sophia](../docs/guidelines/ai-structure-guidelines.md).
SP-006 and SP-007 are closed with documented prototype limitations. SP-002 research is
complete, as is SP-003 planning. The reader-only SP-005 contract is accepted and SP-009
is selected and in progress under the owner’s “Develop M2” request. SP-008 retains only the pre-M3 annotation gate.
See the development plan for that sequence. Native Pencil palette remains a separately
scoped feature. SP-007 completion does not authorize production persistence or cross-feature
integration, and does not complete M5.
Before execution, announce the ticket, milestone, visible outcome, exclusions and tests.

## Readiness and completion

Statuses: draft, ready, in_progress, blocked, done. A ready ticket has enough confirmed
inputs for its stated work type; a ready research ticket is not authorization for app
implementation. Blocked tickets name their dependencies. Done requires actual evidence
for the acceptance criteria, not merely a generated document or code file.

Use stable numbered IDs and descriptive filenames. Each ticket includes purpose/type,
owner, requirement IDs, exact design links, dependencies, scope, acceptance criteria,
verification, documentation impact, and evidence. Add implementation files/modules when
known. Do not invent module paths or mark draft schemas as finalized to make work ready.
