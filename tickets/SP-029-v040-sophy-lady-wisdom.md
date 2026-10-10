# SP-029 — v0.4.0 Sophy, Lady Wisdom and Hugging Face

Status: in progress. Incoming implementation reviewed and corrected on 2026-10-10, including chat, History, enhancement, privacy, durable actions and backup. Focused verification and remaining release gates are recorded below; live-provider and physical acceptance remain open.
Type: feature release. Target: v0.4.0. Milestone: post-baseline cross-feature follow-up.
Owners: Frontend UI/UX, backend/integration and persistence, Security, SQA, documentation;
System Architect owns command boundaries. Role ownership does not require delegation.
Requirements: REQ-008, REQ-010, REQ-011, REQ-013, REQ-015, REQ-019, REQ-025 plus
the owner-confirmed Sophy requirements below.
Dependencies: existing SP-013/015/016/018–023 and SP-026–028 implementations.
Existing physical acceptance gaps remain independent; do not mark them closed here.

**Required execution companion:** [Sophy implementation guide](../docs/design/sophy-implementation-guide.md).
Read it before execution. It defines provider routing, structured responses, action
validation, state transitions, durable commands, crash reconciliation, retrieval limits,
text-edit safety, handoffs, character delivery and package-specific test gates. Proposed
interfaces are requirements to implement, not APIs already present in source.

## Execution checklist — resume here

Follow the guide's P0–P8 gates, then update this list with source changes, test
counts/commands, evidence paths and remaining criteria.
Do not mark a package complete merely because its UI renders.

| Package | Status | Evidence / unresolved gates |
| --- | --- | --- |
| P0 Source and baseline reconnaissance | Done | Incoming implementation and acceptance guide audited; baseline 297 unit tests passed in `build/sp029-review/baseline.xcresult`. |
| P1 Shared routing and Hugging Face | Source implemented; live acceptance open | Existing adapter work retained. Explicit deleted bindings now fail closed. Provider/routing unit coverage runs with the full unit suite; no live keys used. |
| P2 Typed response contracts/state machine | Corrected | Complete action schemas/catalogs/guardrails, safe repair, actual task cancellation and generation/route/access invalidation. Focused regression evidence below. |
| P3 Durable actions and reconciliation | Corrected; exhaustive failure gates open | Whole-plan preflight, shared plan receipt IDs, persist-result handling, recovery preservation and guarded store mutation. No automatic replay; partial/uncertain work requires inspection and a fresh request. Exhaustive crash/interleaving fixtures remain open. |
| P4 Retrieval, insights, History and backup | Corrected | Explicit reviewed-source transmission, protected/mixed ancestry filtering, separate History list/detail, safe summaries, optional full-backup wiring and validation. Round-trip/legacy/invalid-history tests added. |
| P5 Panel, slash commands, previews and handoffs | Corrected; owner UI acceptance open | Adaptive large-detent chat sheet, separate messages and stable composer, commands, source cards, editable hierarchy/descriptions/dates/modes and reuse decisions; typed setup handoffs preserve drafts and active work. |
| P6 Notes enhancement | Corrected; device acceptance open | Native Page/Canvas menu, actual ranges, original/suggestion review, all operations/tones/rating, per-request protected consent and revision/route/access checks; partial Canvas replacement/Undo and protected relock regressions added. |
| P7 Character assets and animation | Existing assets retained; partial | Seven 72×96 pt illustrations retained. Accessible move/reset and Reduce Motion handling exist. Asset provenance, original-resolution requirement, richer motion, full collision handling and physical visual/Pencil acceptance remain open. |
| P8 Integration and release preparation | In progress | Focused unit/UI evidence below. Full-scheme UI regression, live provider, physical acceptance, release notes/version/tag/publication remain open. |

**Review record:** [SP-029 implementation review and owner walkthrough](../docs/testing/sp029-sophy-review.md).
It records confirmed incoming defects, corrections, source locations and remaining acceptance gaps.

## Purpose and execution boundary

Deliver Sophy as a distinct, quiet, illustrated human companion with conversational
agency, its own action History, natural-language/slash commands and Notes enhancement.
Add Hugging Face BYOK support shared by Sophy, Companion chat and Quiz Me.
Existing chat and quiz remain separate experiences.

