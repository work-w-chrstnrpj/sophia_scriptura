# SP-043 — Enhance lasso-selected handwriting with Sophy

Status: draft; detailed planning complete; implementation not selected.
Type: native selection + AI workflow feature. Priority: follows accepted SP-042 Canvas slice.
Created: 2026-10-13, owner requested planning.
Milestone: proposed post-v1.1.0 study automation; target release unassigned.
Owners: Frontend and Companion/Sophy integration; System Architect, Security, SQA and Documentation support.
Requirements: owner wants Pencil lasso selection with Enhance with Sophy; ticket-local ENH-AC criteria below. Dependencies: SP-042 reviewed transcription and snapshot contract, SP-029 enhancement, SP-025 ink selection, SP-026–028 protection. No MCP dependency.

## Usable outcome

Lasso handwritten ink, choose **Enhance with Sophy**, review/correct the transcription, choose an existing enhancement operation, explicitly generate, and review the result before Copy or Insert as Text. Original handwriting remains intact. The same workflow can consume SP-042 rectangle selection; no second OCR engine or duplicate selection gesture implementation.

This is a native Sophia capability. A reusable external-agent skill may later orchestrate exposed tools under SP-041; adding a Markdown skill cannot make the in-app lasso or OCR work.

## Current source evidence

Paths below are under `application/SophiaScriptura/SophiaScriptura/`.

- `Core/Sophy/SophyNoteSelection.swift` is a typed-text selection snapshot with note/object IDs, UTF-16 range, digest, revision, route and requiresConsent. It is not a saved-ink selection type.
- `Features/Sophy/SophyEnhancement.swift` stages typed selections, checks stale selection/access before request/response/apply, isolates selected text from note metadata/history, requires consent for selected protected material, validates provider output, and copies or replaces typed text.
- `Core/Sophy/SophyNoteSelection.swift` defines the existing operation set: Grammar Check, Recreate Text Tone, Organize Idea, Expound and Rate. Reuse these; do not silently add unsupported summarization or a new provider prompt contract.
- `Features/Sophy/SophyEnhancementSheet.swift` and `SophySession.swift` own the editable workflow/session state.
- `Features/Notes/NotesSession.swift` / `applySophyReplacement` applies digest/range-checked typed replacements with undo; this API must not be called with invented text ranges representing ink.
- `Core/Sophy/SophyEligibility.swift` excludes protected items from bulk retrieval, while the explicit typed-selection flow can require narrow consent. Preserve this distinction.

Read [SP-042](SP-042-selected-handwriting-to-text.md), [SP-029](SP-029-v040-sophy-lady-wisdom.md), [item protection](../docs/security/item-protection.md), [Notes contract](../docs/data/notes-contract.md), [Companion design](../docs/design/companion-screen-specification.md) and [TDD](../docs/tdd/tdd.md).

## Recommended user journey

1. In a supported ink editor, lasso or box-select handwriting. The contextual palette includes Convert to Text and **Enhance with Sophy**. These share one immutable selection snapshot; no whole-note screenshot or hidden OCR pass.
2. Enhance first performs SP-042 local recognition and opens **Review handwriting text**. The owner corrects OCR errors before AI can receive anything. No automatic request from selecting ink or opening the menu.
3. Continue to the existing enhancement review, visibly identified as **From handwriting**. Show the reviewed source text, operation and configured provider/model. Preserve explicit review even when OCR confidence is high.
4. Offer existing Grammar Check, Recreate Text Tone, Organize Idea, Expound and Rate. Default Grammar Check. Keep current tone/rating options and theological guardrails; label generated expansion as an AI suggestion, not Scripture or a quotation.
5. Owner taps Generate. Send only reviewed text and operation parameters. The selected crop, full note, title/tags, journal states, other ink, surrounding Scripture, previous chats and other enhancement results are excluded.
6. Display Original transcription and Suggested text/feedback with an editable suggestion. Non-rating output offers Copy, Insert as Text, Retry and Cancel. Rate offers feedback/scores and Copy Feedback; it never replaces or inserts a rewrite implicitly.
7. Insert uses the current, still-valid source/destination context through the owning session. Canvas creates a new text object beside the ink. Page-style destinations use SP-042's explicit insertion mapping. Ink remains. Confirm destination and keep each commit one undoable action.
8. Close leaves the owner in the same editor/folder. Collections-opened notes retain their existing route. Turning Sophy off or changing provider during the request cancels/invalidates the pending operation.

