# Notes and Collections app access locks (SP-026–028)

Implementation selected by the owner on 2026-10-07/08. The owner explicitly selected app access locks with existing storage formats, rather than content/backup encryption.

## Guarantees and boundaries

A nullable `protectionID` on each NoteDocument/StudyCollection binds protection to the original lock credential. Missing metadata decodes unprotected. Protection never changes when access is locked or unlocked. Canvas object position locks remain a separate feature.

One Sophia password backs up Touch ID/Face ID, with independent, memory-only Notes and Collections grants. Item opens and category controls grant that category; Settings Unlock All grants both with one authentication. Settings Lock All immediately revokes both without authentication. Lock All is available only while a category that still has protected items is unlocked. Unlock All is available only while a category with protected items is still locked. Both stay disabled, with an explanation, when nothing is protected. Category controls stay independent after a combined action. Archiving, trashing, or deleting an item cancels a pending authentication only when that request includes the item's category. These actions do not add/remove protection on plain records. Each category expires after 600 seconds without genuine user input in that category. App relaunch never restores grants. Settings, music, rendering, autosave and provider updates do not count as category activity. Input handling covers taps, scroll, Pencil and text edits. Expiration is checked before access and by a foreground timer; elapsed background time counts. Opening the app does not show a Sophia Protected screen. The app switcher can show the screen that was open; locked note and collection content stays hidden by the access locks. Backgrounding cancels pending authentication; foreground rechecks deadlines.

The password uses a random 32-byte salt and PBKDF2-HMAC-SHA256 with 600,000 iterations and a 32-byte verifier. Verification compares all 32 bytes. Configuration is stored under a distinct Keychain service with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. It contains no plaintext password or biometric data and is excluded from exports. The LocalAuthentication policy allows biometrics only; device-passcode fallback is hidden, and the app provides its own password field. Password setup requires 10–256 characters and confirmation. Failed guesses receive persisted backoff after five attempts (30 seconds increasing to 16 minutes). Password changes authenticate first, preserve the credential ID, replace salt/verifier and relock both categories. Removing a note or collection lock always asks again with Touch ID or Face ID, even when that category is already unlocked. The lock password remains available on that same prompt. Cancelling leaves the protection in place. No unauthenticated password reset or credential removal is offered.

These locks guard Sophia routes, editing commands and export/restore. They do not encrypt note bodies, drawings, attachments, Collection artifacts, on-device JSON, old backups or newly exported backups. Titles, note type and dates remain visible; locked note previews, tags and body-based search disappear. Locked Collection descriptions, content, membership counts and type hints are hidden. Archived/trashed records retain protection and use the same privacy rules. Archive, unarchive, Trash, restore from Trash and permanent deletion remain available while locked. Item settings, color, rename, membership edits and adding children are denied through locked routes, including direct session/store calls. Filing authorizes the changed membership edges: unchanged locked memberships remain intact while unlocked memberships can be added or removed. Rejected filing or move commands keep the picker open and show an error. The open note (…) menu and a long-press use the same three states. A note or collection with no lock offers Protect. One that is protected and currently unlocked offers Lock and Remove Protection; removal still asks for Touch ID or Face ID. One that is locked offers Unlock only, with no removal command. No Folder has no lock command. Locking again locks that whole category.

A protected Collection gates its own route and every descendant route through protected ancestors. It does not mark member Notes protected. A note filed in any locked collection, including a note in a subfolder at any nesting depth, is omitted from the Notes library, search, tag list, archive list, and open editor. That stays true when the note itself is unlocked. After the collection is unlocked, the note returns to Notes and then follows its own lock. A note that also belongs to an unlocked collection stays hidden in Notes while any of its collections is locked; that unlocked collection can still show and open it. The editor retains that collection route, rechecks its membership and ancestor access after authentication and before reading/editing, and conceals the editor if that route locks or loses the note. Opening from Notes does not inherit an earlier collection route. No Folder cannot be protected, so an unfiled note is governed only by its own lock. A separately protected Note still requires Notes access when its collection is unlocked. Global Scripture/bookmark/gleaning/conversation features remain independently accessible: filing an artifact into a protected Collection is not an artifact encryption or protection flag. Settings Trash can still list a trashed note's title while its collection is locked, with restore and deletion actions. Its private tags and body-based search matches stay hidden. Trash tag suggestions come only from trashed notes whose own and collection access allow metadata visibility.

