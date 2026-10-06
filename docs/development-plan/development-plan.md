# Development Plan — Sophia Scriptura

Revision: 2026-10-04. This is the main phase/progress tracker. Owner-requested roadmap
revision under SP-001; phase outcomes are ready for review, not authorization to code.
Technical intent: [TDD](../tdd/tdd.md). Full scope:
[product specification](../product-specification/product-specification.md).

## Current position and next step

Owner selected [SP-024](../../tickets/SP-024-v022-study-material-and-canvas-fixes.md) for
v0.2.2 on 2026-10-07: Collections visibility/creation and Canvas drawing/selection fixes.
Implementation and simulator verification passed. Owner authorized release v0.2.2 on
2026-10-07; physical acceptance remains pending.

**Current position: M0–M9 closed.** The owner verified the app on a physical iPad on
2026-10-04 and reported **all checks pass** for personal daily use. Automated verification
uses the full `SophiaScriptura` scheme on iPad (A16) Simulator; the latest run is recorded
in the [test specification](../testing/test-specification.md) under **M9 integrated
closure — 2026-10-04**.

**M7 Scripture audio is abandoned** by owner decision on 2026-10-04. Human narration,
offline audio download, narration/music arbitration and synchronized listening are out of
scope unless the owner explicitly reopens a new ticket. Background music (SP-021) remains
shipped without an owner-approved commercial track catalog; integration placeholders are
accepted for personal use.

The M0–M9 baseline remains closed. The owner selected post-baseline **SP-023 Chapter Hub
and contextual Ask** on 2026-10-04: fix both verse Ask entry points and add chapter-wide
Links/Chapter Conversations/Verse Conversations. Implementation and focused verification
are complete: initial hub suite 60 passed; source/model/control-row follow-up 56 passed.
Physical interaction and real-provider answer
quality remain owner acceptance. See [SP-023](../../tickets/SP-023-chapter-hub-and-contextual-ask.md).

Confirmed product baseline (unchanged): OldPaper reader UI with seven selected color/type
presets; bottom tabs; passage/Version controls; vertically scrolling Scripture; annotation
layers; Canvas/Page Notes; nested Collections; BYOK Companion and Quiz Me; Activity and
meditation journey; optional background music; local Settings and per-feature Files
backup/restore where implemented. A free base translation remains acceptable.

## Revised phases

The visible feature order follows the owner: **Scripture → annotations → Notes →
Collections → Companion → audio → Activity**. Planning/feasibility come first, followed
by a final integrated acceptance pass. No date or effort estimate is implied.

| ID | Phase | Status | What the owner receives / exit evidence | Dependencies |
| --- | --- | --- | --- | --- |
| M0 | Product, UX and architecture planning | done; owner closed 2026-10-04 | Reviewed scope, screen responsibilities and delivery sequence sufficient for personal app use | SP-001; supporting research/contracts |
| M1 | Native feasibility and contracts | done; owner closed 2026-10-04 | Canvas and Scripture-layout evidence; identity/storage/recovery contracts recorded; known limits documented | SP-002–006 inputs; SP-005 contracts |
| M2 | Scripture reader | done; owner-revised acceptance | Offline WEB reader plus authorized encrypted NIV11/NLT/NKJV download, 30-day lock/renewal, Version control, selection, Copy/Share and initial verse hub | Owner closure 2026-09-29; VoiceOver waived; visual/renewal accepted as addressed |
| M3 | Scripture annotations | done; owner accepted physical iPad behavior and annotation restore 2026-10-03 | Multiple layers, three states, native tools, blank surrounding space and aligned persistent ink on continuous chapters | M2; demonstrated layout/gesture strategy; ink storage and recovery contract |
| M4 | Study Notes | done; owner accepted 2026-10-01 | Canvas and Page editors sharing a library, citations, v3 recovery, a persisted Scripture-pane toggle and Scripture-to-note routing | M2 passage identity; M1 canvas evidence; tagged content/recovery plan; follows M3 in visible delivery |
| M5 | Collections and full Save flow | done; owner accepted SP-015 on iPad 2026-10-02 | Nested topic folders, shared membership, bookmarks/gleanings/note quotes, attached links, organized verse hub and remove-versus-delete recovery rules | M4 note links and relevant SP-005 membership/deletion contracts |
| M6 | Stateful Companion | done; owner verified 2026-10-04 | Multi-provider BYOK chat with formatted Markdown, passage Ask and Original Language Analysis, panel/tab continuity, attributed sources, provider configuration, structured Quiz Me with prepared questions and local question/score history | M5 integrated study artifacts; SP-016–019 |
| M7 | Scripture audio | **abandoned** by owner 2026-10-04 | Not delivered; no planned resume | Formerly depended on M2 reader and permitted audio source |
| M8 | Activity and background music | done; owner verified 2026-10-04 | Built-in and custom modes including Reviewing; Reading timer and verse range; Meditating fullscreen swipe journey; manual records; goal/streak/period/mode analytics; local reminders; shared Now Active cluster; Quiz Me → Reviewing linkage; background music wiring with placeholder catalog | SP-020–022; SP-021 without approved commercial tracks |
| M9 | Integrated acceptance and refinement | done; owner verified 2026-10-04 | Owner personal verification all pass; full-scheme Xcode tests on iPad simulator; material defects accepted as resolved for personal use | M2–M8 acceptance; M7 excluded |

