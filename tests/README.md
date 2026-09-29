# Tests

Cross-cutting test plans, manual cases, and fixtures for Sophia Scriptura. Executable
unit and UI test targets for SP-006 exist under `application/SophiaScriptura/`;
this folder holds the plans and manual cases that span the whole app.

Keep naming and commands aligned with `docs/testing/test-specification.md` and the
verification commands in `AGENTS.md`.

## What to cover

- Unit (XCTest): verse-reference parsing/formatting and ranges; content-store
  fetch-or-cache; LLM adapter request mapping and streaming normalization;
  verse-anchor-hub queries.
- UI (XCUITest): six-tab navigation; verse-tap popup; selection menu actions
  (Copy/Ask/Save/Share); annotation layer toggle.
- Manual: offline reading of bundled versions; provider cache expiry and content permissions;
  ESV audio playback; export/import round trip.

## Layout

- `manual/` — manual test case documents (create with the create-manual-test-cases skill).
- `fixtures/` — sample chapter JSON and preset fixtures for unit tests.

Run the automated suites with the `xcodebuild test` command in `AGENTS.md`.
