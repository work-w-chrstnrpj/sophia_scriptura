# SP-045 — Study record duplication, annotation cleanup and Journal settings

Status: implemented and simulator-verified, 2026-10-15. Physical acceptance open.
Milestone: post-v1.2.0 personal-study refinement.
Owners: UI, local domain/persistence, QA and documentation.

## Scope and decisions

- Deleted annotation layers no longer appear as saved materials in Collections when
  the loaded annotation snapshot confirms their tombstone. Missing/unloaded layers
  retain an unavailable reference, with a confirmed Remove Annotation Reference
  action (including swipe Delete). Only the saved reference and membership edges
  are removed; the underlying annotation repository/ink is untouched.
- Duplicate Collection is available in folder hold menus and its detail menu.
  A modal asks `Include contents`; the folder/subfolder tree gets new IDs under
  the same parent. With contents enabled, the same existing item IDs are assigned
  to the new folders, as selected by the owner. Without it, structure alone is copied.
  Names gain `(Copy)` at the root. Colors, descriptions, icons and protection
  bindings remain; archived/trashed branches are excluded. No Folder is excluded.
  Every copied folder and changed membership is access-checked. The complete new
  Collections generation commits before it is published; failures show an error.
- Duplicate Note in Notes' hold/swipe More menu creates a separate value document,
  retaining body, formatting, ink, attachments, metadata, statuses and protection,
  with a new note ID/title/timestamps. It is unfiled and does not change the current
  editor route. Object IDs are local to their document; no external payload path is
  shared. Existing 200-note and aggregate payload limits apply before appending.
- Page/Journal editing icons can collapse into a chevron. Collapse preference is
  local UI state, not document data. Undo, status and options remain available;
  Canvas and Prayer toolbars are unchanged.
- Journal Type: Diaristic Journal / Spiritual Journal. Stored additive raw key
  `journalType`; absent or unknown values decode as Spiritual. Existing body,
  ink, emotional/mental state and Scripture visibility are preserved. Choices are
  editable in the Journal toolbar and shared library status menu.

## Boundaries

No release/tag/version change, provider integration, reset, bulk deletion or destructive
migration. Keep earlier SP-044 changes. Protection is preserved and access guards remain
in the authoritative session/store. New copies do not grant access or remove protection.

## Verification

Unit: legacy/unknown Journal Type decode, both choices round-trip, note-copy independence
and persistence, folder-tree identities with/without membership copies and relaunch,
annotation tombstone projection and reference-removal persistence without ink changes.
UI: note duplication, Page/Journal toolbar collapse/re-expand and Journal Type choice;
Collection duplicate modal and creation/cancellation. Check locked routes reject copying.
Physical iPad: title space, chevron touch targets, Pencil, split view and accessibility
remain owner acceptance. Record actual build/test/install evidence below.

## Verification evidence — 2026-10-15

105 domain/protection tests passed in `build/sp045/final.xcresult`, including
CollectionsStoreTests, NotesTests and ItemProtectionTests. After expanding the note
copy fixture and adding unknown-binding rejection, 70 Notes/Collections tests passed
in `build/sp045/final-r2.xcresult`. This is focused coverage, not a full-suite run.

Two new UI flows passed across those bundles: Collection duplicate modal cancellation
and creation; standalone note copy, Page collapse/re-expand and Journal Type choice/
collapse. The initial Notes UI test relied on an unexposed toolbar value; it was
corrected to inspect tool visibility and passed on rerun. Collection context-menu
animation-idle timeout recovered and its flow completed successfully. Screenshot
`build/sp045/r2-images/06E850E9-0CB0-4335-9A78-1D607FC2DFF0.png` was reviewed:
collapsed Journal controls leave Untitled Journal fully visible.

