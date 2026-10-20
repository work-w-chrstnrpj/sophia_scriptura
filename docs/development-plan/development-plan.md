# Development Plan — Sophia Scriptura

Revision: 2026-10-19. This is the main phase/progress tracker. Owner-requested roadmap
revision under SP-001; phase outcomes are ready for review, not authorization to code.
Technical intent: [TDD](../tdd/tdd.md). Full scope:
[product specification](../product-specification/product-specification.md).

## Collection Plans — proposed post-baseline milestone, 2026-10-19

Owner requested detailed tickets and explicitly deferred implementation. No new release
number, runtime change, migration, device installation or milestone closure is selected.
Visible target: create a Plan in Collections, read ordered section assignments in a
focused Scripture workspace, retain checked progress and Plan-specific Pencil ink.
Owner confirmed checked notes/links created during reading, an explicit section-summary
pause, and new annotation layers named after the Plan. The subsequent D1–D5 resolution selects
remaining implementation defaults under the owner's design-resolution request.

| Ticket | Status | Planned outcome |
| --- | --- | --- |
| [SP-049](../../tickets/SP-049-plan-model-and-authoring.md) | implemented; simulator verified; physical acceptance open | Domain, durable Plans, authoring and lifecycle |
| [SP-050](../../tickets/SP-050-plan-reading-and-progress.md) | ready for implementation; implementation unselected | Fullscreen focused reading, progress and section summaries |
| [SP-051](../../tickets/SP-051-plan-annotations-and-study-tools.md) | ready for implementation; implementation unselected | Plan-named Pencil layers, checked reflections and embedded tools |
| [SP-052](../../tickets/SP-052-plan-integrated-acceptance.md) | ready for implementation; implementation unselected | Integrated durability, privacy, physical Pencil and accessibility acceptance |

