# SP-044 — Consistent long-press and swipe record actions

Status: implemented, simulator-verified and installed on the owner iPad 2026-10-14.
Latest Subfolders polish launch is pending because the device is locked; earlier
swipe delivery launched successfully. Physical acceptance remains open.
Milestone: post-v1.2.0 interaction refinement. Type: UI behavior fix.
Owners: Frontend/UI, SQA and documentation. Dependencies: SP-013/015/040.

## Outcome and scope

Collection material list records expose actions by long press or horizontal swipe,
without an always-visible ellipsis. Collection cards also omit the ellipsis and
retain their long-press menu. Notes cards
and list records retain long-press menus and gain swipe actions. Prayer updates
retain long-press Edit/Delete and reveal those controls on swipe.

A shared app-owned swipe rail supports ScrollView/LazyVStack hosts. Swipe left
reveals controls; swipe right on the record body closes. Only one rail can remain
open across mounted tabs. Vertical finger pans and tab changes close the rail.
No full-swipe mutation. Collections and Notes
show More (the existing complete context menu) and Delete where eligible; Prayer
updates show Edit/Delete. Existing access/type guards, confirmations and commands
remain authoritative. Multiselect disables Notes swipe; vertical scrolling remains
available. Reduce Motion suppresses the settling animation. Accessibility actions
provide Show/Hide actions as an alternative to horizontal gestures.

## Boundaries and implementation

No persistence/schema/provider/release changes. No destructive gesture without the
existing confirmation. DesignSystem/StudySwipeReveal.swift owns transient offset and
horizontal-intent filtering and StudySwipeCoordinator. RootTabView owns the shared
coordinator; ScrollActivityObserver passively reports vertical finger intent without
recognizing or preventing scrolling. The row drag takes priority over its navigation button;
disabled hosts do not install the parent drag. Sharing a Prayer update dismisses
its input keyboard so the action rail can be reached. CollectionArtifactRow, NotesView and NotePrayerEditorView
supply their existing menu and mutation closures. No native List-only modifier is
assumed to work in a LazyVStack. Original record sizing, metadata and navigation stay.

## Verification

Focused UI: collection list ellipsis absence, swipe/More/delete confirmation and
relaunch; note long-press/delete; Notes list/card swipe/More, rightward close and long press; Prayer swipe/Delete
cancellation retaining update; vertical drag starting inside a long Prayer update. Check physical finger/Pencil, vertical-scroll diagonal
intent, Dynamic Type, VoiceOver, split view and Reduce Motion on iPad; simulator
checks do not close physical acceptance. Evidence recorded after execution.

## Execution evidence — 2026-10-14

Four focused UI tests passed with zero failures on iPad (A16), iOS 27.0:

- `CollectionsUITests/testDeleteBookmarkFromNoFolderUsingSwipe`: no permanent list
  ellipsis, swipe/More/delete confirmation, and deletion preserved after relaunch.
- `CollectionsUITests/testDeleteNoteFromNoFolderMovesItToTrash`: long-press actions
  retain the existing note Trash behavior.
- `NotesUITests/testNotesListAndPrayerUpdatesRevealActionsOnSwipe`: Notes list and
  card swipe reveal, rightward close, long-press menu, Prayer update swipe controls
  and cancelled deletion retaining the update.
