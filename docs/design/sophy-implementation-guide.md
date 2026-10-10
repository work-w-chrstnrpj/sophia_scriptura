# SP-029 implementation guide — Sophy v0.4.0

Status: approved-plan elaboration, 2026-10-10; proposed interfaces below are not existing
implementation. Parent: [SP-029](../../tickets/SP-029-v040-sophy-lady-wisdom.md).
This guide is normative for SP-029 execution. It fixes engineering defaults without
authorizing app implementation. Product decisions in the parent remain authoritative.

## 1. Instructions for the implementing agent

1. Read AGENTS.md, context routing, the parent ticket, this guide, and each package's exact
   source before editing. Check Git status; preserve unrelated and owner-authored changes.
2. Execute packages P0–P8 in order. A package is complete only when its required checks
   pass and evidence is recorded. Do not build all screens first and defer command safety.
3. Existing names below are source observations from 2026-10-10. Proposed names are design
   targets. If source moved, find its actual owner; do not duplicate the feature.
4. Use feature-specific files and extensions; do not put planning, storage or provider
   parsing in RootTabView or NoteCanvasSurface. Do not install an agent framework/backend.
5. Inject provider transport, clock/calendar, repositories, and navigation callbacks for
   deterministic tests. Do not use live keys, live personal stores or notifications in tests.
6. Record completed packages, changed files, actual tests and unresolved gates in SP-029.
   On context restart, resume the first incomplete package after inspecting current state.
7. Do not omit failed checks, weaken existing tests, reset study data, silently substitute
   an icon for finished character assets, or declare provider output factually verified.
8. Ask the owner only for material product changes or unavailable external inputs. Routine
   coding choices inside these contracts do not require repeated approval.

## 2. Existing behavior and required integration changes

All application paths in this guide are relative to
`application/SophiaScriptura/SophiaScriptura/` unless a repository-root path is given.

| Existing source / behavior | Required change or preservation |
| --- | --- |
| `Features/Companion/CompanionSession.swift`: `preferredProviderConfiguration()` returns the first record with a key; `createConversation()` uses its default model. Quiz has separate persisted defaults. | Add an explicit shared default route for Sophy/new chat. Preserve explicit quiz defaults and existing conversation/quiz routes. |
| `Core/Companion/LLMProviderAdapter.swift`: completion contains model, system instruction and turns; events stream text. | Build validated Sophy response parsing above this boundary; do not advertise tool capability merely because a model returns JSON text. |
| `Features/Collections/CollectionsStore.swift`: `createCollection` mutates then queues a revision-checked save. | Add awaited, batch, persist-before-publish Sophy tree creation. Never loop over ordinary createCollection and call the tree atomic. |
| `Features/Activity/ActivityStore.swift`: `addManual` returns Void; `upsertReminder` returns in-memory acceptance; `flush` cannot report save failure. | Add awaited create-only commands returning typed durable outcomes; do not infer success from errorMessage being nil. |
| `Infrastructure/Activity/ActivityFileRepository.swift`: checked envelope/current/previous, atomic write, schema 1. | Reuse validation and recovery, preserve existing store/schema. Stable new record IDs avoid a separate metadata migration. |
| `Features/Companion/CompanionView.swift`: Quiz setup is local sheet state; `QuizMeView.swift` initializes local difficulty/types/timed defaults. | Add a one-shot setup request and initial-value initializer; no quiz starts when a request is merely consumed. |
| `Features/Activity/ActivityView.swift`: Start Activity sheet owns mode/title/passage; Start invokes store.start and then the journey callback. | Add a one-shot initial-value request to this sheet. Preserve the existing Start path and guided-workflow setting. |
| `Core/Activity/MeditationJourney.swift`: chosen passages are one chapter, at most two verses. | Validate against actual available verses; explain unsupported ranges instead of silently truncating the owner's request. |
| `Core/Music/MusicModels.swift`: commands include selectTrack/play/pause/next/loop/clear. | Sophy exposes only play/pause/selectTrack in v1. Pass IDs resolved from the existing catalog, never paths or URLs. |
| `Infrastructure/Backup/StudyBackupService.swift`: full envelope schema 1; restores reject other schemas. | Add optional Sophy summary payload while retaining envelope schema 1; absent payload preserves current Sophy history. Imported history never imports executable receipts. |
| `Features/Notes/NotesSession.swift`: guarded edit/history and native flush; `NoteCanvasSurface.swift` owns UIKit selectedRange. | Add a narrow enhancement selection bridge and guarded replacement; preserve the existing session history and text-formatting owner. |

### Required source reconnaissance at P0

Read the complete implementations above and their nearby tests, not only these observations.
Also inspect CompanionSnapshot encode/decode/save, ProviderModelCatalog, provider Settings,
CollectionsSnapshot and revision conflicts, ActivityReminderNotifications and permission
handling, Notes formatting span operations and protected collection membership filters,
Settings all-data deletion/full backup callers, shell scene lifecycle and UI-test isolation.
Record actual test class names and current simulator destination in the ticket. Do not
reuse a historical simulator UUID without confirming it exists.

