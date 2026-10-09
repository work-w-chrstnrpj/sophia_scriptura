# SP-026 — v0.3.0 lock authentication and lifecycle

Status: in_progress; source implemented under owner selection 2026-10-07/08; simulator verification recorded below; physical-device acceptance remains open.
Type: feature/security foundation. Target version: v0.3.0. Existing baseline: v0.2.*.
Milestones: M4/M5/shared shell follow-up. Owners: Security, System Architect, storage, SQA.
Requirements: owner-requested Notes and Collections locks; REQ-009/010 integration.
Dependencies: SP-013/015 data and recovery contracts. Consumers: SP-027 and SP-028.
Release: [v0.3.0 release](../docs/releases/v0.3.0.md). Intent: [TDD](../docs/tdd/tdd.md).

## Confirmed product contract

Touch ID authentication with a password backup protects selected notes/collections.
One successful unlock grants access to all protected items in that category. Notes and
Collections are independent: category-specific unlocking or manually locking one does not
change the other. The explicit combined Settings actions below target both categories.
All protected items in a category relock together after 10 minutes idle, and every fresh
app launch starts both categories locked. Removing protection requires unlocking first.
Archive/Delete remain allowed when locked; rename/color/settings changes are denied.
Each category has a top settings/command-bar lock control: authenticate to unlock its
protected items, or immediately lock them all when currently unlocked. Opening a protected
item is the second unlock entry point and resumes that intended navigation on success.

## Combined Settings controls — owner requested 2026-10-07

Settings also exposes **Lock All Notes & Collections** and **Unlock All Notes & Collections**.
Lock All immediately revokes both category sessions without authentication, conceals any
protected open content, and invalidates pending authentication requests in both categories.
Unlock All uses one successful Touch ID or backup-password authentication to grant both
category sessions together. Failure or cancellation grants neither session and preserves
existing access, subject to normal idle expiration. A stale result after Lock All cannot
unlock either category. Combined unlock starts both idle deadlines from the successful
operation; subsequent activity follows the resolved category inactivity policy.

These actions apply to items already marked protected; they do not add/remove item
protection, change passwords, or make unprotected items require authentication. Category
controls remain independent after a combined action. Represent fully locked, partially
unlocked and fully unlocked states explicitly. Enable Lock All when either category has
an active protected-item session; enable Unlock All when either category has protected
items awaiting unlock. Disable unavailable actions and explain when no items are protected.

Implement combined commands in the shared coordinator and Settings UI, with a single
validated authentication result and coherent publication of both session grants. If
separate passwords are chosen, resolve how one fallback authentication authorizes both
categories before implementation; never silently require two prompts for Unlock All.

## Architecture and implementation sequence

1. Resolve decisions below and record the security/UX contract before product coding.
2. Introduce shared authentication services with separate Notes/Collections session state,
   injected clock and authentication adapters. LocalAuthentication handles biometrics;
   custom password verification is distinct from the device passcode. Inspect the existing
   `Infrastructure/Security/ScriptureKeychain.swift` for conventions, without reusing its
   licensed-content credentials. New service paths are an implementation decision.
3. Persist per-item protection flags and credential configuration, never session-unlocked
   flags. Legacy records decode unprotected. Keep credentials in device-only Keychain;
   store no plaintext password and use a reviewed salted, slow verifier/KDF. Password
   changes/removal require authentication; reject empty setup and verify confirmation.
4. Gate commands in NotesSession/CollectionsStore and all navigation at the application
   boundary, beyond merely hiding menus. RootTabView owns lifecycle propagation.
5. Track genuine user activity and compute deadlines from elapsed time; rendering, music,
   autosave and provider updates do not reset inactivity. Recheck deadlines before access
   and on foreground return, not just timer callbacks. Start locked after termination/crash.
6. Revoke access and dismiss/obscure protected editors, sheets, previews and pending routes
   when a session locks. Preserve accepted edits through the existing durability mechanism;
   do not discard dirty content or reveal it through a save-error screen.
7. Specify backup/restore, search/thumbnail/share protection and stale-authentication handling;
   integrate both category tickets and validate real-device biometrics.

Use a session generation to reject late authentication success after manual lock, timeout,
background policy changes, restore/reset or item deletion. Cancelled/failed biometric or
password attempts never unlock; one prompt at a time; provide password fallback for absent,
unavailable or locked-out Touch ID. Rate-limit password guesses without erasing study data.

