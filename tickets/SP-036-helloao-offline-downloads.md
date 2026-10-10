# SP-036 — Recoverable AO Lab offline downloads and manual updates

Status: draft; planning only, implementation not selected.
Target: v1.0.0. Created: 2026-10-10.
Parent: [SP-033](SP-033-v100-multi-source-translation-release.md).

## Outcome and dependencies

Depends on SP-034/035. Owners: persistence/integrations, security and SQA. Explicitly download selected eligible translations, keep them offline and update safely. Existing API.Bible and bundled storage remain source-owned.

## Download design and steps

1. Default to bounded chapter requests using the selected edition's books manifest. This allows granular progress/resume without loading an entire Bible in memory. `/api/{translation}/complete.json` is an official alternative, but adopt it only after measured memory/size and integrity checks; never use the all-source ZIP/11 GB database in the app.
2. Store AO data in its own local generation store under Infrastructure/Scripture/Persistence, not API.Bible's lease store. Manifest records source/edition/reference IDs, coverage, content hashes, attribution/rights snapshot, parser schema, fetch date and revision. Use platform file protection; additional encryption is edition-policy driven.
3. Before downloading, check disk space including staging and previous generation. Set documented payload/disk/request bounds during implementation. Snapshot metadata/eligibility, validate every chapter and persist a completed-chapter journal. Resume only compatible validated staging; if provider revision changes, restart staging safely.
4. Commit only a fully validated declared-coverage generation with an atomic manifest switch. Relaunch sees old valid generation or new valid generation. Cancellation, failure, low disk and process termination preserve readable installed content. Incomplete first downloads are not advertised as installed. Staging cleanup cannot delete active data.
5. Where no stable provider revision exists, record per-chapter hashes and revalidate manifest/content before promotion; document residual upstream snapshot-consistency limits. Never claim independent authenticity from a locally calculated checksum.
6. Updates require an explicit Check for Updates/Update action. No invented 30-day lease for AO. Network errors never expire open content. New revisions pass annotation compatibility handling before presentation; preserve old revision/ink recovery when geometry differs.
7. Delete Download removes replaceable AO content only, with confirmation and size/status. Preserve notes, collections, canonical references and annotations; keep unresolved study references visible. Bundled WEBP cannot be deleted through this action. Backup exports contain study data/provenance by default; include translation text only where policy and archive format explicitly permit it.

## Acceptance and tests

- Install, progress, cancellation, resume and manual update work for one selected edition; zero background fetches.
- Crash injection at staging writes and manifest promotion, corrupted payload, wrong revision, disk-full, timeout, throttle and restart preserve old content; interrupted fresh install remains uninstalled.
- Validated resume does not skip corrupted completed chapters. Concurrent operations serialize or reject cleanly; late completions after cancellation/delete cannot resurrect content.
- Offline reading and relaunch require no catalog/network/key. AO failure/deletion does not block WEBP or API.Bible; API.Bible denial cannot block AO.
- Changed revisions retain references and quarantine incompatible ink geometry; tests show no silent ink reattachment.
- Deletion/backup/restore tests preserve study artifacts and respect source policy. Record storage/performance measurements on owner iPad before release.

Docs: data/recovery contract, content integration, backup exclusions and manual test guide. Stop before promotion on coverage, identity, rights or integrity mismatch. Status: draft; implementation/tests not run.

## Detailed execution contract — refinement 2026-10-10

[Implementation guide](../docs/design/v100-translation-implementation-guide.md) supplies
source call sites, proposed domain contracts, legacy decode fixtures, AO normalization,
transaction ordering, operation states, engineering bounds, screen behavior and TR-01–22
verification. These are proposed requirements, not implemented APIs or passing evidence.

Read sections 5–6 and TR-07–11/14. D2 is decided: keep annotated revision active until explicit switching; installed generation and active reading revision remain separate. Follow explicit journal/root-pointer ordering, operation epochs, annotation pins, lease-aware cleanup and engineering bounds. Never automatically activate updates for annotated editions or prune their pinned source revisions. Follow the guide’s edition-wide revision switching rule. The completion record must show injected crash/race/disk tests, not only successful downloads.

Owner answers recorded 2026-10-10: preserve the active annotated revision until an explicit switch; support the selected complete 66-book editions plus WEBU’s complete additional-book inventory with verified mapping. D1 is settled: KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`).

## Final initial-edition selection — 2026-10-10

Owner selected KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`) for AO support. Bundled WEBP and approved API.Bible editions remain. All five are required release acceptance targets, subject to verified rights and complete content/mapping. Reconcile AO LSV’s reported 31,104 verses against the publisher’s 31,102 before signoff; preserve CC BY-SA attribution and applicable conditions. WEBU is owner-selected for v1.0.0, including its 15 additional entries; other extended-canon editions remain excluded. Earlier candidate shortlists and pending-D1 notes are superseded.

## WEBU scope expansion — owner selected 2026-10-10

WEBU (`eng_webu`, proposed app ID `helloao.eng_webu`) joins KJV, BSB, ASV and LSV for v1.0.0. Include all 81 provider book entries (66 plus 15 additional entries), not a silently truncated 66-book subset. The implementation guide section 10 defines inventory, navigation, identity, references, annotations and TR-19–22 acceptance. This supersedes the earlier 66-book-only boundary for WEBU alone. All five selected editions require acceptance; implementation remains unselected.
