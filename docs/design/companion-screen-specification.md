# Companion screen specification

Status: owner-approved M6 planning baseline, 2026-10-02. No Companion runtime is
implemented by this document. Requirements: REQ-011–013, REQ-019, REQ-024 and REQ-025.
Technical storage and provider boundaries are in the
[Companion data contract](../data/companion-contract.md).

## Product boundary

Companion is an explicitly online, provider-neutral study workspace inside the existing
Companion tab. The owner may configure multiple bring-your-own-key providers. Sophia ships
an adapter for each supported provider; "any provider" means any provider with a compatible
adapter, not an assumption that unrelated APIs are interchangeable. OpenAI, Anthropic and
Gemini are the first intended adapters. An OpenAI-compatible custom endpoint is a later
adapter, with an owner-entered base URL and the same trust-boundary checks.

Sophia's local history is authoritative. Each conversation pins its provider, model,
provider capability snapshot and resolved prompt-preset snapshot. Changing provider starts
a new conversation by default. **Continue with another provider** explicitly creates a
branched conversation after showing which permitted context will be copied.

## iPad information architecture

- The leading column contains New Conversation, Quiz Me, search and conversation history.
- The main column contains messages, passage/note attachments, source cards and composer.
- Source and transmitted-context details use an inspector on wide layouts and a sheet on
  compact layouts.
- Scripture may show the same conversation in a side panel when both columns remain
  readable. Compact widths use a sheet or the full Companion destination.
- Moving between the panel and tab, switching tabs, backgrounding and relaunch preserve
  conversation identity, scroll position and unsent draft.

The composer visibly shows the selected preset, provider/model, attached-context chips,
research availability and that Send transmits the displayed context online. It never
implies that the whole local library or unrelated conversations are available to the model.
Provider requests include a response-format instruction: return readable Markdown with
short paragraphs, descriptive headings for distinct sections, and lists where useful rather
than one unbroken paragraph. The UI renders that Markdown and falls back safely to plain text.

Assistant messages use Foundation's full Markdown parser to render headings, paragraphs,
bulleted and numbered lists, block quotes and fenced code, preserving inline emphasis and
links. Streaming chunks are concatenated verbatim and saved without rewriting Markdown:
transport chunk boundaries do not define paragraphs or emphasis. No regular-expression
recovery inserts inferred breaks or changes URLs, code or escaped content. Provider instructions
request valid Markdown with actual newlines. User-message bubbles hug short prompts and wrap longer
prompts within the available panel width, capped at 560 points; they remain trailing aligned.

Scripture selection includes both **Ask** and **Original Language Analysis**. The latter
opens a passage-linked Companion draft that identifies Hebrew, Aramaic or Koine Greek as
appropriate and requests original wording, transliteration, key words/grammar, literary and
historical context, meaning in context and translation observations. It explicitly rejects
root-only word studies and decontextualized dictionary-gloss lists.

## Provider settings

Settings lists each supported adapter with provider name, API-key status, available models,
default model, optional lower-cost quiz model, advertised capabilities, connection test and
Delete Key. Keys are written to Keychain per provider/account and are never displayed again,
logged or exported. A replacement requires the complete new key.

Capabilities are explicit: streaming, structured output, tools, provider retrieval, usage
reporting and cancellation. A missing capability is disabled with an explanation; Sophia
does not silently claim that a search, tool or citation check occurred.

## Retrieval and source presentation

Local Scripture retrieval remains Sophia-owned and uses canonical references plus a
permitted local edition. A model may compose an explanation but does not establish a
Scripture quotation or quiz answer key. Licensed text is transmitted only when the edition's
permissions allow it; otherwise Sophia sends the reference or offers an explicitly permitted
edition such as WEB.

External research may use provider retrieval when the selected adapter supports it. Sophia
normalizes returned evidence into source cards containing, where available: title,
author/publisher, publication date, URL or work identifier, retrieval provider and the
claim the source supports. Without retrieval evidence the response is labeled **No external
sources retrieved**. Citation formatting alone is never treated as source verification.

Source priority for answer validation is: permitted Scripture; primary historical sources;
official institutional or denominational sources; academic books, journals and recognized
reference works; reputable general web sources; then explicitly unverified model recollection.
Christian History quiz keys may use only the first four tiers.

## Privacy and selected context

Each request contains only the resolved preset, current question, permitted current
conversation context and attachments deliberately included by the owner. Notes, Collections,
unrelated conversations and the whole library are never attached implicitly. Before Send,
the UI identifies each attachment as local-only, reference-only or text transmitted.

