# Sophia Scriptura Tickets

Tickets connect [requirements](../docs/product-specification/product-specification.md)
to [technical intent](../docs/tdd/tdd.md), acceptance criteria, and verification evidence.
Milestones **M0–M9 are closed** as of **2026-10-04**. M7 Scripture audio is **abandoned**.
Milestone ordering and closure evidence live in the
[development plan](../docs/development-plan/development-plan.md).

| Ticket | Current status | Work |
| --- | --- | --- |
| [SP-041](SP-041-sophia-mcp-bridge.md) | draft; planning complete; implementation unselected | Paired MCP bridge: scoped reads, reviewed writes and per-client compatibility gates |
| [SP-042](SP-042-selected-handwriting-to-text.md) | draft; planning complete; implementation unselected | Local box/lasso ink transcription, editable review and safe typed insertion |
| [SP-043](SP-043-lasso-handwriting-sophy-enhancement.md) | draft; planning complete; implementation unselected | Reviewed handwriting transcription → Sophy enhancement → Copy/Insert, retaining ink |
| [SP-040](SP-040-folder-drag-and-journal-prayer-presentation.md) | implemented; simulator verified; physical acceptance pending | Folder drag/reparent, Journal/Prayer presentation and Page status |
| [SP-033](SP-033-v100-multi-source-translation-release.md) | draft; v1.0.0 planning | v1.0.0 multi-source translation release |
| [SP-034](SP-034-translation-source-contracts.md) | draft; v1.0.0 planning | Source contracts and backward-compatible translation routing |
| [SP-035](SP-035-helloao-catalog-and-content-adapter.md) | draft; v1.0.0 planning | AO Lab catalog, eligibility and content adapter |
| [SP-036](SP-036-helloao-offline-downloads.md) | draft; v1.0.0 planning | Recoverable AO Lab offline downloads and manual updates |
| [SP-037](SP-037-multi-source-versions-and-reader.md) | draft; v1.0.0 planning | Multi-source Versions controls and reader integration |
| [SP-039](SP-039-v100-scripture-audio-and-verse-highlighting.md) | draft; v1.0.0 planning; audio choices approved | Scripture audio player and synchronized verse highlighting |
| [SP-038](SP-038-v100-translation-acceptance-and-release.md) | draft; v1.0.0 planning | v1.0.0 translation acceptance and release gate |
| [SP-032](SP-032-v05-esv-text-audio-manual-sync.md) | draft; planning complete; audio persistence permission open | v0.5.* bounded ESV text, passage narration and manual 30-day refresh |
| [SP-031](SP-031-study-picture-in-picture.md) | in progress; PiP device acceptance pending | Owner-selected floating music/Activity PiP and system Play/Pause mapping |
| [SP-030](SP-030-background-music-and-activity-system-controls.md) | in progress; app+extension build; G0/device AC open | Home/Lock Screen Now Playing and Activity Live Activity; no overlay above other apps |
| [SP-029](SP-029-v040-sophy-lady-wisdom.md) | in progress; panel, character and handoffs added; release and device acceptance open | v0.4.0 Sophy/Lady Wisdom, approved actions, Notes enhancement and Hugging Face |
| [SP-025](SP-025-v030-compound-ink-and-stroke-editing.md) | implemented; simulator verified; physical acceptance pending | v0.3.0 compound ink and stroke editing |
| [SP-026](SP-026-v030-lock-authentication-and-lifecycle.md) | in_progress; simulator verified; physical acceptance pending | v0.3.0 authentication and independent lock sessions |
| [SP-027](SP-027-v030-notes-lock.md) | in_progress; simulator verified; physical acceptance pending | v0.3.0 Notes lock |
| [SP-028](SP-028-v030-collections-lock.md) | in_progress; simulator verified; physical acceptance pending | v0.3.0 Collections lock |
| [SP-024](SP-024-v022-study-material-and-canvas-fixes.md) | simulator verified; physical acceptance pending; release authorized | v0.2.2 Collections and Canvas fixes |
| [SP-001](SP-001-product-and-device-decisions.md) | done; owner closed 2026-10-04 | Product scope and delivery sequence closed at M9 |
| [SP-002](SP-002-free-scripture-access.md) | done | WEBP baseline verified; preferred editions conditional; import plan documented |
| [SP-003](SP-003-scripture-ink-layout.md) | done | Renderer/layout decision and native validation plan; no implementation |
| [SP-004](SP-004-freeform-notes.md) | done; owner closed 2026-10-04 | Editor design delivered through SP-013 |
| [SP-005](SP-005-data-and-quality-contracts.md) | done; owner closed 2026-10-04 | Data, recovery, and testing contracts closed for personal use |
| [SP-006](SP-006-native-canvas-experiment.md) | done | Bounded canvas experiment closed with owner-approved deferred checks |
| [SP-007](SP-007-collections-ui-slice.md) | done | Bounded Collections prototype; simulator and physical UI verification passed |
| [SP-008](SP-008-scripture-layout-validation.md) | done; bounded validation | All physical criteria owner-reported successful; production ink remains separate |
| [SP-009](SP-009-first-offline-scripture-reader.md) | done; revised acceptance | Offline WEBP Scripture reader; owner M2 closure |
| [SP-010](SP-010-licensed-offline-translations.md) | done; revised acceptance | Licensed offline translations and development cache authorization |
| [SP-011](SP-011-tab-shell-motion.md) | done; owner verified 2026-10-04 | Timed dock/slide/glow; owner accepted on iPad |
| [SP-012](SP-012-persistent-scripture-annotations.md) | done; owner accepted 2026-10-03 | Actual-reader layers, durable ink, recovery and annotation-only backup |
| [SP-013](SP-013-freeform-notes.md) | done; owner accepted 2026-10-01 | M4 Canvas/Page Notes, shared library, passage quotes and Notes-only recovery |
| [SP-014](SP-014-pencil-shapes-and-app-icon.md) | done; owner verified 2026-10-04 | Shared held-stroke shape refinement, Notes ruler and Sophia app icon |
| [SP-015](SP-015-collections-and-save-flow.md) | done; owner accepted 2026-10-02 | M5 persisted folders, No Folder, bookmark/gleaning save, move and cards |
| [SP-016](SP-016-companion-planning-and-contracts.md) | done; owner approved 2026-10-02 | M6 multi-provider BYOK, Companion/Quiz design, data/privacy/recovery contracts |
| [SP-017](SP-017-maintainability-hardening.md) | done; not selected | Closed at M9 without implementation |
| [SP-018](SP-018-companion-response-and-quiz-refinements.md) | done; owner verified 2026-10-04 | Markdown response contract, Original Language Analysis, Bible Quiz and Bible or False |
| [SP-019](SP-019-quiz-question-cache.md) | done; owner verified 2026-10-04 | Quiz Me cache and in-app replenishment |
| [SP-020](SP-020-activity-tracking.md) | done; owner verified 2026-10-04 | M8 Activity records, Reading timer, Reviewing import, history, insights and Files archive |
| [SP-021](SP-021-background-music.md) | done; owner verified 2026-10-04 | M8 offline music wiring; commercial track catalog not approved |
| [SP-022](SP-022-meditation-journey.md) | done; owner verified 2026-10-04 | M8 Meditating fullscreen journey |
| [SP-023](SP-023-chapter-hub-and-contextual-ask.md) | implemented; hub 60/source follow-up 56 checks passed; owner acceptance pending | Chapter Hub, contextual Ask, model fallback and usable source links |

## Owner selection

See [How we develop Sophia](../docs/guidelines/ai-structure-guidelines.md).
The M0–M9 baseline is closed. SP-023 is the owner-selected post-baseline follow-up.
SP-041–043 are owner-requested planning tickets, not selected implementation. Recommended order: SP-042 Canvas transcription → SP-043 Canvas enhancement → SP-041 MCP read-only bridge; later surfaces/write/remote stages have explicit gates. Other new work requires owner selection.

## Readiness and completion

Statuses: draft, ready, in_progress, blocked, done. A ready ticket has enough confirmed
inputs for its stated work type; a ready research ticket is not authorization for app
implementation. Blocked tickets name their dependencies. Done requires actual evidence
for the acceptance criteria, not merely a generated document or code file.

Use stable numbered IDs and descriptive filenames. Each ticket includes purpose/type,
owner, requirement IDs, exact design links, dependencies, scope, acceptance criteria,
verification, documentation impact, and evidence. Add implementation files/modules when
known. Do not invent module paths or mark draft schemas as finalized to make work ready.
