# v1.0.0 translation implementation guide — SP-033–038

Status: proposed implementation contract, 2026-10-10. D1–D3 are owner-decided; edition verification remains open. This guide refines the draft tickets; it does not describe implemented behavior. If a ticket conflicts with this guide, resolve the discrepancy before execution; owner answers take precedence. Existing reader/annotation contracts remain binding.

## 1. Owner decision register and readiness

| Decision | Question | Recommendation, not approval | Blocks |
| --- | --- | --- | --- |
| D1 — decided 2026-10-10 | Which AO editions should v1.0.0 offer? | Owner selected KJV (`eng_kjv`), BSB (`BSB`), ASV (`eng_asv`), LSV (`eng_lsv`) and WEBU (`eng_webu`). | SP-035 eligibility signoff, SP-038 real-edition acceptance |
| D2 — decided 2026-10-10 | What happens when an update changes text with existing ink? | Owner chose: keep annotated revision active; explicitly switch to update. Preserve old source revision and ink. | SP-036 activation/retention, SP-037 revision UI, SP-038 update acceptance |
| D3 — decided 2026-10-10 | What coverage is supported at v1.0.0? | Owner revised scope: four selected complete 66-book editions plus WEBU with its complete 81-entry inventory. Verify mapping for every supported entry; no other partial/extended-canon/RTL expansion is authorized. | SP-035 coverage filter/parser scope, SP-037 availability labels |

Owner answers above are authoritative. D1 is now a fixed five-edition selection, subject to source rights and content validation. Selection does not authorize app implementation. The owner selected WEBU with Apocrypha/Deuterocanonical books for v1.0.0. Section 10 defines this bounded expansion. Other partial/extended-canon editions and RTL rendering remain outside scope.

Independent work: SP-034 contracts/legacy compatibility can be selected before D1 is settled, but no owner-pending activation or coverage behavior may be inferred. No implementation ticket is selected by this planning request. Draft → ready requires named inputs, fixture inventory, resolved relevant decisions and review of current source. Ready → in_progress requires owner selection.

## 2. Source evidence and exact change map

Read these exact files again at implementation time; paths below are relative to `application/SophiaScriptura/SophiaScriptura/` unless otherwise stated.

| Current file | Observed issue / required bounded change | Ticket |
| --- | --- | --- |
| `Core/Scripture/ScriptureModels.swift` | Chapter reference ID and isLicensed derive from API prefix; otherwise WEB. Add explicit compatible identity; stop using prefix as authorization. | SP-034 |
| `Core/Scripture/LicensedTranslations.swift` | TranslationLibrary/TranslationStatus expose API-specific credentials and lease. Keep API library internally; introduce source-neutral library boundary. | SP-034 |
| `Infrastructure/Scripture/OfflineTranslationLibrary.swift` | API-only encrypted generations, lease and shared revocation flag. Wrap; do not broaden approved editions or reuse flag for AO. | SP-034 |
| `Infrastructure/Scripture/BundledScriptureRepository.swift` | Strict WEBP manifest/schema and immutable bundle. Preserve resource verification and identity. | SP-034 |
| `Features/Scripture/ReaderSession.swift` | Startup routes only API prefix; authorizeQuote returns other text unrestricted; repository lookup assumes existing sources. Resolve source explicitly and authorize each operation. | SP-034/037 |
| `Features/Scripture/ReaderTextSurface.swift` | Native copy/share/drag bypass authorization for non-API content. Make native actions capability-driven, including late async action validation. | SP-034/037 |
| `Features/Scripture/Annotations/AnnotationSurface.swift` | Drag gating uses isLicensed. Apply same operation policy as ordinary reader. | SP-034/037 |
| `Features/Scripture/ScriptureView.swift` | Save/Share/Ask/context expansion invoke quote authorization. Pass explicit operation and retain correct provenance. | SP-037 |
| `Core/Scripture/ChapterTextMap.swift` | Selection excludes labels/headings/notes and uses UTF-16. Extend optional metadata without changing legacy selection output. | SP-035 |
| `Features/Scripture/ReaderTextSurface.swift` and `Features/Scripture/Annotations/AnnotationRenderer.swift` | Existing heading/note/poetry rendering; no structured words-of-Jesus field. Both surfaces must consume the same normalized semantics. | SP-035 |
| `Core/Annotations/AnnotationModels.swift` | Source includes edition/revision/reference system. Preserve identity; do not rewrite groups during content update. | SP-034/036 |
| `Features/Scripture/Annotations/AnnotationSession.swift` | Finds all chapter layers across revisions, picks exact source if possible, checks layout. Revision choices must not activate mismatched layers. | SP-036/037 |
| `Features/Scripture/ScriptureVersionsView.swift` | API-specific rows, Sync all three, attribution links. Replace with source-aware view models/actions. | SP-037 |