The original request created this ticket without authorizing implementation. The owner
subsequently implemented Sophy in Cursor and explicitly selected an implementation audit
and code corrections, highlighting the poor chat interface. This review stays within SP-029;
release publication and deployment are not selected. For a future initial implementation, a later
“Execute SP-029” selects all work packages below, including integration, focused fixes,
tests and documentation. Announce the ticket, visible outcome, exclusions, affected
modules and checks before implementation. Execute packages in order, keeping progress
and evidence here; return to the owner before expanding scope. Do not publish, merge,
tag, deploy or claim physical acceptance merely because implementation is selected.

## Confirmed product contract

### Presence, routing and history

- Settings label: **Turn on Lady Wisdom**, off by default. Enabling shows a movable,
  edge-docking Sophy character across tabs. Tapping opens a conversation panel with
  its own History page. Disabling hides the character and closes her panel, without
  deleting history or disabling explicit Notes enhancement.
- Sophy speaks/acts only in response to requests. No unsolicited suggestions,
  background AI execution, voice or autonomous scheduling.
- Use a modest illustrated storybook woman, warm paper/muted gold/sage, with consistent
  transparent poses: idle, greeting, listening, thinking, presenting, success and error.
  Subtle animations respect Reduce Motion and pause when hidden/backgrounded. Keep
  controls clear of the keyboard, tab dock, ink input and existing floating controls.
  The visual deliverable is an in-app human companion, not a ChatGPT pet integration.
- Reuse saved provider credentials and the shared Companion provider/model choice.
  Show current routing in the panel. Add a shared default route if current selection
  is only implicit; do not rewrite routing of existing conversations or quiz sessions.
- Conversational context is memory-only until New Session or termination. History
  stores action summaries only: timestamp, action type, status and eligible result IDs.
  No prompts, replies, generated enhancements, note excerpts or sensitive error payloads.
  Render safe labels and recheck result access on display/open. Include individual
  deletion and explicit Clear History confirmation; lookup/insight/enhancement summaries
  may identify the operation but must not persist its input or answer.
- Saved changes require one editable preview and approval per plan. Clear playback
  requests execute immediately. Quiz, Contemplation and chat requests open configured
  setup/draft screens; their existing Start/Send action remains the owner's action.

### Commands

Natural language and these discoverable slash commands use the same handlers:
`/folders`, `/enhance`, `/reminder`, `/activity`, `/music`, `/quiz`, `/contemplate`,
`/find`, `/insights`, `/chat`, `/help`. Incomplete commands open relevant prompts;
unknown commands show help without changing data. Multiple requested saved changes
must be visible in the approved preview; never execute hidden follow-on actions.

| Capability | Required behavior |
| --- | --- |
| Folders | Editable nested tree with names, descriptions and destination. Bible → Old Testament/New Testament → books uses the existing bundled book catalog/order. Description default: “This folder is notes about the {book}.” Existing matching destinations require explicit reuse/create selection. No overwrite, implicit move or deletion. |
| Reminders | Resolve title/date/time and existing supported recurrence; clarify missing/ambiguous details. Use current device timezone and show exact dates/timezone in preview. Report saved state separately from notification scheduling/permission state. |
| Activity records | Create manual records using existing validation. Clarify title, mode, date, duration or start/end times. Do not invent missing duration or alter an active timer. |
| Music | Play/pause/select existing available tracks. Clarify ambiguous selections; explain unavailable files/empty catalog. No downloads or new track rights. |
| Quiz/Contemplation | Fill understood existing setup options, clarify essential missing values, open existing workflow for Start. Preserve normal Activity linkage and current passage/content permissions. |
| Chat | Accept an explicit existing preset or propose one based on intent. Show preset and editable prompt; open a new Companion draft without sending. |
| Lookup | Retrieve eligible active Notes/Collections with tappable source references. Explain no eligible match without suggesting protected content exists. No OCR/handwriting recognition. |
| Insights | Daily/weekly/monthly/annual local metrics using existing Activity period/goal/streak semantics. Send only necessary aggregates for narrative insights/habit tips. Label current incomplete periods and handle no data without invented activity. |

### Enhance with Sophy

- Add to native typed-text selection in Page bodies and Canvas text objects, preserving
  Copy/Cut and existing editing actions. `/enhance` opens a text-input flow if no eligible
  selection exists; it does not silently read the open note.
- Modal shows selected text above choices with a gentle scale transition: Grammar Check,
  Recreate Text Tone, Organize Idea, Expound, Rate.
