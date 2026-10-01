# Collections Library and Detail Specification

Status: design proposal for owner review. SP-007 implements a bounded in-memory UI slice;
production persistence, cross-feature routing and recovery remain unimplemented. Collections
organize existing study artifacts without copying or taking ownership of the notes, passages
or conversations they reference.

Related documents: [App shell specification](app-shell-specification.md),
[Notes screen specification](notes-screen-specification.md),
[Scripture screen specification](scripture-screen-specification.md),
[UX specification](ux-specification.md), [product specification](../product-specification/product-specification.md),
and [SP-005 data contracts](../../tickets/SP-005-data-and-quality-contracts.md).

## Owner decisions carried forward

- Collections are owner-created topic folders.
- Nested folders are supported.
- One artifact can belong to several collections without being duplicated.
- Collections may contain notes, conversations, saved Scripture, passage references and
  external links.
- Curated topical indexes are optional future content and are not required for the local
  Collections experience.
- The bottom tab and shared overlay/state rules come from the [App Shell specification](app-shell-specification.md).

## The organizing principle

A collection is a **membership view**, not a second copy of an artifact. A Note, saved
verse, conversation or link keeps one stable identity and can have zero, one or many
collection memberships. Removing a membership does not delete the original item. Opening
an item from a collection always routes to the owning feature so it remains editable in
its proper context.

```text
Collection: Assurance
  ├── Collection: Romans
  ├── Note: Romans 8 study ----------------┐
  ├── Saved verse: Romans 8:1               │ one source item
  ├── Conversation: Why no condemnation?   │ may appear in other collections
  └── Link: Historical context article -----┘
```

## Collections library

The Collections tab opens to a quiet folder library rather than a dense file manager.

```text
┌───────────────────────────────────────────────────────────────────────┐
│ Collections                                      [⌕] [Sort] [＋] │
├───────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐    │
│  │ Assurance        │  │ Romans           │  │ Prayer            │    │
│  │ 8 items · 2 child│  │ 14 items         │  │ Empty             │    │
│  │ oxblood folder   │  │ sage folder      │  │ Create first item │    │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘    │
│                                                                       │
│ Scripture  Collections  Notes  Companion  Activity  Settings           │
└───────────────────────────────────────────────────────────────────────┘
```

### Library behavior

The root library uses **Collections** as a quiet leading header in the active appearance
preset's heading font. Minimal symbol-only Search,
Sort and Add controls sit at the trailing edge. Tapping Search replaces its symbol with a
compact inline field and focuses it; closing the field clears the query and restores the
symbol. Every symbol retains a 44-point target and an explicit accessibility label. There
are no decorative button capsules or duplicated navigation titles.

- **New Folder** creates a collection with an editable name and optional description.
  It opens the new collection so the owner can add the first item immediately.
- **Cards** show name, direct-item count, child-folder count, owner-selected color and
  one of the collection editor's consistent filled-symbol icons. The existing filled
  folder remains the default. The count must distinguish direct items from descendants.
- Long-pressing a collection card or child-folder tile exposes **Edit Collection** and
  **Delete Collection**. No Folder exposes only its allowed color edit.
- **Search** searches collection names, descriptions, tags and indexed item titles/references
  available locally. Results identify whether the match is a folder or an artifact.
- **Sort** supports Name, Recently modified and Item count. Name sorting is locale-aware;
  date sorting uses the collection’s last membership or metadata change.
- **Unfiled** shows artifacts eligible for membership that currently belong to no collection.
  It is a query, not a hidden collection and not a second copy of the artifacts.
- **Recent** shows recently opened collections and does not silently reorder the owner’s
  chosen library sort.
- A future list view may be added for accessibility and dense browsing; the initial design
  uses folder cards with a clear row fallback rather than a separate content model.

### Library states

The library must cover first use, populated folders, no folders, search-empty, unfiled
items, loading, offline and recoverable-error states. First use offers **Create a topic**
and explains that an item can live in several topics. An empty folder offers **Add study
material** and **Create child folder**.

## Collection detail

