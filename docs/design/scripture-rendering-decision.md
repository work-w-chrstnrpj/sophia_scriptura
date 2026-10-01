# Scripture rendering and ink geometry — SP-003

Decision date: 2026-09-21. Status: implementation direction selected for planning;
native pagination/gesture feasibility remains untested. This document does not authorize
implementation. Requirements: REQ-004/005/006/007/016. Content input:
[SP-002 specification](../integrations/scripture-content.md).

## Current M2 owner revision — 2026-09-22

The owner replaced visible chapter pagination with one continuously scrolling chapter.
M2 uses a single TextKit 1 UITextView, continuous selection, manual chrome collapse and
horizontal chapter swipes. No page gaps, page counter or duplicated top location title.
The previous bounded-page design below is retained as historical context and an unaccepted
M3 annotation candidate. Revisit annotation geometry before M3; do not reintroduce visible
reading pages merely to match that proposal.

## M3 validation selection — 2026-09-29

SP-008 is now selected. Test one continuous, fixed-width chapter coordinate space shared
by TextKit 1 and PencilKit in a zooming viewport, with a permanently reserved margin.
Viewport resize/rotation must not reflow annotated text. Larger-type reading uses a
separate ink-hidden view with an explicit return to the preserved layout. This is a
candidate awaiting physical evidence, not a production architecture approval. The older
page/pagination details below are historical candidates; they do not override the
continuous reader or require cross-page selection. VoiceOver is waived for this gate.

## Decision and alternatives

Use a custom native TextKit-backed reader hosted by SwiftUI. Prefer TextKit 2, a
read-only selectable UITextView for ordinary text interaction, and a separate layout
adapter for bounded pages. Do not assume that a default UITextView automatically provides
multi-page layout or cross-view selection. Those are the specific SP-008 feasibility gates.

| Approach | Benefit | Cost / decision |
| --- | --- | --- |
| Custom TextKit + UIKit surface | Own selection, typography, passage mapping and geometry | Selected; pagination and gesture integration need native evidence |
| YouVersion Swift reader | Documented version controls, navigation, attribution and selection UI | Optional provider integration; no verified contract for Sophia's page geometry, ink overlay or custom selection actions |
| SwiftUI Text per verse | Easy initial display | Independent text views do not establish continuous passage selection; not selected as the production reader |
| PDF/image pages | Stable picture coordinates | Loses a straightforward semantic reading/selection path; not the primary renderer |

Use provider APIs/files as content sources, not owners of the screen. The app can start
with bundled WEB and no SDK. Preserve a replaceable renderer boundary if a focused native
check requires TextKit 1 containers or a custom TextKit 2 selection surface; record that
decision before expanding implementation. Preserve selectable text; the owner explicitly superseded visible M2 pages.

## Responsibilities and data flow

Proposed ownership; these modules are not implemented:

```text
Content repository → immutable chapter document + source references
                                  ↓
Reader session → layout engine → page descriptors / text range map
      ↓                ↓                    ↓
SwiftUI controls   UIKit reading surface   annotation surface
      ↓                                      ↓
Passage action requests                 drawing transactions
      ↓                                      ↓
Feature routing                     annotation repository (M3)
```

- Chapter document: source edition/revision, ordered text blocks, verse labels and
  explicit canonical mappings. Store text separately from presentation and user ink.
- Layout engine: typography, reserved margin, pagination, source-offset-to-page/rect
  mapping. No storage, provider requests or Companion calls.
- Reading surface: native selection, accessibility and hit testing; emits source ranges.
- Session: reference navigation, selected layer, mode and pending transitions. It does
  not own parsing, drawing serialization or API policy.
- Annotation surface: page-local PencilKit input and viewport transform. Repositories
  own durability; SP-005 defines atomic save/error behavior before M3.

## Passage selection and page boundaries

Maintain one logical chapter text stream and a UTF-16 range map compatible with NSRange.
Rendered verse numbers, headings and footnotes are typed runs, not part of the copied
verse body by accident. Never infer references by searching repeated text strings.
Intersect selection ranges with body runs, preserving the actual partial text selected
and every intersected source verse. Store source labels, edition and mapping status with
the selection; a canonical range alone cannot reconstruct every translation.

