# Companion data, provider and recovery contract

Status: owner-approved M6 planning contract, 2026-10-02. This defines the implementation
boundary; no provider adapter or production persistence is implemented here. Interaction
behavior is in the [Companion screen specification](../design/companion-screen-specification.md).

## Ownership

- Core/Companion owns provider-neutral conversation, message, attachment, source, prompt
  snapshot, quiz and attempt values plus repository and adapter protocols.
- Infrastructure/Companion owns validated local generations, Keychain provider credentials,
  provider adapters, HTTP streaming and export/import implementation.
- Features/Companion owns conversation, source inspection, provider setup routing, Scripture
  panel continuity, Quiz Me and history presentation.
- The composition root registers supported adapters and supplies repositories. Views do not
  select concrete providers or read credentials directly.

## Shared route and Hugging Face

`CompanionSnapshot` may store optional `defaultProviderConfigID` and `defaultModelID`.
Snapshots that omit them keep the previous new-chat behavior: the first saved configuration
that has a key, and that configuration's model. An explicit shared route is used for new
chats. Existing conversation and quiz records keep their stored provider and model. Quiz
uses its own saved defaults when those are present; only absent quiz defaults inherit the
shared route. Removing the selected route's key does not silently switch to another provider.

Hugging Face adapter id is `huggingface`. Chat requests use
`https://router.huggingface.co/v1/chat/completions` with a Bearer token. Connection testing
sends a one-token completion for the selected model id, including any `:provider` suffix.
A successful model list is not treated as proof of inference. Hugging Face models are not
labeled free, and none is selected automatically.

Qwen (Alibaba Cloud Model Studio / DashScope) uses OpenAI-compatible chat completions.
Adapter ids are `qwen-cn` (China Beijing keys,
`https://dashscope.aliyuncs.com/compatible-mode/v1`) and `qwen-intl` (international keys,
`https://dashscope-intl.aliyuncs.com/compatible-mode/v1`). API keys are region-bound; a
401 on the wrong endpoint should prompt the owner to switch adapters. Curated models include
Flash and Turbo as paid/unknown-cost options; no Qwen free-model filter is offered. Remote model lists merge when the key can list models. Trial quota depends on the account and provider console.

## Provider-neutral contract

`LLMProviderAdapter` exposes provider identity, model discovery when supported, advertised
capabilities, connection validation, cancellation and a normalized asynchronous event stream.
Normalized events cover response start, text delta, source/retrieval evidence, tool request
and result, usage, completion, refusal, interruption and failure.

Provider-specific payloads remain inside the adapter. The shared domain does not pretend all
providers support the same tools, search, roles, usage fields or continuation identifiers.
Sophia sends locally composed context on every request; provider-side conversation state may
optimize a request but is never the only copy or authority.

## Stable identities and records

- `ProviderConfigurationReference`: stable local ID, adapter ID and account label; never a
  secret value.
- `ProviderCapabilitySnapshot`: provider/model plus capabilities used by a conversation.
- `PromptPresetSnapshot`: resolved shared guardrail, preset content and version/hash.
- `CompanionConversation`: local ID, title, provider/model snapshots, timestamps, state and
  optional parent conversation/branch point.
- `CompanionMessage`: local ID, conversation ID, role, permitted content, timestamps,
  delivery state and ordered response attempts.
- `CompanionAttachment`: passage/note/artifact identity, disclosure mode and retained
  permitted payload or reference.
- `CompanionSource`: normalized provenance plus supported claim and retrieval evidence.
- `ContextSummary`: derived, provenance-linked context with source message IDs.
- `QuizSession`, `QuizQuestion`, `QuizAnswerKey`, `QuizAttempt` and `QuizResult`: separate
  concepts so generated explanation text cannot become an answer key implicitly.

Conversation messages are ordered by stable local sequence, not provider timestamps. A
streaming response is stored as an incomplete draft and becomes complete only after a
terminal event. Retry adds an attempt to the same assistant response slot and does not
duplicate the user turn.

Assistant deltas are concatenated verbatim, regardless of transport chunk boundaries.
Completion and persistence retain that same Markdown source in the message and its response
attempt. Presentation uses a full Markdown parser rather than inserting inferred whitespace,
unescaping content or rewriting emphasis. Existing malformed saved responses are not migrated:
the owner can retry the response or edit and resend the prompt to regenerate it.

