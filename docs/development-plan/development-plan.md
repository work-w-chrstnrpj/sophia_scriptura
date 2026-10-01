# Development Plan — Sophia Scriptura

Revision: 2026-10-02. This is the main phase/progress tracker. Owner-requested roadmap
revision under SP-001; phase outcomes are ready for review, not authorization to code.
Technical intent: [TDD](../tdd/tdd.md). Full scope:
[product specification](../product-specification/product-specification.md).

## Current position and next step

**Current position: M2 is closed under owner-revised acceptance; SP-008 validation is closed
and M4/SP-013 Notes is closed (2026-10-01).** The owner accepts the implemented
reader visual refinements and confirms expiry/renewal was addressed in the other
conversation. Current SP-010 source/evidence records the Debug development authorization
and cached-access recovery; Release/Archive retains the standard lease. VoiceOver is
waived for this M2 closure and SP-008 transition, not recorded as passed. Historical
unrun accessibility/device cases remain evidence gaps, not blockers to this decision.
SP-001 and later-feature SP-005 contracts remain in progress. The Activity/Music behavior
baseline was refined with the owner on 2026-10-01; M8 still awaits M7 and a bounded
implementation ticket. The Canvas/Page redesign and first workspace refinement are installed. The owner then
selected dark/light/dark ink correction, removal of reserved footer space across tabs,
and consistent theme surfaces; this follow-up is implemented and installed under SP-013, with 35 selected checks passing.
The owner then selected [SP-014](../../tickets/SP-014-pencil-shapes-and-app-icon.md) as a
separate pre-M5 refinement: held Pencil strokes now refine into a bounded supported shape
set across Notes and Scripture annotations, Notes includes the native ruler, and the supplied
Sophia icon is compiled for default/dark/tinted appearances. Focused shape tests, the
Notes/annotation regression, the Notes ruler, and the installed Home Screen icon pass on
the iPad simulator. Endpoint snap, its Undo/Redo, palm rejection, and dark/tinted Home
Screen appearances remain physical iPad checks. No M5 code is included.

Confirmed: OldPaper reader UI baseline with seven selected color/type presets; bottom tabs; passage/Version controls with sequential Book → Chapter → Verse navigation;
vertically scrolling Scripture pages; multiple annotation layers and three states;
translation-specific ink with preserved annotated layouts; Blank surrounding writing space through Margin (owner revision 2026-09-29);
layer-owned appearance/layout selection and compact Draw palette (SP-012 owner revision);
selectable Scripture typeface; landscape verse-hub popovers; optional two-translation
comparison aligned by canonical verse anchors; stable compact reader controls;
expandable Notes with native Pencil palette, explicit grouping and direct text editing;
nested Collections; four approved Companion presets and contextual follow-ups; human
narration preference; six built-in Activity modes plus custom modes, a Reading start-to-end
passage flow, pause-excluded duration, ten-minute daily goal/streak defaults, and
human-composed instrumental ambient lo-fi background music; local Settings and Files
backup/restore with optional reminders. A free base translation is acceptable.

Existing evidence: scaffold, SP-006 sample and native test targets; prior build/unit and
individual UI results are recorded in the [test specification](../testing/test-specification.md).
The owner tried the sample and reported it broadly works, but lacks the expected Pencil
palette. This is not acceptance of all device cases or a completed Notes editor.

**Most recently closed owner work:** [SP-013](../../tickets/SP-013-freeform-notes.md), M4 Study Notes. The Canvas/Page split, workspace refinement, ink-memory correction and Page recursion correction are accepted. Scripture now routes selected passages into an open note or offers new Page, new Canvas and existing-note destinations. The reader is quieter and the floating dock uses a three-second idle delay. Verification and installation evidence are tracked in SP-013. Earlier selected work: [SP-012](../../tickets/SP-012-persistent-scripture-annotations.md),
persistent annotations in the actual Scripture reader. SP-005 annotation planning is
complete; domain identity, generation storage/recovery, reader layers and ink-only Files
backup/restore are implemented and undergoing verification. M3 remains in progress until
actual-reader Pencil acceptance and the recovery drill. See the
[device walkthrough](../testing/sp012-ipad-guide.md). SP-008's physical acceptance remains
bounded experiment evidence; VoiceOver is waived. SP-011 footer reachability is fixed;
subjective shell-motion review remains separate.

## Historical M2 implementation sequence