Recommended dependency order: SP-049 → SP-050 → SP-051 → SP-052. SP-049 includes
compatibility and backup support from the first data-bearing slice; SP-051 completes
cross-feature/ink recovery; SP-052 verifies the connected journey. No implementation
ticket is considered accepted merely because planning is complete. Owner chooses each
next ticket. Physical Pencil/privacy/accessibility and real-provider acceptance remain
separate from simulator/build evidence. See [shared design](../design/collection-plans.md)
and [TDD baseline](../tdd/tdd.md#collection-plans--planning-baseline-sp-049052).
Documentation-only validation: local links/anchors and whitespace; native tests not run.

### Collection Plans planning review — 2026-10-19

[Review](../design/collection-plans-review.md) records twelve gaps/conflicts and their
recommended contract resolutions, with expanded PA/PR/PT/PI acceptance criteria. Principal
changes: single Collections writer; 80-character title/layer-name compatibility; annotation
capacity handling; scoped reader/shell ownership; typed durability/restore results;
protected orphan reflection handling; version-safe ink access and inert restored retries.
At review time the tickets remained draft pending the writer/reader/access/recovery design.
The resolution below closes those design gates. No native build/tests/device/provider work
occurred; Start stays gated until SP-051 safety criteria.

### Collection Plans contracts resolved; tickets ready — 2026-10-19

Owner authorized resolving schema, transaction API, access bindings and reader lifecycle,
while explicitly withholding implementation. The selected
[D1–D5 contract](../data/collection-plans-contract.md) specifies Collections 4, Notes 5,
annotation 2, full-backup 2 and gated wrappers/pointers; typed single-writer commands and
receipts; durable per-domain access capsules and propagation; a scoped reader lease; and
checkpointed sequential backup recovery. Exact keys, API shapes and future file ownership
are recorded. No remaining schema/API/access/lifecycle design blocker is carried forward.

SP-049–052 are **ready for implementation; implementation unselected**. SP-050 still needs
SP-049 code; SP-051 needs SP-049/050; SP-052 needs all three implementations/evidence.
This is dependency sequencing, not an unresolved design decision. Implementation tests,
physical/provider acceptance and milestone completion remain unproduced. Documentation-only
links/anchors/schema/API consistency and whitespace are the checks for this resolution.

### SP-049 implementation selected — 2026-10-19

Owner requested implementation and continuation. Execution began with SP-049 (authoring,
validation, Collections/Notes schema+access and single-writer/backup foundations). Focused
r4: 153 tests passed; later final-source full/native UI evidence is recorded in the ticket.
SP-050/051 reading/Pencil/tools and SP-052 acceptance remain unselected; Start is unavailable.
No release/version, signing/install, user-store migration/reset or feature acceptance is
selected by this source implementation checkpoint.

### SP-049 verification complete — 2026-10-20

Plan authoring/data foundations are implemented locally. Final simulator build and **434
unit tests passed**, zero failures/skips (build/sp-049/final-regression.xcresult). The
focused create/assign/save/relaunch UI journey passed (ui-r4.xcresult); its screenshot was
reviewed. Two injected/round-trip backup integration cases passed separately and in the
full suite. Ticket evidence records earlier failures/fixes and exact scope limitations.
SP-050–052 remain ready and unselected; Start stays unavailable. Physical authoring,
accessibility/owner-data upgrade and integrated acceptance remain open. No physical install,
source publication, release/version bump or user-data reset occurred.

### Plan opening/playback correction — 2026-10-20

Owner superseded the earlier Start gating decision: a Plan opens its contents, Edit is
explicit, and basic Start/Resume uses the existing reader without a new app mode.
Next saves checks/cursor and pauses at section summaries. This SP-049 correction/basic
SP-050 entry slice does not close the full reader-lease, focus-contrast or SP-051 tools/ink
requirements. The owner also requested signed in-place installation. See SP-049 for
final-source evidence: 21 focused unit tests and the complete playback/relaunch UI journey
passed; signed in-place iPad install and unlocked launch succeeded at 1.3.2/build 27.
Earlier unavailable-Start statements above
record the previous implementation checkpoint and no longer describe current behavior.

### Plan fullscreen/preview/control correction — 2026-10-20

Owner selected SP-050 presentation and SP-051 note/link/music controls after rejecting
the floating Plan UI. Fullscreen theme-aware content/reading, full book titles, gray
non-assignment verses, actual Notes previews and the requested icon bar are implemented.
Checked reflections retain creation order and target-first durability; notes reuse the
shared New Note/editor workflow, and music uses the existing root session. Plan-owned
Pencil, Companion integration, full reader lease and physical acceptance remain open.
Add assignment now separates Scripture, Notes and Links into dedicated tabs with retained
input drafts. Final test/visual/install evidence is recorded in SP-049.

## v1.3.2 — owner-selected publication, 2026-10-18

Owner authorized commit, push, merge and source release as v1.3.2/build 27.
Scope: SP-048 Quiz Me ready-bank lifecycle/refill durability, matched summary controls,
source-grounded documentation reconciliation and the complete app README. Bravado skill
and showcase outputs remain outside this release. No data migration/reset or additional
feature ticket is selected. Final simulator build and 414 unit tests passed, zero
failures/skips, on Xcode 27.0 / iPad (A16) iOS 27.0. Portrait/landscape summary renders
and local documentation checks passed. Publication follows merge through the hosted
Release workflow. Verification evidence is in
[release notes](../releases/v1.3.2.md); physical/provider acceptance remains separate.

## Documentation reconciliation — 2026-10-18

Owner requested documentation alignment with the current source. Reviewed `ae573a9`
(v1.3.1/build 26), uncommitted SP-048, root session composition, provider/preset wiring,
translation/narration and feature persistence/backup boundaries. Corrected stale scaffold,
in-memory Collections, absent-provider and original-M7-only descriptions in the canonical
TDD/product map, project/source maps, README, release index and agent guidance. Existing
SP-048 edits/evidence are retained; no app implementation, release or new acceptance is
claimed. Documentation checks: local links/source paths, bundled preset consistency and
`git diff --check`; native tests are not rerun for this documentation-only reconciliation.

Owner-requested README expansion: added a connected study walkthrough, all six tabs,
Sophy, narration/music/system controls, storage/privacy boundaries, technology and
architecture, setup, release-versus-working-tree status and documentation navigation.
Verified descriptions against the current source and checked README links/anchors;
no application changes or new runtime verification were performed.

## SP-048 — owner-selected Quiz Me fixes, 2026-10-18

[SP-048](../../tickets/SP-048-quiz-bank-lifecycle-and-summary-actions.md) matches
summary buttons and changes bank lifecycle to immediate ready-bank starts,
reservation-triggered replacement, 100 minimum / 200 capacity per type/difficulty
and scoped provider/edition, durable batched refill and foreground reconciliation.
Implemented: 414 unit tests passed and portrait/landscape summary renders reviewed.
Signed build, signature/identity checks, in-place iPad install and normal launch
passed after signing was restored. Physical acceptance remains open. Included in owner-selected v1.3.2.

## v1.3.1 — owner-selected publication, 2026-10-16

Owner authorized commit, push, merge and release of the current fixes as
v1.3.1/build 26: SP-046 compact/red Delete card and SP-047 link editing, material
subfolder drops and icon-only section headers. All 406 unit tests and three focused UI journeys passed, zero failures. Signed
build, signature/identity, versioned in-place iPad install and launch passed. Physical acceptance remains separate.
See [release notes](../releases/v1.3.1.md).

## SP-047 — owner-selected Collections fixes, 2026-10-16

[SP-047](../../tickets/SP-047-link-editing-and-study-material-drag.md) adds saved-link
editing and material → subfolder drag/drop through existing Collections persistence.
69 domain/protection tests and the edit/drag/relaunch UI flow passed; signed
build, in-place iPad install and launch passed. Physical acceptance remains open. The SP-046 compact/red Delete
question-card follow-up passed its UI flow and was installed/launched. These follow-ups
are newer than the published v1.3.0 tag; no new release is selected.

## v1.3.0 — owner-selected publication, 2026-10-15

Owner authorized commit/push/merge/release of the current worktree as v1.3.0/build 25.
Scope: SP-044 swipe refinements, SP-045 duplication/Journal tools, SP-046 Points to
Ponder and study conversions, active save destinations and final button wording/style.
Full local unit suite: 403 passed; three final-label UI journeys passed, zero failures.
Final source is signed, installed
in place and launched on the owner's iPad. Hosted verification/publication follows
the main merge; physical/live-provider acceptance remains separate. See
[release notes](../releases/v1.3.0.md).

## SP-046 — v1.3.0 study material conversions, 2026-10-15

[SP-046](../../tickets/SP-046-points-to-ponder-and-study-conversions.md) adds Points to
Ponder, question → Companion/new note, Bookmark → Gleaning and Gleaning → new note.
Owner selected implementation and in-place iPad delivery. Version 1.3.0/build 25;
111 domain/protection/Companion tests and two focused UI journeys passed. Owner follow-up fixes exclude
inactive save destinations and align bookmark conversion button order/size. Signed
build, in-place iPad install and launch passed; physical acceptance and release
publication remain separate.

## SP-045 — owner-selected study record refinement, 2026-10-15

[SP-045](../../tickets/SP-045-study-record-duplication-and-journal-type.md) fixes
annotation tombstone presentation, adds collection/note duplication, retractable
Page/Journal tools and backward-compatible Journal Type. Collection copies reuse
existing items by owner choice; standalone note duplicates are independent. Focused
domain/protection and two new UI flows passed; signed build/signature checks passed.
Journal Type follow-up adds Unset for new journals and book/quill/owl type icons;
legacy journals retain Spiritual. Physical acceptance remains open. See the ticket
for coverage and delivery evidence.

## SP-044 — owner-selected interaction refinement, 2026-10-14

[SP-044](../../tickets/SP-044-consistent-record-swipe-actions.md) removes the permanent
Collection material-list/card ellipsis and adds shared swipe action reveal to Collection
lists, Notes cards/lists and Prayer updates, retaining long-press menus and existing
confirmations/access commands. Implemented: four focused UI tests and signed iPad
build/signature checks passed. The follow-up signed build was installed in place and launched on the paired iPad;
physical interaction acceptance remains open. Owner follow-up for
single-open rails, body swipe-back, scroll dismissal and faster release/settling
passed four focused UI cases across two runs. Further owner-requested polish makes
Arrange plain and adds direct child-folder counts to subfolder previews; the nested
hierarchy UI check and screenshot review passed. Evidence is in the ticket.

## v1.2.0 — owner-selected publication, 2026-10-14

Owner authorized commit/push/merge/release of all current changes as v1.2.0/build 24.
Scope: Collection Smart Order, No Folder color and item actions; Sophy commands/Bible
tree intent; Qwen region adapters; SP-041–043 planning documents. Release fixes align
No Folder note access, authoritative Companion trash and conservative Qwen costing/model
fallback. Verification passed: 392 units and two focused Collection deletion UI tests.
See [release notes](../releases/v1.2.0.md) for evidence and acceptance limits.

## Proposed study automation — planning requested 2026-10-13

The owner requested three detailed tickets after v1.1.0. This section records
proposals, not implemented behavior, a new release promise or permission to code.
Existing M0–M9 closure is unchanged; target release is unassigned.

| Ticket | Proposed outcome | Dependencies/readiness |
| --- | --- | --- |
| [SP-041](../../tickets/SP-041-sophia-mcp-bridge.md) | Optional paired Mac MCP bridge for scoped reads, later native-reviewed writes and independently verified ChatGPT/Cursor/Claude connections | Draft; foreground transport/auth/rights/idempotency spike required; no runtime backend exists today |
| [SP-042](../../tickets/SP-042-selected-handwriting-to-text.md) | Box/lasso selected ink → local transcription → editable review → Copy/Insert with original ink retained | Draft; physical handwriting accuracy/coordinate spike; Canvas first, Page-style and Scripture gates explicit |
| [SP-043](../../tickets/SP-043-lasso-handwriting-sophy-enhancement.md) | Selected handwriting → reviewed transcription → existing Sophy enhancement operations → reviewed Copy/Insert | Draft; depends on accepted SP-042 source snapshot and review; preserves existing typed selection and protected disclosure consent |

Recommended owner selection: SP-042 G0/G1 first, SP-043 Canvas next, then SP-041
read-only integration. MCP feasibility can be evaluated independently after owner
selection; OCR/enhancement need no MCP. Surface expansion, external writes and remote
hosting are explicit checkpoints. Full acceptance matrices and stop conditions live
in the tickets; every new acceptance case is Not Run. Source-grounded documentation
planning is complete; no new app code, agents' skills, server, accounts or deployment
is authorized by this planning request.

## v1.1.0 — owner-selected publication, 2026-10-13

Owner authorized commit, push, merge and release of all current changes as v1.1.0
(build 23). Scope includes SP-040 Notes/Collections refinements, Activity chart and
record-detail presentation, and Companion repeated Quiz Me rounds/activity updates.
The release snapshot passed 376 unit tests with zero failures; see
[release notes](../releases/v1.1.0.md) for verification and acceptance limits.

## Post-v1.0.0 refinements — owner selected 2026-10-13

[SP-040](../../tickets/SP-040-folder-drag-and-journal-prayer-presentation.md) implements
folder drag/reparent at root and nested levels, consistent Journal state icons, and
Enlarged Rubber Stamp Answered/Redirected marks with stable 1–15° tilts overlapping prayer card text (outside the editor). Owner addition: Page-only
pageStatus toolbar with Unset/Drafting/Revising/Editing/Publishing/Closed choices;
Journal cards show both states in one row, Page cards show opening text, and Closed
Pages show a green PUBLISHED mark in the preview area; stamp entry animation and
collection-local note editing preserve the folder on return; type-specific long-press
status menus are available in Notes and Collection note rows; Collection folders
offer remembered List/Card layouts with uniform dimensions across material types;
Notes and Collection note cards now share presentation and stamp animation;
42 Page-status-focused checks passed (41 Notes unit, 1 UI), with compatibility,
persistence and undo coverage. Build and 60 focused checks passed (58 unit, 2 UI);
Signed build, signature verification, in-place installation and launch on the owner's
iPad A16 passed on 2026-10-13; physical feature acceptance remains open. This scope is
included in v1.1.0. Installation evidence is recorded in SP-040.

## v1.0.0 — owner-selected publication, 2026-10-13

[SP-033](../../tickets/SP-033-v100-multi-source-translation-release.md) defines the
owner-requested release outcome: retain bundled WEBP and API.Bible, add independently
managed AO Lab translations. Sequence: SP-034 source contracts/compatibility → SP-035
catalog/eligibility/parser → SP-036 offline downloads → SP-037 Versions/reader integration
→ SP-039 narration → SP-038 acceptance/release. **2026-10-11:** SP-034–037 and SP-039
implementation landed in app source (multi-source contracts, Hello AO catalog/download/read,
Versions UI, bounded BSB narration). SP-038 publication is owner-selected on 2026-10-13 as version 1.0.0/build 22;
the full TR/AU matrix and physical/provider acceptance remain open. See
[v1.0.0 release notes](../releases/v1.0.0.md) for evidence and disclosed gaps. API.Bible licensed trio is NASB (`b8ee27bcd1cae43a-01`), NLT and NKJV; NIV removed from picker/sync list (legacy NIV edition IDs remain in stored study data only).
WEB is the World English Bible family; existing WEBP identity/data remain preserved.
[Detailed execution guide](../design/v100-translation-implementation-guide.md) now defines
contracts, recovery, limits and TR-01–22 evidence. D2/D3 are owner-decided; D1 is decided: KJV, BSB, ASV, LSV and WEBU; verification remains open
NASB provider ID is recorded above; authenticated rights/lease verification remains open.
Preserve legacy NIV study references; do not transfer its Debug authorization to NASB.
dependent work cannot become ready by assuming the recommendations.
SP-032 remains a separate v0.5.* ESV draft and is not silently superseded by this plan.

## v0.5.* — ESV text and passage audio planning, 2026-10-10

[SP-032](../../tickets/SP-032-v05-esv-text-audio-manual-sync.md) records the owner's
request for ESV text and narration, bounded caching and manual refresh after 30 days.
Status: **draft; planning complete, implementation not selected**. Proposed default:
refresh-due status rather than an API.Bible expiry lock. Persistent audio downloads
require separate permission evidence; online playback and bounded text are independent.
Exact patch assignment remains open. This is new ESV-specific scope after M7 abandonment.

## v0.4.0 delivery — owner selected 2026-10-10

SP-029–031 and the current study-companion presentation changes are included in version
0.4.0/build 21. Signed installation and launch on the owner's iPad passed; release checks
are recorded in [v0.4.0 notes](../releases/v0.4.0.md). Publication does not close pending
provider, extended background, accessibility or physical visual acceptance in those tickets.

## Floating study player — selected 2026-10-10

[SP-031](../../tickets/SP-031-study-picture-in-picture.md) adds owner-selected PiP for
music/Activity display, with one system Play/Pause mapped to music when present and
Activity otherwise. Explicit preview/start, existing command owners and privacy-safe
Activity projection are implemented; simulator and physical acceptance are recorded in
the ticket. It supplements SP-030 and supersedes its PiP exclusion for this selected work.
No permanent Home-screen notch is claimed; release assignment remains undecided.
Owner-selected Settings opt-out is implemented with a persisted toggle and guarded PiP
entry; preference and late-command regression checks are recorded in SP-031.

## Background system controls — planned 2026-10-10

[SP-030](../../tickets/SP-030-background-music-and-activity-system-controls.md) plans
outside-Sophia music controls and an Activity Live Activity for the Home and Lock Screens. Playback/timing continue during app switching, but
display above other open apps, force-close and a custom in-app pill are excluded. Actual iPad system
placement and Personal Team extension signing must pass a feasibility gate. Status:
**in progress** — Now Playing, committed Activity projection, Live Activity extension target, and `sophiascriptura://activity` deep link are in the tree; **G0 device evidence and AC1–AC10 acceptance remain open**. Its
[normative execution guide](../design/sp030-system-controls-implementation-guide.md)
defines state transitions, committed-save projection, failure tests and G0–G6 gates.

## v0.4.0 — Sophy implementation and review, 2026-10-10

[SP-029](../../tickets/SP-029-v040-sophy-lady-wisdom.md) captures the owner-approved
Sophy/Lady Wisdom and Hugging Face plan as one executable release ticket with ordered
work packages and a [normative implementation guide](../design/sophy-implementation-guide.md)
covering contracts, crash recovery and P0–P8 evidence gates. Status: **in progress**. The panel, Lady Wisdom character, slash commands, editable previews, insights and Notes replacement are in the app and off until Settings “Turn on Lady Wisdom” is enabled. Owner-requested review corrected the chat interface, source disclosure, cancellation, enhancement safety, durable action handling and backup integration; see the [review and acceptance walkthrough](../testing/sp029-sophy-review.md). Full-scheme regression, live provider calls and physical acceptance are still open. It covers the quiet
illustrated companion, editable action approvals, separate action-only History,
unprotected study retrieval, consented protected-text enhancement, Activity insights,
existing workflow handoffs and shared BYOK routing. This is not a release and not physical acceptance. Existing v0.3.0 physical acceptance remains independent.

## v0.3.0 follow-up — selected 2026-10-07, release authorized 2026-10-09

Owner requested tickets for [v0.3.0](../releases/v0.3.0.md), then selected SP-025 implementation
on 2026-10-07, then SP-026–028 together. The owner chose app access locks with existing storage formats. Source is implemented and simulator-verified; physical acceptance is tracked below. Owner selected commit, merge and v0.3.0 publication on 2026-10-09; physical acceptance remains tracked independently.
Affected handwriting version: v0.2.*; target fix version: v0.3.0.

| Ticket | Status | Planned outcome |
| --- | --- | --- |
| [SP-025](../../tickets/SP-025-v030-compound-ink-and-stroke-editing.md) | implemented; simulator verified; physical acceptance pending | Ink regions with internal stroke editing and spatial indexing |
| [SP-026](../../tickets/SP-026-v030-lock-authentication-and-lifecycle.md) | in_progress; simulator verified; physical acceptance pending | Touch ID/password, independent category sessions, combined Settings lock/unlock, 10-minute idle/relaunch locking |
| [SP-027](../../tickets/SP-027-v030-notes-lock.md) | in_progress; simulator verified; physical acceptance pending | Notes lock controls, protected cards and guarded routes |
| [SP-028](../../tickets/SP-028-v030-collections-lock.md) | in_progress; simulator verified; physical acceptance pending | Collections lock controls and independent protected access |

SP-025 implementation and simulator evidence are recorded in its ticket; physical acceptance
remains open. SP-026 precedes SP-027/028. Physical Pencil and biometric acceptance,
legacy data/recovery and resolved security policies are v0.3.0 gates. Baseline milestone
closures and SP-024's remaining physical acceptance are unchanged.

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
| M8 | Activity and background music | done; owner verified 2026-10-04 | Built-in and custom modes including Studying; Reading timer and verse range; Scripture Contemplation fullscreen swipe journey; manual records; goal/streak/period/mode analytics; local reminders; shared Now Active cluster; Quiz Me → Studying linkage; background music wiring with placeholder catalog | SP-020–022; SP-021 without approved commercial tracks |
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
quiz questions through the final summary automatically creates a Studying record, whether
timed or untimed and without an Activity timer. Active question duration counts toward the
normal goal/streak; abandoned sessions are not automatically recorded. Quiz-history deletion
leaves its Activity time intact. Activity owns duration/goal records, not the quiz answer key,
answers, score or explanation.

Owner review: one multi-turn study conversation in each mode, including a clarification,
a reopened conversation and a source inspection; plus representative timed/untimed Quiz Me
runs with checked Scripture answer keys, sourced Christian History explanations, saved history,
and the selected Studying-record flow. No provider purchase is implicitly authorized.

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
strict-JSON questions with distinct difficulty rubrics. SP-048 supersedes SP-019 sizing with a 100-question minimum target and 200-question
capacity per type/difficulty bucket; a warm quiz starts from the local cache and
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
Implement five built-in modes plus user-created modes; one timestamp-based
timer that survives backgrounding/relaunch and excludes paused intervals; independent Settings choices for automatic Reading and Scripture Contemplation workflows (enabled by default); a separate Contemplation section; Reading start/end reference capture when its workflow is enabled
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
Also verify a completed Quiz Me session can be associated with a Studying record according
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

## v1.0.0 audio planning expansion — 2026-10-10

[SP-039](../../tickets/SP-039-v100-scripture-audio-and-verse-highlighting.md) adds a Scripture player, transport controls and verified verse-synchronized highlighting. BSB is the initial candidate, not a claim of complete audio coverage. Recording-specific rights, exact text/audio/timing binding, shared music/system ownership and AU-01–09 are required. A1–A3 approved: ±15-second/chapter controls, Continuous/Follow initially off, streaming and optional manual chapter/book downloads. Prior AO-audio exclusions are superseded for this bounded feature; word-level highlighting and unverified edition audio are excluded. Implementation remains unselected.

### SP-049 stability correction selected — 2026-10-20

Owner reported app termination on removing a day/section and requested broader tests.
The original code was reproduced with a confirmed Swift exclusivity abort. The editor
now renders value snapshots and uses stable-ID draft commands with stale-callback
checks. Additional regression coverage includes structural edits, reset/replacement,
chapter bounds and repository reopening. See [investigation](../testing/sp049-plan-stability-investigation.md)
and SP-049 for final suite/device evidence. No new feature ticket or schema is selected.

Stability result: final simulator bundle `build/sp-049/plan-stability-final.xcresult`
passed 455 tests (453 unit + 2 Plan UI), no failures/skips. Signed build and in-place
physical install passed after retrying a device connection error. SP-049 remains
implemented/simulator verified with physical feature acceptance open.

SP-049 action presentation follow-up: assignment removal is available in the item's
ellipsis menu with a trash icon. Plan reset/duplicate/archive/trash rows have icons;
Move Plan to Trash explicitly uses red. Command ownership and schemas are unchanged.
Verification evidence is recorded in SP-049.

Owner wording follow-up (2026-10-20): Collections now uses “Items” for its section
heading and “Add Items” for actions/picker title. Accessibility and search labels use
the same terminology; existing identifiers and behavior remain unchanged.

SP-049 completion presentation follow-up: completed Plans show a passive COMPLETED
stamp on Collection list/cards and their contents page, derived from checked nonempty
assignments. Reset removes it; no new persistence format. Evidence is recorded in SP-049.

SP-049 owner stamp correction: replace the initial badge with the actual Notes stamp
renderer and matching Rubber Stamp vector wordmark; center over Collection cards,
with compact list scaling and full-size Plan contents presentation. See ticket evidence.

Owner placement correction: COMPLETED appears only on the outside Collection
list/card record. The Plan contents page does not display a stamp.

SP-009 owner reading-position correction: hydrate ReaderSnapshot once before writes,
including early lifecycle/shell saves, so the last book/chapter survives startup.
Existing persistence format and corrupt-store protection remain unchanged. Native
ordering/store-reopen tests and physical install evidence are tracked in SP-009.

### Owner-authorized v1.4.0 / build 28 delivery — 2026-10-20

Includes SP-049 authoring/basic reading, structural stability corrections, Items labels,
Notes-style outside-only Plan completion stamps and SP-009 startup position protection.
Full Plan reader lease, Plan Pencil and embedded Companion scope remain unselected/open.
The final candidate passed 456 unit tests; focused UI/release evidence is recorded in
[release notes](../releases/v1.4.0.md). Signed in-place iPad install/version query passed;
launch initially blocked by device lock. Remote cleanup preserves development and main.
