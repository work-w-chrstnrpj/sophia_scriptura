# Project Structure — Sophia Scriptura

Status: M2 reader, M3 annotations and M4/SP-013 Notes implementation; physical Notes
acceptance pending, 2026-09-29.

| Path | Responsibility and present state |
| --- | --- |
| `application/SophiaScriptura/SophiaScriptura.xcodeproj/` | App, unit and UI targets; simulator build verified |
| `application/SophiaScriptura/SophiaScriptura/Features/` | Six tabs; `Notes/` has the SP-013 library and editor plus an isolated DEBUG `CanvasExperiment/` |
| `application/SophiaScriptura/SophiaScriptura/Core/` | `Scripture/` domain and selection mapping, `Annotations/` contracts, `Notes/` document values and contracts; other boundaries remain placeholders |
| `application/SophiaScriptura/SophiaScriptura/Infrastructure/Notes/` | SP-013 validated Notes generations, recovery and Notes-only Files archives |
| `application/SophiaScriptura/SophiaScriptura/Features/Collections/` | SP-015 persisted folders/subfolders, No Folder, bookmarks and gleanings: library/detail, cards/rows, folder chooser (save, move, assign), passage save and card sheets, editor, twelve-accent style and observable store |
| `application/SophiaScriptura/SophiaScriptura/Infrastructure/Collections/` | SP-015 checksummed Collections generations with current/previous pointers and damaged-file preservation |
| `application/SophiaScriptura/SophiaScriptura/DesignSystem/` | Shared seven-preset palette roles, offline font registration and responsive library command controls; UI-only, no content or storage access |
| `application/SophiaScriptura/SophiaScriptura/Resources/Fonts/` | Nine bundled font families, OFL notices and source/checksum manifest |
| `service/ingestion/` | Strict offline USFM importer, VPL comparison and importer tests; generated WEBP SQLite/manifest |
| `shared/` | Book-code and prompt seed JSON; schema/guardrails still need review |
| `application/SophiaScriptura/SophiaScripturaTests/`, `SophiaScripturaUITests/` | Executable native experiment tests |
| `tests/` | Cross-cutting testing guidance; target fixtures/cases are planned |
| `scripts/install-ipad.sh` | Personal iPad build/signature validation/install/launch automation; logs and derived data stay in ignored `build/ipad-install/` |
| `docs/product-specification/` | Numbered requirements and confirmed owner context |
| `docs/tdd/` | Canonical technical intent and evidence sources |
| `docs/integrations/` | Dated Scripture-content feasibility, permissions and import acceptance plan; no implemented provider client |
| `docs/data/` | Accepted reader identity, immutable content, reader-state and restoration contract; later feature data contracts remain open |
| `docs/design/` | UX proposals and canvas comparison; two interactive concept reviews are recorded |
| `docs/development-plan/` | Milestones, dependencies, and documentation roadmap |
| `docs/testing/`, `docs/deployment/` | Actual test, iPad walkthrough and setup guidance |
| `docs/guidelines/ai-structure-guidelines.md` | Owner-directed ticket workflow and maintainability expectations |
| `tickets/` | Bounded planning/design/research work, followed by implementation tickets |
| `.agents/`, `.ai/`, generated adapters | Existing AI workflow sources and discovery tools |

## Proposed application organization

v0.2.0 adds `Core/Notes/NoteTextFormatting.swift` for formatting spans and operations.
The Notes editor adds `NoteFormatPopover.swift`, `NoteInkColorPalette.swift`,
`NoteBlockQuoteBarView.swift`, `CanvasObjectPaletteBuilder.swift`, and `NoteMediaCapture.swift`
for formatting presentation, object actions, and camera/scan/audio integration.

SP-023 adds `Features/Scripture/ChapterHubView.swift` for chapter-index presentation and
link aggregation. Companion domain/session own distinct chapter anchors and conversation
queries; infrastructure owns provider-facing context composition. Focused coverage is in
`SophiaScripturaTests/ScriptureHubTests.swift`. No new module/package or backend is added.
Its source follow-up adds `Infrastructure/Companion/CompanionStudySources.swift` for
selected-passage links and reference lookup/provenance, with source/model regression
coverage in `SophiaScripturaTests/CompanionSourcesTests.swift`.