Also audit app composition, `Core/Activity/MeditationJourney.swift`, Companion/Sophy passage resolvers, Notes/Collections quote persistence, and Files archives before editing their call sites. These callers are impact-review targets, not permission to redesign those features. Current source—not aspirational legacy documentation—is implementation truth.

## 3. Proposed domain and adapter contracts

Keep types in existing Core/Scripture and Infrastructure/Scripture folders. Names are proposed; responsibilities and invariants are required. Do not expose networking or platform stores to views.

- `TranslationSourceID`: closed supported source registry with unknown persisted strings retained as unavailable. Initial registered values: bundled-web, api-bible, helloao. Optional ESV adapter only if SP-032 has actually landed.
- `TranslationDescriptor`: appEditionID, sourceID, exact providerEditionID, referenceSystemID, name/abbreviation, language/direction, coverage, provenance and rightsPolicyID. New fields decode additively; do not alter existing ScriptureEdition IDs.
- `TranslationCoverage`: declared ordered books and actual chapter numbers/verse inventories, completeness category and excluded/unsupported material. A total count alone cannot establish mapping. Do not assert all traditions use one canon.
- `TranslationRightsPolicy`: reviewed evidence URL/date/notice/digest and separate decisions for install, offlineRead, copy, share, drag, saveQuote, aiContext and textExport. Each decision is allowed/denied/needsReview with explanation and any budget/attribution requirements. Reference-only Save/Ask does not transmit hidden text.
- `TranslationInstallStatus`: installed revision, active revision, staging operation, last successful update, last attempted/error and available retained revisions. Credential/lease status is a source-specific projection, not a universal expiry field.
- `TranslationSourceAdapter`: local descriptors/status, open installed repository by edition and optional exact revision, explicit catalog refresh where supported, explicit download/update command, cancellation, policy authorization and source-scoped credentials when supported. Use capability discovery rather than empty credential methods for bundled/AO sources.
- `TranslationLibraryCoordinator`: dispatch by registered source/edition; local status aggregation isolates source errors; one source's unavailable store does not discard other statuses. It does not weaken any adapter's permission checks.
- `ScriptureOperationRequest`: operation, selected edition/revision/reference identity, canonical ranges, exact quote body and current generation token. Authorization returns permitted text + mandatory attribution/provenance, or a typed denial. Validate the selection again after await, before pasteboard/export/AI effects. Missing policy fails closed for text operations.

`ScriptureContentRepository` remains an immutable read boundary. Add exact-revision opening in the library, not hidden downloads in chapter(). Runtime reading must never depend on refreshing the remote catalog.

### Identity and persistence compatibility

Preserve `web.engwebp` / `org.sophia.web.engwebp` and existing `api.bible.<id>` / `org.sophia.api.bible.<id>` byte-for-byte. New AO app IDs: `helloao.<exact catalog ID>`; reference IDs: `org.sophia.helloao.<exact catalog ID>`. Case is significant. Different sources remain distinct even when text is identical; cross-edition passage alignment is an explicit resolver operation, never reference-ID aliasing.

