# App Shell and Cross-Screen Specification

Status: design proposal for owner review; implementation is not authorized by this
document. This specification defines the shared frame around Scripture, Collections,
Notes, Companion, Activity and Settings so individual screen designs feel like one
premium study workspace.

Related documents: [UX specification](ux-specification.md),
[Scripture screen specification](scripture-screen-specification.md),
[product specification](../product-specification/product-specification.md),
[TDD](../tdd/tdd.md), and [development plan](../development-plan/development-plan.md).

## Design intent

Sophia should feel like one quiet study desk rather than six unrelated utilities. The
reader, notes, conversations and activity records are different views of the same local
study practice. The shell keeps the current place visible, protects unfinished work, and
makes cross-screen movement reversible.

OldPaper is the owner-selected shared UI direction: book-like typography, generous spacing,
quiet floating controls, and clear hierarchy. Its base palette is black, white and neutral
gray. The seven Scripture appearance presets provide optional color-and-type pairings;
they change appearance roles, not feature structure or behavior. Palette and font assignments
are recorded in the [Scripture screen specification](scripture-screen-specification.md#owner-selected-oldpaper-design-and-presets--2026-09-29).
Use platform materials sparingly for navigation and transient controls. Keep reading content
legible and calm; avoid paper-grain decoration and dense dashboard chrome.

## Root layout

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ optional screen-specific context bar                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                         active tab content                              │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│ [audio mini-player when active]                                         │
├─────────────────────────────────────────────────────────────────────────┤
│ Scripture  Collections  Notes  Companion  Activity  Settings             │
└─────────────────────────────────────────────────────────────────────────┘
```

The primary tab bar is always at the bottom, as the owner requested. It is the stable
place for the six top-level destinations and does not move to the top when the device
rotates. The active tab uses label, icon, tint and a shape/selection treatment so color
is not the only cue.

The shell owns the safe-area relationship between content, the optional audio mini-player
and the tab bar. A screen must receive the available content region rather than guessing
its own bottom inset.

## Top-level destinations

| Tab | Shell responsibility | Screen-specific responsibility |
| --- | --- | --- |
| Scripture | Preserve reader location and annotation state when leaving and returning | Passage reading, verse hub, selection actions, layers, comparison and audio source |
| Collections | Preserve selected folder and navigation path | Browse nested topics and open shared study artifacts |
| Notes | Preserve library filter and selected note | Browse notes and open the expandable canvas editor |
| Companion | Preserve conversation list position and draft context | Start/follow conversations, apply presets, inspect sources and handle provider states |
| Activity | Preserve current date/range and active timer state | Start/manual sessions, tags, goals, streaks and analytics |
| Settings | Preserve the settings section being edited | Typography, appearance, backups, reminders, provider configuration and accessibility |

There is no separate Sophia Account tab. The app is local-first and single-user; local
settings contain export, restore, privacy and configuration controls without requiring a
login. Account or cloud-sync features are outside the current product boundary.

## Navigation and state preservation

Each tab owns a navigation path and restores it when the user returns. The shell preserves:

- the last visible location and scroll position;
- selected filters, folders, conversation and note;
- unsent Companion text and an active Note editing transaction;
- the selected Scripture translation, layer and interaction state;
- an active Activity timer and its tag;
- transient focus only when it can be restored safely, never a stale modal.

Switching tabs does not reset a screen. A destructive or ambiguous action must complete,
be cancelled, or ask the owner before the shell changes destination. If restoration fails,
the app returns to the nearest safe parent and explains what could not be restored.

### Cross-screen route types

Cross-feature actions use typed intents rather than view-to-view references:

| Route | Example | Expected result |
| --- | --- | --- |
| Passage | `Romans 8:1` plus translation | Scripture opens the passage and focuses the verse |
| Artifact | Note, collection, saved quote or conversation ID | Owning tab opens the original item |
| Ask | Selected quote, reference, edition and user question | Companion opens with immutable passage context and an editable question |
| Save | Selected quote and reference | Save flow chooses bookmark, gleaning or note quote, then returns to the source |
| Collection | Collection ID plus optional originating artifact | Collection opens the folder and can navigate back to the artifact |
| Activity | Activity type or date range | Activity opens the relevant timer/editor/analytics context |
| Settings | Settings destination and optional highlight | Settings opens the exact section, such as Reading → Typeface |

The shell may route an intent to another tab, but the destination owns the feature logic.
No view directly mutates another feature’s files or provider client.

## Overlay policy

Transient surfaces follow a small, predictable set of rules:

- **Popover:** contextual detail on landscape or wide iPad layouts, including the
  Scripture verse hub and compact pickers.
- **Sheet:** focused tasks that need more room, including Save, filters, settings detail,
  and narrow-window replacements for popovers.
- **Side panel:** Companion beside Scripture when both columns remain readable. The panel
  becomes a sheet or full-screen conversation when width is insufficient.
- **Full-screen cover:** rare, task-focused experiences such as a dedicated canvas or
  restore/recovery review. It must provide an obvious close or cancel route.
- **Alert:** destructive confirmation, permission explanation or an unrecoverable error;
  never routine navigation.

Only one transient task surface should demand input at a time. Opening a new surface either
replaces the previous one or returns to it after the task completes. Dismissing a surface
returns to the same tab, location, selection and draft when those states are still valid.

## Audio continuity

Audio is a cross-screen service presented through a compact mini-player above the tab bar
whenever playback is active. It shows edition, passage, play/pause and progress. Tapping it
returns to the Scripture context that owns the current narration.

The mini-player must not cover the tab bar or the active canvas. Screens receive its measured
height from the shell. Draw, Notes and Companion may continue while audio plays; changing
the primary translation or starting another chapter requires a clear replacement action.
The player states when human narration is unavailable rather than silently implying that
TTS or an unlicensed recording is the same edition.

## Global search and continuity

Global search is a shell action available from the tab context bars. It searches only local
content by default:

- permitted bundled Scripture and verse references;
- saved quotes, notes, collections and conversation titles;
- activity labels and dates when useful.

Results show the artifact type and source reference, then route to the owning tab. Search
does not expose private AI or note content outside the device. Online research is a
Companion action with explicit context and provider behavior, not a hidden search fallback.

## Shared visual system

The DesignSystem owns tokens and reusable presentation primitives. Features supply meaning
and content, not their own competing colors or spacing systems.

| Token group | Initial rule | Applies to |
| --- | --- | --- |
| Surface | Selected preset roles; OldPaper uses white; transient surfaces preserve contrast | Scripture, Notes, sheets, popovers |
| Text | Selected preset ink roles, explicit error and disabled roles | All tabs and accessibility labels |
| Accent | Selected preset reference/study roles; never the sole state cue | Scripture, Save, Draw and focus states |
| Type | Selected preset Scripture/supporting UI pair; OldPaper uses Georgia with system sans; Dynamic Type for labels and controls | Reader and shell |
| Spacing | consistent compact, regular and generous increments; no feature-specific magic numbers | Cards, bars, lists and canvas chrome |
| Shape | restrained corner radius and hairline rules; depth reserved for surfaces above content | Cards, popovers and toolbars |
| Motion | short, reversible transitions; reduce motion removes ornamental movement | Navigation, focus and state changes |

The appearance preset supplies the selected Scripture and supporting UI type roles. Text
size remains adjustable independently. Preset or size changes must not silently rewrite an
annotated reading layout; the detailed preservation rule is in the
[Scripture specification](scripture-screen-specification.md).

## Shared component responsibilities

```text
App/
  SophiaScripturaApp.swift       # scene and root dependency assembly
  AppShellView.swift             # tab selection, safe areas and overlays
  AppRoute.swift                 # typed cross-screen intents

DesignSystem/
  Theme.swift                    # surfaces, colors and appearance roles
  Typography.swift               # UI roles and Scripture typeface mapping
  Spacing.swift                  # shared layout increments
  Components/                    # bars, cards, empty/error/loading states

Core/Application/
  RouteIntentHandler.swift       # maps intents to feature-owned operations
  StudyContextCoordinator.swift  # restoration and cross-feature context
```

These are proposed ownership boundaries, not files to create yet. The shell may depend on
feature contracts and route intents, but it must not own Scripture parsing, PencilKit
editing, note geometry, SQLite access, LLM calls or Keychain secrets.

## Shared states every screen must design

Every screen specification must show the following states before implementation:

1. **First use:** explain the screen’s purpose with one useful action.
2. **Populated:** show realistic study data and the primary action hierarchy.
3. **Empty:** explain what is absent and provide a direct creation or navigation action.
4. **Loading:** preserve the surrounding structure and communicate what is loading.
5. **Offline:** show what remains available locally and what requires an online request.
6. **Failure:** name the failed action, preserve recoverable input, and offer retry or exit.
7. **Permission/content unavailable:** explain rights or configuration limits without
   pretending the feature succeeded.
8. **Accessibility:** support VoiceOver, Dynamic Type, reduced motion, keyboard and
   pointer/finger alternatives for essential gestures.

## Acceptance scenarios for the shell design

1. Launch the app and move between all six bottom tabs. The selected tab is clear and each
   tab returns to its previous valid location.
2. Start reading Scripture, switch to Notes, then return to Scripture. Book, chapter,
   translation, scroll location and annotation state remain intact.
3. Open a verse hub, route to a linked note, then return through the source reference.
4. Select Scripture and choose Ask. Companion opens with the quote and reference attached;
   closing the panel returns to the same reading position and preserves the draft.
5. Start permitted audio, switch to Notes, and return through the mini-player. Playback
   remains visible without covering the canvas or tab bar.
6. Open a popover in landscape and rotate to portrait. The task adapts to a sheet without
   losing its draft or selected item.
7. Trigger an empty, offline and recoverable error state in each representative screen.
   Each state explains the next action and does not fabricate content.
8. Enable larger text, VoiceOver and reduced motion. Navigation, overlays and essential
   actions remain usable without relying on color or precise gestures.

## Open decisions before implementation

- Exact tab labels/icons and whether the compact landscape bar uses the same full labels.
- Whether global search is a visible shell control or reached through each tab’s More menu.
- The exact persistence mechanism for tab navigation paths and draft restoration.
- Audio interruption, background playback and lock-screen behavior after rights/source review.
- The first DesignSystem token values after visual prototypes on the owner’s iPad.
- Whether a future multi-window scene needs independent shell state; current scope is one
  local study session.

## Design handoff

After owner review, create detailed specifications in this order:

1. Notes library and expandable canvas.
2. Collections library and collection detail.
3. Companion panel, conversation list and full conversation.
4. Activity timer, manual entry and analytics.
5. Settings and Files backup/restore.

Each handoff must link back to this shell and the Scripture specification, then identify a
bounded implementation ticket only after the design and contracts are accepted.
