# How we develop Sophia

The owner chooses what starts. The AI explains scope and executes the selected work.
This project uses the existing `.agents/` roles, skills, and workflows with the following
Sophia-specific process. A milestone is a larger outcome; a ticket is one bounded task.
SP-006 is a native experiment inside M1, not the end of the app.

## Commands you can give

| Your command | What happens |
| --- | --- |
| “Explain the roadmap and recommend the next ticket.” | Explain current position, dependencies, and options; no implementation. |
| “Plan the Pencil toolbar and write a ticket.” | Prepare a reviewable proposal with requirements, limits, files, tests, and unresolved choices; no app code. |
| “Review SP-006's architecture.” | Inspect source and report coupling, responsibilities, testability, and concrete risks; no edits unless requested. |
| “Execute SP-006.” | Announce its scope, then implement and verify that ticket, including necessary fixes. |
| “Continue SP-006.” | Resume unfinished work in that ticket; do not start a different one. |
| “Run the SP-006 iPad walkthrough.” | Guide the cases and record observed pass/fail/not-run evidence. |
| “Update the docs with my feedback.” | Record feedback without treating it as permission to implement a new feature. |

Natural language is welcome; exact command wording is not required. If “next” could mean
several tickets, identify the choices before coding. A ticket marked ready means its
inputs are sufficient, not that the owner has selected it for execution.

## Before execution

Owner request (2026-09-21): before the first product implementation, explicitly announce
“We are now starting actual product implementation,” name its ticket and usable outcome,
and distinguish experiments from product work. Planning is not a working daily-use feature.

Give the owner a brief task statement: ticket ID, milestone, purpose, visible outcome,
exclusions, affected modules, and verification. Read its requirements and design sources.
If it is an experiment, explain what is temporary and what the owner should test.
Proceed once the owner selects that scope; do not repeatedly request authorization for
routine implementation and fixes inside it. New feature scope returns to the owner.

## During and after execution

Use the smallest relevant role and skill from `.agents/`, selected through `.ai/`.
Role ownership does not automatically mean spawning additional agents.
Report concrete changes, results, blockers, and the next check. Preserve evidence under
ignored `build/` rather than temporary system folders; link durable conclusions from the
ticket. Report user observations separately from automated results.

At the end, report acceptance criteria met/unmet, checks actually run, limitations,
and documentation changes. Mark done only when required evidence exists. Recommend the
next ticket, but do not start it. “It works” feedback is not evidence for every test case.

## Maintainable code is an acceptance requirement

Each implementation ticket names file/module ownership and dependency direction, data
contracts, error handling, and tests. UI, editing operations, persistence, and provider
access should have explicit responsibilities. Avoid adding empty layers or packages
merely to match the template. Review growing responsibilities before adding more features.

For the canvas, the current split is View → Session/Surface → Fixture/Store. The native
surface handles rendering, gestures, and PencilKit integration; this concentration must
be reviewed before expanding the editor. Experimental JSON and whole-drawing grouping
are not approved production contracts. See the [structure map](../project-structure/project-structure.md).

## Sources of truth

| Question | Source |
| --- | --- |
| What should Sophia do? | [Product specification](../product-specification/product-specification.md) |
| What is the intended technical design? | [TDD](../tdd/tdd.md) |
| What stage are we in? | [Development plan](../development-plan/development-plan.md) |
| What may this task change? | Selected [ticket](../../tickets/README.md) and owner instruction |
| What exists and works? | Exact source, executed checks, and recorded observations |
| Which AI instructions apply? | `AGENTS.md`, `.ai/context-routing.md`, relevant `.agents/` role/skill |

## Documentation and adapter maintenance

Keep useful decisions, contracts, test evidence, and setup instructions. Create dedicated
API/data/diagram pages only when there is actual content and a ticket that maintains it;
unresolved work stays in the roadmap. Diagrams belong beside the design they explain.

The reusable `.agents/` sources and existing generated adapters are retained. Project
choices belong in `AGENTS.md`, `docs/`, and `.ai/`, not portable role/skill definitions.
Codex reads `AGENTS.md` and canonical skills directly. If role/skill/overlay/workflow/tool
sources change, use `scripts/sync-ai-adapters.ps1` and its validation script. These require
PowerShell (`pwsh`), which was not found on this Mac during this cleanup. No canonical
reusable assets or generated adapters were changed, and no adapter sync is claimed.

## Cleanup record

Removed empty API, data-model, command-reference, and five diagram placeholder pages.
Existing TDD sections retain proposed data/integration design; SP-002 and SP-005 own
future contracts. Build/test commands remain in testing and deployment guides. Replaced
the generic template onboarding with this project workflow and populated `.ai/` maps.
No application code or new feature was implemented during this cleanup.