- Tone choices: Casual/Personal, Professional/Formal, Creative/Poetic, Academic,
  Devotional. Tone recreation includes grammar correction. Rate offers Grammar, Idea,
  Both, with explained scores out of ten; feedback is advisory, not factual authority.
- Show original/result and Replace/Copy. Rating never replaces text. Replacement is one
  undoable edit, preserving unaffected formatting. Apply existing text formatting rules
  within the replaced span; do not copy model-generated rich formatting automatically.
- Capture note/object identity, selected UTF-16 range, text and revision. If target text
  or access changes during generation, reject Replace and offer reselection; never apply
  an old range to changed content. Cancellation leaves text unchanged.

### Privacy and guardrails

- General lookup excludes protected Notes/Collections even while unlocked, including
  content behind protected Collection ancestors. Filter before assembling prompts,
  metadata lists and source references. Do not treat unlocked as unprotected.
- Exception selected by owner: an unlocked protected Note may send explicitly selected
  text for enhancement only after per-request consent naming the provider. Send no
  surrounding text, title, membership or other note context. This is not general retrieval.
- Recheck access throughout async work and before disclosure/application. Relock clears
  sensitive selection/result UI and cancels affected requests. Ignore late callbacks.
- Treat retrieved content and model output as untrusted data, never execution authority.
  Retain theological guardrails; Sophy personifies wisdom without claiming divine identity,
  revelation or authority. Do not invent citations or claim unperformed searches.
- No arbitrary scripting, web browsing, destructive agent commands, lock changes,
  protected search, external messaging or background autonomy.

## Source grounding and ownership

Read exact current source before changes; these are discovery anchors, not frozen APIs:

- `RootTabView.swift`: shared Notes, Collections, Companion, Activity, Music and meditation
  construction/navigation. Keep root as composition, not the agent executor.
- `Core/Companion/LLMProviderAdapter.swift`: text streaming request/events and capability
  boundary; `Infrastructure/Companion/ProviderRegistry.swift`,
  `OpenAICompatibleProviderAdapter.swift`, `ProviderModelCatalog.swift`: provider wiring.
- `Features/Companion/CompanionSession.swift`: credentials, presets, conversation/quiz
  routing. Reuse provider access without putting Sophy history into Companion messages.
- `Features/Collections/CollectionsStore.swift`: guarded hierarchy creation and persistence;
  its current single-folder create queues a write, so batch trees need an explicit command.
- `Features/Notes/Editor/NoteCanvasSurface.swift`: UIKit Page/Canvas text views and selection;
  `Features/Notes/NotesSession.swift`: edits, undo, persistence and access guards.
- `Features/Activity/ActivityStore.swift`: manual records/reminders; existing analytics
  implement metric semantics. `MeditationJourneyCoordinator.swift` owns the guided journey.
- `Features/Music/MusicSession.swift`: existing music commands and playable catalog.
- `Features/Protection/ItemProtectionSession.swift` and
  `Infrastructure/Backup/StudyBackupService.swift`: access lifecycle and full backup.

Design/contract prerequisites: [TDD](../docs/tdd/tdd.md),
[Companion design](../docs/design/companion-screen-specification.md),
[Notes design](../docs/design/notes-screen-specification.md),
[Collections design](../docs/design/collections-screen-specification.md),
[Activity design](../docs/design/activity-screen-specification.md),
[shell design](../docs/design/app-shell-specification.md),
[Companion data](../docs/data/companion-contract.md),
[Notes data](../docs/data/notes-contract.md),
[protection](../docs/security/item-protection.md),
[compatibility](../docs/guidelines/backward-compatibility.md),
[native verification](../docs/testing/test-specification.md).

## Ordered implementation work packages

### A. Provider and shared routing

Detailed package: guide P1 and §4. Preserve explicit quiz defaults; only absent quiz
defaults inherit the shared route.