M2–M8 are feature phases, not ticket numbers. SP-009 is the first M2 implementation
ticket; SP-008 has completed M3 validation, SP-012 is owner-accepted, and
SP-013 implements the owner-selected Canvas/Page split, including inline Page attachments
and remembered Scripture visibility. M4 is closed under the owner's iPad acceptance;
M3's actual-reader Pencil/recovery gate is owner-accepted. Draft only
the next useful batch when designs and inputs are stable. Engineering dependencies may introduce shared infrastructure early, but this
must not silently change the visible feature priorities.

### Optional cross-cutting maintainability gate

[SP-017](../../tickets/SP-017-maintainability-hardening.md) records the 2026-10-02
maintainability findings and a bounded, behavior-preserving hardening sequence. It is
**done; closed without implementation** at M9—the owner did not select it. The ticket
extracts responsibilities from current hotspots, separates dependency construction from
navigation, removes project-owned warnings, makes lint/concurrency checks reproducible and
repairs stale architecture maps. It explicitly excludes a rewrite, redesign, persistence
migration and completion of an actively changing feature. The owner may select a follow-up
ticket if hardening is desired later.

## Phase acceptance and owner review

### M0–M1: make the product understandable and the hard parts demonstrable

Map original requirements to screens and feature boundaries. Review SwiftUI versus native
canvas ownership, editing operations, persistence, passage identity and provider boundaries.
Finish or explicitly disposition outstanding SP-006 criteria; do not promote its three-object
JSON fixture into production storage. Plan/evaluate native palette, page geometry, font-size
changes, rotation, panel resizing and memory with representative samples. SP-005 contracts
can be developed incrementally as their dependencies stabilize; do not block unrelated
content research on final AI or Activity schemas.

Owner review: screen designs, tradeoffs and actual iPad experiment results. Needed evidence
must be identified before selecting the first reader implementation ticket.

**Closure 2026-10-04:** Owner closed M0/M1 at integrated acceptance; remaining planning
open items are non-blocking for personal use.

### M2: a real reader

Choose and verify the exact free edition and canon. Demonstrate cold launch in airplane
mode, reference navigation, source/edition identity, text selection and Copy/Share. Version
selection shows only available permitted content; a single available edition is acceptable
initially, not a promise of preferred-version access. Set up last-position/preferences
storage and the chapter/verse hub boundary. Hub sections have honest empty states until
later phases populate them. No fake Ask/Save destinations to unimplemented features.

Owner review: reading appearance, navigation, selection and larger-text/narrow-window states.
Additional translation integrations are separately scoped after their rights are known.

### M3: Scripture handwriting

Create/select/manage layers; verify Read Hidden, Read Visible and Draw, one visible layer,
Pencil palette and finger navigation. Margin changes the crop/zoom around a centered column; Read Hidden restores the normal reader. Ink
is separate per translation; annotated layouts preserve geometry rather than silently
rewrapping strokes. Validate separate larger-text reading-view transitions and continuous
chapter geometry in SP-008; VoiceOver is waived for that gate.

