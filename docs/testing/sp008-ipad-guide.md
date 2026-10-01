# SP-008 physical iPad validation

Ticket: [SP-008](../../tickets/SP-008-scripture-layout-validation.md). First M3 validation,
selected 2026-09-29. Use disposable handwriting only. VoiceOver is waived for this gate.

## Setup

Install the signed Debug build over the existing app, preserving the app's data. Open
**Settings → Experiments → SP-008 Pencil validation**. The experiment uses bundled WEB
John 3 and an isolated `Application Support/SP008-disposable/ink.json` file. Save is
manual. It does not sync translations. Record actual iPadOS and Pencil model below.

## Walkthrough

1. Choose **Draw**, **Study 1**. Confirm the native Pencil palette. Underline a specific
   word near the start and write “A” beside it in the ruled margin. Scroll down with a
   finger, underline another word and write “B”. Keep the Pencil/palm resting normally.
2. Pinch zoom, pan, rotate both ways, and enable **Narrow viewport**. Check both marks
   against their original words. No text rewrap, drifting ink, palm marks or frozen controls.
3. Toggle **Margin rules**. The rules disappear but the margin width and handwriting stay.
   This tests rules only, not the production hide-margin-ink control.
4. Choose **Visible**, then **Hidden**. Only Hidden removes ink. Long-press Scripture to
   select text in either read mode. Choose Draw again; Pencil draws and fingers navigate.
5. Switch to **Study 2** and draw “2”. Switch back: Study 1 must contain only A/B. During
   an ongoing Pencil stroke, attempt a mode/layer change with the other hand; transitions
   should remain disabled until the stroke ends. No stroke may move into the other layer.
6. In Draw, add a stroke; Undo then Redo. Try the eraser and native lasso. Change layers
   and press Undo: it must not alter the previous layer. This experiment clears history
   when changing layers or reopening; cross-layer history retention is not promised.
7. Press **Save**, leave the experiment, open it again and press **Reopen**. Both layers
   must return aligned; it reopens in Visible, not Draw. Repeat after terminating/relaunching
   Sophia. Return to both marked words to check alignment.
8. Enable **Larger reading view**. Ink is absent; text reflows at a larger size. Disable it:
   original text/ink geometry returns. Enable **Unavailable background**: text and ink
   overlay are suppressed with an explicit message. Disable it: original drawing returns.
   Real signature mismatch is tested automatically and cannot be cleared by this toggle.

Report any failure with the step, what happened and whether it repeats. An overall
“works” does not count as separate evidence for an unattempted case.

## Evidence

- Physical device: paired iPad A16 detected 2026-09-29; actual test OS/Pencil model pending.
- Automated result: 5/5 passed, iPad A16 Simulator / iOS 26.5,
  `build/sp008/unit-r2.xcresult`; includes UIKit viewport resize/zoom geometry and storage.
- Signed Debug build/install: passed; `build/sp008/device-build.log` and `device-install.log`.
- Physical app launch: succeeded, `build/sp008/device-launch.log`; Pencil observations now owner-reported successful.
- Documentation: relative Markdown paths and `git diff --check` passed.
- Physical LAYOUT-04: Pass — owner report for all validation criteria, 2026-09-29.
- Physical LAYOUT-05: Pass — owner report for all validation criteria, 2026-09-29.
- Physical LAYOUT-06: Pass — owner report for all validation criteria, 2026-09-29.
- Physical LAYOUT-07: Pass — owner report for all validation criteria, 2026-09-29.
- Physical LAYOUT-08 simulation: Pass — owner report, 2026-09-29; actual provider revocation is outside this harness.
- Physical LAYOUT-09 larger reading view: Pass — owner report, 2026-09-29. VoiceOver: waived, not passed.
- Production gate: physical validation accepted; production ink/recovery contract remains to be defined.

Owner report: “All criteria for validation is successful.” Exact test OS and Pencil model
were not supplied. This closes bounded SP-008; production annotation durability remains
a separate implementation requirement.
