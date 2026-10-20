# Product Specification — Sophia Scriptura

Status: personal-use closure recorded **2026-10-04**. The owner verified the implemented
app on physical iPad (**all pass**). Milestones M0–M9 are closed in the
[development plan](../development-plan/development-plan.md). **M7 Scripture audio is
abandoned** at that checkpoint; later owner-selected SP-039 adds AO narration.
Source reconciliation: **2026-10-18**, v1.3.2/build 27 including SP-048 work.
The requirement statuses below describe intent/approval, while the feature map records
implemented behavior separately from outstanding acceptance. Source code remains the
implementation truth.
Technical intent lives in the [TDD](../tdd/tdd.md).

## Purpose and confirmed context

A premium personal iPad Bible-study workspace, built for the owner's local use and
learning of native Apple development, for the glory of God. Reading, handwriting,
notes, collections, conversation, audio, and reading activity should work together.
The owner has Python, Java, React, batch-processing, and web-service experience.

Confirmed in this conversation:

- Device: iPad A16. Owner reports iPadOS 26.6.2 and an Apple Pencil that is not Pro;
  USB-C versus first-generation Pencil has not been identified.
- Xcode 26.6 and simulator/device builds were verified. The owner has tried the native
  canvas experiment on iPad; this does not establish complete feature acceptance.
- Notes must allow free placement of text boxes, ink, and images like OneNote.
- Bible content should prioritize free options; preferred editions are NIV, NLT,
  NKJV, or ESV. Payment and complete offline access to those editions are not assumed.
- After the interactive comparison, the owner selected expandable canvas for Notes.
- On 2026-10-01, after testing the installed Notes build, the owner requested a plan for
  separate Canvas and Page note types, then selected the plan for implementation. The
  two-type implementation supersedes the single-editor model; Prayer and Journal were
  subsequently added. The dated SP-013 and later ticket evidence governs physical acceptance.
- The owner accepted explicit grouping: text and handwriting remain independent until
  deliberately grouped, then move together.
- Planning, understandable architecture, documentation, traceable tickets, and physical
  iPad testing precede feature implementation.

## Owner questionnaire decisions — 2026-09-16

These answers refine the full design; they do not authorize feature implementation.
The questionnaire numbers Q1–Q12 below are distinct from requirement and D-decision IDs.

