# Application map

- Entry: `application/SophiaScriptura/SophiaScriptura/SophiaScripturaApp.swift`; six tabs: `application/SophiaScriptura/SophiaScriptura/RootTabView.swift`.
- `Features/Notes/NotesView.swift` opens the production SP-013 library; SP-006 is
  reachable from its DEBUG Backups menu for the isolated experiment.
- `Features/Collections/`: persisted nested folders/shared memberships, passages, links,
  annotations, note/conversation routes and Points to Ponder. `CollectionsStore` owns
  guarded commands; `Infrastructure/Collections/CollectionsFileRepository.swift` owns
  checked generations. SP-040/044–047 add moves, shared cards, swipes, copies and conversions.
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

All six tabs contain production study workflows. The experiment remains isolated; do
not add provider or disk IO directly to canvas rendering. Source review: 2026-10-18.

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

SP-019 M6 Quiz Me cache: `Core/Companion/CompanionModels.swift` defines standalone cached
questions and scope. `Infrastructure/Companion/QuizQuestionCacheCoordinator.swift` coalesces
per-bucket provider generation. `Features/Companion/CompanionQuizCache.swift` computes
deficits, validates local exclusions and reserves questions; `CompanionSession` persists
them in the existing Companion snapshot and `QuizMeView` shows warm/cold start state.

SP-020 M8 Activity: `Features/Activity/ActivityView.swift` owns the Activity flows and
`ActivityStore.swift` coordinates mutations. `Core/Activity/ActivityAnalytics.swift` and
`ActivityHistoryGrouping.swift` calculate chart buckets and relative history groups.
`Features/Activity/ActivityAnalyticsView.swift`, `ActivityHistoryView.swift`, and
`ActivityRecorderControl.swift` render charts, history, and the movable timer.
`ActivityRemindersView.swift` manages the reminder form, preview rows and grouped View all;
`ActivityTodayDetailView.swift` renders per-mode progress and goal editing;
`ActivityDistributionDetailView.swift` renders the selected pie/time breakdown;
`Infrastructure/Activity/ActivityReminderNotifications.swift` schedules repeating iPad
notifications. Activity export renders the selected chart range to PNG. One-time reminder
cleanup is stored on each reminder.
`RootTabView` hosts the cross-tab timer control
and routes Reading to `ReaderSession`. Companion's Reviewing link is imported into Activity
without quiz answer data. See `tickets/SP-020-activity-tracking.md` for remaining acceptance.

Current additional routes:

- `Features/Scripture/ScriptureTranslationPickerView.swift` chooses installed editions;
  `ScriptureTranslationDownloadsView.swift` manages AO/API downloads. ReaderSession uses
  `Infrastructure/Scripture/MultiSourceTranslationLibrary.swift`. Narration is owned by
  `ScriptureNarrationSession.swift`, not by the abandoned original M7 scope.
- `Features/Protection/ItemProtectionSession.swift` owns independent Notes/Collections
  grants; read `docs/security/item-protection.md` before touching protected routes.
- `Features/Sophy/` owns the opt-in Lady Wisdom session, reviewed actions, enhancement
  and History; domain validation and persistence live in Core/Sophy and Infrastructure/Sophy.
- `Features/Music/`, `Features/SystemPlayer/` and `AppShell/StudyAudioCoordinator.swift`
  own music UI, PiP and audio arbitration. Root composes these with Activity's committed
  system projection; `StudyActivityWidgetExtension/` is a sibling target directory.
- SP-048 (v1.3.2): `QuizQuestionCachePolicy` sets 100 minimum/200 capacity per scoped
  bucket; CompanionQuizCache replaces reserved questions and persists batches, while
  RootTabView reconciles foreground demand. See the ticket for remaining acceptance.

SP-049 (2026-10-20): Core/Plans/ owns Plan values/commands and Core/Security/ owns copied
access requirements. Features/Plans/ has PlanDetailView content/basic playback plus authoring/editor-draft/assignment/lifecycle UI;
CollectionsStore remains the single persistence writer. Fullscreen Plan pages reuse AppTheme and the shared reader/Notes editor;
PlanStudyTools.swift coordinates checked note/link creation and shared music controls.
Plan-owned Pencil layers are not present yet (SP-051). Basic Start/Resume uses the existing reader; full workspace lifecycle remains open. See the SP-049 ticket.

SP-049 stability correction: `Features/Plans/PlanEditorDraft.swift` owns stable-ID
draft mutations, safe title bindings and stale-callback guards. PlanEditorView renders
value snapshots; PlanAssignmentPicker clamps dependent chapter bounds before book changes.
No persistence schema changes are involved.