Keep one application target initially. Group UI and feature state under each feature;
place reusable passage, persistence, content-provider, and drawing boundaries in Core
only when needed. The freeform NoteCanvas owns document-coordinate editing behavior.
SwiftUI can host UIKit/PencilKit components where native editing requires them.

Views depend on application/domain operations; those operations depend on storage and
provider interfaces. Provider code does not own UI or note geometry. Separate user
study data from replaceable/provider-restricted Scripture content. Do not create a
runtime web backend or copy server-service layering into a local app without a need.

Local Swift packages, final model/file layouts, and test target organization follow
approved decisions. Proposed module names in the TDD are not claims that those folders
or working implementations already exist. Update this map when new structures land.

## Documentation boundaries

Empty API/data/command/diagram templates were removed. The accepted reader contract is
maintained in `docs/data/scripture-reader-contract.md`; other proposed data and provider
contracts stay in the TDD until their selected tickets produce maintained contracts.
The root README and populated `.ai/maps/` are the entry points. Existing reusable
`.agents/` assets, adapter folders and scripts remain available; no new package or
application layer was added as part of documentation cleanup.

## Broader target layout (create only as needed)

```text
SophiaScriptura/
  App/                      # Entry, dependency construction, navigation
  Features/
    Scripture/              # Reader views, session/model and selection bridge
    Annotations/
    Notes/
      Presentation/         # Screens, screen models, UIKit canvas bridge
      Application/          # Editing/saving workflows where needed
      Domain/               # Document/object rules and repository contracts
    Collections/
    Companion/
    Activity/
    Settings/
  Core/
    Scripture/              # Edition, reference, chapter and reader-state values/contracts
  Infrastructure/
    Scripture/              # Bundled SQLite repository
    Persistence/            # SwiftData reader state
  DesignSystem/             # Colors, typography, spacing, shared UI components
  Resources/Scripture/      # Generated WEBP SQLite snapshot and manifest
```

This is a responsibility map, not a requirement to create every folder immediately.
Other features adopt inner folders only when their implementation needs them. Tests
mirror feature ownership in the existing native test targets. CanvasExperiment remains
isolated until a selected migration/replacement ticket defines which pieces to reuse.
Empty protocols in `Core/ModuleBoundaries.swift` are discovery scaffolding, not completed
interfaces; replace them with actual operation contracts as selected features arrive.
The canonical dependency rules and stack recommendation are in TDD §5.1.

## Folder use cases

| Folder | Use cases it owns | Examples of code that belongs here |
| --- | --- | --- |
| `App/` | Start the app, assemble dependencies, select the root scene, and connect the six tabs. | `SophiaScripturaApp`, `AppContainer`, root navigation |
| `Features/Scripture/` | Browse a book/chapter/verse, switch translation, select text, copy/share, play permitted audio, and open verse attachments. | Scripture screen, reader screen model, passage query use case |
| `Features/Annotations/` | Toggle Read Hidden/Read Visible/Draw, manage multiple layers, persist version/chapter/layout-specific ink, and show the extended ruled margin. | Annotation screen state, layer identity, PencilKit bridge adapter |
| `Features/Notes/` | Create expandable pages, place text/ink/images, group objects explicitly, edit text, navigate/zoom, and manage note presentation. | Note canvas, object selection, note screen model, note workflows |
| `Features/Drawing/` | Share production Pencil gesture interpretation and geometric stroke refinement without owning feature persistence. | Endpoint hold recognizer, line/shape classifier, `PKStroke` replacement |
| `Features/Collections/` | Create topic folders, nest folders, add/remove shared memberships, and browse related notes, verses, conversations and links. | Collection list, membership commands, collection detail |
| `Features/Companion/` | Start separate conversations, preserve follow-up context, choose one of four presets, attach selected Scripture, and show citations/references. | Chat screen, conversation screen model, context builder, preset selector |
| `Features/Activity/` | Start/stop or manually enter study sessions, tag activity, correct entries, calculate streaks/goals, and show local analytics. | Timer, activity editor, streak calculator, analytics view |
| `Features/Settings/` | Configure theme, typography, accessibility preferences, backups, reminders, provider keys and local privacy controls. | Settings screens, import/export commands, preference model |
| `Core/Domain/` | Define shared concepts and rules used by more than one feature without importing UI or platform frameworks. | `VerseRef`, `PassageRange`, `ArtifactID`, `AnnotationIdentity`, `StudyDate` |
| `Core/Application/` | Coordinate cross-feature workflows and transactions. | Save-selection workflow, verse hub query, delete-artifact policy |
| `Core/Contracts/` | Define inward-facing repository and provider interfaces. | `ScriptureRepository`, `StudyArtifactRepository`, `CompanionProvider`, `AudioSource` |
| `Infrastructure/Storage/` | Store metadata, files, drawings, SQLite content and migrations; implement recovery and atomic writes. | SwiftData repositories, SQLite reader, file vault, import/export validator |
| `Infrastructure/Providers/` | Adapt external Scripture, audio and LLM services to internal contracts. | API.Bible adapter, ESV adapter, narration adapter, LLM adapter |
| `Infrastructure/Security/` | Keep BYOK secrets and sensitive local configuration out of ordinary models and logs. | Keychain store, redaction helpers |
| `DesignSystem/` | Keep the premium visual language consistent across all tabs. | Warm-paper colors, typography, spacing, cards, buttons, accessibility tokens |
| `Resources/` | Ship only permitted bundled content, prompt seeds and static assets. | WEB seed, book metadata, approved preset JSON, icons |
| `Tests/` | Verify domain rules, application workflows, repositories, provider contracts and a small number of UI journeys. | Unit, integration, contract and XCUITest targets |

