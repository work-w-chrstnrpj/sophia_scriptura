# SP-014 — Pencil shape refinement and app icon

- Type: implementation. Status: done; owner verified on physical iPad 2026-10-04.
- Milestones: cross-cutting M3 Scripture annotations and M4 Study Notes refinement before M5.
- Requirements: REQ-006, REQ-008, REQ-016, REQ-021.
- Owner: Frontend UI/UX Developer.
- Selected by owner: 2026-10-01.

## Visible outcome

- Holding Apple Pencil at the end of one new line-like or supported shape stroke for
  about half a second refines it without changing PencilKit storage.
- Supported refinement: line, single-stroke arrow, circle/ellipse, rectangle/square,
  triangle, diamond, pentagon, hexagon and five-point star.
- Ambiguous, short, highly curved and unsupported shapes remain unchanged.
- Notes exposes PencilKit's native ruler in its bounded native palette. Scripture
  annotations retain the native picker, including its ruler.
- The supplied Sophia Scriptura artwork is compiled as the default, dark and tinted
  iPad app icon appearances.

## Exclusions

- M5 Collections and Save-flow work.
- Apple's private Notes recognizer or claims of parity with every Apple Notes shape.
- Hearts, clouds, speech bubbles, freeform curves and multi-stroke shape recognition.
- A new drawing or persistence schema; refined output remains an ordinary `PKDrawing`.
- Redesigning the owner-supplied icon artwork.

## Ownership and implementation

- `Features/Drawing/PencilStrokeRefinement.swift` owns the Pencil-only endpoint hold,
  conservative geometry classification and replacement-stroke construction.
- Notes and Scripture controllers own their viewport integration, undo transaction and
  existing save flow. The shared component performs no file or repository access.
- `Assets.xcassets/AppIcon.appiconset` owns the three public iOS appearance roles. The
  source exports are 167×167; 1024 catalog inputs are derived from them for compilation.

## Acceptance

- A held supported stroke refines only the last completed stroke and retains ink style.
- A normal stroke without the deliberate hold is never sent through refinement.
- Undo restores the exact rough drawing; Redo restores the refined result.
- Shapes remain in the correct document coordinates at Notes zoom and annotation zoom.
- Native ruler remains available without removing ink, eraser or Canvas lasso.
- The compiled app uses the supplied icon in default, dark and tinted appearances.
- Physical Pencil drawing, palm rejection and Home Screen appearance are checked on iPad.

## Verification evidence

2026-10-01: `build/sp014-shapes-r3.xcresult` passed six focused tests on iPad (A16)
Simulator / iOS 26.5. Coverage includes line geometry/style, last-stroke-only replacement,
ellipse, rectangle, arrow, triangle, diamond, hexagon, star, and rejection of short or
clearly curved input. The simulator test build compiled and linked the app and its asset
catalog, emitting the expected `AppIcon76x76@2x~ipad.png` output.

2026-10-01: `build/sp014-regression.xcresult` passed **48 tests, 0 failed, 0 skipped**
on the same iPad (A16) Simulator / iOS 26.5 (`523DDB8A-9EF6-44ED-A4F8-F8059ECB7725`).
The selection was `PencilStrokeRefinementTests`, `NotesTests`, and `AnnotationTests`.

2026-10-01: `build/sp014-ui-r7.xcresult` passed **9 tests, 0 failed, 0 skipped** on that
simulator. It covers shape geometry, an endpoint pause distinct from a moving stroke,
the Notes ruler in the Pencil palette, and the installed app icon on the Home Screen.
XCUITest can draw, but a paused drag does not leave the stationary Pencil samples that
a hardware pause does, so snap, Undo/Redo of the snap, and palm rejection stay physical.

The unsigned generic iOS build compiled the new drawing and icon sources but Xcode 27
twice reported unrelated existing Swift compile commands as failed despite compiler exit
code 0. The successful simulator app/test build is current compilation evidence; this
anomalous generic build is not recorded as passed.

Physical Pencil hold behavior, ruler interaction, Undo/Redo and installed default/dark/
tinted icon appearances remain Not Run. Keep this ticket in progress until those checks
are observed on the owner's iPad.
