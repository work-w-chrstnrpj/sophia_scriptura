# Project Structure — Sophia Scriptura

Source reconciliation: 2026-10-18, v1.3.2/build 27, including SP-048.
All six tabs have implemented workflows. Current ownership is summarized here; dated
sections below explain how those boundaries evolved. Physical/provider/accessibility
acceptance remains governed by the matching tickets.

| Path | Responsibility and present state |
| --- | --- |
| `application/SophiaScriptura/SophiaScriptura.xcodeproj/` | App, unit and UI targets; simulator build verified |
| `application/SophiaScriptura/SophiaScriptura/Features/` | Six tabs; `Notes/` has the SP-013 library and editor plus an isolated DEBUG `CanvasExperiment/` |
| `application/SophiaScriptura/SophiaScriptura/Core/` | Scripture/reference/rights/narration, annotation, Notes, Companion/quiz, Activity, Music and Sophy values/contracts; `ModuleBoundaries.swift` retains unused scaffolding |
| `application/SophiaScriptura/SophiaScriptura/Infrastructure/Notes/` | SP-013 validated Notes generations, recovery and Notes-only Files archives |
| `application/SophiaScriptura/SophiaScriptura/Features/Collections/` | SP-015 persisted folders/subfolders, No Folder, bookmarks and gleanings: library/detail, cards/rows, folder chooser (save, move, assign), passage save and card sheets, editor, twelve-accent style and observable store |
| `application/SophiaScriptura/SophiaScriptura/Infrastructure/Collections/` | SP-015 checksummed Collections generations with current/previous pointers and damaged-file preservation |
| `application/SophiaScriptura/SophiaScriptura/DesignSystem/` | Shared seven-preset palette roles, offline font registration and responsive library command controls; UI-only, no content or storage access |
| `application/SophiaScriptura/SophiaScriptura/Resources/Fonts/` | Nine bundled font families, OFL notices and source/checksum manifest |
| `service/ingestion/` | Strict offline USFM importer, VPL comparison and importer tests; generated WEBP SQLite/manifest |
| `shared/` | Book-code and prompt seed JSON; schema/guardrails still need review |
| `application/SophiaScriptura/SophiaScripturaTests/`, `SophiaScripturaUITests/` | Executable unit/integration and UI targets covering production features and isolated experiments |
| `tests/` | Cross-cutting testing guidance; executable native tests live in the Xcode test targets |
| `scripts/install-ipad.sh` | Personal iPad build/signature validation/install/launch automation; logs and derived data stay in ignored `build/ipad-install/` |
| `docs/product-specification/` | Numbered requirements and confirmed owner context |
| `docs/tdd/` | Canonical technical intent and evidence sources |
| `docs/integrations/` | Dated Scripture-content permissions/feasibility evidence; implemented clients live under Infrastructure |
| `docs/data/` | Maintained Scripture reader/annotation, Notes, Companion and music evidence contracts; feature stores retain independent schemas |
| `docs/design/` | Current feature specifications, implementation guides and historical canvas design proposals |
| `docs/development-plan/` | Milestones, dependencies, and documentation roadmap |
| `docs/testing/`, `docs/deployment/` | Actual test, iPad walkthrough and setup guidance |
| `docs/guidelines/ai-structure-guidelines.md` | Owner-directed ticket workflow and maintainability expectations |
| `tickets/` | Bounded planning/design/research work, followed by implementation tickets |
| `.agents/`, `.ai/`, generated adapters | Existing AI workflow sources and discovery tools |

## Current production boundaries

| Source directory (under the app) | Current responsibility |
| --- | --- |
| `Features/Scripture/`, `Infrastructure/Scripture/HelloAO/` | Reader, source-specific downloads, separate translation choice/download sheets, narration session and media playback/storage |
| `Core/Companion/`, `Infrastructure/Companion/`, `Features/Companion/` | Provider-neutral requests, registry/adapters, Keychain credentials, preset/context composition, conversation generations and quiz bank/session flows |
| `Core/Activity/`, `Infrastructure/Activity/`, `Features/Activity/` | Durable timer/records, analytics, reminders, meditation journey and committed system projection |
| `Core/Music/`, `Infrastructure/Music/`, `Features/Music/` | Catalog/imported music, playback preferences, audio engine and Now Playing controls |
| `Features/Protection/`, `Infrastructure/Security/ItemLockCredential.swift` | Independent Notes/Collections access grants and credential binding; access locks do not encrypt study files |
| `Core/Sophy/`, `Infrastructure/Sophy/`, `Features/Sophy/` | Typed action validation, eligible local context, reviewed execution, History/journal and text enhancement |
| `Infrastructure/Backup/StudyBackupService.swift` | Study archive composition and sequential restore through feature stores; excludes Keychain secrets, licensed content and user music |
| `AppShell/`, `Features/SystemPlayer/`, `RootTabView.swift` | Mounted tabs, dock, shared audio/timer/character overlays, PiP, session composition and lifecycle routing |
| `StudyActivityWidgetExtension/` (project sibling) | WidgetKit Live Activity extension using the safe committed Activity projection |

