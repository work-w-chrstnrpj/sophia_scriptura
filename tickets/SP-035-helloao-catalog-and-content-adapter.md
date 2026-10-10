# SP-035 — AO Lab catalog, eligibility and content adapter

Status: draft; planning only, implementation not selected.
Target: v1.0.0. Created: 2026-10-10.
Parent: [SP-033](SP-033-v100-multi-source-translation-release.md).

## Outcome and dependencies

Depends on SP-034 contracts. Owners: integrations, architecture, security, SQA. Discover available translations and normalize eligible AO chapters without downloading full editions yet.

## Acquisition and eligibility

1. Explicit Refresh Catalog calls `https://bible.helloao.org/api/available_translations.json`; cache metadata for offline browsing. Preserve exact case-sensitive IDs and links. Fetch book manifests through `/api/{translation}/books.json` only through explicit discovery/download actions.
2. Keep a versioned reviewed eligibility manifest: edition ID, source URLs, date, license/notice evidence, permitted storage/quotation/AI/export operations, coverage and mapping support. Missing or changed rights evidence blocks new installation until reviewed, while previously stored content follows its recorded policy.
3. Initial supported content: left-to-right editions whose exact book/chapter/verse mapping fits the existing reader contract. Other languages are not inherently blocked; unsupported RTL, additional books outside the approved WEBU inventory, verse numbering or incomplete coverage receive an explanation. Never label a partial edition a complete Bible or discard extra books silently.
4. Live candidates observed 2026-10-10: `BSB`, `eng_kjv`, `eng_asv`, `tgl_ulb`, `ceb_ulb`, `ceb_ocb`, `ENGWEBP`, `eng_web`, `eng_webu`, `eng_webpb`. These are candidates, not approved licenses. Proposed first release: BSB plus one eligible edition chosen before SP-038 live tests. WEB variants must retain separate identities and edition labels.

## Parser and transport steps

Implement AO DTOs/transport/parser under Infrastructure/Scripture with Core values as output. Standard chapter endpoint: `/api/{translation}/{book}/{chapter}.json`. Standard JSON supports headings, subtitles, verse content pieces, poetry, line breaks, words of Jesus and footnotes. Preserve wording and supported formatting; extend the reader contract where required rather than silently dropping footnotes. Reject unknown semantic structures until deliberately supported.

Validate HTTPS same-origin API links, identifiers, response edition/book/chapter and payload size. No API.Bible key is ever read or sent. Use conservative bounded requests, timeouts and capped retries honoring Retry-After. Treat publisher license links as external informational links, not trusted download instructions.

Reference compatibility must use actual book/verse sets, not only 66/1,189/31,102 counts. Never invent a missing verse or reuse WEBP text. Record provider revision/hash if trustworthy; otherwise compute deterministic normalized-content revision locally. Verify documented hash semantics before comparing a provider hash with downloaded bytes.

## Acceptance and verification

- Recorded live catalog metadata and fixture tests show exact IDs, languages, coverage, source and license links. Missing fields fail or degrade predictably without enabling downloads.
- Fixtures cover Genesis prose, Psalm poetry/subtitles, words of Jesus, footnotes, Unicode Tagalog/Cebuano, omitted verses, partial NT and unsupported book/RTL data.
- Parsed verse text matches source; footnotes are not verse text/anchors; deterministic blocks/revision do not change with dictionary iteration order.
- Wrong edition/chapter, malformed JSON, unknown structures, cross-origin links, timeout and throttling produce source-specific errors. Test zero credential headers.
- Live unauthenticated sample checks are recorded separately from mocked tests and rights review. Do not fetch all editions for testing.

Docs: maintain AO endpoint/schema/eligibility decisions in Scripture content integration and reader contract. Stop unsupported editions at eligibility; no global regex flattening or implicit mapping. Status: draft; rights review and parser tests not run.

Sources: [catalog](https://bible.helloao.org/api/available_translations.json), [reference](https://bible.helloao.org/docs/reference/translations/), [standard schema](https://bible.helloao.org/docs/reference/translations/standard.html).

## Detailed execution contract — refinement 2026-10-10

[Implementation guide](../docs/design/v100-translation-implementation-guide.md) supplies
source call sites, proposed domain contracts, legacy decode fixtures, AO normalization,
transaction ordering, operation states, engineering bounds, screen behavior and TR-01–22
verification. These are proposed requirements, not implemented APIs or passing evidence.

Read sections 1, 4 and TR-04–06. D3 is revised: complete selected 66-book editions plus WEBU’s complete 81-entry book inventory, all with supported verse mapping. D1 is settled: KJV, BSB, ASV, LSV and WEBU; verify all five exact editions before eligibility signoff. Preserve wordsOfJesus, arbitrary supported poetry levels and footnote caller metadata additively; update regular and annotation rendering together. Verify actual licenses per edition and record exact eligible IDs; a catalog entry is not an approval. Unsupported source mappings trigger an owner question if they affect a selected edition.

Owner answers recorded 2026-10-10: preserve the active annotated revision until an explicit switch; support the selected complete 66-book editions plus WEBU’s complete additional-book inventory with verified mapping. D1 is settled: KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`).

## Final initial-edition selection — 2026-10-10

Owner selected KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`) for AO support. Bundled WEBP and approved API.Bible editions remain. All five are required release acceptance targets, subject to verified rights and complete content/mapping. Reconcile AO LSV’s reported 31,104 verses against the publisher’s 31,102 before signoff; preserve CC BY-SA attribution and applicable conditions. WEBU is owner-selected for v1.0.0, including its 15 additional entries; other extended-canon editions remain excluded. Earlier candidate shortlists and pending-D1 notes are superseded.

## WEBU scope expansion — owner selected 2026-10-10

WEBU (`eng_webu`, proposed app ID `helloao.eng_webu`) joins KJV, BSB, ASV and LSV for v1.0.0. Include all 81 provider book entries (66 plus 15 additional entries), not a silently truncated 66-book subset. The implementation guide section 10 defines inventory, navigation, identity, references, annotations and TR-19–22 acceptance. This supersedes the earlier 66-book-only boundary for WEBU alone. All five selected editions require acceptance; implementation remains unselected.