The important rule is ownership: a Scripture view may request a passage through its
screen model, but it must not open SQLite, call an LLM, or mutate a note file directly.
A Notes canvas may render a PencilKit drawing, but it must not decide how Bible
translations are licensed. Cross-feature actions go through an application workflow
and shared identifiers. This keeps a future feature from becoming a second service
locator or a grab-bag of unrelated helpers.

We will create these folders incrementally as tickets select them. The first production
ticket should create only `App/`, `DesignSystem/`, `Core/Domain/`, `Core/Contracts/`,
and the Scripture feature slice it needs; it should not create empty folders for every
future feature.

## Implemented M2 folders

- `Core/Scripture/`: immutable source models, passage ranges, reader-state contracts and selection mapping.
- `Infrastructure/Scripture/`: actor-isolated, validated read-only SQLite access.
- `Infrastructure/Persistence/`: local-only SwiftData v1 reader adapter.
- `Infrastructure/Security/`: device-only Keychain access for the API credential,
  encryption key, revocation state and trusted last-seen time.
- `Infrastructure/Scripture/`: also owns SP-010's API.Bible adapter, typed parser and
  staged licensed-edition library; `Infrastructure/Persistence/EncryptedBibleStore.swift`
  contains ciphertext-only licensed payload records.
- `Features/Scripture/`: session, composed reader/hub, ScripturePassagePicker navigation sheet, and one continuous native selection surface.
- `Features/Scripture/ScriptureVersionsView.swift`: WEB/NIV11/NLT/NKJV choice, secure
  credential entry, download progress, lease status and attribution.
- `Features/Settings/`: immediate reader preference editing.
- `Resources/Scripture/`: generated database and provenance manifest.

Dependencies flow from views to session/domain contracts to injected adapters. Renderer
receives chapter values only. `RootTabView` composes dependencies and retains all tab state.
No empty App/Domain/Application folders or extra packages were created.

## SP-008 validation boundary — 2026-09-29

`Features/Scripture/LayoutValidation/` is a DEBUG-only experiment opened from Settings.
View owns controls, Surface owns shared TextKit/PencilKit geometry and input, and Session
owns two disposable layers and isolated atomic fixture save/reopen. It uses bundled WEB
and has no provider calls or production ink persistence. Tests live in
`SophiaScripturaTests/InkValidationTests.swift`; physical results are tracked in the
[walkthrough](../testing/sp008-ipad-guide.md).

## SP-011 shell presentation — 2026-09-29

`AppShell/ShellChromeState.swift` owns the transient monotonic three-second idle timer.
`AppShell/ScrollActivityObserver.swift` observes direct finger movement without competing
with native gestures or observing Pencil strokes. `RootTabView.swift` composes these and
owns dock/reveal styling and animated mounted-tab presentation. Shell timing does not
modify feature persistence or provider policy. Focused tests are `ShellChromeStateTests`
and `ShellNavigationUITests`, with reader scroll/navigation regressions.

