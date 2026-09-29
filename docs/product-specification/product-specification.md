# Product Specification — Sophia Scriptura

Status: full-design reconciliation draft, 2026-09-16; owner questionnaire recorded; all four Companion contexts approved; evaluation and detailed design review pending. This document separates user requirements from
proposals. It is not approval to implement unresolved choices. Technical intent lives
in the [TDD](../tdd/tdd.md); work status lives in the [development plan](../development-plan/development-plan.md).

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
| Q2 | One margin toggle for the current reading layout; show beside its pages and reserve the space when hidden to avoid shifting existing marks | Page dimensions and narrow-window behavior |
| Q3 | Separate handwriting per translation | Page/layout identity and reference mapping; no automatic transfer of strokes |
| Q4 | Preserve the original annotated layout; separately adjustable reading view accepted with the recommendation | How to switch/access saved layouts; accessible font-size and rotation behavior |
| Q5 | Owner-created topics first; nested collection folders; one item can belong to several collections without duplication | Nesting constraints and deletion rules; curated topical index optional |
| Q6 | Bookmark = passage to revisit; gleaning = passage with a short insight; note quote = Scripture inserted into a freeform note. Keep source quotation intact and edit commentary separately | Save dialog, collection placement, licensed quotation limits |
| Q7 | Plain Notes background by default, ruled/grid options; stacked cards by default with list option; edit text directly on canvas | Editing gestures, resizing, keyboard behavior; current prototype sheet is not the final editor |
| Q8 | Owner supplied Biblical Studies and Christian Living samples and approved the refined shared foundation and both presets | Saved in shared/prompt-presets.seed.json; Apologetics/Tough Questions refinements also approved; runtime and evaluations remain pending; no specific confession or source whitelist selected |
| Q9 | Explicit online Companion use with selected passages/questions and online source retrieval; verified sources where available. Spending is not a major constraint | Provider/model, source access, privacy and cost controls; no numeric ceiling or purchase authorization given |
| Q10 | Manually triggered study timer with activity-type tags, streaks and goals; pause/resume and corrections through the accepted recommendation | Goal units, qualifying day, timezone, overlaps and activity categories; no automatic tracking selected |
| Q11 | Local Settings, no Sophia login; export/import through Files and optional backup reminders | Reminder timing and archive/recovery contract; no cloud sync selected |
| Q12 | Preferred sequence: Scripture → annotations → Notes → Collections → Companion → audio → Activity. Free base translation accepted; human narration preferred | Exact base edition, narrated content rights and release-level acceptance; TTS is not an approved substitute for human narration |

The owner's useful-app expectation spans the connected feature set above. The earlier
reader-plus-note slice from the superseded roadmap is only an internal checkpoint, not the agreed finished useful
product. Technical dependencies may require shared infrastructure earlier than its visible
feature; explain those dependencies without silently changing owner priorities.

## Requirements and acceptance intent

IDs remain stable when wording is refined. Confirmed means requested by the owner;
proposed means an assistant recommendation awaiting review. None is marked implemented.

