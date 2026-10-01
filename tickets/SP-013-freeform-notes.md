# SP-013 — M4 Study Notes

- Type: implementation. Status: done. Owner: Frontend UI/UX Developer.
- Selected by owner: “is M4 can be implemented? Please check what to do, then implement it.”
- Requirements: REQ-008, REQ-009, REQ-016, REQ-017.
- Inputs: SP-004, SP-005, SP-006; M2 passage identities. M3 physical Pencil/Files
  acceptance is still pending and is not implicitly closed by this work.

## Prior owner-selected implementation — 2026-09-29

Owner: “Yes, now implement it.” At that point the acceptance contract was the
[study-page design](../docs/design/notes-screen-specification.md). It supersedes the
original object-canvas interactions below: centered flowing text, fixed page/column
width, page-anchored Pencil overlay above everything, and finger-controlled floating
objects with resize handles. Full Scripture reader remains alongside Notes. Inline
citations navigate and selected source text can start or extend notes. Personal-noting
permission for the existing translations was confirmed by the owner.

Affected modules: Core/Notes, Infrastructure/Notes, NotesSession, Notes/Editor, shared
reader selection actions and Root composition. Preserve original old-note bytes before
v2 publication. Exclude Companion implementation, Collections membership, full-app backup
and redesign of Scripture annotations. Verify body/ink/object independence, old-note
conversion, save/reopen/recovery, citations, gestures and reader navigation. Physical
Pencil behavior, Files and the owner's unsupported-data/crash report require explicit
results. Status remains in_progress.

This describes the 2026-09-29 implementation selection. The owner subsequently selected
the two-type plan for execution with “Can we execute-code-change base on the plan we create?”

## Owner-selected two-type implementation — 2026-10-01

After testing the installed build, the owner reported Pencil input becoming text, difficulty
leaving typing, an incomplete Pencil palette, Pencil failing when Scribble is disabled, and
requested a way to hide Scripture. The owner proposed two separate document behaviors:

- **Canvas:** open object workspace; all inserted content, including Pencil drawing, is an
  object that can be positioned and transformed. Links are cards.
- **Page:** flowing text with Pencil ink fixed above it. Links are inline hyperlinks and
  Scripture references remain inline citations.

The selected two-type plan supersedes the earlier one-editor interaction model. The source
now includes the chooser, typed schema, Canvas ink transforms, Page attachments, Pencil
routing changes and persisted Scripture toggle. See the [design specification](../docs/design/notes-screen-specification.md).

### Selected implementation sequence

1. Reproduce Pencil routing on the physical iPad with Scribble enabled/disabled, body
   focused/unfocused; fix Page input arbitration and a reliable exit from typing.
2. Define a tagged Canvas/Page content value and type-specific validation while keeping
   shared note metadata, backup and recovery contracts.
3. Add the Canvas/Page creation choice and independent editing surfaces. Restore the full
   supported PencilKit inking/eraser palette; Canvas supports drawing-object selection,
   while Page ink remains fixed and unselectable.
4. Route Scripture into Canvas quote objects or Page inline citations. Add a default-visible
   Scripture-pane toggle that preserves ReaderSession position when hidden.
5. Upgrade snapshot payloads to v3. Map legacy notes with `page` data to Page and earlier
   object-only notes to Canvas; preserve IDs, geometry, drawing bytes and a byte-exact
   pre-upgrade generation. Keep v1/v2 readable and unknown versions protected.
6. Verify type-specific round trips, both creation journeys, pane toggle/navigation, legacy
   migration and physical Pencil behavior before considering M4 acceptance.

**Change mode:** feature redesign plus Pencil-input bug fix. **Roles:** Frontend UI/UX,
Backend & Database for the Notes document/recovery boundary, and SQA for device acceptance.
**Affected modules:** `Core/Notes/NoteDocument.swift`, `Infrastructure/Notes/`,
`Features/Notes/NotesSession.swift`, `Features/Notes/Editor/`, `Features/Notes/NotesView.swift`,
`Features/Notes/Editor/NoteScripturePane.swift`, `RootTabView.swift`, Notes unit/UI tests,
and the linked design/data/testing docs. No API/provider work is needed.

