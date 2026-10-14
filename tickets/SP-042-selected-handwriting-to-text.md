# SP-042 — Box/lasso selected handwriting to reviewed text

Status: draft; detailed planning complete; implementation not selected.
Type: native UI + local recognition feature. Priority: high within proposed study automation.
Created: 2026-10-13, owner requested planning.
Milestone: proposed post-v1.1.0 study automation; target release unassigned.
Owners: Frontend and System Architect; SQA, Security, persistence owner and Documentation support.
Requirements: owner requests selecting handwritten annotation with a box and converting it to text; relates to SP-013/025 ink editing, without asserting a new existing global requirement ID.
Dependencies: SP-013/025, SP-012 for Scripture stage, SP-026–028 for access. No MCP, AI provider or subscription dependency. SP-043 consumes the reviewed result.

## Usable outcome

Select handwritten ink using a rectangle or lasso, choose Convert to Text, review/correct a local transcription, then copy it or insert typed text. Original ink stays unchanged by default. Notes Canvas is the first implementation checkpoint; Page-style notes and Scripture annotation layers are explicit subsequent checkpoints, not claimed to already have the same selection support.

“Skill” here is an in-app capability. This ticket does not create a Codex skill file as a substitute for native selection and OCR.

## Source evidence and missing pieces

All app paths below are under `application/SophiaScriptura/SophiaScriptura/`.

- `Features/Notes/Editor/NoteInkStrokeIndex.swift`: stable stroke references, polygon containment, sampled visible centerlines and selected bounds.
- `Features/Notes/Editor/NoteCanvasSurface.swift`: Canvas-only Pencil lasso interception and app-owned gesture selection. For non-Canvas content it currently substitutes an ink tool; Page support must be deliberately added.
- `Features/Notes/Editor/NoteCanvasInk.swift`: framed Canvas ink mapping, copying and edit reconciliation.
- `Features/Notes/NotesSession.swift`: stroke selection, guarded editing, undo and autosave; no ink transcription command.
- `Features/Notes/Editor/NoteMediaCapture.swift` / `NoteTextScan`: accurate Vision OCR of scanned images; currently flattens recognized lines and swallows OCR errors. Reuse the engine concept, but add a typed result/error contract instead of silently treating recognition failure as empty handwriting.
- `Features/Scripture/Annotations/AnnotationSession.swift`: layer IDs/revisions, edition/chapter/layout identity, flush/save coordination; no shared selected-ink transcription route.
- `Core/Annotations/AnnotationModels.swift`: layer drawing bytes. Do not assume persistent per-stroke IDs match Notes or introduce an unreviewed schema migration.

Read [Notes contract](../docs/data/notes-contract.md), [annotation contract](../docs/data/scripture-annotation-contract.md), [SP-025](SP-025-v030-compound-ink-and-stroke-editing.md), [item protection](../docs/security/item-protection.md), [compatibility](../docs/guidelines/backward-compatibility.md) and [Notes design](../docs/design/notes-screen-specification.md).

## Recommended interaction

1. Select ink using a visible **Select Ink** control with Rectangle and Lasso options. The Pencil palette lasso may activate the app-owned Canvas selector; never depend on undocumented PencilKit selection internals.
2. Rectangle drag selects strokes whose visible centerlines are fully contained, matching the current lasso rule. Touching a bounding box alone is insufficient. Show the actual selected stroke outlines/count; allow adjusting the boundary before recognition.
3. The contextual palette offers **Convert to Text** only for accessible nonempty ink selection. Selecting images, typed objects or shapes does not OCR them implicitly. Preserve existing move/copy/recolor/delete actions and gesture priorities.
4. Freeze the accepted drawing buffer and create an immutable selection snapshot. Render selected ink only on an opaque white background with safe padding, adapting neutral theme ink to dark contrast. Do not take a screenshot of the entire editor or Bible passage.
5. Run local recognition off the main thread; show progress, Cancel, actionable no-text/error states and an editable review sheet. Display transcription as recognized, not an AI-corrected paraphrase.
6. Actions: Copy Text, Insert Text and Cancel. Default is insertion that keeps the ink. No automatic “replace handwriting” in the initial scope. Label the destination before insertion; allow choosing a valid caret or placing a Canvas text object beside the selected bounds.
7. Keep a non-Pencil accessible path (selection tool controls and review actions). VoiceOver announces selection count, recognition state and destination; support Dynamic Type, split view and light/dark themes.

### Destinations and stage coverage

