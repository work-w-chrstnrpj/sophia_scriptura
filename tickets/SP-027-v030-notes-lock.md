# SP-027 — v0.3.0 Notes lock

Status: in_progress; source implemented under owner selection 2026-10-07/08; simulator verification recorded below; physical-device acceptance remains open.
Type: feature. Target version: v0.3.0. Existing baseline: v0.2.*.
Milestone: M4 follow-up. Owners: Frontend, Security, storage, SQA.
Requirements: REQ-009 plus owner-requested note privacy lock.
Dependencies: [SP-026](SP-026-v030-lock-authentication-and-lifecycle.md); SP-013.
Design: [Notes](../docs/design/notes-screen-specification.md).
Contract: [Notes](../docs/data/notes-contract.md).
Release: [v0.3.0 release](../docs/releases/v0.3.0.md).

## Scope and visible outcome

Add persistent protection to individual notes across Canvas/Page/Journal/Prayer. While the
Notes session is locked, protected cards/list rows show a lock icon and gray appearance;
long-press omits Edit Note settings, and rename/color/settings commands are denied.
Archive and Delete remain available through existing confirmations/Trash semantics.
Opening any protected note prompts Touch ID or backup password, then opens the requested
note and unlocks all protected notes. Other protected notes open without repeated prompts.
The top settings/command-bar Notes lock control unlocks all through authentication, or
force-locks all immediately. Removing a note's protection requires Notes unlock first.

Locked versus protected are distinct: after session unlock the protection flag remains.
Use accessible labels to indicate current lock state; gray color alone cannot carry meaning.
Unlocked protected cards regain their configured color; removing protection clears the badge.

Settings also provides combined Lock All Notes & Collections and Unlock All Notes &
Collections under SP-026. Combined lock revokes both sessions immediately; combined unlock
authenticates once for both. These commands retain per-item protection flags and leave
unprotected items accessible. Category-specific controls remain independent.

## Source ownership and sequence

1. Add backward-compatible per-note protection metadata in `Core/Notes/NoteDocument.swift`
   and validated persistence/export handling in `Infrastructure/Notes/NotesFileRepository.swift`.
2. Guard open/edit/rename/color/protection-removal commands in `Features/Notes/NotesSession.swift`.
   Keep archive/delete allowed. Reject stale editor callbacks after session revocation.
3. Integrate `Features/Notes/NotesView.swift` cards, rows, context menus and top lock control
   with the independent Notes session; define set-lock and remove-lock settings flows.
4. Route every note entry point through the same check: Collections material, verse/chapter
   hubs, note links, create/open callbacks and restored editor state through RootTabView.
5. Apply the SP-026 confirmed preview/search/export policy and conceal open editors on relock.
   Canvas object position locks are separate from whole-note authentication.

## Acceptance and verification

- [ ] Protected notes retain flags after save/reopen, archive/trash/restore and approved backup
  recovery. Old records are unprotected; no app-data reset or lost note content.
- [ ] Card/list lock icon, gray locked appearance, accessible state and unlocked configured
  color work in light/dark mode. Locked menus omit Edit Note settings.
- [ ] Rename/color/settings and removal of protection cannot execute while locked, including
  bulk actions and direct session calls. Archive/delete of locked notes still work.
- [ ] Item-open and top lock control both unlock all protected Notes on successful auth;
  force-lock, 10-minute idle and app restart relock them together.
- [ ] Collections unlock never bypasses a protected note; all alternate note routes authenticate.
- [ ] Combined Settings actions update this category alongside the other; one successful
  authentication grants both, while cancel/failure grants no new access. Independent controls
  still work afterward; mixed session states and unprotected items behave as specified.
- [ ] Active editor relock preserves data and hides content; rejected/late auth cannot reopen it.
- [ ] Unit/UI checks cover metadata, command guards, mixed protected/unprotected bulk actions,
  menu visibility and routes. Owner iPad verifies Touch ID/password, Pencil/keyboard editing,
  10-minute idle, force-lock and quit/reopen across note types.

Exclusions: Collection session implementation (SP-028), per-stroke editing (SP-025),
per-item unlock sessions. Resolve SP-026 security/privacy decisions first. Stop on access
bypass or content loss. Update Notes contract/design/device guide and release evidence.
Evidence: planning only; no implementation or tests run.

## Implementation evidence — 2026-10-08

Implemented together under the owner-authorized SP-026–028 scope. See [the protection contract](../docs/security/item-protection.md) for chosen app-access guarantees, device-only credential recovery, ancestor/privacy rules and backup compatibility. Native accepted buffers flush before concealment; category grants and combined controls do not mutate protection flags. Notes/Collections command boundaries enforce locks, including settings, filing and backups. Protected metadata uses Notes schema 4 / Collections schema 2 with legacy defaults and matching bindings retained on restore.

Simulator evidence on 2026-10-08, iPad (A16): `ItemProtectionTests` **27 passed, 0 failed** in `build/sp026-028/unit.xcresult`; signed `ItemProtectionUITests` **1 passed, 0 failed** in `build/sp026-028/ui-signed.xcresult`. An unsigned UI run cannot open the Keychain and is not acceptance evidence. Physical Touch ID/Face ID, real Pencil/keyboard buffers, ten-minute device inactivity, app-switcher snapshots and accessibility remain **Not Run**. These tickets are not marked done on simulator evidence alone. That implementation check predates the owner-authorized 2026-10-09 v0.3.0 release; it does not establish physical acceptance.
