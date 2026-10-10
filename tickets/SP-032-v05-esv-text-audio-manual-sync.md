# SP-032 — v0.5.* ESV text, passage audio and manual cache refresh

Status: draft; source-grounded plan complete, implementation not selected. Audio persistence permission gate open.
Type: feature. Target: v0.5.*; exact patch release unassigned. Created: 2026-10-10.
Owners: Product/Planning and Architect (scope/contracts), integration and persistence,
Frontend (reader/Versions/player), Security (credentials/redirects), SQA and documentation.
Requirements: REQ-014 (Scripture audio), REQ-023 (translation variety), existing reader and annotation contracts.
Dependencies: SP-002/009/010/012; SP-021 music and SP-030/031 system-control boundaries.

## Purpose and boundary

Owner requests ESV text and sound through Crossway's API, local caching, and a manually
triggered sync after 30 days. Deliver bounded ESV reading with passage narration and
visible refresh status. This ticket reintroduces ESV-specific narration after M7 was
abandoned; it does not reopen the entire M7 scope or its historical acceptance.
This request authorizes planning and writing this ticket, not app implementation.

Excluded: full offline ESV, bulk book/Bible downloads, automatic/background sync,
search endpoint, TTS, other audio editions, timed verse/word highlighting, automatic
next-chapter downloads, new backend, changes to API.Bible grants or Debug exceptions,
release publication, and closure of existing device acceptance gaps.

## Verified provider evidence and permission gate

Checked 2026-10-10:

