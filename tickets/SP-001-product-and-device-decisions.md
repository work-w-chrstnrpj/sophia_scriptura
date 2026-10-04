# SP-001 — Product and device decisions

- Type: planning. Status: done; owner closed at M9 integrated acceptance 2026-10-04. Owner: Product & Planning Manager.
- Requirements: REQ-001–REQ-024 (full-product reconciliation; not implementation of those requirements).
- Dependencies: owner answers; no code dependency.
- Design: [product specification](../docs/product-specification/product-specification.md),
  [TDD §4](../docs/tdd/tdd.md#4-decision-status).

## Purpose and scope

Reconcile the full original brief first, then obtain owner-reviewed delivery priorities
and an understandable first daily-use scope. The smaller workflow is not approved yet.
Confirmed: iPad A16, owner-reported iPadOS 26.6.2, non-Pro Apple Pencil, essential
freeform notes on an expandable canvas, free-first Bible access with preferred editions.
Personal Team signing has been used for the experiment. OldPaper is now the selected
Scripture visual baseline, and seven color/type presets are selected; full feature screens,
exact Pencil model, detailed interactions, long-term signing choice and concrete AI cost
controls remain open. Questionnaire decisions below confirm local Settings. Native Pencil
palette is an explicit expectation from subsequent feedback.

## Work

### Scripture screen design deliverable

The first concrete design deliverable is the [Scripture screen specification](../docs/design/scripture-screen-specification.md).
It records the owner-selected OldPaper base and seven appearance presets, alongside the
bottom navigation, Book/Chapter/Verse and Version
controls, verse hub, text actions, audio, three annotation states, responsive behavior,
accessibility gates and the first SwiftUI ownership map. Its unreviewed feature details
remain proposals; the visual direction and preset names are selected.

1. Map every original feature and subsequent decision to requirements, interaction,
   current evidence, unresolved decisions and proposed milestone placement; obtain owner
   review of the whole design before choosing a reduced delivery slice.
2. Record exact Pencil model when available; do not make core controls depend on it.
3. Explain signing/reinstall and recovery tradeoffs without changing machine settings.
4. Capture decisions gradually, linking each to affected requirements and tickets.

## Acceptance and verification

- Each unresolved decision has an owner, impact, and explicit pending status.
- The owner can describe the first study workflow and its deferred capabilities.
- No proposed translation/provider, editor geometry, or paid service is labeled approved.
- Verify document consistency and links. No app build is required for this planning ticket.

## Outputs and boundaries

Update product specification, TDD decision status, and development plan. Produce no
application code. This ticket does not authorize deleting the existing scaffold.

## Execution contract

Planning work only in the current stage. No implementation completion is implied by
this ticket. Record unresolved items explicitly. Do not create provider accounts,
accept agreements, purchase access, or obtain credentials on the owner's behalf.

## Evidence

2026-09-16: owner authorized full-design reconciliation. Updated the existing product
specification with the complete feature map, theological brief, D-01–D-09 open decisions,
and proposed milestone assignments; extended UX to the whole app. Added REQ-021–023 for
native Pencil palette, Settings/Account review, and translation/topic coverage. Preserved
REQ-001–020 IDs. Corrected the implication that premium quality belongs only in M5.

Review pending: full-design completeness, visual/interaction direction and delivery order.
The initial M2 workflow remains an unapproved proposal. No app code or new implementation
ticket executed. Validation: 92 local file links resolve, REQ-001–023 are unique and ordered, and
`git diff --check` passed. Native tests were not rerun for documentation-only changes. This ticket is not done until owner review.


2026-09-16: owner approved D-02 — multiple Scripture annotation layers with Read Hidden,
Read Visible and Draw states. Updated REQ-006, feature map, UX and TDD. This is a design
approval, not authorization to implement annotations. Other full-design decisions remain open.

2026-09-16: owner reaffirmed YouVersion-style Book/Chapter/Verse navigation plus a separate
Version selector, and questioned chapter-sized annotation surfaces. Recorded D-10 as an
open page-based Scripture design question. No chapter-per-page or pagination approach was
approved; expandable Notes remains unchanged.

2026-09-16: owner selected D-10 Option 1 (vertical scrolling through bounded Scripture
pages) and D-11 (main tab bar at the bottom, not the top). Updated product, UX and TDD;
page dimensions/layout persistence and detailed navigation interactions remain open.
This records design approval only; no application code was changed.

2026-09-16: recorded all twelve questionnaire answers in the product specification.
Q1–7 and Q9–12 establish the warm-paper direction, margin/layout policy, per-translation
ink, Collections/Save/Notes defaults, online Companion direction, tagged manual Activity
with streaks/goals, local Settings/Files backup/reminders, free-base acceptance and
human-narration preference. Q8 explicitly awaits the owner's next sample; no theological
answer ordering is selected. No numeric spending cap or purchase authorization inferred.

Preferred feature sequence is Scripture → annotations → Notes → Collections → Companion
→ audio → Activity. Prior M2/M3 boundaries need a reviewed revision; do not label the small
prototype the owner's complete useful app. At this checkpoint the next owner action was
to send the Companion sample; that input was received in the following evidence entry.
SP-001 stays in_progress; no app code, provider calls, purchases or implementation executed.

2026-09-16: owner supplied Biblical Studies and Christian Living samples, approved the
refined prompts, and requested adding them as Companion context. Saved the exact approved
shared foundation and both preset instructions in `shared/prompt-presets.seed.json`, context
version 1. Marked the other two existing presets draft; their specific wording was not
changed or approved. Documented placeholder composition and follow-up context requirements.
Q8 input is received. No runtime integration, provider request or behavioral evaluation
was performed. SP-001 stays in_progress for remaining design/phase decisions.

2026-09-16: owner requested stateful conversational follow-ups and supplied Apologetics
and Tough Questions samples for refinement. Added REQ-024 and a proposed conversation-scoped
memory design in TDD §12.1, including context limits, source/privacy boundaries and test
scenarios. Updated seed to revision 2 with refined draft presets; preserved the approved
shared foundation and first two presets. The two new refinements await wording approval.
No cross-chat memory, runtime implementation, provider call or evaluation is claimed.

2026-09-16: owner explicitly approved the refined Apologetics and Tough Questions drafts.
Marked both owner-approved in seed revision 2 without changing instruction wording; the
shared foundation and all four presets now have wording approval. REQ-024 follow-up context
remains confirmed, with its architecture proposed and unimplemented. SP-001 remains
in_progress for overall design/phase review. No runtime code or provider calls executed.
Verification: parsed JSON, four unique approved presets, one shared-context marker each,
and `git diff --check`; behavioral evaluation remains pending.

2026-09-16: owner requested roadmap revision. Replaced the previous M0–M5 proposal with
M0–M9: planning, feasibility, Scripture, annotations, Notes, Collections, Companion,
audio, Activity, integrated acceptance. Preserved M0/M1 identities and documented the
old-to-new mapping. Added phase outcomes, dependencies, owner review steps, current status,
and incremental recovery/quality gates. Updated current feature-map milestone references,
entry points and ticket index. Rich Notes stays in its own phase rather than being silently
deferred to final polish. Existing implementation statuses remain unchanged. Next recommended
owner selection is full-app screen/architecture planning under SP-001; no app code changed.

Roadmap validation: 94 local file links resolve; M0–M9 are unique and ordered; product/UX milestone references resolve. Documentation-only checks; no native tests rerun.

2026-09-17: owner approved the next Scripture screen design decisions: selectable
Scripture typeface in Settings, verse hub as a landscape popover with adaptive portrait
fallback, Reserved ruled margin by default, collapsing reader controls, and an optional
two-translation comparison synchronized by canonical verse anchors. The visual direction
is a balanced antique study-Bible and modern editorial treatment. Updated the Scripture
screen specification with the comparison behavior, font/layout preservation rule,
responsive compact bar, and design-review acceptance scenarios. No application code was
authorized or changed; exact font list, renderer, content permissions and layer migration
 rules remain open.

2026-09-17: designed the [App shell and cross-screen specification](../docs/design/app-shell-specification.md)
as the next M0 deliverable. It defines the persistent bottom tab bar, per-tab state
restoration, typed cross-screen intents, popover/sheet/panel rules, audio mini-player,
local search, shared DesignSystem responsibilities, common empty/offline/error states and
the handoff order for detailed Notes, Collections, Companion, Activity and Settings designs.
No implementation ticket was selected at that checkpoint and no application code changed.
The reader-only SP-005 contract and ready SP-009 ticket now supersede that next-step state.

2026-09-17: drafted the [Collections library and detail specification](../docs/design/collections-screen-specification.md).
It defines nested topic folders, shared artifact membership without duplication, collection
detail filters, Save/Add flows, verse-hub integration, remove-versus-delete behavior,
missing-target handling, recovery boundaries and accessibility scenarios. Exact ordering,
folder styling, child-folder deletion policy and export format remain open. No application
code changed; SP-005 contract work remains a dependency.

2026-09-29: owner selected OldPaper as the Scripture UI guide and the base appearance
preset: white, black and grayscale, with the current Georgia Scripture face. Recorded the
seven color/type presets in the Scripture design: OldPaper, Midnight Library, Quiet Sage,
Sepia Notes, Ink and Linen, Tree of Knowledge (formerly Marginalia), and Spring Leaf
(formerly Stillwater). Updated the shared shell, UX, TDD, product decision register and
roadmap to use this direction. Presets change appearance only; annotation layers and states,
translation-specific ink, the reserved margin, verse links, and other planned workflows
remain in scope. This is documentation and design selection, not app implementation.
Detailed feature screens, font packaging, exact token validation, accessibility and native
iPad acceptance remain open; SP-001 stays in progress.