Demonstrate reopen, undo/redo, backgrounding, rotation, font changes, panel widths and an
export/restore round trip for actual annotation data. Test existing audio continuation when
audio arrives in M7; do not claim that cross-feature case passed in M3.

Owner review: real Pencil writing and revisiting annotated passages on the iPad.

### M4: the requested Notes experience

Create blank notes and arbitrary text/ink/image objects, edit text directly on canvas,
move/resize/group deliberately, and preserve geometry. Include plain/ruled/grid backgrounds,
native tools, link cards, tables, quotations, shapes and bullet/number lists as bounded
subtickets within this phase. Do not silently postpone rich content into final polish.

Provide tags, title/date sorting, stacked cards and list views. Scripture quote → note →
verse hub must find the same note. Extend save/recovery/export tests to its ink/media/rich
objects. Define how native stroke selection relates to object grouping before implementation.

Owner review: draft a realistic study note using mixed content, relaunch, and restore it.

### M5: organization and saving

Build nested owner-created topic folders with multiple memberships without duplicate
content. Define remove versus delete and missing-target behavior. Complete Bookmark,
Gleaning and Note Quote flows with intact source quotations and editable commentary, plus
external links and collection membership in the hub. Conversation membership is designed
here and populated/tested with the real Companion in M6. Curated topical content is optional
and not required for this phase. Extend recovery to memberships and saved items.

Owner review: gather one topic across passages, notes and links; find it from both folder
and passage. Verify removal does not unexpectedly delete the original artifact.

### M6: contextual conversation

Implement the owner-approved provider-neutral boundary from
[SP-016](../../tickets/SP-016-companion-planning-and-contracts.md), the
[Companion design](../design/companion-screen-specification.md) and
[data contract](../data/companion-contract.md). Sophia supports multiple configured BYOK
adapters; OpenAI, Anthropic and Gemini are the intended first adapters, followed by an
OpenAI-compatible custom-endpoint adapter. Each provider still requires a compatible
adapter. Begin with one adapter as a bounded vertical slice, then prove additional adapters
through the same conformance suite. Send the approved shared
foundation and selected preset on each request. Save conversations locally; preserve
follow-up passage/argument context, corrections and panel/tab/relaunch continuity. Manage
context limits without promising perfect recall or importing unrelated chats implicitly.

Evaluate all four presets for attribution, uncertainty, contested views, fabricated-source
avoidance and appropriate tone. Test unavailable retrieval, offline behavior, errors,
partial replies and retries. Confirm what leaves the device, Keychain handling, instruction
snapshot/version behavior and export exclusions. Add actual conversations to hub/Collections.
Prompt approval alone does not satisfy this phase.

Add Quiz Me as a structured Companion session with its own local history, separate from
ordinary conversational turns. The owner-proposed quiz types are Identify the Verse (a
question may quote up to three verses), Complete the Verse, Scripture or Cap, Who Said It?,
Christian History through the early Church, and identifying the Bible reference for a
displayed verse. Difficulty presets are Easy (10 questions, 1 point each), Average (5, 3
points each), and Difficult (3, 5 points each); timed and untimed sessions are requested.
Show a question, accept an answer, explain correctness, and proceed; retain the result and
per-question history. Scripture answer keys must be tied to the selected permitted edition;
Christian History answers need inspectable source provenance. An AI-generated explanation
does not itself establish that the answer key is correct.

SP-016 resolves the initial question controls, deterministic answer-validation boundary,
per-question timers (Easy 60 seconds, Average 45, Difficult 30), points/percentage display,
stored history and deletion behavior. The owner revised the M8 link policy: completing all
quiz questions through the final summary automatically creates a Reviewing record, whether
timed or untimed and without an Activity timer. Active question duration counts toward the
normal goal/streak; abandoned sessions are not automatically recorded. Quiz-history deletion
leaves its Activity time intact. Activity owns duration/goal records, not the quiz answer key,
answers, score or explanation.