- [Overview](https://api.esv.org/docs/): token authorization; separate text and audio endpoints.
- [Text](https://api.esv.org/docs/passage-text/): JSON passage strings and reference metadata;
  configurable verse numbers, headings, footnotes and copyright.
- [Audio](https://api.esv.org/docs/passage-audio/): passage query redirects to MP3;
  no timing metadata or offline retention grant is documented there.
- [Conditions](https://api.esv.org/): local text storage is capped at 500 verses and
  half of any book; query/display limits also apply. Requests are limited to
  60/minute, 1,000/hour and 5,000/day. Noncommercial mobile use is permitted within
  the general conditions. Attribution and an ESV link are required; keys stay private.

The 30-day interval is the owner's refresh preference, not a Crossway license term.
It does not authorize a complete offline edition or permanent audio downloads.
Before persistent MP3 caching, record provider evidence covering this personal native
app, download scope, retention, refresh/deletion, attribution and revocation. Until
then offer online passage playback only, with no intentional persistent audio cache.
Inspect player and URLSession disk-cache behavior rather than assuming streaming is
storage-free. Do not contact Crossway on the owner's behalf without authorization.
Text and online playback can be implemented independently of the audio-download gate.

## Current source and affected boundaries

Inspected existing files (paths relative to repository):

- `Core/Scripture/LicensedTranslations.swift`: only NIV/NLT/NKJV; API.Bible-specific
  errors and 30-day access lease, including a provider-specific Debug exception.
- `Infrastructure/Scripture/OfflineTranslationLibrary.swift` and `APIBibleClient.swift`:
  encrypted edition generation/sync and API.Bible transport. Do not insert ESV into
  that approved full-edition list or reuse its authorization policy implicitly.
- `Features/Scripture/ReaderSession.swift`: repository selection, explicit sync,
  metadata refresh on resume, and reader access checks.
- `Features/Scripture/ScriptureVersionsView.swift`: current key entry and download UI
  are API.Bible-specific. ESV needs its own connection and bounded-cache controls.
- `AppShell/StudyAudioCoordinator.swift`: narration is currently a no-op contract.
- `Features/Music/MusicSession.swift`: music already pauses narration via that
  coordinator and owns Now Playing updates. Audit reciprocal takeover before adding audio.
- `SophiaScripturaTests/LicensedTranslationTests.swift`: API.Bible lease/regression tests.
- [TDD §8.2](../docs/tdd/tdd.md), [reader contract](../docs/data/scripture-reader-contract.md),
  [SP-002](SP-002-free-scripture-access.md), [SP-010](SP-010-licensed-offline-translations.md)
  and [development plan](../docs/development-plan/development-plan.md).

Proposed new ESV transport/cache types belong under existing Core/Scripture and
Infrastructure/Scripture; narration state/player under the Scripture feature and audio
infrastructure. These are proposed responsibilities, not files or APIs already implemented.
Views → reader/narration sessions → contracts → provider/cache/player adapters.

## Target behavior and decisions

1. **Explicit fetching.** Versions offers separate ESV Keychain credential entry,
   cache status and Clear Cache. Fetch a selected chapter/passage only through a visible
   Load/Download action; Play explicitly requests online audio. Navigation to uncached
   content shows a load action. Cold launch, resume and connectivity recovery never
   start downloads or sync. This explicit initial-load policy is a planning default.
2. **Bounded text.** Track canonical verse identities, counts by book and response
   revision; deduplicate overlaps. Validate query, response and resulting stored corpus
   before committing. Use bounded LRU eviction for replaceable cache entries; explain
   eviction in the download UI. Do not evict user-authored study data. Reject an
   over-limit request before networking, including short-book edge cases. Never silently
   show WEB text under an ESV label; offer an explicit switch to WEB.
3. **Thirty-day manual refresh.** Each committed passage has `fetchedAt`, `refreshDueAt`
   (30 × 24 hours later), revision and source reference. Before due: Available offline;
   at/after due: Refresh due, with Sync now. Existing bounded text remains readable;
   no API.Bible-style expiry lock is inferred. This soft due status is a planning default
   because the owner requested manual sync, not mandatory lockout. Early manual refresh
   is allowed. Refresh only retained passages; success resets only successful entries.
   Failure/cancellation preserves prior content and due state. No credential check,
   failed attempt, app launch or metadata-only refresh renews timestamps.
4. **Study integrity.** Stable ESV edition/reference identity is distinct from API.Bible.
   A changed text revision preserves references and quarantines/revalidates ink geometry
   rather than silently placing old ink onto changed text. Reading position, annotations,
   notes and collections survive cache clearing. Cache and credentials are excluded
   from Files backups. Reference-only Save/Ask is the initial ESV path: persistent
   verbatim quotations, AI transmission and unrestricted Copy/Share are gated until
   storage/redistribution accounting is implemented and reviewed. Count retained copies
   across all app stores; never bypass the cache budget through logs or derived indexes.
5. **Audio.** Passage/chapter play, pause, resume, stop, progress and clear offline/error
   states; display the actual loaded passage even if the reader navigates away. Do not
   promise timing alignment. Validate HTTPS redirect destinations; never forward the
   API token to the media host. Streaming failure preserves reader state. Manual refresh
   applies to audio files only if the permission gate enables downloads and its approved
   retention rules permit it; those rules override the proposed 30-day cadence.
6. **Shared audio ownership.** Starting narration pauses music and vice versa; never
   auto-resume either after takeover. One owner controls AVAudioSession, Now Playing
   and remote commands at a time. Cover interruptions, headphones and background behavior.
   Existing PiP currently models music/Activity: do not silently add narration to its
   command mapping. Preserve that mapping and prevent it from reclaiming audio ownership;
   broader narration PiP controls require separately selected scope.
7. **Failure and security.** Distinguish missing/invalid key, denied access, throttle,
   transport, malformed passage, unsupported mapping and storage failure. Honor Retry-After
   and enforce shared request budgets without infinite retries. Denial stops new network
   access; any verified revocation policy also governs retained material. Secrets, passage
   bodies and signed media URLs never enter logs. Clearing credentials stops active ESV
   requests/player access; cache deletion is a separate explicit action.

## Ordered implementation plan

- P0: Recheck provider terms, settle audio-download evidence and confirm soft refresh
  versus expiry lock. Inspect current reader composition, Keychain, backup, annotations,
  Now Playing and PiP owners; finalize quote accounting and short-book request rules.
- P1: Add ESV-specific identity, errors, bounded-cache policy, injected clock and mocked
  transport. Parse references and verse blocks from text without treating footnote numbers
  as verses or modifying Scripture wording. Validate poetry, headings and missing labels.
- P2: Implement secure token transport, throttling and atomic bounded cache. Include
  staging bytes and overlapping generations in storage accounting; do not temporarily
  retain an extra complete corpus during refresh. Use conservative in-place eviction
  or fail safely when atomic replacement cannot fit the approved budget.
- P3: Wire explicit load, ESV selection, status/last sync/refresh due, progress, retry and
  cache clearing into reader/Versions. Prevent stale async results after navigation/key
  changes. Refresh revisions through the annotation compatibility gate.
- P4: Replace narration stub with passage player, safe redirects and shared audio
  arbitration. Add permission-backed persistent downloads only after P0 evidence is recorded.
- P5: Complete focused tests, owner iPad walkthrough and documentation. Record actual
  evidence and unresolved gates here. Assign the exact v0.5 patch only during release planning.

## Acceptance and verification gates

- AC1: Valid ESV key loads a passage with correct verse anchors, unchanged wording,
  ESV attribution/link; invalid keys and malformed responses fail clearly.
- AC2: Cache remains within global/per-book limits after overlap, concurrent requests,
  replacement, restart, cancellation and failure. Test 499/500/501 verses and exact
  per-book thresholds, including one- and two-chapter books. No full-edition loop exists.
- AC3: Injected-clock checks at just before/exactly/after 30 days show the defined state;
  due text is readable offline. Relaunch/foreground/network recovery generate zero fetches.
- AC4: Explicit sync refreshes retained passages, preserves prior data on failure and
  cancellation, and changes only successful timestamps. Crash recovery does not exceed budget.
- AC5: Clearing cache and restoring a metadata backup preserve study artifacts;
  stored quotations cannot bypass policy. Revision changes cannot misplace existing ink.
- AC6: Online MP3 redirect/play/pause/resume/stop works; token does not leak on redirect.
  No persistent audio cache exists without recorded permission and retention tests.
- AC7: Narration/music takeover, interruptions and remote control ownership are tested;
  existing music, Activity and PiP behaviors regress correctly.
- AC8: Physical iPad verifies text offline/relaunch, explicit refresh, real audio, app
  switching, lock screen, interruption and accessible controls. Provider credentials
  stay local. Mock/simulator success does not close live-provider or hardware criteria.

Run focused ESV parser/cache/clock/transport/player tests plus existing licensed translation,
reader, annotation and music/system-control suites appropriate to integration changes.
Use current simulator/device commands from the test specification; record result paths,
counts and failures. No native tests are required for this planning-only change.

Documentation during implementation: TDD §8.2, Scripture content integration and reader
contract, audio ownership/design, backup exclusions, test specification/manual walkthrough,
provider setup and actual assigned release notes. Do not claim a working feature from this plan.

## Evidence and status

2026-10-10: official public documentation and current source inspected; ticket, indexes and
TDD planning pointer written. No authenticated API request, app change, build, native test,
installation or release performed. Permission for persistent audio and physical acceptance
remain open. Exact patch release and planning defaults can be refined before execution.