## Context composition

Ask-from-Scripture persists its passage anchor and permitted complete-verse attachment independently of
the user's question. Its initial composer draft is empty and there is no auto-send action
or generated user message. When the owner sends a question, the user turn retains exactly
that question; the context builder prefixes the latest provider-facing user turn with the
reference/translation, attached complete involved verses and selected focus. The system
instruction also retains explicit attachments. This request-only composition resolves
short questions like "What does it mean?" without changing stored user content or OLA's
initial structured provider content. It is rebuilt on follow-up, retry and edit/resend.
If this user-turn prefix exceeds the existing character budget it falls back to a disclosed
reference-only prefix; earlier turns are removed first to keep the budget. Reference-only
disclosure never adds restricted verse wording. Existing saved drafts/history are unchanged.

SP-023 adds optional `CompanionAttachment.selectedText` (only authorized transmitted
wording) and optional `CompanionConversation.chapterAnchor`. Missing fields decode as nil
in existing v1-v3 generations; the existing v3 writer and recovery envelope stay unchanged.
The chapter anchor stores canonical book, chapter, edition and a display reference, not
a synthetic verse range. Chapter conversations keep a reference-only attachment with no
payload. Request context is `In "{book} Chapter {number} ({translation})"`; no chapter text
is loaded or transmitted for this action. Provider branches retain the same anchor and
explicit attachments. Hub queries separate chapter and verse chats by canonical identity
and edition, and display an overlapping multi-verse conversation only once.

For Original Language Analysis, the title is prefixed `OLA:` while the passage anchor retains
the plain canonical reference. The selected wording and translation/mode are retained in the
user message's display content and full provider prompt; the passage attachment retains the
authorized complete involved verse(s). Existing `providerContent` carries the structured
instructions into follow-ups and retries. No new snapshot schema or history migration is
required. If expanded quote authorization fails, neither selection nor passage text is sent:
the attachment is reference-only and the prompt explains that the target wording is unavailable.

The context builder resolves the pinned preset exactly once, includes the current question,
permitted explicit attachments, recent relevant turns and still-valid summaries. It reserves
room for the answer, records omitted ranges, and never implies that every saved message was
sent. Unrelated chats, private notes and the entire library are excluded unless the owner
explicitly attaches them.

Changing provider creates a branched conversation with a new provider/model snapshot.
Deleted or redacted messages invalidate all summaries derived from them before the next
request. Provider content, retrieved documents and generated summaries are untrusted data,
not instruction authority.

## Credentials and network trust boundary

API keys use device Keychain items scoped per provider/account. Records and exports store
only the stable configuration reference. Keys, authorization headers, complete request
bodies, private responses and restricted text are excluded from logs and diagnostics.

Requests enforce HTTPS. A future custom endpoint requires an explicit owner-entered URL,
rejects non-HTTPS transport, does not forward a key across redirects to another origin, and
shows the destination host during setup and connection testing.

## Scripture and retrieval policy

SP-023 source handling: bibliography entries and URLs supplied by a model have provenance
`model-bibliography` or `model-link`; parsing them does not set retrievalPerformed or
retrievalAvailable. Sources also derives an `attached-scripture` reference from the
conversation anchor, linking WEB chapters to their eBible.org publisher page. This is
the selected text's reference, not independent proof of the answer. Only valid HTTP(S)
URLs without credentials are opened. A work without a URL offers a clearly labeled web
search rather than a fabricated direct source. Existing replies gain these display-time
links without rewriting stored text. Recognizable HTML/template artifacts in new replies
produce a failed message, with raw provider text retained in the response attempt.

The selected provider currently supplies quiz questions, provisional answer keys and cited
references. The app validates structure, required fields, choice bounds, requested type order
and exact duplicate exclusion, but does not independently prove the cited claim. Persisted
question history retains the generated key and provenance disclosure for review.

