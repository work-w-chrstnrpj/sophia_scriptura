# Application map

- Entry: `application/SophiaScriptura/SophiaScriptura/SophiaScripturaApp.swift`; six tabs: `application/SophiaScriptura/SophiaScriptura/RootTabView.swift`.
- Current feature: `application/SophiaScriptura/SophiaScriptura/Features/Notes/NotesView.swift` opens SP-006.
- `Features/Collections/`: SP-007 in-memory prototype. `CollectionsView` owns the library;
  `CollectionDetailView` owns nested browsing; picker/editor sheets and cards/rows are
  separate files. `CollectionsStore` owns temporary data; `CollectionStyle` owns adaptive
  appearance. No production persistence or cross-feature routing. Tests: `CollectionsStoreTests`
  and `CollectionsUITests`; evidence in the SP-007 ticket.
- Canvas folder: `application/SophiaScriptura/SophiaScriptura/Features/Notes/CanvasExperiment/`.
  - `CanvasExperimentView.swift`: SwiftUI controls and text editing sheet.
  - `CanvasExperimentSurface.swift`: UIKit/PencilKit bridge, rendering, gestures, viewport.
  - `CanvasExperimentSession.swift`: selection, edits, history and save coordination.
  - `CanvasFixture.swift`: experimental geometry, grouping and validation.
  - `CanvasFixtureStore.swift`: serialized file persistence and restore validation.
  - `CanvasSample.swift`: synthetic content.
  - `CanvasMemoryProbe.swift`: opt-in DEBUG-only physical footprint sampling and bounded synthetic workload; requires isolated fixture UUID.
- `application/SophiaScriptura/SophiaScriptura/Core/ModuleBoundaries.swift`: placeholder protocols, not working services.
- Intent: `docs/tdd/tdd.md`, `docs/design/canvas-interactions.md`, `tickets/SP-006-native-canvas-experiment.md`.
- Tests: sibling `SophiaScripturaTests/` and `SophiaScripturaUITests/` targets.

Most tabs remain scaffolds. Review responsibilities before promoting experiment code into
the full editor; do not add provider or disk IO directly to canvas rendering.

`tickets/SP-009-first-offline-scripture-reader.md` is selected and in progress. The reader
uses `Features/Scripture/ReaderSession.swift`, `ReaderTextSurface.swift` and `ScriptureView.swift`.
`Core/Scripture/` owns models/contracts/range mapping; `Infrastructure/` owns SQLite and
SwiftData. Remaining acceptance is recorded in `docs/testing/sp009-reader-evidence.md`.
