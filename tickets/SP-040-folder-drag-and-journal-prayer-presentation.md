# SP-040 — Folder dragging and Journal/Prayer presentation

Status: implemented; simulator verified; physical iPad acceptance pending. Owner selected 2026-10-13.
Milestone: post-v1.0.0 personal study refinements.

## Outcome and scope

- Drag top-level Collection cards or nested folder tiles onto another folder to reparent the entire subtree. Move Collection offers the full destination tree and top-level destination, by tap or dragging its source folder.
- Thriving uses the SF Symbols flower (`camera.macro`); unset Emotional state uses an outlined `heart`, including the Not set chooser row. Selected emotions retain their face emoji.
- Answered and Redirected prayers show a presentation-only stamp horizontally in Arial Black: ANSWERED green, REDIRECTED yellow. Waiting has no stamp. Scalable vector wordmarks preserve Arial Black on iPadOS without font fallback. Stamps appear on unlocked prayer cards in the Notes library, outside the prayer editor, without intercepting card taps.

## Boundaries and ownership

CollectionsStore validates moves and persists the existing parentID. CollectionFolderMove owns the custom local drag payload, targets and full-tree sheet; library/detail views expose these interactions. Notes editor views own glyph/stamp presentation. No schema change, study text/ink mutation, provider traffic, release or physical installation is included.

Moves reject virtual No Folder, inactive/unknown/locked sources or targets, unchanged parent, self and descendants. Protected ancestors retain existing access checks. Descendants keep IDs, own protection bindings and memberships; moving changes inherited protection according to the destination ancestry. Stale drag payloads are revalidated at commit, and Sophy commit exclusion remains effective.

## Acceptance and verification

- Unit regressions: root/nested/top-level moves, cycle rejection, memberships/subtree preservation, unknown/inactive/locked targets and persistence after reopen.
- UI checks: root-to-folder and nested-to-folder drag, reopen; prayer status transitions and stamps; Journal unset/Thriving state controls. Capture screenshots in result bundle.
- Manual iPad acceptance: long-press drag feedback, cross-branch Move Collection sheet, protected ancestors, Pencil behavior, narrow split view, Dynamic Type, VoiceOver and stamp appearance. Automated checks do not replace physical acceptance.
- Evidence: ignored `build/sp040/` result bundles. Results recorded after execution.

## Verification — 2026-10-13

Final build and focused test run passed **60 tests: 58 unit + 2 UI, zero failures**,
on iPad (A16) Simulator. Evidence: `build/sp040/verified-r2.xcresult` and
`build/sp040/verified-r2.log`. Both root/nested drag and relaunch persistence passed;
Prayer status transitions, no stamp when waiting, Journal unset emotion and Thriving
controls passed. Answered/Redirected screenshots were visually inspected and confirm
45-degree green/yellow Arial Black outlines without covering writing controls. Journal
screenshot confirms the flower/outlined-heart icons.

An earlier repeat run timed out on nested dragging; the final implementation uses
explicit own-process NSItemProvider data with commit-time validation. The final test
uses a deliberate target hold. An initial font screenshot exposed silent Arial Black
fallback; vector wordmarks corrected it. Earlier failed bundles remain in build/sp040
for traceability. The full native suite and physical interaction/accessibility matrix
were not run. No release or installation performed. Documentation links, plist lint
and git diff --check passed.

## Owner addition — Page status, 2026-10-13

Owner requested `pageStatus` for Page noteType with Unset, Drafting, Revising, Editing,
Publishing and Closed, accessed through a new icon in the top Page toolbar. Implemented
as additive PageContent metadata, with guarded NotesSession updates. Missing/unknown
values fall back to Unset; Unset is omitted on write. The Page assignment setter retains
metadata so text edits, reflow and undo cannot reset the field. Older apps may drop the
status when rewriting a note; no storage-schema change or external publishing is added.
Verification: Notes tests cover legacy/unknown decode, all choices, body undo/redo,
reopen, reset and exclusion from other note types. UI test checks every menu choice.
Evidence: `build/sp040/page-status/results.xcresult`; **42 checks passed** (41 Notes unit tests and the Page status UI test), zero failures. The exported menu screenshot was visually inspected and shows all six choices in the requested order. Physical iPad acceptance remains pending.

## Owner-requested iPad installation — 2026-10-13