### Scope and phased availability

Initial scope is Notes Canvas after SP-042 G1. Page/Journal/Prayer may be enabled only after their SP-042 selection and insertion checkpoints pass. Scripture ink enhancement is a later checkpoint dependent on SP-042 G3 and a host-neutral source identity: initial behavior is Copy or create a Page with explicit passage context, never replacing Bible text/annotation ink.

An unavailable operation must be hidden or disabled with a clear reason: no ink selected, no recognized text, missing provider key, unsupported surface, inaccessible source or busy request. Do not advertise every surface as supported because Canvas is working. Native typed-text enhancement remains available and behavior-compatible.

## Proposed architecture and data contract

- Generalize the enhancement source as a tagged transient value: typed selection (existing), reviewed ink selection (new), or explicit pasted text (existing). Keep typed `SophyNoteSelection` semantics intact; no fake `NSRange` for ink.
- Reviewed ink source includes SP-042 immutable source identity/drawing digest/stroke references/revision/route/access generation, reviewed text and digest, OCR language and request generation. It does not persist raster bytes or raw recognition output in Companion/Sophy history.
- Shared enhancement orchestration consumes reviewed text but dispatches source validity and commit to the appropriate host coordinator. UI does not call a repository or mutate PKDrawing directly.
- Snapshot and consent bind both the selected-ink digest and corrected-text digest. Editing the reviewed text after consent resets consent and invalidates any old provider response. Editing a suggestion invalidates any already staged insertion preview and is revalidated before commit.
- Use existing `SophyResponseValidator.userInputLimit` and enhancement response schema/limits, rather than copying numeric constants into the new feature. SP-042's larger OCR result must be reduced explicitly by the owner if it exceeds the enhancement limit; no silent truncation or automatic chunking that changes meaning.
- Preserve generation/provider route checks. Changing note, object, chapter, layer, destination, protection grant, selected ink, source revision or configured provider makes the pending operation stale. Late callbacks cannot mutate newly selected content.
- Reuse existing BYOK credential adapters and model routing. No new secret store, model subscription integration or image-provider requirement.
- Suggested proposed additions: an ink case in a host-neutral enhancement-source value under `Core/Sophy/`, a small adapter from SP-042's coordinator, and typed insertion support in the appropriate existing session. Exact filenames should be fixed after SP-042's snapshot contract is accepted; do not create empty parallel layers beforehand.

## Protection, disclosure and recovery

- Local recognition happens before any cloud disclosure. Protected source requires current Notes/Collections grants and an explicit one-request consent explaining that the reviewed selected text will be sent to the named provider. Consent is never inferred from an earlier typed enhancement or a Settings toggle.
- Bulk search still excludes protected notes/folders. This feature uses an explicit current selection exception only; surrounding protected text and metadata must not join the request.
- Recheck source/access before generation, after response, on Copy and immediately before insertion. On relock/background/dismiss/source change, cancel work, clear protected buffers/reviews and follow existing clipboard concealment rules.
- UI must state that a provider already sent the reviewed text cannot be made to forget it by later cancellation. Cancellation prevents future disclosure/application; it cannot undo network receipt.
- Honor translation rights for any added verse context. Default context is reviewed personal handwriting only; no automatic Bible text injection. If the owner corrects text into a quotation, do not expand disclosure beyond that explicit selection.
- Prompt-injection strings in handwriting are untrusted content. Enhancement cannot create folders, change settings, open URLs, fetch sources or execute other Sophy actions. Returned text remains data, validated as the selected enhancement operation.
- Save/validation/capacity failure retains original ink and typed content; source-accessible review remains retryable. No deleting ink first, no partial insert and no success notice before the owning session accepts the command. Repeated taps cannot insert duplicates.
- Persistent source-history changes are excluded initially. Inserted results are ordinary text and inherit destination protection. Summary history must not contain source transcription or generated private content; review existing summary behavior before reuse.

