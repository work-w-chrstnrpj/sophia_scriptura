# Project Structure — Sophia Scriptura

Status: native SP-006/SP-007 prototypes plus SP-009 reader implementation, 2026-09-22.

| Path | Responsibility and present state |
| --- | --- |
| `application/SophiaScriptura/SophiaScriptura.xcodeproj/` | App, unit and UI targets; simulator build verified |
| `application/SophiaScriptura/SophiaScriptura/Features/` | Six tabs; Notes contains `CanvasExperiment/` model, session, UIKit surface, SwiftUI controls, fixture store and opt-in DEBUG-only memory probe |
| `application/SophiaScriptura/SophiaScriptura/Core/` | `Scripture/` domain models, repository contracts and UTF-16 selection map; other boundary protocols remain placeholders |
| `application/SophiaScriptura/SophiaScriptura/Features/Collections/` | SP-007 in-memory prototype: separate library/detail views, cards/rows, picker/editor sheets, adaptive style, models and observable store; no file/provider access |
| `application/SophiaScriptura/SophiaScriptura/DesignSystem/` | Shared seven-preset palette roles and offline font registration; UI-only, no content or storage access |
| `application/SophiaScriptura/SophiaScriptura/Resources/Fonts/` | Nine bundled font families, OFL notices and source/checksum manifest |
| `service/ingestion/` | Strict offline USFM importer, VPL comparison and importer tests; generated WEBP SQLite/manifest |
| `shared/` | Book-code and prompt seed JSON; schema/guardrails still need review |
| `application/SophiaScriptura/SophiaScripturaTests/`, `SophiaScripturaUITests/` | Executable native experiment tests |
| `tests/` | Cross-cutting testing guidance; target fixtures/cases are planned |
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
