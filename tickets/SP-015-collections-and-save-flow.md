# SP-015 — Collections, bookmarks and gleanings

- Type: implementation. Status: done; owner accepted 2026-10-02.
- Milestone: M5 Collections and full Save flow (first slice).
- Owner: Frontend UI/UX Developer with Backend & Database Engineer for persistence.
- Selected by owner: 2026-10-01.

## Visible outcome

- Collections are folders with nested subfolders, a name, an optional description, a
  personalized filled-symbol icon (folder by default), and
  one of twelve muted colors (red, rose, orange, ochre, yellow, yellow-green, green,
  teal, blue, bluish purple, purple and brown) that lighten for dark appearances.
- **No Folder** is always first. It shows every note, bookmark, gleaning and link that has no
  collection, accepts only a color change, and cannot be deleted. Deleting a collection
  moves its subfolders up one level and returns items that have no other collection to
  No Folder; nothing is deleted.
- Selecting text or using the verse hub offers **Bookmark** and **Gleaning**. Both open a
  centered save sheet before anything is stored. The sheet previews the passage, lets the
  owner choose existing collections or create a new one inline, and keeps an unselected
  item in No Folder. Gleanings also take an insight.
- Partially selected verses keep ellipses instead of expanding to the whole verse, e.g.
  `2...sample verse etc. 3 And it was continue...`. Multiple verses are supported.
- A bookmark card is titled `Book Chapter:Verse (Translation)`. Opening it presents a
  centered card with the passage and **See the whole chapter**, which opens the chapter
  with the saved excerpt highlighted.
- A gleaning card adds a read-only insight with **Edit**, which becomes **Save**, plus
  **Clear**. Clearing outside editing asks for confirmation.
- Items in a collection can be moved to another collection, added to additional
  collections, removed from the current collection, or (bookmarks/gleanings) deleted.
- Bookmark (`bookmark.fill`) and gleaning (`laurel.leading`) glyphs take the folder color.
- The M4 "Save to note" workflow is unchanged.
- From the Notes library, **Add to Collection…** checks the collections that hold that note.
  Clearing every check returns it to No Folder and does not delete the note.
- Add Study Material can also save an http or https link, and can file **Sample conversation**,
  a placeholder until Companion exists. Opening the link asks before leaving the app.
  Opening the sample explains that it is not a real chat and can show the Companion tab.
- Verse Hub bookmark and gleaning rows show their direct folder names, or no folder label
  when unfiled. Gleaning insight text no longer occupies that placement line.
- Verse Hub can add an http/https link anchored to the current verse and edition. It starts
  in No Folder, can be filed later, and remains compatible with older unanchored links.
- Verse Hub exposes licensed-content-aware Copy and Share actions; Copy presents a brief
  success message.
- The Collections and Notes library roots use the same minimal header hierarchy: the tab
  name in the active appearance preset's heading font on the left, then symbol-only Search,
  sort/filter, optional More, and Add controls on the right. Search expands into a compact
  focused field only after the owner taps its symbol.

## Exclusions

- Real Companion conversations as collection items (M6); SP-015 keeps only the explicit
  sample-conversation placeholder used to prove the collection flow.
- Drag and drop, multi-select batch moves and collection reordering.
- Cloud sync or export of collections.

## Ownership and implementation

- `Features/Collections/CollectionModels.swift`: Codable folders, memberships, saved
  passages, accents and outline entries.
- `Features/Collections/CollectionsStore.swift`: validated folder, membership, move,
  assign, passage and insight commands with serialized saves.
- `Infrastructure/Collections/CollectionsFileRepository.swift`: checksummed generations
  with `current`/`previous` pointers and damaged-file preservation in `Collections-v1`.
- `Features/Collections/CollectionStyle.swift`: dynamic accents, glyphs, contrast-safe
  button styles and the color grid.
- `CollectionDestinationPicker.swift` (folder chooser, Move, Add to Collections),
  `PassageSaveSheet.swift`, `PassageCardSheet.swift`, plus the redesigned library, card,
  detail, row, editor and picker views.
- `Core/Scripture/ChapterTextMap.swift` builds ellipsis excerpts and highlight spans;
  `ReaderSession`/`ReaderTextSurface` hold the highlight after See the whole chapter.

## Acceptance

- Saving asks for collections, supports creating one inline, and Cancel stores nothing.
- Move and Add to Collections never leave an item without a home; No Folder is never a
  destination.
- Cards present centered on iPad; prominent buttons keep paper text on the accent fill
  in light and dark appearances.
- Counts read "N items · N subfolders" and align with the collection description.
- Collections, memberships, passages and colors survive relaunch.
- Notes and Collections show one leading preset-font tab name, an expandable search icon,
  and minimal symbol-only secondary and create controls with 44-point targets.

## Verification evidence

2026-10-01, iPad (A16) Simulator / iOS 26.5 (`523DDB8A-9EF6-44ED-A4F8-F8059ECB7725`):

