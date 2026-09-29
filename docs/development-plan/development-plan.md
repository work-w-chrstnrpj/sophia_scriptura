# Development Plan — Sophia Scriptura

Revision: 2026-09-29. This is the main phase/progress tracker. Owner-requested roadmap
revision under SP-001; phase outcomes are ready for review, not authorization to code.
Technical intent: [TDD](../tdd/tdd.md). Full scope:
[product specification](../product-specification/product-specification.md).

## Current position and next step

**Current position: SP-009 and SP-010 / M2 are selected and implementation is in progress.**
The offline baseline is WEBP (`engwebp`) USFM; optional translation entitlements remain
conditional. The offline WEBP reader is implemented with acceptance gaps tracked in the SP-009 evidence page. SP-007's nine scoped simulator tests and both
physical-iPad UI journeys passed on 2026-09-21. SP-006 is closed as a
bounded experiment under owner-approved revised acceptance. SP-001 remains in progress for
full-app design review. SP-005 remains in progress for later feature persistence/recovery
contracts; its reader-only identity, storage and restoration slice is accepted.

Confirmed: OldPaper reader UI baseline with seven selected color/type presets; bottom tabs; passage/Version controls with sequential Book → Chapter → Verse navigation;
vertically scrolling Scripture pages; multiple annotation layers and three states;
translation-specific ink with preserved annotated layouts; Reserved writing margin by default;
selectable Scripture typeface; landscape verse-hub popovers; optional two-translation
comparison aligned by canonical verse anchors; stable compact reader controls;
expandable Notes with native Pencil palette, explicit grouping and direct text editing;
nested Collections; four approved Companion presets and contextual follow-ups; human
narration preference; manual tagged Activity with streaks/goals; local Settings and Files
backup/restore with optional reminders. A free base translation is acceptable.

Existing evidence: scaffold, SP-006 sample and native test targets; prior build/unit and
individual UI results are recorded in the [test specification](../testing/test-specification.md).
The owner tried the sample and reported it broadly works, but lacks the expected Pencil
palette. This is not acceptance of all device cases or a completed Notes editor.

**Current owner-selected work:** [SP-009](../../tickets/SP-009-first-offline-scripture-reader.md),
the first M2 product implementation ticket. The reader now has bundled WEBP content,
navigation, continuous native selection, chapter swipes, settings and bottom tabs.
The 2026-09-29 owner-selected UI refinement adds the OldPaper reader/shell and seven
persisted presets with offline fonts; annotation work remains in M3. See [implementation evidence](../testing/sp009-reader-evidence.md)
for automated checks and remaining design/physical acceptance. M2 is not marked complete.
The owner then selected [SP-010](../../tickets/SP-010-licensed-offline-translations.md) for
NIV11, NLT and NKJV under owner-supplied provider approval. Its encrypted offline-library
implementation is complete pending the owner-operated physical download and acceptance.
SP-008 is no longer a required disposable reader prototype: LAYOUT-01–03 move into SP-009,
while its annotation-only LAYOUT-04–09 remain a pre-M3 validation gate.
The implementation does not authorize production persistence, cross-feature routing or a
new feature ticket. SP-004 inherits deferred editor/accessibility cases; SP-005 inherits
production membership, recovery and export verification.

## Path from prototypes to the first usable reader

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
4. **SP-009 — first product slice (in progress):** implement and verify offline reading,
   Book/Chapter/Verse navigation, one available Version, fonts, Copy/Share, the initial
   verse hub and the approved bottom-tab shell in one vertical slice.

The owner then selects that implementation ticket. Do not repeat completed canvas
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
| M2 | Scripture reader | in progress; SP-009/SP-010 selected | Offline WEB reader plus authorized encrypted NIV11/NLT/NKJV download, 30-day lock/renewal, Version control, selection, Copy/Share and initial verse hub | Reader physical acceptance and owner-operated licensed download |
| M3 | Scripture annotations | blocked | Multiple layers, three states, native tools, ruled margin and aligned persistent ink on vertically scrolling pages | M2; demonstrated layout/gesture strategy; ink storage and recovery contract |
| M4 | Freeform Notes | blocked | Blank expandable notes, direct text editing, ink, images, rich objects, grouping, tags, card/list library, passage links and recoverable revisions | M2 passage identity; M1 canvas evidence; accepted note contracts; follows M3 in visible delivery |
| M5 | Collections and full Save flow | blocked | Nested topic folders, shared membership, bookmarks/gleanings/note quotes, attached links, organized verse hub and remove-versus-delete recovery rules | M4 note links and relevant SP-005 membership/deletion contracts |
| M6 | Stateful Companion | blocked | Four approved contexts in working chat; follow-ups, passage Ask, panel/tab continuity, attributed sources and provider configuration | M5 integrated study artifacts; provider/source choice, privacy/context contracts and evaluations |
| M7 | Scripture audio | blocked | Permitted human narration with playback controls and tested interruptions; explicit edition/availability handling | M2 reader and permitted audio source; follows M6 in visible delivery |
| M8 | Activity and habits | blocked | Manual tagged timer, pause/corrections/manual entries, goals, streaks and local analytics | Session/day/goal rules reviewed; follows M7 in visible delivery |
| M9 | Integrated acceptance and refinement | pending | Owner-approved complete study journey, recovery drill, accessibility/performance evidence and resolved material defects | M2–M8 acceptance |