Add an optional persisted explicitReferenceSystemID to ChapterDocument with a custom decoder/validated accessor: missing field maps only known legacy WEBP or validated legacy API IDs; unknown IDs lacking explicit identity are rejected. Validate any supplied explicit value against the edition descriptor. Existing schema-1 chapter fixtures keep their old identity and text. Audit constructing call sites and body/selection helpers; do not leave a second prefix-derived fallback.

New AO generation payloads use a new supported schema version and never overwrite bundled/API payloads. New optional ScriptureBlock metadata must preserve old fields and old decode defaults. Older builds must ignore source-specific AO files and fail safely on new selected editions without resetting reader/study data. Bidirectional compatibility is tested, not presumed; if an older app would corrupt new state, document the downgrade boundary and preserve a pre-upgrade recovery export before release. No automatic destructive migration.

Compatibility fixtures: unmodified WEBP chapter/snapshot; each existing API edition chapter/manifest; annotations with group layout only and layer-owned layout; Notes/Collections quote with old metadata; unknown AO selection; future schema; explicit identity mismatch. Fixtures must be copied non-production data and contain no keys/private owner content.

## 4. AO normalization contract

Use the standard AO JSON schema, not prose regex. DTO validation checks exact translation/book/chapter identity and semantic structures before normalization. Fail an edition with unsupported semantics rather than omit Scripture content.

| AO structure | Normalized representation | Selection/anchor rule |
| --- | --- | --- |
| heading / inline heading | heading block at source position | No body verse anchor/text |
| verse.number | label block, positive unique integer with body mapping | Preserve source number; missing numbers remain missing |
| plain string | body run, exact source text | Exact UTF-16 selection |
| formatted text | body run with optional poetryLevel and wordsOfJesus metadata | Same text/anchors; metadata cannot change quote wording |
| line_break / inline lineBreak | break block preserving order | Body selection uses established separator rule |
| Hebrew subtitle | heading/subtitle metadata, original content pieces | Never invent verse 0 |
| footnote reference | note block with chapter-local sourceNoteID/caller and resolved text | Marker and note excluded from body quotes |

Optional normalized block fields: sourceNoteID, sourceCaller, sourceKind, poetryLevel, wordsOfJesus. Preserve original content piece boundaries in deterministic IDs. Existing q1/q2 rendering may remain for legacy documents; AO indent levels must not be silently collapsed. Add support in both regular and annotation renderers. Preserve wordsOfJesus metadata losslessly; a new user-facing red-letter toggle is outside this release unless separately selected. Required footnote presentation uses the existing tappable note UI, retaining source caller in its detail/accessibility label.

Duplicate verse numbers, dangling/duplicate note IDs, invalid poem levels, empty structural payloads, out-of-range numbers and response identity mismatch fail parsing. Numeric verse omissions are valid when declared/observed. Unknown harmless extra JSON metadata may be ignored; unknown content union variants are rejected. Keep payload snapshots of unsupported public examples for later tests, without enabling them automatically.

Canonical revision = SHA-256 over a versioned canonical serialization of ordered normalized content and reference mapping, excluding fetch timestamps, transport order of object keys, audio URLs and unrelated metadata. Include parser-schema version. Serialize integer/string/optional fields deterministically and specify Unicode handling: preserve source Unicode, do not normalize wording to make hashes match. Separate metadataDigest covers attribution/rights changes; those changes trigger rights review without pretending content changed. Local digest proves byte consistency, not publisher authenticity. Provider sha256 is supplemental until its calculation is verified.

## 5. AO local store and transaction rules

Proposed root: Application Support/ScriptureSources/HelloAO. Paths use generated UUID storage keys; never concatenate raw remote IDs into paths. A manifest maps exact edition identity to storage key. AO text follows reviewed rights, platform file protection and backup exclusion; API encrypted store remains untouched.

