# Testing map

- Commands and recorded results: `docs/testing/test-specification.md`.
- Device cases: `docs/testing/sp006-ipad-guide.md`.
- Unit/store/session checks: `application/SophiaScriptura/SophiaScripturaTests/CanvasExperimentTests.swift`.
- UI checks: `application/SophiaScriptura/SophiaScripturaUITests/CanvasExperimentUITests.swift`.
- SP-007: sibling `CollectionsStoreTests.swift` and `CollectionsUITests.swift` verify
  membership/hierarchy semantics (later expanded for persisted production Collections) and simulator journeys. Results and screenshots
  live under ignored `build/sp007-*`; the ticket records exact runs.
- Scheme: `application/SophiaScriptura/SophiaScriptura.xcodeproj/xcshareddata/xcschemes/SophiaScriptura.xcscheme`.
- Preserve run artifacts under ignored ticket-specific `build/` directories; summarize results in
  the ticket so reports remain understandable if local build artifacts are removed.

Select an installed simulator. Never equate build success, simulator input, owner feedback,
and complete physical-device acceptance. Run relevant checks for the selected change;
documentation-only work needs link/path/consistency checks, not another app build.

The reader contract includes `READER-DATA-01` through `READER-DATA-12` in
`docs/data/scripture-reader-contract.md`. SP-009 owns their executable implementation,
LAYOUT-01–03 and the first offline reader UI journeys. Recorded runs and remaining cases are in `docs/testing/sp009-reader-evidence.md`; do not
apply the original Not Run state to later evidence.

Current production coverage includes Notes/ink/protection, Collections, Companion/provider
routing/cache, Scripture sources/narration, Sophy, Activity and shell/audio targets.
Use the matching source test files and dated test-specification sections rather than
this historical experiment list as an exhaustive inventory. SP-048 (v1.3.2) adds
`QuizBankLifecycleTests.swift`; recorded 414-test evidence is in its ticket, not a new
run from the 2026-10-18 documentation reconciliation. Physical/provider acceptance is separate.
