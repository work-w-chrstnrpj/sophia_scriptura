# Scripture reader data and recovery contract

Status: accepted planning contract for the first M2 product ticket, 2026-09-22.
This is the completed reader-only slice of SP-005. It does not define Notes,
Collections, Companion, Activity, annotation-file persistence, or full backup archives.

Related sources: [content feasibility](../integrations/scripture-content.md),
[rendering decision](../design/scripture-rendering-decision.md), and
[Scripture screen specification](../design/scripture-screen-specification.md).

## 1. Ownership and dependency direction

```text
Scripture views and reader state
            ↓
Reader use cases and domain models
            ↓
ScriptureContentRepository      ReaderStateRepository
            ↓                              ↓
read-only bundled SQLite        local SwiftData metadata
```

- UI never imports SQLite or reads bundle files directly.
- The renderer receives an immutable `ChapterDocument`; it never fetches content,
  persists preferences, or knows provider policy.
- Scripture content is replaceable source material. Reading progress/preferences are
  user data and survive content replacement or failure.
- Provider caches, when added, implement the same repository contract but remain
  physically and policy-wise separate from the bundled WEB artifact.
- No runtime backend is introduced. The importer is local build tooling only.

The first implementation stays in one application target. Create meaningful folders and
protocols, without separate packages or empty abstraction layers.

## 2. Stable identity

### Edition and revision

- `EditionID`: stable application key, initially `web.engwebp`. Provider IDs are metadata,
  never primary keys used by study artifacts.
- `ContentRevisionID`: lowercase SHA-256 of the canonical generated content payload.
  It identifies exact source text and structure, not an app release number.
- `ReferenceSystemID`: identifies verse numbering/mapping. Initial value:
  `org.sophia.web.engwebp`. “Canonical” means stable within this named reference system,
  not that all Bible editions share identical numbering.

### Passage identifiers

`VerseID` contains `referenceSystemID`, three-letter USFM `book`, positive `chapter`, and
positive integer `verse`. Its interchange display may be `ROM.8.1`, while persisted data
also carries the reference-system ID. Never parse display text as the database key.

`PassageRange` is an inclusive ordered `start` and `end` in the same reference system.
Book ordering comes from the validated artifact, not lexical string comparison. The
domain supports cross-chapter and cross-book ranges; the first reader’s drag selection
may remain chapter-local. Invalid/reversed ranges are rejected.

Source labels such as `3-4`, suffixes, or omitted verses are not forced into invented
text. `SourcePassageMapping` records the exact source label and zero, one, or several
canonical `VerseID` values. A bridge can map to multiple anchors; a missing verse has no
text mapping and produces an explicit unavailable result.

`PassageRange` overlap is interval intersection after resolving both endpoints through
the same reference-system order:

```text
candidate.start <= query.end AND query.start <= candidate.end
```

Hub and collection queries must use this rule, not string equality or quotation text.

### Content and reading location

- `ChapterID`: `EditionID + book + chapter`.
- `BlockID`: deterministic within a `ContentRevisionID`; it identifies a paragraph,
  poetry line, heading, or other structured block. It is not expected to survive a
  changed content revision.
- `ReadingLocation`: edition, content revision, nearest `VerseID`, optional block ID and
  UTF-16 offset within the block. Verse is the recovery anchor; block/offset only refines
  scroll restoration. Persisting a page number or pixel offset as the sole position is
  forbidden because pagination changes.

Selection results retain exact selected body text, edition/revision, source mappings,
and ordered canonical ranges. Verse numbers, headings, attribution, and footnote UI are
excluded from copied body text unless explicitly selected as content. UTF-16 offsets are
used at the UIKit boundary; domain tests include combining characters and emoji.

## 3. Immutable Scripture artifact

The first reader bundles two generated resources:

- `web-engwebp.sqlite`: read-only Scripture content.
- `web-engwebp.manifest.json`: provenance, schema and integrity metadata.

The manifest includes artifact schema version, edition/reference-system IDs, source and
retrieval URLs, retrieval UTC, unmodified source archive SHA-256/byte count, generator
version, generated database SHA-256/byte count, content revision, book-set digest,
license/attribution text, and generation UTC. Generation UTC is excluded from deterministic
content hashes.

SQLite uses `application_id` plus `user_version`. Schema v1 contains:

- `edition`: identity, name, abbreviation, language, translation type, source,
  reference system, content revision, attribution, capability-policy metadata.
