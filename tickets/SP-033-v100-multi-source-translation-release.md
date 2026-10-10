# SP-033 — v1.0.0 multi-source translation release

Status: draft; planning only, implementation not selected.
Target: v1.0.0. Created: 2026-10-10.
Parent: owner-requested release plan.

## Outcome and scope

Deliver one offline-first Scripture library backed by independent bundled WEBP, API.Bible and AO Lab adapters. Source selection must never change the displayed edition silently. WEB means World English Bible, a translation family rather than a transport provider. Existing bundled WEBP remains available without networking or credentials.

This is the owner-requested v1.0.0 release plan, not an implementation or publication instruction. Requirements: REQ-023; SP-002/009/010/012 compatibility. SP-032 ESV remains a separate v0.5.* draft; if implemented first, preserve its bounded-cache policy through the new routing contract. ESV audio is not a v1.0.0 prerequisite.

Excluded: commentaries, Strong's data, automated/background fetching, downloading the entire global catalog, new backend, App Store distribution, and unreviewed canon support beyond WEBU and RTL support.

## Delivery sequence

1. SP-034: source identity, policy, routing and compatibility foundation.
2. SP-035: live AO catalog, eligibility review and Scripture parser.
3. SP-036: explicit, recoverable full-edition AO downloads and updates.
4. SP-037: unified Versions UI and study-workflow integration.
5. SP-039: Scripture narration player and verified verse highlighting; owner audio choices and recording rights gates apply.
6. SP-038: upgrade, provider/device/audio acceptance and release gate.

All implementation tickets are draft until their stated inputs/dependencies are met. No ticket is complete merely because this plan exists.

## Source policy matrix

| Source | Access | Storage and refresh | Identity |
| --- | --- | --- | --- |
| Bundled WEBP | No key, no network | Existing immutable bundled SQLite; app-delivered updates | Preserve `web.engwebp` and `org.sophia.web.engwebp` |
| API.Bible | Existing owner key/approved editions | Existing encrypted store, authorization, Release lease and Debug exception; explicit manual sync | Preserve existing `api.bible.*` IDs |
| AO Lab | No key | Edition-specific rights; manually downloaded generations; no invented 30-day expiry | Proposed `helloao.<exact-provider-id>`; distinct reference identity |

Do not infer rights from a source name or MIT software license. Discovery, download, offline reading, quotation, Copy/Share, AI transmission and backup/export are separate capabilities. Unknown rights mean visible pending review, not automatic download permission.

## Release acceptance

- Bundled WEBP and existing API.Bible downloads survive upgrade with original identities and study artifacts.
- All five selected AO editions—KJV, BSB, ASV, LSV and WEBU—are installed, switched, read offline and restored after relaunch after their rights and content checks pass.
- No network request starts on launch/resume/navigation/connectivity restoration. Catalog refresh, download and update are explicit actions.
- All SP-034–038 acceptance gates pass or have explicit owner waivers recorded; unknown content rights are not silently waived.
- Release remains targeted v1.0.0 until implementation, checks and owner acceptance are complete. Assign version/build and publish only in the selected release execution scope.

## Evidence and risks

Checked 2026-10-10: current source and official AO documentation; unauthenticated live catalog contains 1,256 entries. Catalog availability is not rights/completeness approval. No authenticated API.Bible call or app test performed.

Critical risks: current prefix-derived WEB reference fallback, shared API.Bible authorization leakage, changed text moving ink, incomplete editions, unbounded downloads and incompatible legacy snapshots. Child tickets own mitigations and tests.

Sources: [AO overview](https://bible.helloao.org/docs/), [catalog/reference](https://bible.helloao.org/docs/reference/translations/), [standard content and complete download](https://bible.helloao.org/docs/reference/translations/standard.html), [bulk downloads](https://bible.helloao.org/docs/guide/downloads.html).

## Detailed execution contract — refinement 2026-10-10

[Implementation guide](../docs/design/v100-translation-implementation-guide.md) supplies
source call sites, proposed domain contracts, legacy decode fixtures, AO normalization,
transaction ordering, operation states, engineering bounds, screen behavior and TR-01–22
verification. These are proposed requirements, not implemented APIs or passing evidence.

Owner decisions: D2 keeps annotated revisions active until explicit switching; D3 supports the four selected 66-book editions plus the complete WEBU inventory, including its additional books, with verified mapping. D1 is settled: KJV, BSB, ASV, LSV and WEBU. The guide decision register controls readiness; earlier shortlist recommendations are not approval.

Owner answers recorded 2026-10-10: preserve the active annotated revision until an explicit switch; support the selected complete 66-book editions plus WEBU’s complete additional-book inventory with verified mapping. D1 is settled: KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`).

## Final initial-edition selection — 2026-10-10

Owner selected KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`) for AO support. Bundled WEBP and approved API.Bible editions remain. All five are required release acceptance targets, subject to verified rights and complete content/mapping. Reconcile AO LSV’s reported 31,104 verses against the publisher’s 31,102 before signoff; preserve CC BY-SA attribution and applicable conditions. WEBU is owner-selected for v1.0.0, including its 15 additional entries; other extended-canon editions remain excluded. Earlier candidate shortlists and pending-D1 notes are superseded.

## WEBU scope expansion — owner selected 2026-10-10

WEBU (`eng_webu`, proposed app ID `helloao.eng_webu`) joins KJV, BSB, ASV and LSV for v1.0.0. Include all 81 provider book entries (66 plus 15 additional entries), not a silently truncated 66-book subset. The implementation guide section 10 defines inventory, navigation, identity, references, annotations and TR-19–22 acceptance. This supersedes the earlier 66-book-only boundary for WEBU alone. All five selected editions require acceptance; implementation remains unselected.

## API.Bible selection correction — owner reported 2026-10-10

Target API.Bible selection is NASB, NLT and NKJV; NASB replaces NIV. The inspected checkout still lists NIV in LicensedTranslations.swift, so this is an owner-reported selection change, not verified runtime implementation. Owner confirmed NASB 1995. Its exact API.Bible provider ID and edition-specific rights remain to be verified through authorized provider metadata. Do not guess an ID or simply rename the NIV entry. Keep legacy NIV reference IDs, notes, saved quotations and annotations intact and source-unavailable where appropriate; never relabel NIV text or ink as NASB. NASB gets its own edition/reference identity and verified policy/attribution. The historical Debug exception specifically named NIV11/NLT/NKJV and must not automatically extend to NASB. Verify NASB offline rights/lease and any development authorization before enabling its cache. No credentials or owner data are changed by this planning correction.

## Audio scope added — 2026-10-10

[SP-039](SP-039-v100-scripture-audio-and-verse-highlighting.md) adds owner-requested player controls and synchronized verse highlighting to v1.0.0. Initial BSB recording/timing candidate requires source/rights/coverage validation. A1–A3 approved: ±15-second plus chapter navigation; Continuous and Follow toggles initially off; streaming plus optional manual chapter/book downloads. This supersedes the earlier AO-audio exclusion; it does not promise audio for every translation or word-level timings.
