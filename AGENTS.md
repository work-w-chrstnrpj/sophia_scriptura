# Project Agent Rules

Source of intent: `docs/tdd/tdd.md`. Source files remain the final implementation truth.

Agents working in this repository must keep implementation and documentation changes aligned with the project goal:

```text
Build Sophia Scriptura, a personal, offline-first iPadOS Bible study app for a single
user that unifies scripture reading, Apple Pencil annotation layers, note taking,
verse-anchored collections, a guardrailed AI study companion (BYOK), audio playback,
and a Bible reading habit tracker — grounded in historic orthodox Christian conviction.
```

## Owner-directed development

Follow `docs/guidelines/ai-structure-guidelines.md` and `.ai/context-routing.md`.
The owner chooses the next ticket. Before implementation, name the ticket, milestone,
visible outcome, exclusions, affected modules, and checks. A ready ticket is not automatic
permission to execute it. Continue necessary work inside the selected scope without
repeated confirmation; return to the owner before starting another ticket or new feature.
Planning, feedback, and architecture-review requests do not authorize app implementation.
Use existing `.agents/` roles and skills as applicable; role selection does not itself
require spawning agents. End each ticket with evidence, gaps, and status.

## Project Overview

Sophia Scriptura is a native SwiftUI application for iPadOS 17+, built and run by its
single owner on a personal iPad using a free Apple Developer account (weekly re-deploy
from Xcode). It is explicitly not a production or App Store product.

Target user: one person doing personal Bible study and discipleship.

Implemented study workflows (see source and tickets for acceptance limits):

- Read scripture across multiple translations. Free access is prioritized; NIV, NLT,
  NKJV and ESV are preferred. Provider access and offline permissions remain subject
  to source-specific policy. Bundled WEBP, API.Bible NASB/NLT/NKJV and eligible Hello AO editions are implemented; ESV remains a draft. See TDD §8.
- Toggle a transparent Apple Pencil annotation layer over the text, with an optional
  extended ruled writing area beside the scripture column.
- Tap chapter and verse numbers to see everything anchored to that verse: notes,
  conversations, saved verses, and links.
- Select scripture text to Copy, Ask (start a guardrailed AI conversation auto-linked
  to the verse), Save (as a gleaning, bookmark, or note quote), or Share.
- Chat with an AI Companion whose every conversation starts from an editable prompt
  preset that carries orthodox theological guardrails.
- Take OneNote-style notes mixing typed text, ink, images, tables, quotes, and link
  cards; group by tag; sort by title or date; view as cards or a list.
- Group notes, conversations, scriptures, and links into collections shown as folders.
- Listen to permitted AO narration through SP-039; ESV audio remains draft scope and TTS is not an approved substitute.
- Track reading sessions with a timer or manual entry and view local analytics.

Highest-level system responsibilities: render scripture with tappable verse anchors,
persist user study data locally, keep ink annotations aligned per version and chapter,
anchor all study artifacts to canonical verse references, and mediate AI requests
through a provider-agnostic bring-your-own-key adapter without leaking secrets.

## Implemented and proposed technology

- Application/runtime: `SwiftUI on iPadOS 17+ (Swift 5.9+, Xcode 16+)`
- Service/API layer: no runtime backend. SP-010 implements a direct on-device API.Bible
  client and encrypted licensed-content sync for the owner-approved NASB, NLT and NKJV IDs.
- Current runtime stores: SP-006 retains an isolated atomic JSON experiment fixture;
  SP-013 adds validated Notes generations with ink/images and Notes-only recovery.
  SP-009 implements bundled read-only SQLite plus local-only SwiftData reader state.
  SP-010 adds AES-GCM-encrypted Core Data payloads and device-only Keychain state for
  licensed editions. Collections, Companion, Activity and Sophy have independent local
  stores; StudyBackupService composes study exports through feature owners.
- Testing: `XCTest (unit and UI); manual test cases under tests/ and docs/testing.`
- Deployment: `Personal sideload from Xcode to the owner's iPad (free Apple Developer account, 7-day signing validity). GitHub Actions verifies/publishes source releases; device signing/install remains local. No runtime server or App Store distribution.`

## Repository Map

Update this map whenever the project structure changes.

