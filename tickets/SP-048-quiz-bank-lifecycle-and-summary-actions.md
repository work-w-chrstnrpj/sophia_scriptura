# SP-048 — Persistent ready Quiz Me bank and matching summary actions

Status: implemented, simulator-verified and installed/launched on iPad;
physical acceptance open; included in owner-selected v1.3.2/build 27, 2026-10-18.
Milestone: post-v1.3.1 Quiz Me reliability. Owner selected both fixes directly.

## Source-grounded findings and plan

The bank already lives in CompanionSnapshot.cachedQuizQuestions / checked generation
files, schema 3. No intentional app-exit clearing was found; actual owner-data loss
is not reproduced. Buckets are partitioned by provider configuration, adapter, model,
edition, prompt contract, type and difficulty. Changing those inputs selects another
bank rather than clearing the old one. Removing a provider explicitly removes its bank.

Two confirmed wait boundaries: cold exams previously filled a bucket to 100 before
checking whether enough questions existed; warmup also exhausted a bucket before
serving other buckets. Successful refill writes were scheduled without waiting for
the batch's save before requesting more. The summary Done control styled its text
before an outer width frame, unlike Quiz again's expanding label.

Implementation sequence:
1. Keep schema/storage and validated provider-generation ownership. Minimum readiness
   target is 100 per existing bucket, maximum capacity 200. Below 100, background
   work fills toward 200. Above the minimum, replace reservations by their consumed
   counts (up to 200), without discarding existing surplus.
2. Reserve ready questions synchronously into the session, schedule replacement on
   start/Again/exam before awaiting the local reservation save; never await a provider
   response if the selected ready bank is sufficient.
3. Make buckets playable first, then refill eligible buckets in round-robin batches
   of at most 10. Reprioritize at batch boundaries. Keep per-bucket generation dedup,
   independent bucket failures and bounded retry; new quiz intent can cancel backoff.
4. Cold standard/exam starts generate only the missing count. Cold requests share the
   bucket coordinator with refill so simultaneous generation is coalesced. Save each
   validated merged batch before the next request. Missing/provider-failed preparation
   keeps already prepared records. Loaded unused records survive restart.
5. Prevent repeated view loads from overwriting a live in-memory session with an
   earlier snapshot. Reconcile on load, foreground return, start/Again/finish/quit
   and provider/settings events. Keep the selected edition when scheduling work.
6. Give Quiz again and Done identical expanding label geometry, then retain their
   existing secondary/primary styling. Correct stale Quiz Me defaults help text.

## Boundaries and acceptance

No schema migration, reset, question recycling, backend, external queue, new provider,
removal of theological/duplicate/content validation. Release/tag was separately selected
by the owner as v1.3.2 on 2026-10-18. This is event-driven
in-app work; iPadOS can suspend/terminate network generation. Local prepared records
remain, and foreground reconciles demand. A missing bank/provider key/network still
requires preparation; the 100 minimum is a replenishment target, not a start gate.
A ready start still commits local reservation/session state for durability.

Tests: surplus retention/cap200 and scope separation; ready quiz/Again/exam returns
while provider stream is blocked, refill begins before completion; below-minimum
reservation asks for high-water refill; restart/second load preserve unused bank and
reserved session records; cold exam with24 needs1, not100; fair playable-first and
exact consumed-deficit replenishment; existing Companion/provider/quiz regression.
Summary portrait/landscape screenshots verify equal actions. Test artifacts under
`build/sp048/`; physical perceived latency, real-provider factual quality, interruption,
VoiceOver/Dynamic Type and iPadOS suspension acceptance remain owner checks.

## Verification so far — 2026-10-18

- `build/sp048/all-unit-r3.xcresult`: **414 unit tests passed**, zero failures.
  The initial full run exposed a provider-routing test's background refill leaking
  into the following test's shared HTTP stub. Async teardown now cancels and awaits
  its sessions' refill work before replacing the stub; the original routing
  assertions remain intact. The final full run passed with that isolation fix.
- `build/sp048/final.xcresult`: **58 focused tests passed**, zero failures across
  CompanionTests, QuizBankLifecycleTests and QuizMeTimerTests. Coverage includes
  gated-provider ready starts/Again/exam, refill-on-reservation before completion,
  persisted unused/session records, repeated-load protection, capacity/scope,
  cold exam24→25 requesting1, fair playable-first batches, exact replacement and
  disk persistence before the next blocked provider request.
- Portrait/landscape summary renders from the final QuizSessionView were exported
  and visually inspected: Quiz again and Done have equal full-width capsule
  geometry. These are hosted-view fixtures, not full-app live-provider UI journeys.
- The first run exposed a rigid mock returning a full mixed quiz to a smaller
  per-type request; the fixture now follows actual requested type/count contracts.
  Final focused run passed after that correction.
- Installer dry-run passed, but signed build failed before installation: Xcode
  reported No Accounts and a missing development profile for
  `com.personal.SophiaScriptura.StudyActivityWidget`. Existing app/data preserved.
  Evidence: `build/sp048/ipad-install.log`. User account/signing action is needed;
  no signed device build, install or launch is claimed for these fixes yet.
- After the owner confirmed Xcode sign-in, the installer dry-run passed again but
  the live retry still reported No Accounts and no widget development profile.
  Project signing remains Automatic with existing team `LMHJKZ2N43` for both app
  and extension. No signing configuration was changed and nothing was installed.
  Retry evidence: `build/sp048/ipad-install-retry.log`.
- Final retry passed signed Debug build, strict signature/bundle identity checks,
  in-place install and normal launch on `iPad ni Paj`. Existing study data preserved;
  version remains 1.3.1/build 26. Signing blocker resolved without source changes.
  Evidence: `build/sp048/ipad-install-retry2.log`. Physical feature acceptance and
  real-provider quality/latency checks remain open.

## v1.3.2 release gate — 2026-10-18

Owner separately selected commit/push/merge/publication as v1.3.2/build 27. Final
simulator build and all 414 unit tests passed with zero failures/skips using Xcode 27.0
and iPad (A16) / iOS 27.0. Result: `build/v132-release/verification.xcresult`;
summary: `build/v132-release/summary.json`. Fresh portrait/landscape hosted summary
attachments were exported and visually reviewed for matching action geometry.
Documentation/link/whitespace checks passed. This source release preserves the open
physical/provider/suspension acceptance above; it does not claim a v1.3.2 device install.