SP-019 stores prepared quiz questions in Companion snapshot schema v3. Each cached item is
independent of a session and is scoped to one provider configuration, adapter, model,
edition, difficulty, game type and prompt-contract version. SP-048 uses 100 as a minimum refill target and 200 as the hard capacity per type /
difficulty bucket (18 buckets per provider/model/edition scope). Below 100, warmup
fills toward 200; reservations above the minimum request replacement of the consumed
quantity without discarding surplus. Refills request at most 10 questions per batch
and await each validated merge's serialized save before requesting more. On quiz start, the session takes the
required items from the cache and creates session-specific question records in the same
in-memory mutation before the next serialized generation save. Prior v1/v2 snapshots
decode with an empty cache; existing quiz history is not rewritten. Deleting a provider
configuration removes its prepared items. Keys remain only in Keychain.
Reconciliation fills one playable quiz per bucket before spare capacity, and is requested
on start/Again/exam, completion, quit, app load and return to foreground. Ready starts
await only local reservation persistence, not provider generation. Cold starts request
only missing questions; exams recheck readiness after each small batch. A running refill incorporates newer priorities
at the next batch boundary, prioritizing the selected type and difficulty. Failed warmups leave existing questions intact and use bounded
in-app retries; iPadOS suspension may prevent completion.
Transmission is capability-checked at initial prompt, follow-up, summary, retry and retrieval
boundaries. When text is not permitted, use a canonical reference or an explicitly permitted
edition. External retrieved text retains source identity and permission/retention metadata.

Christian History generation requests a concise primary, official or academic/reference
source label. Until that source is independently resolved and checked, the generated key is
provisional and must remain visibly AI-authored.

## Local generations, recovery and deletion

Companion and Quiz history use checksummed, versioned generations with atomic publication,
current/previous recovery and damaged-generation preservation, consistent with other Sophia
feature stores. Import validates into staging before publication. Failed import or migration
leaves the current local store usable.

Backup includes permitted local conversations, source metadata, prompt snapshots and Quiz
history. It excludes API keys, authorization data, provider caches and restricted Scripture
replicas. Conversation deletion removes messages, attempts, derived summaries and memberships.
Quiz deletion removes questions, answers, explanations and sources; an Activity record keeps
only its duration metadata and a source-deleted marker. Deleting Quiz history does not delete
the Studying Activity record. Completing all quiz questions creates the Studying link
automatically, without a separate Activity timer or an opt-out switch; abandoned sessions
remain unrecorded. Untimed quizzes track active question time as well as timed quizzes.

## Required contract tests

- Adapter conformance and normalized streaming event order for every provider.
- Provider/model snapshot round trip and explicit cross-provider branching.
- Keychain isolation, replacement/deletion and export/log secret exclusion.
- Context isolation, budget trimming, explicit attachments and summary invalidation.
- Cancellation, refusal, partial stream, retry idempotency, offline, invalid key, 429 and
  malformed provider response.
- Licensed-content blocking across first request, follow-up, summary, retry and retrieval.
- Atomic save, previous-generation recovery, corrupt preservation, migration and failed
  import rollback.
- Deterministic Scripture quiz keys/decoys, tolerant Complete-the-Verse normalization,
  Christian History provenance and score/history round trips.
- Studying linkage stores no answer/score duplication and survives source quiz deletion.

Compatibility note for v0.3.0: Companion retains the existing `reviewingLinks`, `recordReviewing` and `reviewingLinkID` stored field names. They are historical wire names, not an Activity mode. Activity classifies all imported Quiz Me links as Studying, migrates existing Reviewing records/goals to Studying, and preserves quiz-session identity, suppression and source-deletion behavior.


## Sophy integration (SP-029)

Sophy reuses the explicit shared provider/model binding and Keychain credentials without
adding her turns to Companion conversations. Deleted explicit bindings fail closed.
Sophy turns, selected text, reviewed excerpts and pending plans are memory-only; action
History contains type/status/time/count and result IDs. General requests attach no note
bodies. Local lookup excludes protected Notes, protected Collections/ancestry and mixed
memberships even when unlocked. Sending eligible excerpts requires Review Context.
Selected protected text has a separate per-request enhancement consent boundary.

Sophy history and non-replayable receipts use independent checked current/previous JSON
generations. Full backup's optional `sophyHistory` field carries validated summaries only;
absence preserves local History. Restore invalidates pending requests and never imports
execution receipts. See the [implementation guide](../design/sophy-implementation-guide.md)
and [review evidence/remaining gates](../testing/sp029-sophy-review.md).

Collection conversation deletion uses Companion’s authoritative Trash command, with
Collections projections reconciled by existing sync callbacks. Qwen model names do
not establish free pricing; adapters use conservative paid/unknown labels.