**Verification plan:** decode v1/v2 fixtures and prove type inference plus unchanged IDs,
frames, citations and ink; round-trip and recover both v3 content cases; cover creation,
editing, link rendering, citation routing and Scripture-pane toggle in UI tests; then repeat
Pencil behavior on the iPad with Scribble on/off and the editor focused/unfocused. Risks are
legacy misclassification, accidental page-ink movement, per-OS PencilKit differences and
higher live view memory on dense Canvases. Do not raise media/object limits before measuring
representative iPad content.

### Acceptance contract

- New Note clearly offers Canvas or Page; both share the same Notes library and metadata.
- Pencil draws ink rather than typing in either type with Scribble on or off. Page always
  keeps ink above content and fixed. Canvas ink is a movable/resizable object.
- Page editing exits reliably; its palette exposes the supported native inking and eraser
  choices. Canvas can select and transform drawings without affecting Page ink behavior.
- Canvas URLs render as cards; Page URLs are inline links. Verse citations return to the
  same reader passage; source metadata and translation authorization remain intact.
- Hiding Scripture retains passage and edition; citations reveal the pane and navigate.
- v1/v2 round-trip without content loss; v3 saves only the selected content case and
  preserves the pre-upgrade generation. Corrupt/unknown formats do not replace valid data.
- Physical-device acceptance repeats Scribble on/off, type-to-ink transitions, palette,
  background/reopen, and the previously reported unsupported-data/crash workflow.

Page inline images/tables and cross-launch Scripture visibility were selected as the
implementation defaults. Current status remains in progress pending physical acceptance.

### Implementation evidence and deviations

- Mode A, plan-first execution. Shared metadata plus one Canvas/Page payload; legacy notes
  infer their original editing type, and exact pre-v3 bytes are retained in
  `before-note-types.notes` without replacing `before-study-page.notes`.
- New Page attachments flow with text. Existing v2 Page floating objects remain editable
  in `legacyObjects` rather than being silently converted or lost.
- Dedicated surface controller types share viewport/input/object manipulation plumbing.
  This avoids duplicating the existing coordinate and touch-down fixes. Canvas reconciles
  PencilKit strokes into framed ink objects; Page keeps its single fixed overlay.
- The common paper ancestor receives the drawing recognizer and editable text suppresses
  Scribble. Full native inking/eraser items are retained; Canvas also retains lasso.
- The native palette can cover the bottom tabs. The toolbar can hide/show it while
  preserving drawing input; UI tests dismiss it before switching tabs. An initial test
  tapped the palette's Undo in place of the covered Scripture tab, explaining lost ink.
- Physical Pencil reproduction could not be automated. Scribble on/off, palette behavior,
  palm rejection, Files, and the original unsupported-data/crash workflow remain owner
  acceptance gates. No simulator result closes them.
- Signed iPad build and signature verification passed with Xcode 27.0. Installed over
  the existing app on the paired iPad A16 and launched successfully. No data deletion or
  translation sync. Logs: `build/sp013/two-types/device-handoff.log`, `install.log`,
  `launch.log`. Physical interaction acceptance remains pending.
- Automated verification: **28/28 selected checks passed across the final suite and
  affected retests**: 19 Notes model/recovery tests and 9 distinct Notes UI journeys.
  `build/sp013/two-types/acceptance.xcresult` passed all 19 model checks and 8/9 UI tests;
  the new Canvas test initially queried the intentionally hidden drawing overlay.
  After targeting the actual workspace, `final-ui.xcresult` passed all five affected
  UI retests, including Canvas drawing/move/reopen, Page typing/reopen, Page ink durability,
  inline table/pane persistence and hidden-pane citation navigation. No unresolved selected
  test failures remain. Simulator finger input exercises the common paper recognizer;
  it is not physical Pencil/Scribble acceptance.
- Final Canvas drawing screenshot was inspected: drawing object, selection/resize handle,
  Saved state and available editor controls are visible. `git diff --check`, local Notes
  Swift whitespace checks and documentation link checks passed. No commit or push made.

Focused verification command (Xcode 27.0, installed iPad A16 iOS 26.5 simulator):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project application/SophiaScriptura/SophiaScriptura.xcodeproj \
  -scheme SophiaScriptura \
  -destination 'platform=iOS Simulator,id=523DDB8A-9EF6-44ED-A4F8-F8059ECB7725' \
  -derivedDataPath build/sp013/two-types/DerivedData \
  -resultBundlePath build/sp013/two-types/acceptance.xcresult \
  -only-testing:SophiaScripturaTests/NotesTests \
  -only-testing:SophiaScripturaUITests/NotesUITests \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Use a fresh result-bundle path for reruns. The five final affected UI cases are recorded
