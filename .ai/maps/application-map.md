# Application map

- Entry: `application/SophiaScriptura/SophiaScriptura/SophiaScripturaApp.swift`; six tabs: `application/SophiaScriptura/SophiaScriptura/RootTabView.swift`.
- `Features/Notes/NotesView.swift` opens the production SP-013 library; SP-006 is
  reachable from its DEBUG Backups menu for the isolated experiment.
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

`tickets/SP-009-first-offline-scripture-reader.md` is closed under revised M2 acceptance. The reader
uses `Features/Scripture/ReaderSession.swift`, `ReaderTextSurface.swift` and `ScriptureView.swift`.
`Core/Scripture/` owns models/contracts/range mapping; `Infrastructure/` owns SQLite and
SwiftData. Remaining acceptance is recorded in `docs/testing/sp009-reader-evidence.md`.

SP-008 bounded physical validation is owner-accepted. DEBUG Settings opens
`Features/Scripture/LayoutValidation/` (View, Surface, Session); disposable fixtures
are isolated from reader/Notes state. See `docs/testing/sp008-ipad-guide.md`. M2 is closed
under owner-revised acceptance; historical reader gaps remain documented.

SP-011 owns timed tab-dock visibility and slide/glow presentation. `RootTabView.swift`
composes `AppShell/ShellChromeState.swift` and `ScrollActivityObserver.swift`.
See `tickets/SP-011-tab-shell-motion.md`; production annotations remain separate.

SP-012 implements actual-reader annotations in `Features/Scripture/Annotations/`:
`AnnotationSession` owns layer/save/mode state, `AnnotationControls` owns layer/Files UI,
`AnnotationRenderer` measures preserved layouts, `AnnotationSurface` shares a fixed
TextKit/PencilKit viewport. `RootTabView` retains the session and gates tab changes;
`ReaderSession.beforeNavigation` gates chapter/edition changes. Tests: `AnnotationTests`
and `AnnotationUITests`; physical gate: `docs/testing/sp012-ipad-guide.md`.

SP-013 replaces the Notes tab entry with `NotesView(session:reader:)`, composed in RootTabView.
`NotesSession` owns library/edit/save state; `Editor/NoteEditorView` and `NoteCanvasSurface`
own production controls and UIKit/PencilKit rendering. Core/Notes and Infrastructure/Notes
own document/recovery boundaries. The old CanvasExperiment remains DEBUG-only.
`ScriptureView` uses `NotesSession` quotation authorization and destination routing: an open
note receives a passage directly; otherwise the user chooses a new Page, new Canvas or an
existing note.

SP-013 study-page revision: `Core/Notes/NoteDocument.swift` adds `NotePage` and
`NoteCitation`. `Features/Notes/Editor/NoteCanvasSurface.swift` renders the fixed body,
floating objects and Pencil overlay; `NoteScripturePane.swift` composes the existing
reader beside the note. `NotePageTypography.swift` shares fixed-column measurement and
text styling. Root passes the shared ReaderSession into Notes.

## Canvas/Page implementation — 2026-10-01

`NoteDocument` stores a tagged `NoteContent` with `CanvasContent` or `PageContent`.
`NoteCanvasSurface.swift` contains dedicated Canvas/Page controller entry points and shared
viewport/input plumbing. `NoteCanvasInk.swift` reconciles PencilKit scenes into framed ink
objects; `NotePageAttachments.swift` renders inline images/tables/links, using shared fixed
column measurement from `NotePageTypography.swift`. `NoteEditorView` owns the persisted
Scripture visibility preference. `NotesFileRepository` writes v3 and preserves exact prior
generation bytes; `NotesSession` never converts legacy object-only notes on open.

`Core/Notes/NoteObjectStyle.swift` defines optional shape/color metadata.
`Editor/NoteInsertGallery.swift` owns shape/emoji choices; `NoteInkAppearance.swift` resolves
neutral ink for the theme. `Infrastructure/Notes/NoteLinkPreview.swift` fetches explicit
link previews; thumbnails persist within validated object payloads. Contextual object
actions live beside selection geometry in `NoteCanvasSurface.swift`.


`DesignSystem/AppTheme.swift` carries the selected appearance into all tab surfaces and
native Notes controllers. Root overlays the dock without a reserved footer; Notes extends
through the bottom safe area. `ThemeWorkspaceUITests.swift` verifies screen-edge colors,
full-height Notes and ink appearance cycles.

The Notes live PKCanvasView is a viewport-sized sibling of the document scroll view.
Its zoom/content offset track that viewport while stored ink retains document coordinates.