Native drag selection must span adjacent verses. For adjacent pages within a chapter,
use one logical selection owner with visible-page range projection. Independent selectable
UITextViews per page are insufficient. SP-008 must demonstrate continuous selection
across a real page break. Explicit Select Passage via reference controls additionally
supports ranges crossing chapters; a cross-chapter drag is not promised.

Tap only verse-number hit regions or the chapter heading to open the relevant hub.
Tapping body text retains normal native selection behavior. Use labeled accessible actions
for chapter/verse controls; gestures must not intercept native long press or selection handles.
Compose Copy/Ask/Save/Share through the text view's edit-menu delegate, preserving useful
system actions. M2 exposes working Copy/Share; Ask/Save arrive with their actual destinations.
Do not put no-op controls into the product.

Missing verses stay missing. A combined label such as 3–4 maps to both canonical anchors
only if source mapping establishes that relationship; never fabricate separate verse text.
Hub queries use anchor intersection, not displayed label or quotation equality. Unknown
mappings show an explicit unavailable state in navigation and comparison.

## Bounded pages and preserved layouts

Chapter content flows through vertically stacked, bounded pages; a chapter can span many.
Paginate on line boundaries and retain paragraph/poetry metadata. Long verses may continue
onto another page with separate source ranges. Footnotes use accessible disclosure rather
than silently modifying body offsets. A page number is a display value, never an ink key.

Choose logical page dimensions, text width and reserved margin together in the layout
recipe; exact numeric dimensions are a visual/native validation result, not fixed here.
Each page has an immutable ID within a layout revision, its body ranges and geometry.
Store ink in page-local points. A shared transform positions text and ink in the viewport:
screen point = page origin + zoom × page-local point. Never update saved strokes when
scrolling, rotating or opening a panel.

Layout identity includes edition/content digest, renderer/schema version, resolved font
identity/version and metrics, type size, spacing, direction, page/text/margin dimensions,
and pagination/range manifest. Theme color and hiding margin rules do not change geometry.
A reproducible recipe alone is insufficient after OS/font changes: validate the rebuilt
layout against saved line/range geometry. If it differs, keep ink intact and show an explicit
incompatible-layout state; do not overlay it on changed text. SP-005 defines retention of
permitted source revisions and geometry. No permission-limited text may survive as hidden
screenshots, glyph caches or exports after its retention rights expire.

**Preserved spatial layout is selected over automatic passage-relative ink reflow.**
Semantic anchors remain useful for navigation, but cannot reliably reposition underlines,
arrows or writing between lines. Do not attempt automatic cross-version ink migration.

## States, margin and layout transitions

| State | Input owner | Behavior |
| --- | --- | --- |
| Read Hidden | Text surface + reader viewport | Ink absent; selection and passage taps enabled |
| Read Visible | Text surface + reader viewport | Selected ink rendered without hit interception |
| Draw | PencilKit for Pencil; viewport for finger navigation | Native palette; Scripture selection and passage taps disabled |

Hidden/Visible changes alone never repaginate. In Draw use explicit Pencil-only drawing;
finger drawing is not part of this Scripture scope. Outer viewport owns finger pan/zoom;
page canvas scrolling is disabled. Simultaneous gesture recognition, palm behavior and
PencilKit integration are SP-008 tests, not guarantees from drawingPolicy alone. Active
stroke pins its page and blocks layer/version/layout changes until committed; a failed
save keeps the old session and offers retry. Do not recycle an active canvas mid-stroke.
Native lasso edits only the active page/layer; no Notes-style mixed-object grouping.

Reserved margin is part of every spatial page recipe. Toggle rules/visibility without
changing width or moving ink. Hidden margin ink is retained and returns when shown;
there is no writable invisible region. On narrow windows, pan/zoom the same page or use
the separate reading layout. Do not detach existing margin handwriting into a sheet.
Keep palette, essential controls and bottom tabs reachable above safe areas/keyboard.

