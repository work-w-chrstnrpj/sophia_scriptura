# SP-003 — Scripture renderer and ink layout

- Type: spike plan. Status: done (decision/validation plan only). Owner: Frontend UI/UX Developer.
- Requirements: REQ-004, REQ-005, REQ-006, REQ-007, REQ-016.
- Dependencies: SP-002 baseline now available; this ticket resolves detailed layout/gesture decisions. D-02 three-state UX is approved. Optional provider-specific SDK hooks remain unverified.
- Design: [TDD §9–10](../docs/tdd/tdd.md#9-scripture-rendering-and-interaction),
  [UX specification](../docs/design/ux-specification.md).
- Affected later modules: ScriptureRenderer, AnnotationEngine, VerseAnchorHub.

## Purpose and scope

Determine how text selection, passage taps, and spatial drawing can coexist without
ink drifting when text layout changes. Prepare the experiment; native prototype code
is a later owner-requested execution step.

## Work

1. Compare custom TextKit rendering with documented YouVersion customization hooks.
2. Compare stable annotation layouts and passage-region anchoring. Explain tradeoffs
   for larger text, narrow windows, and readable accessible Scripture.
3. Honor confirmed Read Hidden / Read Visible / Draw states; specify precise Pencil/finger routing, undo, layer management and margin behavior.
4. Define layout identity and content revision handling without retaining restricted text
   snapshots after provider permission expires.

## Acceptance and verification

- Decision records cover selection across verses, chapter taps, layer switching,
  translation changes, and the extended ruled margin.
- A future iPad experiment has repeatable steps: mark a specific word, reopen, rotate,
  resize, change font, open Companion, and verify alignment or explicit preserved-layout behavior.
- Specify tests for missing/combined verses and passage overlap, not string equality alone.
- Unknown SDK hooks are labeled unverified, not assumed supported.

## Outputs and boundaries

Update TDD, UX specification, and later a decision record plus executable spike ticket.
Do not replace the existing reader scaffold as part of planning.

## Execution contract

Planning work only in the current stage. No implementation completion is implied by
this ticket. Record unresolved items explicitly. Do not create provider accounts,
accept agreements, purchase access, or obtain credentials on the owner's behalf.

## Evidence

2026-09-21 completion: owner selected SP-003. The
[rendering decision](../docs/design/scripture-rendering-decision.md) compares renderers,
specifies range mapping, geometry, state/gesture routing, layer/history scope and revision
handling. Apple/YouVersion sources checked. [SP-008](SP-008-scripture-layout-validation.md)
is drafted, not selected, with repeatable native cases. Planning acceptance satisfied;
no app code or native test executed. Paths/whitespace checked. The reader-only SP-005
contract was subsequently completed; SP-009 is now the ready next product ticket.
Before actual product implementation, explicitly notify the owner and name its outcome.
Historical entries below retain earlier status.

Historical decisions: on 2026-09-16, D-02 was approved by owner: multiple layers, at most one visible, with three
interaction states. See UX specification for the contract. This resolves the high-level
mode choice only; the remaining provider/layout questions were resolved by the decision
record above or assigned to SP-005/SP-008.

2026-09-21 readiness update: SP-002 completed its public-source research with a WEBP
USFM offline baseline. Custom Sophia rendering can be planned without accounts or
optional translation entitlements. Owner explicitly wants legitimate file/API content
mapped into Sophia's own reader. Plan that route first, comparing SDK hooks only where
relevant. That readiness entry preceded the completed planning work recorded above.