SP-006 and SP-007 are actual code, but bounded prototypes. The reader-only planning chain
is complete; the owner selected **SP-009** via “Develop M2”. Its inputs are:

1. **SP-002 — content (research done):** WEBP USFM, the existing 66-book scope,
   source/credit and import checks are recorded. Snapshot acquisition/import still needs
   implementation. Preferred commercial translations must not block a
   permitted free-base reader; track their access separately.
2. **SP-003 — rendering (planning done):** custom TextKit direction, verse selection/taps
   and layout identity that can support the approved future ink behavior. Scope a
   focused layout experiment only if unresolved risk requires executable evidence.
3. **SP-005 — reader contracts (done):** canonical passage/edition/revision IDs, immutable
   bundled content, last-position/preferences storage, restore fallbacks and errors are
   recorded in the maintained reader contract. Other feature contracts remain separate.
4. **SP-009 — first product slice (now closed under revised acceptance):** implement and verify offline reading,
   Book/Chapter/Verse navigation, one available Version, fonts, Copy/Share, the initial
   verse hub and the approved bottom-tab shell in one vertical slice.

The owner selected that implementation ticket; M2 is now closed as recorded above. Do not repeat completed canvas
experiments or require all future screens to be designed before beginning M2. The owner
reviews the visible reader and any meaningful unresolved tradeoffs; the agent handles
research, contracts, ticket drafting, implementation and automated checks within each
selected scope. This sequence is a recommendation, not authorization for new tickets.

## How to use this tracker

- A milestone (M) is an outcome; a ticket (SP) is a bounded planning, research, experiment
  or implementation task. SP-006 is not the sixth/final app phase.
- Owner chooses a ticket after its scope is explained. “Ready” does not mean selected.
- `in_progress` means work has started; `blocked` names unmet dependencies; `pending`
  means unstarted. `done` requires evidence for the exit criteria, not code alone.
- The AI updates the selected ticket and this tracker after work, identifies gaps, and
  returns control before a new ticket or feature. Follow the [owner workflow](../guidelines/ai-structure-guidelines.md).
- Test artifacts stay in ignored `build/`; durable conclusions and owner observations
  belong in tickets. Never count an unreviewed result or missing report as a pass.

## Revised phases

The visible feature order follows the owner: **Scripture → annotations → Notes →
Collections → Companion → audio → Activity**. Planning/feasibility come first, followed
by a final integrated acceptance pass. No date or effort estimate is implied.

| ID | Phase | Status | What the owner receives / exit evidence | Dependencies |
| --- | --- | --- | --- | --- |
| M0 | Product, UX and architecture planning | in_progress | Reviewed full-app screens, responsibilities, open decisions and a ready next-ticket scope | Owner review and SP-001; supporting research/contracts as relevant |
| M1 | Native feasibility and contracts | in_progress | Canvas and Scripture-layout evidence; reviewed identity/storage/recovery contracts; honest limits recorded | SP-002–006 inputs; targeted owner-selected experiments |
| M2 | Scripture reader | done; owner-revised acceptance | Offline WEB reader plus authorized encrypted NIV11/NLT/NKJV download, 30-day lock/renewal, Version control, selection, Copy/Share and initial verse hub | Owner closure 2026-09-29; VoiceOver waived; visual/renewal accepted as addressed |
| M3 | Scripture annotations | in_progress; SP-012 implemented; verification/device acceptance pending | Multiple layers, three states, native tools, blank surrounding space and aligned persistent ink on continuous chapters | M2; demonstrated layout/gesture strategy; ink storage and recovery contract |
| M4 | Study Notes | done; owner accepted 2026-10-01 | Canvas and Page editors sharing a library, citations, v3 recovery, a persisted Scripture-pane toggle and Scripture-to-note routing | M2 passage identity; M1 canvas evidence; tagged content/recovery plan; follows M3 in visible delivery |
| M5 | Collections and full Save flow | done; owner accepted SP-015 on iPad 2026-10-02 | Nested topic folders, shared membership, bookmarks/gleanings/note quotes, attached links, organized verse hub and remove-versus-delete recovery rules | M4 note links and relevant SP-005 membership/deletion contracts |
| M6 | Stateful Companion | ready for a bounded implementation ticket; SP-016 planning approved | Multi-provider BYOK chat with four approved contexts, follow-ups, passage Ask, panel/tab continuity, attributed sources, provider configuration, structured Quiz Me and local question/score history | M5 integrated study artifacts; approved Companion design/data/privacy contracts; current provider API feasibility must be rechecked per adapter |
| M7 | Scripture audio | blocked | Permitted human narration with playback controls and tested interruptions; explicit edition/availability handling | M2 reader and permitted audio source; follows M6 in visible delivery |
| M8 | Activity and background music | blocked by M7; behavior baseline recorded | Built-in and custom modes including Reviewing; cross-book Reading timer and verse range; manual records; goal/streak/period/mode analytics; human-composed instrumental ambient lo-fi; shared Now Active cluster; opt-out linked Reviewing records for Quiz Me | M7 narration arbitration; Activity design contract; remaining overlap/concurrency/midnight/per-book allocation decisions |
| M9 | Integrated acceptance and refinement | pending | Owner-approved complete study journey, recovery drill, accessibility/performance evidence and resolved material defects | M2–M8 acceptance |

