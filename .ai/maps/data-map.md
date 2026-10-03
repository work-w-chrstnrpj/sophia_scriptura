# Data map

The separate SP-006 Notes experiment retains its disposable fixture under
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

SP-012: `Core/Annotations/AnnotationModels.swift` owns source/layout/layer identities and
repository contract; `Infrastructure/Annotations/AnnotationFileRepository.swift` owns
serialized generation commits, integrity/fallback, tombstones and ink-only archive restore.
Store: Application Support/Annotations; UUID test scope follows SP009_TEST_STORE. The
maintained contract is `docs/data/scripture-annotation-contract.md`; this store contains
no Scripture text or credentials and does not replace reader/licensed/Notes stores.

- Notes: `Core/Notes/NoteDocument.swift`, `Infrastructure/Notes/NotesFileRepository.swift`;
  contract `docs/data/notes-contract.md`. Notes-only generations and Files archive include
  ink/media; separate from SP-006 fixtures and SP-012 annotations. No migration of the separate experiment or Scripture stores.

SP-013 schema v3: a note stores one Canvas/Page content case. Page attachments have UTF-16
anchors; Canvas ink remains framed. v1/v2 decode by page presence; first v3 publication
retains `before-note-types.notes` and leaves `before-study-page.notes` untouched.

SP-013 refinement retains schema v3 with optional shape/tint values and dotted paper.
Canvas link payloads optionally contain validated thumbnail images and count toward the
existing media limits. Theme presentation preserves unchanged stored ink bytes.

SP-019 Companion schema v3 adds prepared quiz questions. Prior v1/v2 generations decode
with an empty cache. A cache item is scoped by provider configuration, adapter, model,
edition, prompt contract, game type and difficulty; quiz history remains separate.

SP-020 Activity uses `Core/Activity/ActivityModels.swift` and
`Infrastructure/Activity/ActivityFileRepository.swift`. The local Activity-v1 envelope
has a SHA-256 payload checksum, previous-file recovery, and a separate pre-restore archive.
Quiz linkage stores only a quiz-session ID, mode, date and duration.
