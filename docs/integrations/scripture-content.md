# Scripture content feasibility — SP-002

Researched 2026-09-21. This is the content integration specification supporting
[TDD §8](../tdd/tdd.md#8-external-integrations), not an implemented provider client.
Requirements: REQ-002/003/005/014/019. All availability below concerns the documented
route, not purchases or downloads in another Bible app.

## Offline baseline

Select **World English Bible, American English, Protestant edition, `engwebp` (WEBP)**
for first-reader planning. The publisher describes it as Updated WEB without the
Deuterocanon/Apocrypha and dedicates its text to the public domain [S1]. This matches
the repository's existing 66-book scope; it does not decide which canons future
editions may support.

- Source format: USFM, linked as `engwebp_usfm.zip` on [S1]. Follow that publisher
  link at ingestion time; do not substitute `eng-web` Classic or `engwebu`.
- App edition key proposed: `web.engwebp`. Keep provider IDs separate from this key.
- Display credit chosen for Sophia: “World English Bible (WEB), American English,
  Protestant edition · eBible.org · Public domain.” Include a source link in About.
- Preserve the source wording. The publisher reserves the WEB name for unchanged
  text [S1]. Keep notes and generated explanations separate from Scripture.
- Bundle text without a subscription, account, expiry timer or runtime network dependency.
  Copy/export and on-device TTS are feasible; runtime AI context is feasible on the
  public-domain basis (engineering inference), subject to the later AI provider/privacy contract.

**Historical research snapshot (superseded by SP-009 evidence below):** this research pinned the edition and format, not immutable
bytes. S1 has mixed edition labels, including a “2020 stable” footer alongside Updated
metadata. Do not invent a release year. The future ingestion ticket must record archive
metadata and SHA-256 before accepting a snapshot. No full Bible was downloaded here.

## Provider comparison

“Conditional” means documentation supports a route, but Sophia's account, exact edition
license or capability has not been verified. Unknown permission means the feature stays
disabled, not that the publisher has necessarily prohibited it.

| Route | Price / setup | Text and offline rights | Attribution / quotation / export | AI / TTS / narration |
| --- | --- | --- | --- | --- |
| eBible WEBP | Free; no key | Complete offline text candidate; archive integrity pending | Preserve edition credit and source; public-domain text [S1] | See baseline above; recordings require their own evidence |
| YouVersion Platform | Free app key; app registration [S2] | NIV advertised; entitlement determined by app. SDK caching/download UI is not evidence of unrestricted bundling or a specific cache lifetime [S3] | Card/Reader views supply attribution; custom Text view must supply version metadata [S4]. Quote/export limits unresolved | Exact edition AI, TTS and audio grants unresolved |
| API.Bible | Starter $0, 5,000 calls/month, optional three copyrighted editions; Pro starts $29/month [S5] | Refresh cached content within 30 days [S6]; permanent bundled copyrighted text not established | Per-edition license and notices govern saved quotes and export [S7] | Copyrighted text prompt context prohibited by FAQ; public-domain prompt context allowed [S8]. Copyright text/audio format conversion restricted [S7] |
| Crossway ESV API | Free noncommercial; registered application/key [S9] | At most 500 stored verses or half a book, whichever is less; no full offline ESV | Per-page display limits, ESV attribution/link and redistribution limits apply [S9]; see below | Prompt/TTS permission unresolved. Passage MP3 endpoint exists [S10]; long-term audio storage unresolved |

Preferred editions: **NIV, NLT and NKJV are conditional** through API.Bible's advertised
catalog [S11], subject to actual Starter license selection and entitlement. NIV also has
an advertised YouVersion route [S2]. **ESV is conditional** through Crossway's own API;
API.Bible says ESV is not offered there [S8]. Account catalog access for NIV11, NLT and NKJV was verified on 2026-09-22 (see below). Their
unrestricted offline and full Save/Ask capabilities are not established.

API.Bible's July 2026 plan page supersedes the earlier project assumption that Starter
only exposes public-domain/CC editions. Older daily-rate documentation and catalog
wording conflict with newer monthly plans: use the current selected plan/dashboard when
integrating, not the old 5,000/day statement. Do not purchase Pro merely to investigate.

Crossway detail: request ceilings are 60/minute, 1,000/hour, 5,000/day. Its request rule
has exceptions for one/two-chapter books; do not transfer those exceptions to storage or
display rules. API redistribution has a 50% work limit [S9]; general publishing guidance
uses 25% and excludes commentary/reference works [S12]. Export/Share needs explicit
channel-specific handling; default to reference-only until resolved. Cache clearance is
encouraged, without a verified hard lifetime on S9. The old TDD assertion that API audio
is expressly stream-only was not substantiated by S10; Sophia should initially avoid
audio persistence as a conservative product policy, not misquote a publisher prohibition.

Biblica requires express AI permission [S13]; its AI policy is conditional on a license,
not a blanket authorization [S14]. Do not send NIV text through a different route to
evade the API.Bible restriction. Ask can retain a reference and let the owner explicitly
choose WEB context, visibly naming that edition; never silently swap the quotation.

## YouVersion verification boundary

Official Swift docs establish reader/card/text components, version selection, navigation
and attribution. They also describe sign-in suppression and version-download checks [S3].
They do **not** establish Sophia's exact offline, cache-duration, export, AI or narration
entitlements. The linked Platform Terms page [S15] returned an empty client-rendered
page in both the web reader and browser inspection. No terms were accepted or account
created. Before a YouVersion integration ticket: owner registers the app, reviews actual
terms, checks the entitled versions and preserves the applicable edition licenses. SDK
licensing does not itself license Bible content. Custom Pencil/layout hooks remain SP-003.

## Human narration

The WEBP-linked MP3 directory currently lists Mark and Ephesians chapter files, not a
complete matching audiobook [S16]. Do not infer narrator identity or recording rights
from the text license. Separately, eBible explicitly offers Michael Paul Johnson's WEB
recordings as public domain [S17]. This is a human-recorded candidate, not proof of
complete coverage or word-for-word alignment with the selected WEBP snapshot.

M7 must pin recording/reader, edition, chapter coverage, license, size and hashes, then
listen to samples and check correspondence. No synchronized highlighting without timing
data. TTS is an explicit optional fallback; it does not fulfill the owner's human-narration
preference. ESV MP3 availability likewise does not establish offline redistribution rights.

## Reproducible import acceptance plan (not executed)

1. Follow S1's USFM link over HTTPS. Save the unmodified archive in ignored build inputs.
   Record retrieval UTC, resolved URL, byte count, SHA-256, source metadata/credit and
   parser version in a manifest. A checksum pins bytes; it does not prove authenticity.
2. Reject unsafe ZIP paths, symlinks, duplicate entries, excessive expansion, invalid
   encoding and malformed structure. Separate front matter/license files from books.
3. Read USFM `id` markers, not filename positions. Require exactly the 66 distinct IDs
   in `shared/usfm-books.json` (39 OT + 27 NT). Report missing/extra books and stop;
   never silently discard books to force a match. Preserve introductions separately.
4. Parse chapters, verse labels/bridges, paragraphs, poetry, notes and cross-references
   structurally. Do not assume every integer exists, split verses by a regex alone, or
   use a universal verse total to manufacture absent text. SP-003/005 settle representation.
5. Validate unique source passage keys and source ordering; retain unusual labels and
   reference mappings in a reviewed exception report. Compare per-book/chapter counts
   and normalized body text against an independently exported publisher format of the
   same snapshot. Document differences rather than normalizing away meaningful content.
6. Inspect Genesis 1, Psalm 119, a Gospel with notes, a short epistle and Revelation 22;
   compare source/render/copy output for punctuation, Unicode, poetry and footnotes.
7. Build the local content artifact twice from identical inputs; compare deterministic
   content/index hashes, excluding declared build timestamps. Record output manifest,
   book/chapter inventory, parser diagnostics and source-to-output checks.
8. Install the validated artifact through a later M2 ticket. Test fresh cold launch in
   airplane mode, first/last passage navigation and search/reference bounds. Corrupted
   updates must preserve the last valid artifact and all user study records.

## Future capability and failure tests (not executed)

| ID | Required behavior | Owner |
| --- | --- | --- |
| CONTENT-01 | WEB opens without account/network; invalid artifact rejected atomically | M2 ingestion/reader |
| CONTENT-02 | Missing/combined verses yield explicit mapping/unavailable states, never fabricated text | SP-003/005 → M2 |
| CONTENT-03 | API.Bible cache past 30 days is unavailable until refreshed, including offline/clock rollback; user annotations remain | Provider ticket |
| CONTENT-04 | Denied/revoked key, 429 and failed refresh preserve edition identity and offer explicit WEB navigation | Provider ticket |
| CONTENT-05 | ESV limits cover cache + saved quotations + notes/chat copies + export staging; test below/at/above verse/book bounds and overlapping selections | SP-005 + provider ticket |
| CONTENT-06 | Required credit follows reader, copy/share and permitted exports; missing metadata fails safely | M2/provider ticket |
| CONTENT-07 | Ask blocks unauthorized text in initial prompts, summaries, follow-ups and retrieval; reference-only or explicit WEB choice remains possible | Companion ticket |
| CONTENT-08 | Expiry removes restricted replicas, not user ink/notes/reference IDs. Retained layout metadata must not conceal restricted text snapshots | SP-005 + annotation/provider ticket |
| CONTENT-09 | Exports exclude keys and restricted caches; permitted user data and WEB remain recoverable | SP-005 |
| CONTENT-10 | Audio reflects actual edition/coverage; missing chapters and absent timing metadata are explicit | M7 |

Capability checks belong at the provider/content boundary as well as in UI. Do not solve
quota failures by silently deleting user-authored notes: prevent prohibited text copies
from entering durable notes in the first place. Exact accounting and retained user
quotation permissions are integration gates, not completed contracts from this research.

## Dated primary sources

All inspected 2026-09-21; provider pages can change. Recheck at integration.

- S1: [eBible WEBP edition and rights](https://ebible.org/details.php?id=engwebp).
- S2: [YouVersion overview](https://developers.youversion.com/) and [Swift setup](https://developers.youversion.com/sdks/swift/quick-start).
- S3: [Swift components](https://developers.youversion.com/sdks/swift/components).
- S4: [Attribution](https://developers.youversion.com/sdks/swift/guides/copyright-and-attribution).
- S5: [API.Bible plans, updated July 22, 2026](https://care.api.bible/article/378-comparing-api-bible-plans).
- S6: [Cache policy](https://care.api.bible/article/401-caching-content).
- S7: [API.Bible terms](https://api.bible/terms-and-conditions).
- S8: [Express licensing and AI FAQ](https://care.api.bible/article/405-express-licensing-faqs).
- S9: [Crossway API conditions](https://api.esv.org/) and [key setup](https://api.esv.org/docs/).
- S10: [ESV passage audio endpoint](https://api.esv.org/docs/passage-audio/).
- S11: [API.Bible catalog overview](https://docs.api.bible/) and [availability guidance](https://care.api.bible/article/382-which-bible-versions-are-available).
- S12: [Crossway publishing permissions](https://www.crossway.org/permissions/).
- S13: [Biblica permissions](https://www.biblica.com/permissions/).
- S14: [Biblica publisher AI policy](https://www.biblica.com/publisher-ai-policy/).
- S15: [YouVersion Platform Terms entry point](https://platform.youversion.com/?tos=1) (body unavailable during inspection).
- S16: [WEBP audio directory](https://ebible.org/engwebp/mp3/) (HTML index inspected; no recordings downloaded).
- S17: [eBible narration rights and sources](https://ebible.org/webaudio/).

Research exit: complete for a free baseline and conditional-provider assessment.
Archive acquisition, API entitlement checks, authenticated requests, playback, parsing
and runtime tests remain unperformed. These do not block WEB-based renderer planning.

## SP-009 acquisition and implementation — 2026-09-22

The owner selected M2. Publisher-linked USFM and VPL archives were acquired, hashed and
compared. The importer now generates the bundled 66-book/1,189-chapter resource. The
manifest pins exact bytes and provenance; [reader evidence](../testing/sp009-reader-evidence.md)
records comparison projection rules, deterministic output and remaining device gates.
The research-stage “not acquired” statements above describe the earlier work only.
Optional provider entitlements remain unverified; none were enabled.

## Additional-version inquiry — 2026-09-22

Owner asked whether Sophia can acquire more than one version. One edition was the initial
SP-009 scope, not a permanent product restriction. Current publisher notices verify
[Berean Standard Bible public-domain use](https://berean.bible/terms.htm) and
[ASV public-domain use](https://ebible.org/eng-asv/copyright.htm). These are viable full-offline
source candidates; neither archive has been acquired or validated for Sophia in this review.
Multi-edition repository lookup, version switching and restoration require explicit
implementation after the owner chooses the next edition. No additional translation was installed.

[Crossway’s standard API](https://api.esv.org/) limits local ESV storage to 500 verses or
one-half of any book, whichever is less. [API.Bible Starter](https://care.api.bible/article/378-comparing-api-bible-plans)
advertises optional access to three copyrighted editions; Sophia’s exact entitlements remain
unverified, and [cache refresh requirements](https://care.api.bible/article/401-caching-content)
apply. This inquiry does not establish unrestricted offline rights for NIV/NLT/NKJV/ESV.

## Authenticated edition verification — 2026-09-22

Owner selected NIV, NLT and NKJV and authorized use of their supplied API key. The
correctly transcribed key returned HTTP 200 from the official `/v1/bibles` endpoint;
NIV metadata also returned HTTP 200 from its edition endpoint. No key is stored here.
The earlier screenshot-based check failed authentication. The first exact-abbreviation
filter missed NIV because the provider labels this edition NIV11; the full catalog and
direct metadata request resolved it. No Scripture-body request or full download occurred.

| Owner choice | Provider abbreviation | Verified Bible ID |
| --- | --- | --- |
| NIV (2011) | NIV11 | 78a9f6124f344018-01 |
| NLT | NLT | d6e14a625393b4da-01 |
| NKJV | NKJV | 63097d2a0a2f7db3-01 |

**Correction to earlier download recommendation:** the 30-day freshness requirement alone
does not authorize acquiring a complete Bible database. The current
[API.Bible terms](https://api.bible/terms-and-conditions), section 8, prohibit systematic
extraction to populate databases for internal or external use; section 11 separately
addresses conditional offline storage and freshness. Section 5 instructs developers to
resolve conflicting license conditions with the provider before use. Full-edition offline
acquisition therefore remains pending provider clarification or express permission, even
though catalog access is confirmed. Do not infer bulk-download rights from HTTP 200.

[Permission-request draft](api-bible-offline-request.md) describes the owner's one-user
native iPad use, periodic refresh proposal, and the planned Companion boundary. It has
not been sent. No app code, provider cache, content bundle or credential store was changed.

## SP-010 licensed offline approval and implementation — 2026-09-23

The owner subsequently supplied a provider reply authorizing complete offline storage for
the NIV11, NLT and NKJV Bible IDs above in this single-user iPad application. The owner
also supplied a later license update permitting unrestricted personal bulk Copy/Share and
text extraction. This is a record of owner-supplied correspondence, not an independently
verified provider record.

SP-010 keeps each downloaded chapter payload encrypted with AES-GCM before it reaches the
app's protected Core Data SQLite store. The API credential, encryption key, revocation
flag and monotonic last-seen time are device-only Keychain entries. A manifest is published
only after every canonical chapter is parsed and stored; partial generations stay staged
and resume later. Each edition receives a 30-day lease from an authenticated server date.
Expiry, a revoked token, or a clock rollback locks the licensed reader while preserving
user reading state and the bundled WEB edition. No licensed text is bundled in the source
tree, included in diagnostics, or exported by a database feature.

### Development-period exception — 2026-09-29

The owner supplied written API.Bible authorization specifically naming Sophia Scriptura,
NIV11, NLT and NKJV. The authorization permits encrypted local retention beyond the normal
30-day refresh period during development, testing, debugging and application rebuilds. It
does not authorize unrestricted permanent caching or distribution after development ends.

The implementation therefore selects `OfflineContentPolicy.developmentException` only in
Debug builds. It still rejects clock rollback, revoked access, missing manifests, invalid
encrypted storage and unauthorized editions. Release and Archive builds retain
`OfflineContentPolicy.standard` and the normal 30-day refresh boundary. Copyright notices,
attribution, access security and redistribution restrictions remain active in every build.

The physical download remains owner-operated: enter the API key in Sophia’s Versions
screen, then choose Sync all three now while the iPad remains connected. Sync is manual
only: launch, resume and near-expiry status checks do not contact the provider. This is
necessary because encrypted payloads are tied to a device-only key and the credential is
never written into the app source or build settings.

### Cached access recovery — 2026-09-29

Debug builds honor the owner-supplied development authorization for existing encrypted
NIV11, NLT and NKJV copies even when an earlier denied sync set the legacy shared
access-block flag. Failed API requests still fail; they do not invalidate these separately
authorized development copies. The flag is retained and enforced by the standard policy
in Release/Archive. Missing or invalid encrypted content and clock rollback still block
access. Opening cached translations does not start a sync or download.