## 3. Module ownership and proposed interfaces

Use these ownership boundaries; filenames may follow adjacent naming conventions, but
responsibilities must remain separated. Do not create empty placeholder files.

| Proposed owner | Responsibility |
| --- | --- |
| `Core/Sophy/SophyModels.swift` | Codable response types, enums, resolved action plans, receipts, safe errors; no SwiftUI, Keychain, or store references. |
| `Core/Sophy/SophyResponseValidator.swift` | Strict structural validation, limits, valid catalog handles and action argument combinations. |
| `Core/Sophy/SophyExecutionState.swift` | State transition rules and request-generation invalidation. |
| `Infrastructure/Sophy/SophyCompletionService.swift` | Obtain selected route/credential, stream through existing adapter, parse only final validated response; never execute actions. |
| `Infrastructure/Sophy/SophyFileRepository.swift` | Checked summary/receipt storage, recovery and isolated test directory. |
| `Features/Sophy/SophySession.swift` | MainActor UI session, transient conversation, requests, clarification and approval. |
| `Features/Sophy/SophyActionExecutor.swift` | Typed dispatch to awaited feature commands and navigation callbacks; no arbitrary tools. |
| `Features/Sophy/SophyContextBuilder.swift` | Eligibility, bounded search/context and model-visible handle mapping. |
| `Features/Sophy/SophyPanel.swift`, preview/history/character views | Presentation and bindings; never write repositories directly. |
| Existing Notes, Activity, Collections and Companion owners | Validation, mutations, persistence, undo and existing workflows remain here. |

Required boundary shapes (Swift declarations are proposed, not claims they already exist):

```swift
struct SophyRoute: Codable, Equatable, Sendable {
    let providerConfigurationID: UUID
    let modelID: String
}
enum SophyCommitOutcome: Sendable {
    case committed(resultIDs: [UUID])
    case alreadyCommitted(resultIDs: [UUID])
    case rejected(SophySafeError)
    case uncertain(resultIDs: [UUID])
}
```

Completion service accepts a route snapshot, system rules, transient turns and eligible
context, returns text stream/final validated response, supports cancellation. Executor
accepts an app-resolved approved plan, never raw JSON. Feature commit commands accept
app-generated stable IDs and validated values, return durable outcome after awaited save.
Navigation callbacks accept typed setup values and return presented/busy/rejected.
Safe errors use fixed codes/localized messages, never raw provider payloads or study text.

## 4. Shared provider/model contract

- Persist optional `defaultProviderConfigID` and `defaultModelID` in CompanionSnapshot;
  include them in its existing custom Codable paths, apply/save/backup and tests.
- Existing snapshots missing these fields resolve to the first configuration with a key
  and that configuration's default model, matching today's new-chat behavior. No config
  means unconfigured; do not silently choose another provider mid-session.
- Add a Companion Settings “Default provider and model” picker. Sophy displays and follows
  it, with a link to edit Settings. Selecting an existing chat does not change the default.
- New chats and Sophy use the shared default. Quiz retains explicit quiz defaults; when
  absent it inherits the shared default. Existing stored routes remain untouched.
- Capture route per request. If the user changes route or removes its key/config while
  Sophy is working, cancel that request and invalidate any unsaved preview. Explain that
  it must be generated again. Never resend to a replacement provider automatically.
- Do not persist selected text or model output while switching providers. Fetch credentials
  just in time from existing Keychain abstraction; never store them in Sophy state/history.
- Hugging Face adapter ID: `huggingface`; display name: `Hugging Face`.
  Use official router chat completions, existing compatible SSE transport where possible.
  Check current official model listing/auth requirements during P1. Allow manual exact
  model IDs, show routing suffix as part of that ID, and verify inference with the selected
  token/model. Do not hardcode an unverified model or advertise every model as free.
- If model listing fails, preserve selected ID and allow connection testing/manual entry.
  No automatic paid-model fallback. Map auth/permission, unavailable model, rate/quota,
  offline, malformed stream and cancellation to safe user-facing errors.

## 5. Provider-neutral response format

All Sophy intent requests ask for exactly one JSON object, no Markdown fences or prose
outside it. Accumulate streaming content in a bounded buffer; do not execute partial JSON.
Show a neutral Thinking indicator, not partial plan content that could reveal unvalidated
sources. Normal replies are displayed from the validated `message` field.

Envelope version 1:

```json
{
  "version": 1,
  "kind": "clarification",
  "message": "What time should I remind you tomorrow?",
  "questions": [
    {"field": "time", "prompt": "What time?", "choices": []}
  ],
  "actions": [],
  "sourceHandles": []
}
```

