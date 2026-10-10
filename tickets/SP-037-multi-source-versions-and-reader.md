# SP-037 — Multi-source Versions controls and reader integration

Status: draft; planning only, implementation not selected.
Target: v1.0.0. Created: 2026-10-10.
Parent: [SP-033](SP-033-v100-multi-source-translation-release.md).

## Outcome and dependencies

Depends on SP-034–036. Owners: frontend, architecture, SQA. Provide one understandable library while keeping source-specific actions and credentials separate.

## UI and integration steps

1. Inspect `Features/Scripture/ScriptureVersionsView.swift`, `ReaderSession.swift`, app composition and existing quote/annotation/Companion callers. Replace API.Bible-only assumptions with source descriptors and capabilities.
2. Show Installed and Browse views, searchable by translation/language with source filters. Each row shows exact edition, source, language, coverage, attribution/rights link and offline/download status. A metadata-only catalog row is not an installed edition.
3. Bundled WEBP shows Included offline. API.Bible retains Keychain credentials, approved editions and manual Sync/expiry/development notices. AO shows Refresh Catalog, Download, progress, Cancel/Resume, Update and Delete Download as applicable; no key field or expiry warning.
4. Do not merge same-named editions across sources. Bundled WEBP and AO `ENGWEBP` are separately labelled; source substitution is explicit. Sync All, if retained, must state the exact source/editions and never download every discovered AO translation.
5. Switching restores the selected edition at an explicitly compatible verse reference; missing passages explain unavailability rather than substitute text. Restore preferred edition offline after relaunch. Reject stale results after navigation, source changes, cancellation or credentials changes.
6. Route Copy/Share/Save, Companion/Sophy context, meditation passage resolution and annotations through the selected edition's policy and reference identity. Citation/provenance follows quotations. AI transmission requires an allowed operation and the existing user-triggered flow. Do not alter canonical references to force cross-edition alignment.

## Acceptance and tests

- UI tests cover source filters, installed vs discovered entries, credential isolation, correct actions and all download states.
- No networking on open Versions, app launch/resume, navigation or connection recovery; explicit catalog refresh/download/update/sync alone initiate requests.
- Switch WEBP → API.Bible → AO and relaunch offline: exact edition/attribution/position remains correct. Missing verse and duplicate labels cannot produce hidden substitution.
- Copy/Save/Ask tests prove selected source policy is used; annotations remain scoped to edition/revision. Pending rights disable affected actions with an understandable reason.
- VoiceOver labels, Dynamic Type, touch reachability and long translated names are verified; unsupported directions never render as falsely supported.

Docs: reader screen/settings specification, TDD source matrix and manual walkthrough. Preserve current appearance controls and manual-sync semantics. Status: draft; implementation and physical acceptance not run.

## Detailed execution contract — refinement 2026-10-10

[Implementation guide](../docs/design/v100-translation-implementation-guide.md) supplies
source call sites, proposed domain contracts, legacy decode fixtures, AO normalization,
transaction ordering, operation states, engineering bounds, screen behavior and TR-01–22
verification. These are proposed requirements, not implemented APIs or passing evidence.

Read sections 3 and 7; verify TR-03/11–13/17. Source-aware native menu authorization and explicit cross-reference mapping are required. Apply approved D2 revision/layer UI and D3 selected-edition eligibility including WEBU; retain old annotated revisions. Versions opening is local-only. API Sync All retains its three-edition source scope; no AO Download All. Show rights-pending/unsupported rows with disabled actions and reasons.

Owner answers recorded 2026-10-10: preserve the active annotated revision until an explicit switch; support the selected complete 66-book editions plus WEBU’s complete additional-book inventory with verified mapping. D1 is settled: KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`).

## Final initial-edition selection — 2026-10-10

Owner selected KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`) for AO support. Bundled WEBP and approved API.Bible editions remain. All five are required release acceptance targets, subject to verified rights and complete content/mapping. Reconcile AO LSV’s reported 31,104 verses against the publisher’s 31,102 before signoff; preserve CC BY-SA attribution and applicable conditions. WEBU is owner-selected for v1.0.0, including its 15 additional entries; other extended-canon editions remain excluded. Earlier candidate shortlists and pending-D1 notes are superseded.

## WEBU scope expansion — owner selected 2026-10-10

WEBU (`eng_webu`, proposed app ID `helloao.eng_webu`) joins KJV, BSB, ASV and LSV for v1.0.0. Include all 81 provider book entries (66 plus 15 additional entries), not a silently truncated 66-book subset. The implementation guide section 10 defines inventory, navigation, identity, references, annotations and TR-19–22 acceptance. This supersedes the earlier 66-book-only boundary for WEBU alone. All five selected editions require acceptance; implementation remains unselected.

## API.Bible selection correction — owner reported 2026-10-10

Target API.Bible selection is NASB, NLT and NKJV; NASB replaces NIV. The inspected checkout still lists NIV in LicensedTranslations.swift, so this is an owner-reported selection change, not verified runtime implementation. Owner confirmed NASB 1995. Its exact API.Bible provider ID and edition-specific rights remain to be verified through authorized provider metadata. Do not guess an ID or simply rename the NIV entry. Keep legacy NIV reference IDs, notes, saved quotations and annotations intact and source-unavailable where appropriate; never relabel NIV text or ink as NASB. NASB gets its own edition/reference identity and verified policy/attribution. The historical Debug exception specifically named NIV11/NLT/NKJV and must not automatically extend to NASB. Verify NASB offline rights/lease and any development authorization before enabling its cache. No credentials or owner data are changed by this planning correction.