| ID | Status | Requirement | Acceptance intent |
| --- | --- | --- | --- |
| REQ-001 | Confirmed | Personal iPad study workspace | A bottom tab bar connects Scripture, Collections, Notes, Companion, Activity, and Settings; primary tabs must not appear at the top. |
| REQ-002 | Confirmed | Free-first Bible access | No paid content subscription is required for the first usable reader; preferred editions are evaluated without promising availability. |
| REQ-003 | Proposed | Complete offline base edition | Bundled Scripture opens after a cold launch in airplane mode without account setup; identify the edition visibly. SP-002 selects WEBP (`engwebp`) USFM as the planning baseline; import/runtime validation remains pending. |
| REQ-004 | Confirmed | Verse and chapter hub | A passage shows linked notes, conversations, saved Scripture, links, and collection memberships; selecting an item opens it. |
| REQ-005 | Confirmed | Copy, Ask, Save, Share | Text selection retains the selected passage and source edition; Ask links a conversation; Save offers the requested save types. |
| REQ-006 | Confirmed | Scripture annotation layers | Multiple empty transparent layers; at most one visible. Confirmed states: Read Hidden, Read Visible (no drawing), Draw (native palette, finger navigation, text selection/verse taps paused, existing audio can continue). Optional ruled area beside Scripture. |
| REQ-007 | Proposed | Reliable spatial ink | Version switches and layout changes never silently place existing ink over different words; save/reopen preserves alignment. |
| REQ-008 | Confirmed | Freeform Notes on an expandable canvas | Place text boxes, handwriting, and images freely on a canvas that can grow; edit and reopen the note with those positions preserved. A linear block editor alone fails acceptance. |
| REQ-009 | Confirmed | Rich note content | Support link cards, tables, quotations, shapes, and bulleted/numbered text; manage tags, title/date sorting, and card/list views. |
| REQ-010 | Confirmed | Collections | Folder-like collections group notes, conversations, passages, and links. Support nested topic folders and multiple memberships without duplicating items. |
| REQ-011 | Confirmed | Contextual Companion | Scripture selection opens a passage-linked conversation; closing or expanding its panel preserves that conversation and draft. |
| REQ-012 | Confirmed | Theological prompt presets | Every new conversation uses reviewed instructions for Biblical Studies, Christian Living, Apologetics, or Difficult Questions; present tradition differences where relevant. |
| REQ-013 | Proposed | Evidence-aware AI | Distinguish retrieved evidence from unverified recollection; no invented citations, claimed searches without retrieval, or claims of divine authority. |
| REQ-014 | Confirmed | Scripture audio | Provide play/pause and chapter listening where access permits; human narration is preferred; exact editions, voices, rights and synchronization remain open. |
| REQ-015 | Confirmed | Activity tracking | Manually start/finish a timer, tag the activity type, enter/correct sessions, and inspect local analytics with streaks and goals. Define pause, overlap, day boundaries, and listening treatment before implementation. |
| REQ-016 | Confirmed | Accessible, organized, premium experience | Define and manually verify readable layouts, discoverable controls, clear grouping, and accessibility across the main flows. |
| REQ-017 | Proposed | Data durability | Autosave, undo, and export/restore preserve notes, media, ink, links, and collections; failed import leaves intact data usable. |
| REQ-018 | Confirmed | Implementation traceability | Each ready ticket links requirements, design, dependencies, acceptance criteria, tests, and required documentation changes. |
| REQ-019 | Proposed | Local privacy with explicit online features | Persist study locally; keep secrets out of exports/logs; disclose which selected context goes to a configured AI provider. |
| REQ-020 | Proposed | Search and continuity | Find Scripture and study material; reopen the last reading position without losing note or conversation drafts. |
| REQ-021 | Confirmed by subsequent feedback | Native Pencil tool palette | Drawing offers the familiar native Pencil tool picker; supported tools, erasing, selection and navigation are specified and tested. The SP-006 pen/eraser buttons do not fulfill this expectation. |
| REQ-022 | Confirmed intent; details proposed | Settings and Account decision | Local Settings without Sophia login; theme/font preferences, Files export/import and optional backup reminders. Detailed controls remain to design. |
| REQ-023 | Confirmed | Translation variety and topic study | Aim for word-for-word, thought-for-thought and paraphrase reading options subject to access; passages can be gathered by topic. Owner-created topics first; a curated topical index remains optional. |
| REQ-024 | Confirmed | Contextual follow-up conversations | Follow-up questions and clarifications use the current conversation's messages, passage and preset; reopening or moving panel/tab preserves the conversation. No automatic cross-conversation memory is assumed. Long-chat context limits must not be represented as perfect recall. |

## Full-design reconciliation — review baseline

This section traces the initial brief plus later owner decisions. It describes the full
product, not a reduced first release. Milestone assignments below follow the revised M0–M9 roadmap and remain reviewable
planning boundaries, not authorization to execute. Existing SP tickets own planning/feasibility;
they are not substitutes for future feature implementation tickets.

Current implementation is the six-tab scaffold and SP-006 sample canvas. “Not implemented”
below means no working feature is established; a placeholder tab is not feature completion.

### Scripture and the connected study workflow

