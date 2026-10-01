# SP-016 — M6 Companion architecture, design and contracts

- Type: planning/design contract. Status: done; owner approved 2026-10-02.
- Milestone: M6 Stateful Companion.
- Owner: System Architect with Product & Planning, Security, SQA, Frontend UI/UX,
  Backend & Database, and Technical Documentation roles.
- Selected and approved by owner: 2026-10-02.

## Visible outcome

M6 has an owner-approved multi-provider BYOK boundary, detailed Companion and Quiz Me
interaction design, provider/privacy/retrieval rules, local data/recovery contract,
verification targets and a bounded delivery sequence. This ticket creates planning records
only; it does not implement Companion.

## Confirmed decisions

- Sophia supports multiple configured provider adapters and owner-supplied keys. OpenAI,
  Anthropic and Gemini are the intended first adapters; a custom OpenAI-compatible endpoint
  is later scope. An arbitrary API still requires a compatible adapter.
- Local history is authoritative. Each conversation pins provider, model, capabilities and
  resolved preset snapshot. Switching provider explicitly branches rather than silently
  changing an existing conversation.
- Scripture retrieval/quiz validation is local and permission-aware. External retrieval is
  capability-advertised, source evidence is inspectable, and unavailable retrieval is never
  presented as a completed search.
- Only displayed, deliberately selected context leaves the device. Keys are isolated in
  Keychain and excluded from logs and exports.
- Quiz answer controls, deterministic validation, per-question timer defaults, scoring,
  history fields and Reviewing linkage follow the approved Companion design.
- Record this as Reviewing defaults on but may be disabled before a quiz. Active quiz time
  counts toward the normal goal/streak; Activity does not duplicate answers or scores.

## Deliverables

- [Companion screen specification](../docs/design/companion-screen-specification.md)
- [Companion data/provider/recovery contract](../docs/data/companion-contract.md)
- Reconciled product specification, TDD, M6 roadmap, Activity boundary and test plan
- Recommended implementation order below

## Implementation handoff order

1. Conversation domain/repository and recovery generations.
2. Keychain provider configurations, capability model and adapter registry.
3. OpenAI adapter plus the first local streaming conversation vertical slice.
4. Anthropic and Gemini adapters using shared conformance tests.
5. Scripture Ask, side-panel/tab continuity, verse hub and Collections membership.
6. Retrieval/source inspection and four-preset behavioral evaluation.
7. Deterministic Scripture Quiz Me modes and history.
8. Curated Christian History fixtures and Reviewing linkage.

Each implementation step requires a separately owner-selected implementation ticket. The
first ticket may change adapter order after current official API feasibility is rechecked,
but may not weaken the provider-neutral contract or silently broaden transmitted context.

## Exclusions

- App source changes, API calls, account creation, purchases or entry of real credentials.
- Automatic cross-chat memory, background autonomous research or arbitrary-provider support
  without an adapter.
- M7 audio or general M8 Activity implementation.

## Acceptance and verification

- Canonical documents agree on multi-provider identity, local history, privacy, retrieval,
  Quiz Me and Reviewing ownership.
- Links resolve and Markdown has no whitespace errors.
- No native test is required because this ticket changes documentation only.

## Evidence

- Owner approved the proposed decision package on 2026-10-02.
- `git diff --check` passed on 2026-10-02.
- Relative Markdown link targets under `docs/` and `tickets/` were checked and resolved.
- Cross-document search confirmed the M6 roadmap, TDD, product specification, Companion
  design/data contract, Activity boundary and test plan use the approved SP-016 terms.
- Native tests were not run because this ticket changes documentation only and introduces no
  application behavior.