M2–M8 are feature phases, not ticket numbers. SP-009 is the first M2 implementation
ticket; later feature tickets have not been created yet. Draft only the next useful batch when designs and inputs are
stable. Engineering dependencies may introduce shared infrastructure early, but this
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
Pencil palette and finger navigation. The margin toggle reserves space when hidden. Ink
is separate per translation; annotated layouts preserve geometry rather than silently
rewrapping strokes. Review accessible reading-view transitions and page boundaries.

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

Integrate one chosen provider and accessible retrieval sources. Send the approved shared
foundation and selected preset on each request. Save conversations locally; preserve
follow-up passage/argument context, corrections and panel/tab/relaunch continuity. Manage
context limits without promising perfect recall or importing unrelated chats implicitly.

Evaluate all four presets for attribution, uncertainty, contested views, fabricated-source
avoidance and appropriate tone. Test unavailable retrieval, offline behavior, errors,
partial replies and retries. Confirm what leaves the device, Keychain handling, instruction
snapshot/version behavior and export exclusions. Add actual conversations to hub/Collections.
Prompt approval alone does not satisfy this phase.

Owner review: one multi-turn study conversation in each mode, including a clarification,
a reopened conversation and a source inspection. No provider purchase is implicitly authorized.

### M7: narrated Scripture

Verify human narration availability and usage rights before promising an edition or offline
download. Implement listening controls and edition attribution, then test chapter completion,
background/screen-lock behavior, interruptions and coexistence with annotation states.
Synchronization depends on available timing information. TTS is not a silent replacement
for the preferred human narration; propose an alternative if narration access is blocked.

Owner review: listen while reading/writing and recover from interruptions.

### M8: manual study activity

Set activity-type tags and explicit goals. Define which sessions qualify for streaks,
timezones/day boundaries, overlap, pause/resume and manual corrections before coding.
Implement tagged sessions, goal/streak feedback and meaningful local analytics. Do not
count merely opening the app as study or introduce automatic tracking without a decision.
Extend export/restore to activity history and goal settings.

Owner review: create, pause, finish and correct sessions, then verify totals and streaks.

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
M3/M4, provider/preset configuration in M6, listening in M7 and goals in M8. No Sophia login.
Files backup/restore is designed in SP-005 and verified before relying on irreplaceable
study content; M3 is the latest first durable annotation checkpoint. Extend it with every
new data type and offer optional reminders. Do not postpone data safety until M9.

## Existing tickets and their role

| Ticket | Status | Phase contribution / next evidence |
| --- | --- | --- |
| [SP-001](../../tickets/SP-001-product-and-device-decisions.md) | in_progress | M0: owner decisions, full-app UX/architecture review and reviewed next scope |
| [SP-002](../../tickets/SP-002-free-scripture-access.md) | done; research | M0/M1: WEBP baseline and permission matrix; preferred editions conditional, imports not executed |
| [SP-003](../../tickets/SP-003-scripture-ink-layout.md) | done; planning | M1: custom renderer/layout decisions recorded; native proof remains draft SP-008 |
| [SP-004](../../tickets/SP-004-freeform-notes.md) | in_progress | M0/M1: complete editor design for M4, including accepted palette/direct-text expectations |
| [SP-005](../../tickets/SP-005-data-and-quality-contracts.md) | in progress; reader slice complete | M1 contracts refined per feature; reader identity/storage/restore accepted, later feature contracts still open |
| [SP-006](../../tickets/SP-006-native-canvas-experiment.md) | done; revised acceptance | M1: bounded canvas evidence for M4; remaining checks explicitly deferred to SP-004/005 |
| [SP-007](../../tickets/SP-007-collections-ui-slice.md) | done; bounded prototype | M5: nine simulator checks and two physical UI journeys passed; persistence and cross-feature integration remain deferred |
| [SP-008](../../tickets/SP-008-scripture-layout-validation.md) | split; annotation gate not selected | LAYOUT-01–03 absorbed by SP-009; LAYOUT-04–09 remain bounded pre-M3 native validation |
| [SP-009](../../tickets/SP-009-first-offline-scripture-reader.md) | in progress | M2: first actual product slice, an offline WEBP Scripture reader |

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
| UX specification | Scripture OldPaper direction and seven appearance presets owner-selected; other feature screens and shared shell detail remain design work | SP-001: review full shared frame and feature journey; SP-004 remaining Notes details; SP-008 native reader validation when selected |
| Screen specifications | OldPaper Scripture direction is selected; App shell, detailed Scripture interactions, Notes and Collections still have proposed details | SP-001: review shared frame, accessibility and current detail; then design Companion, Activity and Settings |
| Data model and recovery contract | Reader contract accepted; later Notes/ink/media, membership and full backup contracts remain open | SP-009 implementation; later SP-005 feature slices |
| Integration specification | SP-002 findings in TDD §8 and `docs/integrations/scripture-content.md` | Import implementation and optional provider entitlements; later Companion planning |
| Test specification/manual cases | SP-006 evidence plus twelve reader data cases and SP-009 acceptance plan documented | Execute with SP-009; add later feature recovery cases in SP-005 |
| Deployment guide | Personal signing and run guide documented | SP-001/005: signing, selected Xcode, actual simulator/device instructions |
| Architecture decision records and diagrams | Keep diagrams beside decisions in the TDD/design pages; empty diagram files removed | Each spike records alternatives, selected approach, consequences, and evidence |
| Project structure | Current scaffold and proposed boundaries documented | Update when approved implementation changes structure |

2026-09-22 owner feedback: SP-009 now uses continuous chapters, stable compact controls,
horizontal chapter swipes and no duplicate top location title. Earlier M2 pagination
requirements are superseded; M3 annotation geometry remains a future decision.