Native accepted ink/text buffers are flushed before an editor is concealed; dirty snapshots continue saving. Save failures retain dirty data and existing recovery behavior. Relocking clears the protected editor, undo/selection and protected in-app clipboard. Accepted changes are not discarded. Protection flags are not part of body undo operations.

## Recovery, backup and compatibility

All-data export/restore preflights both categories; Notes-only backup preflights Notes. When access is needed, authentication occurs before processing. A cancelled/failed request produces no exported content and no new grants. Existing grants survive cancellation until their own deadline. Export permissions are rechecked after async work. Pre-restore archives are inspected before disclosure. Restoring invalidates pending requests and relocks restored categories. Replacing content from a legacy backup retains existing protection for matching item IDs, rather than silently dropping it.

The original device-only verifier is required to unlock protected records. Forgotten password may be recovered through the device's working biometrics, then changed in Settings. If the Keychain credential is missing/unreadable or a protected backup originates from another device/credential, that record remains locked even if a new app password is set up. No reset silently adopts it. Restore protected backups on the original device with the original Keychain credential. Archive/delete remain available; exported plaintext backups should be handled as private files. Cross-device credential portability and encrypted backup recovery are not implemented in v0.3.0.

Stores containing protection use Notes schema 4 / Collections schema 2; stores without protection retain Notes schema 3 / Collections schema 1. Older apps reject these protected schemas rather than decoding away protection or automatically falling back to a plain previous generation. Current store locations and atomic-generation recovery remain unchanged. When adding protection, the previous generation receives the same binding for matching records in a separate copy, preventing automatic recovery from dropping a new lock. The original pre-protection Notes bytes are retained. Recovered rejected-ink notes inherit their source note’s binding. Explicit legacy restoration requires current access; matching bindings survive. Existing v0.2 backups without flags remain readable and unprotected unless matching a currently protected record.

## Implementation ownership

- `Infrastructure/Security/ItemLockCredential.swift`: salted verifier, device Keychain and credential error messages.
- `Features/Protection/ItemProtectionSession.swift`: separate category grants, deadlines, single prompt, cancellation/stale-result guards and injectable biometrics.
- `Features/Protection/ItemProtectionViews.swift`: password/biometric UI, category/combined Settings controls, and the real-input observer.
- `Features/Notes/NotesSession.swift`: command/open/export guards, per-item protection, accepted-buffer flush and concealment.
- `Features/Collections/CollectionsStore.swift`: ancestor gates, membership/settings guards and protection persistence.
- `Infrastructure/Backup/StudyBackupService.swift`: full-backup preflight across categories.

Unit and simulator UI evidence belong to the tickets. Physical Touch ID/Face ID, real Pencil buffers, accessibility and ten-minute device idle/relaunch acceptance remain owner-device gates. Confirm that opening Sophia no longer shows a Sophia Protected screen.

## Primary platform references

- [Apple: biometric authentication without device-passcode fallback](https://developer.apple.com/documentation/localauthentication/logging-a-user-into-your-app-with-face-id-or-touch-id)
- [Apple: localizedFallbackTitle and hiding the system fallback](https://developer.apple.com/documentation/localauthentication/lacontext/localizedfallbacktitle)
- [Apple: device-only Keychain accessibility and backup migration](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)

SP-045 duplication retains source protection bindings. Notes copying rejects locked
notes and notes concealed by collection access. Collection copying preflights every
active descendant and source parent; copying membership edges requires Notes access
for protected member notes. No partial tree is published on rejected or failed saves.
Annotation-reference cleanup checks affected folder access and never deletes ink.

## SP-046 Collections schema extension

Collections stores containing Points to Ponder (including Trash) write schema 3,
regardless of protection. Schemas 1/2 still load with no points. Existing credential
bindings, ancestor route guards and backup preflights are retained. Older versions
reject schema 3 safely. Collection relocking dismisses the question/Explore/New note
flow. Newly created material inherits only accessible source folder memberships.