- All six root keys are required. Unknown root/argument keys are rejected. Version must
  be 1; kind is `reply`, `clarification` or `plan`. Reject duplicate JSON keys using a
  checked JSON parser/preflight, not a dictionary decode that silently picks one value.
- `message`: plain or existing safe Markdown, at most 8,000 characters. It cannot authorize
  actions. Existing Markdown rendering applies; never render executable HTML.
- `reply`: no questions/actions. `clarification`: 1–3 questions, no actions. `plan`: 1–10
  actions, no questions. Each question has `field`, `prompt`, `choices` (0–6 strings).
  App treats field names as labels for follow-up context, never writable property paths.
- `sourceHandles`: at most 8 app-issued eligible source handles from this request. Reject
  unknown handles. UI resolves handles locally; the model cannot supply URLs or record IDs.
- Raw response limit: 64 KiB UTF-8. Request user input limit: 8,000 characters. Display a
  length explanation before sending oversized input; never silently truncate the request.
- One automatic format-repair request is allowed for syntactically invalid output, using
  the same provider and schema description plus a safe validation code. Do not echo raw
  invalid output or expand retrieved context. A second failure ends with Retry; no mutation.
  No repair request after cancellation, auth failure, permission expiry or offline failure.
- No automatic execution loop. After execution, render app receipts locally. A follow-up
  requires a new user turn; generated messages cannot create invisible next actions.

### Action discriminator and arguments

Each action has exactly `type` and `arguments`. Reject absent/extra fields. Optional
fields below may be omitted; supplied null is accepted only where explicitly nullable.
App maps string enums to existing domain enums, validates IDs via request handles, then
produces a resolved plan with app-generated plan/action/result UUIDs.

| Type | Arguments and validation |
| --- | --- |
| `createFolders` | `destinationHandle` nullable; `nodes` array of `{key,parentKey,name,description}`. key is unique request-local string, parentKey nullable refers to another node. Root nodes use destination. App performs cycle/missing-parent validation. 1–100 nodes, depth ≤8; name trimmed 1–120 chars, description ≤2,000; reserved No Folder rejected. |
| `createReminder` | `title`, optional `description`, `modeHandle`, `localDate` YYYY-MM-DD, `localTime` HH:mm, `repeatRule` one of once/daily/weekdays/weekends/weekly, optional `deleteAfterFiring` bool default false. No model timezone; app attaches captured device timezone. Title 1–200, description ≤2,000. |
| `createActivity` | `title`, optional `description`, `modeHandle`, `localDate`, optional `localStartTime`, optional `localEndDate`, optional `localEndTime`, optional integer `durationMinutes`. Title 1–200, description ≤2,000. Resolve date/time/duration as specified below; no replace/delete argument. |
| `music` | `operation` play/pause/select, optional `trackHandle`. select requires valid track; pause forbids track; play may use one. No volume/loop/file/network access in v1. |
| `openQuiz` | Optional `types` using current QuizType raw values exposed by app, `difficulty` using current enum raw values, `timed` bool. Missing fields use setup defaults and are visible before Start. Reject unknown type IDs. |
| `openContemplation` | Optional `title`; optional `passage` containing book/chapter/startVerse/endVerse in the selected eligible edition. No passage means curated seven-passage setup. Invalid/unsupported range requires clarification, not truncation. |
| `openChat` | `presetHandle`, `prompt` (1–8,000 chars). Handles come from preset catalog. Show editable preset/prompt handoff before creating the normal chat draft. |
| `lookup` | `query` (1–1,000 chars), `scope` notes/collections/both. Performs filtered local retrieval; has no mutation fields. |
| `insights` | `period` day/week/month/year; optional `anchorDate` YYYY-MM-DD; optional `modeHandle`. Default anchor is today. No custom executable aggregation expressions. |
| `enhance` | `operation` grammar/tone/organize/expound/rate; optional `tone` casual/professional/creative/academic/devotional; optional `ratingTarget` grammar/idea/both. tone required only for tone; ratingTarget required only for rate. Selection/text comes from UI, not model arguments. |

Keep lookup/insights/enhance separate from saved mutations in each resolved plan: when a
request mixes them, first gather/answer read-only needs, then present an explicit saved
plan. Do not silently run read actions against future folders or promise dependent data.
Multiple saved actions can share one preview. Navigation/music accompanying saves wait
until saved-step completion; a standalone clear music request can run immediately.

### Examples that must become fixtures

```json
{"version":1,"kind":"plan","message":"Review these folders.","questions":[],"actions":[{"type":"createFolders","arguments":{"destinationHandle":null,"nodes":[{"key":"bible","parentKey":null,"name":"Bible","description":"Bible study notes."},{"key":"old","parentKey":"bible","name":"Old Testament","description":"Old Testament study notes."},{"key":"genesis","parentKey":"old","name":"Genesis","description":"This folder is notes about the Genesis."}]}}],"sourceHandles":[]}
```