The broad `Core/Domain`, `Core/Application` and `Infrastructure/Providers` layout below
was a planning sketch. Current code groups these responsibilities by feature and uses
shared sessions directly at the root; it has not been reorganized into that sketch.

## Organization principles and historical additions

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

Empty API/data/command/diagram templates were removed. Maintained contracts now live in
`docs/data/` for reader, annotations, Notes and Companion, with access-lock boundaries in
`docs/security/item-protection.md`. Source repositories define feature formats; the
TDD retains clearly labeled historical sketches and future proposals.
The root README and populated `.ai/maps/` are the entry points. Existing reusable
`.agents/` assets, adapter folders and scripts remain available; no new package or
application layer was added as part of documentation cleanup.

## Historical target layout (illustrative, not the current tree)

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

## Historical target-folder use cases (conceptual ownership)

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

We will create these folders incrementally as tickets select them. The original first production
slice called for only `App/`, `DesignSystem/`, `Core/Domain/`, `Core/Contracts/`,
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
- `Features/Scripture/ScriptureTranslationPickerView.swift`: read-only installed edition choice.
- `Features/Scripture/ScriptureTranslationDownloadsView.swift`: AO/API download management;
  API credential/sync, lease status and attribution retain their source-specific controls.
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

`DesignSystem/StudySwipeReveal.swift` owns SP-044 shared record swipe presentation
for Collections, Notes and Prayer update scroll-stack hosts.

SP-044 dismissal follow-up: RootTabView supplies StudySwipeCoordinator for a single
open action rail. AppShell/ScrollActivityObserver passively dismisses it on vertical
finger intent; StudySwipeReveal keeps the shifted record body available for closing.
Collection cards and lists omit the permanent item ellipsis.

SP-045: CollectionDuplicateSheet presents folder copy choices; CollectionsStore
owns atomic tree/membership copy and saved annotation-reference cleanup. JournalType
is an additive Notes domain field, while NoteEditorView owns the retractable tools.

## SP-046 study material ownership

`Features/Collections/PointToPonderSheets.swift` owns question creation/card and serial
Explore → Note modal flow. `CollectionModels.swift` owns PointToPonder values and
saved-passage note titles/content; CollectionsStore owns lifecycle/conversion commands.
The existing Collections generation repository/all-data backup carry schema 3 points.
`DesignSystem/StudyNoteDestinationPicker.swift` accepts initial New note title/content.
SettingsTrashViews exposes question recovery; RootTabView supplies Companion routing.

SP-047 extends `StudyMaterialSheets.swift` with the shared link editor, and
`CollectionFolderMove.swift` with the separate own-process material drag payload.
CollectionsStore owns link updates and access-checked material moves. Folder tiles
accept folder/material types declared in `AppInfoSupplement.plist`; existing
Collections generation schemas remain unchanged.

SP-048 retains QuizQuestionCachePolicy sizing, CompanionQuizCache orchestration and
QuizQuestionCacheCoordinator per-bucket in-flight ownership. CompanionSession guards
one successful initial load and owns bank/session persistence; RootTabView reconciles
foreground demand. QuizMeView reports readiness and QuizSessionView sizes summary
actions consistently. QuizBankLifecycleTests covers durable/event-driven bank behavior.

## Proposed Plan ownership — SP-049–052, not created

[Collection Plans](../design/collection-plans.md) proposes Core/Plans/ domain values and
Features/Plans/ authoring/playback/commands. These directories are proposals, not current
runtime modules. Collections retains memberships and checked generation persistence;
Notes/Annotations/Companion/Music retain their existing feature data and commands.
RootTabView composes the workspace but must not own Plan business logic. No runtime
repository-map or generated adapter change is needed for ticket authoring.

## Plan future file ownership resolved — no runtime files created

