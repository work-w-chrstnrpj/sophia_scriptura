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

Local canonical Scripture and curated quiz fixtures establish Scripture answer keys.
Transmission is capability-checked at initial prompt, follow-up, summary, retry and retrieval
boundaries. When text is not permitted, use a canonical reference or an explicitly permitted
edition. External retrieved text retains source identity and permission/retention metadata.

Christian History answer keys require an inspectable primary, official or academic/reference
source record. Model output may help draft a question or explanation but cannot create or
approve its own authoritative key.

## Local generations, recovery and deletion

Companion and Quiz history use checksummed, versioned generations with atomic publication,
current/previous recovery and damaged-generation preservation, consistent with other Sophia
feature stores. Import validates into staging before publication. Failed import or migration
leaves the current local store usable.

Backup includes permitted local conversations, source metadata, prompt snapshots and Quiz
history. It excludes API keys, authorization data, provider caches and restricted Scripture
replicas. Conversation deletion removes messages, attempts, derived summaries and memberships.
Quiz deletion removes questions, answers, explanations and sources; an Activity record keeps
only its duration metadata and a source-deleted marker.

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
