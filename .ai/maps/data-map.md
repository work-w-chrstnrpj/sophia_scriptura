# Data map

Experimental Notes persistence remains SP-006's disposable fixture, under
`application/SophiaScriptura/SophiaScriptura/Features/Notes/CanvasExperiment/`:
`CanvasFixture.swift` defines geometry and validation; `CanvasFixtureStore.swift` saves
and loads an atomic JSON envelope; `CanvasExperimentSession.swift` coordinates saves.
Normal fixture: Application Support/SP006/canvas-fixture-v1.json. DEBUG UI tests use
UUID-scoped fixtures. Tests: `application/SophiaScriptura/SophiaScripturaTests/CanvasExperimentTests.swift`.

The accepted reader slice lives in `docs/data/scripture-reader-contract.md`: immutable
bundled SQLite Scripture, stable edition/revision/reference identities and SwiftData
reader state behind repositories. `tickets/SP-009-first-offline-scripture-reader.md`
implements that slice. SP-005 still owns later study-data relationships, drawing/media,
recovery, export and migration contracts. Do not use the SP-006 sample schema as a
production contract.

SP-009 implements reader state in `Infrastructure/Persistence/ReaderStateStore.swift` and
read-only content in `Infrastructure/Scripture/BundledScriptureRepository.swift`. Bundled
resources live in `Resources/Scripture/`; ingestion is under `service/ingestion/`. No automatic
store reset is permitted. See the reader evidence page for unverified acceptance cases.
