# Notes Canvas Comparison — Review 01

Date: 2026-09-14. Status: expandable canvas selected; interaction details pending. Work item:
[SP-004](../../tickets/SP-004-freeform-notes.md). Requirements: REQ-008, REQ-009,
REQ-016, REQ-017. This review compares design behavior; it does not select an editor
architecture or demonstrate native PencilKit performance.

## Comparison delivered

An interactive concept named `sophia-notes-comparison` is presented in the design
conversation. The editable fragment is held in that conversation's visualization
storage, outside the application source. No app files were changed for this mockup.

Both alternatives start with the same sample note, “Love that gives”: John 3:16 in WEB,
two typed observations, a sample landscape image object, blue handwriting around the
first observation, and a connecting arrow. The quotation follows the public-domain
[WEB publisher text](https://ebible.org/details.php?id=eng-web). The observations are
illustrative study content, not retrieved commentary. The landscape is a decorative
illustration, not a historical photograph or evidence source.

## Review walkthrough

| Action | Expandable canvas | Fixed pages | Decision it helps reveal |
| --- | --- | --- | --- |
| Extend study | A third reflection continues below on the same surface | The same reflection starts on a second paper page | Continuous space versus deliberate page boundaries |
| Switch A/B | Content remains the same | Content remains the same | Compare behavior without changing visual style or content |
| Move observation | Text shifts while independent ink stays in place | Same behavior | Whether text and overlaid ink should move independently |
| Move text and its ink together | Grouped sample moves together | Same behavior | Explicit grouping is a separate decision from page type |
| Undo | Reverses the last sample edit | Same behavior | An expected editing affordance, not a proven persistence implementation |
| Overview | Navigate by named content regions | Navigate by numbered pages | How to return to material as notes grow |
| PDF preview | Compare pagination with fitting a canvas to a page | Paper boundaries map to export pages | Which export behavior is expected |

The host design controls also compare dotted, ruled, and plain backgrounds. These are
visual alternatives, not additional editor modes or committed product settings.

## Decision and open choices

The owner selected expandable canvas after the comparison: “I think I like the
Expandable Canvas.” This confirms the Notes page model and updates REQ-008 and TDD §4.
Fixed-page editing is not planned for the initial Notes implementation. The comparison
above remains a record of the alternatives considered.

In the subsequent interaction review, the owner accepted explicit grouping: text and
handwriting remain independent until deliberately grouped. Growth limits, detailed
navigation, backgrounds, and paper/PDF export remain open. An expandable canvas does
not imply unlimited memory or a particular PDF layout.

## Limits and next verification

- Buttons simulate bounded example edits; this is not a freeform editor. Arbitrary drag,
  text editing, real ink capture, pinch/zoom, and canvas growth are not implemented.
- Overview is a navigation concept. It does not prove viewport virtualization or spatial
  indexing for large documents.
- PDF preview is a simplified layout sketch, with abbreviated content. It neither
  generates a PDF nor proves exact preservation of geometry, fonts, images, or ink.
- No persistent save, reload, export/restore, native undo integration, keyboard handling,
  iPad rotation, side-panel reflow, or device performance has been tested here.
- The concept uses responsive layout and labeled controls; VoiceOver and physical-device
  accessibility still require testing. HTML resize behavior is not evidence about iPadOS.

With expandable canvas selected, refine object/grouping rules and the state model,
then prepare the bounded native experiment described by SP-004. That experiment must
demonstrate placement, movement, zoom, save/reopen, and preservation of geometry on the
actual iPad A16 before committing to persistence architecture.
