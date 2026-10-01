# SP-008 — Continuous Scripture ink geometry and gesture validation

- Type: bounded native validation. Status: done; owner reported all validation criteria successful 2026-09-29.
- Milestone: first M3 ticket, after owner-revised M2 closure.
- Requirements: REQ-004/005/006/007/016.
- Design: [SP-003 decision](../docs/design/scripture-rendering-decision.md).
- Owner: Frontend UI/UX Developer; QA records physical observations.

## Owner decision and visible outcome

The owner requested revision/selection of SP-008, then physical iPad Pencil validation,
then production annotation layers. VoiceOver is waived for this gate, not passed.
M2 visual refinements and expiry/renewal are accepted as addressed. Larger-text geometry
remains in scope independently of VoiceOver.

Settings → Experiments → SP-008 Pencil validation opens a DEBUG-only disposable harness
using bundled WEB John 3. It tests a continuous chapter, not artificial pages. TextKit 1
and PencilKit share an 800-point-wide chapter coordinate space with a 540-point text
column and reserved writing margin. These dimensions are experimental, not product design
approval. A single outer viewport pans/zooms both surfaces; resize must not rewrap text.

## Scope and file ownership

`application/SophiaScriptura/SophiaScriptura/Features/Scripture/LayoutValidation/`:

- `InkValidationView.swift`: experiment controls and separate larger-text reading view.
- `InkValidationSurface.swift`: fixed text geometry, shared viewport, Pencil-only canvas,
  palette, input ownership and per-layer history reset on transition.
- `InkValidationSession.swift`: two disposable drawings, isolated atomic save/reopen,
  mismatch handling and stroke transition guard. Saves only test ink and layout signature.

Settings adds the DEBUG entry; existing XCTest target owns `InkValidationTests.swift`.
The harness uses the read-only bundled repository; it does not access licensed providers,
reader preferences/storage, Notes fixtures or production annotation stores.

Excludes production layers, layer management/deletion, production export/restore,
cross-feature routing, chapter swipes while drawing, cross-edition ink migration and
large-chapter performance approval. Physical validation of one chapter does not establish
long-document viability. SP-005 must define durable ink/recovery contracts before real
study handwriting ships. Undo is deliberately cleared on layer change/reopen; preserving
independent undo stacks is a production decision, not claimed here.

## Acceptance cases

| Case | Procedure | Expected result |
| --- | --- | --- |
| LAYOUT-01–03 | Assigned to SP-009 | Product reader owns continuous selection, verse hit testing and UTF-16 mapping |
| LAYOUT-04 | Underline a word, write in margin; Save/Reopen; rotate, resize, zoom and pan | Text/ink remain aligned in fixed chapter coordinates; viewport actions do not rewrite strokes |
| LAYOUT-05 | Narrow viewport; toggle rules; enter larger reading view and return | Fixed margin/text geometry; separate reading view hides ink; return preserves original alignment |
| LAYOUT-06 | Hidden/Visible/Draw; switch Study 1/2; attempt transitions during a stroke | One visible layer, native palette in Draw, selection only in read modes, no lost stroke or layer leakage |
| LAYOUT-07 | Finger pan/zoom with Pencil/palm resting; draw, erase, lasso, Undo/Redo; change layer | No palm strokes; controls remain usable; history never affects another layer (reset at transition) |
| LAYOUT-08 | Toggle unavailable background; restore it; load saved ink with mismatched layout signature | No wrong-text overlay; stored ink retained; actual mismatch remains blocked; simulation makes no provider call |
| LAYOUT-09 | Larger reading view, return to annotated view | Larger text does not mutate ink; VoiceOver explicitly waived by owner |

See the [physical walkthrough and results](../docs/testing/sp008-ipad-guide.md).
Automated tests cover save/reopen, corrupt-file retention, signature mismatch and active
stroke save/reopen guard. They do not prove physical Pencil accuracy or palm rejection.

## Exit and production handoff

Record pass/fail/not-run with actual iPadOS/Pencil model and retained evidence under
ignored `build/sp008/`. Fix failures inside this ticket and repeat the affected cases.
Production annotation layers must wait for physical LAYOUT-04–09 acceptance (excluding
waived VoiceOver), an explicit geometry decision, and the SP-005 ink/recovery contract.
If the shared continuous canvas fails gestures, alignment or practical memory limits,
record the boundary and revise the candidate; do not silently restore visible pagination.
Notes experiment results cannot substitute for Scripture evidence.

Current status: harness implemented; five focused tests passed on iPad A16 Simulator /
iOS 26.5 in `build/sp008/unit-r2.xcresult`. Tests cover save/reopen, corrupt retention,
layout mismatch, active-stroke save guard, and UIKit resize/zoom geometry with ink bytes
unchanged. The first build had an ambiguous CGFloat literal; corrected before this run.
Signed device build and in-place install passed (`build/sp008/device-build.log`,
`device-install.log`). Physical iPad launch succeeded (`build/sp008/device-launch.log`).
Physical LAYOUT-04–09 are now owner-reported passed; see closure below.
No production annotation layer implemented.

## Owner physical acceptance — 2026-09-29

The owner stated: “All criteria for validation is successful.” This explicitly accepts
all physical LAYOUT-04–09 procedures in the linked walkthrough, including geometry,
mode/layer changes, gestures/history, save/reopen, unavailable-background simulation and
larger reading-view return. VoiceOver remains waived. These are owner-reported results,
not agent-instrumented physical traces. The exact test OS and Pencil model were not
provided; the paired iPad A16 was used for delivery.

SP-008 is closed as a bounded validation ticket. The shared fixed continuous-chapter
coordinate space is accepted for the next annotation design; experimental dimensions
and disposable storage do not become production contracts. Production ink/recovery
contracts remain SP-005 work. The owner next selected SP-011 tab-shell refinement before
proceeding with production annotations.
