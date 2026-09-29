# SP-008 — Scripture page selection and ink validation

- Type: bounded native validation. Status: split; annotation portion not selected.
- Milestone: M1 evidence for M3 annotations. Reader cases are assigned to SP-009.
- Requirements: REQ-004/005/006/007/016.
- Design: [SP-003 decision](../docs/design/scripture-rendering-decision.md).
- Proposed owner: Frontend UI/UX Developer.

## Scope and file ownership

SP-009 validates the chapter-level TextKit selection owner over real bundled content as
part of the product reader. This remaining ticket validates one page-local PencilKit
layer under a shared viewport. Use disposable geometry/ink fixtures; no provider accounts.
Proposed isolated folder: `Features/Scripture/LayoutValidation/`, with separate document,
layout, surface and session files; final paths must be checked before implementation.
Native tests belong in existing XCTest/XCUITest targets. Do not modify the Notes experiment.

Excludes full reader UI, ingestion, production persistence, cross-feature routing and
large-document benchmarking. Stop after these gates; do not grow a second app prototype.

## Acceptance cases

| Case | Procedure | Expected result |
| --- | --- | --- |
| LAYOUT-01 | **Assigned to SP-009.** Select part of a verse, extend across adjacent verses and beyond one viewport; Copy | Exact body substring and source range, no duplicated text or headings |
| LAYOUT-02 | **Assigned to SP-009.** Tap verse number or the labeled hub control; long-press body | Correct hub intent; selection gesture remains functional |
| LAYOUT-03 | **Assigned to SP-009.** Use missing verse, bridge 3–4, repeated text, emoji/combining marks and RTL fixture | Explicit mapping/overlap and correct UTF-16 boundaries; no guessed text |
| LAYOUT-04 | Underline one word and write in margin; save/reopen, rotate and resize | Word/ink geometry agrees with saved page transform; ink bytes unchanged by viewport changes |
| LAYOUT-05 | Change font, open Companion-sized panel, toggle margin rules | Preserved layout or explicit separate reading view; no reflow beneath ink |
| LAYOUT-06 | Switch Hidden/Visible/Draw and layers; switch during stroke | Correct input owner, no lost stroke, one visible layer, native palette in Draw |
| LAYOUT-07 | Finger pan/zoom with Pencil resting; draw then Undo/Redo; switch page | No palm strokes; undo affects active page/layer only; no frozen controls |
| LAYOUT-08 | Simulate revoked text and renderer/font mismatch | Ink/reference data retained; explicit unavailable background; no wrong-text overlay |
| LAYOUT-09 | VoiceOver reading and larger type; return to annotated layout | Semantic order and reachable actions; accessible reflow does not mutate ink |

Automate range mapping, transforms, revision mismatch and history isolation; use UI tests
for selection/menu/state transitions. Physical Pencil/palm and VoiceOver observations
require explicit evidence, with minimal owner assistance only where automation cannot
observe them. Record actual OS and retained result paths under ignored `build/`.

## Exit and fallback

Record pass/fail once per case after necessary fixes. If UITextView/TextKit 2 cannot meet
cross-page selection, document the failing boundary and recommend TextKit 1 containers
or custom selection handling before changing architecture. Do not claim a passing Notes
test proves Scripture behavior. Product renderer acceptance in SP-009 depends on
LAYOUT-01–03. This ticket's annotation delivery depends on LAYOUT-04–09. No checks
executed yet.

2026-09-22 owner revision: M2 uses continuous chapters. LAYOUT-01 now validates long
continuous selection, not an artificial page break. Page-based annotation cases 04–09
remain unselected candidates and must be reconciled with this direction before M3.
