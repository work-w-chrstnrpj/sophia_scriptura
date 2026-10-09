# SP-028 — v0.3.0 Collections lock

Status: in_progress; source implemented under owner selection 2026-10-07/08; simulator verification recorded below; physical-device acceptance remains open.
Type: feature. Target version: v0.3.0. Existing baseline: v0.2.*.
Milestone: M5 follow-up. Owners: Frontend, Security, storage, SQA.
Requirements: REQ-010 plus owner-requested collection privacy lock.
Dependencies: [SP-026](SP-026-v030-lock-authentication-and-lifecycle.md); SP-015.
Cross-feature acceptance: [SP-027](SP-027-v030-notes-lock.md).
Design: [Collections](../docs/design/collections-screen-specification.md).
Release: [v0.3.0 release](../docs/releases/v0.3.0.md).

## Scope and visible outcome

Add persistent protection to individual collections. While the Collections session is
locked, protected folder cards show a lock icon and gray appearance; long-press omits
Edit Collection settings, and rename/color/settings commands are denied. Archive and
Delete remain allowed with existing confirmations and membership recovery semantics.
Opening any protected collection prompts Touch ID or backup password, then opens that
folder and unlocks all protected collections. The top settings/command-bar Collections
lock control authenticates to unlock all, or immediately force-locks all. Removing a
collection's protection requires Collections unlock first.

Category-specific Collections unlock leaves the Notes session unchanged. A separately protected member note
requires Notes unlock when opened; category-specific Notes unlock leaves protected Collections locked.
All protected collections relock together after 10 idle minutes or app restart.
A session unlock does not remove persistent protection. Show accessible state labels and
restore configured folder colors when unlocked; removing protection clears the badge.

Settings also provides combined Lock All Notes & Collections and Unlock All Notes &
Collections under SP-026. Combined lock revokes both sessions immediately; combined unlock
authenticates once for both. These commands retain per-item protection flags and leave
unprotected items accessible. Category-specific controls remain independent.

## Source ownership and implementation sequence

1. Locate `StudyCollection` and add optional/defaulted protection metadata; extend validated
   `Infrastructure/Collections/CollectionsFileRepository.swift` persistence/recovery.
2. Guard settings/rename/color/protection-removal and folder access in
   `Features/Collections/CollectionsStore.swift`; keep archive/delete behavior recoverable.
3. Integrate `CollectionsView.swift` cards, context menus and top lock control, and
   `CollectionDetailView.swift` navigation and relock dismissal with SP-026.
4. Audit folder breadcrumbs, nested folders, search, destination pickers, moves/assignments,
   Add Study Material and root callbacks for protected-folder access/mutation bypasses.
   Determine which picker metadata and assignment operations remain usable under the
   confirmed SP-026 policy; hiding a context menu alone is insufficient.
5. Verify locked folder archive/delete does not delete member notes/conversations or clear
   their independent protection. Recovery retains protection metadata.

## Acceptance and verification

- [ ] Protected folders preserve flags through reopen and archive/trash/restore; legacy data
  defaults unprotected without resets or changed memberships.
- [ ] Locked gray cards/icon and accessible state render correctly; Edit Collection settings
  is absent while locked and rename/color commands fail at the store boundary.
- [ ] Archive/delete remain available for locked folders under existing confirmations;
  member artifacts and independent note locks follow existing recovery semantics.
- [ ] Item-open and top control authenticate once for all protected Collections; force-lock,
  10-minute idle and fresh launch relock the category together.
- [ ] Notes and Collections stay independent in every combination of locked/unlocked state;
  protected member notes are gated separately when opened.
- [ ] Combined Settings actions update this category alongside the other; one successful
  authentication grants both, while cancel/failure grants no new access. Independent controls
  still work afterward; mixed session states and unprotected items behave as specified.
- [ ] Nested/breadcrumb/search/picker/add-material routes obey the resolved inheritance and
  mutation contract; relock closes or obscures existing protected detail views.
- [ ] Unit/UI tests cover metadata, guards, mixed folder states, memberships and alternate
  routes. Owner iPad tests Touch ID/password, long-press, card appearance, timers and relaunch.

Resolve nested-folder inheritance and virtual No Folder behavior under SP-026 before
implementation. Exclusions: automatically adding note protection from folder membership,
per-item unlock sessions, Companion locks. Stop on route bypass, recovery loss or ambiguous
inheritance. Update Collections design/persistence/security/test docs and release evidence.
Evidence: planning only; no implementation or tests run.

## Implementation evidence — 2026-10-08

Implemented together under the owner-authorized SP-026–028 scope. See [the protection contract](../docs/security/item-protection.md) for chosen app-access guarantees, device-only credential recovery, ancestor/privacy rules and backup compatibility. Native accepted buffers flush before concealment; category grants and combined controls do not mutate protection flags. Notes/Collections command boundaries enforce locks, including settings, filing and backups. Protected metadata uses Notes schema 4 / Collections schema 2 with legacy defaults and matching bindings retained on restore.

Simulator evidence on 2026-10-08, iPad (A16): `ItemProtectionTests` **27 passed, 0 failed** in `build/sp026-028/unit.xcresult`; signed `ItemProtectionUITests` **1 passed, 0 failed** in `build/sp026-028/ui-signed.xcresult`. An unsigned UI run cannot open the Keychain and is not acceptance evidence. Physical Touch ID/Face ID, real Pencil/keyboard buffers, ten-minute device inactivity, app-switcher snapshots and accessibility remain **Not Run**. These tickets are not marked done on simulator evidence alone. That implementation check predates the owner-authorized 2026-10-09 v0.3.0 release; it does not establish physical acceptance.