- `book`: edition, USFM code, source code, canonical order, title, testament, chapter count.
- `chapter`: edition/book/chapter, ordered structured `ChapterDocument` payload,
  payload digest, and source label inventory.
- `passage_index`: source label and canonical anchor(s) to chapter/block/UTF-16 ranges.

`ChapterDocument` is a versioned Codable payload of ordered blocks and attributed runs.
Runs distinguish body text, source verse label, heading, paragraph/poetry boundaries,
footnote/cross-reference content, and canonical mappings. The renderer constructs visible
verse-number UI from structured labels; it does not use regex matching against prose.

The importer follows the SP-002 acceptance plan: safe ZIP handling, exactly 66 distinct
USFM IDs (39 OT, 27 NT), structural USFM parsing, exception reports, independent-format
comparison, deterministic builds, and representative manual inspection. Generated output
is accepted only when importer tests and manifest validation pass.

At runtime, open the bundled database read-only. Validate compatible schema,
manifest/database identity, edition, book inventory, and declared content revision before
serving a chapter. Code signing protects normal bundle resources; tests inject missing,
corrupt, truncated, mismatched, and future-schema fixtures. Never “repair” a bad resource
by modifying the application bundle.

## 4. Repository contracts and errors

`ScriptureContentRepository` provides async, Sendable operations for:

- listing available editions and their capabilities/attribution;
- listing ordered books and valid chapters;
- loading one immutable `ChapterDocument`;
- resolving a `VerseID` or `PassageRange` to source mappings;
- finding the nearest available mapped location without changing editions;
- reporting artifact identity and health.

The initial SQLite adapter is isolated behind an actor and uses read-only prepared
statements. It must not expose SQL rows to views. Cache decoded chapters by immutable
`ChapterID + ContentRevisionID`, with bounded memory and explicit invalidation when the
repository instance changes.

Typed failures distinguish at least: artifact missing, incompatible schema, integrity or
identity mismatch, edition unavailable, book/chapter unavailable, passage unmapped, and
decode/query failure. User messages are calm and actionable; diagnostic logs contain IDs
and error categories, never provider credentials or private study data.

No failure silently switches translations. With only WEB installed, failure shows the
offline-reader recovery screen and retry/reinstall guidance. Later provider failures may
offer WEB at the same mapped reference only through an explicit user action.

## 5. Reader progress and preferences

Persist reader metadata through `ReaderStateRepository`, with SwiftData hidden behind the
adapter. Domain/UI code depends on Codable/Sendable values, not `@Model` types.

`ReaderProgress` has a stable singleton/profile key, `ReadingLocation`, and `updatedAt`.
Save after explicit navigation, when a stable visible verse changes (debounced), and on
scene background. A failed save leaves reading usable for the session and displays one
nonblocking “Reading position not saved” notice; it never deletes the existing record.

On launch:

1. Validate the saved edition and reference system.
2. If its exact revision exists, restore block/offset then verse.
3. If revision changed, ignore stale block/offset and resolve the saved verse.
4. If the verse is absent, use the nearest mapped verse in the same chapter, then the
   chapter start. Record that recovery occurred.
5. If the edition is unavailable, show that state. Do not silently rewrite progress to WEB.
6. With no saved record, open WEB at Genesis 1.

`ReaderPreferences` v1 stores preferred edition, curated Scripture typeface ID, bounded
text-size step and light/dark/system theme. The legacy controlsExpanded field is retained
for decoding existing state, but the compact passage/Version row is always visible.
Unknown enum values and out-of-range sizes use documented defaults without destroying the
stored record. Annotation/margin/layout preferences enter the schema in M3, not as fake M2
fields. Settings writes are immediate and transactional.

SwiftData schema v1 is local-only with no CloudKit. Container-open or migration failure
must never trigger automatic deletion/recreation. The reader can operate session-only with
an explicit persistence warning while leaving the store untouched for recovery.

## 6. Updates, deletion and recovery

- App updates may replace the bundled artifact. Validate the replacement before use and
  resolve saved locations by verse anchor. User data is never cascaded from content rows.
- Removing a future provider cache removes only replaceable text/cache metadata. Passage
  references, progress, notes, ink, and collection membership remain, showing source
  unavailable until the same edition/revision can be restored.
- M2 has no user-facing delete operation for WEB. Reinstalling the signed app restores its
  bundled content but must not be described as a user-data backup strategy.