by name in `build/sp013/two-types/final-ui.log`; the final `xcodebuild` result is success.
Xcode's post-run diagnostics helper still reports its default-toolchain `simctl` lookup
warning; that is separate from the successful test results.

## Original outcome and boundaries

Replace the Notes prototype entry point with a local blank-note library and expandable
editor: text, ink, images, links, tables, quotations, shapes, lists, explicit flat
grouping, tags, search/sort, cards/list, passage links, revisions and Files recovery.
Keep SP-006 available as a DEBUG experiment. Exclude M5 membership/full Save chooser,
AI, provider changes, nested groups, ink/group scaling, and automatic ink/text reflow.

## Ownership and sequence

1. `Core/Notes`: document values, object geometry, validation, edits and repository boundary.
2. `Infrastructure/Notes`: atomic document generations, integrity, media validation,
   archive validation and recoverable replacement.
3. `Features/Notes`: library, editing session/history, UIKit/PencilKit surface and object UI.
4. Root composition and Scripture hub: shared Notes session and attributed passage quotes.
5. Unit recovery/edit checks, simulator journeys, manual Pencil/Files walkthrough.

Presentation calls the session; storage implements the domain repository. Neither
the renderer nor SwiftUI views perform persistence. Production documents do not reuse
the disposable SP-006 fixture format or migrate its data.

## Original canvas acceptance (historical; superseded by study-page design)

- Create blank note, add/edit mixed objects directly, move/group/ungroup, undo/redo.
- Pan/zoom/window changes preserve geometry; offscreen objects remain reachable.
- Native tools, independent ink objects, plain/ruled/grid paper.
- Tags/search/title/date sort/cards/list; tombstone delete and restore.
- Verse quote preserves edition/reference/source; hub opens the same note.
- Autosave reports actual success; reopen, interrupted commit, corrupted latest revision,
  failed import, image/ink archive round trip and pre-restore recovery preserve data.
- Physical Pencil feel, realistic capacity, VoiceOver and Files workflow remain explicit
  device acceptance, separate from automated results.

## Evidence

The study-page redesign is implemented and simulator-verified. See the latest evidence
below. No M4 physical acceptance or completion is claimed yet.

## Original canvas scope and verification — 2026-09-29 (historical)

Production Notes now has blank documents, card/list library, local search, single-tag
filter, title/created/modified sorting, title/tags/paper editing, recoverable deletion,
and Notes-only Files export/replacement/pre-restore recovery. The UIKit canvas supports
independent direct text, ink, downsampled Files images, bounded tables, HTTP(S) link cards,
rounded rectangles, bullet/numbered text and immutable source quotes with commentary.
Objects have explicit checkmark selection, grouping, move/resize/stack/center controls;
viewport changes do not rewrite geometry. Native lasso stays within one ink object.

The verse hub creates an attributed WEB quote note and reopens the same UUID. Licensed
editions show a clear disabled quote action because saved-note and backup export rights
are not established by the existing Copy/Share grant. Validation also rejects licensed
source quote objects from Notes archives.
The SP-006 sample remains DEBUG-accessible and its data is not migrated. Existing M3 and
other workspace edits were preserved. No physical device installation was performed.

`build/sp013/seventh.xcresult` passed **15/15** selected checks: nine Notes model/recovery
checks, four Notes UI journeys and two affected shell regressions on iPad A16 Simulator,
iOS 26.5 (`523DDB8A-9EF6-44ED-A4F8-F8059ECB7725`). Checks cover grouping/clamping/undo,
invalid geometry/links/media, commit interruptions, corruption fallback, future schema
preservation, stale writes, actual serialized ink/source quotes, failed-autosave retry,
archive/pre-restore round trips, delete/restore, direct typing/relaunch, object controls,
rotation, verse-hub linking, DEBUG experiment reachability and shell/footer continuity.

Earlier runs exposed and led to fixes for macro/numeric binding compilation, canvas
origin/focus, ambiguous selection controls and list-row action handling. Earlier failures
are retained in `build/sp013/`. The portrait direct-text screenshot was visually inspected:
text, toolbar, save status and footer are visible. Automated checks do not establish
physical Pencil feel, VoiceOver, realistic maximum capacity or actual Files picker restore.