- `library.json`: versioned root manifest containing immutable generation descriptors, active revision pointers and previous-good root pointer/checksum.
- `editions/<storageUUID>/generations/<generationUUID>/manifest.json`: identity, parser schema, ordered book/chapter coverage, per-chapter digests/byte counts, contentRevision, metadataDigest, rightsPolicyID/evidence snapshot, created/fetched timestamps.
- `.../chapters/<generatedChapterUUID>.json`: validated normalized chapter; manifest supplies book/chapter lookup.
- `staging/<operationUUID>/journal.json`: source identity, metadata fingerprint, parser version, operation epoch, expected chapter inventory and durably verified completed chapter files.

All writes and promotions serialized by actor. Journal completion is written only after chapter file write/close/hash verification. Resume rechecks completed files and expected inventory; invalid files are re-fetched only after explicit Resume. Recovery at launch is local-only: valid active root, otherwise previous-good root, otherwise visible unavailable state; no network and no wipe.

Promotion: validate all declared chapters → compute content revision → publish immutable generation → write/validate next root → atomically replace root pointer → notify reader. Keep previous-good pointer and referenced generations. Cross-store annotation durability is not one atomic transaction: pin old source generation before activation, flush pending ink through prepareForNavigation(), then switch only if flush succeeds. An activation failure leaves previous active revision. Reader/export sessions hold generation leases; cleanup cannot remove leased or annotation-pinned revisions. There is no claim of power-loss durability solely from rename.

D2 is settled: keep an annotated revision active; a validated update becomes installedReady, not active, until explicit owner switching. Keep old annotation-pinned revisions available in revision choices. Never prune annotation-pinned revisions automatically. Promotion to installed and activation for reading are separate operations. Because existing contentRevision is edition-wide, any retained annotation group with live or recoverable deleted ink pins that entire AO edition generation; do not infer per-chapter compatibility or activate a new edition revision automatically. For an edition with no annotation pins, a user-triggered Update may activate its validated replacement after navigation flush. Explicit revision switching is an edition-wide action; show affected chapter count and retain old generation. New layers belong only to the chosen revision. Empty metadata-only layers do not pin text; inspect actual drawing content using existing validated PKDrawing decoding. Unreadable drawing metadata conservatively pins until reviewed. Annotated source revisions must remain available according to reviewed retention rights; if rights prohibit retention, disable activation and explain the conflict for owner review rather than silently deleting ink or text. Manual Delete Download can remove all replaceable text only after an explicit warning that existing ink may become unrenderable; annotations remain intact. No new ink-to-text migration tool is included.

For unannotated/unleased content, retain active and one previous-good generation; garbage-collect older unreferenced generations only after a subsequent validated commit. Annotation pins include recoverable deleted layers until their actual permanent deletion; never inspect only currently visible layer. At startup, reconcile pins from annotation metadata locally before cleanup. If reconciliation fails, suspend cleanup.

## 6. Download operation state machine and engineering bounds

These are proposed engineering defaults, testable and adjustable only with recorded measurement/reason in SP-036. They do not represent provider rate limits or owner product decisions.

| State | Entry / permitted action | Exit and invariant |
| --- | --- | --- |
| notInstalled | eligible edition, Download | checking; no readable staged edition |
| checking | policy, disk, manifest and network preflight | downloading or failed; never alter active pointer |
| downloading | at most 2 chapter requests in flight | validating, paused or failed; progress counts verified chapters |
| paused | Cancel, backgrounding or termination | explicit Resume only; keep journal and old active copy |
| validating | complete declared inventory staged | installedReady or failed; no partial activation |
| installedReady | complete immutable generation committed | D2 activation choice; installed and active may differ |
| installed | active valid generation | explicit update/check/delete; reading uses local repository |
| failed | typed stage/error with previous status | explicit retry/resume; no automatic loop |
| deleting | epoch invalidated, requests cancelled, leases checked | notInstalled or retained/pinned warning; never delete study files |

Progress: completed verified chapters / expected selected inventory, plus phase label; no fake percentage from network bytes when Content-Length is absent. Backgrounding requests pause cooperatively; no background download session. A current response may finish staging, but cannot promote or renew source policy after operation invalidation. App termination leaves resumable journal.

