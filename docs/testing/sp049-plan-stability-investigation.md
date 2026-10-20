# Investigation Report: Plan section deletion — 2026-10-20

## Summary

Removing a section/day could abort the app inside the Plan editor. The original
implementation was reproduced in the simulator; its crash stack confirms a Swift
exclusive-access conflict. SP-049 now uses value snapshots and stable-ID draft commands.
Earlier happy-path tests did not exercise section deletion and missed this defect.

## Symptoms

The owner reported the app quitting when removing a section/day. The original native
UI reproduction terminated Sophia immediately after selecting Remove section.

## Facts

- Original-code reproduction: `build/sp-049/section-delete-before-r3.xcresult` failed
  after reaching Remove section.
- The simulator report was `SophiaScriptura-2026-10-20-090407.ips`; a reduced summary
  is retained at `build/sp-049/section-delete-crash-summary.json`.
- Exception: EXC_CRASH / SIGABRT, with `_swift_reportExclusivityConflict`,
  `swift_beginAccess`, `PlanEditorDraft.draft.getter`, SwiftUI Binding getters and
  the section removal predicate (original PlanEditorView line 111).
- The action changed an editor draft before Save. No owner storage reset, uninstall,
  persistence migration or schema change was performed.

## Observations

The old `ForEach($model.draft.sections)` exposed a live section binding. Its removal
predicate read `section.id` through that binding while `draft.sections.removeAll`
already held mutable access to the same draft. This is an overlapping access, not
merely an out-of-range index. Retained row callbacks also needed identity checks.

## Suspected Failing Boundary

SwiftUI Plan editor bindings and local structural mutation; Collections persistence
was not on the crashing stack.

## Primary Investigator

Frontend/UI role, performed by the current agent.

## Supporting Specialists

SQA role, performed by the current agent for reproduction and regression verification.
No separate agents were required.

## Hypotheses

| Hypothesis | Supporting evidence | Contradicting or missing evidence |
| --- | --- | --- |
| Overlapping Swift array access via a section binding | Confirmed runtime exclusivity stack and matching source predicate | None in the reproduced path |
| Stale row/index after structural mutation | Mutable array binding design made this plausible | The actual abort stack identifies overlapping access; stale callbacks are covered separately |
| Corrupt persisted Plan or schema migration | Could cause other failures in principle | Reproduced with a fresh isolated test store before Save; no persistence frame in abort |

## Evidence

The before-r3 bundle is the confirmed reproduction. The earlier before and before-r2
runs failed to open the menu because their tap missed its text hit target; they are
not crash reproductions. The corrected focused bundle,
`build/sp-049/section-stability-focused.xcresult`, passes 12 draft tests and the native
only-section deletion/save/relaunch regression. Final suite and device evidence are
recorded in [SP-049](../../tickets/SP-049-plan-model-and-authoring.md).

## Most Likely Root Cause

Confirmed overlapping read/write access to the editor's draft when the removal
predicate reread its section UUID through the live array binding.

## Confidence

High for the reproduced simulator path. The owner's physical crash report was not
collected, so exact physical stack equivalence is not independently confirmed.

## Recommended Fixes

Implemented within SP-049: snapshot section/item values for rendering, resolve all
mutations by stable UUID, and make removed-row title bindings and stale reorder
callbacks safe. Picker/reset routes are cleared when their target is removed.
Replacement state is cleared on cancellation; batch replacement retains all selected
chapters. Chapter controls clamp dependent bounds before switching to a shorter book.
Menu hit targets now cover their row; assignment removal is also available in its menu.

Regression coverage includes first/middle/last/only deletion, delayed callbacks,
reorder and cross-section moves, duplication, reset, replacement, capacity/save guards,
400 mixed structural edits with save/reopen, and chapter-bound combinations. Native
UI journeys verify empty and populated section deletion plus retained note content.

## Open Questions

Physical interaction, Pencil, accessibility and sustained use remain owner acceptance
checks. Simulator coverage and installation do not establish universal app stability.

## RCA Needed?

No formal RCA is necessary for this local development defect; this investigation and
the ticket retain the reproduction, correction and verification boundaries.