| Answer | Confirmed direction | Still to specify |
| --- | --- | --- |
| Q1 | OldPaper reader design and seven named palette/type pairings, recorded in the [Scripture screen specification](../design/scripture-screen-specification.md#owner-selected-oldpaper-design-and-presets--2026-09-29) | Final system tokens, platform font packaging, dark/light behavior, accessibility validation and full feature-screen review |
| Q2 | Owner-revised Margin: blank writing space around all sides of the centered Scripture; viewport expansion/crop preserves ink; Read Hidden restores the normal reader | Page dimensions and narrow-window behavior |
| Q3 | Separate handwriting per translation | Page/layout identity and reference mapping; no automatic transfer of strokes |
| Q4 | Each annotation layer captures its preset/typeface, size and spatial layout; selecting it restores that appearance. Read Hidden remains the ordinary reader. | Physical validation of font changes with existing ink, rotation and narrow windows |
| Q5 | Owner-created topics first; nested collection folders; one item can belong to several collections without duplication | Nesting constraints and deletion rules; curated topical index optional |
| Q6 | Bookmark = passage to revisit; gleaning = passage with a short insight; note quote = Scripture inserted into a Canvas object or Page body. Keep source quotation intact and edit commentary separately | Save dialog, collection placement, licensed quotation limits |
| Q7 | Plain Notes background by default, ruled/grid options; stacked cards by default with list option; direct text editing in Canvas text objects and Page body | Editing gestures, resizing, keyboard behavior; current prototype sheet is not the final editor |
| Q8 | Owner supplied Biblical Studies and Christian Living samples and approved the refined shared foundation and both presets | Saved in shared/prompt-presets.seed.json; Apologetics/Tough Questions refinements also approved; runtime implemented, behavioral evaluations remain open; no specific confession or source whitelist selected |
| Q9 | Explicit online Companion use with selected passages/questions and online source retrieval; verified sources where available. Spending is not a major constraint | Provider/model, source access, privacy and cost controls; no numeric ceiling or purchase authorization given |
| Q10 | Manually started timer; Reading, Studying, Contemplating, Journaling and Memorizing Verses plus custom modes; pause/resume/correction; optional automatic Reading routes to Scripture and records one continuous start-to-end range; a separate Scripture Contemplation section retains an optional guided journey; streaks and goals | 10 active minutes is the default goal and streak threshold; overlap, simultaneous timers, midnight attribution, custom-mode removal and per-book time allocation remain open |
| Q11 | Local Settings, no Sophia login; export/import through Files and optional backup reminders | Reminder timing and archive/recovery contract; no cloud sync selected |
| Q12 | Preferred sequence: Scripture → annotations → Notes → Collections → Companion → audio → Activity. Free base translation accepted; human narration preferred | Exact base edition, narrated content rights and release-level acceptance; TTS is not an approved substitute for human narration |

The owner's useful-app expectation spans the connected feature set above. The earlier
reader-plus-note slice from the superseded roadmap is only an internal checkpoint, not the agreed finished useful
product. Technical dependencies may require shared infrastructure earlier than its visible
feature; explain those dependencies without silently changing owner priorities.

## Requirements and acceptance intent

IDs remain stable when wording is refined. Confirmed means requested by the owner;
proposed means an assistant recommendation awaiting review. These labels are approval
states, not implementation or test results; see the current feature map below.

| ID | Status | Requirement | Acceptance intent |
| --- | --- | --- | --- |
| REQ-001 | Confirmed | Personal iPad study workspace | A bottom tab bar connects Scripture, Collections, Notes, Companion, Activity, and Settings; primary tabs must not appear at the top. |
| REQ-002 | Confirmed | Free-first Bible access | No paid content subscription is required for the first usable reader; preferred editions are evaluated without promising availability. |
| REQ-003 | Proposed | Complete offline base edition | Bundled Scripture opens after a cold launch in airplane mode without account setup; identify the edition visibly. SP-009 implements the bundled WEBP (`engwebp`) SQLite reader and importer validation; historical acceptance is recorded in its evidence page. |
| REQ-004 | Confirmed | Verse and chapter hub | A passage shows linked notes, conversations, saved Scripture, links, and collection memberships; selecting an item opens it. |
| REQ-005 | Confirmed; refined 2026-10-02 | Copy, Ask, Original Language Analysis, Save, Share | Text selection retains the selected passage and source edition; Ask links a general conversation; Original Language Analysis opens a structured Hebrew/Aramaic/Koine Greek contextual analysis draft; Save offers the requested save types. |
| REQ-006 | Confirmed | Scripture annotation layers | Multiple empty transparent layers; at most one visible. Confirmed states: Read Hidden, Read Visible (no drawing), Draw (native palette, finger navigation, text selection/verse taps paused, existing audio can continue). Optional blank writing space around centered Scripture. |
| REQ-007 | Proposed | Reliable spatial ink | Version switches and layout changes never silently place existing ink over different words; save/reopen preserves alignment. |
| REQ-008 | Confirmed | Freeform Notes on an expandable canvas | Place text boxes, handwriting, and images freely on a canvas that can grow; edit and reopen the note with those positions preserved. A linear block editor alone fails acceptance. |
| REQ-009 | Confirmed | Rich note content | Support link cards, tables, quotations, shapes, and bulleted/numbered text; manage tags, title/date sorting, and card/list views. |
| REQ-010 | Confirmed | Collections | Folder-like collections group notes, conversations, passages, and links. Support nested topic folders and multiple memberships without duplicating items. |
| REQ-011 | Confirmed | Contextual Companion | Scripture selection opens a passage-linked conversation; closing or expanding its panel preserves that conversation and draft. |
| REQ-012 | Confirmed | Theological prompt presets | Every new conversation uses reviewed instructions for Biblical Studies, Christian Living, Apologetics, or Difficult Questions; present tradition differences where relevant. |
| REQ-013 | Proposed | Evidence-aware AI | Distinguish retrieved evidence from unverified recollection; no invented citations, claimed searches without retrieval, or claims of divine authority. |
| REQ-014 | Confirmed | Scripture audio | Provide play/pause and chapter listening where access permits; human narration is preferred; exact editions, voices, rights and synchronization remain open. |
| REQ-015 | Confirmed; refined 2026-10-01 | Activity tracking | Start/pause/resume/finish a Reading, Studying, Contemplating, Journaling, Memorizing Verses or custom-mode session; timer duration excludes paused intervals. Settings independently controls automatic Reading and Scripture Contemplation workflows. With Reading enabled, select a start reference, open Scripture with a fading highlight, and select an end reference at finish; when disabled, start a timer without a passage requirement. Manual records require title, mode, date and duration; optional start/end times auto-compute duration. Show local metrics, streaks and goals. See the Activity design for unresolved overlap, concurrency, midnight and per-book allocation rules. |
| REQ-016 | Confirmed | Accessible, organized, premium experience | Define and manually verify readable layouts, discoverable controls, clear grouping, and accessibility across the main flows. |
| REQ-017 | Proposed | Data durability | Autosave, undo, and export/restore preserve notes, media, ink, links, and collections; failed import leaves intact data usable. |
| REQ-018 | Confirmed | Implementation traceability | Each ready ticket links requirements, design, dependencies, acceptance criteria, tests, and required documentation changes. |
| REQ-019 | Proposed | Local privacy with explicit online features | Persist study locally; keep secrets out of exports/logs; disclose which selected context goes to a configured AI provider. |
| REQ-020 | Proposed | Search and continuity | Find Scripture and study material; reopen the last reading position without losing note or conversation drafts. |
| REQ-021 | Confirmed by subsequent feedback | Native Pencil tool palette | Drawing offers the familiar native Pencil tool picker; supported tools, erasing, selection and navigation are specified and tested. The SP-006 pen/eraser buttons do not fulfill this expectation. |
| REQ-022 | Confirmed intent; details proposed | Settings and Account decision | Local Settings without Sophia login; theme/font preferences, Files export/import and optional backup reminders. Detailed controls remain to design. |
| REQ-023 | Confirmed | Translation variety and topic study | Aim for word-for-word, thought-for-thought and paraphrase reading options subject to access; passages can be gathered by topic. Owner-created topics first; a curated topical index remains optional. |
| REQ-024 | Confirmed | Contextual follow-up conversations | Follow-up questions and clarifications use the current conversation's messages, passage and preset; reopening or moving panel/tab preserves the conversation. No automatic cross-conversation memory is assumed. Long-chat context limits must not be represented as perfect recall. |
| REQ-025 | Confirmed and refined 2026-10-02 | Companion Quiz Me | Launch structured quizzes from Companion with provider-generated questions, answer keys and cited references plus local attempts, answers, explanations and scores. Identify the Reference is replaced by Bible Quiz; Bible or False is added. Prepare 10 Easy, 5 Average and 3 Difficult questions per type locally and replenish consumed questions in-app. Easy, Average and Difficult use distinct prompt rubrics. Optional per-question timers and an automatic Studying record follow the approved Companion design. AI provenance is disclosed because structural validation does not independently prove factual correctness. |

## Full-design reconciliation — review baseline

This section traces the initial brief plus later owner decisions. It describes the full
product, not a reduced first release. Milestone assignments below follow the revised M0–M9 roadmap and remain reviewable
planning boundaries, not authorization to execute. Existing SP tickets own planning/feasibility;
they are not substitutes for future feature implementation tickets.

The six tabs now contain implemented study workflows. SP-006 remains a separate DEBUG
experiment. The states below reflect the source reviewed on 2026-10-18; they do not
claim that every original requirement or device/provider acceptance case is complete.

### Scripture and the connected study workflow

| Requested capability / IDs | Intended interaction | Current state and unresolved detail | Proposed placement / planning owner |
| --- | --- | --- | --- |
| Bible reader, many versions (002, 003, 023) | Use a Book/Chapter control with verse navigation and a separate Version selector, as requested with YouVersion as the interaction reference; preserve passage position when switching. Include different translation approaches where permitted. | Implemented: bundled WEBP, API.Bible NASB/NLT/NKJV and eligible Hello AO downloads through the shared reader. ESV remains SP-032 draft; licensed rights/acceptance remain source-specific. | M2; later permitted editions separately scoped; SP-002/003 |
| Topic-grouped passages (010, 023) | Gather passages under a study topic and revisit them together. | Implemented through persisted nested Collections and shared memberships. Curated topical indexes remain separate scope. | M5; curated index optional; SP-001/002 |
| Transparent annotation layers (006, 007) | Choose among multiple empty-by-default layers; use Read Hidden, Read Visible or Draw; retain hidden content. | SP-012 implemented and owner-accepted on the iPad, including Pencil writing and annotation recovery. | M3; SP-012 |
| Extended annotation area (006) | Turn on blank writing space around Scripture and freely pan/zoom. | SP-012 revised implementation: centered column, surrounding blank space, normal Hidden reader, autosave and palette closure; owner accepted physical behavior on 2026-10-03. | M3; SP-003/008 |
| Chapter/verse hub (004) | Verse numbers open Verse Hub. The labeled Chapter icon button in the annotation/actions row opens Chapter Hub with only Links, Chapter Conversations and Verse Conversations. | SP-023 adds edition-specific chapter aggregation, numeric verse ordering and distinct reference-only chapter chats. Existing verse artifacts are reused, not copied. | M2/M5/M6 follow-up; SP-023 |
| Copy and Share (005) | Select Scripture; copy the text or open system sharing with its reference and edition. | Implemented through the native reader selection actions and source-specific quotation authorization. Provider permission is not inferred from text selection. | M2; SP-002/003 |
| Ask (005, 011) | Selection Ask and Verse Hub Start conversation open blank composers with authorized full involved verse context; the owner supplies the question. Chapter Ask uses only the chapter reference/translation. | SP-023 places context beside the question in the outgoing request while preserving exact saved user wording. Model factual/answer quality requires owner verification. | M6 follow-up; SP-023 |
| Save as gleaning/bookmark/note (005) | Select Scripture → Save → choose a collection and/or save type; note quote can be followed by editable commentary. | Implemented: bookmark/gleaning save sheets and note destinations retain source identity. SP-046 adds Bookmark → Gleaning and Gleaning → Note. | M4 note quote; M5 full Save flow; SP-001/005 |
| Cross-version ink (007) | Switching versions must not put handwriting over unrelated words; return to a version to find its marks. | SP-012 persists separate edition/chapter/layer layouts; changing editions does not migrate ink. Later physical regressions remain ticket-specific. | M1 feasibility → M3; SP-003/005/008 |
| Audio Bible (014) | Start/pause chapter listening while reading. | Original M7 abandoned on 2026-10-04; SP-039 later implements AO narration, playback controls, bounded media storage and validated timing. ESV audio remains draft SP-032. | Formerly M7 |

### Collections and Notes

| Requested capability / IDs | Intended interaction | Current state and unresolved detail | Proposed placement / planning owner |
| --- | --- | --- | --- |
| Folder-like collections (010) | Open a topic folder containing related notes, conversations, passages and links. | Implemented: persisted nested folders/shared memberships, Trash/archive, access locks, Smart Order, folder moves/copies, Points to Ponder, link editing and material drops. See the [Collections specification](../design/collections-screen-specification.md) and SP-040/044–047. | M5 with M6 conversation integration; SP-001/005 |
| Canvas and Page Notes (008; owner-selected 2026-10-01) | Create either an object-based Canvas with movable ink and link cards, or a flowing Page with fixed ink above text and inline links. Hide/show Scripture while retaining reader position. | SP-013 now implements both types with Scribble suppression, native inking/eraser tools, inline Page images/tables and persistent Scripture visibility. Physical Pencil acceptance is pending after failures in the previous installed build. SP-006 remains separate. | M4; SP-013 |
| Explicit grouping (008) | Objects stay independent until selected and grouped; move a group together, then ungroup without changing content. | SP-013 implements flat groups, move/ungroup, object resize and stacking. Native lasso selects strokes within one ink object; physical behavior is unverified. | M4; SP-013 |
| Native drawing palette (021) | Use the supported native inking and eraser tools; Pencil always draws in Notes regardless of Scribble setting. | Production Notes and Scripture integrate native PencilKit tools; SP-014 adds shared stroke refinement and SP-025 adds compound-ink/stroke editing. Physical Pencil regressions remain device checks. | M3 Scripture and M4 Notes; SP-012/013 |
| Images, link cards, tables, quotes, shapes, lists (009) | Canvas uses movable cards/objects; Page uses inline links and citations, with inline images and tables. | SP-013 provides Files images, bounded tables, URL cards, one shape and text lists on Canvas. Page images/tables flow inline and URLs are normal links. Old Page floating objects remain intact. | M4; SP-013 |
| Tags, sort and views (009) | Group/filter notes by tag; sort by title/date; switch stacked cards and a normal list. | SP-013 implements tags, one-tag filtering, title/created/modified sort and card/list views. Multi-tag filters remain open. | M4; SP-013 |
| Verse-linked notes (004, 008) | Quote or attach a passage in a note; find the same note again from its verse hub and collection. | Authorized translation quotes reopen the same note; persisted Collections memberships and shared note destinations implement the M5 Save flow. | M4/M5; SP-013 and later membership ticket |

### Companion

| Requested capability / IDs | Intended interaction | Current state and unresolved detail | Proposed placement / planning owner |
| --- | --- | --- | --- |
| Chat-style Companion tab (011, 024) | Familiar conversational interface with a conversation list, messages and input. Each chat pins a BYOK provider/model and preserves local context. | Implemented: multi-provider BYOK, persisted conversation/message history, explicit selected context, source inspection, retry/failure states and panel/tab continuity. See the [Companion design](../design/companion-screen-specification.md). | M6; SP-016 planning done; bounded implementation ticket required |
| Quiz Me (025) | Start a structured quiz in Companion, answer one question at a time, see correctness and explanation, continue, and review the final score and saved question history. | Identify the Reference is removed as duplicative; Bible Quiz and Bible or False are available. The selected provider prepares cached questions with distinct difficulty bands. Warm sessions start locally and consumed questions trigger in-app refill. The app rejects malformed and duplicate output and discloses AI-authored keys; factual and semantic-quality evaluation remains required. | M6 Companion implementation and provider evaluation |
| Scripture panel and expansion (011) | Open beside Scripture, close it, or expand into Companion without losing conversation, draft or passage context. | Implemented in CompanionScripturePanel and the shared CompanionSession; panel/tab routes retain conversation and draft ownership. | M6; SP-003/005 |
| Four presets (012) | Choose Biblical Studies, Christian Living, Apologetics or Difficult Questions; preconfigured instructions accompany each conversation. | Implemented: bundled owner-approved presets resolve the shared guardrail into conversation snapshots; request composition includes the instruction on follow-ups. Theological/live-provider evaluation remains open. | M0 wording approved → M6 runtime/evaluation |
| Study method and theological foundation (012, 013) | Answer through historic orthodox Christianity with careful interpretation and relevant supporting sources. | See the complete brief below. Preset/context runtime and capability-dependent retrieval exist; factual/theological quality remains an acceptance gate, not a guarantee from the prompt. | M0 foundation → M6 behavior |
| References and research (012, 013) | Name authors/works and provide references for further reading; distinguish traditions when relevant. | Implemented: authorized local context, source inspection/provenance and capability-dependent provider retrieval. Generated references are not evidence of verified retrieval. Rights and factual-quality evaluation remain separate. | M6; SP-002 rights and SP-016 Companion contracts |

The owner's theological brief is preserved as these requirements for prompt review:

- Historic orthodox Christian conviction, not an assumption that “orthodox” means only
  the Eastern Orthodox Church; pursuit of truth rather than pleasing answers.
- Sound hermeneutics and exegesis; let Scripture interpret Scripture.
- Historical/cultural context and the principle “written for us, but not to us.”
- Hebrew, Aramaic or Koine Greek analysis when it materially clarifies the passage.
- Relevant cross-references, prophecy/fulfillment, foreshadowing and recurring patterns
  within the Bible's unified story leading to Jesus; avoid forced connections.
- Relevant Protestant interpretations aligned with the owner's five-Solas criterion,
  Roman Catholic and Eastern Orthodox interpretations, clearly attributed. The precise
  inclusion criteria and handling of contested teachings require owner review.
- Draw on appropriate commentaries, journals/articles, theologians, biblical scholars,
  pastors/preachers, apologists, philosophers and Church Fathers; name proponents and works.
- Compile references in APA style; respect requests for concision without sacrificing
  important context. “Search all available materials” is an aspiration, not a capability
  a prompt alone can provide or a claim the app can honestly make.
- Respect the owner's belief in truth revealed by the Holy Spirit. The proposed software
  guardrail is to avoid presenting AI output as revelation or divine authority; theological
  grounding and human discernment remain distinct from model-generated responses.

### Activity, Settings, and quality throughout the app

| Requested capability / IDs | Intended interaction | Current state and unresolved detail | Proposed placement / planning owner |
| --- | --- | --- | --- |
| Study sessions (015) | Start a built-in or custom mode; pause/resume/finish; with the Reading workflow enabled, select a start passage, read with a fading verse focus, then select the last verse. Reading and Scripture Contemplation can instead start plain timers through independent Settings choices. Manually enter title, mode, date and duration, with optional clock times. Quiz Me contributes Studying time; legacy Reviewing records and goals migrate to Studying. Scripture Contemplation has a separate Activity section. | Implemented (SP-020/022). Owner verified 2026-10-04. | M8 closed |
| Analytics (015) | Review daily/weekly/monthly minutes, time by mode, goal progress, streaks and reading records by book. | Implemented locally (SP-020). Owner verified 2026-10-04. Cross-book per-book minutes are not inferred. | M8 closed |
| Background music | Settings FAB starts/pauses human-composed instrumental ambient lo-fi; control playback and change track from the shared shell; collapse controls while studying. | Implemented (SP-021) with integration placeholder tracks; owner verified 2026-10-04. Commercial track catalog and rights evidence remain optional follow-up. SP-039 now wires narration/music arbitration through the shared audio coordinator. | M8 closed |
| Theme and font size (016, 022) | Set readable typography and preferred light/dark/system appearance. | Implemented: persisted reader preferences, shared AppTheme and offline fonts. Annotation layers retain their captured spatial layout rather than reflowing stored ink. | M2 baseline in SP-009; feature-specific preferences alongside each phase |
| Further Settings / Account (019, 022) | Review downloads/versions, drawing preferences, AI provider/key/presets, activity goals, export/restore and About/attributions as relevant. | Local Settings without Sophia login and Files backup/reminders approved; further feature settings need detailed review. | M0 decisions; settings staged M2–M8 |
| Accessible and premium (016) | Calm, coherent reading and editing, discoverable actions, readable text, meaningful grouping, responsive Pencil input and clear empty/error states. | Owner verified personal use 2026-10-04 (all pass). Formal VoiceOver certification was waived in earlier milestones and was not rerun at M9 closure. | M9 closed |
| Maintainable and understandable development (018) | Owner understands the architecture, chooses tickets, and receives source/design/test traceability with each result. | Role/skill routing and tickets exist; full product architecture review remains necessary. | Every milestone; SP-001/005 |
| Data safety and local operation (003, 017, 019, 020) | Preserve study locally, recover drafts, export/restore, and make optional network use explicit. | Implemented: reader continuity, feature-owned checked stores/recovery, Keychain BYOK and Files study backup/restore. User music, licensed text and credentials are excluded from full study exports. Network-dependent features remain explicit. | M1 contracts; M2 preferences; M3 ink backup and extensions M4–M8; SP-005 |

### Decisions for owner review

These are design questions, not implementation blockers to resolve by assumption. Owner
chooses product behavior; technical/content feasibility is investigated through tickets.

| Decision | What is requested versus proposed | Why it matters / planning owner |
| --- | --- | --- |
| D-01 Visual direction — confirmed and refined 2026-09-29 | OldPaper is the selected Scripture UI guide and visual baseline; it retains the agreed book-like reading, blank surrounding writing space and restrained Apple-style hierarchy. Seven appearance presets are selected. | Final token values, font packaging, accessibility validation, and detailed Notes/Collections/Companion/Activity/Settings screens remain design work under SP-001/004. See the [Scripture specification](../design/scripture-screen-specification.md#owner-selected-oldpaper-design-and-presets--2026-09-29). |
| D-02 Scripture modes — confirmed 2026-09-16 | Owner accepted multiple layers with three states: Read Hidden, Read Visible and Draw. At most one layer visible. Reading states allow verse taps, selection actions and listening; Draw pauses text actions/verse taps, uses Pencil tools and finger navigation, and permits existing audio to continue. | SP-003 specifies layer/gesture behavior; SP-005/SP-008 own persistence and native proof. This is not implementation authorization. |
| D-03 Translation/topic direction — confirmed | Free base translation acceptable; owner topics first, nested collections and multiple memberships. Curated index optional. | Edition/canon and content rights remain SP-002; collection data contract SP-005. |
| D-04 Save meanings — confirmed | Bookmark for revisiting; gleaning with short insight; note quote in freeform note. Preserve source quote, edit commentary separately. | Save UI and content permissions remain SP-001/002/005 work. |
| D-05 Notes defaults — confirmed | Expandable canvas/grouping/native palette; plain with ruled/grid options, stacked cards/list, direct text editing. | Resizing, rich objects and export geometry remain SP-004 work. |
| D-06 Companion — confirmed planning baseline 2026-10-02 | Selected-context online AI, multiple BYOK provider adapters, local authoritative history, source retrieval and all four preset contexts are approved. Conversations pin provider/model/capability/preset snapshots; provider changes explicitly branch. | OpenAI, Anthropic and Gemini are the intended first adapters, followed by an OpenAI-compatible endpoint. Current API feasibility, exact models, source availability, costs and behavioral evaluations are implementation-ticket work. |
| D-07 Activity — refined and confirmed 2026-10-01 | Built-in modes Reading, Studying, Contemplating, Journaling, Memorizing Verses; custom modes allowed. Timer active duration excludes pauses. When its workflow is enabled, Reading chooses a start reference, routes to Scripture with temporary fading focus, and requires an end reference to record one continuous inclusive range across chapters/books; disconnected passages use separate records. Scripture Contemplation launches its existing guided journey when enabled. Independent Settings choices allow either activity to start only its timer. Manual record requires title, mode, date and duration; optional clock range computes duration. Default goal and qualifying streak threshold are 10 active minutes per local calendar day; completed timed/manual activities count. | SP-020 implementation uses one timer, custom modes in goals, local-midnight splitting, custom-mode archiving and overlap rejection; physical acceptance remains. Per-book minutes are not inferred from a cross-book range. |
| D-14 Background music — refined 2026-10-03 | Human-composed instrumental ambient lo-fi, no vocals; 3–5 verified bundled offline tracks; Play/Pause, Next and Loop using iPad volume; explicit Play takes over from external audio. Continue across tabs, background and screen lock. Starting narration pauses music; choosing Play on music pauses narration. | Owner closed M8 with SP-021 wiring and placeholder catalog 2026-10-04. Verified commercial track rights remain optional. SP-039 implements narration/music arbitration; its acceptance remains separate. |
| D-15 Quiz Me and Studying — refined 2026-10-02 | Quiz Me is a structured Companion mode with provider-generated questions and provisionally graded AI answer keys, local prepared-question cache and history, optional per-question timers and points/percentage results. The cache targets 10/5/3 questions per type and difficulty has explicit semantic bands. Completed Quiz Me sessions automatically contribute Studying time; eligible active time counts toward the normal goal/streak without duplicating quiz data in Activity. | Structural validation is implemented; real-provider factual accuracy, semantic repetition, difficulty quality, device behavior and acceptance evaluation remain. See REQ-025, TDD §12.3 and the Companion design. |
| D-08 Settings/backup — confirmed | No Sophia login; local Settings, Files export/import and optional reminders. | Feature settings, reminder schedule and recovery contract remain open. |
| D-10 Scripture pages — confirmed direction | Owner selected vertical scrolling through bounded Scripture pages, not horizontal page turns or one giant chapter page. | SP-003 specifies preserved page geometry and an independent accessible reading layout; SP-009 owns reader selection proof and SP-008 retains annotation proof. Expandable Notes remains unchanged. |
| D-11 Main navigation — confirmed placement and motion 2026-09-29, revised 2026-10-01 | Owner requested bottom tabs, three-second idle hide with scroll reveal, and sliding/glowing tab transitions. | SP-011 implements a reveal handle, stable content inset and retained tab state; Reduce Motion fades. Keep passage/version controls in the reader header. |
| D-12 Scripture appearance presets — confirmed 2026-09-29 | OldPaper is the base UI. The selected appearance set is OldPaper, Midnight Library, Quiet Sage, Sepia Notes, Royal Ink (formerly Ink and Linen), Tree of Knowledge (renamed from Marginalia), and Spring Leaf (renamed from Stillwater). Each preset selects palette roles and paired Scripture/supporting UI typefaces; OldPaper keeps the current system sans UI face. | Presets change appearance only. Annotation layers and states, translation-specific ink, reading-margin geometry, verse anchoring, and the rest of the agreed workflows remain in scope. Final token/font integration and accessibility validation are outstanding; this decision authorizes documentation, not app implementation. |
| D-13 Two Notes types — selected 2026-10-01 | Separate object-based Canvas from flowing Page with fixed overlaid ink; offer a Scripture-pane visibility toggle. | SP-013 implements the selected plan: Page attachments flow inline, Scripture visibility persists, and Scripture selections route to open/new/existing notes. M4 was owner-accepted. |
| D-09 Preferred delivery sequence — recorded | Scripture → annotations → Notes → Collections → Companion → human-preferred audio → Activity. | Revised M2–M8 follows this order, with M0/M1 planning and M9 integrated acceptance; the earlier small slice is not the full useful-app scope. |

### Reconciliation findings

The earlier docs retained the broad feature list but compressed translation styles/topic
study, blank-note creation, rich-object/library behavior, the complete theological prompt,
and Account/Settings into insufficient detail. The native Pencil palette expectation was
not captured as an explicit requirement until now. Premium quality incorrectly appeared
concentrated in the final milestone. These are now explicit; none is removed to simplify
implementation. The questionnaire confirms the directions recorded above; Companion behavioral evaluation and detailed design/phase review remain pending.

## Vocabulary to review

- Passage: a chapter, verse, or range. Links retain the original edition/reference and
  map to a shared reference when that mapping is known.
- Gleaning: saved passage with a short insight. Bookmark: passage to return to. Note quote: Scripture embedded within a larger note.
- Collection: grouping of existing items. Tag: reusable label for finding/grouping notes.
- Annotation layer: spatial drawing over Scripture. Note canvas: independent study page.
- Premium: calm presentation, consistent controls, responsive input, accessible actions,
  and reliable preservation of study—not a particular color theme or animation style.

## Delivery checkpoints and the full useful-app target

The [revised roadmap](../development-plan/development-plan.md) separates Scripture (M2),
annotations (M3), Notes including rich objects (M4), Collections (M5), stateful Companion
(M6), human-preferred audio (M7) and Activity (M8). M0/M1 establishes design and feasibility;
M9 verifies the complete workflow. Each phase is a demonstrable increment, not a replacement
for the full original design. Durability and premium quality apply throughout.

## Decisions still open

- Companion runtime integration and behavioral evaluation; current models, source
  availability, provider-specific retrieval behavior and concrete cost controls.
- Exact free base edition/canon, preferred-edition rights and human narration access.
- Physical annotation alignment after deliberate font changes, rotation and panel
  resizing; detailed visuals and canvas editing interactions.
- Activity per-book minute allocation, overlapping manual entries, simultaneous timers,
  midnight metric attribution, custom-mode removal/history/streak behavior, and exact
  custom-mode fields. The ten-minute default goal/streak threshold and local-day basis are
  decided.
- Final background-music track selection and whether volume/repeat/shuffle controls belong
  in v1; verify composition and sound-recording rights for each candidate.
- Collection deletion/nesting limits, backup/reminder/recovery details, implementation
  architecture, and review of the revised phase boundaries.
- Exact Pencil model, supported OS baseline and long-term signing preference.

## Scope boundaries

Current target is personal iPad use. No Sophia login is confirmed. No runtime backend remains the architecture proposal;
online provider access is explicit and optional to local study.
App Store distribution, collaboration, Android/web clients, and cloud sync are not
planned. Content-provider accounts may still be needed for online editions. Core local
study must remain usable when an optional online feature is unavailable.

## Collection Plans — proposed extension, 2026-10-19

Planning only; no implementation selected. Add Plan as a Collections material with ordered,
configurably named sections of Scripture assignments, notes and links, editable checkboxes
and scoped resets. A fullscreen focused reader supports Prev/Next, Notes, links, Companion,
background music and Pencil while normal tabs are unavailable. Owner confirmed checked
reflections added while reading, explicit section-summary pauses, and new annotation layers
named after the Plan. Scheduling and public/shared Plans remain outside the first version.
See [design and recommended defaults](../design/collection-plans.md),
[TDD](../tdd/tdd.md#collection-plans--planning-baseline-sp-049052) and
[proposed milestone](../development-plan/development-plan.md#collection-plans--proposed-post-baseline-milestone-2026-10-19).
