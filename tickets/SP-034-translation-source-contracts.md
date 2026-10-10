# SP-034 — Source contracts and backward-compatible translation routing

Status: draft; planning only, implementation not selected.
Target: v1.0.0. Created: 2026-10-10.
Parent: [SP-033](SP-033-v100-multi-source-translation-release.md).

## Outcome, dependencies and ownership

Dependency: SP-033 scope. Owners: architecture, Scripture/persistence, security and SQA. Refactor existing providers behind source-neutral contracts while preserving behavior. No AO network/download/UI work in this ticket.

## Exact current boundaries

`Core/Scripture/ScriptureModels.swift`: `ScriptureContentRepository` already abstracts reading, but `ChapterDocument.referenceSystemID` treats every non-API.Bible edition as WEBP. `ChapterDocument.isLicensed` and `ReaderSession.isLicensed` infer policy from prefixes. `Features/Scripture/ReaderSession.swift` restores only API.Bible via the library. `Core/Scripture/LicensedTranslations.swift`, `Infrastructure/Scripture/OfflineTranslationLibrary.swift`, `APIBibleClient.swift` and `Infrastructure/Persistence/EncryptedBibleStore.swift` own provider-specific policy/storage. These are implementation truth; proposed types below are not existing APIs.

## Implementation steps

1. Inventory all edition-prefix checks, quote authorization, annotation keys, reading snapshots, collection references, Companion/Sophy contexts and backup paths. Record callers and baseline tests before edits.
2. Define source descriptor, edition descriptor and capability/policy contracts under Core/Scripture. Include source ID, exact source edition ID, app edition ID, reference-system ID, revision, language/direction, coverage, provenance, attribution, rights evidence and supported operations. Policies must support full-edition and bounded-passage sources.
3. Add a registry/coordinator under Infrastructure/Scripture. Views → sessions → contracts → source adapters; no provider JSON or credentials in views. Wrap bundled repository and existing API.Bible library without rewriting transport/encryption/lease logic.
4. Persist explicit reference identity additively in chapter/snapshot contracts. Legacy decoding preserves WEBP/API.Bible identities exactly; unknown edition IDs without explicit identity fail safely. Do not retain the current generic WEB fallback. Unknown source restore preserves original state and offers an explicit switch.
5. Route reader and quote/context authorization through descriptors/policies. Keep API.Bible-specific errors and authorization scoped to API.Bible. Source selection never grants another source's rights.

## Acceptance and tests

- Legacy reader snapshots, chapter documents, annotations and quote metadata decode and round-trip with unchanged identity; test real legacy fixtures for both existing sources.
- Two equal provider IDs from different sources cannot collide. AO cannot acquire WEBP references or API.Bible lease/Debug exceptions.
- Existing API.Bible lease, revocation, rollback, encryption, manual-sync and cache-recovery tests pass unchanged in meaning. Launch/resume makes zero network calls.
- Unknown sources and malformed reference identities fail without rewriting saved locations. Older-reader compatibility or safe refusal is documented and tested.
- Existing reader/annotation/collection/Companion tests relevant to changed callers pass. ESV behavior, if present by execution, remains bounded and source-specific.

Stop before persistence writes if legacy mapping is ambiguous; preserve fixtures and resolve the mapping. Update reader contract, content integration and TDD with actual final APIs. Status/evidence: planning only; tests not run.

## Detailed execution contract — refinement 2026-10-10

[Implementation guide](../docs/design/v100-translation-implementation-guide.md) supplies
source call sites, proposed domain contracts, legacy decode fixtures, AO normalization,
transaction ordering, operation states, engineering bounds, screen behavior and TR-01–22
verification. These are proposed requirements, not implemented APIs or passing evidence.

Read sections 2–3 and TR-01–03/12/15 before coding. The authorization call-site audit must include native UIKit copy/share/drag and annotation text surfaces, not only ReaderSession. Deliver an explicit caller inventory and copied legacy fixtures with the implementation. SP-034 can become ready independently of D1–D3 after source/compatibility review; it does not select any owner-pending behavior.

Owner answers recorded 2026-10-10: preserve the active annotated revision until an explicit switch; support the selected complete 66-book editions plus WEBU’s complete additional-book inventory with verified mapping. D1 is settled: KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`).

## Final initial-edition selection — 2026-10-10

Owner selected KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`) for AO support. Bundled WEBP and approved API.Bible editions remain. All five are required release acceptance targets, subject to verified rights and complete content/mapping. Reconcile AO LSV’s reported 31,104 verses against the publisher’s 31,102 before signoff; preserve CC BY-SA attribution and applicable conditions. WEBU is owner-selected for v1.0.0, including its 15 additional entries; other extended-canon editions remain excluded. Earlier candidate shortlists and pending-D1 notes are superseded.

## WEBU scope expansion — owner selected 2026-10-10

WEBU (`eng_webu`, proposed app ID `helloao.eng_webu`) joins KJV, BSB, ASV and LSV for v1.0.0. Include all 81 provider book entries (66 plus 15 additional entries), not a silently truncated 66-book subset. The implementation guide section 10 defines inventory, navigation, identity, references, annotations and TR-19–22 acceptance. This supersedes the earlier 66-book-only boundary for WEBU alone. All five selected editions require acceptance; implementation remains unselected.

## API.Bible selection correction — owner reported 2026-10-10

Target API.Bible selection is NASB, NLT and NKJV; NASB replaces NIV. The inspected checkout still lists NIV in LicensedTranslations.swift, so this is an owner-reported selection change, not verified runtime implementation. Owner confirmed NASB 1995. Its exact API.Bible provider ID and edition-specific rights remain to be verified through authorized provider metadata. Do not guess an ID or simply rename the NIV entry. Keep legacy NIV reference IDs, notes, saved quotations and annotations intact and source-unavailable where appropriate; never relabel NIV text or ink as NASB. NASB gets its own edition/reference identity and verified policy/attribution. The historical Debug exception specifically named NIV11/NLT/NKJV and must not automatically extend to NASB. Verify NASB offline rights/lease and any development authorization before enabling its cache. No credentials or owner data are changed by this planning correction.
