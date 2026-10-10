# SP-029 implementation review and correction

Date: 2026-10-10. Scope: owner-requested audit and correction of the incoming Sophy implementation, with particular attention to the poor chat interface. This work does not publish v0.4.0 or close physical-device and live-provider acceptance.

The incoming implementation did **not** meet the ticket's acceptance criteria. Its 297 passing simulator unit tests established a baseline but did not exercise the defective orchestration, privacy and interaction paths below. Existing character illustrations and Hugging Face adapter work were retained.

## Findings corrected

| Priority | Incoming defect | Correction and source |
| --- | --- | --- |
| P1 | Ordinary requests automatically attached recent Notes content, without the required source review. | `Features/Sophy/SophySession.swift` keeps search local, excludes protected ancestry/mixed memberships, and sends excerpts only after the Review Context screen. Protection, membership and content changes invalidate attached context and late responses. |
| P1 | The provider prompt omitted action argument schemas, supported catalogs and theological boundaries. Malformed output was echoed into repair requests. | `Core/Sophy/SophyHandoff.swift` defines all allowlisted shapes and guardrails. The session provides catalog metadata and repairs the original request without echoing malformed output. Strict JSON validation remains the execution boundary. |
| P1 | Stop cancelled a dummy task; actual provider work could continue and publish a stale reply. | The session retains/cancels the actual completion task and checks generation, route and access after awaits. Explicit deleted provider bindings fail closed. |
| P1 | Enhancement used whole Canvas objects, lacked the required choices/consent and allowed stale replacements. | `SophyEnhancement.swift`, `SophyEnhancementSheet.swift` and `NotesSession` capture the exact native range, note revision and route; isolate provider context; enforce protected-selection consent; distinguish rating from replacement; and apply one undoable edit. Native Page/Canvas edit menus preserve Copy/Cut and add Enhance with Sophy. Invalid surrogate ranges are rejected. |
| P1 | Corrupt or missing journal/history generations could appear empty; subsequent saves could overwrite the last good recovery generation. Receipt failures could be reported as success. | `Infrastructure/Sophy/SophyFileRepository.swift` preserves validated previous generations and damaged bytes, blocks mutations when recovery is unavailable, and validates summaries. `SophyActionExecutor` preflights all saved actions, prepares receipts under one plan ID and propagates final persistence failures. Known partial saves are distinguished from uncertain outcomes. |
| P1 | Feature mutations could race an awaited Sophy save and be overwritten. | Activity and Collections guard interactive mutations while a Sophy commit is in flight, acquire the gate before draining queued saves and defer automatic linkage writes. Commands continue to validate current access before publishing durable results. |
| P2 | The cramped panel mixed messages, action fields and an unbounded inline History list. | `SophyChrome.swift` uses an adaptive chat sheet with distinct message bubbles, stable multiline composer, commands, route disclosure, Stop, source cards and separate History navigation. It opens at the large detent and can collapse. |
| P2 | Previews omitted descriptions, destinations, hierarchy, exact times and duplicate reuse choices. | `SophyActionPreview.swift` displays/edits those fields and requires explicit matching-folder resolution. Bible trees use the existing catalog. Manual activity no longer invents midnight, and impossible/ambiguous local times are rejected. |
| P2 | Slash dispatch discarded intent/options; chat handoff overwrote unsent text. | Natural-language and incomplete slash requests retain their command intent. Quiz/Contemplation use typed setup handoffs without Start. Chat preserves existing drafts and creates a separate conversation when available. Requested enhancement operation/tone is retained. |
| P2 | Backup support existed as an optional argument but Settings did not connect it. | Settings now exports/restores safe Sophy summaries. Backup history is validated before feature restore writes; absent legacy fields preserve local history. Pending Sophy requests are invalidated. Execution payloads/journals are excluded. |
| P2 | Historical closed periods were always called incomplete, and playback acknowledgments did not reflect actual state. | Insights compare the period end with the current clock. Music reports selected/playing/paused or failure from the existing Music session. |

## Verification evidence

Incoming baseline: `build/sp029-review/baseline.xcresult`, 297 unit tests passed.

Full final unit regression: `build/sp029-review/final-unit.xcresult`, **322 tests passed** with no failures/skips, including **25 new Sophy acceptance regressions**. UI-only `build/sp029-review/final-ui.xcresult` passed 3 checks (Sophy chat/History, enhancement choices and Activity workflow). The final Sophy-only rerun `build/sp029-review/final-sophy-ui.xcresult` passed both UI tests. The enhancement screenshot was visually inspected. Landscape interaction assertions pass, but the exported landscape image remains clipped/black despite waiting for rotation; landscape visual acceptance stays unresolved and must be reproduced on device or with a stable simulator capture. Earlier failed iterations remain in `build/sp029-review/`; they are not counted as passing evidence. The mixed unit/UI run `fixes-r7.xcresult` passed 319 unit tests and the chat UI test but had an app termination during Activity relaunch and a second-launch navigation/runner failure; The subsequent passing UI-only runs supersede that failed mixed-run evidence.
Follow-up polish (2026-10-10): preview cancel uses `cancelPreview()` so the chat stays open
without a Stop-style cancellation error; confirm validation keeps the preview visible; local
`/help` and `/bible-tree` show the owner message in the thread. Evidence:
`build/sp029-fix/post-correction.xcresult` (23 acceptance/product/command tests and 2 UI tests). New `SophyAcceptanceRegressionTests` cover provider payload isolation, schema disclosure, cancellation/late replies, safe repair, slash intent, History confirmation, explicit deleted routes, preserved chat drafts, rating safety, stale revisions, partial Canvas/list replacement/Undo, Unicode/surrogate/combining ranges, invalid local dates/DST, edited-duration accuracy, recovery preservation, explicit History clear after corrupt storage, corrupt journal refusal, whole-plan preflight, historical insights, backup compatibility/preflight, protected consent/relock and natural enhancement routing.