- `application/`: the SwiftUI iPad app. `application/SophiaScriptura/` holds the Xcode
 project: the six tabs (Scripture, Collections, Notes, Companion, Activity, Settings)
 with the SP-013 Notes library/editor, isolated SP-006 experiment, and persisted
 Collections workspace (SP-015 onward). M6 adds `Core/Companion/`, `Infrastructure/Companion/` (local
 generations, Keychain provider keys, streaming adapters, bundled prompt presets,
 SP-019 quiz refill coordinator) and `Features/Companion/` (conversation UI, session,
 quiz cache orchestration). Collections
  separates library/detail, picker/editor, components, styling and persisted store commands; Core
  contains Scripture domain contracts, selection mapping, annotation and Notes contracts,
  plus remaining placeholder protocols. Infrastructure contains Notes recovery,
  reader SQLite/SwiftData adapters and SP-010's API.Bible,
  encrypted-store and Keychain adapters; Resources/Scripture bundles WEBP content.
  Features/Scripture/LayoutValidation holds the DEBUG-only SP-008 continuous-chapter
  PencilKit experiment; its disposable ink is separate from production study storage.
  Features/Drawing owns SP-014's shared production Pencil endpoint-hold and conservative
  geometric stroke refinement used by Notes and Scripture annotations; feature controllers
  retain viewport, undo and persistence ownership. Assets.xcassets owns the supplied
  default/dark/tinted Sophia app icon catalog.
  AppShell owns the tab-dock idle timer and passive finger-scroll observation; RootTabView
  preserves mounted tab state while animating navigation.
  DesignSystem owns reader appearance tokens, shared AppTheme surfaces across tabs, and font registration; Resources/Fonts
  contains the selected offline font families, licenses and provenance.
- `service/`: no runtime backend; strict local WEBP USFM importer and independent VPL validation. Content permissions must
  be verified before implementing downloads.
- `shared/`: book-code and prompt-preset seed JSON; not a completed shared runtime.
- `scripts/install-ipad.sh`: personal signed Debug build, signature/identity checks,
  in-place iPad install and normal launch; usage lives in the deployment guide.
- `tests/`: cross-cutting manual and automated tests. Native SP-006 targets live in
  `application/SophiaScriptura/SophiaScripturaTests/` and `SophiaScripturaUITests/`.
  The isolated prototype lives in `Features/Notes/CanvasExperiment/`; its physical
  walkthrough is `docs/testing/sp006-ipad-guide.md`.