Bounded choices: one tag filter; 20×10 tables; Files image input; one rectangle shape;
no nested groups, ink/group scaling, full Save chooser, M5 memberships or PDF pagination.
These are explicit scope limits, not full word-processor or full-app-backup claims.
The [physical walkthrough](../docs/testing/sp013-ipad-guide.md) remains **Not Run**.
SP-013/M4 status at this checkpoint: **in_progress — current Page editor implemented;
physical acceptance and reported Pencil failure investigation pending**.

Final verification: `build/sp013/final.xcresult` passed nine Notes unit/recovery tests
and five Notes UI journeys, including synthetic ink across tab change/relaunch and a
landscape rotation assertion. The earlier `seventh.xcresult` also passed two affected
shell regressions. A simulator-only drawing reopen crash in a tiled UIKit paper view
was traced to the retained `build/sp013/ink-reopen-crash.ips`; the paper now draws
vector grid lines on the main view lifecycle, and the ink reopening journey passes.

After the quote-rights audit, `build/sp013/quote-policy.xcresult` passed ten Notes
unit/recovery tests and the WEB verse-hub UI journey. The added check rejects licensed
quote payloads, including payloads placed on a non-quote object, before saving or
importing an archive. The project records API.Bible Copy/Share permission but leaves
saved-note and JSON backup export rights edition-specific, so licensed source quoting
is disabled pending that decision. No new provider access or credentials were used.

The iPad Pencil, VoiceOver, Files picker restore and representative-capacity cases
remain Not Run. M3's own physical acceptance is also still separate and pending.

`build/sp013/landscape-visual.xcresult` passed the focused object/group/rotation journey.
The app frame reported landscape, but app-only and full-screen simulator captures had
inconsistent rotation framing. They do not establish landscape visual acceptance;
inspect the actual iPad in both orientations in the physical walkthrough.

## Owner iPad installation — 2026-09-29

The signed M4 Debug build succeeded for the paired iPad A16 and kept the existing
`com.personal.SophiaScriptura` bundle identifier. It installed over the existing app
without an uninstall, then CoreDevice launched it normally. Evidence:
`build/sp013/device-build.log`, `device-install.log`, and `device-launch.log`.
This establishes installation and launch only; the physical Pencil, Files, VoiceOver,
landscape and representative-capacity walkthrough remains for owner testing. M4 stays
**in_progress** until those results are reviewed.

## Study-page redesign evidence — 2026-09-30

Implemented the approved fixed-width body, topmost fixed Pencil overlay, direct finger
object movement/resize, fixed typography, full side-by-side Scripture reader, inline
citations and authorized source selection capture. New notes need no type or Collection.
Old object coordinates are preserved; old drawings are composed into page coordinates.
The original v1 generation is retained byte-for-byte before the first v2 save.
Companion integration remains deferred; ordinary clipboard paste works in the editor.

`build/sp013/redesign/final.xcresult` passed **16/16 Notes model/recovery tests** and
**5/6 UI journeys**. The new direct corner-resize test failed because the finger could
leave the object before the pan recognizer began. The controller now captures the
touch-down location, and `build/sp013/redesign/resize-fix.xcresult` passed the remaining
journey, including finger movement, corner resize, unchanged body text and Saved state.
Thus all 22 selected checks passed across these runs; the aggregate first run remains
a recorded failure. Earlier focus tests also caught and verified a keyboard-scroll tap
target fix. The successful portrait screenshot was inspected and shows the reader,
typed body, selected/resized shape and native Pencil palette together.

Covered: UTF-16 citations, licensed quote metadata, body/ink/object independence,
undo/reopen, old ink translation, exact v1 preservation, corruption/commit recovery,
save retry, archives, grouping, rotation, synthetic ink reopening, verse-hub routing,
and retained DEBUG experiment. Synthetic finger ink does not prove Apple Pencil feel.

`build/sp013/redesign/device-final-build.log` confirms the final signed iOS Debug build
succeeded. At the time this status was written, CoreDevice reported the paired iPad
unavailable, so installation had not yet occurred. The owner connected it afterward;
the completed installation and launch are recorded below.
`git diff --check` passed. Existing unrelated workspace work is preserved.

The former rejection of valid ink outside its handwriting box is reproduced and fixed.
The owner's exact device crash/save error has not been reproduced or conclusively
diagnosed. Physical Pencil/palm rejection, citation navigation feel, Files picker,
VoiceOver, narrow windows and realistic capacity remain in the revised iPad guide.
SP-013/M4 status at the 2026-09-30 pre-install checkpoint: **in_progress — Page editor
implemented; device installation was still pending at that moment**.

