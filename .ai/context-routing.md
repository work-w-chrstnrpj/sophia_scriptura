# Sophia context routing

1. Read `AGENTS.md` and the owner's request.
2. Read `docs/development-plan/development-plan.md` and the selected ticket to establish
   stage and scope. No ticket selection means no automatic feature execution.
3. Select the smallest relevant role/skill via `.ai/maps/agent-map.md`.
4. Follow one relevant map below, then read exact source before editing.
5. Execute the selected scope, verify, update evidence, and return control to the owner.

| Task | Discovery map | Intent |
| --- | --- | --- |
| UI, Notes, Pencil | `.ai/maps/application-map.md` | TDD and `docs/design/` |
| Persistence and recovery | `.ai/maps/data-map.md` | TDD §7; reader contract; SP-005/006/009 |
| Content or AI providers | `.ai/maps/api-map.md` | TDD §8; SP-002 |
| Offline ingestion | `.ai/maps/service-map.md` | No runtime backend; content-policy constraints |
| Tests | `.ai/maps/testing-map.md` | Ticket acceptance and test specification |
| Signing and device run | `.ai/maps/deployment-map.md` | Deployment guide |
| Planning or documentation | `docs/README.md` | Owner workflow, roadmap, selected ticket |

Maps are discovery aids, never implementation or test evidence. Generated indexes are
optional; do not generate broad context when these paths and exact reads suffice.