Native command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test`
with SophiaScriptura project/scheme, installed iPad (A16) simulator
`709D6F70-328D-4458-8F8A-B2C47A945A80`, focused selectors above and
`CODE_SIGNING_ALLOWED=NO`. Logs accompany each result bundle under ignored `build/sp045/`.
Signed generic-iPad Debug build passed (`build/sp045/ipad-final-build.log`), as did
strict deep signature validation (`build/sp045/signature.log`). Bundle/version remain
com.personal.SophiaScriptura, 1.2.0/build 24. Markdown local links and diff whitespace
checks passed. No commit, merge, tag or release was performed.

Physical existing-library annotation cleanup, copied media/ink editing, title space
for owner titles, Pencil, split view, VoiceOver and biometric access remain owner
acceptance. Missing annotation snapshots preserve references rather than guessing
deleted state; unavailable references can explicitly be removed without deleting ink.

Delivery retry: installer build and strict signature/identity checks passed, but
CoreDevice rejected installation with error 4016: the device could not fulfill
remote-service connectivity/power usage assertions. Evidence: `build/sp045/install.log`.
No install/launch is claimed for SP-045. Existing installed app/data were not removed.
The signed artifact is ready; reconnect and unlock the iPad before retrying delivery.

## Journal Type icon follow-up — 2026-10-15

Owner selected Unset (book), Diaristic Journal (quill), and Spiritual Journal (owl).
New JournalContent starts Unset. Existing stored diaristic/spiritual values remain;
missing or unknown values still decode as Spiritual, preserving historical content.
The new `unset` raw value round-trips in the existing additive field; earlier SP-045
builds read it as Spiritual without losing content. No schema bump or migration.
NoteJournalFields owns shared monochrome vector quill/owl drawings; the editor's
selected icon and editor/library picker choices use the same presentation. The
library Journal Type menu also reflects the current type. Note-card kind glyphs
remain unchanged. No new files or modules.

The focused legacy/unknown/all-choice round-trip test passed on iPad (A16)
simulator in `build/sp045/journal-icons/unit.xcresult`; the fixture also asserts
new journals start Unset. Physical icon appearance and accessibility acceptance
remain open. No install, version bump, commit or publication in this follow-up.
The focused editor UI regression also passed in
`build/sp045/journal-icons/ui.xcresult`: new Journal starts Unset, selection changes
to Diaristic, Spiritual and back to Unset, and type selection remains available
with editing tools collapsed. Local Markdown link checks and `git diff --check`
passed. This is focused coverage, not a full-suite rerun.

Journal Type follow-up delivery: installer dry-run, signed Debug build, strict
signature/bundle validation, in-place iPad installation and normal launch passed
on 2026-10-15. Evidence: `build/sp045/journal-icons/ipad-install.log`.
Existing app/data preserved; same bundle and 1.2.0/build 24. Physical icon and
Pencil/accessibility acceptance remain owner checks.

## Journal Type native-menu icon correction — 2026-10-15

Owner observed missing quill/owl icons in the card hold menu, both on the Journal
Type field and its choices. The earlier custom Shape labels worked in the SwiftUI
editor but were unsuitable for native menu image extraction. JournalTypeImages now
caches template UIImages rendered from the same vector paths and returns a direct
SwiftUI Image for each label. Both library and editor menus share these images;
book remains the system symbol. No document/data/default changes. A focused card
hold-menu regression captures the field and all choices across three selections
for visual inspection, since label existence alone cannot prove icon visibility.
Verification: editor type/collapse regression passed in
`build/sp045/journal-icons/menu-fix.xcresult`; card hold-menu selection regression
passed in `build/sp045/journal-icons/card-menu.xcresult`. Exported screenshots in
`build/sp045/journal-icons/card-images/` were visually inspected: all three choice
icons are present, and the field shows the selected quill/owl after reopening.
`git diff --check` passed. No data migration or full-unit rerun was needed for
this presentation correction. This correction has not yet been installed on iPad.

Native-menu icon correction delivered 2026-10-15: installer dry-run, signed build,
strict signature/bundle checks, in-place install and normal launch passed on
`iPad ni Paj`. Existing app/data preserved. Evidence:
`build/sp045/journal-icons/menu-fix-install.log`. Physical owner acceptance remains open.
