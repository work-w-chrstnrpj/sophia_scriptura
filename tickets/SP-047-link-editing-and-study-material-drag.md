# SP-047 — Link editing and study material drag/drop

Status: implemented, simulator-verified and installed/launched on iPad, 2026-10-16. Physical owner acceptance remains open.
Milestone: post-v1.3.0 Collections refinement. Owner selected these fixes directly.

## Outcome and boundaries

- Saved links offer Edit in the open link sheet (Collections and Scripture hub) and
  Edit Link in Collections hold/swipe More actions. Edit title and URL, then Save or
  Cancel. Invalid/non-http(s) addresses keep the editor open with an error.
- Link edits preserve ID, creation date, verse/edition anchors and all memberships.
  Blank titles use the URL host; existing 120-character title limit applies.
- Drag a directly listed study material onto a folder/subfolder tile. This moves
  only the current source membership to the destination. Assignments elsewhere
  remain. No Folder can file unfiled items. Descendant-only aggregate rows cannot
  drag because their source membership is ambiguous; open the owning folder first.
- Folder drag/reparenting remains a separate payload and command. No schema change,
  content copy, external drag export, destructive migration or release publication.

## Ownership and access

CollectionsStore owns validated link updates and moveStudyMaterial, which rechecks
active source/destination ancestry, explicit membership/unfiled status, known item
identity and Notes/Collections access at receipt. Rejected moves leave all edges
intact. CollectionFolderMove adds an own-process org.sophia.study-material payload
containing only artifact/source IDs, capped at 512 bytes with strict UUID decoding.
AppInfoSupplement declares the type. Folder tiles accept both typed drag kinds;
material rows provide the separate material kind and refresh Notes metadata first.
StudyMaterialSheets owns the shared editor and observed current link presentation;
CollectionDetailView owns local modal routes and dismisses on relock. Global Scripture
link access follows the existing independently-accessible study-artifact policy.

## Verification

CollectionsStoreTests: invalid URL rejection, identity/anchor/filing preservation,
blank-title host fallback, edit/reload, source-only move/reload, stale/unfiled races,
archived ancestor/trashed target rejection and unknown-credential denial.
ItemProtectionTests: existing route/command/access regressions.
Collections UI: create parent/child/link, edit title/URL, drag material into child,
verify source removal, destination inclusion and relaunch persistence.
Evidence: `build/sp047/`. Physical touch/Pencil, VoiceOver, split view, longer title
and real owner-data acceptance remain separate from build/install and simulator QA.

## Evidence — 2026-10-16

- **69 tests passed**, zero failures: 33 CollectionsStoreTests and 36
  ItemProtectionTests in `build/sp047/regression.xcresult`.
- **One UI journey passed**, zero failures, in the same bundle: saved-link title/URL
  edit, native material drag from parent into child, source disappearance,
  destination inclusion and edited URL/membership persistence after relaunch.
  The edited-link screenshot was exported and reviewed.
- App type declaration and `git diff --check` passed. The first compile/test exposed
  a missing exported material UTI declaration, which was added before the passing
  regression. No whole-suite, physical drag or live-provider test is claimed.
- Installer dry-run, signed Debug build, strict signature/identity, in-place iPad
  install and normal launch passed. First installation hit a CoreDevice connection
  reset; immediate retry succeeded. Evidence: `build/sp047/ipad-install-retry.log`.
  Installed-app query confirms **1.3.0/build 25**, `com.personal.SophiaScriptura`
  (`build/sp047/installed-app.log`). Existing app/data preserved, without uninstall,
  reset or translation sync. The SP-046 compact card correction is included.
- These are uncommitted post-release fixes; v1.3.0 tag/release remains immutable.

Owner header polish (2026-10-16): collection-detail Arrange, New Subfolder, Study
Material View and Add controls show icons only, with descriptive accessibility
labels retained and 44-point targets. Menu actions and creation behavior are unchanged.

Header polish verification passed: the existing nested-folder/Arrange UI flow in
`build/sp047/icon-headers/check.xcresult`; screenshot reviewed for all four icon-only
controls. Signed build, strict signature, in-place iPad install and normal launch
passed (`build/sp047/icon-headers/ipad-install.log`). No unit rerun was needed for
this presentation-only edit; whitespace validation passed.

## Owner-authorized v1.3.1 release — 2026-10-16

The owner authorized commit, push, merge and publication of the current fixes.
Version is 1.3.1/build 26, with SP-046 compact/red Delete card included. This
supersedes earlier no-publication scope for this delivery. Existing v1.3.0 stays
immutable. Final evidence lives under `build/v131-release/`.

Release-version verification: all 406 unit tests passed with zero failures in
`build/v131-release/verification.xcresult`. Signed 1.3.1/build 26 installed in place
and launched successfully; installed-app query confirms version and bundle identity.
See `build/v131-release/ipad-install.log` / `installed-app.log`.

Final release gate passed: **406 unit tests and three UI journeys, zero failures**
in `build/v131-release/verification.xcresult`. All release code was unchanged during
this run. Staged whitespace, credential-pattern, large/generated-file, plist/project
and release-link checks passed. Publish via the existing main Release workflow after
pushing development and fast-forward merging into main; preserve the pre-release
recovery ref at 8d654bc. Physical acceptance remains open independently.