Bounds: catalog 8 MiB, books manifest 2 MiB, chapter wire and decoded payload 8 MiB each; cap as data arrives, not after whole-body allocation. Complete.json is not used initially. Request timeout 30 seconds; resource timeout 120 seconds. At most 2 retries for transient transport/408/429/5xx per request, with injectable jittered delays based on 1 and 3 seconds. Retry-After takes precedence; if above 60 seconds, pause visibly for explicit later Resume rather than silently ignore it. No retries for permanent 4xx, schema/identity/hash/rights failures. Redirects must remain HTTPS on bible.helloao.org; cross-origin redirects are rejected. No credentials/cookies attached.

Per-edition operation storage budget: 256 MiB of validated staged normalized payloads; preflight reserve at least 512 MiB free in addition to retained bytes, then recheck before each write. Unknown expected size is shown as unknown, not zero. If bounds exclude an otherwise eligible edition, mark it unsupported by current limits, preserve existing copy and open a measured engineering follow-up; do not silently increase budgets. Validate these budgets on selected real editions before readiness for release. Avoid whole-edition Data or in-memory chapter arrays; stream/process bounded chapter batches.

Deletion/cancellation invalidates operation epoch before awaiting cancellation; every result validates epoch and source/edition/revision before journal/pointer mutations. One active AO install/update at a time; different-edition taps show busy with active edition. Catalog refresh is independently cancellable; registry blocks refresh from replacing metadata used by an in-flight operation. API adapter scheduling/policy is unchanged.

## 7. Versions and reading screen behavior

Versions opens from local cached metadata only. Installed tab lists bundled, available/locked API editions and installed AO editions; Browse lists last-known AO catalog and explicit Refresh Catalog. First empty catalog shows explanation + Refresh Catalog, no spinner until user acts. Search/filter uses local metadata, with source filter and language search. Catalog refresh failure preserves cached catalog and shows last successful refresh date.

Rows show exact name/abbreviation, source, language, coverage and status. Rights pending/unsupported rows are discoverable but Download disabled with reason. Installed AO row offers Read, Update, Delete Download; pending/staging row offers Cancel/Resume/retry. API rows preserve Download/Sync/key/lease states; bundled row says Included offline and has no delete/sync. Attribution panel follows selected row/source; do not show API.Bible links as attribution for AO.

Download is explicit per edition; no AO Download All. Existing API action stays labelled Sync API.Bible's three approved editions, preserving its bounded scope. Check for Updates may fetch manifest and chapter hashes/content where upstream lacks version metadata; show that it can use network/data. It never downloads another edition or activates changed content. Consolidate Check/Update if upstream offers no cheap revision probe; UI must describe actual requests.

Selection of an installed edition waits for annotation flush, resolves target location and validates rights locally. Use a known explicit mapping table to cross reference systems; matching book/chapter/verse integers alone do not prove mapping. If no compatible mapping exists, show Choose passage in selected edition, keep old view/location until choice; do not silently select nearest verse across editions. Within the same edition, legacy restore-by-nearest-verse behavior remains with its existing notice. D3 controls eligible inventory, not permission to invent reference mappings.

Uninstalled or locked saved edition on launch keeps original saved identity, offers retry/source controls and explicit Open bundled WEB. No automatic WEB fallback or provider call. Delete active AO download routes through navigation flush and a visible unavailable screen; owner can choose another installed edition. Reader state is not rewritten merely by deletion.

Every copy/share/drag/saveQuote/aiContext path, including native text-menu actions and annotation surface, checks policy and current selection epoch. Reference-only fallback labels exactly what will be saved/sent; never hide quote transmission in a reference-only action. Existing stored quotations retain their original text and provenance during content updates, and future use follows applicable policy rather than replacing them with new wording.

The owner-approved D2 revision controls must identify current text revision in human terms (download/update date and short revision), affected annotated chapters and available old layers. UI never offers to move old ink automatically. New-layer creation always records exact active revision and measured layout. Read Hidden can show current text, but showing an older layer must reproduce its exact source/layout or show unavailable state.

