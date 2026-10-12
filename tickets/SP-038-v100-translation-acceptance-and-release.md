# SP-038 — v1.0.0 translation acceptance and release gate

Status: publication selected by owner on 2026-10-13; full acceptance remains open.
Target: v1.0.0. Created: 2026-10-10.
Parent: [SP-033](SP-033-v100-multi-source-translation-release.md).

## Outcome and dependencies

Depends on SP-034–037 and SP-039. Owners: SQA, security, documentation and release operations. Verify the integrated multi-source library and prepare v1.0.0 for personal sideload delivery.

## Required execution

1. Freeze the exact candidate commit and record approved AO editions/rights evidence. Recheck official provider documentation; unchanged API.Bible implementation does not grant new editions. If ESV exists, run its policy regressions without expanding its cache permissions.
2. Run focused identity/parser/download/policy/legacy migration tests, existing licensed reader and annotation suites, and full native suite for the release snapshot using current test-specification commands. Record result bundles/counts/failures and relevant UI tests.
3. Use a copied legacy data fixture for destructive/fault tests. Verify upgrade from the owner's actual installed baseline, snapshots, ink, saved verse quotes, collections, Companion/Sophy references and backups. No uninstall/reset of owner data.
4. Physical iPad: bundled WEBP, existing approved API.Bible and at least two eligible AO editions; explicit catalog refresh/download/cancel/resume/update; airplane-mode navigation and relaunch; source switching/restore; Save/Ask/Copy rights; annotation revision changes; deletion of replaceable AO content; accessibility and disk/performance measurements.
5. Record real-provider evidence separately from fixtures/simulator results and owner reports. Record any deferred gate with an explicit owner decision; no automatic completion from build/install/launch.
6. Update integration, reader/data/recovery, screens, test and deployment docs. Create actual v1.0.0 release notes only when behavior/evidence is known. Increment app version/build at release execution, preserve recovery references, verify final branch/tag/release and install in place through the existing installer workflow when authorized.

## Acceptance and stop conditions

- Every child ticket has evidence against each acceptance criterion; compatibility, source isolation and offline recovery pass.
- Installed translations are identified by source/edition/revision; API.Bible policies remain effective and no unreviewed edition is enabled.
- No user-authored content lost and no automatic provider traffic. Owner accepts actual iPad library workflows.
- Remaining defects/waivers are visible in release notes; rights ambiguity, data corruption or wrong-translation display prevents release.
- Publication/installation only occurs in owner-selected release execution scope. This planning ticket does not publish v1.0.0.

Status: draft; all release tests, live authenticated provider checks and physical acceptance not run. Planning-only changes require links/path validation and `git diff --check`, not native tests.

## Detailed execution contract — refinement 2026-10-10

[Implementation guide](../docs/design/v100-translation-implementation-guide.md) supplies
source call sites, proposed domain contracts, legacy decode fixtures, AO normalization,
transaction ordering, operation states, engineering bounds, screen behavior and TR-01–22
verification. These are proposed requirements, not implemented APIs or passing evidence.

Use section 8 as the release evidence matrix and section 9 as documentation ownership. Verify all five D1 editions and the approved D2/D3 rules. Record each TR ID against tests/manual evidence and exact candidate commit; tests can be Passed/Failed/Not Run, observations Owner Reported, and deferrals Waived with named owner decision. Data/text loss, wrong source, unknown enabled-edition rights and unsafe ink revision behavior prevent release.

Owner answers recorded 2026-10-10: preserve the active annotated revision until an explicit switch; support the selected complete 66-book editions plus WEBU’s complete additional-book inventory with verified mapping. D1 is settled: KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`).

## Final initial-edition selection — 2026-10-10

Owner selected KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`) for AO support. Bundled WEBP and approved API.Bible editions remain. All five are required release acceptance targets, subject to verified rights and complete content/mapping. Reconcile AO LSV’s reported 31,104 verses against the publisher’s 31,102 before signoff; preserve CC BY-SA attribution and applicable conditions. WEBU is owner-selected for v1.0.0, including its 15 additional entries; other extended-canon editions remain excluded. Earlier candidate shortlists and pending-D1 notes are superseded.

## WEBU scope expansion — owner selected 2026-10-10

WEBU (`eng_webu`, proposed app ID `helloao.eng_webu`) joins KJV, BSB, ASV and LSV for v1.0.0. Include all 81 provider book entries (66 plus 15 additional entries), not a silently truncated 66-book subset. The implementation guide section 10 defines inventory, navigation, identity, references, annotations and TR-19–22 acceptance. This supersedes the earlier 66-book-only boundary for WEBU alone. All five selected editions require acceptance; implementation remains unselected.

## API.Bible selection correction — owner reported 2026-10-10

Target API.Bible selection is NASB, NLT and NKJV; NASB replaces NIV. The inspected checkout still lists NIV in LicensedTranslations.swift, so this is an owner-reported selection change, not verified runtime implementation. Owner confirmed NASB 1995. Its exact API.Bible provider ID and edition-specific rights remain to be verified through authorized provider metadata. Do not guess an ID or simply rename the NIV entry. Keep legacy NIV reference IDs, notes, saved quotations and annotations intact and source-unavailable where appropriate; never relabel NIV text or ink as NASB. NASB gets its own edition/reference identity and verified policy/attribution. The historical Debug exception specifically named NIV11/NLT/NKJV and must not automatically extend to NASB. Verify NASB offline rights/lease and any development authorization before enabling its cache. No credentials or owner data are changed by this planning correction.

## Audio release gate

SP-039 AU-01–09 joins TR-01–22 as required evidence. Verify actual BSB playback/highlighting, chosen controls/follow/continuous/offline behavior and system audio ownership on iPad. A1–A3 are approved; recording permission gates must be resolved; unavailable audio on other editions remains explicitly labelled.

## Owner-selected publication — 2026-10-13

Owner instruction: “Release all the changes as v1.0.0”, including commit, push, merge
and release. Scope is all current worktree changes and version 1.0.0/build 22.
Publication does not close the unexecuted physical/provider TR/AU acceptance gates
or certify copied legacy-data upgrade tests. See [release notes](../docs/releases/v1.0.0.md).
Recovery: `codex/recovery-pre-v1.0.0-20261013` preserves prior main;
`build/v100/pre-release-refs.bundle` preserves pre-release Git references locally.
Final app evidence: `build/v100/activity-final.xcresult`; 369 unit tests and the Activity workflow UI test passed.
Four reader UI tests passed in `build/v100/final-acceptance.xcresult` before the final
Activity accessibility identifier correction; full UI suite remains incomplete.
The initial `build/v100/results.xcresult` run failed and was interrupted during UI execution;
its stale fixtures and contrast regression were corrected. Results are recorded in release notes.
