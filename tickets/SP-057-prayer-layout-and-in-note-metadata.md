# SP-057 — Prayer layout and in-note metadata

- Milestone: owner-selected Notes refinement / v1.6.1, 2026-10-30.
- Status: implemented; simulator verified; signed iPad install/launch verified; owner-authorized release prepared; physical owner/Pencil acceptance open.
- Intent: [TDD](../docs/tdd/tdd.md), [Notes contract](../docs/data/notes-contract.md), [compatibility](../docs/guidelines/backward-compatibility.md).
- Affected modules: Notes Prayer presentation, shared page viewport/typography, shared metadata editor, Notes and Collections entry routes.

## Scope and acceptance

1. Compact Prayer balances top/left/right text padding against the actual available board width in portrait and landscape. Every line fits horizontally; long text and handwriting remain vertically reachable.
2. Maximized Prayer displays gray **dashed**, not dotted, boundaries around the writing column. These identify the annotation region visible in the compact board; long content scrolls. Guides are presentation only and cannot intercept Pencil or finger input.
3. Every note editor's More menu opens the existing metadata sheet: Edit Note for Page, Edit Canvas, Edit Journal, Edit Prayer. The same action works when opened from Notes or Collections. Save retains title/tags/paper/color; Cancel discards sheet edits. Color remains the library/card accent, consistent with the existing editor.
4. Preserve all saved text and original Pencil coordinates/bytes through preview, maximize/minimize, rotation, save and reopen. No migration, data transformation, store reset, new backend, or unrelated Plan work.
5. After verification, publish the owner-authorized patch v1.6.1/build 31 and install in place on the personal iPad. Physical interaction acceptance is distinct from simulator checks.

## Diagnosis and implementation

The old Prayer preview derived its board height from UIScreen instead of its container and shifted the column flush against the left edge while retaining its full-page top offset. PrayerPageLayout shares a canonical writing region between the compact viewport and maximized guide. The compact fit preserves canonical text/ink coordinates and reads actual saved drawing bounds for vertical reach. GeometryReader responds to width/rotation changes. The guide is a noninteractive CAShapeLayer with gray 8/6 dashes.

The library already had a guarded NoteEditorSheet with color selection, but editor menus did not present it. NoteEditorView now flushes the writing surface and presents that same sheet for every kind and both navigation routes. Contextual labels also apply to the library and sheet title. No persistence format changes occur.

## Verification and gaps

Native layout checks initially passed 3/3: balanced native text bounds at four widths, last-line scrolling, guide/preview mapping, and ink-byte save/reopen retention. Initial two UI journeys passed for synthetic prayer text and ink. Extended dark-theme/orientation and metadata navigation checks passed 3/3 in `build/sp057/expanded-ui.xcresult`. The versioned full unit suite passed 502/502. A broadened Page regression exposed an obsolete selector: the card preview is a separate overlay, not a child of the open button. Its test now opens by the saved title and exercises the new Edit Note action; the focused rerun passed 1/1 in `build/sp057/page-retry.xcresult`. App source did not change for this test correction. Synthetic content is used throughout; the owner's attached prayer is not copied into fixtures or logs. Final release evidence follows below.

### Final candidate — 2026-10-31

**502 unit tests and six UI journeys passed** across `build/sp057/final.xcresult` and the corrected Page-only rerun `page-retry.xcresult`. The combined run had 507/508 passes and one obsolete card-selector failure; after fixing that test lookup, its focused rerun passed with no remaining failed check. All runs had zero skips. No app-source change followed the versioned full suite. UI covers every note kind's contextual Edit label/color, Collections save/reopen, Page metadata/body relaunch, existing Canvas/Journal controls, Prayer text/rotation/relaunch and ink survival. Native geometry tests also cover long-text bottom reach and unchanged saved ink bytes.

Dark-mode screenshots for compact/maximized Prayer in both orientations were visually reviewed (`build/sp057/final-attachments/manifest.json`): balanced compact padding, complete horizontal lines and visible gray dashes. XCUIScreen captures avoid the app-only screenshot crop/EXIF artifact from an earlier run. Signed Debug build, strict signature/identity checks, in-place iPad install and normal launch passed. The device query confirms 1.6.1/build 31 (`device-install.log`, `device-launch.log`, `device-apps.json`). Local Markdown links and whitespace validation passed.

No personal prayer content, export, signed binary or unrelated local assets are committed. Physical Pencil/owner acceptance remains open; device UI-runner provisioning remains the previously recorded limitation. Source release is owner-authorized through the normal development → main workflow.
