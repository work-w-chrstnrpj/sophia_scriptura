# SP-023 — Chapter Hub and contextual Ask

- Type: implementation. Status: implemented; focused checks passed; owner acceptance pending.
  Owner selected 2026-10-04.
- Milestones: post-baseline M2/M5/M6 follow-up; baseline milestone closures remain intact.
- Ownership: Scripture UI/routing, Companion domain/context/session, focused SQA and docs.
- Requirements: REQ-004, REQ-005, REQ-011; owner conversation on 2026-10-04.
- Intent: [TDD §12](../docs/tdd/tdd.md), [Scripture design](../docs/design/scripture-screen-specification.md),
  [Companion contract](../docs/data/companion-contract.md).

## Outcome and boundaries

1. Selection Ask and Verse Hub Start conversation open blank question composers and send
   authorized complete involved verse(s), reference, active translation and selected focus
   immediately alongside the question in the outgoing provider request. Saved question
   content remains owner-written. No automatic question or send is introduced.
2. Chapter Hub opens via a labeled `Chapter` icon button in the annotation/actions row,
   per the owner's follow-up. The chapter title stays non-clickable. It uses the
   same popover/sheet layout policy as Verse Hub and contains only Links, Chapter
   Conversations and Verse Conversations, with quiet empty states.
3. Chapter Ask opens blank and sends only `In "Matthew Chapter 1 (WEB)"`-style reference
   context and the owner's question. No whole chapter is attached or loaded for transmission.
4. Chapter chats have distinct persisted anchors; existing verse chats (including OLA)
   are aggregated once per conversation, sorted by starting verse. Existing links are
   ordered numerically by verse. Queries respect canonical book/chapter and edition.

Exclusions: no OLA prompt/mode changes, new providers, preset rewrites, automatic response
rewriting, lexical corpus, chapter Notes/Save/Share, chapter-level link creation, migrations
of existing histories, or unrelated maintainability work. No real provider keys or private
responses are used in automated verification.

## Evidence and implementation

The screenshots show a passage card and transmitted-text disclosure, but the selected
model asks for the passage anyway. Source inspection confirms the original adapter sends
attachments in the system instruction, not beside the user question. This establishes an
instruction-placement weakness, not proof that transport dropped the text or certainty
about a model's internal reasoning.

- `Core/Companion/CompanionModels.swift`: optional chapter anchor and selected-text metadata;
  old records decode missing optional fields as nil; existing v3 envelope stays intact.
- `Infrastructure/Companion/CompanionContextBuilder.swift`: request-only context beside
  latest manual question, direct-answer instruction, character-budget fallback, disclosure
  filtering and unchanged initial OLA provider content.
- `Features/Companion/CompanionSession.swift`: chapter commands and queries, full verse
  attachment for Ask, reference-only chapter attachment, context retained on provider branch.
- `Features/Scripture/ScriptureView.swift`: quote authorization before transmitting full
  verse and selected focus, separate Chapter Hub entry and popover/sheet routing.
- `Features/Scripture/ChapterHubView.swift`: chapter index UI and verse-ordered link query.
- `Features/Companion/CompanionView.swift`: reference-only chapter context card.
- `Infrastructure/Companion/OpenAICompatibleProviderAdapter.swift`: extracts the unchanged
  live request-body serialization into a testable function; no endpoint/auth/model change.
- `SophiaScripturaTests/ScriptureHubTests.swift`: captures real Session-to-provider requests,
  checks serialized Groq-compatible body, retry/edit-resend, no restricted/local-only leak,
  persistence/backward decoding, chapter/verse separation, filtering, ordering and budget.

## Verification and acceptance

### Response/source follow-up selected 2026-10-04

- Owner screenshots still show ALLaM generating drafting instructions, HTML and unrelated
  material. Source inspection found alphabetical fallback selection and a compulsory
  bibliography format that accepted missing URLs and incorrectly marked generated entries
  as retrieved evidence. Passing request-composition tests did not establish answer quality.