The current SP-040 checkout, including Page status, built as signed Debug, passed
strict signature and bundle-identity checks, installed in place on `iPad ni Paj`
(iPad A16), and launched successfully. Existing app identity and data were retained;
no uninstall or reset was used. Evidence: `build/sp040/ipad-install.log` and
`build/ipad-install/logs/20261013-100741-5010/`. Installation and launch do not close
the physical interaction, visual or accessibility acceptance checks above.

## Owner placement correction — 2026-10-13

Moved ANSWERED/REDIRECTED stamps from the prayer editor to Notes library cards.
Locked cards conceal status; waiting cards have no stamp. UI verification checks
card placement, editor absence and both status transitions.

Verification passed: targeted simulator UI test
`NotesUITests/testPrayerStatusStampsAndJournalStateIcons`, including card stamps,
editor absence, card taps and waiting removal. Both card screenshots were exported;
Redirected was visually inspected. Evidence: `build/sp040/card-stamp.xcresult`.
The corrected signed build passed signature checks, installed in place and launched
on iPad ni Paj; no uninstall/reset. Evidence: `build/sp040/card-stamp-ipad.log`.
Physical feature acceptance remains with the owner.

## Owner horizontal stamp refinement — 2026-10-13

Stamp lettering now remains upright and horizontal (owner described a 180-degree
straight angle), centered in the card’s blank former-preview area between the header
and dates. Colors and Arial Black outlines remain unchanged.

Focused UI verification passed (`build/sp040/horizontal-stamp.xcresult`). The
Redirected card screenshot was visually inspected: horizontal stamp centered in
the blank area, clear of title and dates. Signed build, signature verification,
in-place installation and launch on iPad ni Paj passed; data retained. Evidence:
`build/sp040/horizontal-stamp-ipad.log`. Physical owner review remains open.

## Owner card preview refinement — 2026-10-13

Unlocked Journal cards show Emotional State and Mental State together in one row,
with the existing state glyphs and Not set defaults. Unlocked Page cards show the
opening body text (two lines); Closed Pages replace it with a horizontal green
Arial Black PUBLISHED stamp, matching prayer stamps. This is a local status mark,
not an external publishing action. Locked cards conceal all previews and stamps.

Verification: both focused UI tests passed in `build/sp040/card-previews.xcresult`;
after correcting the shared stamp border tint, the Journal/Page test passed again
in `build/sp040/card-previews-final.xcresult`. Final screenshot visually confirms
the single Journal row and green PUBLISHED lettering/border clear of header/dates.
Text-preview restoration after Closed → Drafting passed. Signed build, signature
checks, in-place install and launch on iPad ni Paj passed in
`build/sp040/card-previews-ipad-retry.log`. Initial device-specific build timed out
during Xcode device preparation before installation; generic iOS build retry passed.
No uninstall/reset or release performed; physical owner acceptance remains open.

## Owner rubber stamp styling — 2026-10-13

All three marks use Rubber Stamp lettering, enlarged to overlap card text, with a
stable per-note randomized tilt from 1 through 15 degrees. Colors, access guards
and tap-through behavior remain. See [font provenance](../docs/design/stamp-font-provenance.md).

Verification: both focused UI tests passed in `build/sp040/rubber-stamps.xcresult`.
The PUBLISHED screenshot was visually inspected for distressed lettering, enlarged
overlap and small tilt. Card tap-through and status/preview transitions passed.
Signed build, strict signature checks, in-place installation and normal launch on
iPad ni Paj passed (`build/sp040/rubber-stamps-ipad.log`). No app deletion/reset
or release performed. Owner physical visual acceptance remains open.

## Owner animation and Collections return refinement — 2026-10-13

Scope: SP-040 post-release Notes presentation/navigation only. Stamps animate on
Notes-tab activation: soft black shadow, darkening impression, then status color.
Reduce Motion shows the final mark directly; tab departure cancels pending animation.
Collection-opened and newly created notes use a full-screen shared editor over the preserved Collections stack and
return to the same folder. Reader, Companion and ordinary Notes routes retain their
existing destinations. Existing NotesSession access guards and saves are retained;
no persistence format, protection policy or other artifact routing change.
Affected: RootTabView, CollectionsView, NotesView, stamp view and focused UI checks.
Verification: create/open/back within Collections, Page previews and Prayer transitions.