This is a small wire-shape fixture, not the complete Bible tree acceptance case. Build
the complete Testament tree deterministically from the app's actual book catalog when
requested; verify expected catalog membership/order in tests, not an LLM list.
Reject action `deleteNote`, extra `script`/`url`/`protectionID` arguments, a nonexistent
destination handle, a cycle, invalid model-enum strings and a forged source handle.
If a model reply says “I created it” without a committed receipt, show it as a proposal
and never display app-owned success styling. Prefer generated proposal wording in prompts.

## 6. Resolution, clarification and previews

- Capture now/calendar/timezone, eligible handles and route at request start. Relative
  language such as tomorrow resolves against that captured time. Preview shows localized
  absolute date/time and timezone. If timezone changes before approval, invalidate date
  plans and require a refreshed preview.
- Ask only missing essentials; retain answers in transient context and combine them with
  the original request. Clarification itself never mutates data. Escape/cancel abandons it.
- Destination default is root; folder accent/icon default to the existing create-folder
  defaults (read them at P0). Show defaults in preview, not hidden in a commit.
- Match existing folder names case-insensitively after trim, under the same parent only.
  Offer Use existing/Create another in preview. Reuse requires eligible unprotected parent;
  duplicate names are permitted only after explicit Create another. Do not rename existing
  folders. Resolve app handles to stable IDs only after confirming selection.
- Reminder mode must be selected; if not requested, ask rather than invent Reading.
  Repetition defaults to once; description defaults empty. Show date/time and repeat rule.
  For nonexistent DST local time ask for another time. For repeated local time ask which
  occurrence and show UTC offset. One-time date must remain future at commit.
- Activity mode/title/date/duration are required. If only date and duration are supplied,
  ask for start time: current addManual creates real intervals and overlap validation;
  do not invent midnight or bypass overlap checks. Explicit start/end can compute duration.
  If start/end/duration conflict, ask which to keep. End time earlier than start without
  an explicit next-day date requires clarification. Existing overlap validation includes
  the active timer; never auto-delete/edit an overlapping record.
- Existing custom modes are usable by exact handle; unknown modes prompt selection from
  existing choices. Creating modes is outside this ticket's Sophy command set.
- Quiz defaults come from existing setup (currently Easy, Identify Verse + Who Said It,
  untimed). Contemplation defaults to curated passages. Missing optional setup values
  need not trigger repeated follow-up; display them in existing setup before Start.
- `/chat` without a preset may recommend an existing preset but must show it. Unsupported
  preset names prompt an existing choice. Do not modify preset definitions automatically.
- Preview UI: per-action editable fields, explicit destinations, validation errors, Cancel,
  and “Confirm N changes”. Disable confirm while invalid/executing. Any edit produces a
  new revision and clears prior approval. Reconfirm after target state changed.
- A source/destination becomes protected, archived, trashed, missing or materially changed
  before commit: reject stale plan. No authentication dialog to bypass the retrieval policy.

## 7. State machine, cancellation and concurrency

MainActor session owns state; provider tasks carry generation/request IDs. Late callbacks
must match active generation, route and access snapshot before UI/state updates.

| State | Allowed next states and events |
| --- | --- |
| idle | interpreting on user Send; enhancing through explicit selection bridge |
| interpreting | clarifying, previewing, answering/read-only, failed, cancelled |
| clarifying | interpreting on user answer; cancelled on Cancel/New Session |
| previewing | committing on valid Confirm; interpreting on revised request; cancelled |
| committing | completed, partiallyCompleted, failed, uncertain; never another simultaneous commit |
| answering/enhancing | completed, failed, cancelled; apply enhanced text only through explicit Replace |
| completed/partiallyCompleted/failed/cancelled/uncertain | idle/new request; retry follows receipt rules below |

- Serialize Sophy requests. Send disabled while interpreting/answering; provide Stop.
  During a saved commit, prohibit another Sophy commit. Do not cancel an in-flight atomic
  file write; finish/reconcile that step, then stop remaining steps if Cancel was requested.
- Backgrounding cancels provider requests and clears protected enhancement buffers; unapproved
  date plans must be revalidated on return. Restore/data deletion invalidates all tasks/plans.
- New Session clears transient turns, selected text, lookup evidence and previews. It cannot
  undo committed records. Turn off Lady Wisdom hides UI and cancels noncommitting requests;
  finish/reconcile an in-flight save before closing its execution status.
- No timer/notification/provider callback counts as genuine protection-category activity.
- Cancellation errors must not become red provider failures or claim a save was rolled back.
- Inject time; never put arbitrary sleeps in tests to make stale callbacks pass.

## 8. Durable execution and crash recovery

### Persist-before-publish feature commands