- Curated chat models now lead fallback selection; new manual Scripture/chapter Ask chats
  defaulting to ALLaM choose an available curated model, preferring GPT OSS 120B, with a
  visible notice. Explicit model choices remain available; existing history is retained.
  OLA selection is not automatically switched. Groq's [current model catalog](https://console.groq.com/docs/models)
  was checked on 2026-10-04; account availability still comes from its model-list response.
- Markdown instructions omit sample answer scaffolds. Bibliographies are optional and must
  represent identifiable cited works; generated references do not establish retrieval.
  The concrete template artifacts from the screenshots mark a new reply failed, retaining
  original output in its attempt. This does not detect all factual errors.
- Sources includes a publisher link for the selected WEB chapter (representative
  [1 Thessalonians 2 page](https://ebible.org/engwebp/1TH02.htm) verified on 2026-10-04),
  validates HTTP(S) model links, rejects credential-bearing/unsafe URLs, and offers a
  labeled reference search for entries without direct URLs. Old replies gain passage/link
  inspection without rewriting their content. Model references remain visibly unverified.
- Chapter now appears with its icon and label in the annotation/actions row, as requested.
- Follow-up suite `build/companion-source-repair-r3-20261004.xcresult`: **56 passed,
  0 failed, 0 skipped**, covering Companion, hubs, sources and adapter conformance.
  Signed device build and strict signature verification passed; installed in place and
  launched on the paired iPad. Logs: `build/companion-source-repair-device-20261004/`.
  No uninstall/reset or historical answer rewrite. Real-provider
  answer quality and physical interaction remain owner checks; fixture output is not an
  evaluation of GPT OSS or ALLaM factual accuracy.

`build/chapter-hub-ask-final-20261004.xcresult`: **60 passed, 0 failed, 0 skipped**
across CompanionTests, ScriptureHubTests and ScriptureReaderTests on iPad (A16) Simulator /
iOS 26.5. Simulator and signed physical-device builds passed. The initial run had two
fixture failures from capturing background Quiz Me warmup as chat traffic; filtering chat
requests in the fixture resolved these without changing app lifecycle. `git diff --check`
passes. Existing project warnings remain; no real provider answer was verified.

Signed Debug build and strict `codesign --verify --deep --strict` passed; installed in
place on `iPad ni Paj` and launched as `com.personal.SophiaScriptura`, without uninstall,
data reset or translation sync. Logs: `build/chapter-hub-ask-device-20261004/`
(`build.log`, `signature.log`, `install.log`, `launch.log`). See the
[deployment record](../docs/deployment/deployment.md). Delivery is complete; owner
interaction and real-provider acceptance remain pending below.

Owner iPad acceptance (pending):

1. Select a word/phrase → Ask. Confirm blank composer and full involved verse card. Ask
   "What is this about?"; inspect that the real provider answers that passage directly.
2. Verse Hub → Start a new conversation. Ask "What does it mean?"; verify the same context,
   then Retry and Edit/resend. Check OLA's existing workflow separately remains unchanged.
3. Open Chapter in the annotation/actions row for Matthew 1. Confirm only the three requested sections, links in
   numeric order, each verse/range conversation listed once and no cross-chapter/edition items.
4. Ask about this chapter. Confirm blank question, chapter/translation reference-only card,
   no verse quote. Send a question, relaunch and reopen the same persisted chapter chat.
5. Open existing verse conversations and links from Chapter Hub. Verify the existing item
   opens without duplication. Rotate and test a narrow panel; dismiss to unchanged reader.

Passing tests prove request composition and persistence, not factual accuracy or adherence
by a real model. Physical interaction and answer quality must not be marked accepted from
build/install evidence alone. Stop if deployment would require uninstall/reset or credentials
in logs; preserve all existing uncommitted owner work. No commit/push is included.
