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

Intended user workflows (mostly not implemented):

- Read scripture across multiple translations. Free access is prioritized; NIV, NLT,
  NKJV and ESV are preferred. Provider access and offline permissions remain subject
  to SP-002; WEB is a proposed bundled base. See TDD §8.
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
- Listen to permitted narration or on-device text-to-speech where content rights allow.
- Track reading sessions with a timer or manual entry and view local analytics.

Highest-level system responsibilities: render scripture with tappable verse anchors,
persist user study data locally, keep ink annotations aligned per version and chapter,
anchor all study artifacts to canonical verse references, and mediate AI requests
through a provider-agnostic bring-your-own-key adapter without leaking secrets.

## Implemented and proposed technology

- Application/runtime: `SwiftUI on iPadOS 17+ (Swift 5.9+, Xcode 16+)`
- Service/API layer: no runtime backend. SP-010 implements a direct on-device API.Bible
  client and encrypted licensed-content sync for the owner-approved NIV11, NLT and NKJV IDs.
- Current runtime stores: SP-006 retains an isolated atomic JSON experiment fixture;
  SP-013 adds validated Notes generations with ink/images and Notes-only recovery.
  SP-009 implements bundled read-only SQLite plus local-only SwiftData reader state.
  SP-010 adds AES-GCM-encrypted Core Data payloads and device-only Keychain state for
  licensed editions; remaining study data contracts are still staged by feature.
- Testing: `XCTest (unit and UI); manual test cases under tests/ and docs/testing.`
- Deployment: `Personal sideload from Xcode to the owner's iPad (free Apple Developer account, 7-day signing validity). No CI/CD, no server, no App Store distribution.`

## Repository Map

Update this map whenever the project structure changes.

- `application/`: the SwiftUI iPad app. `application/SophiaScriptura/` holds the Xcode
  project: the six tabs (Scripture, Collections, Notes, Companion, Activity, Settings)
  with the SP-013 Notes library/editor, isolated SP-006 experiment, and SP-007 in-memory
  Collections prototype. Collections
  separates library/detail, picker/editor, components, styling and temporary data; Core
  contains Scripture domain contracts, selection mapping, annotation and Notes contracts,
  plus remaining placeholder protocols. Infrastructure contains Notes recovery,
  reader SQLite/SwiftData adapters and SP-010's API.Bible,
  encrypted-store and Keychain adapters; Resources/Scripture bundles WEBP content.
  Features/Scripture/LayoutValidation holds the DEBUG-only SP-008 continuous-chapter
  PencilKit experiment; its disposable ink is separate from production study storage.
  AppShell owns the tab-dock idle timer and passive finger-scroll observation; RootTabView
  preserves mounted tab state while animating navigation.
  DesignSystem owns reader appearance tokens, shared AppTheme surfaces across tabs, and font registration; Resources/Fonts
  contains the selected offline font families, licenses and provenance.
- `service/`: no runtime backend; strict local WEBP USFM importer and independent VPL validation. Content permissions must
  be verified before implementing downloads.
- `shared/`: book-code and prompt-preset seed JSON; not a completed shared runtime.
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
