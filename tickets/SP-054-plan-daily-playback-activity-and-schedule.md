# SP-054 — Daily Plan playback, Activity and optional dates

- Milestone: Collection Plans, owner-selected follow-up (2026-10-30).
- Type/owners: feature + UI correction; Frontend, domain/persistence, SQA and documentation responsibilities handled in this chat.
- Status: implemented; simulator verified; signed iPad install/launch verified; physical owner acceptance open.
- Intent: [TDD](../docs/tdd/tdd.md), [Plan contract](../docs/data/collection-plans-contract.md), [compatibility](../docs/guidelines/backward-compatibility.md).
- Dependencies: existing SP-049/053 Plan writer, root Activity/Companion/Music sessions.

Current behavior is refined by [SP-055](SP-055-plan-creation-catch-up-and-prayer-actions.md): manual due-date controls are replaced by optional Catch up, and stopping an unfinished Plan activity no longer checks remaining assignments or adds History. The evidence below records the original SP-054 checkpoint.

## Selected scope and acceptance

1. Give Lock and Archived Plans separate spacing and consistent header icon sizing.
2. Answer existing archive behavior from source; do not introduce individual material archiving.
3. Place New conversation between Link and Music while reading. Use the existing Companion defaults, provider guardrails, local history and explicit Send. Show provider-setup failures without advancing the Plan.
4. Play/Resume reads only the current day/section. Previous stays within that section. Its last assignment ends the activity and shows a congratulations modal; Done exits the Plan. Another Resume starts the next incomplete day. A completed Plan requires explicit reset before replay.
5. Edit exposes Activity type (Reading for legacy/missing values, existing custom types supported). Playing starts a durable timer named `Plan title - Day/Section title`; completion appears in ordinary Activity History. Existing unrelated activities block Play without replacement. Early exit/background pauses; Resume retains the session and excludes paused time.
6. Strict plan mode defaults off. On: choose a start date, or anchor it at first Play; derive one calendar day per section in the stored time zone. Optional per-section overrides. Show dates beside section labels and small due/completion captions below assignments and at the Plan footer. Overdue sections remain playable.
7. Existing Plans/Activity files decode with absent fields. No store reset, user-data transformation script or schema bump. Existing item completion timestamps derive completion dates.

## Boundaries and failure handling

`Core/Plans/StudyPlan.swift` and `PlanSchedule.swift` own optional values, schedule derivation and start cursor resolution. `PlanPlaybackService` coordinates existing single writers; it does not persist a third store. `ActivityStore` owns awaited timer commands and History. A stable optional cursor session ID plus optional Activity Plan/section IDs support retry/relaunch. Progress commits before History on the last assignment; failure retains a summary and timer for retry, and exact session IDs prevent duplicate History or old records re-completing reset progress. Finishing the Plan timer through Activity completes that section when the playback service reconciles it (while open, or on Resume after returning). Notes must save before advancing/exiting. New conversation reuses the existing Companion screen without sending automatically or adding scripture/private context.

Exclusions: source release/commit/push, Plan Pencil layers/full reader lease, individual link/bookmark/gleaning archives and broader SP-052 acceptance. Strict schedule is optional date tracking, not access restriction. Existing unknown-field readers can open the formats but may discard new optional settings if they rewrite them; no downgrade preservation guarantee is added.

## Archive answer

`CollectionDetailView.row` provides Archive only for Notes. SavedLink/SavedPassage have no archive/trash timestamps. `deleteLink`/`deletePassage` remove records and memberships immediately. Archived Collection folders retain contents and can be unarchived through Collections → Archived collections. Plan tree Trash is a separate paired lifecycle that can retain exclusive materials; it does not add individual material Trash.

## Verification

- Build: `build/sp054/build.log` — initial build-for-testing passed.
- Final-source native suite: **491 unit tests + 2 focused UI journeys passed, 0 failures/skips** (`build/sp054/final-r2.xcresult`, `final-r2.log`). UI covers Notes/link/music regressions, completion/exit, relaunch, per-day Resume, strict date labels, conversation position/setup failure and both History records.
- Manual owner checks: physical portrait/landscape spacing, conversation with configured provider, custom activity types, overdue dates, background/pause/Resume and Activity completion. No live provider request or personal-data mutation is part of simulator checks.

## Owner-authorized physical follow-up

The owner subsequently authorized iPad testing. `iPad ni Paj` is paired, unlocked and in
Developer Mode. Signed `build-for-testing` failed because Xcode has no signed-in account
and no provisioning profile for `com.personal.SophiaScripturaUITests.xctrunner`
(`build/sp054/device-build.log`). App-only signed build, strict signature/identity checks and in-place installation passed
through the installer (`build/sp054/device-install.log`). A normal launch with
`SOPHIA_LAUNCH=user` passed (`build/sp054/device-launch.log`). Existing 1.5.0/build 29
metadata remains unchanged. No uninstall, data reset or explicit content sync occurred.
No automated physical pass is claimed.

## Final verification and remaining acceptance

The first combined run passed 491 units and failed both UI cases: one existing assertion
needed scrolling after the editor gained settings; the new case exposed the shared
Companion alert replacing the Plan. Final source clears that shared notice synchronously
and keeps the setup error inside the Plan. A second combined run passed **all 493 tests**.
The same final product source passed signed build/identity validation, installed in place
and launched normally on the physical iPad. Documentation links and `git diff --check`
passed. No commit, push, release, version change, user-data transformation or reset occurred.

Met in simulator/source: all seven scoped acceptance items above, including backward
compatibility and error recovery. Remaining: physical interaction/landscape/accessibility
acceptance, configured-provider conversation quality and UI automation after signing setup.
These gaps do not close the broader SP-050/051/052 acceptance gates.

Final bundle summary: `result=Passed`, 493/493 passed, zero failures/skips
(`build/sp054/summary.json`). Fullscreen reader/control order and the day-completion
modal/strict-date screen attachments were visually inspected under
`build/sp054/final-ui-attachments/`. Xcode's optional post-test `simctl diagnose` collection
stalled after all tests ended; only that child diagnostics process was stopped. The test
runner exited normally (0), xcodebuild finalized the bundle and returned **TEST SUCCEEDED**.


## Owner-selected release — 2026-10-30

The owner authorized commit, push, merge and source publication with the other Plan,
Collections and Prayer fixes as [v1.6.0/build 30](../docs/releases/v1.6.0.md). This supersedes
earlier unselected-release statements in this ticket; physical/provider acceptance gaps
remain. Final release-candidate/hosted evidence is recorded in the development plan and
release notes; no personal-data conversion/reset is part of publication.