The [selected file/interface map](../data/collection-plans-contract.md#selected-module-interfaces-and-file-ownership)
now assigns future Core/Plans/, shared Core/Security/StudyAccessRequirements.swift,
Features/Plans/ command/playback/views/adapters, Features/Protection/StudyAccessCoordinator.swift
and Infrastructure/Backup/StudyRestoreJournal.swift. Existing feature stores remain owners;
CollectionsStore is the sole Collections writer. SP-049–052 are design-ready and unselected;
the actual repository map is updated when implementation creates these modules.

## SP-049 actual authoring/foundation modules — 2026-10-20

Core/Plans/ now contains StudyPlan.swift and PlanCommands.swift; Core/Security/ contains
StudyAccessRequirements.swift (including PlanOrigin). Features/Plans/ contains the command
service, owner-retained editor draft, editor/assignment picker and archive/Trash library.
CollectionsStore persists through a single queued writer, with a separate committed state
and compatibility projection for existing sync UI commands. Existing folder/Sophy/restore
paths no longer call the repository independently. Collections schema 4 and Notes schema 5
have sticky activation and version-2 wrappers/pointers with protected fallbacks.

Infrastructure/Backup/StudyRestoreJournal.swift owns local staged recovery inputs and phase
markers/hashes; StudyBackupService writes v2 all-data archives with inert Plan recovery data.
SettingsStudyBackupView offers explicit recovery actions. These files exist; the earlier
proposed ownership sections are planning history. Reader workspace/playback and Plan-owned
Pencil layers remain future SP-050/051 work. Source evidence lives in SP-049.

SP-049 owner correction (2026-10-20): Features/Plans/PlanDetailView.swift owns
content-first opening, explicit editing and basic Start/Resume using the existing
ReaderSession/ReaderTextSurface. CollectionsStore persists Next completion/cursor;
full D4 lifecycle and SP-051 ink/tools remain separate.

SP-050/051 owner presentation correction: PlanDetailView is fullscreen and theme-aware;
PlanStudyTools.swift owns checked reflection drafts/link creation. NoteCreatorSheet
allows awaited feature-specific creation while retaining its shared UI. NotesSession's
transient Plan presentation flag prevents second editor hosts in hidden tabs. Root
exposes the existing MusicSession to Plan controls; ReaderTextSurface's optional focus
changes only Plan verse colors, preserving default reader rendering.

SP-049 stability correction: `Features/Plans/PlanEditorDraft.swift` owns stable-ID
draft mutations, safe title bindings and stale-callback guards. PlanEditorView renders
value snapshots; PlanAssignmentPicker clamps dependent chapter bounds before book changes.
No persistence schema changes are involved.

## SP-053 editing refinement — 2026-10-25

PlanEditorDraft owns snapshot autosave and stable-ID reorder callbacks; CollectionsStore
owns atomic linked-folder updates and Scripture-reference material projections.
PlanDetailView exposes Linked Folder without constraining its position in Collections.
Collection/link/gleaning editors and Notes metadata/object/Prayer-update editors feed
their existing store/session writers. Core/Plans/StudyPlan.swift adds optional
materialsFolderID; no new runtime store, target or backend is introduced.

SP-053 folder creation/filing: PlanCommandService builds ensure-folder commands;
CollectionsStore remains the only writer for atomic folder creation and checked
material filing. Both editor assignments and reading reflections use it. The previous
optional-folder picker was removed by the strict lifecycle update below.

SP-053 inline editing: PlanEditorView supports creation and embedded presentations;
PlanDetailView mounts the editor directly in its workspace and owns header Done/Exit
flush boundaries. The separate main-Plan edit sheet is removed; assignment/folder
pickers retain their temporary sheets. No new module/store is introduced.

SP-053 section folders: Core/Plans/StudyPlan.swift owns optional section folder IDs.
CollectionsStore reconciles managed section children/edges through its existing serialized
writer. PlanAssignmentPicker/PlanStudyTools use each target section's folder, and
PlanEditorView passes stable section identity. No separate persistence service is added.

SP-053 strict lifecycle: CollectionModels owns PlanTreeTrash/v5 values; CollectionsStore
owns mandatory root commands and grouped deletion/restore. NotesSession owns checked
Notes Trash batching. Root reconciles durable pending phases. PlanLinkedFolderPicker
is removed; PlanEditor displays fixed identity. PlanDetail/Collection captions use
completed sections. Settings/Plan confirmations describe paired deletion.

SP-053 Scripture editing: Features/Plans/PlanScriptureAssignmentEditor.swift owns the
shared Plan/folder editor and stable target resolver. PlanAssignmentPicker handles
seeded Scripture-only fields and checked Save; PlanCommandService builds the guarded
replacement command. CollectionArtifactRow retains explicit Read Scripture actions.

Nested CollectionDetailView destinations pass the shared ReaderSession recursively,
so Scripture editing and other reader-dependent Plan controls remain available inside
all Day/Section folder depths.

SP-054 daily playback: Core/Plans/PlanSchedule.swift owns optional strict calendar dates
and start cursor derivation. Features/Plans/PlanPlaybackService.swift coordinates existing
Collections/Activity writers using durable session identity; ActivityStore retains timers
and History. PlanDetailView owns single-day presentation/completion and uses shared root
Companion/Activity environment objects. PlanEditorView owns activity/date input. No new
store or backend is introduced.

SP-055 reuses existing modules: CollectionsStore synchronizes owned root names on checked
save/adoption; CollectionArtifactPicker closes the parent creation flow. PlanSchedule owns
catch-up/date captions; PlanEditorDraft/View expose the optional Edit action. ActivityStore
pauses ordinary Plan stop commands; PlanPlaybackService records completed sections only.
Prayer Clear moves inside NotePrayerEditorView's existing More menu. No new store/schema.

SP-056 uses PlanDetailView plain Day buttons and one caption per Day. PlanSchedule and
PlanPlaybackService share targeted playback with main Play/Resume. Core/Activity's optional
pausedPlanDrafts and the existing Activity writer/repository retain same-Plan Day timers
across switches/relaunch, with single-running-draft validation and existing backup support.