Verification: Page/Journal and Prayer UI regressions passed in
`build/sp040/stamp-navigation.xcresult`. The initial Collections routing check caught
return to the folder root; replaced that push with a full-screen editor preserving
the underlying stack. Final create/open/back regression passed in
`build/sp040/collection-return.xcresult`. Signed build, strict signature checks,
in-place installation and launch on iPad ni Paj passed
(`build/sp040/stamp-navigation-ipad.log`). No app deletion/reset or release.
Physical animation timing, Reduce Motion and protected-folder acceptance remain open.

## Owner long-press status controls — 2026-10-13

Holding an active, accessible note adds type-specific status menus in Notes cards/list
and Collection note rows: Page Status, Prayer Status, or Emotional State and Mental
State. Existing choices, including Unset/Not set, remain available. Changes persist
without selecting the note or changing editor navigation. The command rechecks
locks, concealed collection ancestry, note kind and active state before committing.

Verification: persistence/type-safety test plus Notes hold-menu UI passed in
`build/sp040/hold-status.xcresult`. Collection hold-menu/reopen/back UI passed in
`build/sp040/collection-hold-status-final.xcresult`. The initial Collection check
exposed a brittle generic Back selector (it tapped Pencil tools); the final test
uses collections.note.back and requires the underlying row to be hittable.
Signed build, strict signature checks and in-place installation passed in
`build/sp040/hold-status-ipad.log`; launch was denied because the iPad was locked.
Unlock and open Sophia manually. No app deletion/reset or release performed.
Physical protection/visual acceptance remains open.

## Owner folder material layouts — 2026-10-13

Each folder’s Study Material View menu offers List View and Card View, including
No Folder and nested folders. The choice is remembered per folder in local UI
preferences. List records are uniformly 80pt high; card records uniformly 176pt
high in a shared adaptive 220–320pt grid. All artifact types use the same geometry
within each mode; long titles/previews truncate instead of increasing record size.
Context menus, access guards, filters, sorting, descendants and opening remain.
List swipe actions remain; card organization uses the same long-press menu.
No collection or note storage migration or other tab layout change.

Verification: folder create/open/status/back passed in `build/sp040/folder-layout.xcresult`.
Expanded card/list switch test passed in `build/sp040/folder-layout-verified.xcresult`,
including 176pt cards and 88pt list hit regions (80pt content + 8pt outer spacing).
Card screenshot visually inspected. An intermediate assertion counted list spacing
as content; corrected the expected hit-region size, with no product change.
Signed build and strict signature checks passed (`build/sp040/folder-layout-ipad.log`).
Installation was not confirmed: initial CoreDevice tunnel timeout and retry remote
connection interruption (`build/sp040/folder-layout-install-retry.log`). Reconnect
and unlock the iPad before retrying. No uninstall/reset or release performed.

Owner-requested installation retry succeeded: existing signed build reverified,
installed in place and launched on iPad ni Paj. Evidence:
`build/sp040/folder-layout-install-again.log` and
`build/sp040/folder-layout-launch-again.log`. No uninstall or reset.

## Shared note card presentation — 2026-10-13

Notes and Collection card mode now render the same NoteLibraryCard: note-selected
accent/top rule, note-kind glyph, title/type, creation and modification dates,
Page opening text/Published mark, Journal states, and Prayer stamps. The shared
stamp sequence runs on card appearance and active-tab entry, cancels while hidden
and respects Reduce Motion. Hosts retain their own selection, context actions and
navigation. Fixed 176pt size and Collection list mode remain. Locked notes conceal
previews and stamps in both hosts. No persistence or protection-policy changes.

Verification: all three focused UI checks passed in
`build/sp040/shared-note-cards.xcresult`: Collection layout/status/open/back,
Journal/Page previews and Prayer transitions. Exported Collection screenshot
visually confirms the same note accent/top rule, Page glyph, dates and enlarged
PUBLISHED stamp. Signed build, strict signature checks, in-place installation and
launch passed on iPad ni Paj (`build/sp040/shared-note-cards-ipad.log`).
No uninstall/reset or release. Physical animation timing and accessibility review
remain owner acceptance checks.

## v1.1.0 publication snapshot — 2026-10-13

Owner authorized commit/push/merge/release of all current work as v1.1.0/build 23.
The release snapshot passed 376 unit tests with zero failures in
`build/v110/unit-tests-final.xcresult`; earlier focused UI and physical deployment
evidence remain above. Feature-level physical acceptance remains pending.
See [release notes](../docs/releases/v1.1.0.md) for all included scope and limits.