## 8. Verification matrix and evidence rules

IDs below supplement ticket acceptance criteria. Unit tests use fake clocks, bounded transport fixtures, isolated directories and failure hooks. Live calls are opt-in and separate. Native suites named are existing suites, not proof of passing tests.

| ID | Owner ticket | Required check | Pass evidence / release consequence |
| --- | --- | --- | --- |
| TR-01 | 034 | WEBP and all three legacy API identities/snapshots round-trip | XCTest fixtures; corruption/misidentity blocks release |
| TR-02 | 034 | Unknown source and mismatched explicit identity fail without writes | XCTest store comparison; blocks |
| TR-03 | 034/037 | Native Copy/Share/drag + Save/AI cannot bypass source policy | Unit and UI tests with denied/pending policy; blocks |
| TR-04 | 035 | Prose/poetry/subtitle/footnote/words-of-Jesus/Unicode fidelity in both reader surfaces | Fixture exact text/metadata and visual inspection; loss blocks |
| TR-05 | 035 | D1 editions have dated rights/coverage/mapping evidence | Reviewed manifest and URLs; unreviewed editions disabled |
| TR-06 | 035 | Partial/extra-book/RTL/unknown structure follows D3 support boundary | Fixture eligibility/parser tests; false support blocks |
| TR-07 | 036 | First download, cancel and explicit resume; progress verified only | XCTest journal and request counts; blocks |
| TR-08 | 036 | Termination before/after each commit boundary, disk full, corrupted journal | Recovery fixtures retain old or new complete generation; blocks |
| TR-09 | 036 | Epoch validation defeats stale results after delete/cancel/update | Controlled race tests; resurrection blocks |
| TR-10 | 036 | Bounded payloads/retry/concurrency/disk checks hold | Instrumented transport/store tests and actual iPad measurements; blocks on overrun |
| TR-11 | 036/037 | D2 update activation, old ink revision access and cleanup pins | Automated source/layout checks + iPad ink walkthrough; misplaced/lost ink blocks |
| TR-12 | 034/037 | Zero network on launch/resume/navigation/Versions/connectivity recovery | Spy transport tests and device observation; blocks |
| TR-13 | 037 | WEBP/API/AO switching and relaunch preserve exact labels/positions; unmapped location prompts | UI tests + owner iPad checks; substitution blocks |
| TR-14 | 036/038 | Delete/download/backup restore retain notes/collections/ink/provenance | Fixture comparisons + copied-data restore; data loss blocks |
| TR-15 | 034/038 | API Release lease/Debug exception/revocation/rollback/encryption unchanged | LicensedTranslationTests + applicable reader tests; rights regression blocks |
| TR-16 | 038 | Real eligible AO editions offline after cold relaunch; API approved cached editions still work | Owner iPad and authorized provider evidence separately recorded; gate open until observed |
| TR-17 | 037/038 | VoiceOver/Dynamic Type/long names/action reachability | Physical manual record; explicit owner waiver needed if deferred |
| TR-18 | 038 | Candidate version/build, recovery refs, tag/release/final checkout match exact tested commit | Release record in selected release execution; mismatch blocks publication |

Run existing ScriptureReaderTests, LicensedTranslationTests, AnnotationTests, ScriptureAppearanceTests and affected ScriptureHubTests/Companion/Sophy/Collections tests based on actual changed callers; add focused AO parser/store/source-policy suites. Run full native suite at SP-038 release snapshot, not repeatedly for planning-only edits. Use current test specification for simulator command and result paths. No tests touch owner data or need committed credentials.

Each ticket's completion record must list criterion → TR ID → exact test/manual result → fixture/device/provider → commit/result bundle → gaps. Use Not Run, Failed, Passed, Owner Reported or Waived distinctly. A screenshot/build/install is not live-provider/offline/Pencil acceptance. Stop release for unverified selected editions, unknown enabled-edition rights, data loss, text loss, source substitution or unverified annotation revision behavior.

## 9. Documentation, execution and residual unknowns