## Owner iPad installation — 2026-09-30

After the device became available, the signed build above installed over the existing
app and Sophia launched successfully. Evidence: `build/sp013/redesign/device-install.log`
and `device-launch.log`. No uninstall was performed. Physical study-page and Pencil
acceptance remains in progress.

The 2026-10-01 Canvas/Page proposal supersedes that single-editor behavior as the planned
direction. The owner subsequently selected and received the two-type implementation recorded above.


## Owner-selected workspace refinement — 2026-10-01

Selected scope: eleven reported Canvas/Page UX issues. Compact controls, title renaming,
dotted paper, footer/Objects/Done typing removal, floating contextual actions, genuine
shape/emoji choices, cached link previews, full bounded Canvas and theme-aware neutral ink.
Notes editing overlays the dock; other tabs keep their layout. Page coordinates stay fixed.
Optional style fields and validated link thumbnail payloads retain old v3 decoding; no new
migration or destructive operation. Excludes system stickers, arbitrary attachments,
Companion integration and complete Freeform feature parity.

Implementation and automated verification are complete for this refinement. M4 remains
in progress pending physical Pencil and owner UX acceptance. Artifacts are under
`build/sp013/ux-refinement/`:

- **33 distinct Notes checks passed**: 22 model/repository checks and 11 UI journeys,
  across `tests2.xcresult`, `refined-ui.xcresult`, `final-preview.xcresult` and `final.xcresult`.
  The final run passed all 25 selected checks (22 model plus three affected UI journeys).
- The initial UI run failed the gallery and rename-field lookup. Evidence showed the
  root-anchored popover compressed to 24 points; it is now button-anchored with an intrinsic
  height. The native alert exposed its field without the SwiftUI identifier; the test now
  addresses that alert's actual text field. Both journeys passed subsequent retests.
- Live Apple webpage and YouTube video previews loaded real thumbnails, survived insertion
  Undo/Redo and relaunch. The corresponding screenshots were inspected. A missing site's
  metadata still produces a domain fallback; this does not promise every URL has an image.
- Inspected portrait/landscape screenshots show the expanded workspace, borderless
  unselected ink, dotted background, shape/sticker content and contextual palette.
- Early compilation failures came from mixed SwiftUI toolbar content; explicit toolbar
  groups resolved them. `device-release.log` confirms the final signed build succeeded;
  strict signature verification passed (`signature.log`).
- Local documentation links and `git diff --check` passed. Existing unrelated work is
  preserved. No reset, uninstall, commit, push or translation sync was performed.

Shape/tint metadata is optional in v3. Previews share existing media validation/limits,
and their cached updates do not consume an extra Undo step. The existing history byte
budget still applies after enriching cached redo data. Page geometry is unchanged.
Physical Pencil/Scribble/palm rejection, Files recovery, narrow-window/dense-content feel
and owner acceptance remain open; simulator finger input does not close those gates.


### Refinement installed on the owner's iPad

The final signed build installed over `com.personal.SophiaScriptura` on the paired iPad
A16 and launched successfully on 2026-10-01. Existing app data was retained; no uninstall
or translation sync occurred. Evidence: `build/sp013/ux-refinement/install.log` and
`launch.log`. This confirms delivery and launch, with physical acceptance still pending.


## Owner-selected ink/theme/footer correction — 2026-10-01

Scope: SP-013/M4 Notes and the explicitly requested shared shell/tab surfaces. Correct
neutral ink through Dark → Light → Dark, remove reserved footer height across tabs, and
carry the selected theme from status/navigation backgrounds into tab bodies, including
Collections. No storage schema, fixed Page geometry, new note type, translation policy,
or unrelated feature change. System status icons and navigation remain available.

Implementation: `AppTheme` supplies one palette to SwiftUI and native Notes. The dock
overlays the full-height viewport; list content has scroll clearance while open Notes
extends through the bottom safe area. Body text, paper, rules, inline tables and object
content use theme roles. Canonical neutral black is handed to PencilKit, which handles
dark appearance itself; cached drawing images render within explicit appearance traits.
Opening/changing appearance retains original stored drawings and object geometry.

Investigation and checks:
- `build/sp013/theme-edge/reproduction.xcresult` reproduced black ink pixels in both dark
  stages before the fix. Pre-resolving neutral ink to white caused PencilKit to invert
  it again. The pixel test passes with canonical neutral ink.
