# SP-058 — Plan floating controls and contextual editing

- Milestone: owner-selected Plan workflow refinement, 2026-11-02.
- Status: implemented; unit and Plan UI verification passed; final signed iPad installation/launch passed; physical owner and live-provider acceptance open.
- Intent: [TDD](../docs/tdd/tdd.md), [compatibility](../docs/guidelines/backward-compatibility.md).
- Execution: source-grounded planning followed by owner-authorized implementation and device delivery. No release selected.

## Scope and delivered behavior

1. Active Activity recorder and enabled Lady Wisdom remain above the fullscreen Plan, including reading. The root suppresses its covered instances. Timer expansion, pause/resume and drag reuse the shared control; Finish exits safely and opens the existing Stop Plan Activity flow.
2. Plan Edit retains one-tap Add section and adds **Add multiple sections… → count → Add sections**. Six adds six additional Days/Sections. Draft mutations preserve existing identities, assignments, completion and folders, with 200-section/2000-item limits. Cancel makes no change.
3. Share with Lady Wisdom explicitly attaches the saved Plan from its header or the character's in-chat Share this Plan button. The chat labels the attachment and discloses provider transmission. Context includes bounded title/section names/Scripture references only, excluding note/link bodies and protected Plans/folders, even when temporarily unlocked.
4. Sophy's `updatePlan` proposal appends a section count or grows to a total count and adds one or many Scripture assignments to numbered existing/new sections. Ambiguous destinations should prompt clarification; the validator requires explicit 1-based destinations. A single proposal may combine new sections and assignments, with at most 200 new assignments.
5. Preview lists resulting section count and new references/destinations. Confirm uses the existing atomic Collections writer, revision/access checks, reference validation and folder filing. Cancel writes nothing. Changed/deleted/archived/protected targets invalidate sharing. Plan edits cannot mix with other action types; re-share after a successful save.
6. Existing progress is preserved. Adding assignments at an active section summary opens its first new assignment while retaining the Activity session. Existing playback handles already-recorded sessions on subsequent Start.
7. Sophy journals new section/item IDs before saving and reconciles them after relaunch. Uncertain outcomes remain visible and never auto-retry.

## Ownership and compatibility

- PlanDetailView owns fullscreen shared chrome and explicit sharing; RootTabView supplies the shared Sophy environment object.
- PlanEditorDraft/View owns count entry and stable draft changes; CollectionsStore remains the sole Plan/folder writer.
- Sophy models/validator/session own the additive whitelist, bounded context, revision-bound preview and provider routing. Shared-Plan Scripture assignment requests bypass the ordinary open-Scripture shortcut.
- Sophy executor/repository owns receipts/reconciliation; History labels sections and references without exposing protected targets.
- No Plan schema, backend, signing identity, version, backup format or reset changes. Sophy recognizes the new action type and up to 400 new IDs (200 sections + 200 assignments). Older binaries can reject new Sophy history while retaining recovery generations; Plan data uses its existing format.
- No arbitrary-screen capture, deletion/shrinking, generated note bodies, new provider, commit/push/merge or release.

## Verification evidence

- Full unit regression: **510 passed, zero failures/skips** (`build/sp058/verified-retry.xcresult`, `verified-retry.log`). That combined run's initial UI attempt was subsequently corrected; it is not an overall green bundle.
- Subsequent batch checks: **2 passed**, including autosave/explicit-save/reopen with seven sections (`build/sp058/batch-dialog.xcresult`, unit portion). One case overlaps the full regression; the second adds a new durability check.
- Final fullscreen UI journey: **1 passed**, `build/sp058/dialog-touch-ui.xcresult` / `dialog-touch-ui.log`, **TEST SUCCEEDED**. Covers six added sections, saved/relaunched seven-section Plan, explicit sharing, character/timer hittability, pause, rotation, Stop Plan Activity and safe return.
- Existing daily playback/strict-schedule/History UI journey: **1 passed** (`build/sp058/final.log`). Combined earlier runs had corrected test-helper/setup failures; do not describe those bundles as wholly passing.
- Final signed build, strict signature/identity checks, in-place install and normal launch on iPad ni Paj: **passed** (`build/sp058/ipad-install-final.log`). Initial No Accounts/widget-profile failure was resolved after owner-confirmed Xcode sign-in.
- `git diff --check` and new local documentation link/path checks passed. Temporary synthetic diagnostics were removed before the final device build.

Simulator setup encountered Mach -308 and keyboard/accessibility timing failures. Final automation keeps confirmation inside the count dialog, waits for dismissal and verifies exactly seven sections, preventing a duplicate-add false pass. Simulator screenshots are supporting artifacts, not physical layout acceptance.

Owner walkthrough: [Plan context guide](../docs/testing/sp058-plan-context-guide.md). Real-provider interpretation/clarification quality and physical iPad layout/interaction remain owner checks. Installation establishes delivery, not those acceptance gates.
