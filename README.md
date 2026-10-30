<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/readme/sophia-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="docs/assets/readme/sophia-light.svg">
    <img src="docs/assets/readme/sophia-light.svg" alt="Sophia Scriptura — A quiet place to read, reflect, and grow." width="100%">
  </picture>
</p>

<p align="center">
  A personal, offline-first Bible study workspace for iPad.<br>
  Scripture, handwritten thought, and thoughtful study — together.
</p>

<p align="center">
  <a href="https://github.com/work-w-chrstnrpj/sophia_scriptura/releases/latest">Latest release</a> ·
  <a href="docs/README.md">Explore the wiki</a> ·
  <a href="docs/deployment/deployment.md">Run on iPad</a> ·
  <a href="docs/releases/README.md">Release history</a>
</p>

<p align="center">
  <a href="https://github.com/work-w-chrstnrpj/sophia_scriptura/actions/workflows/release.yml"><img src="https://github.com/work-w-chrstnrpj/sophia_scriptura/actions/workflows/release.yml/badge.svg?branch=main" alt="Release workflow status on main"></a>
  <br>
  <sub>SwiftUI · PencilKit · iPadOS 17+ · Local-first · Bring your own AI key</sub>
</p>

---

## A quiet place to read, reflect, and grow

Sophia Scriptura is a native iPad Bible study app that brings Scripture, Apple Pencil
handwriting, notes, collections, AI-assisted study, audio and reading habits into one
personal workspace. It is built for the rhythm of personal study: read carefully, ask a
question, write a reflection, connect it to a passage and return to it later.

The app is grounded in historic orthodox Christian conviction. Its AI instructions
encourage sound interpretation, Scripture interpreting Scripture, historical context and
careful treatment of differing Christian traditions. The reader retains responsibility
for discernment, interpretation and checking sources.

Sophia is designed for one person's iPad, with local study storage and optional online
services. It requires no Sophia account and has no runtime backend or cloud sync. The
project is developed for personal sideloading from Xcode and is not distributed through
the App Store.