| Requested capability / IDs | Intended interaction | Current state and unresolved detail | Proposed placement / planning owner |
| --- | --- | --- | --- |
| Bible reader, many versions (002, 003, 023) | Use a Book/Chapter control with verse navigation and a separate Version selector, as requested with YouVersion as the interaction reference; preserve passage position when switching. Include different translation approaches where permitted. | Not implemented. Free edition, canon, preferred-edition access and offline rights need decisions. No NIV/NLT/NKJV/ESV availability promise. | M2; later permitted editions separately scoped; SP-002/003 |
| Topic-grouped passages (010, 023) | Gather passages under a study topic and revisit them together. | Not implemented. User collections can support this; curated topical indexes are a separate undecided scope. | M5; curated index optional; SP-001/002 |
| Transparent annotation layers (006, 007) | Choose among multiple empty-by-default layers; use Read Hidden, Read Visible or Draw; retain hidden content. | Not implemented. SP-003 specifies lifecycle, state transitions and page-local history; storage/native validation remain SP-005/SP-008. | M1 feasibility → M3; SP-003/005/008 |
| Extended annotation area (006) | Turn on a ruled writing area to the right of Scripture. | Not implemented. Reserved page geometry and narrow-window pan/zoom behavior are specified; native validation remains. | M3; SP-003/008 |
| Chapter/verse hub (004) | Tap a chapter or verse number to see linked notes, conversations, saved Scripture, collections and external links; open each item. | Not implemented. Range overlap, chapter aggregation, attaching links and translation mapping need contracts. | M2 hub boundary; M4 Notes; M5 organization; M6 conversations; SP-003/005 |
| Copy and Share (005) | Select Scripture; copy the text or open system sharing with its reference and edition. | Not implemented. Quotation formatting and permissions are unresolved. | M2; SP-002/003 |
| Ask (005, 011) | Select Scripture → Ask → contextual Companion; automatically attach the resulting conversation to the selected passage. | Not implemented. New versus continued conversation and selected-context disclosure need designs. | M6; SP-001/005 |
| Save as gleaning/bookmark/note (005) | Select Scripture → Save → choose a collection and/or save type; note quote can be followed by editable commentary. | Not implemented. Save meanings and intact source quotations are approved (Q6); combined collection/type flow remains open. Original source must remain identifiable. | M4 note quote; M5 full Save flow; SP-001/005 |
| Cross-version ink (007) | Switching versions must not put handwriting over unrelated words; return to a version to find its marks. | SP-003 selects separate per-edition preserved layouts with no automatic ink migration; persistence/native validation remain. | M1 feasibility → M3; SP-003/005/008 |
| Audio Bible (014) | Start/pause chapter listening while reading. | Not implemented. Human narration preferred; source rights, offline availability, speed, queue and background behavior need review. Synchronized highlighting is an optional proposal. | M7; SP-002 and future audio design |

### Collections and Notes

| Requested capability / IDs | Intended interaction | Current state and unresolved detail | Proposed placement / planning owner |
| --- | --- | --- | --- |
| Folder-like collections (010) | Open a topic folder containing related notes, conversations, passages and links. | The [Collections screen specification](../design/collections-screen-specification.md) proposes nested folders, shared membership views, detail filters and safe remove-versus-delete behavior. Storage, ordering and import rules remain SP-005 work. | M5 with M6 conversation integration; SP-001/005 |
| Blank freeform Notes (008) | Create an empty note and place typed text, ink and images anywhere on an expandable canvas. | SP-006 has only three seeded objects. Blank creation, arbitrary insertions and multiple notes are not implemented. Expandable canvas is accepted; the [Notes screen specification](../design/notes-screen-specification.md) now defines the proposed library/canvas behavior. | M4; SP-004/005 |
| Explicit grouping (008) | Objects stay independent until selected and grouped; move a group together, then ungroup without changing content. | Bounded sample implemented. Production selection, resizing and stacking are proposed in the [Notes screen specification](../design/notes-screen-specification.md); native stroke/object selection remains open. | M1 evidence → M4; SP-004/006 |
| Native drawing palette (021) | Enter Draw and choose tools through the familiar native Pencil palette. | Missing. Requested through device feedback. Exact supported tools and lasso interaction with object grouping need a scoped follow-up. | M3 Scripture and M4 Notes; M1 scoped feasibility as needed |
| Images, link cards, tables, quotes, shapes, lists (009) | Insert and edit these objects alongside ink and text; links appear as readable cards. | Only a generated sample image and plain text exist. Rich objects, insertion menus and editing rules are missing. | M4 in bounded subtickets; SP-004/005 |
| Tags, sort and views (009) | Group/filter notes by tag; sort by title/date; switch stacked cards and a normal list. | Not implemented. Stacked cards by default and list alternative approved; created versus modified date and tag behavior remain open. | M4; SP-004 |
| Verse-linked notes (004, 008) | Quote or attach a passage in a note; find the same note again from its verse hub and collection. | Not implemented. Connection should reference the same note, not silently duplicate it. | M4; SP-005 |