Add create-only awaited commands in existing stores. Suggested names:
`CollectionsStore.createTreeFromSophy`, `ActivityStore.createManualFromSophy`,
`ActivityStore.createReminderFromSophy`. Each validates stable result IDs, current access,
target state and values; builds a candidate snapshot; awaits its repository save; publishes
the new snapshot only after successful commit. Return a typed outcome to executor.

Drain existing write chains before acquiring the feature commit slot. Protect the awaited
candidate save with a feature-owned mutation gate: existing mutation/restore/delete commands
must reject with a clear busy notice while that candidate is saving; normal browsing is
allowed. Never let a stale candidate overwrite an owner edit made during await. Release
the gate with defer on all outcomes. Collections uses expected revision; conflict requires
reload/re-preview, not overwriting. Activity save must not run alongside an earlier queued
snapshot write. Preserve ordinary UI command semantics outside this narrow gate.

Do not pass a new Activity ID into current `addManual(replacing:)`: that parameter requires
an existing record. Extract/reuse validation in the new create-only command. Reminder
creation similarly must not upsert over an owner reminder with a matching ID.

### Execution journal

Use a separate internal receipt journal, not visible conversation History. Before any
saved mutation, atomically persist `{planID, actionID, actionType, resultIDs, state,
createdAt, updatedAt, safeErrorCode?}`. App generates result UUIDs in advance for every
new folder/record/reminder. Journal contains no titles, descriptions, prompts, text,
date payloads or credentials. It does not contain enough arguments to replay a command.

1. Validate entire plan, allocate IDs, save journal entries in `prepared` state. Journal
   failure means no feature mutation. Existing reused folder IDs are separate read-only
   references and are not mistaken for newly created results.
2. Save `applying` for the next action; then call its awaited feature command. Only the
   app-owned approved transient plan supplies payloads.
3. On durable success save `committed` receipt, then append safe visible summary. If receipt
   or history write fails after feature save, show “Saved; history could not be updated”,
   retain the result IDs, and forbid blind retry. History failure cannot undo saved data.
4. On known pre-write rejection mark `rejected`; stop later saved steps. On ambiguous
   repository I/O outcome mark `uncertain`; block dependent actions pending reconciliation.
5. Restart loads journal and current validated feature stores. Never automatically execute
   any entry. Reconcile applying/prepared/uncertain entries by preallocated IDs: all new
   IDs present => recovered committed; none present => not applied/unknown, request new
   user action rather than replay; subset present for an atomic tree => integrity error.
6. A completed receipt is terminal even if its result was later deleted. Never recreate
   missing results when retrying a terminal action. A fresh user request is a new plan.
7. If a feature store recovered an older generation, do not infer absence proves an action
   never happened. Display recovery uncertainty and require owner inspection/new preview.
8. In-memory retry after a known pre-write failure retains action/result IDs and revalidates
   current state; applies only unfinished actions after fresh approval. After restart no
   payload survives, so ask the user to re-enter the request; identify uncertain prior work.

Journal retention: keep nonterminal entries until reconciled or explicitly dismissed;
terminal receipts remain until explicit Clear History/all-data deletion. Per-row history
deletion removes display entry, not nonterminal recovery evidence. Clear History is disabled
during commit, warns that recovery summaries are being cleared, and invalidates all pending
plans. No pending request survives relaunch, so cleared terminal receipts cannot be replayed.
No automatic retention pruning in v1. Document this local storage behavior.

Cross-store transaction guarantee: each feature step is atomic, mixed-feature plans are
ordered and may partially complete. The UI must never describe the whole release workflow
as a cross-store transaction. Notification scheduling is a separate post-save side effect.
Music/navigation are not replayed/reconciled as saved data after restart.

## 9. Retrieval and aggregate privacy

Eligibility uses actual protection bindings, not session lock indicators. Inactive, archived
or trashed records are excluded. Notes with a protectionID are excluded. Collections with
a protectionID or any protected ancestor are excluded. A Note with membership in ANY such
collection is excluded from Sophy even if also filed in an unprotected collection. Unknown
bindings, dangling ancestry or cycles fail closed for affected items. No Folder is virtual
and unprotected; do not send it as a real destination ID.

- Search local eligible fields only: note title/tags, Page body, Canvas typed text object
  content; collection name/description. Exclude ink, images/OCR, audio, link-fetched pages,
  protected descendants, archived/trash and attachment binary data. Do not start link fetches.
- Rank exact title, title contains, then body/tags contains; break ties by modified date
  descending and stable ID. Return at most 8 candidates. Show a picker for ambiguous named
  targets before sending substantive content. “No eligible match” must not disclose exclusions.
- Per-request context budget: max 8 sources, max 4,000 characters per source, max 16,000
  total source characters. Clip at safe String boundaries and mark excerpts as excerpts.
  Counts/previews describe eligible content only. Sources use ephemeral `n1`, `c1` handles.
- Before sending, show a compact disclosure of eligible source titles and provider; the
  user may remove sources or cancel. This is a context review, not permission to read locks.