SP-011 footer follow-up: RootTabView allocates separate vertical regions to tab content
and the dock, plus shared SwiftUI bottom scroll-content clearance. Settings, Collections
and Notes expose end-of-content UI identifiers; footer-bound checks live in
`ShellNavigationUITests`. Native reader/canvas surfaces receive the bounded viewport.

## SP-012 persistent Scripture annotations — 2026-09-29

- `Core/Annotations/`: platform-independent identity, layout/layer values and repository interface.
- `Infrastructure/Annotations/`: actor-isolated file generations, SHA-256 integrity, recovery and ink-only archive validation.
- `Features/Scripture/Annotations/`: annotation session, layer/Files controls, captured layout renderer and shared UIKit/PencilKit viewport.
- `AnnotationTests.swift` / `AnnotationUITests.swift`: temporary-store recovery fixtures and actual-reader layer journeys.

Root retains the annotation session; ReaderSession gates navigation through a save callback.
LayoutValidation remains disposable DEBUG evidence. Notes and Collections persistence are
unchanged. See the annotation contract and SP-012 for acceptance boundaries.

## SP-013 production Notes — 2026-09-29

`Core/Notes/NoteDocument.swift` defines independent document/object values, flat groups,
geometry, source quotes and repository contracts. `Infrastructure/Notes/NotesFileRepository.swift`
implements serialized integrity-checked generations, previous/pre-restore recovery and
media validation. `Features/Notes/NotesSession.swift` owns edits, bounded differential
history and autosave; `NotesView` owns the library/Files UI; `Editor/` owns controls,
object inspection and the native zooming canvas. Root composes the shared session and
routes verse-hub quotes into the same library. `CanvasExperiment/` remains isolated and
DEBUG-accessible. No prototype-data migration or Collections membership is performed.

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

SP-013 workspace refinement adds `Core/Notes/NoteObjectStyle.swift` for optional shape/tint
values, `Editor/NoteInsertGallery.swift` for shape/emoji selection, and
`Editor/NoteInkAppearance.swift` for theme-aware neutral ink. LinkPresentation loading is
isolated in `Infrastructure/Notes/NoteLinkPreview.swift`; cached thumbnails use the existing
validated object payload. The surface owns contextual controls tied to selection geometry.


`DesignSystem/AppTheme.swift` shares the selected paper/ink palette across tab bodies,
status/navigation backgrounds and native Notes rendering. RootTabView owns the full-height
viewport and overlaid dock; `ThemeWorkspaceUITests` covers this shared presentation boundary.

SP-025: `Features/Notes/Editor/NoteInkStrokeIndex.swift` owns internal stroke references,
legacy identity derivation and spatial geometry queries. `NoteCanvasInk` owns composition,
identity reconciliation and region edits/spill. NotesSession owns selection/history/recovery
commands; NotesFileRepository owns additive metadata validation and rejected ink recovery.
`NoteStrokeEditingTests.swift` covers identity, geometry, limits and persistence.

SP-026–028: `Features/Protection/` owns independent access sessions, authentication presentation, combined/category controls and real-input idle tracking. `Infrastructure/Security/ItemLockCredential.swift` owns the device Keychain verifier. NotesSession and CollectionsStore guard domain commands and protected routes; StudyBackupService preflights access across both categories. The authoritative boundaries are in `docs/security/item-protection.md`.

SP-040: `Features/Collections/CollectionFolderMove.swift` owns the custom local drag
folder ID and drag/drop/full-tree move sheet. `AppInfoSupplement.plist` exports its UTI.
`CollectionsStore` validates reparenting and writes existing parentID values. Journal
glyphs live in `NoteJournalFields`; `PrayerStatusStamp` in `NotePrayerEditorView` is
presentation-only and does not enter stored prayer content.

`Assets.xcassets/PrayerAnsweredStamp.imageset` and `PrayerRedirectedStamp.imageset`
contain template PDF wordmarks in Arial Black outlines, regenerated on macOS by
`scripts/generate-prayer-stamps.swift` without distributing a font file.

SP-040: `Features/Notes/NoteLibraryCard.swift` renders shared note cards for Notes
and Collections, including previews, dates, protection glyphs and stamp activation.

`Features/Activity/ActivityChartAnimation.swift` owns the shared animated distribution
and bar chart views used by Activity analytics and distribution details.