- `verification.xcresult` under that directory passes all 23 Notes model tests, 2 shell
  timer tests, 5 shell UI tests and the six-tab Spring Leaf color/edge test.
- The first Canvas appearance UI assertion inherited a blue pen from a previous simulator
  run; the new regression explicitly selects neutral ink through a DEBUG-only fixture.
  Page creation also needed to wait for its menu during the tab animation. These initial
  failures are retained in the verification bundle rather than described as passes.
- Existing Canvas and Page ink save/relaunch UI cases pass in `cycles.xcresult`; the
  focused appearance-cycle results and physical delivery are recorded below.

Reference: Apple's [Introducing PencilKit](https://developer.apple.com/videos/play/wwdc2019/221/)
explains native appearance support and rendering drawing thumbnails inside the requested
trait environment. Pixel tests verify the behavior used here.

Remaining acceptance: physical Pencil/Scribble/palm rejection, dense-note performance,
keyboard/rotation feel and Files recovery still require the owner's iPad walkthrough.
M4 remains in progress until owner acceptance.

### Final verification and delivery

All 35 distinct selected checks passed across `verification.xcresult` and the successful
`cycles.xcresult`: 23 Notes model, 2 shell timer, 5 shell navigation UI, 3 theme/workspace
UI, and 2 ink save/relaunch UI checks. Canvas and Page both pass Dark → Light → Dark
pixel checks and the bottom-edge viewport assertion. Exported screenshots were inspected.
Signed device build (`device.log`) and strict signature verification (`signature.log`)
passed. CoreDevice installed over the existing app and launched it normally on the paired
iPad A16 (`install.log`, `launch.log`), without test environment variables. No uninstall,
data reset or translation sync occurred. Documentation links and `git diff --check` pass.
This correction is implemented and installed for owner testing; it does not close M4's
remaining physical acceptance.


## Canvas ink memory termination and active pen — 2026-10-01

Owner report: delayed Canvas annotations followed by app exit, plus a request for a solid
active pen icon. Direct implementation is limited to the Notes rendering/input surface,
its toolbar indicator, targeted verification and documentation. No migration, note-type
change, fixed-body reflow, Scripture annotation rewrite or unrelated feature is included.

Evidence: the iPad's `JetsamEvent-2026-10-01-092243.ips` identifies SophiaScriptura as the
largest process, terminated for `highwater`, with 228,182 resident 16-KiB pages (~3.48 GiB).
The later 14:55 event does not identify Sophia as the killed high-water process. Local
reports are retained only under ignored `build/sp013/ink-stability/`; unrelated device
process details are not copied into project documentation.

The old live PKCanvasView frame covered the entire 12,000 × 12,000 Canvas. It now occupies
only the visible editor bounds as a sibling of the document scroll view, with matching
native zoom/content size/offset. This preserves document-coordinate ink while bounding
the live drawing surface. Stroke start no longer calls tool-picker/responder setup. The
pen button switches between `pencil.tip.crop.circle.fill` and its hollow variant based
on tool visibility, with accessible Active/Hidden state. Pencil remains usable when the
palette is hidden, as previously agreed.

Apple's [PKCanvasView documentation](https://developer.apple.com/documentation/pencilkit/pkcanvasview)
distinguishes drawable content size from view frame size. The implementation uses that
boundary; the termination reason is confirmed by the device report, while exact Pencil
latency still requires physical owner testing.

Initial physical test runner launch was blocked by iPadOS Developer App trust. The owner
confirmed verification and a retry was started. The initial simulator repeated-stroke
case stopped before editor creation when the five-second dock hid during test navigation;
the helper now reveals/retries navigation. Neither initial failure is recorded as a pass.


Follow-up test corrections: physical Canvas hides its live ink view between strokes, so
its UIKit accessibility node cannot serve as a bounds probe. The DEBUG finger fixture now
exposes the actual live view dimensions and stroke count through the viewport's accessible
value. Production builds expose no diagnostic value. The first measured run stayed alive
and peaked at 210,127 kB, but its fixed twenty-stroke assertion did not include XCTest's
unmeasured warm-up. The final test counts every invocation and also verifies reopening.
Stroke-start text dismissal was further narrowed to text responders, leaving PencilKit's
active responder intact. Final results are recorded below.


