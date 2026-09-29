# SP-006 — iPad walkthrough

Status: experiment closed with owner-approved revised acceptance. Evidence below is
retained; unperformed accessibility and detailed gesture cases are deferred to SP-004/005,
not passes. This walkthrough is no longer an active demand for further owner testing.

Linked acceptance: [SP-006](../../tickets/SP-006-native-canvas-experiment.md).

## Open the experiment

Follow the [deployment guide](../deployment/deployment.md), then open **Notes → Open
canvas experiment**. The other tabs are scaffolds. Wait for the local-save status.

## Record these observations

| Check | Action and expected result | Actual result |
| --- | --- | --- |
| Independent objects | In Select, move text with the arrows or drag it away from the ellipse. Ink stays put. Undo once restores text. | Pass on retry — owner report, 2026-09-17. Initial Draw → Select transition froze the app; restart allowed the check to succeed. See hang fix and retest below. |
| Explicit grouping | Select Text and Ink using the object buttons; Group; move. Both travel together. Ungroup changes neither position. | Automated simulator pass, 2026-09-17: dedicated grouping/ungrouping UI test at 50% zoom, including text-only movement afterward, unchanged image and preserved text/stroke count. Physical repetition not executed. |
| Text editing | Edit text, change its length, Done. Ink keeps its coordinates; Cancel discards the draft. | Automated simulator pass, 2026-09-17: Done, Cancel, unchanged geometry/stroke count, retained grouping and saved text after reopen. Physical repetition not executed. |
| Pencil input | Draw mode, Finger drawing off. Write short words with Pencil while resting your palm. Record missed strokes, stray marks, lag, and exact Pencil model. | Pass — owner report, 2026-09-17: no lag, missing strokes, palm marks or unexpected freezing during the guided check. Pencil reported Type-C, non-Pro; exact model unconfirmed. Qualitative small-sample result. |
| Input modes | With Finger drawing off, a finger pans. Enable it: one finger draws, two pan. Select allows object dragging; Pan navigates without editing. | Owner pass, 2026-09-17: Pencil-only one-finger pan, finger drawing/two-finger pan, and Pan navigation. Select direct-drag substep remains unverified; prior arrow movement does not establish drag behavior. |
| Undo/redo | Add a stroke, lift Pencil, Undo once, then Redo. Repeat with group movement. Each gesture is one edit. | Pass — owner reports Undo/Redo works, 2026-09-17. Exact stroke/group transaction sequence not separately described. |
| Viewport | Test at 50%, 100%, 200%; pan, rotate, resize the app window, Return. Check relative positions and selection alignment. Cancel a drag and confirm no committed move. | Owner reports objects stay aligned, 2026-09-17. Exact zoom levels, resize and canceled-drag substeps were not individually confirmed. |
| Relaunch | Sample → Save and reopen; then close and relaunch the app. Text, image, strokes, positions, groups remain. Undo history resets on reopening. | Owner reports work is preserved, 2026-09-17; existing automated fixture and relaunch coverage supplements this. Exact physical relaunch sequence not described. |
| Recovery | Sample → Check damaged restore. Status must report rejection and saved sample unchanged. | Automated pass: retained 15-test hang-fix suite includes corrupt-restore byte preservation and UI rejection/status checks. Physical repetition not required for this bounded check; not full backup recovery. |
| Accessibility | Navigate the labeled object/move/zoom controls with VoiceOver. Try larger system text; record clipping or inaccessible actions. | Deferred, not run — owner-approved experiment closure; SP-004 must transfer to the production editor ticket. |
| Memory | In Xcode's Debug navigator, record memory before and after a few minutes of strokes, undo, zoom and rotation. Record crashes/warnings and approximate stroke count. | Completed with DEBUG-only physical-device probe on iPadOS 27.0: 60 added synthetic strokes, movement/Undo/Redo/zoom; 37.58 MiB baseline, 51.72 MiB sampled peak, 40.02 MiB final idle; zero memory warnings and all saves successful. About 115 seconds; no physical rotation in this run. See ticket for method and limits. |

Report failures with the action, expected/actual behavior, orientation, zoom, and whether
reopening changes it. A small fixture does not establish production capacity. Do not
uninstall the app to test relaunch: uninstalling removes its local sample.

## Known experiment boundaries

Only three seeded objects exist. All strokes belong to one movable ink object; its
writing area is 1,100 × 800 points even though the surrounding canvas can expand. Text
editing uses a sheet and is limited to 500 characters. No actual Scripture or private
study notes are loaded. This is a feasibility experiment, not the final visual design.

## Draw-to-Select hang and retest (2026-09-17)

Owner clarified that Draw → Select froze the interface rather than immediately
closing the app. Restart allowed the independent-object check to pass. The connected
iPad report was retrieved to ignored `build/sp006-verification/select-crash-20260917.ips`.
It shows a SwiftUI AttributeGraph cycle through first-responder changes while
`applySession()` disables PencilKit interaction during a representable update; iPadOS
subsequently recorded a watchdog termination.

A fix defers/coalesces representable-driven canvas updates onto the next main-queue
turn. Automated verification passed (15 tests), and the installed-build physical Pencil
retest passed as recorded below. Keep SP-006 in progress for the remaining cases.

Owner retest on the corrected installed build: **Pass** (2026-09-17). Repeated
Pencil Draw → Select three times; Select remained responsive, movement and Undo
worked, and handwriting remained intact. This verifies the reported transition
scenario, not all input-mode, undo or persistence acceptance cases.

## Guided physical Pencil and palm check

Use the current installed hang-fix build and disposable sample. Status: Pass by owner
report on 2026-09-17; no lag, missing strokes, palm marks or unexpected freezing.
Pencil reported Type-C, non-Pro; exact model unconfirmed. This is qualitative responsiveness evidence, not a
measured latency benchmark.

1. Open Notes → Open canvas experiment. Set zoom to 100%, select Draw, turn
   Finger drawing off and Eraser off. Write in a blank portion inside the blue ink
   boundary; writing outside the fixed ink object is not supported by this experiment.
2. Keep the palm lifted. Write “Grace and peace” and draw five short lines and
   three circles, first slowly and then at normal writing speed. Observe visible lag,
   broken/missing strokes or freezes.
3. Rest the palm naturally and repeat the same writing nearby. Check for unwanted
   marks under the palm, unexpected panning/zooming, missed strokes or worse lag.
4. Lift both hand and Pencil. Rest the palm first, then begin writing a short word.
   Repeat three times, noting whether the initial palm contact moves the page.
5. Report lag (none/slight/disruptive), missed/broken strokes, stray palm marks,
   unexpected movement or freezes, and Pencil model if known. Record whether an issue
   happened with palm lifted, palm resting, or palm placed before Pencil contact.

The absence of the native Pencil palette is a known scope boundary, not a failed step
in this input check. Do not infer pressure support or numerical latency from this test.