`SophyUITests` exercise default-off activation, chat/composer, local help, dedicated History and enhancement controls without real provider keys. Existing Notes, Collections and Activity workflow checks are selected for cross-feature regression. UI screenshots are attached to result bundles. Simulator checks do not establish Pencil/Scribble, biometric, notification or live model quality acceptance.

## Acceptance disposition and remaining gates

| Contract area | Source disposition | Remaining evidence or limitation |
| --- | --- | --- |
| Chat, History, commands and previews | Corrected and covered by focused automated checks | Owner review of final visual design; unresolved clipped landscape capture, wide/narrow windows, dark theme and large Dynamic Type/device checks. |
| Retrieval/privacy and selected text | Corrected with isolated prompts, consent and stale/access guards | Physical protection expiry, Pencil/Scribble/native selection menu and protected clipboard lifecycle; the guide’s exact selected-text zoom animation remains a polish gate. |
| Durable creation and recovery | Corrected with checked stores, preflight, receipts and no automatic replay | Exhaustive injected crash/failure boundaries and suspended-save interleavings remain a release gate. After a partial/uncertain result the user inspects History and requests remaining work; there is no automatic retry of the old plan. |
| Shared routing/Hugging Face | Existing adapter retained; explicit deleted bindings fixed | Owner-controlled live token/model checks for chat, quiz, Sophy planning and enhancement; provider-specific response quality. |
| Quiz, Contemplation, chat and music | Existing setup/player integrations retained and tightened | Physical playback, actual requested passage availability, active-workflow and notifications acceptance. Existing unsent chat drafts are preserved; the user clears/saves them before a new handoff. |
| Character | Existing seven illustrations retained; accessible movement/reset and Reduce Motion handling | Asset provenance/owner approval, requested richer motion and exact collision avoidance with all floating controls remain open. Current assets are 216×288 at 3x, below the guide's original 768×1024 source requirement. |
| Release readiness | In progress | Full-scheme UI regression, live provider and physical acceptance; release notes/version/tag/publication are not performed by this review. |

## Owner walkthrough

1. In Settings enable **Turn on Lady Wisdom**, tap Sophy and inspect chat in portrait/landscape and Split View. Type a multiline message with the keyboard visible; check that Send and Stop remain reachable.
2. Use `/help`, `/bible-tree`, `/history` and `/new-session`. Cancel a folder preview and verify no data changed. Repeat the Bible preview with existing matching folders and choose reuse/create explicitly.
3. Ask for a reminder with missing time and an activity with missing duration. Verify follow-ups, then review exact timezone/date/time/mode before saving. Check notification status separately from the saved reminder.
4. Use `/find` to locate a plain note. Inspect/remove excerpts in Review Context before sending. Protect a source or its ancestor while a request is pending; its content/result must disappear. Protected items stay excluded even when unlocked.
5. In a Page and Canvas text object select a middle phrase and choose **Enhance with Sophy**. Try Grammar, every tone, Organize, Expound and Rate. Compare the original/suggestion, Copy, Replace, then Undo. Rate must never offer Replace.
6. Repeat with an accessible protected selection. Sending requires fresh consent, surrounding text is excluded, and relock/background cancels the result. Edit outside the selected range during a request; replacing that stale revision must fail.
7. Prepare quiz, Contemplation and chat requests. Review existing setup; no workflow starts or message sends automatically. Existing chat drafts and active Activity are preserved.
8. Open History, inspect a result, delete one summary and confirm Clear. Study items remain. Export/restore a full backup and verify summaries return without replaying actions.

Do not mark SP-029 complete until remaining acceptance evidence is recorded explicitly.

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

## v0.4.0 release follow-up — 2026-10-10

Full-release verification found a stale repair fixture after incoming plain-text reply
support. The malformed fixture now uses invalid JSON; a separate regression establishes
that a bounded plain reply completes without a repair/action. Reminder retry tests inject
notification synchronization to avoid requesting OS permission from a unit test; production
uses the real service by default. The first run was interrupted at that permission prompt.

The next run passed 341 unit tests and enhancement UI, but failed two UI assertions:
rotation assumed a landscape-shaped multitasking window, and the character containment
check failed although its image remained visible. Rotation now checks composer containment
and interaction in the actual app window. The character's TimelineView has an explicit
72×96 frame to bound its hit area. Final verification is recorded in v0.4.0 release notes;
these failed attempts are not counted as acceptance passes.

Diagnostic `build/v040/ui-frames.xcresult` established the containment failures' cause:
XCTest's `app.windows.firstMatch.frame` was `(0,0,0,0)` while `app.frame` was 1180×820
(landscape) or 820×1180 (portrait). Composer and character frames lay inside those actual
application bounds. The checks now use `app.frame`; they still assert full containment
and actual tapping. The animated character also retains the explicit 72×96 layout bound.

`ui-final.xcresult` passes relaunch/character containment and enhancement. Its chat test
stopped in setup after an intermittent Settings toggle tap failed to enable the character.
The helper now verifies the switch's on value and retries once only if it remains off.
The separate final chat rerun records interaction, rotation containment and History.