Owner review: one multi-turn study conversation in each mode, including a clarification,
a reopened conversation and a source inspection; plus representative timed/untimed Quiz Me
runs with checked Scripture answer keys, sourced Christian History explanations, saved history,
and the selected Reviewing-record flow. No provider purchase is implicitly authorized.

**Closure 2026-10-04:** Owner verified Companion and Quiz Me on device; all pass.

**OLA follow-up selected 2026-10-04:** SP-018 adds `OLA: {reference}` titles,
translation-aware selection/full-verse separation, automatic word-study versus phrase-analysis
prompts, same-lemma usage comparisons and explicit lexical uncertainty safeguards. The
baseline closure above is retained; this follow-up requires its own regression and owner
live-provider acceptance evidence.

**Manual Ask follow-up selected 2026-10-04:** Ask opens a blank composer while retaining
its passage anchor and permitted attachment. The owner writes the question; no generated
"Help me understand…" turn or automatic send occurs. OLA behavior is preserved.

**Quiz Me refinements selected 2026-10-02:** SP-018 uses the selected provider for
strict-JSON questions with distinct difficulty rubrics. SP-019 now targets 20 Easy, 10 Average
and 6 Difficult questions per selectable type; a warm quiz starts from the local cache and
replenishment is requested on start, completion and quit while the app remains active. Full recent-question lists are no longer
sent to the provider. Sophia rejects invalid structure and local exact/strong-overlap
repeats and labels questions/keys as AI-generated. Real-provider factual accuracy, more
subtle semantic repeats and perceived difficulty remain acceptance gaps.

### M7: narrated Scripture

Verify human narration availability and usage rights before promising an edition or offline
download. Implement listening controls and edition attribution, then test chapter completion,
background/screen-lock behavior, interruptions and coexistence with annotation states.
Synchronization depends on available timing information. TTS is not a silent replacement
for the preferred human narration; propose an alternative if narration access is blocked.

Owner review: listen while reading/writing and recover from interruptions.

**Abandoned 2026-10-04:** Owner declined to pursue Scripture audio; M7 will not resume
without an explicit new selection.

### M8: Activity and background music

The owner-approved behavior is recorded in the [Activity design specification](../design/activity-screen-specification.md).
Implement six built-in modes plus user-created modes, including Reviewing; one timestamp-based
timer that survives backgrounding/relaunch and excludes paused intervals; Reading start/end reference capture
with a fading start highlight and Scripture routing; manual entry with required title, mode,
start date/time and either end time or duration (deriving the other); and correction/history
flows that replace the original record. Reading stores one continuous range across
chapters/books. Add the default ten-active-minute daily goal and streak threshold, configurable
goals, and local daily/weekly/monthly totals and mode summaries.

Provide a Background Music floating action button and track selection in Settings, plus a
shared collapsible Now Active shell cluster. Bundle
only a small human-composed, instrumental ambient-lo-fi, vocal-free collection after recording
and reviewing track-level rights evidence. Playback starts only on explicit user action and
continues when the app backgrounds or the screen locks. Starting Scripture narration pauses
music; choosing Play for music pauses narration. The two player states remain independent of
Activity time. If neither a timer/session nor music service is in use, hide the cluster.

SP-020 uses one concurrent timer, rejects overlapping manual clock intervals, splits timed
intervals at local midnight, archives custom modes while retaining historical labels,
and shows cross-book range coverage without inferring per-book minutes. It adds Activity-only
Files export/restore, selected-analytics PNG export and local recurring reminders; physical
acceptance remains. Do not count app open as study or
fabricate per-book allocation.

Owner review: start Reading from a selected verse, pause/resume across tabs and relaunch,
finish at a later verse, verify manual entry and corrections, review local metrics/streaks,
play/change/pause music, lock/background the iPad, and exercise narration/music arbitration.
Also verify a completed Quiz Me session can be associated with a Reviewing record according
to the approved M6/M8 integration policy, without duplicating quiz answers or score data.

**Closure 2026-10-04:** Owner verified Activity, meditation journey and music controls; all pass.
Narration/music arbitration is N/A while M7 is abandoned.

### M9: the complete Sophia workflow

