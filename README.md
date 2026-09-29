# Sophia Scriptura

A personal, offline-first iPad Bible study app, built for the owner's iPad with SwiftUI
and PencilKit. The full product is still being designed and developed.

## Start here

1. [Roadmap and current work](docs/development-plan/development-plan.md): milestones M0–M9.
2. [How you direct development](docs/guidelines/ai-structure-guidelines.md): choose, plan,
   execute, review, and close bounded tickets.
3. [Tickets](tickets/README.md): status and scope of each piece of work.
4. [Product specification](docs/product-specification/product-specification.md): intended behavior.
5. [Technical design](docs/tdd/tdd.md) and [source structure](docs/project-structure/project-structure.md).

## Current app

Six-tab scaffold with an isolated expandable-canvas experiment under Notes (SP-006).
The owner has opened and tried the canvas on iPad. This is not the finished Notes editor:
the native Pencil tool picker and full study workflow are not implemented.
SP-006 is closed as a bounded experiment with documented deferred checks. SP-007 adds a
bounded in-memory Collections prototype. SP-009 / M2 is selected: the offline WEBP reader,
navigation, selection, settings and reader state are implemented. Physical acceptance and
remaining checks are tracked in [reader evidence](docs/testing/sp009-reader-evidence.md).

[Run on iPad](docs/deployment/deployment.md) · [Tests and evidence](docs/testing/test-specification.md)
· [Canvas walkthrough](docs/testing/sp006-ipad-guide.md)

## AI development structure

- `AGENTS.md`: project rules, owner-controlled execution, and verification entry points.
- `.agents/`: reusable role instructions, skills, overlays, workflows, and tool policies.
- `.ai/context-routing.md`: maps the selected task to exact documents and source files.
- `docs/`: product intent, decisions, roadmap, design, and verification guidance.
- `tickets/`: requirements → bounded scope → source changes → tests → evidence.
- `scripts/`: existing adapter generation and validation utilities.

Canonical AI assets are retained. Generated tool adapters are not edited by hand.
See [AI workflow](docs/guidelines/ai-structure-guidelines.md) for maintenance details.

MIT — see [LICENSE](LICENSE).