### Companion

| Requested capability / IDs | Intended interaction | Current state and unresolved detail | Proposed placement / planning owner |
| --- | --- | --- | --- |
| Chat-style Companion tab (011, 024) | Familiar conversational interface inspired by Claude, with a conversation list, messages and input. Each chat is a conversation. | Tab placeholder. Owner requires contextual follow-ups; per-conversation memory architecture is proposed in TDD §12.1. Navigation, titles, sources and errors still need design. | M6; SP-001 and future Companion design |
| Scripture panel and expansion (011) | Open beside Scripture, close it, or expand into Companion without losing conversation, draft or passage context. | Not implemented. Panel size and preservation of annotation layout require joint reader/chat design. | M6; SP-003/005 |
| Four presets (012) | Choose Biblical Studies, Christian Living, Apologetics or Difficult Questions; preconfigured instructions accompany each conversation. | Shared foundation and Biblical Studies/Christian Living wording approved and saved; Apologetics/Tough Questions refinements are also approved. Runtime and evaluations not implemented. | M0 wording approved → M6 runtime/evaluation |
| Study method and theological foundation (012, 013) | Answer through historic orthodox Christianity with careful interpretation and relevant supporting sources. | See the complete brief below. No evaluated prompt, retrieval integration or theological acceptance set exists. | M0 foundation → M6 behavior |
| References and research (012, 013) | Name authors/works and provide references for further reading; distinguish traditions when relevant. | Not implemented. Available materials, retrieval permissions, verified citations, costs and offline behavior are unresolved. | M6; SP-002 Scripture rights and future evidence contract |

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
| Study sessions (015) | Start and finish a timer, or enter a start and end time manually, with a Focusmeter-like emphasis on focused sessions. | Tab placeholder. Manual trigger and activity tags approved; pause/corrections accepted in principle; overlap, backgrounding and qualifying rules need design. | M8; future Activity design |
| Analytics (015) | Review study activity over time. | Not implemented. Streaks and goals approved with session/minutes trends; precise metrics and book breakdowns need review. | M8 |
| Theme and font size (016, 022) | Set readable typography and preferred light/dark/system appearance. | Reader preference ownership and restore behavior are contracted but not implemented. Annotation reflow must still be addressed. | M2 baseline in SP-009; feature-specific preferences alongside each phase |
| Further Settings / Account (019, 022) | Review downloads/versions, drawing preferences, AI provider/key/presets, activity goals, export/restore and About/attributions as relevant. | Local Settings without Sophia login and Files backup/reminders approved; further feature settings need detailed review. | M0 decisions; settings staged M2–M8 |
| Accessible and premium (016) | Calm, coherent reading and editing, discoverable actions, readable text, meaningful grouping, responsive Pencil input and clear empty/error states. | Warm-paper/book-like direction approved; full-app mockups and accessibility acceptance remain outstanding. Prototype styling does not represent final design. | M0 design, every feature phase, M9 integrated acceptance |
| Maintainable and understandable development (018) | Owner understands the architecture, chooses tickets, and receives source/design/test traceability with each result. | Role/skill routing and tickets exist; full product architecture review remains necessary. | Every milestone; SP-001/005 |
| Data safety and local operation (003, 017, 019, 020) | Preserve study locally, recover drafts, export/restore, and make optional network use explicit. | Reader continuity and immutable bundled-content behavior are contracted for SP-009, not implemented. Full backup, search and BYOK details remain open. Local install does not automatically mean every feature can operate without internet. | M1 contracts; M2 preferences; M3 ink backup and extensions M4–M8; SP-005 |

### Decisions for owner review

These are design questions, not implementation blockers to resolve by assumption. Owner
chooses product behavior; technical/content feasibility is investigated through tickets.

