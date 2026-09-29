# Testing map

- Commands and recorded results: `docs/testing/test-specification.md`.
- Device cases: `docs/testing/sp006-ipad-guide.md`.
- Unit/store/session checks: `application/SophiaScriptura/SophiaScripturaTests/CanvasExperimentTests.swift`.
- UI checks: `application/SophiaScriptura/SophiaScripturaUITests/CanvasExperimentUITests.swift`.
- SP-007: sibling `CollectionsStoreTests.swift` and `CollectionsUITests.swift` verify
  temporary membership/hierarchy semantics and simulator journeys. Results and screenshots
  live under ignored `build/sp007-*`; the ticket records exact runs.
- Scheme: `application/SophiaScriptura/SophiaScriptura.xcodeproj/xcshareddata/xcschemes/SophiaScriptura.xcscheme`.
- Preserve run artifacts under ignored `build/sp006-verification/`; summarize results in
  the ticket so reports remain understandable if local build artifacts are removed.

Select an installed simulator. Never equate build success, simulator input, owner feedback,
and complete physical-device acceptance. Run relevant checks for the selected change;
documentation-only work needs link/path/consistency checks, not another app build.

Reader planning now includes `READER-DATA-01` through `READER-DATA-12` in
`docs/data/scripture-reader-contract.md`. SP-009 owns their executable implementation,
LAYOUT-01–03 and the first offline reader UI journeys. These cases are Not Run.