Font/accessibility changes offer two explicit paths when ink exists: keep the annotated
layout, or open an independently reflowed reading layout with ink hidden. Show a clear
“Reading layout — annotations remain in original layout” state and a return action.
Going to Read Visible/Draw returns to that saved layout and restores the nearest source
passage; it must not project old ink into the reflow. New handwriting at a new font requires
an explicitly created layout with blank layers. Preserve the old revision, without copying
strokes. Reflow is free before ink exists, and does not freeze accessible reading type.

Rotation, Companion panels, compact reader controls and comparison change the viewport,
not preserved geometry. Use a sheet if a side panel would leave unreadable columns.
Comparison scrolls by mapped passage, not equal pixel offsets; only the primary edition
owns ink. Switching editions restores its own layout/layer and defaults to Read Hidden
when none exists. Existing audio continues on mode changes; edition changes require an
explicit audio-source policy in M7, not a claim of implemented playback.

## Layer and history decisions

- Named layer IDs are chapter/edition/layout scoped, with separate drawing data per page.
  Selection remains consistent across the chapter's pages. At most one is visible.
- Create an empty layer (default name Study 1, incrementing); allow rename. Deletion
  requires confirmation and recoverable removal under SP-005 before shipping real ink.
- Selecting a layer while hidden keeps Read Hidden. Reopen restores the selected layer
  and reading location, but never automatically re-enters Draw; prior Draw opens Visible.
- Switching page/layer must not apply Undo to another target. History is keyed to layout,
  layer and page. A completed stroke/lasso operation is one undoable transaction; toolbar
  Undo targets the active page only. Navigation and visibility changes are not ink edits.
- On missing content/expired permissions retain user ink, names and references. Explain
  that the original text background is unavailable; never substitute another translation
  underneath it. Restore only after matching permitted content/layout is verified.

## Verification gate and delivery boundary

[SP-009](../../tickets/SP-009-first-offline-scripture-reader.md) now owns paginated
selection cases LAYOUT-01–03 inside the actual product reader. SP-008 retains the bounded,
unselected shared-ink geometry and gesture cases LAYOUT-04–09 before M3. This avoids a
second disposable reader while preserving clear pass/fail gates. No layout case has run.

SP-003 is complete as a decision/experiment plan. The reader-only SP-005 contract is
accepted and SP-009 is ready as the first M2 product ticket. Full Notes, AI and Activity
contracts do not block that slice.
Before executing a product ticket, explicitly notify the owner: **“We are now starting
actual product implementation,”** name the usable outcome and distinguish it from an
experiment. Do not describe this planning document as a working reader.

## Sources checked 2026-09-21

- Apple [text-view edit-menu delegate](https://developer.apple.com/documentation/uikit/uitextviewdelegate/textview(_:editmenufortextin:suggestedactions:)) supports menu customization.
- Apple [layout fragment enumeration](https://developer.apple.com/documentation/uikit/nstextlayoutmanager/enumeratetextlayoutfragments(from:options:using:)) provides geometry access; it does not prove this pagination design.
- Apple [PencilKit drawing policy](https://developer.apple.com/documentation/pencilkit/pkcanvasviewdrawingpolicy) distinguishes Pencil-only input.
- YouVersion [Swift components](https://developers.youversion.com/sdks/swift/components) documents content views/navigation; Sophia-specific page/ink/selection hooks remain unverified.

All architecture choices above are Sophia design decisions, not promises made by those APIs.

## Initial SP-009 implementation decision — superseded after owner test

The initial product renderer uses TextKit 1 in one read-only UITextView, with full-width
exclusion bands separating 900-point reading pages. This keeps native selection owned by
one chapter text storage and provides explicit line-fragment exclusion geometry. This is
a deliberate implementation choice, not evidence of a TextKit 2 failure. The domain range
map and repository remain renderer-independent. Native cross-page selection and physical
accessibility remain acceptance gates; M3 preserved ink geometry is not implemented.

## SP-008 bounded acceptance — 2026-09-29

The owner reported all validation criteria successful. The fixed continuous-chapter
coordinate-space candidate is accepted for production design. This closes the physical
experiment gate; exact dimensions, durable storage/recovery and long-chapter performance
remain production design/verification work. VoiceOver remains waived for this ticket.