Messages show failed, refused, partial and interrupted states. Retrying reuses the same user
turn and creates a linked response attempt rather than duplicating the question. Deleting a
message invalidates any derived context summary that included it.

## Quiz Me

Quiz Me is a structured Companion mode, not an ordinary chat and not a new tab. Setup chooses
quiz types, difficulty, permitted Scripture edition, timed/untimed mode, and **Record this as
Reviewing**, which defaults on and can be disabled before the session.

| Type | Answer control | Current validation |
| --- | --- | --- |
| Identify the Verse | Four choices | Provider key plus cited Scripture reference; AI provenance disclosed |
| Complete the Verse | Text field with optional word bank | Normalized selected-edition text |
| Scripture or Cap | Scripture / Cap buttons | Provider key plus cited reference; AI provenance disclosed |
| Who Said It? | Four speaker choices | Provider key plus cited Scripture reference; AI provenance disclosed |
| Christian History | Four choices | Provider key plus requested primary-source label; AI provenance disclosed |
| Bible Quiz | Four choices | Provider key plus cited Scripture reference; AI provenance disclosed |
| Bible or False | True / False | Provider key plus cited Scripture reference; AI provenance disclosed |

Complete the Verse ignores case, surrounding punctuation and repeated whitespace. A
paraphrase is not silently accepted as exact: it may be marked **Nearly correct**, separately
from Correct, and the selected edition wording is then shown. Provider-generated questions
are parsed as strict JSON and rejected when their count, type order, choices, keyed index,
required reference, explanation or exact uniqueness is invalid. This is structural rather
than independent factual validation. Sophia locally repositions the keyed answer for ordinary
multiple-choice questions so provider ordering bias does not make the first choice predictably
correct. True/False and Scripture/Cap retain their conventional control order.

Untimed is the default. Timed mode is per question: Easy 60 seconds, Average 45 seconds and
Difficult 30 seconds. The timer pauses between questions, while feedback is shown, and for
background/system interruption. Expiry records Unanswered, awards zero points and still
shows the explanation. There are no speed bonuses. Results show points earned/available,
percentage, and Correct/Nearly correct/Incorrect/Unanswered counts.

Quiz setup uses the already approved counts and points: Easy 10 × 1, Average 5 × 3 and
Difficult 3 × 5. Quiz history stores the setup, edition, provider/model used for composition
or explanation, start/active/completion time, score, completion state, every question/key,
owner answer, result, explanation, sources and optional Reviewing record link.

When **Record this as Reviewing** is enabled, a completed or intentionally ended session
creates a Reviewing record. Only active question/feedback time counts; paused/background
time does not. Reviewing contributes to the normal daily goal and streak. An abandoned
session does not create a record automatically, but its elapsed time may be saved manually.
Activity stores duration, date, mode, title and quiz-session ID only; quiz answers and score
remain owned by Companion. Deleting quiz history leaves a linked Activity record with a
source-deleted state.

Quiz Me prepares up to 20 Easy, 10 Average and 6 Difficult questions per selectable type,
enough for two consecutive single-type quizzes once fully warm.
A warm session opens from the local cache; a first or depleted session waits for the selected
provider to generate the missing set. In-app replenishment is requested after consumption
and again after completion or quit. The first playable set takes priority over spares. Each
generation request includes a random nonce and a distinct difficulty rubric, without full
recent-question prompt padding. Sophia rejects exact and strong word-overlap repeats against
the response, cache and history. Real-provider review must evaluate subtle paraphrases,
factual keys and perceived difficulty because those properties are not proven locally.

## Acceptance scenarios

- Configure two provider keys, start independent conversations and confirm neither key or
  provider history appears in logs, exports or the other conversation.
- Ask about a passage, follow with an ambiguous reference, correct an assumption, reopen the
  chat, switch panel/tab and relaunch without losing the conversation or draft.
- Branch to another provider and verify the copied-context disclosure, new identity and
  original conversation remain intact.
- Exercise streaming completion, cancellation, refusal, offline mode, invalid key, rate
  limit, partial response and retry without duplicate user turns.
- Inspect retrieved and non-retrieved responses; unavailable retrieval never appears as a
  successful search or verified citation.
- Run representative timed and untimed quizzes, including Nearly correct, Unanswered,
  background pause, deterministic decoy, inspected Christian History source, saved history,
  deletion and Reviewing linkage.

## Exclusions from the first implementation slice

- Automatic cross-conversation memory or personal profiling.
- Silent provider fallback or automatic mid-conversation model switching.
- Arbitrary provider APIs without a compatible adapter.
- Provider accounts, purchases or bundled Sophia credentials.
- A general autonomous agent, background web research or actions outside the displayed
  request.