- `docs/`: project intent, contracts, architecture, operations, and quality
  documentation (this repository's wiki). Canonical technical intent lives in
  `docs/tdd/tdd.md`; the reader data contract lives in `docs/data/`; work tracking lives
  in `docs/development-plan/development-plan.md`.
- `.agents/`: canonical reusable AI roles, skills, overlays, workflows, and tool policies.
- `.ai/`: context routing, maps, prompt recipes, and generated-index guidance.
- Tool adapters: `.claude/`, `.codex/`, `.cursor/`, `.github/`, `.opencode/`, and other generated folders expose canonical assets in each tool's expected format.

## Core Operating Rules

- Consider [docs/guidelines/backward-compatibility.md](docs/guidelines/backward-compatibility.md) before persistence, migration, or delete/archive behavior changes.
- Prefer project wiki pages as the source of product intent.
- Prefer exact source files as the source of implementation truth.
- Use maps, indexes, graphs, and summaries only for discovery.
- Read exact files before changing them.
- Make small, reviewable edits that follow the project structure.
- Run relevant verification before claiming success.
- Ask for approval before destructive, high-risk, production, secret, or migration operations.

## Documentation Rules

- Keep `docs/tdd/tdd.md` canonical for technical intent.
- Update API, data, diagram, testing, deployment, and project-structure docs pages when behavior or architecture changes.
- If work is tracked in `docs/development-plan/development-plan.md`, update the matching status.
- Do not add project-specific requirements to reusable template files unless the project has adopted them.

## Security Rules

- Do not commit secrets, tokens, private keys, credentials, or production configuration.
- Do not log sensitive input, provider responses, credentials, or private user data.
- Validate input at trust boundaries.
- Prefer least privilege for accounts, tokens, services, and automation.

## Git And PR Rules

- Check `git status` before major edits.
- Do not revert user changes unless explicitly asked.
- Keep commits scoped and explain verification in PR notes.
- Avoid force push, reset, clean, or destructive history operations without explicit approval.

## Canonical AI Structure

Canonical reusable AI assets live in `.agents/`:

- `.agents/roles/`: 8 role owners.
- `.agents/skills/`: reusable workflow skills only.
- `.agents/overlays/`: Mentor and Coach overlays.
- `.agents/workflows/`: multi-role workflows.
- `.agents/tools/`: context, verification, adapter, and tool policies.

Tool-specific folders are generated adapters, not source of truth. Update canonical files first, then run `scripts/sync-ai-adapters.ps1`.

## Overlay Usage

Use overlays to change response style without changing work ownership.

Examples:

- `Mentor ELI12: Explain this architecture.`
- `Coach: Critique this plan.`
- `Backend & Database Engineer + Mentor: Explain this API design.`
- `System Architect + Coach: Challenge this architecture proposal.`

## AI Role Usage Guide

Portable role prompts live in `.agents/roles/`. Tool-specific generated adapters live under `.claude/agents/`, `.codex/agents/`, `.cursor/rules/`, `.github/agents/`, and `.opencode/agents/`.

- System Architect: architecture, module boundaries, dataflow, and technical risk.
- Product & Planning Manager: requirements, acceptance criteria, task breakdown, dependencies, and progress coordination.
- Frontend UI/UX Developer: UI, routing, state, accessibility, client behavior, and frontend tests.
- Backend & Database Engineer: APIs, services, validation, auth, persistence, integrations, jobs, queues, and data ingestion.
- DevOps Engineer: CI/CD, deployment, runtime config, automation operations, monitoring, and releases.
- Security Engineer: secrets, auth, authorization, dependency risk, unsafe inputs, logging, and sensitive workflows.
- SQA Engineer: test plans, manual cases, automated tests, regressions, acceptance verification, and bug reports.
- Technical Documentation Specialist: README, API docs, setup, onboarding, operations, workflow, integration, and changelog docs.

## Skill Usage Guide

Create or keep a standalone skill only when it defines a reusable workflow with clear inputs, steps, boundaries, and outputs.

Do not create standalone skills for every role capability. Put domain-specific capability guidance inside the owning role file under `Embedded Capability Playbooks`.

Reusable skills live in `.agents/skills/`. Tool-specific skill copies are generated for Claude, Cursor, GitHub Copilot, OpenCode, and Windsurf; Codex and Antigravity use `.agents/skills/` directly. Choose the smallest skill that matches the task, then read exact source files before editing.

## Verification Commands

Use `docs/testing/test-specification.md` for the current native test command and
`docs/deployment/deployment.md` for builds, signing and physical-device execution.
The actual project exists at `application/SophiaScriptura/SophiaScriptura.xcodeproj`.
Use the SophiaScriptura scheme and an installed iPad simulator; do not assume an M4
simulator exists. Set DEVELOPER_DIR per command where the Mac selects Command Line Tools.
Keep result bundles in ignored `build/` and summarize evidence in the ticket.
Documentation-only changes require relevant link/path and `git diff --check` validation;
do not rerun native tests without a code change or unresolved verification need.

## SP-033 structure update

`Core/Scripture/ScriptureReferenceIdentity.swift` and `TranslationSourceContracts.swift` own
source-neutral edition identity, rights policy and operation authorization boundaries.
`Infrastructure/Scripture/MultiSourceTranslationLibrary.swift` coordinates bundled WEBP,
existing `OfflineTranslationLibrary` (API.Bible) and `Infrastructure/Scripture/HelloAO/`
(catalog, parser, generation store and edition repository). `Features/Scripture/ReaderSession.swift`
`ScriptureTranslationPickerView.swift` (read-only edition choice) and `ScriptureTranslationDownloadsView.swift` (AO/API download management) replace the combined Versions sheet; Settings opens downloads directly
and API.Bible sync separately. SP-039 adds `Core/Scripture/ScriptureNarrationValues.swift`,
`ScriptureNarrationTiming.swift`, `Features/Scripture/ScriptureNarrationSession.swift` and
Hello AO chapter narration transport wired through `StudyAudioCoordinator`. SP-038 acceptance
and v1.0.0 publication remain separate gates.

## SP-012 structure update

`application/SophiaScriptura/SophiaScriptura/Core/Annotations/` contains annotation values
and repository contracts. `Infrastructure/Annotations/` owns generation persistence and
ink-only backup/recovery. `Features/Scripture/Annotations/` owns actual-reader layers,
layout and PencilKit integration. `docs/data/scripture-annotation-contract.md` and
`docs/testing/sp012-ipad-guide.md` define contract and acceptance. These are separate from
SP-008's disposable LayoutValidation harness and SP-006's Notes fixture.

## SP-013 structure update

`Core/Notes/` owns production document/object geometry and repository contracts;
`Infrastructure/Notes/` owns validated generations and Notes-only recovery;
`Features/Notes/Editor/` owns the production mixed-object canvas. `NotesSession` coordinates
library edits, history and autosave. SP-006 remains a separate DEBUG experiment.
`docs/data/notes-contract.md` and `docs/testing/sp013-ipad-guide.md` define durability
and remaining physical acceptance. Root shares Notes with the verse hub.

SP-013 study-page revision: `Core/Notes/NoteDocument.swift` adds `NotePage` and
`NoteCitation`. `Features/Notes/Editor/NoteCanvasSurface.swift` renders the fixed body,
floating objects and Pencil overlay; `NoteScripturePane.swift` composes the existing
reader beside the note. `NotePageTypography.swift` shares fixed-column measurement and
text styling. Root passes the shared ReaderSession into Notes.

SP-013 Canvas/Page revision: `NoteDocument.swift` now stores one tagged `NoteContent`.
`NoteCanvasSurface.swift` exposes Canvas/Page controllers with shared viewport/input
plumbing. `NoteCanvasInk.swift` maps scene strokes to framed objects;
`NotePageAttachments.swift` renders inline Page images/tables/links. New Page content
flows within the fixed column; old Page floating items stay in `legacyObjects`.
`NotesFileRepository` writes v3, reads v1/v2 and retains `before-note-types.notes`.

SP-013 workspace refinement: `NoteObjectStyle.swift` adds optional shape/tint values;
`NoteInsertGallery.swift` owns shape/emoji choices, `NoteInkAppearance.swift` adapts neutral
ink to theme, and `NoteLinkPreview.swift` fetches explicit link previews. The editor owns
contextual selection actions; Root overlays the dock while editing to reclaim writing space.

v0.2.0 Notes follow-up: `Core/Notes/NoteTextFormatting.swift` owns body span values and
formatting operations. `Features/Notes/Editor/` adds `NoteFormatPopover.swift`,
`NoteInkColorPalette.swift`, `NoteBlockQuoteBarView.swift`, `CanvasObjectPaletteBuilder.swift`,
and `NoteMediaCapture.swift` for formatting UI, Canvas actions and camera/scan/audio input.
New object editor fields decode with defaults; see `docs/releases/v0.2.0.md` for release evidence.

## SP-015 structure update

`Features/Collections/` now persists through `Infrastructure/Collections/CollectionsFileRepository.swift`.
`CollectionsStore` owns folder, membership, move/assign and saved-passage commands; No Folder
is virtual (`StudyCollection.unfiledID`). `CollectionDestinationPicker.swift` holds the shared
folder chooser; `PassageSaveSheet.swift` and `PassageCardSheet.swift` own bookmark/gleaning
save and centered cards. Scripture builds ellipsis excerpts via `ChapterTextMap.excerpt(in:)`.

## SP-020 structure update

`Core/Activity/` owns modes, records, active intervals and local metrics;
`Infrastructure/Activity/` owns the Activity-only checked file and archive.
`Features/Activity/` owns the screen, timer commands and Files UI. Root hosts the
cross-tab Activity control and passes the reader's verse catalog into Reading selection.
`Core/Activity/` also defines reminder values; `Infrastructure/Activity/ActivityReminderNotifications.swift`
owns local notification scheduling and `Features/Activity/ActivityRemindersView.swift`
owns their editor. Settings exposes one-time reminder cleanup. Analytics can export PNG.
Original M7 narration was abandoned; later SP-039 adds AO narration. SP-021 adds `Core/Music/`, `Infrastructure/Music/`, `Features/Music/`, and AppShell Now Active plus `StudyAudioCoordinator` for background music; the owner closed M8 with placeholder tracks; commercial track rights remain separate.

## SP-022 structure update

`Core/Activity/MeditationJourney.swift` owns launch values, passage rules, bundled seed
catalog and passage text resolution. `Features/Activity/MeditationJourneyCoordinator.swift`
and `MeditationJourneyView.swift` own the fullscreen swipe journey. Root overlays the journey
above tab content while keeping music and Activity recorder FABs visible; the tab dock hides
during the journey. `ActivityView` starts the journey when Meditating is started from Start
Activity. `Resources/Activity/meditation-passages.seed.json` supplies default seven-passage sets.

## SP-023 structure update

`Features/Scripture/ChapterHubView.swift` owns the chapter index over existing links and
conversations. `Core/Companion/CompanionModels.swift` distinguishes optional chapter anchors
from verse-range anchors; `CompanionSession` owns chapter Ask/query commands.
`CompanionContextBuilder` composes reference-only chapter or authorized verse context beside
manual questions without rewriting stored user messages. `ScriptureHubTests.swift` covers
provider-bound requests, persistence, chapter aggregation and disclosure boundaries.
`Infrastructure/Companion/CompanionStudySources.swift` owns selected-passage links and
reference lookup/provenance; `CompanionSourcesTests.swift` covers source and model fallback
regressions. The Chapter control is hosted in the annotation/actions row.

## SP-025 structure update

`Features/Notes/Editor/NoteInkStrokeIndex.swift` owns internal stroke references, deterministic
legacy IDs and grid/geometry queries. `NoteCanvasInk` retains PKDrawing regions with optional
parallel `strokeIDs` in `Core/Notes/NoteDocument.swift`, reconciliation/editing and safety spill.
NotesSession owns stroke selection/history; NotesFileRepository validates ID cardinality
and stores rejected drawing recovery beside Notes generations. See the Notes contract
and `NoteStrokeEditingTests.swift`. Authentication tickets SP-026–028 remain separate.

## SP-030 structure update

`Infrastructure/Music/MusicNowPlayingCoordinator.swift` owns Lock Screen / Control Center remote commands and Now Playing metadata; `BackgroundMusicEngine` exposes duration and resume-friendly playback. `Core/Activity/ActivitySystemProjection.swift` and `StudyActivityLiveActivityAttributes.swift` define the safe timer projection. `Infrastructure/Activity/ActivityLiveActivityCoordinator.swift` projects committed Activity drafts to ActivityKit. `StudyActivityWidgetExtension/` is the WidgetKit Live Activity target embedded in the app. `ActivityStore` publishes `committedProjection` only after successful saves. `RootTabView` reconciles Live Activities on foreground and handles `sophiascriptura://activity`. Physical G0 placement and extension signing acceptance are tracked in [SP-030](tickets/SP-030-background-music-and-activity-system-controls.md).

## SP-029 structure update

`Core/Sophy/` owns response values, strict JSON validation, eligibility, insights, context limits and execution-state rules.
`Infrastructure/Sophy/` owns history, journal generations and the Lady Wisdom preference.
`Features/Sophy/` owns the session, durable action executor, adaptive chat sheet, editable action preview, dedicated History and enhancement screens. `Core/Sophy/SophyNoteSelection.swift` owns transient typed-text selection snapshots; native Page/Canvas edit menus call the shared Notes session. Review evidence and remaining acceptance live in `docs/testing/sp029-sophy-review.md`.
Hugging Face is an OpenAI-compatible adapter in `Infrastructure/Companion/`, and the shared
default route lives on `CompanionSnapshot`. Folder and Activity Sophy commits are awaited
commands on the existing stores. Notes replacement goes through `NotesSession.applySophyReplacement`.
The character stays hidden until Settings “Turn on Lady Wisdom” is on.

## SP-026–028 structure update

Whole-item app access protection is owned by `Features/Protection/` with credential persistence in `Infrastructure/Security/ItemLockCredential.swift`. Preserve independent category grants, the single authentication prompt, stale-result invalidation, flush-before-conceal and guarded session/store commands. Read `docs/security/item-protection.md` before changes: access locks are not encryption, unknown credential bindings fail closed, and simulator evidence does not close physical biometric/Pencil/privacy acceptance. Combined Settings actions affect only already protected records.

## SP-031 structure update

`Features/SystemPlayer/StudyPiPPlayer.swift` owns the sample-buffer floating study player,
safe presentation state and explicit PiP preview. RootTabView owns coordinator lifetime;
MusicSession/ActivityStore retain command and persistence ownership. BackgroundMusicEngine
retains the shared audio session while PiP is active. See tickets/SP-031-study-picture-in-picture.md
for limits and physical acceptance; no permanent Home-screen notch is implemented.

## SP-040 structure update

`Features/Collections/CollectionFolderMove.swift` owns typed folder drag/drop and the
full-tree move sheet; `CollectionsStore` validates and persists subtree reparenting.
`NoteJournalFields` owns Journal icon presentation, and `PrayerStatusStamp` in
`NotePrayerEditorView.swift` owns the presentation-only Prayer status mark.

`Features/Notes/NoteLibraryCard.swift` owns shared Notes/Collection note-card
presentation, previews and stamp activation; hosts own navigation/context actions.

## SP-044 structure update

`DesignSystem/StudySwipeReveal.swift` owns transient swipe-reveal presentation for
Collection/Notes records and Prayer updates; hosts retain menus/command ownership.

SP-044 dismissal follow-up: RootTabView supplies StudySwipeCoordinator for a single
open action rail. AppShell/ScrollActivityObserver passively dismisses it on vertical
finger intent; StudySwipeReveal keeps the shifted record body available for closing.
Collection cards and lists omit the permanent item ellipsis.

## SP-045 structure update

`Features/Collections/CollectionDuplicateSheet.swift` owns the duplicate modal;
CollectionsStore owns guarded atomic folder-tree/membership copy and annotation
reference cleanup. NotesSession owns standalone note copy and Journal Type commands;
Core/Notes/NoteDocument.swift owns additive JournalType decoding. NoteEditorView
owns transient retractable tools and type selection.

## SP-046 structure update

`Features/Collections/PointToPonderSheets.swift` owns question creation and serial
question/Explore/New note modals. CollectionModels/CollectionsStore own persisted
PointToPonder values, Trash lifecycle and Bookmark → Gleaning commands. Collections
schema 3 and all-data backups include points; older schemas default to none.
NoteCreatorSheet accepts initial titles/content; existing NotesSession and Companion
retain creation/send ownership. SettingsTrashViews exposes point recovery.

## Source documentation checkpoint — 2026-10-18

v1.3.2/build 27 includes the SP-048 Quiz Me bank lifecycle changes and documentation
reconciliation. `QuizQuestionCachePolicy` sets 100 minimum / 200
capacity per scoped type/difficulty bucket with 10-question refill batches.
`CompanionQuizCache` owns reservation-triggered refill; `CompanionSession` guards initial
load and persistence; RootTabView reconciles foreground demand. Physical/provider-quality
and suspension acceptance remain separate from recorded simulator/build/install evidence.

## SP-049 structure update — authoring slice

`Core/Plans/` owns Plan/section/item identity, canonical assignments, validation and typed
commands/receipts. `Core/Security/StudyAccessRequirements.swift` owns copied Notes/Collections
credential requirements. `Features/Plans/` owns content-first PlanDetailView, editor/assignment picker/lifecycle UI and
PlanCommandService; CollectionsStore remains the sole Collections persistence writer.
Collections schema 4 and Notes schema 5 activate v2 wrappers/pointers; legacy supported
formats remain readable. `Infrastructure/Backup/StudyRestoreJournal.swift` owns local staged
restore input/phase checkpoints; Settings backup exposes explicit recovery. Basic Start/Resume uses the existing ReaderSession/ReaderTextSurface with durable Next
progress and section summaries; a separate app mode is not required. Plan pages are fullscreen and use shared theme surfaces/full book names. Optional
ReaderTextSurface Plan focus dims unassigned verses. PlanStudyTools.swift coordinates
checked note/link reflection creation; the shared Notes editor previews content inside
the Plan, and the icon bar reuses the root MusicSession. NotesSession tracks transient
Plan presentation ownership to prevent duplicate offscreen editors. Full reader lease,
Plan Pencil and remaining tools remain SP-050/051 acceptance scope. No Plan runtime
backend is introduced. See the SP-049 ticket for verification limits.

SP-049 stability correction: `Features/Plans/PlanEditorDraft.swift` owns stable-ID
draft mutations, safe title bindings and stale-callback guards. PlanEditorView renders
value snapshots; PlanAssignmentPicker clamps dependent chapter bounds before book changes.
No persistence schema changes are involved.

## SP-053 structure update

PlanEditorDraft owns debounced, responsive snapshot autosave. StudyPlan adds optional
materialsFolderID; CollectionsStore atomically creates/renames the Plan folder and
files shared targets plus reference-only Scripture item projections. CollectionDetailView
opens these references with existing reader navigation. Notes detail/object/Prayer-update
editors feed NotesSession autosave; Collection/link/gleaning editors feed CollectionsStore.
See tickets/SP-053-plan-autosave-and-materials-folders.md for acceptance evidence.

SP-053 folder ownership now uses a mandatory fixed root; the earlier optional-folder
workflow and its picker were removed. Both new note/link entry points use checked
section-folder filing receipts. See the strict lifecycle update below.

SP-053 inline editing: PlanDetailView owns the transient editor draft and renders
PlanEditorView embedded inside its main workspace. Header Done/Exit flush edits;
PlanEditorView retains creation presentation and shared tools/autosave.

SP-053 section folders: PlanSection.materialsFolderID is optional. CollectionsStore
atomically organizes assignments in named section children and retains the shared Plan
at the linked root. New note/link routes use sectionID for checked child filing.

SP-053 strict lifecycle: Plan roots are mandatory/immutable. CollectionModels owns
Collections v5 PlanTreeTrash bundles; CollectionsStore owns paired tree Trash/restore
and NotesSession owns checked note batching. Root reconciles pending phases. Optional
folder picker is removed. Progress captions count completed Days/Sections.

SP-053 Scripture editing: PlanScriptureAssignmentEditor.swift is shared by Plan and
section-folder projections. PlanAssignmentPicker seeds the current passage;
PlanCommandService.replaceScripture checks revision/access and uses the existing writer.

## SP-054 structure update

`Core/Plans/PlanSchedule.swift` owns optional strict dates and start-cursor derivation.
`Features/Plans/PlanPlaybackService.swift` coordinates one-day playback through the
existing Collections and Activity writers, with optional cursor session and Activity
Plan/section IDs for retry/relaunch. PlanDetailView owns completion/exit and reuses root
Companion/Activity environment objects. PlanEditorView exposes activity type and optional
dates. Current schemas remain unchanged; missing fields preserve legacy defaults.

## SP-055 structure update

CollectionsStore synchronizes managed Plan root names during saves/adoption while preserving
custom descriptions/location. CollectionArtifactPicker owns closing Add Items after saved
Plan creation. PlanSchedule owns explicit optional Catch up and shared date captions;
PlanEditorDraft/View own its edit/autosave action. PlanPlaybackService checks section
completion before Activity History; ordinary Activity stop only pauses Plan drafts.
NotePrayerEditorView exposes confirmed Clear only in More. Existing schemas/keys remain.

## SP-056 structure update

PlanDetailView Day headings call shared playback with a section ID; dates appear only once
below each Day. PlanSchedule resolves targeted/resumed/replayed cursors. ActivityStore
retains switched-out Day timers in optional ActivitySnapshot.pausedPlanDrafts; repository
validation, mode canonicalization, overlap detection, backups and Activity clearing include
them. Existing stored formats remain readable without a conversion or schema bump.

## SP-057 structure update

`Features/Notes/Editor/PrayerPageLayout.swift` shares the compact Prayer writing region and maximized gray dashed guide geometry. NotePageController retains canonical text/ink coordinates while fitting the preview to its actual width. NoteEditorView presents the existing NoteEditorSheet from every kind's More menu, shared by Notes and Collections entry routes.