The extended final memory run lost its XCTest application connection at ~92 seconds.
CoreDevice subsequently still listed the Sophia process, the recording ended on an intact
Canvas, and no new Sophia/Jetsam report appeared. This is retained as a failed automation
run, not claimed as a confirmed app crash or a pass. The final persistence regression
omits metric warm-up and draws twenty strokes directly. The prior physical diagnostic
measurement remains ~210 MB peak for its particular repeated-stroke workload.


### Final ink stability verification and delivery

Twenty repeated strokes, viewport bounds, Active/Hidden pen state, and exact stroke
count after relaunch passed on the owner's physical iPad A16 in
`build/sp013/ink-stability/ipad-persistence.xcresult` (88-second run). The tests use isolated
Notes/reader stores and simulated direct finger input, not real Pencil input. The earlier
physical memory diagnostic peaked at ~210 MB; this is a bounded workload, not a guarantee
for arbitrary dense notes. Across `tests.xcresult`, `final-input.xcresult` and this physical
bundle, 29 distinct selected cases pass: 23 Notes model, 3 theme UI, 2 save/relaunch UI and
1 repeated-stroke physical case. Final input retests pass after narrowing responder dismissal.

Xcode installed the final signed build in place as part of the physical test. Strict
signature verification passed (`signature-final.log`). CoreDevice then terminated the
isolated test launch and launched `com.personal.SophiaScriptura` normally without test
variables (`normal-launch.log`), returning to owner storage. No uninstall, reset, migration
or translation sync occurred. Documentation local links and `git diff --check` pass.

Status: correction implemented, physically regression-tested and installed. Real Pencil
latency/palm rejection, dense content and owner acceptance remain open; M4 stays in progress.

### Page crash correction — 2026-10-01

Owner reported that opening Page exited the app after the bounded Canvas ink change. The
paired iPad crash report `SophiaScriptura-2026-10-01-164621.ips` identifies a main-thread
stack overflow from recursive `updateInkViewport()` → `setContentOffset` →
`scrollViewDidScroll(_:)`. `PKCanvasView` also inherits `UIScrollView`; synchronizing its
offset was entering the controller's document delegate. The controller now ignores scroll
and zoom callbacks unless they came from the document viewport itself.

Focused physical iPad tests passed in `build/sp013/page-crash/ipad-page.xcresult`:
Page Dark → Light → Dark ink and Page ink save/reopen. The last build had been installed;
the corrected build passed strict signature verification, was installed in place, and
launched normally (`device.log`, `signature.log`, `install.log`, `launch.log`). No schema,
migration, note content, or translation data changed. This reopens the reported Page and
is ready for owner testing; M4 remains in progress pending broader physical acceptance.

### M4 closure — Scripture-to-note routing and quieter reader — 2026-10-01

The owner confirmed the corrected M4 build is working and authorized closure. This final
slice removes transient annotation status text and the duplicate bottom reader location.
The tab dock now hides after three seconds of inactivity.

Scripture selection and the Verse hub share one saved-quote path. If a Notes document is
already open, the authorized quote is inserted directly into it. Otherwise the destination
sheet offers New Page, New Canvas and each non-deleted existing note. A Page receives its
source text and inline citation; a Canvas receives a quote object. The existing Scripture
pane inside Notes continues to insert directly into its active note.

Focused physical Notes and shell tests passed: 27 tests in
`build/sp013/m4-final/notes-shell.xcresult`, including the explicit existing-note quote
regression and the three-second shell default, plus the passing three-second hide/manual
reveal UI regression in `shell-idle-r4.xcresult`. An earlier combined reader/shell UI
invocation did not create a readable result bundle after its build phase, so it is not
counted as a pass. The final signed build passed strict verification, installed in place
and launched normally (`final-device-build.log`, `final-signature.log`, `final-install.log`,
`final-launch.log`). This closes M4/SP-013. M3's independent
actual-reader annotation and Files-recovery acceptance remains out of scope and open.

### Post-closure correction — append Scripture quotes and normalize library cards — 2026-10-01

After owner testing, saving a passage to a reopened Page was found to use the reset body
selection at offset zero. Page quotation insertion now always appends to the end of the
body; Canvas keeps appending its quote object after existing objects. Notes-library cards
now have a consistent 220-point height for both Page and Canvas documents. Focused iPad
Notes regression evidence: `build/sp013/post-close-fixes/notes-r2.xcresult` (25 passed).