SP-034 maintains reader contract/TDD actual type definitions and compatibility fixtures. SP-035 maintains content integration/rights manifest and schema mapping. SP-036 maintains data/recovery and manual download guide. SP-037 maintains screen specification/policy UI. SP-038 maintains acceptance evidence, deployment and actual release notes. This proposed guide is updated to the implemented contract as each selected ticket lands; never mark proposed behavior implemented without source/test evidence.

External evidence still required: per-edition terms and notices, actual payload size/format for selected candidates, upstream revision/hash semantics and upstream snapshot consistency. These are research/engineering verification gaps, not decisions for the owner to guess. D2/D3 are owner-approved; D1 selects KJV, BSB, ASV, LSV and WEBU, subject to verification. If research exposes additional choices (for example incompatible verse mapping in a chosen edition), present that concrete question before expanding scope.

Official references checked in preceding planning pass: [AO catalog](https://bible.helloao.org/api/available_translations.json), [translation reference](https://bible.helloao.org/docs/reference/translations/), [standard format](https://bible.helloao.org/docs/reference/translations/standard.html). Revalidate at implementation time; no API.Bible credentialed request or new content-rights approval was performed in this refinement.

## Selected-edition verification follow-up — 2026-10-10

D1 selects KJV, BSB, ASV, LSV and WEBU. Every selected edition is required in SP-038 real-provider/offline acceptance. AO LSV reports 31,104 verses while the publisher reports 31,102; identify exact differences and resolve mapping before signoff. Apply LSV CC BY-SA terms with recorded attribution/export policy. WEBU is selected with all additional entries; D3 is revised accordingly. Other extended-canon editions remain outside scope.

## 10. WEBU bounded canon expansion — owner selected 2026-10-10

The owner selects World English Bible Updated (`eng_webu`) for v1.0.0. Keep bundled `web.engwebp` immutable and separate; WEBU app ID `helloao.eng_webu`, reference system `org.sophia.helloao.eng_webu`. This is additive planning, not implementation authorization.

### Inventory and policy

Observed live AO manifest: 81 entries, comprising the established 66 plus TOB (Tobit), JDT (Judith), ESG (Greek Esther), WIS (Wisdom of Solomon), SIR (Sirach), BAR (Baruch), 1MA/2MA/3MA/4MA (Maccabees), 1ES/2ES (Esdras), MAN (Prayer of Manasses), PS2 (Psalm 151) and DAG (Greek Daniel). Revalidate the exact manifest and every declared chapter at implementation; source order and chapter numbers are authoritative. These 15 entries are provider packaging, not an assertion of a universal Catholic/Orthodox canon.

Extend the reviewed eligibility manifest with WEBU-specific inventory and rights evidence. The publisher states public-domain text; retain exact attribution/trademark notice. Do not generalize eligibility to any other extra-canon edition. Stop on inventory/schema/mapping changes; do not silently truncate or accept unexpected books.

### Ownership and implementation sequence

SP-034: make book/testament/order values extensible; retain stable USFM codes, edition-specific book order and reference identities. Remove assumptions that every source book exists in bundled WEBP. Legacy importer's 66-book assertion remains valid for that artifact; it must not become AO's universal validator.

SP-035: validate WEBU's full book manifest, source chapter inventory and exact content. Preserve ESG and DAG as distinct source books; do not merge them into EST/DAN. Preserve PS2 chapter/verse numbering as supplied; do not invent PSA.151 aliases. Missing cross-edition mapping returns unavailable, never guessed or nearest canonical book. Preserve any Letter of Jeremiah/addition packaging as supplied within source chapters; no invented separate book.

SP-036: use full 81-entry expected inventory for staging, chapter progress, coverage digests, revision generation and atomic promotion. All declared content must validate before installed status. Rights/storage/download limits still apply; update and annotation pin rules are unchanged.

SP-037: book picker presents Old Testament, Apocrypha/Deuterocanonical and New Testament sections using explicit descriptor membership, preserving provider-relative order within sections. This grouping is a UI organization, not a theological equivalence statement. Show WEBU additional-book coverage in Versions. Navigation includes every displayed section/book without routing via the bundled repository's book list. Greek Esther/Daniel labels remain distinct. Cross-source switching from a WEBU-only book offers Choose passage in the destination edition, keeping old position until explicit selection.

Save/Copy/Share/Ask/Chapter Hub/Sophy, notes/collections and restore must accept the explicit WEBU book/reference identity and display its real source name. Check validators that currently allow only the shared 66-book code list. WEBU content uses its own annotation source/revision/layout; no reuse of WEBP ink even on identical text. Backup/restore must retain new codes without converting them to conventional 66-book counterparts. Existing Activity/meditation defaults remain unchanged; manually selected WEBU passage resolution must either work or show explicit unavailable state without substituting text.

SP-038: acceptance includes representative extra books, source-only navigation and backup/restore in addition to all five selected editions. A build that downloads only WEBU's 66 base books fails release acceptance.

### Additional acceptance cases

| ID | Tickets | Required evidence |
| --- | --- | --- |
| TR-19 | 034/035/036 | Exact 81-entry inventory, every declared chapter validated, full progress denominator; unexpected/missing/duplicate entry fails safely. |
| TR-20 | 035/037 | ESG vs EST, DAG vs DAN and PS2 retain distinct source numbering; source-only book switching cannot substitute or invent mappings. |
| TR-21 | 034/037/038 | Tobit/Wisdom/Greek Daniel/Psalm 151 round-trip references through Save/Hub/Ask/annotation/backup and restore; old 66-book fixtures still pass. |
| TR-22 | 036/037/038 | Physical iPad reads representative WEBU additional books offline/relaunch, navigates all groups, preserves ink and explicitly handles unavailable passages in other editions. |

Record publisher/source evidence separately from content integrity. [WEBU publisher notice](https://ebible.org/Scriptures/details.php?id=engwebu), [AO book manifest](https://bible.helloao.org/api/eng_webu/books.json). No additional owner product decision is needed for this bounded selected edition; newly discovered incompatibilities must be reported before proposing a scope reduction.

## API.Bible selection correction — owner reported 2026-10-10

Target API.Bible selection is NASB, NLT and NKJV; NASB replaces NIV. The inspected checkout still lists NIV in LicensedTranslations.swift, so this is an owner-reported selection change, not verified runtime implementation. Owner confirmed NASB 1995. Its exact API.Bible provider ID and edition-specific rights remain to be verified through authorized provider metadata. Do not guess an ID or simply rename the NIV entry. Keep legacy NIV reference IDs, notes, saved quotations and annotations intact and source-unavailable where appropriate; never relabel NIV text or ink as NASB. NASB gets its own edition/reference identity and verified policy/attribution. The historical Debug exception specifically named NIV11/NLT/NKJV and must not automatically extend to NASB. Verify NASB offline rights/lease and any development authorization before enabling its cache. No credentials or owner data are changed by this planning correction.

SP-034 owns distinct NASB identity and legacy NIV compatibility; SP-037 owns API selection/attribution; SP-038 must test NASB/NLT/NKJV plus legacy NIV artifact preservation. NASB 1995 provider ID and rights verification are readiness inputs for those NASB-specific steps. Existing historical three-edition tests remain legacy regression evidence, not proof of NASB support.

## v1.0.0 audio planning expansion — 2026-10-10

[SP-039](../../tickets/SP-039-v100-scripture-audio-and-verse-highlighting.md) adds a Scripture player, transport controls and verified verse-synchronized highlighting. BSB is the initial candidate, not a claim of complete audio coverage. Recording-specific rights, exact text/audio/timing binding, shared music/system ownership and AU-01–09 are required. A1–A3 approved: ±15-second/chapter controls, Continuous/Follow initially off, streaming and optional manual chapter/book downloads. Prior AO-audio exclusions are superseded for this bounded feature; word-level highlighting and unverified edition audio are excluded. Implementation remains unselected.