- `NotesUITests/testPrayerUpdateVerticalDragStillScrolls`: a drag starting inside
  a 55-line update scrolls vertically without revealing destructive actions.

Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test
-project application/SophiaScriptura/SophiaScriptura.xcodeproj -scheme SophiaScriptura
-destination 'platform=iOS Simulator,id=709D6F70-328D-4458-8F8A-B2C47A945A80'
-derivedDataPath build/sp040/page-status/DerivedData -resultBundlePath build/sp044/ui-r6.xcresult`
with the four `-only-testing:SophiaScripturaUITests/...` selectors above and
`CODE_SIGNING_ALLOWED=NO`. Evidence: ignored `build/sp044/ui-r6.{log,xcresult}`;
retained Collection rail screenshot under `build/sp044/r6-images/`.
Final action-button spacing uses a shared style with 44-point targets and complete
labels. The Collection swipe/delete/relaunch check passed again after this polish
(`build/sp044/ui-r7.{log,xcresult}`); screenshot reviewed under `build/sp044/r7-images/`.

Earlier iterations exposed navigation-button activation during simultaneous drags
and keyboard/tab-bar overlap over newly shared updates. The final checks passed
with a priority drag and Prayer input focus cleared after sharing. No persistence
or access-policy change was needed. Full unit suite was not rerun for this UI change.

Signed generic-iPad Debug build succeeded, and `codesign --verify --deep --strict`
passed. Bundle remains `com.personal.SophiaScriptura`, version 1.2.0/build 24.
Evidence: `build/sp044/ipad-final-build.log`, `build/sp044/ipad-signature.log`; artifact:
`build/ipad-install/DerivedData/Build/Products/Debug-iphoneos/SophiaScriptura.app`.
Installer dry-run passed. The earlier device check reported paired `iPad ni Paj`
unavailable; successful follow-up installation is recorded below. No uninstall or
data reset occurred.
`git diff --check` and changed Markdown local-link validation passed.

Physical finger/Pencil, diagonal gestures, split view, Dynamic Type, VoiceOver and
Reduce Motion remain owner acceptance checks. No commit, tag or release was made.

## Owner follow-up — one open rail and reliable dismissal

Owner reported multiple open records, closing swipes getting stuck on the shifted
record body, sluggish swipe response, and a remaining Collection card ellipsis.
The earlier swipe-close test began on the More button, which missed the body hit-test
failure. New regression coverage starts the closing drag in the record's blank area,
opens a second record, and pans vertically over an open record. Collection card
ellipsis absence and the retained hold menu are also checked.

The root now supplies one transient coordinator to all hosts, closing the prior
rail when another is claimed. An explicit rectangular hit surface and transparent
closing surface cover the shifted record even while its navigation button is disabled.
The existing passive finger observer dismisses rails on vertical intent, and tab
switches also clear them. No per-row timers or new persistence are introduced.

Responsiveness adjustment: drag recognition retains 20pt so vertical scrolling can
win recognition before the row drag,
horizontal intent ratio is 1.2 (previously 1.5), release direction threshold is
20pt (previously 30pt), and settling animation is 0.12s (previously 0.18s).
These reduce release/animation delays; physical latency is not
measured by the simulator checks.

Follow-up verification: Collection card ellipsis absence/hold-menu and list
swipe/delete/relaunch passed in `build/sp044/dismiss-r1.xcresult`. An initial 10pt
drag onset blocked vertical scrolling and was rejected. With 20pt onset retained,
all three Notes UI checks passed in `build/sp044/dismiss-r2.xcresult`: the existing
card/list/Prayer action regression, single-open/body swipe-back/scroll dismissal,
and actual vertical scrolling over a long Prayer update. Logs are beside the
result bundles. No unit-suite rerun was needed for these transient UI changes.
Signed generic-iPad build succeeded (`build/sp044/ipad-dismiss-final-build.log`).
Changed Markdown links and `git diff --check` passed. Physical gesture feel and
VoiceOver/Pencil/diagonal/Dynamic Type acceptance remain owner checks.

Follow-up delivery completed: the paired iPad became reachable. Installer dry-run,
signed build, strict signature/bundle validation, in-place installation and normal
launch all passed. Bundle remains `com.personal.SophiaScriptura`, 1.2.0/build 24;
no uninstall or data reset. Logs: `build/sp044/ipad-dismiss-install.log` and
`build/ipad-install/logs/20261014-230023-28190/`. Installation/launch do not establish
owner physical gesture, VoiceOver or Pencil acceptance.

## Owner follow-up — Subfolders heading and nested-folder summary

Owner requested a plain Arrange control beside the New Subfolder button, and each
subfolder preview to include its immediate child-folder count. CollectionDetailView
keeps the existing Arrange menu, identifier and options while replacing its outlined
button style with a plain label and a full-height touch area. New Subfolder remains
the outlined action in that heading.

Subfolder previews show `N items · M subfolders`. Item totals retain the existing
membership semantics; M counts active immediate children through `store.children(of:)`,
excluding deeper folders. Locked subfolders still show only `Locked`. No schema,
storage, sorting-command or hierarchy behavior changes.

Verification: `CollectionsUITests/testSubfolderPreviewCountsOnlyDirectChildFolders`
passed on iPad (A16) simulator: three folder generations confirm first-degree counts
and the Arrange menu remains functional. Evidence: `build/sp044/subfolder-polish.log`
and `.xcresult`; screenshot reviewed under `build/sp044/subfolder-images/` confirms
plain Arrange alongside the outlined New Subfolder action. Signed generic-iPad build
passed (`build/sp044/subfolder-ipad-build.log`). No full unit-suite rerun for this
presentation-only change.

Subfolders polish delivery: installer dry-run, signed build, strict signature and
bundle validation, and in-place installation passed. Launch was attempted but
CoreDevice reported `FBSOpenApplicationErrorDomain error 7: Locked`; owner must
unlock and open Sophia. Existing app/data were preserved. Logs:
`build/sp044/subfolder-ipad-install.log` and
`build/ipad-install/logs/20261014-232102-29009/`. Version remains 1.2.0/build 24.