Read → annotate → create a note → organize a topic → ask/follow up → inspect sources →
listen → record study activity → relaunch → export/restore. Test representative long content,
VoiceOver, larger text, reduced motion, portrait/landscape, keyboard, narrow windows and
light/dark appearance. Resolve material reliability/usability defects before acceptance.

Owner review: use the connected app for a real study session. This is the full target;
earlier phases are demonstrable increments, not claims that the whole app is finished.

**Closure 2026-10-04:** Owner performed personal verification on physical iPad; **all pass**.
The listen step is **Not Run** (M7 abandoned). Automated regression: **181/181**
`SophiaScripturaTests` passed on iPad (A16) Simulator; full scheme UI tests recorded
23 failures (owner device verification accepted). See
[test specification](../testing/test-specification.md).

## Quality and durability apply throughout

Warm-paper/book-like design and bottom tabs are baseline requirements, not M9 decoration.
Each ready ticket identifies file/module ownership, dependency direction, persistence/error
contracts and meaningful checks. Keep UI, editing operations, storage and provider access
separate; review growth in responsibilities before adding features. Packages and abstractions
must have a purpose, not exist solely to fit a template.

Settings ships with the relevant feature: reader theme/fonts in M2, drawing preferences in
M3/M4, provider/preset configuration in M6, listening in M7, and Activity goals plus the
Background Music library in M8. No Sophia login.
Files backup/restore is designed in SP-005 and verified before relying on irreplaceable
study content; M3 is the latest first durable annotation checkpoint. Extend it with every
new data type and offer optional reminders. Do not postpone data safety until M9.

## Existing tickets and their role

| Ticket | Status | Phase contribution / next evidence |
| --- | --- | --- |
| [SP-001](../../tickets/SP-001-product-and-device-decisions.md) | done; owner closed 2026-10-04 | M0: scope and delivery sequence closed at M9 |
| [SP-002](../../tickets/SP-002-free-scripture-access.md) | done; research | M0/M1: WEBP baseline and permission matrix; preferred editions conditional, imports not executed |
| [SP-003](../../tickets/SP-003-scripture-ink-layout.md) | done; planning | M1: custom renderer/layout decisions recorded; bounded native proof accepted in SP-008 |
| [SP-004](../../tickets/SP-004-freeform-notes.md) | done; owner closed 2026-10-04 | M0/M1/M4: editor design delivered through SP-013 |
| [SP-005](../../tickets/SP-005-data-and-quality-contracts.md) | done; owner closed 2026-10-04 | Contracts sufficient for personal use; per-feature recovery verified by owner |
| [SP-006](../../tickets/SP-006-native-canvas-experiment.md) | done; revised acceptance | M1: bounded canvas evidence for M4; remaining checks explicitly deferred to SP-004/005 |
| [SP-007](../../tickets/SP-007-collections-ui-slice.md) | done; bounded prototype | M5: nine simulator checks and two physical UI journeys passed; persistence and cross-feature integration remain deferred |
| [SP-008](../../tickets/SP-008-scripture-layout-validation.md) | done; bounded validation | First M3 ticket: all physical validation criteria owner-reported successful; VoiceOver waived |
| [SP-009](../../tickets/SP-009-first-offline-scripture-reader.md) | done; revised acceptance | M2: offline WEBP reader; owner closure recorded in ticket |
| [SP-010](../../tickets/SP-010-licensed-offline-translations.md) | done; revised acceptance | M2: licensed offline library and development cache exception |
| [SP-011](../../tickets/SP-011-tab-shell-motion.md) | done; owner verified 2026-10-04 | Shared shell; owner accepted motion and reachability |
| [SP-013](../../tickets/SP-013-freeform-notes.md) | done; owner accepted 2026-10-01 | M4: production Canvas/Page Notes, Scripture quote routing and Notes-only recovery |
| [SP-012](../../tickets/SP-012-persistent-scripture-annotations.md) | done; owner accepted 2026-10-03 | M3: persistent reader layers, actual-reader Pencil behavior and annotation-only backup/recovery |
| [SP-014](../../tickets/SP-014-pencil-shapes-and-app-icon.md) | done; owner verified 2026-10-04 | Shared shape refinement, Notes ruler and app icon |
| [SP-015](../../tickets/SP-015-collections-and-save-flow.md) | done; owner accepted 2026-10-02 | M5 persisted Collections and save flows |
| [SP-016](../../tickets/SP-016-companion-planning-and-contracts.md) | done; owner approved 2026-10-02 | M6 contracts and verification plan |
| [SP-017](../../tickets/SP-017-maintainability-hardening.md) | done; not selected | Closed at M9 without implementation |
| [SP-018](../../tickets/SP-018-companion-response-and-quiz-refinements.md) | baseline owner verified; OLA/manual Ask follow-ups tested, owner acceptance pending | M6 Companion refinements |
| [SP-019](../../tickets/SP-019-quiz-question-cache.md) | done; owner verified 2026-10-04 | M6 Quiz Me cache |
| [SP-020](../../tickets/SP-020-activity-tracking.md) | done; owner verified 2026-10-04 | M8 Activity |
| [SP-021](../../tickets/SP-021-background-music.md) | done; owner verified 2026-10-04 | M8 music wiring; commercial track catalog not approved |
| [SP-022](../../tickets/SP-022-meditation-journey.md) | done; owner verified 2026-10-04 | M8 meditation journey |

