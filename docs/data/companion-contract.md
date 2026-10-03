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

The selected provider currently supplies quiz questions, provisional answer keys and cited
references. The app validates structure, required fields, choice bounds, requested type order
and exact duplicate exclusion, but does not independently prove the cited claim. Persisted
question history retains the generated key and provenance disclosure for review.

SP-019 stores prepared quiz questions in Companion snapshot schema v3. Each cached item is
independent of a session and is scoped to one provider configuration, adapter, model,
edition, difficulty, game type and prompt-contract version. The target is 20 Easy, 10
Average and 6 Difficult items per selectable type (two complete quizzes). On quiz start, the session takes the
required items from the cache and creates session-specific question records in the same
in-memory mutation before the next serialized generation save. Prior v1/v2 snapshots
decode with an empty cache; existing quiz history is not rewritten. Deleting a provider
configuration removes its prepared items. Keys remain only in Keychain.
Reconciliation fills one playable quiz per bucket before spare capacity, and is requested
on start, completion, quit, app load and return to foreground. A running refill incorporates newer priorities
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
the Reviewing Activity record. Completing all quiz questions creates the Reviewing link
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
- Reviewing linkage stores no answer/score duplication and survives source quiz deletion.
