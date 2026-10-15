# SP-046 — Points to Ponder and study material conversions

Status: implemented, simulator-verified, installed and launched on iPad (2026-10-15). Physical feature acceptance remains open.
Milestone: v1.3.0 personal-study refinement, build 25.
Owner selected implementation and in-place iPad installation. Publication is separate.

## Visible behavior

- Collections → open a folder or No Folder → Add Study Material → New Point to Ponder.
  Enter a nonempty reflection question (up to 200 characters, matching note-title capacity).
  The material appears in folder lists/cards and the Points to Ponder filter.
- Opening shows the question, Close, Delete and Explore. Explore dismisses the question
  modal before presenting a second modal. Choose Send Question to Companion or Turn into
  a Note. The latter dismisses Explore and opens the existing New note modal with the
  question as its editable title. Cancel creates no note. Create opens the existing editor.
- Companion creates a separate conversation through the configured shared provider/model
  and existing prompt preset, then sends the question through the normal send pipeline.
  Missing configuration or an in-flight response leaves the question and shows guidance.
  Failed sends retain the question and normal Companion retry/draft behavior.
- Bookmark cards offer Turn into a Gleaning. The same passage ID, reference, translation,
  exact excerpt/spans, creation date and memberships remain; the insight becomes editable.
- Gleanings offer Turn into a Note. New note title is `Gleaning from "Book Chapter:Verse
  (Translation)"` (including verse ranges). The editable note includes reference, passage
  text and insight. Source gleanings/questions stay saved so cancellation or failed saves
  cannot lose the source. New notes/conversations inherit accessible source memberships.
- Point Delete is confirmed and moves it into Settings → Trash → Points to Ponder.
  Restore retains memberships. Permanent delete is separately confirmed; normal 30-day
  retention purges expired points and their membership edges.

## Ownership and compatibility

`CollectionModels` owns PointToPonder and title/content derivation. `CollectionsStore`
owns creation, lifecycle, projection, membership and bookmark conversion. Collections
file generations and all-data backup include points. Legacy Collections schemas 1/2
load with an empty points list; stores with points write schema 3, which older apps
reject safely. No reset or one-time destructive migration is required. Protection
bindings remain; collection routes and modal dismissal use existing access guards.

`PointToPonderSheets` owns creation and the serial modal state machine. Existing
`NoteCreatorSheet` accepts an initial editable title/content; NotesSession retains note
creation/editing/persistence ownership. Root wires Companion through its normal provider,
key, preset and send guards. No provider credentials enter Collections storage.

## Verification and limits

Automated targets: CollectionsStoreTests, NotesTests, ItemProtectionTests, focused
Collections UI journeys, and Companion handoff coverage. Verify legacy decoding,
round-trip/backup, trash/restore/expiry, locked creation, stable passage identity,
editable prefilled title, cancellation and editor navigation. Evidence is under
`build/sp046/`. Physical layout, Pencil, accessibility and actual provider responses
remain owner checks; build/install/launch alone do not close them.

## Evidence — 2026-10-15

- **111 domain/protection/Companion tests passed**, zero failures, in
  `build/sp046/final.xcresult`: 29 Collections, 45 Notes, 36 ItemProtection,
  and one new Companion reflection-question test using the mock adapter.
- **Two distinct focused UI journeys passed**. Bookmark → Gleaning → Note,
  including copied reference/insight content and exact title, passed in
  `build/sp046/ui-r3.xcresult`. Point creation → question → Explore → Note,
  cancel/reopen/create and retained source passed in `build/sp046/question-r4.xcresult`.
  Screenshots were exported and reviewed (question card and prefilled New note).
- Initial compile exposed the new artifact tint switch; it was completed. UI checks
  exposed the absent No Folder creation entry point, which now has Add. The reopen
  test also needed an explicit wait for the next modal button before tapping.
  Earlier combined bundles contain these failures; they are not reported as green.
- Installer dry-run passed. Signed Debug build, strict signature, bundle identity,
  in-place install and normal launch passed on **iPad ni Paj**, bundle
  `com.personal.SophiaScriptura`, version **1.3.0/build 25**. First install was
  blocked by CoreDevice 4016; after the owner unlocked/reconnected, retry succeeded.
  Logs: `build/sp046/ipad-install.log` and `build/sp046/ipad-install-retry.log`.
  No uninstall, storage reset or translation sync was performed.
- Documentation relative links and `git diff --check` passed. This is focused
  verification, not a full-suite or live-provider run. Physical touch/Pencil,
  accessibility, owner-data upgrade behavior and actual provider response quality
  remain owner acceptance. No commit, push, merge, tag or publication was requested.

## SP-046 owner follow-up — 2026-10-15

The shared save/folder chooser now includes only active Collections. Trashed and
archived folders are excluded, including branches under archived ancestors; active
children promoted by folder deletion remain available. Restoring/unarchiving makes
eligible destinations available again. Existing saved membership edges are retained.
Bookmark cards show See the whole chapter first and Turn into a Gleaning below it,
with matching full-width dimensions. Turn into a Gleaning uses a transparent,
outlined secondary style; See the whole chapter retains its accent fill.

Follow-up verification: CollectionsStore outline lifecycle regression and focused
save-bookmark / conversion UI checks, including button order and equal dimensions.
Evidence: `build/sp046/fixes/checks.xcresult`: **30 Collections tests and two UI
journeys passed**, zero failures. The deleted-folder save regression passed; the
bookmark UI case verifies action order, equal width/height and successful conversion.
Bookmark screenshot reviewed. Signed Debug build, strict signature/identity, in-place
iPad installation and normal launch passed (`build/sp046/fixes/ipad-install.log`).
Installed-app query confirms 1.3.0/build 25 (`installed-app.log` beside it). Existing
app/data preserved. Physical owner acceptance remains open.

Gleaning card follow-up: **Turn into a Note** sits below **See the whole chapter**,
using the same transparent outlined full-width style and height as the bookmark's
**Turn into a Gleaning** action. Conversion/title/content behavior is retained.

Transparent bookmark action and Gleaning action follow-ups passed the focused
bookmark → gleaning → note UI journey, including both conversion buttons' order,
labels and equal dimensions. Final result: `build/sp046/fixes/gleaning-layout.xcresult`.
Signed build, strict signature, in-place install and launch passed on the owner's
iPad; see `gleaning-layout-ipad-install.log` in the same directory. Version remains
1.3.0/build 25. No data reset or source-release publication occurred.

Final wording correction: button labels are “Turn into a Gleaning” and “Turn into
a Note”. Source, UI expectations and docs agree; whitespace validation, signed
build, strict signature/identity, in-place iPad install and normal launch passed.
Evidence: `build/sp046/fixes/button-labels-ipad-install.log`. Version 1.3.0/build 25;
existing data retained. UI automation was not rerun for this wording-only change.

## Owner-authorized v1.3.0 publication — 2026-10-15

The owner authorized commit, push, merge and release of the current worktree.
Full local unit suite: 403 passed, zero failures (`build/v130-release/unit.xcresult`).
Final-label focused UI verification is recorded under `build/v130-release/ui.xcresult`.
This authorization supersedes earlier statements that publication was outside scope.
Physical feature/provider acceptance remains open independently of publication.

Final release UI gate: all three selected journeys passed, zero failures, on iPad
(A16) simulator in `build/v130-release/ui.xcresult`. The final labels, transparent
button dimensions/order, note content/title, deleted-folder exclusion and question
cancel/reopen/create flows are verified. Local release gates are complete.