- The eventual Files export includes reader progress/preferences and edition/revision
  references. It excludes bundled Scripture bytes, provider caches, secrets, transient
  decoded layouts, and page screenshots. Import validates before replacing good user data.
- Page-layout manifests and Pencil drawings join backup/recovery in M3. M2 must not create
  hidden layout snapshots that accidentally become a content archive.

## 7. M2 test fixtures and acceptance cases

Use dependency injection; tests never modify the bundled database or normal SwiftData
store. Fixtures include Genesis 1, Psalm 119, a poetry block, repeated text, a missing
verse, a `3-4` bridge, footnotes, combining characters, emoji, RTL text, one short book,
and a future-schema manifest.

| ID | Automated or device evidence required |
| --- | --- |
| READER-DATA-01 | Import identical source twice; content/database digests match after excluding declared timestamps. |
| READER-DATA-02 | Reject unsafe ZIP entries, duplicate/missing/extra books, malformed USFM, mismatched hashes and unsupported schemas. |
| READER-DATA-03 | Load all 66 books and their first/last chapters; passage index resolves source mappings without invented verses. |
| READER-DATA-04 | Overlap queries handle verse/chapter/cross-chapter ranges, bridge/missing mappings and repeated text. |
| READER-DATA-05 | Exact and partial selection preserve correct UTF-16 body ranges across adjacent verses and beyond one viewport (continuous-reader owner revision). |
| READER-DATA-06 | Progress survives relaunch; revision change falls back by verse; invalid block/offset and missing verse recover explicitly. |
| READER-DATA-07 | Font/theme/text size persist; invalid values fall back without corrupting the record. |
| READER-DATA-08 | Missing/corrupt content shows a recoverable error while intact reader state remains unchanged. |
| READER-DATA-09 | Persistence failure leaves the previous record intact and the reader usable; no automatic store reset. |
| READER-DATA-10 | Cold physical-iPad launch in airplane mode opens WEB, navigates first/last passages, selects/copies/shares text, backgrounds and restores position. |
| READER-DATA-11 | VoiceOver reads book/chapter/verse/text in order; larger type uses reading layout without inaccessible controls. |
| READER-DATA-12 | No runtime network request, credential lookup, provider SDK, restricted text, or personal study-data log occurs in the WEB-only journey. |

Retain result bundles under ignored `build/` and summarize them in the implementation
ticket. Importer/unit/UI/device evidence are distinct; no single build proves them all.

## 8. Delivery decision

This contract unblocks the first M2 vertical slice. SP-009 is the ready product ticket.
It absorbs SP-008 LAYOUT-01–03 into the real reader instead of requiring another disposable
reader prototype. SP-008 remains the focused pre-M3 validation for Pencil geometry and
gesture cases LAYOUT-04–09; its selection cases stay as traceability, not duplicate work.

Full SP-005 remains in progress. Notes/ink/media, Collections membership, complete Files
export/import, recovery reminders, and later feature schemas require their own selected
slices before those features persist irreplaceable user content.

## SP-009 implementation status — 2026-09-22

Domain contracts, validated read-only SQLite access, structured UTF-16 selection mapping,
SwiftData reader state and restoration are implemented. The artifact stores each book and
edition as a versioned JSON payload inside the v1 tables; chapter payloads have individual
hashes. The source-label inventory is retained as typed label blocks; the passage index
contains canonical body mappings and UTF-16 ranges. See [implementation evidence](../testing/sp009-reader-evidence.md)
for checks and gaps. This does not mark every acceptance case passed.

### Appearance preference compatibility — 2026-09-29

`ReaderPreferences.appearancePreset` is an optional stable string identifier. Missing
values decode successfully for existing schema-1 snapshots and render the OldPaper
palette with the previously saved reading typeface. Selecting a preset persists its
identifier and applies its paired fonts. Unknown identifiers display OldPaper without
invalidating or overwriting the rest of the saved state. No content-store migration is
required. Typography reflow uses the last observed verse/block offset; later annotated
layout changes remain subject to the M3 geometry-preservation contract.

### Reading position startup ordering — owner correction, 2026-10-20

ReaderSession hydrates its existing ReaderSnapshot once before any save, navigation
or preference update. Shell and lifecycle callbacks may save before the asynchronous
reader startup; those saves must preserve the saved book/chapter rather than publish
an initial empty snapshot. Successful navigation still commits immediately, and viewport
updates retain the existing debounce. Failed state decoding remains session-only and
does not overwrite the original store. The persisted format is unchanged.