- `build/sp015-final.xcresult`: all **108** unit tests passed, including 12
  `CollectionsStoreTests` (move/assign, outline, edit, No Folder and persistence) and the
  ellipsis excerpt test. All four `CollectionsUITests` passed: folder color, nesting and
  deletion; filing a note; saving a bookmark to a new collection, moving it and opening a
  centered card; and gleaning Edit/Save/Clear. All four `AnnotationUITests` passed.
- Shell tests that relied on the removed SP-007 demo folders now create their own
  collection; both pass in isolated reruns.
- Known failures that are not from this ticket: `testAppearancePresetPersistsAcrossRelaunch`
  also fails on the unmodified `HEAD` worktree (Settings content stays off-screen at
  x=840). `testSettingsFinalExperimentRowIsFullyAboveDockInBothOrientations` fails the same
  way. `testDarkPresetAndLandscapeDockFit` failed once and passed on rerun.
- Signed Debug build installed and launched on "iPad ni Paj" (iPadOS 27.0); data preserved.

Remaining: owner review on the iPad in light and dark appearances.

2026-10-02 Verse Hub and collection-icon follow-up:

- `build/verse-hub-regression.xcresult`: **27 passed, 0 failed, 0 skipped** on the
  iPad (A16) Simulator / iOS 26.5. The selection covers all collection persistence,
  folder membership and reader regressions, including personalized-icon round trips and
  verse-linked No Folder links.
- The final signed Debug device build succeeded, passed strict code-sign validation and
  installed in place on "iPad ni Paj" without changing its existing data-container identity.
  Evidence is in `build/verse-hub-device-final-build.log`,
  `build/verse-hub-device-final-signature.log`, and
  `build/verse-hub-device-final-install.log`. Automated launch was denied because the iPad
  was locked (`build/verse-hub-device-final-launch.log`), so owner launch and visual review
  of the new Verse Hub actions and icon picker remain pending.

2026-10-02 earlier library UI refinement (superseded by the minimal-header revision below):

- `build/sp015-library-toolbar-r3.xcresult`: the focused command-bar geometry test passed
  on iPad (A16) Simulator / iOS 26.5. Captured Notes and Collections screens were reviewed:
  both are title-free, search leads, secondary controls share one baseline, and the filled
  create action anchors the trailing edge.
- `build/sp015-library-toolbar-regression-r2.xcresult`: **5 passed, 0 failed, 0 skipped**.
  The selection covers both library layouts, note create/open/relaunch, backup access,
  collection create/delete, and preserved collection navigation across tab changes.
- A signed Debug device build passed strict code-sign validation, installed in place on
  "iPad ni Paj", and launched normally. Evidence is under
  `build/sp015/library-toolbar-device/`. No uninstall, data reset, persistence change, or
  behavior change was performed.

Remaining: owner visual review of the installed responsive command bars in portrait,
landscape, light and dark appearances.

Owner revision: replace the earlier wide command bar with an Apple-style minimal header.
The current implementation uses a preset-font tab name on the left and symbol-only controls
on the right; Search expands inline only when invoked.

- `build/sp015-library-header-r3.xcresult`: the focused minimal-header test passed on iPad
  (A16) Simulator / iOS 26.5. Its collapsed and expanded Notes and Collections screenshots
  were reviewed for leading title placement, shared control alignment, search transition,
  and the absence of a duplicate navigation title.
- `build/sp015-library-header-regression-r1.xcresult`: **5 passed, 0 failed, 0 skipped**,
  covering the revised header plus note creation/relaunch, Notes backup access, collection
  creation/deletion, and collection navigation retained across tab changes.
- A signed Debug build passed strict code-sign validation, installed in place on "iPad ni
  Paj", and launched as `com.personal.SophiaScriptura`. Evidence remains under
  `build/sp015/library-toolbar-device/`; the existing application data container was
  preserved and no behavior or persistence contract changed.

Owner accepted M5 on the installed iPad on 2026-10-02. Larger Dynamic Type and VoiceOver
remain verification gaps; they are not recorded as passed.

## 2026-10-02 owner-requested UI fixes

- Collection detail titles now open the existing editor when tapped.
- Long-pressing a collection card or nested subfolder exposes Edit Collection and Delete
  Collection; No Folder retains its color-only restriction.
- The existing safe delete behavior is unchanged: children are promoted and study material
  is preserved.
- The targeted Notes and Collections unit selection passed 38/38 in
  `build/ui-bugfix-unit.xcresult`. Two attempts at a new focused context-menu UI automation
  were killed by the simulator test runner while it failed to collect diagnostics; neither
  produced an assertion failure, and the unstable added test was not retained.
- The signed build passed strict signature verification, installed in place on `iPad ni
  Paj`, and launched as `com.personal.SophiaScriptura`; evidence is in
  `build/ui-bugfix-device/`. Owner touch/visual confirmation remains open.