| Stage | Source selection | Destination recommendation |
| --- | --- | --- |
| G1 Notes Canvas | Existing app-owned stroke lasso plus rectangle | New text object adjacent to selection, constrained to existing document bounds; ink retained |
| G2 Page, Journal, Prayer | Add explicit ink-overlay selector independent of body/Scribble and viewport | Page/Journal body at a confirmed valid caret, or the existing appropriate Prayer text/update flow; never silently select an unrelated update |
| G3 Scripture annotations | Rectangle/lasso on the explicitly selected layer in its own layout coordinates | Copy, or create/file a new Page with verified canonical passage context; do not write arbitrary text into Bible text or delete annotation ink |

For G2 Prayer, prototype the destination picker before implementation: original prayer and individual updates are different editing surfaces. If there is no safely addressable text destination, ship Copy first for that surface and record Insert as blocked, rather than inventing unsupported rich text behavior. G3 verse anchoring is explicit: use the owner's selected verse range or a verified layout mapping; if ambiguous, offer reference selection and do not guess.

## Recognition contract and recommendations

- Use Apple Vision local OCR first. Handwriting accuracy is unproven on the owner's writing; a physical-device feasibility gate precedes full integration. Do not claim Scribble converts arbitrary saved ink or guarantee recognition merely because scan OCR exists.
- Initial language recommendation: English; enumerate supported recognition languages at runtime. Filipino/other languages are conditional on actual framework support and sample results. Unsupported languages show a clear explanation, never silently mislabel results.
- Return text lines with bounding boxes/candidate confidence where available, reading order, engine/language and warnings. Confidence is a recognition signal, not a correctness guarantee. Preserve newline structure; do not infer tables, mathematical notation or verse references as reliable text.
- OCR crop coordinates, document coordinates and view coordinates must be explicitly mapped through zoom, scroll, object transforms, layer margins and orientation. Extract chosen strokes, not every stroke intersecting a crop.
- A Notes snapshot includes note ID/kind, route collection ID, content revision, selected stable stroke refs plus drawing digest, transforms/bounds and access generation. A Scripture snapshot includes edition/source, book/chapter, group/layer ID, layer revision, layout identity and selected drawing digest. No reuse after switching source.
- Selection is ephemeral; accepted text becomes ordinary existing note content. No persistent OCR cache or new note schema is needed initially. Any later provenance/history metadata must be additive and covered by backup/legacy tests.
- Proposed budgets: one active OCR job; up to 2,000 selected strokes; raster ≤8 megapixels and longest edge ≤4,096 pixels; output ≤10,000 characters; 10-second cancellable deadline. Reject or ask for a smaller selection before allocation rather than unbounded downscaling. Validate budgets and peak memory on iPad in G0.
- Proposed performance target: typical paragraph selection completes within three seconds at p95 on the owner iPad after warmup, with responsive Cancel and no ink/input freeze. Record real measurements; this is a target, not current evidence.
- No cloud fallback by default. A future opt-in vision provider requires a separate disclosure/rights/budget design and must not send the underlying Scripture image. It is not required to complete the local-first slice.

## Access, stale results and durability

- Local OCR may operate on protected content only through the currently authorized editor route. Existing category/folder access remains authoritative; OCR must not unlock anything itself.
- Recheck access and exact source snapshot before presenting, copying and inserting. Source edited, relocked, deleted, restored, reflowed incompatibly or route changed means stale result: disable commit and request reselection. Do not auto-apply a late callback to whichever note is currently open.
- Cancel/ignore late recognition on background, dismissal, source switch or request supersession. Clear transient images/text associated with protected sources on concealment. Never log handwriting or recognized text.
- Protected clipboard uses the existing local-only expiring policy and clears on relock without overwriting a newer user clipboard. Copy is explicit disclosure; no auto-copy.
- Insert through the owning session, one undoable user command, then normal generation persistence. Preserve unrelated text, formatting, ink, attachment geometry, page status and protection. Undo/redo and save/reopen must preserve originals.
- Preserve byte-for-byte source drawing data on failed/cancelled OCR. If existing insertion capacity/height limits reject text, keep the editable result available while the source remains accessible and explain the failure. Never delete source ink to make room.

## Proposed ownership and implementation sequence

Recommended new files (proposals, not current APIs): `Core/Notes/InkTextSelection.swift` for immutable snapshots; `Infrastructure/Recognition/InkTextRecognizer.swift` for Vision and typed errors; `Features/Notes/Editor/InkTranscriptionCoordinator.swift` and `InkTranscriptionReviewSheet.swift` for transient orchestration/review. Extract shared selection geometry only if both Notes and Scripture need it; keep host coordinate mapping/session guards in their respective features.