- Recheck eligibility immediately before network send, final response display and source
  navigation. If eligibility changes, cancel/clear affected answer and evidence; conservatively
  clear transient conversation turns containing that context. Never keep stale excerpts to
  reuse after a source becomes protected. Invalidated content cannot leak via summaries.
- Recent conversation: at most 20 turns and 24,000 characters, dropping oldest whole turns
  first with visible context-reset notice. Do not persist an AI summary to bypass this limit.

Insights call ActivityAnalytics interval/buckets/modeTotals and existing goal/streak helpers.
Use Calendar.current week definitions; do not invent Monday/Sunday rules. Payload includes
period bounds, timezone, incomplete flag, seconds by mode, aggregate buckets, and supported
goal/streak values with their time scope labeled. Exclude record titles/descriptions, exact
session timestamps, note links and quiz answers. No metrics not backed by existing helpers;
omit unsupported historical goal achievement rather than treating current goals as past goals.
Use built-in mode labels, and label custom modes “Custom activity 1…” in provider payloads;
resolve local display labels in UI. Generate factual totals locally, keeping model prose
separate so a narrative mistake cannot replace the displayed metrics. Offline: show local
metrics and explain that AI habit commentary is unavailable.

## 10. Notes enhancement boundary

Selection snapshot contains noteID, optional Canvas objectID, UTF-16 range, original text,
content revision and editor route. Flush accepted native text before taking snapshot.
Validate using NSString range bounds AND String boundaries so split surrogate ranges are
rejected. Nonempty typed selection only; do not infer selection from ink/object focus.

- Unprotected selection sends only selected text and requested operation/tone, with provider
  disclosure. Protected Note or any protected Collection ancestry requires fresh explicit
  consent and current access to its actual editor route. Being unlocked alone is not consent.
- Consent is bound to selection digest, operation, provider/model, editor route and generation.
  Changing any invalidates it. Digest is transient; it is not written to history/journal.
- Use a dedicated enhancement completion, not general Sophy conversation context. Never
  carry selected text into later chat, diagnostics, metrics, repair messages or automatic tools.
- Result JSON has version 1, kind `enhancement`, replacementText string and feedback string;
  rating additionally has scores `{grammar: number?, idea: number?}` with requested scores
  in 0–10. Reject absent requested score, unrequested score, invalid type or oversized output.
  Max replacement 16,000 characters and max feedback 4,000; no truncation before Replace.
- Grammar preserves meaning; tone changes voice while retaining intent; organize restructures
  without inventing claims; expound marks additional explanation as generated and never invents
  personal experiences; rating explains scores respectfully. No citation fabrication.
- Review modal keeps original/result visible, editing controls reachable with keyboard, and
  offers regenerate/cancel/copy/replace. Rating offers Copy feedback only. Never auto-apply.
- Recheck original revision, selected substring, note/object existence and route access on
  Replace. On conflict retain only an access-safe result for Copy and request reselection.
  Relock/background/restore clears sensitive results and native selection bridge immediately.
- Replacement goes through NotesSession edit/history. Page replacement shifts existing spans
  using the same text-change machinery as typing; unaffected formatting survives. New text
  inherits insertion-point formatting. Canvas replacement uses existing object styling.
  One Undo restores original text/spans; redo reapplies the result; protection flags stay out
  of body undo. Failed autosave retains existing dirty/recovery behavior and shows its notice.
- Follow existing clipboard clearing on relock for protected content. Copy must not bypass
  current access validation. No selected text in crash breadcrumbs or test logs.

## 11. Typed workflow handoffs

Introduce request IDs and one-shot consumer APIs rather than exposing view-local bindings
across tabs. Suggested values:

- `SophyQuizSetup`: requestID, optional difficulty/types/timed; CompanionView consumes once,
  presents QuizMeView with initial values applied once in init (not repeated on rendering).
  Reject/open existing-session choice when an active quiz exists; never abandon it silently.
- `SophyContemplationSetup`: requestID, title, optional validated range/edition; ActivityView
  opens its current Start sheet with mode `meditating`. Preserve guided-workflow preference.
  If disabled, explain timer-only behavior and link Settings; do not change preference.
  If an Activity draft exists, explain it must finish first; never overwrite/discard it.
- `SophyChatSetup`: requestID, preset ID, prompt and shared route. After user Open in Companion,
  preserve an existing unsent composer draft. If occupied, ask Keep current/Start new draft;
  Keep cancels handoff; Start new retains original draft in its conversation. New conversation
  receives preset snapshot/route and editable prompt, no auto-send or source attachment.
- Music maps play/pause/select to MusicSession.handle. A selected track is not success until
  playback snapshot reports the appropriate state; use existing errors for missing files.
  No active track: one playable track can be selected; multiple tracks prompt a choice.
