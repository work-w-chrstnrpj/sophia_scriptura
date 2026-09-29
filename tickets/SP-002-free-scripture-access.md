# SP-002 — Verify free Scripture access

- Type: research. Status: done (free baseline verified; optional entitlements conditional). Owner: Backend & Database Engineer.
- Requirements: REQ-002, REQ-003, REQ-005, REQ-014, REQ-019.
- Dependencies: free-first preference confirmed; account-specific checks may remain blocked.
- Design: [TDD §8](../docs/tdd/tdd.md#8-external-integrations).
- Affected later modules: ContentStore, provider adapters, ingestion, AudioEngine, Save/Ask.

## Purpose and scope

Establish a usable no-paid-content baseline and assess NIV/NLT/NKJV/ESV without
confusing a provider's public catalog with this app's entitlements.

## Work

1. Pin a WEB edition, format, book set, source, attribution, and import-integrity plan.
   Resolve the difference between the scaffold's 66 books and source edition contents.
2. Compare YouVersion SDK/API and Crossway standard access. Keep API.Bible an
   alternative only where the actual free access meets requirements.
3. Record a matrix of price, account requirements, text availability, cache lifetime/size,
   bundling, copied quotations, export, AI context, TTS, narration, and attribution.
4. Mark uncertain permissions for clarification; do not infer them from technical access.
5. Specify offline/expired/unavailable behavior, including preserving user links/ink.

## Acceptance and verification

- At least one complete offline base candidate has publisher evidence and a reproducible
  import validation plan; downloading or implementing ingestion is separate work.
- Each preferred edition is classified as verified available, conditional, or unresolved.
- No full ESV offline-download claim is made under standard API terms.
- Terms include date/source links; account checks identify missing evidence explicitly.
- Define tests for expired caches, limits across stored quotations, attribution, and
  fallback without silently changing the selected translation.

## Outputs and boundaries

Fill the integration specification's content section; update TDD and requirements as
needed. Keep provider keys out of documents. Do not run the existing ingestion stub as
if it were a functioning or permission-compliant download tool.

## Execution contract

Planning work only in the current stage. No implementation completion is implied by
this ticket. Record unresolved items explicitly. Do not create provider accounts,
accept agreements, purchase access, or obtain credentials on the owner's behalf.

## Evidence

2026-09-21: Completed public-source research in the
[content integration specification](../docs/integrations/scripture-content.md).
Selected `engwebp` USFM as the first-reader planning baseline, matching the existing
66-book map. Publisher evidence supports an offline base; the archive snapshot/hash and
import validation remain future implementation work. No Bible archive, account, key,
authenticated API request or runtime integration was created.

NIV/NLT/NKJV/ESV are explicitly classified as conditional; account-specific availability,
permanent offline access and some quote/export/AI/audio grants remain unresolved.
Corrected outdated API.Bible Starter assumptions and an unsupported ESV audio prohibition.
YouVersion's linked terms body could not be read; its SDK capability is not treated as a
content license. Recorded ten future acceptance cases, including expiry, shared quotation
limits, attribution, fallback and preservation of user artifacts.

Owner clarified the goal: obtain legitimate text through files/APIs, map it and render
Sophia's own Scripture interface for personal use. TDD now states that architecture
explicitly. No provider UI is required. Optional licensed editions do not block WEB.

Acceptance disposition: research complete, not ingestion or provider implementation.
Next recommended selection: SP-003 renderer/layout planning using the offline baseline;
SP-005 reader contracts follow. Neither ticket was automatically executed. Validation:
local book map contains 66 unique USFM IDs; documentation link/path and whitespace checks.
