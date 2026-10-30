# SP-056 — Select a Plan Day and simplify dates

- Milestone: Collection Plans, owner-selected follow-up, 2026-10-30.
- Status: implemented; simulator verified; signed iPad install/launch verified; physical owner acceptance open.
- Intent: [TDD](../docs/tdd/tdd.md), [Plan contract](../docs/data/collection-plans-contract.md), [compatibility](../docs/guidelines/backward-compatibility.md).
- Ownership: PlanDetailView presentation; PlanSchedule cursor resolution; PlanPlaybackService shared commands; ActivityStore and ActivityFileRepository timer durability.

## Scope and acceptance

1. Plan contents show exactly one due/completion caption per scheduled Day, below its assignments. Remove the aggregate caption immediately after the last Day; Edit retains the separate Plan-level summary.
2. Day headings in contents/reading contain only the Day/section title, without appended dates.
3. Clicking a nonempty Day heading starts/resumes that exact Day through the same PlanPlaybackService used by Play/Resume. An empty or archived Day cannot start. Complete assignments commit History with the selected Day's name/type, then show congratulations and exit. Stopping halfway retains checks and no History.
4. Switching between Days of the same Plan pauses and retains the previous Day's time without a partial record. Selecting it again restores its session. Unrelated active activities still block playback. A completed Day may be reread by selecting its heading, preserving original completion timestamps and recording only a finished replay.

## Implementation and compatibility

The duplicate was the last Day's caption followed by the aggregate Plan caption, often identical. Contents removes the aggregate and uses plain title buttons with stable accessibility IDs. Both title and main Play/Resume call the same start command, with an optional selected section ID. Selected playback resumes that Day's cursor/first unfinished assignment, or starts a completed Day's reread without resetting checks.

ActivitySnapshot adds optional `pausedPlanDrafts`; old files/backups decode nil. Only one draft runs. On a same-Plan Day switch the Activity writer atomically pauses/stores the outgoing draft and resumes/creates the incoming one. Failed writes retain the previous committed Activity state. Stored paused drafts must have unique session/Plan-Day identity, no running clock and no History collision. Backup codecs preserve them; mode canonicalization and time-overlap guards include them. Existing Delete All Activity clears them with the active draft/records. No new backend/store or schema version, user-data conversion/reset, commit/release, or unrelated feature is selected.

## Verification and gaps

Initial full native unit suite: **499 passed, zero failures/skips** (`build/sp056/units.xcresult`). New tests cover explicit Day 2 before Day 1; switching/paused seconds/checks/session identity across reopen; completed-Day replay; invalid/empty Day rejection; legacy decode/new archive round-trip and duplicate draft rejection. Final run additionally checks clearing paused Activity state and focused UI date counts/title labels, targeted chapter and completed History.

Final-source combined run: **499 unit tests and two UI journeys passed, zero failures/skips**
(`build/sp056/final.xcresult`, `final.log`). UI selects Day 2 before Day 1, confirms Genesis 2,
plain Day labels, exactly two captions for two Days/no aggregate footer, completed named
History and the partial-day relaunch/no History journey. Signed Debug build, strict
signature/identity checks, in-place iPad install and normal launch passed (`device-install.log`,
`device-launch.log`). Documentation local links and `git diff --check` passed. No commit,
release/version bump, user-data conversion or reset occurred. Physical owner/accessibility/landscape acceptance remains open; the previously recorded device UI-runner signing limitation remains separate from signed app delivery.

Final result-bundle summary confirms `Passed`, **501/501 passed**, zero failed/skipped
(`build/sp056/summary.json`); xcodebuild returned TEST SUCCEEDED. The selected-Day completion
screenshot was visually reviewed: plain headings and one date caption per Day, no repeated
footer. Physical interaction/landscape/accessibility acceptance remains open.


## Owner-selected release — 2026-10-30

The owner authorized commit, push, merge and source publication with the other Plan,
Collections and Prayer fixes as [v1.6.0/build 30](../docs/releases/v1.6.0.md). This supersedes
earlier unselected-release statements in this ticket; physical/provider acceptance gaps
remain. Final release-candidate/hosted evidence is recorded in the development plan and
release notes; no personal-data conversion/reset is part of publication.