- Navigation closes Sophy panel before presenting destination sheet, avoiding overlapping
  SwiftUI sheets. If another modal is busy, show a pending handoff button; do not auto-open
  later after an unrelated user navigation. A consumed request cannot reopen on tab refresh.

## 12. Persistence and backup contract

Sophy local directory: Application Support `Sophy-v1`; DEBUG test store uses
`Sophy-test-<SP009_TEST_STORE UUID>`. Separate checked JSON files for history and journal,
current/previous generations with SHA-256 payload validation, atomic replacement, 8 MiB
read limit per file, schema 1. Bad current recovers validated previous with a visible notice;
both bad preserves damaged bytes and disables mutation until recovery is addressed. Validate
unique IDs, action/status enums, result counts and dates before accepting loaded data.

Preferences (enabled/edge position) use existing preference conventions, not the execution
journal. Do not include API keys or transient content. History includes safe operation
labels, counts and app IDs; titles are resolved only at display time if still eligible.

Full backup optional `sophyHistory` payload carries only validated visible summaries.
Keep outer schema 1 for this additive compatible field: old apps ignore it; new apps accept
absence. If present, validate before any restore writes and archive old history locally
before replacing it. If absent, preserve local history. Never back up/import execution
journal entries as runnable operations. Restore invalidates pending Sophy work, reconciles
local nonterminal receipts against resulting stores and rechecks visible result references.
Sophy history does not promise cross-store restore atomicity beyond existing backup behavior.
All-data deletion clears history/journal/preferences through the existing explicit flow;
ensure no late callback recreates cleared files. Clear History keeps the enabled setting.

## 13. Character and interaction specification

Create original assets with imagegen when available in the implementing environment. If
unavailable, complete command work/tests but record visual assets blocked; request the owner
provide approved assets or select an asset-generation-capable environment. A temporary
development placeholder is allowed only with a visible DEBUG marker; it cannot pass release.

- Asset format: transparent PNG, consistent 768×1024 canvas, same full-body character/scale,
  no words baked into pixels, no religious/divine identity cues or provider branding.
  Seven separate pose assets; use @1x/@2x catalog sizing consistent with actual rendered size.
- Character visual size 72×96 pt by default; minimum 44×44 hit target. Snap left/right with
  normalized vertical position; default lower trailing safe region. Keep ≥12 pt from safe
  edges and ≥12 pt clear of detected dock/FAB/keyboard exclusion rectangles. If space is
  insufficient, collapse to a labeled 44 pt launcher, not a writing-blocking overlay.
- Native animations: idle breathing ±1.5 pt/3 seconds; greeting single small sway; thinking
  subtle opacity pulse; success one short bounce. No continuous roaming, particle effects,
  sound or large motion. Reduce Motion uses static state changes. No invisible full-screen
  gesture recognizer or hit target outside character/panel controls.
- Panel uses app theme, maximum width 480 pt, available-height constrained; narrow windows
  use an adaptive sheet. Header: Sophy, provider/model, New Session, History, Close. Composer
  supports multiline and slash picker. History states: empty/list/detail with safe summaries.
- Enhancement modal scale 0.96→1 over 0.18 seconds; Reduce Motion uses no scale animation.
  Error/approval state communicated by text and accessibility, not just pose/color.
- Accessibility labels: “Open Sophy”, “Move Sophy”, “Reset Sophy position”, “Sophy History”.
  Provide move/reset actions for VoiceOver. Dynamic Type and keyboard focus must work.
- Persist only edge and normalized vertical position; recalculate safe position on rotation,
  Split View, keyboard and docking changes. Sleep animation while hidden/backgrounded.
- Review assets in app light/dark at intended size for transparent fringes, pose continuity,
  legibility, modest human design and fit with Sophia paper aesthetic. Record provenance
  and owner visual acceptance separately from simulator screenshot checks.

## 14. Package gates and verification fixtures

Proposed new test suite names below are implementation deliverables, not existing evidence.
Keep fixtures isolated and use test doubles instead of live model requests.

| Package | Deliverable and completion gate |
| --- | --- |
| P0 Baseline | Record actual source/API/test names; identify selected simulator; confirm clean scope; compile baseline or record existing blockers before attributing failures. |
| P1 Provider | Shared default migration/picker and Hugging Face adapter; provider/routing tests pass; existing chat/quiz route fixtures unchanged. |
| P2 Contracts | Response validator/state machine and mocked completion; SophyResponseTests/SophyStateTests pass before wiring any mutating action. |
| P3 Durable commands | Awaited folder/Activity/reminder commands and journal; SophyExecutionTests cover every failure/crash boundary; no UI success before durable result. |
| P4 Read-only context | Eligibility/search/metrics/history/backup; SophyPrivacyTests/SophyPersistenceTests pass with mixed membership and corrupt/recovered fixtures. |
| P5 UI/handoffs | Panel/slash/preview/history/settings and typed setup requests; SophyUITests verify confirmation/cancel/one-shot navigation; no auto Start/Send. |
| P6 Enhancement | Selection bridge/review/undo and protected consent; SophyEnhancementTests plus targeted editor UI tests pass. |
| P7 Character | Original assets and native motion/layout; simulator screenshots and accessibility/layout checks pass; owner visual acceptance remains separate. |
| P8 Integrated | Documentation/release evidence, focused + unit regression + relevant full-scheme checks; report device/live-provider gates honestly. |