## Selected implementation policy — 2026-10-07/08

The owner selected implementation of SP-026–028 together and explicitly chose app access locks with existing storage/backup formats. The remaining implementation choices follow the ticket's proposals: one shared password; independent category activity/deadlines; elapsed-time foreground expiry; protected ancestor routes without inheriting Note protection; titles/type/dates visible with content, tags, descriptions, counts and body search concealed. No Folder cannot be protected. On 2026-10-08 the owner removed the visible “Sophia · Protected” window cover so opening the app no longer shows that screen. Idle tracking, background cancellation and foreground expiry remain.

Credential recovery fails closed: original device-only Keychain verifier required; protected backups are not credential-portable; matching bindings survive legacy restore; no unauthenticated reset. Touch ID/Face ID can authenticate a password change, which preserves bindings and relocks both categories. Protected store schemas prevent older apps decoding away flags. Complete guarantees, limitations and primary platform references: [item-protection contract](../docs/security/item-protection.md).

## Acceptance and verification

- [ ] Biometric/password success unlocks every protected item in the requested category;
  failure/cancel/lockout leaves both sessions' existing states correct.
- [ ] Category-specific Notes unlock does not unlock Collections, and vice versa; manually relocking one
  preserves the other category's session.
- [ ] Settings Lock All locks both categories from fully/partially unlocked states without
  an authentication prompt; protected editors conceal content and pending auth is invalidated.
- [ ] Settings Unlock All uses one Touch ID/password authentication to unlock both categories;
  cancellation/failure preserves prior access and stale success cannot defeat Lock All.
- [ ] Combined actions preserve protection flags and unprotected-item access; category controls
  remain independent afterward. UI labels/action availability cover all session combinations
  and categories with no protected items. Verify combined controls on the physical iPad.
- [ ] Injected-clock tests cover just before/at/after 600 seconds, genuine activity,
  background time, late auth results and simultaneous requests. Fresh launch locks both.
- [ ] Open editors are concealed on relock without loss of saved/dirty study content.
- [ ] Protection removal and password changes require authenticated state; mutations and
  alternate routes cannot bypass it. Locked archive/delete remain usable with existing confirmations.
- [ ] Decode legacy records, round-trip flags, invalid credentials, Keychain loss, backup
  restore and downgrade cases match the documented policy; prior generations are retained.
- [ ] Device tests verify actual Touch ID success/cancel/failure, password fallback, lock
  controls, idle/relaunch and background-preview behavior. Simulator mocks do not prove Touch ID.

Stop before implementation if credential recovery, archive exposure or encryption guarantees
remain ambiguous. No secret values in logs/tests/exports. No biometric data is stored by the app.
Documentation: [item-protection contract](../docs/security/item-protection.md), Notes contract, TDD, testing specification, roadmap and release plan updated. Automated evidence is recorded below; physical-device acceptance is separate.
Reference: [Apple LocalAuthentication](https://developer.apple.com/documentation/localauthentication).

## Implementation evidence — 2026-10-08

Implemented together under the owner-authorized SP-026–028 scope. See [the protection contract](../docs/security/item-protection.md) for chosen app-access guarantees, device-only credential recovery, ancestor/privacy rules and backup compatibility. Native accepted buffers flush before concealment; category grants and combined controls do not mutate protection flags. Notes/Collections command boundaries enforce locks, including settings, filing and backups. Protected metadata uses Notes schema 4 / Collections schema 2 with legacy defaults and matching bindings retained on restore.

Simulator evidence on 2026-10-08, iPad (A16): `ItemProtectionTests` **27 passed, 0 failed** in `build/sp026-028/unit.xcresult`; signed `ItemProtectionUITests` **1 passed, 0 failed** in `build/sp026-028/ui-signed.xcresult`. An unsigned UI run cannot open the Keychain and is not acceptance evidence. Physical Touch ID/Face ID, real Pencil/keyboard buffers, ten-minute device inactivity, app-switcher snapshots and accessibility remain **Not Run**. These tickets are not marked done on simulator evidence alone. That implementation check predates the owner-authorized 2026-10-09 v0.3.0 release; it does not establish physical acceptance.
