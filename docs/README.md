# Sophia documentation

Start with the [development plan](development-plan/development-plan.md) and
[owner-driven AI workflow](guidelines/ai-structure-guidelines.md).

| Document | Purpose |
| --- | --- |
| [Product specification](product-specification/product-specification.md) | Full-design feature map, requirements, theological brief and open decisions |
| [TDD](tdd/tdd.md) | Technical intent, candidate architecture, data and integration decisions |
| [Scripture annotation contract](data/scripture-annotation-contract.md) | M3 preserved layouts, durable ink commits, recovery and annotation-only backup/restore |
| [Scripture reader data contract](data/scripture-reader-contract.md) | Edition/reference identity, bundled SQLite content, reader state and restore behavior |
| [Scripture content](integrations/scripture-content.md) | SP-002 sources, offline baseline, provider permissions and import acceptance plan |
| [Development plan](development-plan/development-plan.md) | M0–M9 roadmap and current position |
| [Tickets](../tickets/README.md) | Selected scope, dependencies, acceptance, and evidence |
| [UX specification](design/ux-specification.md) | Intended interaction design |
| [App shell specification](design/app-shell-specification.md) | Shared navigation, overlays, state preservation, audio continuity and cross-screen rules |
| [Scripture screen specification](design/scripture-screen-specification.md) | Premium Scripture reader layout, states and acceptance scenarios |
| [Scripture rendering decision](design/scripture-rendering-decision.md) | SP-003 page geometry, selection and native validation gates |
| [Notes screen specification](design/notes-screen-specification.md) | Notes library, expandable canvas, objects, grouping, recovery and acceptance scenarios |
| [Collections screen specification](design/collections-screen-specification.md) | Nested topic folders, shared memberships, mixed artifacts, removal and recovery |
| [Companion screen specification](design/companion-screen-specification.md) | M6 multi-provider chat, selected context, sources, Quiz Me and Reviewing linkage |
| [Companion data contract](data/companion-contract.md) | Provider adapters, local conversation/quiz identity, privacy, recovery and export boundaries |
| [Activity and background music](design/activity-screen-specification.md) | M8 modes, Reading timer flow, manual records, metrics, music sourcing and shared controls |
| [Canvas comparison](design/notes-canvas-review.md) | Why expandable canvas was selected |
| [Canvas interactions](design/canvas-interactions.md) | Grouping and interaction proposal |
| [Project structure](project-structure/project-structure.md) | Actual source responsibilities and proposed boundaries |
| [Tests](testing/test-specification.md) | Native test targets, commands, evidence, and gaps |
| [iPad walkthrough](testing/sp006-ipad-guide.md) | SP-006 physical checks |
| [Deployment](deployment/deployment.md) | Xcode signing and personal iPad installation |

Confirmed intent, proposed design, implemented behavior, and passing tests are different
states. The reader data and Scripture integration contracts are maintained; later feature
contracts will be added only through their tickets. Empty placeholder pages were removed.
Keep diagrams beside the relevant design.

- [Notes document/recovery contract](data/notes-contract.md), [SP-013](../tickets/SP-013-freeform-notes.md)
  and [M4 iPad acceptance](testing/sp013-ipad-guide.md): production Notes and remaining device evidence.