## Implementation checkpoints

- **G0 source contract/design:** confirm SP-042 G1 acceptance, define tagged source validity, insertion destinations and consent lifetime; review with security/session owners. Stop if handwritten source can only be represented by a fake typed range.
- **G1 Canvas integration:** contextual action → reviewed OCR → existing operations → validated provider preview → Copy/Insert. Mock providers first; retain all original ink.
- **G2 races and regression:** protected source, route changes, provider change, background, cancellation, output editing, rapid taps, storage errors, existing typed selection/undo and Collection return. ENH-01–10.
- **G3 real provider/owner iPad:** explicit owner-triggered tests on non-sensitive sample handwriting and configured provider; capture only redacted outcome/latency. Feature success requires physical Pencil workflow and OCR review, not merely mock response success.
- **G4 subsequent surfaces:** Page/Journal/Prayer/Scripture individually after SP-042 prerequisites and target-host commands exist. Record each surface independently; no automatic scope expansion or claim of complete coverage.

## Acceptance and verification matrix

All checks start **Not Run**.

| ID | Acceptance criterion | Required evidence |
| --- | --- | --- |
| ENH-01 | Selecting ink/opening enhancement alone sends no provider request | Spy adapter + UI checks |
| ENH-02 | Reviewed/corrected text is the exact provider payload; no crop, note metadata, other text or previous turns | Request capture using synthetic fixtures |
| ENH-03 | All five existing operations retain their validated schema; Rate cannot replace ink/text | Unit/mock UI tests |
| ENH-04 | Protected selected-source disclosure requires current grants and one-request consent; correction resets it | Consent/access race tests + physical auth |
| ENH-05 | Source edit, move, route/layer change, relock, restore and provider switch invalidate late output/commit | Deterministic async tests |
| ENH-06 | Canvas insertion preserves all original strokes, creates text at confirmed destination, and supports undo/redo/reopen | Drawing digests + session/repository tests |
| ENH-07 | Cancel, malformed response, missing key, timeout, rate limit and save/capacity failure cause no source mutation | Failure injection |
| ENH-08 | Repeated Generate/Insert taps do not duplicate calls/objects; stale result never targets another note | UI/concurrency tests |
| ENH-09 | Existing typed-text enhancement/range checks/clipboard and Collection-local editor navigation remain correct | Existing regression suite + new mixed-origin cases |
| ENH-10 | Dynamic Type, VoiceOver, split view and Reduce Motion remain usable; no Pencil/scroll gesture conflict | Physical/manual matrix |
| ENH-11 | Owner completes a non-sensitive real-provider Pencil workflow and approves transcription/review/insertion | Explicit physical/provider evidence, no private payload logs |
| ENH-12 | Each later surface has independently valid source/destination/anchor handling | Per-surface SP-042 + enhancement acceptance |

## Documentation, exclusions and stop conditions

Update TDD, Sophy/Notes screen specs, selection/data/privacy contracts, SP-029 review guide, manual Pencil test cases, project map and tracker. Record where handwriting support differs from typed selection and how insert differs from replace.

Excluded: lassoing typed text and ink together, automatic ink replacement/deletion, full-note AI enhancement, background OCR, cloud image recognition, handwriting search, MCP bridge delivery, new enhancement operations and automatic provider submission. A future mixed-content lasso or replace-ink action requires its own explicit scope and undo/access design.

Stop on hidden content disclosure, stale-source application, loss of original ink, unsupported PencilKit internals, forced insertion into an unrelated text field or inability to cancel/undo. Human review of OCR and AI meaning remains part of the workflow; expansion must not invent Scripture quotations or present doctrinal suggestions as Scripture.

Evidence/status: planning only. Existing typed Sophy enhancement is source evidence, not proof of handwriting enhancement or physical acceptance.