| Decision | What is requested versus proposed | Why it matters / planning owner |
| --- | --- | --- |
| D-01 Visual direction — confirmed and refined 2026-09-29 | OldPaper is the selected Scripture UI guide and visual baseline; it retains the agreed book-like reading, reserved writing margin and restrained Apple-style hierarchy. Seven appearance presets are selected. | Final token values, font packaging, accessibility validation, and detailed Notes/Collections/Companion/Activity/Settings screens remain design work under SP-001/004. See the [Scripture specification](../design/scripture-screen-specification.md#owner-selected-oldpaper-design-and-presets--2026-09-29). |
| D-02 Scripture modes — confirmed 2026-09-16 | Owner accepted multiple layers with three states: Read Hidden, Read Visible and Draw. At most one layer visible. Reading states allow verse taps, selection actions and listening; Draw pauses text actions/verse taps, uses Pencil tools and finger navigation, and permits existing audio to continue. | SP-003 specifies layer/gesture behavior; SP-005/SP-008 own persistence and native proof. This is not implementation authorization. |
| D-03 Translation/topic direction — confirmed | Free base translation acceptable; owner topics first, nested collections and multiple memberships. Curated index optional. | Edition/canon and content rights remain SP-002; collection data contract SP-005. |
| D-04 Save meanings — confirmed | Bookmark for revisiting; gleaning with short insight; note quote in freeform note. Preserve source quote, edit commentary separately. | Save UI and content permissions remain SP-001/002/005 work. |
| D-05 Notes defaults — confirmed | Expandable canvas/grouping/native palette; plain with ruled/grid options, stacked cards/list, direct text editing. | Resizing, rich objects and export geometry remain SP-004 work. |
| D-06 Companion — partially confirmed | Selected-context online AI and source retrieval accepted; cost not a major concern. Shared foundation and all four preset contexts approved. | No provider, numeric spending cap or source whitelist selected; runtime integration and evaluations pending. SP-001 and future Companion planning. |
| D-07 Activity — confirmed direction | Manual timer, activity tags, streaks, goals, pause/resume and corrections. | Qualifying-day/goal/overlap rules still open. |
| D-08 Settings/backup — confirmed | No Sophia login; local Settings, Files export/import and optional reminders. | Feature settings, reminder schedule and recovery contract remain open. |
| D-10 Scripture pages — confirmed direction | Owner selected vertical scrolling through bounded Scripture pages, not horizontal page turns or one giant chapter page. | SP-003 specifies preserved page geometry and an independent accessible reading layout; SP-009 owns reader selection proof and SP-008 retains annotation proof. Expandable Notes remains unchanged. |
| D-11 Main navigation — confirmed placement | Owner requested primary tabs at the bottom, not the top. | Keep book/chapter and version controls in the reader header; review keyboard, native Pencil palette, safe-area and narrow-window interactions before implementation. |
| D-12 Scripture appearance presets — confirmed 2026-09-29 | OldPaper is the base UI. The selected appearance set is OldPaper, Midnight Library, Quiet Sage, Sepia Notes, Royal Ink (formerly Ink and Linen), Tree of Knowledge (renamed from Marginalia), and Spring Leaf (renamed from Stillwater). Each preset selects palette roles and paired Scripture/supporting UI typefaces; OldPaper keeps the current system sans UI face. | Presets change appearance only. Annotation layers and states, translation-specific ink, reading-margin geometry, verse anchoring, and the rest of the agreed workflows remain in scope. Final token/font integration and accessibility validation are outstanding; this decision authorizes documentation, not app implementation. |
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

- Companion runtime integration and behavioral evaluation; provider/model, source
  access, retrieval/citation behavior and concrete cost controls.
- Exact free base edition/canon, preferred-edition rights and human narration access.
- Page dimensions, annotated-layout selection, separate reading view, font/rotation,
  panel and reserved-margin behavior; detailed visuals and canvas editing interactions.
- Goal units, streak qualification, timezone and activity-tag/overlap rules.
- Collection deletion/nesting limits, backup/reminder/recovery details, implementation
  architecture, and review of the revised phase boundaries.
- Exact Pencil model, supported OS baseline and long-term signing preference.

## Scope boundaries

Current target is personal iPad use. No Sophia login is confirmed. No runtime backend remains the architecture proposal;
online provider access is explicit and optional to local study.
App Store distribution, collaboration, Android/web clients, and cloud sync are not
planned. Content-provider accounts may still be needed for online editions. Core local
study must remain usable when an optional online feature is unavailable.