Register Hugging Face, use existing Keychain handling and provider settings, and add
inference-enabled model selection/manual model entry under existing catalog conventions.
Use `https://router.huggingface.co/v1/chat/completions` with Bearer token; verify current
official [chat API](https://huggingface.co/docs/inference-providers/en/tasks/chat-completion)
before implementation. Token needs Inference Providers permission. Support streaming,
cancellation, selected-model connection testing and actionable auth/quota/model errors.
A public model-list success alone is not proof that a token/model can infer. Do not label
all Hugging Face models free. Reuse compatible transport where its behavior fits.

### B. Sophy orchestration and approved actions

Detailed packages: guide P2/P3 and §§3, 5–8. Strict JSON validation, persist-before-publish
commands and the non-replayable journal are mandatory.

Introduce proposed `Core/Sophy`, `Infrastructure/Sophy`, `Features/Sophy` modules with
typed intents, clarification requests, action plans, receipts and safe history entries.
Keep provider completion, planning, execution, persistence and UI distinct. Use an
allowlisted executor calling guarded feature commands. Strictly decode/validate a
provider-neutral structured plan; native tool calling is optional, not required for
existing providers. Invalid or truncated plans produce no mutations and allow retry.

Plans carry stable IDs and explicit approval state. Recheck target/access/revision at
commit. Reject duplicate submission. A validated folder tree commits as one collection
snapshot/write. Surface durable write failures rather than declaring success on an
in-memory update. For mixed-feature plans, execute approved steps in order and report
per-step results; stop at failure, retain completed receipts, retry only unapplied steps.
Never roll back unrelated owner edits. Persist execution receipts without sensitive
inputs so restart cannot replay a confirmed request automatically; uncertain outcomes
must be reconciled against result IDs before a retry, not blindly executed again.

### C. Retrieval, insights and safe local History

Detailed package: guide P4 and §§9, 12. Follow fail-closed mixed-membership filtering,
context limits and the additive optional full-backup field.

Implement shared eligibility filtering and bounded context construction using existing
protection/membership rules plus Sophy's stricter policy. Calculate insight metrics
locally, then generate prose from aggregates. Add separate validated atomic history
storage/recovery, backup/restore support and all-data deletion. Never persist transient
conversations, pending approvals or sensitive enhancement buffers. Existing schemas,
credentials and study data must survive upgrade without reset. Restore history without
executing actions and invalidate pending requests on restore.

### D. Character, panel, command picker and handoffs

Detailed packages: guide P5/P7 and §§11, 13. A development placeholder cannot satisfy
the final character asset gate.

Create original character assets during implementation with the image generation skill;
use local assets and native animation, no runtime asset generation. Review visual
consistency and record provenance. Implement panel, editable previews, clarification,
history, settings and accessible controls. Persist safe edge position, constrain it to
the visible viewport on rotation/resizing, and provide an accessible open/reset path.
Wire existing setup/draft screens with typed launch values rather than duplicating their
workflows. Add focused coordinator code rather than growing root responsibilities.

### E. Notes enhancement

Detailed package: guide P6 and §10. Protected Collection ancestry also requires selected-
text consent; no general protected retrieval is permitted.

Implement native edit-menu integration, selection snapshots, explicit protected-selection
consent, generation/review UI and a guarded undoable replacement command. Cover both
Page and Canvas text views. Handle keyboard, Scribble, theme, Reduce Motion and dismissal.
No migration of note text or conversion of handwriting is required.

### F. Integration, documentation and release preparation

Detailed package: guide P8 and §§14–15. Source completion, release acceptance and
publication are separate; preserve explicit Not Run device/live-provider criteria.

Update product/TDD, affected screen specifications, provider/data/privacy/backup contracts,
structure map and AGENTS repository map when modules exist. Add manual cases and a
v0.4.0 release page with real evidence and remaining gaps; update version metadata only
after release scope passes verification. Follow current deployment/release guidance for
later owner-selected publishing; preserve local data and existing release refs.

## Acceptance and verification gates

All items below start **Not Run**. Record commands, results, result-bundle paths and
device/provider identity without secrets. Use ignored `build/sp029/` for evidence.

- [ ] A: Hugging Face request/auth/stream/cancel tests; invalid token, unsupported model,
  rate limit, malformed response and missing credential cases. Existing providers regress
  cleanly; routing changes do not retarget stored conversations/quizzes.
- [ ] B: malformed/unknown/injected actions cannot execute; preview cancellation makes no
  changes; repeated taps/retries/restart cannot duplicate actions; partial failure and
  durable write failure accurately report completed/failed/uncertain results.
- [ ] B: Bible tree preview and saved result contain correct catalog books, parent edges
  and descriptions. Reuse/create ambiguity, stale destinations, protected ancestry and
  reserved names are validated; tree failure leaves no partial tree.
- [ ] B/D: reminder and Activity follow-ups resolve missing fields and ambiguous dates;
  invalid durations/time ranges fail; notification denial distinguishes save/scheduling.
  Existing active Activity and reminder recurrence rules remain intact.
- [ ] C: protected records remain excluded while locked AND unlocked, through nested and
  mixed memberships; provider prompts, source labels, history and logs reveal no excluded
  content. Privacy rechecks survive concurrent protection/membership changes.
- [ ] C: period metrics match existing analytics across midnight/week/month/year/timezone
  boundaries; empty/incomplete periods are explicit and no activity is invented.
- [ ] C: history recovery, upgrade, backup round-trip, all-data deletion, clear/delete and
  restore do not replay actions or retain prompts/results/credentials. Legacy backups load.
- [ ] D: music uses actual playable tracks; quiz/Contemplation/chat handoffs configure
  correct screens without auto Start/Send or duplicate Activity linkage.
- [ ] D: character toggle, dragging/docking, narrow window/rotation, keyboard, floating
  controls, light/dark, VoiceOver and Reduce Motion work without intercepting Pencil input.
- [ ] E: each operation/tone/rating choice works; UTF-16/emoji/multiline selections, changed
  targets, unaffected formatting, Copy, cancel and one-step Undo are correct in both editors.
- [ ] E: protected selection requires fresh consent; outgoing context includes only that
  selection; relock/access expiry/background cancellation prevents stale result disclosure.
- [ ] Integration: focused unit/UI suites pass, then current native regression checks from
  the test specification. Separate known baseline failures from new regressions with evidence.
- [ ] Live provider: owner-controlled credentials verify Hugging Face chat, quiz and Sophy
  planning/enhancement; inspect response quality separately from structural validation.
- [ ] Physical iPad: owner verifies selection/Pencil/Scribble, character layout/motion,
  privacy expiry, notifications, playback and real-provider workflows. Simulator success
  does not close these criteria or outstanding SP-025–028 device criteria.

Stop and resolve any data loss, protected-content disclosure, duplicate execution,
unauthorized action or recovery regression before further release preparation. If a
requested behavior needs unsupported recurrence, unavailable licensed passage content or
new destructive/migration behavior, report the concrete boundary rather than inventing it.

## Evidence and completion

2026-10-10: approved plan converted into this ticket; documentation only. No product
implementation, native tests, generated character assets, real-provider calls, physical
acceptance or release publication performed. Documentation verification is recorded by
the ticket-creation response. Completion requires package evidence, acceptance disposition,
documentation alignment and an explicit account of remaining owner-device gates.

2026-10-10 execution-guide expansion: exact-source inspection exposed implicit provider
selection, queued in-memory save APIs and view-local setup state. The normative guide
now specifies proposed replacements, response/action contracts, crash reconciliation,
privacy limits, typed handoffs, character requirements and P0–P8 test gates. No app code
changed; all implementation packages and runtime acceptance remain Not Started/Not Run.

Documentation verification: relative links, Markdown fences, whitespace, JSON examples,
13 existing source anchors and P0–P8 coverage passed; `git diff --check` passed. Native
tests were not run because this change only adds/updates planning documentation.

2026-10-10 implementation slice: shared provider route, Hugging Face adapter, response
validator, execution-state rules, folder/activity durable commands, eligibility search,
and Sophy history/journal storage are in source. Simulator: iPad (A16)
`523DDB8A-9EF6-44ED-A4F8-F8059ECB7725`. Evidence: `build/sp029/p2-contracts-r5.xcresult`
(25 passed) and `build/sp029/p3-execution-r2.xcresult` (7 passed).

2026-10-10 remaining slice: Sophy session, action journal, panel, slash commands,
editable preview, History, quiz/contemplation/chat handoffs, Notes replacement and seven
character poses. `SophyProductTests` 4 and `SophyCommandTests` 3 passed in
`build/sp029/p5-product-r2.xcresult` on the same iPad (A16) simulator. No live provider
call, full-scheme regression, signed device install or release publication.


### 2026-10-10 owner-requested audit and correction

Mode A (existing-ticket execution): reviewed exact incoming source against this ticket and
the guide, then corrected SP-029 defects. The owner specifically identified the overall
poor chat interface. Changes and remaining acceptance boundaries are detailed in the
[review report](../docs/testing/sp029-sophy-review.md).

Verified so far:

- Incoming baseline: `build/sp029-review/baseline.xcresult`, 297 unit tests passed.
- Full corrected unit suite: `build/sp029-review/fixes-r8-unit.xcresult`, 320 passed,
  zero failed/skipped. Includes 23 new acceptance regressions.
- Final focused Sophy regressions after the last input/restore guard changes:
  `build/sp029-review/final-sophy-unit.xcresult`, 23 passed, zero failures.
- Existing Collections material-to-Notes and Notes text/metadata/relaunch UI checks passed
  in `build/sp029-review/fixes-r6.xcresult`. That mixed run is not an all-pass bundle:
  its then-new Unicode/backup-fixture assertions and enhancement-selector assertion failed
  and were corrected before the passing unit evidence above.
- Mixed `fixes-r7.xcresult`: 319 units and portrait/landscape chat/History passed; Activity
  relaunch terminated and enhancement's subsequent launch/navigation failed. Do not use
  this bundle to claim UI acceptance. Final UI-only rerun is recorded below.
- Local Markdown links: 99 checked, zero missing; `git diff --check` passed.

Implementation refinements: the chat uses an adaptive sheet across window sizes, opening
at the large detent after simulator review showed the medium sheet too short. Existing
illustrations were retained. Existing chat drafts are preserved rather than overwritten;
the user resolves them before another handoff. A failed/partial plan is inspected in
History and requested afresh; no old transient plan is silently replayed. Rich character
motion/provenance, exhaustive crash/interleaving cases, full-scheme UI regression,
live-provider and physical acceptance remain open. No version bump, release publication,
commit or physical deployment is included in this review.


Final unit regression: `build/sp029-review/final-unit.xcresult`, **322 tests passed**,
zero failures/skips, including **25 new Sophy acceptance regressions**. Final additions
cover exact Canvas list/combining-character replacement with style/Undo preservation and
explicit confirmed History clear recovering a disabled Sophy store while retaining study
items and the enabled preference. No automatic corruption reset is performed.

UI-only `build/sp029-review/final-ui.xcresult`: **3 passed**, zero failures/skips:
Sophy chat/History, enhancement operation/tone/rating controls, and existing Activity
workflow. This supersedes the failed mixed-run UI evidence. Portrait and enhancement
screenshots were visually inspected. The first landscape capture caught rotation in
progress; the final Sophy UI rerun explicitly waits for landscape layout before capture.

Final Sophy-only rerun: `build/sp029-review/final-sophy-ui.xcresult`, **2 passed**,
zero failures/skips. Enhancement controls were visually inspected in the exported
attachments under `build/sp029-review/accepted-screenshots/`. The landscape attachment
still shows clipped content/black space despite orientation assertions passing. This
is unresolved visual evidence, not an accepted landscape layout; reproduce on the
owner's iPad or obtain a stable simulator capture before closing that gate.

Reproduction command (Xcode at `/Applications/Xcode.app`, iPad A16 simulator, iOS 26.5):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project application/SophiaScriptura/SophiaScriptura.xcodeproj \
  -scheme SophiaScriptura \
  -destination 'platform=iOS Simulator,id=523DDB8A-9EF6-44ED-A4F8-F8059ECB7725' \
  -derivedDataPath build/sp029-review/DerivedData \
  -resultBundlePath build/sp029-review/owner-sophy-ui.xcresult \
  -only-testing:SophiaScripturaUITests/SophyUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

For the full unit suite, select `SophiaScripturaTests` instead and use a new result
bundle path. Result bundle paths must not already exist.

## Enabled character visibility regression (2026-10-10)

Owner reported that the enabled companion disappeared on opening the latest build.
The new overlay positioned a screen-wide character container using a 280-point cluster
center, placing the trailing image outside the window. The container now uses the same
280-point maximum width as its positioning calculation. A first simulator check also
exposed swallowed button taps in the custom UIKit passthrough wrapper; SophyChrome
now uses native SwiftUI hit testing. Character and idle-quote additions are retained.

`SophyUITests.testEnabledCharacterRemainsVisibleAfterRelaunch` checks that the enabled
character persists across app termination/relaunch, stays within the window, and opens
chat. Verification results are recorded below when complete. No device installation
or preference reset is performed.

Verification: `build/sp029-review/visibility-fix-r2.xcresult` passed all **3 Sophy UI tests**, including enabled-character persistence, window containment and opening chat after relaunch. Chat/History and enhancement controls also passed. The earlier `visibility-fix.xcresult` failure exposed the swallowed taps and is superseded by this corrected run. `git diff --check` passed. Physical iPad verification remains open.
