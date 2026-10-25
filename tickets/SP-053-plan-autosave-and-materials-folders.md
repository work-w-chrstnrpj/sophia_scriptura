# SP-053 — Plan editing, autosave and materials folders

Status: **Scripture editing implemented; 481 unit tests + dual-entry UI test passed; corrected build installed; device launch locked; owner acceptance open** (2026-10-25).
Milestone: post-baseline Collection Plans refinement.
Authorization: owner requested clearer assignment buttons, responsive reordering,
autosave in Plans/Notes/Collections, an automatic Plan-named subfolder with shared
materials, and signed installation on the personal iPad.

## Scope and ownership

Plans owns draft snapshots, debounce, ordering and save feedback. CollectionsStore
remains the only Collections writer and atomically creates/renames the materials
folder alongside its Plan. NotesSession retains Notes autosave/persistence ownership.
UI changes touch assignment creation, Collection/link/gleaning editors and Notes
metadata/object/Prayer-update editors. No backend, provider, new Pencil tool, release,
uninstall, data reset or unrelated feature is selected.

## Behavior and compatibility

- Assignment creation uses large prominent buttons.
- Drag callbacks resolve rendered stable identities; stale deleted targets stay rejected.
  Up/down assignment controls provide immediate ordering while in Edit mode.
- Plans debounce valid changes for 350 ms, serialize immutable save snapshots, preserve
  edits arriving during a write, and show pending/saving/saved or validation failure.
  Close/Save waits for persistence; invalid input remains open for correction.
- Existing Page/Canvas/Prayer/Journal content autosave remains. Notes detail/object,
  rename and Prayer-update edits now feed the same autosave. Foreground exit flushes
  Notes input and pending feature saves. New-item creation and destructive actions
  retain explicit commands; autosave applies to edits after material creation.
- Collection creation starts at its first valid name and reuses that ID for later
  edits. Collection details, saved links and gleaning insights save changes automatically.
  Invalid names/URLs do not replace the last valid saved value.
- Optional `StudyPlan.materialsFolderID` remains additive within Collections v4; missing
  keys decode as nil. Linked Folder appears only inside the Edit modal, with options
  to choose an existing folder, create/name a new folder, or leave it empty.
- Ordinary save/autosave, Scripture assignments and selecting existing material preserve
  an empty link. Creating a **new note or link** ensures a folder first; an absent link
  creates and links a Plan-named folder in one checked Collections commit. No Folder
  uses a root folder. Both the editor assignment picker and reading tools use this rule.
- New notes are filed through a checked receipt after their Notes save; new links save
  directly with the linked-folder membership. Assignment attachment remains revision
  checked; partial failure retains the saved original for retry. The editor refreshes
  its revision after automatic folder creation, preserving assignment edits afterward.
- Linked folders keep their own names, descriptions and locations. New folder descriptions
  say “This folder contains the study materials for the Plan ‘[Plan name]’.” Plan renaming
  never overwrites customized existing folder metadata. Folder moves retain the UUID link.
- Unlinking clears only the pointer and preserves folders, materials and memberships.
  A later new note/link creates a new linked folder; it does not rediscover/relink the old
  one by name. Existing notes/links are shared references, not cloned. Scripture assignments
  remain reference-only projections. Previously accepted access requirements stay sticky.

## Verification and remaining acceptance

Automated regressions cover edits during a
suspended save, rapid reorder callbacks, all four Notes kinds without Save, shared
materials, stable rename identity, duplication and legacy optional-key decoding.
Physical drag feel, Pencil input, visual/accessibility acceptance and owner study-data
reopen remain separate from automated and installation evidence.

Owner clarification (2026-10-25): Plan details show Linked Folder. The identity link
survives folder moves; Plan saves never force the folder beside the Plan. Its description
is “This folder contains the study materials for the Plan ‘[Plan name]’.” and follows
Plan rename. A moved-folder regression verifies location and identity after later saves.

## Recorded verification — 2026-10-25

