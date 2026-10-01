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
| [SP-008](SP-008-scripture-layout-validation.md) | done; bounded validation | All physical criteria owner-reported successful; production ink remains separate |
| [SP-009](SP-009-first-offline-scripture-reader.md) | done; revised acceptance | Offline WEBP Scripture reader; owner M2 closure |
| [SP-010](SP-010-licensed-offline-translations.md) | done; revised acceptance | Licensed offline translations and development cache authorization |
| [SP-011](SP-011-tab-shell-motion.md) | in_progress; physical motion review pending | Timed dock/slide/glow implemented; checks passed; iPad update installed |

| [SP-012](SP-012-persistent-scripture-annotations.md) | in_progress; physical acceptance pending | Actual-reader layers, durable ink, recovery and annotation-only backup |

| [SP-013](SP-013-freeform-notes.md) | in_progress; Canvas/Page implemented, physical acceptance pending | M4 Canvas/Page Notes, shared library, passage quotes and Notes-only recovery |

## Owner selection

See [How we develop Sophia](../docs/guidelines/ai-structure-guidelines.md).
SP-006 and SP-007 are closed with documented prototype limitations. SP-002 research is
complete, as is SP-003 planning. M2 is closed under the owner's 2026-09-29 revised
acceptance: visual refinements and expiry/renewal addressed, VoiceOver waived. SP-008 is
closed after the owner reported all criteria successful. SP-011 shell refinement is implemented with subjective motion review pending. The owner
returned to M3 and selected SP-005 annotation planning/SP-012 scoping; that doc-only step
is complete. The owner selected SP-012 implementation; verification and actual-reader device acceptance remain in progress. SP-007 completion does not complete M5.
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