[Explore the features](#your-study-workspace) · [See the technology](#technology-and-architecture) ·
[Run on iPad](#getting-started) · [Read the documentation](#project-guide)

## One connected study session

Imagine studying Ephesians 2:8–9:

1. **Read** the passage in the Scripture tab and choose an installed translation.
2. **Annotate** it with Apple Pencil on a transparent layer, with extra writing space
   around the Scripture column when needed.
3. **Explore** a selected verse through Ask or Original Language Analysis, keeping its
   reference and authorized context attached to the conversation.
4. **Capture** your response in a Page, arrange ideas on a Canvas, or write a Prayer or
   Journal entry. Keep Scripture visible beside the note while writing.
5. **Collect** the passage, conversation, note and further-reading links in a topic folder.
   Save a Point to Ponder for the next study session.
6. **Return** through the folder or Verse Hub, review with Quiz Me, and track the time
   you spend reading and studying in Activity.

The same note or conversation can belong to several folders without becoming separate
copies. Scripture quotations retain their passage and edition identity. Handwritten
Scripture layers stay tied to their own edition and captured layout.

## Your study workspace

Six tabs provide the main destinations; shared controls keep music, activity timing and
optional assistance available as you move between them.

| Space | Purpose |
| :--- | :--- |
| **Scripture** | Read, switch editions, annotate, listen and open passage-linked study material. |
| **Collections** | Organize bookmarks, gleanings, notes, conversations, links, annotation references and reflection questions. |
| **Notes** | Write and draw in Canvas, Page, Prayer and Journal formats. |
| **Companion** | Hold contextual study conversations, inspect sources and review with quizzes. |
| **Activity** | Track study sessions, reading progress, goals, reminders and local analytics. |
| **Settings** | Personalize appearance, configure online services, manage data and enable optional features. |

### Scripture: read, mark and revisit

The reader uses continuous chapters, book/chapter/verse navigation, horizontal chapter
swipes and remembered reading position. Seven appearance presets, bundled offline fonts,
text sizing and light/dark/system themes let you adjust the reading environment.

- **Multiple Scripture sources:** bundled World English Bible Protestant Edition
  (**WEBP**, shown as WEB), API.Bible integration for NASB/NLT/NKJV, and eligible Hello AO
  editions including KJV, BSB, ASV, LSV and WEBU. Installed-edition selection and download
  management have separate screens. API.Bible needs your credential and appropriate
  access; each source keeps its own content and offline-use policy.
- **Apple Pencil layers:** create multiple edition-specific annotation layers and switch
  among Read Hidden, Read Visible and Draw. Captured layouts preserve the relationship
  between words and ink. The optional surrounding writing area supports pan and zoom.
- **Selection actions:** Copy, Share, Ask, Original Language Analysis and Save connect
  a passage to the rest of the workspace, subject to its source permissions.
- **Verse and Chapter Hubs:** revisit verse-linked study artifacts or browse a chapter's
  links and conversations. Chapter Ask attaches a chapter reference rather than silently
  transmitting the full chapter.
- **Narration:** AO chapter audio includes playback controls, speed selection, a sleep
  timer and bounded media downloads. Verse highlighting/following uses validated timing
  when available. Availability depends on the edition and recording.

### Notes: four ways to capture a thought

| Note type | Best suited to |
| :--- | :--- |
| **Canvas** | Freely arranging text, ink, images, quotations, tables, shapes and link cards on an expandable workspace. |
| **Page** | Longer flowing writing with formatting, inline attachments, citations and a Pencil overlay. |
| **Prayer** | Keeping a prayer, dated updates, prayer counts and Praying & waiting / Answered / Redirected states. |
| **Journal** | Personal or spiritual reflection with journal type and emotional/mental state fields. |

Canvas objects can be selected, moved, resized, stacked and explicitly grouped. Ink
supports stroke selection/editing, undo and shared Pencil shape refinement. Page-style
writing supports text formatting and media input, with image import, camera/document
capture and audio attachments where supported by the editor.

Show Scripture beside the note, insert an authorized quotation, use plain/ruled/grid
backgrounds, and organize the library with tags, search, sorting and card/list views.
Duplicate a note to develop an independent version. Page status and Prayer status marks
help distinguish work in progress from finished writing or answered prayer.

### Collections: build a personal study library

Collections are nested topic folders containing shared study material. **No Folder**
keeps unfiled items accessible. Folders support colors, List/Card layouts, Smart Order,
manual arrangement, drag/reparent and a full-tree move chooser.

- File an item into several collections while retaining its original identity.
- Save a **bookmark** to revisit a passage, or a **gleaning** to retain a passage with
  a short insight. Turn a bookmark into a gleaning and a gleaning into a new note.
- Keep web links alongside notes, conversations and references to Scripture annotations;
  edit saved link titles/URLs and drag directly listed material into a subfolder.
- Create **Points to Ponder**: reflection questions that can open an exploration in
  Companion or become the starting title of a new note.
- Duplicate a folder tree with its memberships. Folder copies reuse the existing study
  items; standalone note duplication creates an independent note.

Local SP-049 work adds **Plans** under Add Items: named Day/Section groups of
Scripture assignments, notes and links, with checkboxes, editing, reset, duplication and
archive/Trash. Assignment entry has separate Scripture, Notes and Links tabs. Opening a Plan shows its contents, with an explicit Edit action. Start/Resume reads
assignments in the existing Scripture reader and Next saves progress, pausing at section
summaries. The fullscreen reader uses full book names, dims unassigned verses and previews
notes in the existing editor. Its icon bar restores Previous, Add Note, Add Link, Background
Music and Next; new reflections are checked automatically. Plan-named Pencil layers and
complete reader/Companion integration remain SP-050/051 acceptance scope. See the
[Plan ticket](tickets/SP-049-plan-model-and-authoring.md) for current verification limits.

Shared swipe actions and long-press menus expose record commands. Archive, Trash and
restoration flows help manage material over time, with behavior appropriate to each type.

### Companion: ask, investigate and review

Companion is an online Bible-study conversation workspace using **bring your own key
(BYOK)**. Configure a supported provider/model, choose an editable prompt preset and ask
your own question. Conversations retain local history, drafts, passage attachments and
provider/preset identity; follow-up requests include bounded conversation context.

Built-in study presets include **Biblical Studies, Christian Living, Apologetics and
Tough Questions**. Ask opens a blank composer with passage context attached. Original
Language Analysis starts a structured word study or phrase analysis for the selected
wording, addressing Hebrew, Aramaic or Koine Greek as appropriate.

Source inspection distinguishes attached context, local reference links and
provider-dependent retrieval. Markdown responses, streaming, retry/failure states and
Scripture-panel/full-tab continuity support longer study conversations.

**Quiz Me** offers Bible Quiz and Bible or False with difficulty choices, feedback,
explanations, scores and saved history. Prepared questions allow local starts when the
required pool is ready; preparing fresh questions needs the configured online provider.
Optional **Exam mode** draws from the prepared bank with 25, 50 or 100 questions and an
optional time limit. Completed quiz/exam active time contributes to Studying in Activity.

Registered adapters cover OpenAI, Anthropic, Gemini, OpenRouter, GitHub Models, NVIDIA,
Cerebras, Groq, Mistral, Hugging Face and separate Qwen China/International routes.
Model availability, retrieval support, account quotas and charges vary by provider.
AI-generated answers, language claims, citations and quiz keys still require checking.

### Sophy / Lady Wisdom: optional assistance across the workspace

Enable **Lady Wisdom** in Settings to reveal Sophy, the illustrated companion. Sophy
shares the configured BYOK route and can help with supported study organization,
Activity/reminder tasks, navigation and selected typed-text enhancement.

Requests that save study changes produce an editable action preview for review. Supported
actions run through the app's existing feature commands, with validation and access
checks. Dedicated enhancement and History screens let you review proposed wording and
past action summaries. Sophy is optional and stays hidden until enabled.

### Activity, music and study beyond the current screen

Start, pause, resume and finish a study timer, or add/correct a manual record. Built-in
modes include Reading, Studying, Contemplating, Journaling and Memorizing Verses, with
custom modes, per-mode goals, reminders, streaks and local charts. Reading workflows can
record a continuous start-to-end passage range; the guided meditation journey presents
passages for contemplation. Analytics can be exported as PNG.

Background music offers a library, imported tracks and playback controls shared across
tabs. Narration and music coordinate playback so choosing one pauses the other. Music
also exposes system Now Playing controls. Activity has a Live Activity extension, and an
optional Picture in Picture study player presents music/Activity information outside the
main view. System placement and background behavior depend on iPadOS and device state.

## Local storage, privacy and data safety

Bundled Scripture, notes, ink, collections and recorded study history live on the device.
AI requests, translation downloads, online narration and explicit link previews use the
network. Downloaded Scripture/audio follows its source policy; provider/model preparation
is not an offline AI service.

- **Credentials:** provider secrets use device Keychain and are excluded from study exports.
- **Explicit context:** AI requests use the selected workflow's disclosed, authorized
  context. Saved conversation history can be longer than what a request transmits.
- **Access locks:** protect individual Notes and Collections with biometrics or the
  Sophia password, with independent category access. These are app access controls;
  they do **not** encrypt note content or exported backups.
- **Recovery and exports:** feature-owned stores retain checked generations/recovery
  data. Files supports Notes/annotation/Activity archives and a combined study backup
  containing Notes, annotations, Activity, Collections, Companion and optional Sophy History.
- **Backup boundaries:** combined study exports exclude provider keys, licensed Scripture
  payloads, user music files and Sophy's execution journal. Protected-record restoration
  requires the original device credential; backups are not a complete device clone.

See the [data contracts](docs/README.md) and
[access-protection guide](docs/security/item-protection.md) for precise limits. Keep
private backups safe and upgrade in place: uninstalling can remove local study data.

## Technology and architecture

Sophia is a native **Swift** application targeting **iPadOS 17+**, built with Xcode.
It uses Apple frameworks for rendering, handwriting, persistence, media and system
integration. There is no runtime web service to deploy.

| Technology | Role in Sophia |
| :--- | :--- |
| **SwiftUI** | Six-tab interface, feature screens, appearance and adaptive presentation. |
| **UIKit + TextKit** | Continuous Scripture rendering, text selection and native editor/viewport integration. |
| **PencilKit** | Scripture layers, note handwriting, native tools and stroke editing. |
| **Swift concurrency + URLSession** | Async provider requests, streaming, downloads and serialized storage work. |
| **SQLite + SwiftData** | Immutable bundled Scripture and local reader state/preferences respectively. |
| **Codable file stores** | Feature-owned study snapshots, validated generations, integrity checks and recovery. |
| **Core Data + CryptoKit** | Encrypted API.Bible content payloads and cryptographic integrity/encryption operations. |
| **Keychain + LocalAuthentication** | Device credentials, provider keys and biometric access checks. |
| **Vision + VisionKit + PhotosUI** | Text/document scanning and image capture/import for Notes. |
| **AVFoundation + AVKit + MediaPlayer** | Narration/music playback, Picture in Picture and system Now Playing controls. |
| **ActivityKit + WidgetKit + UserNotifications** | Activity system projection, Live Activity extension and local reminders. |
| **XCTest + XCUITest** | Domain, persistence, provider-contract and UI verification. |
| **Python + GitHub Actions** | Local Scripture ingestion/validation and hosted simulator verification/source releases. |

Code is organized around feature ownership:

- **Features** owns screens, editing interactions and sessions/stores that coordinate commands.
- **Core** owns feature values, rules, identities and repository/provider contracts.
- **Infrastructure** implements storage, recovery, Keychain, content sources and AI adapters.
- **RootTabView/AppShell** composes shared sessions, navigation, lifecycle and cross-tab controls.
- **DesignSystem/Resources** supplies appearance, fonts, approved content and prompt seeds.

Study data is kept separate from replaceable or restricted Scripture content. Verse
references connect study artifacts; spatial ink additionally depends on edition and layout.
The [technical design](docs/tdd/tdd.md) and
[source structure guide](docs/project-structure/project-structure.md) explain the boundaries.

## Getting started

You need a Mac with full Xcode and a suitable iPadOS SDK. Use an installed iPad simulator
for development, or a trusted physical iPad for personal use. Apple Pencil and physical
hardware are needed to assess handwriting and device-specific system behavior.

1. Clone this repository and open
   `application/SophiaScriptura/SophiaScriptura.xcodeproj`.
2. Select the **SophiaScriptura** scheme and an iPad simulator, then build and run.
3. For a physical iPad, configure your **Personal Team**, pair/trust the device and enable
   Developer Mode as described in the [deployment guide](docs/deployment/deployment.md).
4. Start with bundled WEB offline. Adjust appearance in Settings, then optionally configure
   translation access, an AI provider/key, music and Lady Wisdom.
5. Create a note or collection and try the connected study session described above.

After initial device/signing setup, the personal installer can build, verify, install in
place and launch the current checkout:

```bash
./scripts/install-ipad.sh
```

The installer defaults to the owner's paired iPad; use `--device` for another configured
device. Free Personal Team signing generally requires weekly redeployment. Releases
provide source rather than an installable IPA. Full commands and signing recovery are in
the [deployment guide](docs/deployment/deployment.md).

## Project status and verification

The current release is **[v1.6.1](docs/releases/v1.6.1.md), build 31**, dated
**2026-10-31**. Prayer has balanced compact margins in portrait/landscape and gray dashed
annotation boundaries when maximized. Every note kind exposes its metadata/color editor
in More from Notes or Collections, including Edit Canvas. Plans support one-Day playback, direct Day selection, automatic Activity
timing with History only on completion, retained paused time between Days, New Conversation,
and optional strict schedules with explicit Catch up. Folder names follow full Plan titles;
saving a new Plan closes Add Items. Dates appear once below each Day. Prayer Clear lives
inside More actions with its existing confirmation. Plans still edit inline with autosave,
managed Plan/Day folders, paired recoverable Trash and shared Scripture editing. Complete
reader lifecycle and Plan Pencil layers remain SP-050/051 acceptance scope; physical and
live-provider acceptance remain separate. See the release notes and tickets for evidence.

The project has executable unit/integration and UI tests, signed iPad installation evidence
and owner-device walkthroughs. Passing simulator tests or installation does not close all
physical Pencil, accessibility, provider-quality or suspension checks. Recorded results
and remaining gaps live in the [test specification](docs/testing/test-specification.md)
and feature tickets. The workflow badge reports main's hosted workflow state.

GitHub Actions builds and unit-tests simulator source, then publishes a source release
when its version has release notes and no existing tag. Physical signing and deployment
remain local.

**Planned separately:** the MCP bridge, selected-handwriting transcription and handwriting
Sophy enhancement remain draft SP-041–043 work. ESV-specific text/audio remains draft
SP-032 scope. They are not included in the feature showcase above.

## Project guide

```text
application/   SwiftUI iPad app, domain rules, adapters, widget extension and native tests
service/       Local Python Scripture import/validation tools
shared/        Book-code and prompt-preset seed assets
docs/          Product intent, design, contracts, testing, deployment and releases
tickets/       Scoped work, acceptance criteria and recorded evidence
scripts/       Personal iPad installation and supporting maintenance tools
.agents/       Canonical reusable AI roles and development workflows
```

| Read next | What it explains |
| :--- | :--- |
| [Documentation index](docs/README.md) | Entry point to the project wiki and maintained contracts. |
| [Product specification](docs/product-specification/product-specification.md) | Product goals, requirements and the theological brief. |
| [Technical design](docs/tdd/tdd.md) | Architecture, implementation checkpoints and technical intent. |
| [Source structure](docs/project-structure/project-structure.md) | Where responsibilities live in the current codebase. |
| [Roadmap](docs/development-plan/development-plan.md) and [tickets](tickets/README.md) | Implemented work, planned scope and outstanding acceptance. |
| [Testing](docs/testing/test-specification.md) and [deployment](docs/deployment/deployment.md) | Verification evidence, commands, signing and device delivery. |
| [Release history](docs/releases/README.md) | Versioned changes and known limitations. |
| [Backward compatibility](docs/guidelines/backward-compatibility.md) | Persistence and upgrade expectations. |

Development is owner-directed: choose a ticket, define the outcome, implement within its
scope and record the evidence. Follow the [development guidelines](docs/guidelines/ai-structure-guidelines.md)
when contributing changes. Keep credentials and private study data out of Git.

---

<p align="center"><em>Read with attention. Study with humility. Return with purpose.</em></p>

Created by Christian Paje. Licensed under [GPL-3.0-or-later](LICENSE).
Scripture, fonts, music and other third-party assets retain their own notices and
permissions; the app license does not override those rights.