M2–M8 are feature phases, not ticket numbers. SP-009 is the first M2 implementation
ticket; SP-008 has completed M3 validation, SP-012 awaits physical acceptance, and
SP-013 implements the owner-selected Canvas/Page split, including inline Page attachments
and remembered Scripture visibility. M4 is closed under the owner's iPad acceptance;
M3 retains its separate actual-reader Pencil/recovery gate. Draft only
the next useful batch when designs and inputs are stable. Engineering dependencies may introduce shared infrastructure early, but this
must not silently change the visible feature priorities.

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
stored history and deletion behavior. **Record this as Reviewing** defaults on and may be
disabled before a session. Completed or intentionally ended recorded sessions create a
linked Reviewing record whose active duration counts toward the normal goal/streak; abandoned
sessions require manual saving. Activity owns duration/goal records, not the quiz answer key,
answers, score or explanation. Preserve quiz score/history in the Quiz session even if no
Activity record is created.

Owner review: one multi-turn study conversation in each mode, including a clarification,
a reopened conversation and a source inspection; plus representative timed/untimed Quiz Me
runs with checked Scripture answer keys, sourced Christian History explanations, saved history,
and the selected Reviewing-record flow. No provider purchase is implicitly authorized.

### M7: narrated Scripture

Verify human narration availability and usage rights before promising an edition or offline
download. Implement listening controls and edition attribution, then test chapter completion,
background/screen-lock behavior, interruptions and coexistence with annotation states.
Synchronization depends on available timing information. TTS is not a silent replacement
for the preferred human narration; propose an alternative if narration access is blocked.

Owner review: listen while reading/writing and recover from interruptions.

### M8: Activity and background music

The owner-approved behavior is recorded in the [Activity design specification](../design/activity-screen-specification.md).
Implement six built-in modes plus user-created modes, including Reviewing; one timestamp-based
timer that survives backgrounding/relaunch and excludes paused intervals; Reading start/end reference capture
with a fading start highlight and Scripture routing; manual entry with required title, mode,
date and duration; and correction/history flows. Reading stores one continuous range across
chapters/books. Add the default ten-active-minute daily goal and streak threshold, configurable
goals, and local daily/weekly/monthly totals and mode summaries.

Provide a Background Music floating action button and track selection in Settings, plus a
shared collapsible Now Active shell cluster. Bundle
only a small human-composed, instrumental ambient-lo-fi, vocal-free collection after recording
and reviewing track-level rights evidence. Playback starts only on explicit user action and
continues when the app backgrounds or the screen locks. Starting Scripture narration pauses
music; choosing Play for music pauses narration. The two player states remain independent of
Activity time. If neither a timer/session nor music service is in use, hide the cluster.

Before the implementation ticket is ready, settle whether one concurrent timer is supported,
manual overlap correction, midnight metric attribution, custom-mode archival/deletion, and
how per-book reading minutes are derived from a cross-book range. Extend Files backup/restore
to Activity data and settings. Do not count app open as study or fabricate per-book allocation.

Owner review: start Reading from a selected verse, pause/resume across tabs and relaunch,
finish at a later verse, verify manual entry and corrections, review local metrics/streaks,
play/change/pause music, lock/background the iPad, and exercise narration/music arbitration.
Also verify a completed Quiz Me session can be associated with a Reviewing record according
to the approved M6/M8 integration policy, without duplicating quiz answers or score data.

### M9: the complete Sophia workflow

Read → annotate → create a note → organize a topic → ask/follow up → inspect sources →
listen → record study activity → relaunch → export/restore. Test representative long content,
VoiceOver, larger text, reduced motion, portrait/landscape, keyboard, narrow windows and
light/dark appearance. Resolve material reliability/usability defects before acceptance.