```text
┌───────────────────────────────────────────────────────────────────────┐
│ ‹ Collections     Assurance                         [···] [Add +]     │
│ Grace, confidence and the security of salvation       8 items · 2 child│
│ [All] [Scripture] [Notes] [Conversations] [Links]  [Sort]             │
├───────────────────────────────────────────────────────────────────────┤
│ Child folders                                                           │
│  [Romans]  [Promises]                                                   │
│                                                                       │
│ Study material                                                          │
│  ◈ Romans 8:1  Saved verse · NIV                         [···]          │
│  ▤ Romans 8 study  Note · modified today                 [···]          │
│  ◌ Why no condemnation?  Conversation · 3 messages        [···]          │
│  ↗ Historical context  Link                               [···]          │
└───────────────────────────────────────────────────────────────────────┘
```

The header contains breadcrumb navigation, an editable title, optional description, direct-item count,
child-folder count and More actions. Child folders are visible before artifacts so the
hierarchy remains understandable. The item area supports type filters and a stable sort.
Tapping the title opens the same collection editor used by **Edit Collection** so name,
description and color changes follow one validation and persistence path.

### Direct items and descendants

The default detail view shows items directly assigned to the current collection and lists
child folders separately. A deliberate **Include child folders** toggle can add descendant
items to the view, with a small source-folder label. This avoids duplicate-looking results
and makes membership boundaries clear. The toggle state is local to the current view and
does not mutate membership.

## Adding and removing items

Items can enter a collection from three routes:

1. **Save flow:** after saving a Scripture selection as Bookmark, Gleaning or Note Quote,
   the owner may select one or more collections.
2. **Add from collection:** Add opens a searchable picker grouped by Scripture, Notes,
   Conversations and Links. Selecting an existing item creates membership only.
3. **Context action:** a verse hub, Note library, Note canvas or Companion conversation can
   use Add to Collection without leaving its current task.

The picker shows checked membership for the current item and supports Create New Collection
without losing the pending selection. Adding an item already present is idempotent and gives
quiet feedback rather than creating duplicate rows.

Removal language must distinguish the operations:

| Action | Meaning | Result |
| --- | --- | --- |
| Remove from this collection | Remove one membership edge | Original artifact and other memberships remain |
| Move to another collection | Add destination membership, then remove this membership after confirmation | Artifact remains one source item |
| Delete artifact | Delete the source item through its owning feature | All collection memberships become invalid and are cleaned up according to the data contract |
| Delete collection | Remove the folder and its membership edges | Artifacts remain safe; child folders are promoted to the former parent/root unless a future archive rule is approved |

The initial design never treats deleting a folder as deleting its contents. Destructive
artifact deletion is performed from the owning feature and names affected memberships.

## Nested folders

Collections may contain child collections. The initial hierarchy is intentionally simple:

- one parent per collection;
- no cycles and no nested collection groups;
- drag/reorder is optional; More → Move provides an accessible fallback;
- moving a folder validates that the destination is not itself or a descendant;
- child items are not automatically copied when a folder moves;
- the parent view shows child-folder counts and the detail view shows breadcrumbs.

These constraints keep the hierarchy understandable and make export/restore validation
tractable. Multiple collection membership applies to artifacts, not to collection folders.

## Artifact presentation

Every row/card identifies its source type and opens the owning screen:

| Artifact | Display | Open action |
| --- | --- | --- |
| Saved Scripture/bookmark/gleaning | Reference, edition, short quote and save type | Scripture opens the verse hub or passage focus |
| Note | Title, modified date, tags and preview | Notes opens the canvas at the last safe viewport |
| Conversation | Title, preset/context label, modified date | Companion opens the conversation and restores follow-up context |
| Link | Editable title, domain and URL status | System/browser route after explicit action; unavailable metadata remains readable |
| Passage reference | Book/chapter/range and edition | Scripture opens the canonical location |

The collection does not edit artifact content inline. Quick actions are membership actions,
pin/open and source-specific More actions routed to the owning feature.

## Verse hub integration

When a verse hub lists collections, it shows direct membership names and a count for any
additional descendant context only when the owner enables that view. Tapping a collection
opens its detail page with the verse or artifact highlighted. Removing membership from the
hub uses the same Remove from this collection language as the Collections tab.