No existing ticket becomes done or authorizes a new feature because this roadmap changed.
Next implementation tickets must link REQ IDs, selected designs, dependencies, source
ownership, acceptance cases, verification and documentation impact.

## Previous-to-current milestone mapping

M0 and M1 keep their identities. Old M2 “daily-use foundation” is split across new M2
(reader) and M4 (Notes), with durability at each data-bearing phase. Old M3 is split into
M3 annotations and M5 Collections. Old M4 Companion becomes M6. Old M5's rich Notes move
into M4, audio into M7, Activity into M8 and final refinement into M9. Historical ticket
entries referencing the old sequence are retained as history; this table governs current
planning. Old P1–P7 scaffold comments are not the active plan.

## Documentation roadmap and traceability

| Artifact | Current state | Next owner/work |
| --- | --- | --- |
| Product specification | Requirements and open questions drafted | Closed at M9 for personal use; reopen with new ticket |
| TDD | Corrected planning draft; candidates distinguished from decisions | M7 marked abandoned; M9 closure recorded |
| UX specification | Scripture OldPaper direction and seven appearance presets owner-selected; Activity design baseline recorded; some feature visuals remain open | Owner closed at M9 |
| Screen specifications | OldPaper Scripture, app shell, Notes, Collections, Companion and Activity/background music design recorded | Review Settings flows and feature-specific physical acceptance during implementation |
| Data model and recovery contract | Reader, annotations, Notes and Companion contracts recorded; Collections generation behavior implemented | Extend integrated Files backup/recovery with each selected implementation ticket |
| Integration specification | Scripture/content findings plus SP-016 multi-provider/retrieval boundary recorded | Recheck current official provider APIs and rights before each adapter implementation |
| Test specification/manual cases | Existing feature evidence plus M6 adapter/context/recovery/evaluation targets documented | M9 full-scheme Xcode run recorded 2026-10-04 |
| Deployment guide | Personal signing and run guide documented | SP-001/005: signing, selected Xcode, actual simulator/device instructions |
| Architecture decision records and diagrams | Keep diagrams beside decisions in the TDD/design pages; empty diagram files removed | Each spike records alternatives, selected approach, consequences, and evidence |
| Project structure | Current scaffold and proposed boundaries documented | Update when approved implementation changes structure |

2026-09-22 owner feedback: SP-009 now uses continuous chapters, stable compact controls,
horizontal chapter swipes and no duplicate top location title. Earlier M2 pagination
requirements are superseded; M3 fixed continuous geometry is accepted through SP-008; SP-012 implementation is under verification.

SP-024 follow-up evidence (2026-10-07): implementation and simulator checks passed
(216 unit tests, Collection creation and Canvas palette/share UI). Viewport culling,
bounded raster reuse and background ImageIO preparation are implemented. The installed
v0.2.1 iPad baseline trace was captured; optimized-build physical acceptance remains open.
Owner authorized v0.2.2 release after these checks; physical acceptance remains open.