Owner review: use the connected app for a real study session. This is the full target;
earlier phases are demonstrable increments, not claims that the whole app is finished.

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
| [SP-001](../../tickets/SP-001-product-and-device-decisions.md) | in_progress | M0: owner decisions, full-app UX/architecture review and reviewed next scope |
| [SP-002](../../tickets/SP-002-free-scripture-access.md) | done; research | M0/M1: WEBP baseline and permission matrix; preferred editions conditional, imports not executed |
| [SP-003](../../tickets/SP-003-scripture-ink-layout.md) | done; planning | M1: custom renderer/layout decisions recorded; bounded native proof accepted in SP-008 |
| [SP-004](../../tickets/SP-004-freeform-notes.md) | in_progress | M0/M1: complete editor design for M4, including accepted palette/direct-text expectations |
| [SP-005](../../tickets/SP-005-data-and-quality-contracts.md) | in progress; reader slice complete | Reader slice complete; annotation slice specified for SP-012; Notes/media and full-app recovery still open |
| [SP-006](../../tickets/SP-006-native-canvas-experiment.md) | done; revised acceptance | M1: bounded canvas evidence for M4; remaining checks explicitly deferred to SP-004/005 |
| [SP-007](../../tickets/SP-007-collections-ui-slice.md) | done; bounded prototype | M5: nine simulator checks and two physical UI journeys passed; persistence and cross-feature integration remain deferred |
| [SP-008](../../tickets/SP-008-scripture-layout-validation.md) | done; bounded validation | First M3 ticket: all physical validation criteria owner-reported successful; VoiceOver waived |
| [SP-009](../../tickets/SP-009-first-offline-scripture-reader.md) | done; revised acceptance | M2: offline WEBP reader; owner closure recorded in ticket |
| [SP-010](../../tickets/SP-010-licensed-offline-translations.md) | done; revised acceptance | M2: licensed offline library and development cache exception |
| [SP-011](../../tickets/SP-011-tab-shell-motion.md) | in_progress; physical motion review pending | Shared shell implemented; footer reachability fixed and checked on iPad; physical motion review pending |

| [SP-013](../../tickets/SP-013-freeform-notes.md) | done; owner accepted 2026-10-01 | M4: production Canvas/Page Notes, Scripture quote routing and Notes-only recovery |
| [SP-012](../../tickets/SP-012-persistent-scripture-annotations.md) | in_progress; device acceptance pending | M3: persistent reader layers and annotation-only backup/recovery; automated verification and actual-reader Pencil acceptance |

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
| Product specification | Requirements and open questions drafted | SP-001: review scope/terminology with owner |
| TDD | Corrected planning draft; candidates distinguished from decisions | SP-002–005: replace assumptions with evidence |
| UX specification | Scripture OldPaper direction and seven appearance presets owner-selected; Activity design baseline recorded; some feature visuals remain open | SP-001: review full shared frame and feature journey; SP-004 remaining Notes details; SP-011 shell refinement |
| Screen specifications | OldPaper Scripture, app shell, Notes, Collections, Companion and Activity/background music design recorded | Review Settings flows and feature-specific physical acceptance during implementation |
| Data model and recovery contract | Reader, annotations, Notes and Companion contracts recorded; Collections generation behavior implemented | Extend integrated Files backup/recovery with each selected implementation ticket |
| Integration specification | Scripture/content findings plus SP-016 multi-provider/retrieval boundary recorded | Recheck current official provider APIs and rights before each adapter implementation |
| Test specification/manual cases | Existing feature evidence plus M6 adapter/context/recovery/evaluation targets documented | Convert M6 targets into executable cases with each selected implementation ticket |
| Deployment guide | Personal signing and run guide documented | SP-001/005: signing, selected Xcode, actual simulator/device instructions |
| Architecture decision records and diagrams | Keep diagrams beside decisions in the TDD/design pages; empty diagram files removed | Each spike records alternatives, selected approach, consequences, and evidence |
| Project structure | Current scaffold and proposed boundaries documented | Update when approved implementation changes structure |

2026-09-22 owner feedback: SP-009 now uses continuous chapters, stable compact controls,
horizontal chapter swipes and no duplicate top location title. Earlier M2 pagination
requirements are superseded; M3 fixed continuous geometry is accepted through SP-008; SP-012 implementation is under verification.