Mandatory scenario fixtures (use a fixed injected date/calendar/timezone):

1. “Create Bible with New and Old Testament folders and each book” => complete catalog tree,
   editable preview; cancel yields zero new records; confirm once yields correct parent edges;
   double-confirm yields no duplicate; fail tree save yields no published partial tree.
2. “Remind me to read tomorrow” => ask time/title if needed and mode; no save. “Tomorrow at
   8 PM, Reading, Read John” => preview absolute date; past-on-confirm rejected. Monthly
   recurrence => explain unsupported and offer supported choices, never silently daily.
3. “I studied yesterday for 30 minutes” => ask start time/title as needed. Overlap with saved
   or active record rejected with no overwrite. Cross-midnight and conflicting duration clarify.
4. Provider reply `deleteNote`, forged handle, duplicate JSON keys, mixed malformed arguments,
   huge JSON, partial SSE, fake success or prompt-injected note => no unauthorized mutation.
5. Crash before journal, after prepared, after applying, after feature save, after receipt,
   after history write => reopen never auto-executes and identifies correct known/uncertain
   result. Simulate feature recovery to previous generation and deleted terminal result.
6. Reminder durable save succeeds but notification permission denied/scheduler fails =>
   receipt says saved, warning says notifications not scheduled; retry cannot create another.
7. Plain note in plain folder eligible; protected note unlocked excluded; plain note in
   protected ancestor excluded; mixed memberships excluded; cycles/dangling ancestry fail
   closed; protecting a source after send clears answer/context and rejects late callbacks.
8. Protected selected text consent: route/model/selection change invalidates; only selection
   goes into request; relock/restore/background clears it; subsequent normal chat lacks it.
9. Page/Canvas emoji, composed characters, multiline selection and formatting; changed body,
   deleted object, switched route; Replace yields one undo step and rejects stale ranges.
10. Current week/year with midnight and DST splits matches ActivityAnalytics; no interval
    record goes into existing No time behavior; no activity yields honest empty-state totals.
11. Existing quiz/activity active => no silent discard; existing unsent chat preserved;
    one-shot setup does not reopen; guided Contemplation disabled remains disabled.
12. Corrupt history/journal current/previous, missing backup field, valid import, invalid import,
    clear history, all-data deletion during a pending provider task => no replay/content leak.
13. Character off by default; toggle off during inference, rotation, keyboard, Split View,
    VoiceOver reset, Reduce Motion and light/dark => usable controls and no Pencil interception.

### Native verification execution

Use the current [test specification](../testing/test-specification.md) and
[deployment guide](../deployment/deployment.md). Discover Xcode and available iPad simulator
using `xcode-select` and `xcrun simctl list devices available --json`; select a real installed
destination. Put logs/xcresult/DerivedData in ignored `build/sp029/`. Each run needs a fresh
result bundle path. Set DEVELOPER_DIR per command where needed. Use the existing scheme and
project; do not invent a new app target. Focus new suites first, then regression once integrated.
Signed Keychain UI tests require the project's documented setup; an unsigned Keychain failure
is not functional evidence. Never run destructive UI tests against the owner's personal store.

Record each result as pass/fail/blocked/not-run with command, destination, counts and artifact
path. Documentation-only edits require relative-link/path checks and git diff --check, not
native tests. Live-provider tests require locally configured keys; absent keys are Not Run,
never an excuse to fabricate success. Physical device/notification/Pencil/visual gates must
remain separate and need observed owner evidence before closure.

## 15. Definition of done and continuation prompt

SP-029 source work is complete only when P0–P8 deliverables exist, privacy and durable
execution tests pass, docs describe final behavior and all unresolved live/device/visual
criteria are explicitly dispositioned. Release acceptance is separate from source completion.
Do not mark the whole ticket done while required acceptance remains unobserved unless the
owner explicitly accepts/waives those specific gates. No silent feature omissions.

Suggested instruction for another coding agent:

> Execute SP-029 using its normative Sophy implementation guide. Start at the first
> incomplete P0–P8 package, inspect exact current source, implement and verify that package,
> record evidence in SP-029, and continue through the selected scope. Preserve owner data,
> existing protection semantics and unrelated changes. Do not skip privacy/crash tests,
> auto-publish a release, or substitute test fixtures for live/device acceptance. If an
> external input is unavailable, complete independent work and report the exact remaining gate.