- Final arm64 simulator build: **BUILD SUCCEEDED**. Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project application/SophiaScriptura/SophiaScriptura.xcodeproj -scheme SophiaScriptura -destination 'generic/platform=iOS Simulator' -derivedDataPath build/sp053/DerivedData -jobs 2 ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO`. Log: `build/sp053/build-arm64.log`.
- Earlier full unit run: **461 tests, 460 passed, 1 failed**, `build/sp053-final.log`.
  The failed whitespace/caret test ran against the earlier compiled PlanEditorDraft;
  final source preserves the draft's trailing whitespace while storing a trimmed title.
  All-four-kind Notes autosave, concurrent-write edits, shared-folder identity and
  reorder regression tests passed in that run. This is **not** a final-source green suite.
- A preceding run exposed the old reflection-folder expectation; source filing was
  preserved and its assertion now includes the new linked folder. That case passed
  in the subsequent full unit run.
- The UI run collided with another project's tests on iPad (A16). A separate installed
  iPad Pro 13-inch (M5), ID `7252B257-288A-4AEA-BE6B-17BD5FD95B54`, shut down before
  test-host launch. A bounded reboot succeeded, but final test-without-building still
  could not launch the host; even a 15-second app-container query timed out.
  Logs: `build/sp053-verified.log`, `build/sp053-focused.log`. These interrupted runs
  do not establish a runtime pass. Final whitespace retry, moved-folder assertions and
  UI autosave/reopen/action appearance remain unverified at runtime.
- Final documentation relative links: **0 broken**; `git diff --check`: **passed**.
- Installer dry-run: passed. Signed build: **blocked before installation**, with No
  Accounts and missing widget development profile (`build/sp053/ipad-install.log`).
  Owner chose “Finish verification; I’ll sign in later.” Existing iPad app/data untouched.

Next verification: rerun the scoped Plan/Notes tests and
`SophiaScripturaUITests/PlanUITests/testAutosaveCloseReopenAndProminentAssignmentActions`
on an available stable iPad simulator, then retry `scripts/install-ipad.sh` after the
existing Apple account and Personal Team are restored in Xcode. Physical reorder feel,
Pencil/keyboard/background durability, visual accessibility and study-data reopen stay open.

## Signed-in iPad retry — 2026-10-25

After the owner confirmed Xcode sign-in and requested installation, the standard
installer passed the signed Debug build, strict signature and bundle-identity checks,
in-place installation and normal launch on iPad ni Paj. Evidence:
`build/sp053/ipad-install-signed-in.log` and its timestamped installer logs. No uninstall
or data reset was performed. This supersedes the deferred-install status above;
final simulator runtime and physical feature acceptance gaps remain open.

## Owner correction — optional folder link (2026-10-25)

Supersedes the earlier details placement and always-create/rename rules. Owner requested
Linked Folder only inside Edit, explicit existing/new/none selection, direct filing of
new note/link assignments, and automatic folder creation only when creating new material
without a link. No new persistence schema or migration is introduced.

Affected modules: PlanEditorView/PlanLinkedFolderPicker/PlanEditorDraft for presentation
and acknowledged revisions; PlanAssignmentPicker and PlanStudyTools for both creation
entry points; PlanCommandService and CollectionsStore for checked create/link/file commands.
Tests cover optional decode/reopen, unlink followed by autosave and material creation,
shared existing folders/custom metadata, moved folders, idempotent folder commands,
all note types, stale attachments and access rejection. Final evidence follows below.

### Optional-folder verification checkpoint — 2026-10-25

The first focused run rejected new-folder creation because access validation queried
the published store before the new folder existed there. Validation now checks the
proposed snapshot's complete active ancestor chain and credentials before publishing.
The focused rerun passed **46 tests, 0 failures** (`build/sp053/optional-folder-r2.log`).
The final source then passed **466 unit tests, 0 failures**, including new concurrent
folder-choice and unknown-credential regressions (`build/sp053/optional-folder-final.log`).
This supersedes the earlier 460/461 unit checkpoint. The UI check and signed device
build/install are tracked separately below; unit success does not close physical acceptance.

### Optional-folder device delivery — 2026-10-25

Signed device build passed (`build/sp053/optional-folder-device-build.log`). The standard
installer then passed its build, strict signature/bundle identity checks, in-place
installation and normal launch on iPad ni Paj (`build/sp053/optional-folder-ipad-install.log`).
Existing app identity and study data were preserved without uninstall/reset. This delivery
includes optional existing/new/none configuration inside Edit and creation-triggered filing.
Physical interaction/appearance acceptance remains open.

## Inline main-Plan editing selected — 2026-10-25

Owner explicitly requested Edit mode within the main Plan screen, preserving all
editor features/autosave, followed by iPad installation. PlanDetailView now mounts
PlanEditorView inline instead of presenting its own edit sheet. The main header keeps
Exit Plan, save feedback and Done; Done/Exit await checked persistence, leaving invalid
or failed edits open. Reorder controls activate immediately in embedded edit mode.
The shared editor retains fields, assignment/section commands, folder customization,
reset, duplication, archive and Trash. A successful Trash closes the Plan; duplication
returns to its original contents. Assignment/folder pickers remain subordinate sheets.
New Plan creation retains its existing route. No persistence schema/provider/reader
behavior change is selected. Tests and final deployment evidence follow below.

### Inline-edit verification — 2026-10-25

- Final inline-edit source compiled and passed **46 focused Plan unit tests**, zero
  failures, and **1 UI test**, zero failures, on iPad Pro 13-inch (M5) simulator.
  `PlanUITests.testInlineEditKeepsPlanHeaderAndAutosavesWithoutAnotherModal` confirms
  the original header stays hittable, the title editor fills the main workspace, no
  modal Save bar appears, the folder picker opens, Done returns to contents, and edits
  survive relaunch. Evidence: `build/sp053/inline-edit-tests.log` and
  `build/sp053/inline-edit.xcresult`; screenshot attached to that UI result.
- The preceding optional-folder final unit suite passed 466/466. The later change is
  presentation/lifecycle only, verified by the focused Plan suite and UI test above.
- The earlier optional-folder UI attempts failed in automation focus/scroll setup;
  they are not green evidence. The inline full-width UI flow now verifies the chooser
  opens and None survives relaunch. Physical use and all unexecuted cases remain open.
- Signed Debug device build: **BUILD SUCCEEDED**,
  `build/sp053/inline-edit-device-build.log`. Final standard installer result follows.

### Inline-edit iPad delivery — 2026-10-25

Standard installer passed signed build, strict signature/bundle checks, in-place install
and normal launch on iPad ni Paj (`build/sp053/inline-edit-ipad-install.log`).
Version remains 1.4.0/build 28; no uninstall/reset or data cleanup. This supersedes
previous edit-modal presentation. Owner physical interaction acceptance remains open.

## Day/Section material folders selected — 2026-10-25

Owner requested a linked Plan folder containing Day/Section subfolders for their
assignments, and the Plan itself in the top-level Items area. This is shared filing
of the same Plan record, not a divergent duplicate Plan.

PlanSection adds optional materialsFolderID, decoding nil for older records. The
serialized Collections writer creates a managed child per section on the next linked
Plan save/ensure, names it from the custom section title or prefix/ordinal, and files
only that section's note/link targets and reference-only Scripture items there.
Shared targets used in multiple sections belong to each section folder. The root keeps
the Plan reference; current assigned materials previously filed flat there are moved
into their section folders. Other source memberships and unrelated root contents stay.

Stable section IDs keep the child identity through rename/reorder. Moves transfer the
managed filing edge to the destination section; original note/link content is unchanged.
Removed assignments/sections retain prior material/folders. Root relinking creates a
fresh section tree and keeps the old tree. Unlinking preserves it and does not force
a root creation. New note/link creation uses its section's folder immediately, with
existing receipt/retry/access guards. Duplicates clear section-folder ownership.

Affected modules: Core/Plans/StudyPlan and PlanCommands; CollectionsStore's atomic
organizer; both Plan creation entry points and editor routing; tests and contracts.
No Notes format, provider behavior, schema version or destructive deletion is selected.
The previous binaries can decode the optional field but do not maintain this hierarchy;
reinstalling an older build may flatten filing/lose section ownership on subsequent writes.

Initial focused run: **48 tests passed, 0 failures** (`build/sp053/section-folders.log`).
Final tests add legacy flat-layout upgrade, per-day sharing/reopen, optional-field decode,
rename/reorder/move/relink, removed-material retention and locked-child atomic rejection.
Final suite/UI/device evidence follows below.

### Section-folder verification checkpoint — 2026-10-25

Final source passed **469 unit tests, 0 failures**, including the three new section
organization/compatibility/access regression cases. Log: `build/sp053/section-folders-r2.log`.
The first combined attempt hit a test-fixture compile error (`add` local shadowed
XCTest attachment method); corrected before rerun. Signed device build passed
(`build/sp053/section-folders-device-build.log`). Documentation links and
`git diff --check` passed. UI and install outcomes follow below.

Section-folder UI check passed: `PlanUITests.testPlanFolderShowsDaySubfoldersAndScriptureInsideItsDay`
verified a Plan and Day 1 child at the linked root, then opened Day 1 and found only its
Scripture assignment rather than the top-level Plan. Screenshot attached to
`build/sp053/section-folders-r2.xcresult`; log: `build/sp053/section-folders-r2.log`.
This is simulator evidence; physical owner acceptance remains separate.

### Section-folder iPad delivery — 2026-10-25

Standard installer passed signed build, strict signature/bundle checks, in-place
installation and normal launch on iPad ni Paj. Evidence:
`build/sp053/section-folders-ipad-install.log`. Version remains 1.4.0/build 28;
no uninstall/reset or study-data deletion. Existing linked Plans adopt section filing
on their next save/material-creation command, not through an eager startup migration.
Owner physical acceptance remains open.

## Strict Plan ownership and cascade Trash selected — 2026-10-25

Owner requested mandatory immutable Plan folders, linked deletion from either side,
context-specific confirmation, removal of the Edit help note, and completed-section
progress. Owner explicitly chose **keep items shared elsewhere**. These instructions
supersede the earlier optional existing/new/none folder behavior.

- New Plans create dedicated roots immediately in the same checked commit. Legacy
  Plans adopt a valid unique root or acquire one non-destructively; normal root updates
  reject nil or replacement IDs. The folder chooser is removed; Edit displays the fixed
  folder read-only, without the “Assignments are arranged…” help note.
- Main Plan progress and Collection captions count fully completed, nonempty sections.
  Empty sections are not complete; the Plan stamp requires all sections complete.
- Delete Plan / Delete Plan folder confirmations explain the paired deletion and
  retention of shared items. Both route to one checked tree-Trash command; children
  retain their parent links rather than being promoted. Nested owned Plans in the tree
  are included as a group. Items referenced by another folder or Plan (including its
  Trash) remain available; source Bible text and actual annotation ink are never erased
  by deleting a Collections reference.
- Exclusive Collections-owned items are held in a typed PlanTreeTrash bundle. Notes
  keeps its own Trash. A durable pending-action flag is committed before Notes changes;
  retries and launch/foreground reconciliation finish an interrupted phase. A failed
  initial Collections write changes neither Notes nor active Plan/folder state.
- Restore either side restores the group, exclusive items and retained tree. Permanent
  deletion/expiry purges its Collections group; Notes retains its independent Trash
  retention. Existing copied credential requirements remain sticky.

### Data compatibility and boundaries

Collections schema **5** is sticky after ownership activation; v1–4 remain readable.
It adds required planLifecycleActivated and planTreeTrash fields. Existing wrapper
version 2 remains; both current and fallback generations are promoted so older readers
fail closed instead of dropping recovery bundles. The pre-activation envelope is
retained as `before-plan-lifecycle.collections`. Full backup accepts Collections v5;
restore preserves the activation guard. No user reset, backend or secret changes.

Affected owners: PlanEditor/Detail/Lifecycle UI, Collections commands/store/repository,
Notes checked Trash batching, Root lifecycle reconciliation, Settings confirmations,
backup inspection, model progress and tests. No real user data is deleted by testing.

Verification: an initial focused run found an autosave merge that retained the old nil
root after the first in-flight mandatory-folder save. The draft now adopts acknowledged
root/section identities while retaining newer content edits. Subsequent full run passed
**475 unit tests, 0 failures** (`build/sp053/strict-plan-r3.log`). Further final tests
cover write-failure rollback and sharing across multiple deleted/restored Plans.

Strict-lifecycle final source passed **477 unit tests, 0 failures** in
`build/sp053/strict-plan-verified.log`. The signed Debug build passed
(`build/sp053/strict-plan-device-final.log`). The first UI attempts exposed native
iPad confirmation-popover Cancel/query assumptions; Plan deletion now uses the existing
centered confirmation component with explicit Cancel and a distinct confirmation ID.
The final UI flow is recorded separately below. Relative-document links and
`git diff --check` passed.

### Strict-lifecycle UI verification — 2026-10-25

`testStrictPlanAndFolderDeleteConfirmationsAndSectionProgress` passed on iPad Pro
13-inch (M5) simulator. It verifies fixed-folder UI/no arrangement help, 0/1 → 0/2
section progress, Plan delete cancellation/confirmation, removal of its paired folder,
then folder delete cancellation/confirmation and removal of its Plan.
Evidence: `build/sp053/strict-plan-ui-menu.log` and
`build/sp053/strict-plan-ui-menu.xcresult`. The prior long-press context-menu attempt
stalled in automation and was interrupted; the passing run uses the folder action
menu and the same command. Actual iPad feature/privacy acceptance remains owner work.

### Strict-lifecycle iPad delivery — 2026-10-25

The standard installer passed signed Debug build, strict signature/bundle identity,
in-place installation and normal launch on iPad ni Paj (1.4.0/build 28). Evidence:
`build/sp053/strict-plan-ipad-install.log`. No uninstall or data reset. The only final
copy adjustment after the passing suite is the unsaved New Plan folder label
“Created automatically” instead of “None”; the installer rebuilt that source.
No real personal Plan/folder/content was deleted during verification. Accessible old
Plans adopt fixed ownership non-destructively. Physical owner acceptance remains open.

## Scripture assignment editing selected — 2026-10-25

Owner requested editable added Scripture from both Plan view and Day/Section folder
items and explicitly said continue. Plan content Scripture rows now open the shared
PlanScriptureAssignmentEditor; folder Scripture items open the same editor, with Read
Scripture retained in their action menu. The existing inline Replace command is prefilled
as well. PlanAssignmentPicker seeds the current book/chapter/whole-chapter-or-range,
restricts this editor to Scripture and validates the selection before Save Scripture.

PlanCommandService.replaceScripture checks stable Plan/section/item identities, access,
expected revision, Scripture-only payloads, reference system and capacity. It submits
through the existing sole writer/reference validator. The first item identity stays,
expanded chapters follow it, and changed assignments reopen completion. An unchanged
selection preserves completion; unrelated progress and folder identity stay intact.
Folder projections update from the same Plan data, with no copied scripture text.
Rejected stale/invalid writes retain the picker and selection with an error; Cancel
leaves persisted content unchanged. Revoked access conceals/dismisses the shared editor.

No new schema/provider/content rights behavior or new study feature is selected.
Affected modules: PlanAssignmentPicker/PlanEditorView, PlanDetailView, CollectionDetailView
and CollectionArtifactRow, the shared Scripture editor, command service and regressions.
Final tests/device evidence follows below.

### Scripture-editing verification checkpoint — 2026-10-25

Final product source passed **481 unit tests, 0 failures**, including four new
PlanScriptureEditingTests covering shared identity/range persistence, chapter expansion,
unchanged/stale saves and invalid/trashed targets. Evidence:
`build/sp053/scripture-edit-final.log`. Signed Debug build passed
(`build/sp053/scripture-edit-device-build.log`). The first UI attempt failed in shell
setup: the tab dock hid before the element-based tap. The retry uses a coordinate tap
to avoid the test's scroll/query delays exceeding the dock timer; product shell code
was not changed. Final UI/device evidence follows below.

### Scripture-editing iPad delivery — 2026-10-25

Standard installer passed signed build, strict signature/bundle identity checks,
in-place installation and normal launch on iPad ni Paj. Evidence:
`build/sp053/scripture-edit-ipad-install.log`. Version remains 1.4.0/build 28.
No uninstall/reset, data cleanup or changes to stored Bible content were performed.
Final UI retry is recorded separately; owner physical interaction acceptance stays open.

### Nested-folder reader correction

The UI retry reached and saved Plan-view editing, then exposed a real nested-folder
problem: CollectionDetailView did not pass ReaderSession into its child destinations.
The editor opened without a book catalog/stepper. Child folders now receive the shared
reader recursively. A separate earlier retry used the wrong generic Stepper button
identifier; the UI fixture now uses the runtime's specific Increment identifier.

The dedicated shared editor restricts tabs to Scripture; inline Replace retains its
existing note/link replacement choices while seeding the Scripture tab. The corrected
source is undergoing a fresh full unit/UI run and signed build before reinstall.

The corrected recursive-reader source passed another full run: **481 unit tests,
0 failures**, `build/sp053/scripture-edit-verified.log`. Signed Debug build passed
(`build/sp053/scripture-edit-device-final.log`). The final UI run checks the actual
Plan → folder → Plan reference updates and is separate from the preceding failed
UI attempts. Product source has remained unchanged since this corrected run started.

### Final shared Scripture-edit result — 2026-10-25

The corrected source passed **481 unit tests, zero failures**
(`build/sp053/scripture-edit-verified.log`). The final UI retry passed
`testScriptureCanBeEditedFromPlanAndItsDayFolder`, verifying current-selection seeding,
Plan save to Genesis 2, folder save to Genesis 3, the Plan reflecting Genesis 3, and
Cancel preserving the saved reference. Evidence: `build/sp053/scripture-edit-ui-final.log`
and `build/sp053/scripture-edit-ui-final.xcresult`. Earlier failed retries are diagnostic
history: shell timing, Stepper identifier, missing nested ReaderSession, and Back-button
identifier. The nested reader was the product defect and is fixed recursively.

Signed corrected build passed (`build/sp053/scripture-edit-device-final.log`). First
corrected install attempt hit CoreDevice remote-connect error before installation
(`build/sp053/scripture-edit-ipad-final.log`). The standard installer retry passed
signed build, signature/bundle checks and **in-place installation** on iPad ni Paj
(`build/sp053/scripture-edit-ipad-retry.log`), 1.4.0/build 28. Its launch was explicitly
blocked by iPadOS Locked/FBS error 7. Owner was asked to unlock or open manually; no
launch success is claimed for this corrected build. No uninstall/reset or Bible-text
mutation occurred. Documentation links and git diff --check passed.

After the owner reported the iPad unlocked, normal launch was retried twice. Both
were still rejected by iPadOS with Locked/FBS error 7. Evidence:
`build/sp053/scripture-edit-unlocked-launch.log` and
`build/sp053/scripture-edit-unlocked-launch-retry.log`. Corrected installation remains
successful; manual launch from the unlocked Home Screen is still needed.

## Owner-authorized v1.5.0 release — 2026-10-25

Owner authorized commit, push, merge and release. Candidate is v1.5.0/build 29;
scope is the completed SP-053 refinements above, excluding SP-050–052 and unrelated
local Bravado/icon files. Checks: full unit suite, focused native Plan journeys,
project/plist lint, documentation links, staged hygiene, hosted release workflow.
Physical owner acceptance remains open. Release evidence: `build/v1.5.0-release/`.

### v1.5.0 / build 29 signed device delivery — 2026-10-25

The standard installer passed build, strict signature and bundle-identity checks,
in-place installation and normal launch on iPad ni Paj. A subsequent device app
query confirms `com.personal.SophiaScriptura`, version 1.5.0, build 29. Evidence:
`build/v1.5.0-release/ipad-install.log` and `device-apps.json`. No uninstall/reset
was performed. Physical feature acceptance remains open.

### Versioned candidate checks

Full versioned unit suite: **481 tests, zero failures**, result bundle
`build/v1.5.0-release/verification.xcresult`. Project lint, 282 local Markdown links,
staged whitespace, credential-pattern and large-file audits passed. The staged set
contains only SP-053 implementation, tests, aligned docs and release metadata.
Unrelated Bravado/icon directories remain untracked and excluded.

### Final local release verification

Versioned candidate: **481 unit tests and three native UI journeys passed**.
The initial combined run passed units, inline edit/relaunch autosave, and shared
Scripture editing, then stopped on an ambiguous XCTest Collection actions selector.
Only that selector was disambiguated with firstMatch; the focused lifecycle retry
passed all Plan/folder confirmation, Cancel/delete and section-progress checks.
Evidence: `build/v1.5.0-release/verification.log` and `lifecycle-ui.log`, with matching
result bundles. App product source did not change between these runs. Signed iPad
build, install, launch and device version query passed. Physical acceptance remains open.