Saved bookmarks and gleanings show their direct collection folder names below the passage
reference. A gleaning's insight does not replace this placement label; unfiled items show no
folder label. The hub also supports authorized Copy and Share actions, with a short-lived
success message after Copy. **Add Link** validates an http/https URL, anchors the link to the
current verse/edition, and initially leaves it in No Folder. Existing links without verse
metadata remain valid collection items but do not appear as verse-attached links.

The hub and collection detail query the same membership records. They must not maintain
separate bookmark lists that can drift apart.

## Persistence and recovery boundary

The collection data contract needs stable identifiers for collections, artifacts and
membership edges. A membership record should capture collection ID, artifact ID, artifact
kind, creation date, optional order and schema version. The artifact remains authoritative
for its content and deletion state.

Recovery rules:

- interrupted membership writes do not remove the source artifact;
- duplicate membership requests converge on one edge;
- deleting an artifact removes or marks its membership edges in one recoverable transaction;
- importing a collection whose artifact is missing preserves a visible missing-target row;
- exporting collections includes hierarchy and membership records but excludes provider
  secrets and restricted Scripture/audio payloads;
- failed import leaves the existing library unchanged and reports the first actionable error.

The exact storage technology and migration format remain SP-005 decisions. This screen
specification defines behavior and ownership, not a SwiftData schema.

## Accessibility and premium quality gates

- VoiceOver announces collection name, hierarchy position, direct/descendant counts and
  available actions.
- The owner can create, rename, move, filter, add and remove memberships without drag
  gestures or color recognition.
- Child-folder and artifact order is deterministic and remains understandable in list mode.
- Dynamic Type keeps names, counts and destructive-action labels readable; truncation has a
  full accessible value.
- Empty, offline, missing-target and failed-import states explain what remains available.
- Reduce Motion removes ornamental folder transitions while preserving focus and hierarchy.
- Light/dark appearance, landscape/portrait, keyboard, pointer and long names receive QA.

## Proposed ownership map

```text
Features/Collections/
  Presentation/
    CollectionsLibraryScreen.swift
    CollectionsLibraryModel.swift
    CollectionDetailScreen.swift
    CollectionPicker.swift
    CollectionItemRow.swift
  Domain/
    Collection.swift
    CollectionMembership.swift
    CollectionQuery.swift
  Application/
    CreateCollection.swift
    AddArtifactToCollection.swift
    RemoveArtifactFromCollection.swift
    MoveCollection.swift
  Infrastructure/
    CollectionRepository.swift
```

These are proposed boundaries, not files to create immediately. Collection views invoke
application operations and shared queries; they do not mutate Note, Scripture or Companion
stores directly.

## Acceptance scenarios for design review

1. Create an Assurance collection, add a child Romans collection, and navigate through
   breadcrumbs without losing the parent context.
2. Add the same saved verse to Assurance and Prayer. Both collections show it, but opening
   either item reaches the same source artifact.
3. Remove the verse from Assurance. Prayer and the source verse remain unchanged.
4. Delete the Assurance folder. Its artifacts remain available, and child collections are
   promoted according to the approved policy.
5. Open a collection from a verse hub. The collection highlights the originating item and
   back navigation returns to the verse context.
6. Use Add from a collection to find a Note, Conversation and Link; each opens in its
   owning feature and remains editable there.
7. Toggle Include child folders. Descendant results appear with source-folder labels and
   no duplicate rows.
8. Search and sort by name, recent change and item count. Results remain stable after
   switching cards/list presentation or rotating the iPad.
9. Import a collection with a missing artifact and a damaged archive. Existing collections
   remain intact; the missing target is visible and the failed import is explained.
10. Use VoiceOver, larger text, keyboard and reduced motion to create a folder and manage
    membership without drag-only or color-only controls.

## Open decisions before implementation

- Exact folder card preview density beyond the implemented color and filled-symbol choices.
- Whether the initial library needs a list toggle or only an accessible row fallback.
- Child-folder deletion policy confirmation: promote children to the former parent/root.
- Whether parent views should default to direct items only or remember Include child folders.
- Ordering rules for artifacts within a collection and whether manual ordering is needed.
- Which artifact kinds ship in the first Collections slice before Companion exists.
- Export format and treatment of restricted Scripture/audio references in SP-005.
