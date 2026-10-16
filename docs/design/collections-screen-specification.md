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
  **Delete Collection**. No Folder exposes only its allowed color edit. The open
  collection (…) menu includes **Protect Collection** when the folder has no lock, and **Lock
  Collection** plus **Remove Collection Protection** when it is unlocked. A locked folder’s
  long-press offers **Unlock Collection** only. No Folder does not. A note filed in a locked
  collection, or in any subfolder beneath it at any depth, stays out of the Notes library
  until that collection is unlocked.
- **Search** searches collection names, descriptions, tags and indexed item titles/references
  available locally. Results identify whether the match is a folder or an artifact.
- **Sort** supports Name, Recently modified and Item count. Name sorting is locale-aware;
  date sorting uses the collection’s last membership or metadata change.
- **Subfolder arrange** is separate from the library sort. **Smart Order** recognizes
  patterns in folder names. Bible books and testaments follow reading order, including
  common names such as “Psalm” and “I Samuel”. Other names use number-aware order, so
  “Chapter 2” stays before “Chapter 10”. Automatic applies Smart Order when the parent is
  Bible or a testament, when at least half of the children are recognized books, or when
  a name contains a number. Otherwise folders stay in name order. The Arrange menu can
  force Smart Order, Name, or Recently modified. A loaded edition’s book order wins over
  the built-in 66-book sequence when a folder name matches that edition. Folders that are
  not books stay after the books.
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
3. **Context action:** a verse hub, Note library, an open note’s (…) menu, or a Companion
   conversation can use Add to Collection without leaving its current task. In that chooser,
   a collection with subfolders shows a downward chevron. Tapping it hides those subfolders;
   tapping the sideways chevron shows them again. The collection itself stays selectable.

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

## Folder reparenting — SP-040

Root cards and subfolder tiles support dragging onto another folder. Drop feedback
marks the hovered destination; the store revalidates the move on drop. Contents and
subfolders move with their folder. Move Collection in its context menu exposes the
full tree and Collections (top level), supporting cross-branch moves by tap or drag.
No Folder, self/descendants, unchanged parent, inactive records and locked sources or
destinations are rejected. Existing parentID persistence and protection bindings are
preserved; destination ancestry determines inherited protection after moving.

## Owner folder material layouts — 2026-10-13

Each folder’s Study Material View menu offers List View and Card View, including
No Folder and nested folders. The choice is remembered per folder in local UI
preferences. List records are uniformly 80pt high; card records uniformly 176pt
high in a shared adaptive 220–320pt grid. All artifact types use the same geometry
within each mode; long titles/previews truncate instead of increasing record size.
Context menus, access guards, filters, sorting, descendants and opening remain.
List swipe actions remain; card organization uses the same long-press menu.
No collection or note storage migration or other tab layout change.

## Shared note card presentation — 2026-10-13

Notes and Collection card mode now render the same NoteLibraryCard: note-selected
accent/top rule, note-kind glyph, title/type, creation and modification dates,
Page opening text/Published mark, Journal states, and Prayer stamps. The shared
stamp sequence runs on card appearance and active-tab entry, cancels while hidden
and respects Reduce Motion. Hosts retain their own selection, context actions and
navigation. Fixed 176pt size and Collection list mode remain. Locked notes conceal
previews and stamps in both hosts. No persistence or protection-policy changes.

Trashed-folder memberships do not count as filing for No Folder display or note
opening; inaccessible ancestry remains concealed. Delete Conversation moves the
authoritative Companion record to Trash, preventing projection resurrection.

## SP-044 record action consistency

Long press retains the complete action menu. Collection material lists and cards no longer
show a permanent ellipsis; swipe left reveals More/Delete where eligible. Notes
cards/lists gain the same swipe rail; Prayer updates reveal Edit/Delete. Rightward
swipe closes actions; no full-swipe commit. Existing confirmations and access
guards apply. Notes multiselect disables swipe. Accessibility Show/Hide actions
and Reduce Motion handling provide alternatives to gestures/settling animation.

SP-044 follow-up: only one record rail is open at a time. Swipe right on the record
body, tap its shifted body, or start vertical finger scrolling to close it. Opening
another record rail or switching tabs also dismisses it. Collection cards retain
the hold menu without a permanent ellipsis. Drag onset/settling are shortened;
record commands and confirmations remain unchanged.

The Subfolders heading presents Arrange as a plain icon/text menu with no border or
capsule; New Subfolder retains the outlined button style. Each unlocked subfolder
preview includes its existing item total and active direct child-folder count, e.g.
`4 items · 2 subfolders`; deeper folder generations are excluded from that folder
count. Locked previews continue to conceal both counts.

SP-045: Duplicate Collection in root/subfolder hold menus and detail actions opens
an Include contents modal. Structure always copies; enabled contents reuse item IDs
as chosen by the owner, so editing an item affects both folders. Names/colors/icons,
descriptions and protection bindings are retained; new folder IDs distinguish copies.
Confirmed deleted annotation layers are omitted from library projection. Unavailable
references retain a confirmed Remove Annotation Reference action (swipe Delete);
cleanup removes only references/memberships, never underlying ink.

## v1.3.0 — Points to Ponder and conversions

Add Study Material includes New Point to Ponder in folders and No Folder. The question
card shows Close, Delete and Explore. Explore opens a separate choice modal for Send
Question to Companion or Turn into a Note. New note opens with the editable question
title. Bookmark cards offer Turn into a Gleaning; gleanings offer Turn into a Note,
with `Gleaning from "Book Chapter:Verse (Translation)"` as the initial title and the
reference, passage and insight as content. Sources stay saved; cancellation creates
nothing. New items inherit accessible folder memberships. Points support the material
filter and recoverable deletion in Settings → Trash → Points to Ponder.
See [SP-046](../../tickets/SP-046-points-to-ponder-and-study-conversions.md).

## SP-046 owner follow-up — 2026-10-15

The shared save/folder chooser now includes only active Collections. Trashed and
archived folders are excluded, including branches under archived ancestors; active
children promoted by folder deletion remain available. Restoring/unarchiving makes
eligible destinations available again. Existing saved membership edges are retained.
Bookmark cards show See the whole chapter first and Turn into a Gleaning below it,
with matching full-width dimensions. Turn into a Gleaning uses a transparent,
outlined secondary style; See the whole chapter retains its accent fill.

Gleaning card follow-up: **Turn into a Note** sits below **See the whole chapter**,
using the same transparent outlined full-width style and height as the bookmark's
**Turn into a Gleaning** action. Conversion/title/content behavior is retained.

Post-v1.3.0 Point to Ponder card correction: Delete uses a filled red destructive
button with the same full-width dimensions as Explore. The question modal fits its
content vertically with 24-point outer margins and a compact Close header; content
can scroll when constrained. Existing confirmation and Trash behavior remains.

## SP-047 link editing and material drag/drop

Open a saved Link → Edit, or hold the material / swipe More → Edit Link. Title and
URL edits save in place; Cancel retains the original. Invalid web URLs show an error.
Drag directly listed material onto a subfolder tile to move it from the current
folder into that child; other assignments remain. The same drop support exists on
folder tiles. Locked/stale/inactive routes reject the operation. Aggregate rows from
Include Subfolders require opening their owning folder before dragging.

Owner header polish (2026-10-16): collection-detail Arrange, New Subfolder, Study
Material View and Add controls show icons only, with descriptive accessibility
labels retained and 44-point targets. Menu actions and creation behavior are unchanged.