1. **G0 accuracy/interaction spike:** render representative synthetic and owner-volunteered ink; evaluate Vision on physical iPad, at least 20 handwritten selections covering print, cursive, crossed-out words, verses, colors and mixed layouts. Keep real samples private under ignored build storage; owner approves any retained sample. Record character error rate (CER), correction time, runtime and peak memory. Recommended go/no-go baseline for ordinary English paragraphs: median CER ≤15% and at least 80% of samples useful after small corrections, with the owner approving the baseline before evaluation. Keep difficult/non-English samples separately reported; do not hide their failure rate. Confirm a useful review/correction workflow. If most ordinary samples require complete rewriting, stop and return with alternatives rather than proceeding under a false accuracy claim.
2. **G1 Canvas delivery:** snapshot/selection tests, selected-only renderer, cancellable recognizer, review, Copy and safe insertion/undo. Acceptance INK-01–10.
3. **G2 Page-style expansion:** explicit overlay selection and destination mapping; test Page/Journal/Prayer separately. No automatic carryover of Canvas gesture assumptions. Acceptance INK-11.
4. **G3 Scripture expansion:** selected layer extraction, immutable layout identity, reference selection and create-Page handoff with original ink unchanged. Acceptance INK-12.
5. Record each checkpoint's implemented/verified/blocked status. Complete the entire ticket only after all owner-selected surfaces pass their gates; partial Canvas delivery must be named as such.

## Acceptance and verification matrix

All checks start **Not Run**; automation does not close physical Pencil/OCR accuracy.

| ID | Acceptance criterion | Required checks |
| --- | --- | --- |
| INK-01 | Rectangle and lasso select only fully contained visible strokes; no accidental movement/ink | Geometry unit tests + Pencil/manual interaction |
| INK-02 | Selected-only image omits nearby typed text, Bible text and unrelated ink, including overlapped regions | Pixel fixtures across transforms, masks, themes and zoom |
| INK-03 | Known image fixtures produce typed text/error results and unsupported language handling | Recognizer tests; no assertion of perfect arbitrary handwriting |
| INK-04 | Empty/no-text/oversize/timeout/cancel/OCR failure leave source drawings unchanged | Fault injection and drawing digest assertions |
| INK-05 | Source revision/route/layer/access changes invalidate late output | Async race tests |
| INK-06 | Editable review never silently paraphrases; Copy/Cancel cause no document mutation | UI tests |
| INK-07 | Canvas insertion is one undoable command; undo/redo/reopen preserve ink, metadata and unrelated objects | Session/repository tests |
| INK-08 | Protection and local-only clipboard behavior match existing contracts | Lock/ancestor/clipboard race tests + physical auth |
| INK-09 | Selection/action/review usable in split view, rotation, Dynamic Type and VoiceOver | Accessibility/manual matrix |
| INK-10 | Owner paragraph samples meet an agreed useful accuracy baseline and measured responsiveness/memory target | Physical report; sample count and failures recorded |
| INK-11 | Page/Journal/Prayer independently select overlay ink and insert only at confirmed destinations | Per-kind UI/session/physical checks |
| INK-12 | Scripture selection is layer/layout-bound; copy/create note retains verified passage context and original ink | Annotation fixture tests + actual-reader Pencil walkthrough |

## Documentation, exclusions and stop conditions

Update TDD, Notes/annotation contracts and screen specifications, source map, OCR privacy behavior, SP-012/013 manual guides and tracker. Extend existing source owners; do not bypass repository validation or enlarge global ink limits to make OCR work.

Excluded: mixed typed-text/ink lasso, OCR of arbitrary attached images, automatic deletion/replacement of ink, handwriting search across the whole library, background indexing, cloud upload and MCP invocation. SP-043 owns enhancement, not this ticket.

Stop on private-selection leakage, unreliable coordinate mapping, source ink changes during recognition, unsupported selection internals, inaccessible cancellation or unbounded memory use. Any replacement-of-ink feature requires separate owner direction and atomic undo design.

Primary references checked 2026-10-13: [PencilKit drawing image](https://developer.apple.com/documentation/pencilkit/pkdrawing-swift.struct/image(from:scale:)-6p3zc), [Vision text recognition](https://developer.apple.com/documentation/vision/recognizing-text-in-images).

Evidence/status: planning only; existing scan OCR and Canvas lasso are implementation evidence, not acceptance evidence for handwriting transcription.
