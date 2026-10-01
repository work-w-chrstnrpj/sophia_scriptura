# Scripture Screen Specification

Status: OldPaper is the owner-selected visual direction. The owner authorized its SP-009
reader/shell/preset refinement on 2026-09-29; that slice is implemented. Full annotation
interactions, accessibility and final physical acceptance remain open. See the native
refinement section below; other proposed features are not authorized by this document.
Owner choices incorporated: warm-paper/book-like reading, bottom primary navigation,
compact passage and Version controls, continuous vertically scrolling chapters, three annotation states, translation-specific handwriting, and an optional
blank surrounding writing space. The owner has now also chosen a selectable Scripture typeface,
landscape verse-hub popovers, an optional blank surrounding margin, stable compact reader chrome,
two-translation comparison by verse anchors, and the OldPaper UI direction with seven
color-and-type presets. Preset selection changes appearance; it does not remove or change
planned product workflows.

Related documents: [product specification](../product-specification/product-specification.md),
[UX specification](ux-specification.md), [TDD](../tdd/tdd.md), and
[SP-001](../../tickets/SP-001-product-and-device-decisions.md).

## Owner decisions — 2026-09-17

- **Reading typeface (refined 2026-09-29):** select a named color-and-type preset in
  Settings. Each preset pairs Scripture and supporting interface typefaces; OldPaper uses
  the current Georgia Scripture face and system sans UI. Font support and licensing remain
  to validate.
- **Verse hub:** popover in landscape and other wide iPad layouts. It may become an
  adaptive sheet in portrait or narrow windows where a popover would crowd the passage.
- **Margin:** blank surrounding space via viewport expansion; original ink geometry stays stable.
- **Scrolling chrome (revised 2026-09-22):** controls keep a stable height while scrolling.
  The passage and Version buttons remain visible; scrolling must not resize the viewport.
- **Translation comparison:** one primary translation remains the default. Compare opens
  an optional second, read-only column in landscape, synchronized by canonical verse
  references. Portrait uses a primary/compare toggle or sheet rather than squeezing two
  columns together.
- **Visual direction:** balanced antique study-Bible warmth with modern editorial spacing,
  restrained rules and quiet depth.

## Owner-selected OldPaper design and presets — 2026-09-29

OldPaper is the guide for the Scripture UI and the visual baseline for the connected app:
a clear, book-like reading surface; generous margins; optional blank writing space;
and quiet, floating controls with HIG-inspired hierarchy. Use restrained controls and
reserve glass-like materials for navigation or transient controls so decoration does not
compete with Scripture. Avoid simulated paper grain and ornamental distressing. The
OldPaper preset is black and white with grayscale support tones; its Scripture type is
Georgia and its UI type remains the system sans. Scripture is the visual focus; shared
controls remain familiar and unobtrusive.

The owner selected seven color-and-type presets. Each preset pairs a Scripture typeface
with a supporting interface typeface. OldPaper retains the system sans UI face. Sepia
Notes uses Caveat only for display headings and EB Garamond for passage text, preserving a
readable body. Final token values, font packaging/support, contrast, dark appearance and
Dynamic Type require validation before implementation.

| Preset | Palette direction | Scripture type / supporting UI type |
| --- | --- | --- |
| **OldPaper** | White page, black ink, grayscale support | Georgia / system sans UI |
| **Midnight Library** | Midnight blue-gray, soft white, silver | Cormorant Garamond / DM Sans |
| **Quiet Sage** | Soft blue-green paper, deep teal-gray ink, muted teal | Lora / Manrope |
| **Sepia Notes** | Yellow-orange cream, dark sepia, warm ochre-brown | Caveat headings, EB Garamond passages / EB Garamond UI |
| **Royal Ink** | Soft lavender-white, deep plum ink, muted purple | Libre Baskerville / Source Sans 3 |
| **Tree of Knowledge** | Marginalia’s warm paper, dark umber and oxblood | Playfair Display / Source Sans 3 |
| **Spring Leaf** | Stillwater’s calm white, deep green and sage | Lora / DM Sans |

Tree of Knowledge renames the Marginalia palette; Spring Leaf renames Stillwater. These
names describe appearance presets, not features or separate reader modes. Changing a
preset changes only color and typography. It does not alter annotation-layer content or
states, translation-specific ink, reserved margin geometry, passage position, verse links
or other planned workflows. A type or layout change must follow the preservation and
explicit reading-layout rules below; it must not silently move existing ink.

## Design intent

The Scripture screen should feel like opening a beautiful study Bible on a desk: quiet,
legible, tactile and focused. Its visual hierarchy must make the passage primary, the
current location obvious, and study actions available without turning reading into a
toolbar hunt.

The screen has three levels of attention:

1. **The Word** — the Scripture column receives the strongest contrast and the most
   generous space.
2. **The study context** — location, translation, annotation state and audio are easy
   to reach but visually restrained.
3. **The study workspace** — verse attachments, Companion and collections appear when
   requested, preserving the reading position when dismissed.

The design takes a useful cue from YouVersion’s Reader: Bible text itself is interactive,
book/chapter navigation is central, audio is available from the reading context, and
verse actions are close to the passage. Sophia deliberately makes the experience more
private, calmer and more study-oriented: no social feed, promotional cards or account
requirements.

Apple’s current iPad guidance also supports starting with a compact tab bar, adapting
to resizable windows without destructive reflow, and using toolbars that work around
multitasking window controls. The Scripture layout therefore preserves document geometry
when its window or study panel changes size. See the references at the end.

## Screen anatomy

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│ Sophia Scriptura       [Book] | [Version]                                  │  glass context bar
│      New International Version  ·  Read Visible                            │
├─────────────────────────────────────────────────────────────────────────────┤
│ [Romans 8 ▾] [WEB ▾]                                   [Layer ▾] [State ▾]   │  reader controls
│                                                                             │
│       1 Therefore, there is now no condemnation...                         │
│       2 because through Christ Jesus the law of the Spirit...               │  Scripture
│                                                                             │  scroll column
│       3 For what the law was powerless to do...                             │
│                                                                             │
│              [optional blank surrounding writing space]                    │  margin toggle
│  (‹)              Romans 8                                      (›)         │  chapter context
├─────────────────────────────────────────────────────────────────────────────┤
│ Scripture  Collections  Notes  Companion  Activity  Settings                │  bottom tabs
└─────────────────────────────────────────────────────────────────────────────┘
```

Detailed iconography and final color tokens remain subject to validation against OldPaper.
The structural rules are intentional: the primary reader controls remain above the passage, the main
tab bar stays at the bottom, and the annotation state is never hidden inside an overflow
menu when drawing is active.

### Context bar

The context bar identifies the current book and chapter and offers the global actions
that remain useful while reading:

- **Location title:** `Romans 8`, with a subtle subtitle for the current translation.
- **Audio:** opens or resumes the current chapter’s permitted narration. If no licensed
  narration is available, the control explains that state; it does not silently replace
  human narration with TTS.
- **Search:** searches permitted local Scripture content first; online search is an
  explicit optional path.
- **More:** exposes secondary actions such as reading settings, compare translation,
  copy chapter reference and report a content issue.

The context bar remains visually quiet while scrolling. It may collapse to a compact
title on narrow windows, but the current location must remain discoverable.

### Reader controls

M2 uses two compact controls:

| Control | Interaction | Result |
| --- | --- | --- |
| Passage, labeled with book and chapter (Genesis 1) | Searchable Books → Chapters → Verses in a navigation sheet | Final verse choice jumps and briefly highlights the whole verse; Read chapter starts at the first mapped verse |
| Version (WEB) | Shows installed edition, offline status and attribution | Only WEB is currently installed |

Back and cancellation preserve the existing passage until a final choice. The verse grid
uses actual mapped chapter verses, not the topmost visible verse. Scrolling only updates
an internal restoration anchor; no live verse counter is shown. This resolves the misleading
appearance of stopping at verse 22 while the final verses share the bottom viewport.
Future annotation Layer and State controls remain outside M2.

## Reading surface

### Typography

The OldPaper base uses white, black and neutral grayscale. Another preset applies its
paper, ink and accent roles while preserving the same reader layout. Each preset pairs a Scripture face with a supporting UI face, and reading size remains
adjustable. Appearance or type choices
must not silently move ink in an existing annotated layout. If a type change would reflow
the passage, offer a deliberate “keep annotated layout” or “create reading layout” choice.

Shared semantic roles across the seven presets:

| Token | Initial direction | Use |
| --- | --- | --- |
| `paper.background` | Preset paper role; pure white in OldPaper | Scripture and margin surface |
| `paper.elevated` | Preset elevated surface with readable contrast | Verse hub and sheets |
| `ink.primary` | Preset text role; black in OldPaper | Scripture text |
| `ink.secondary` | Accessible secondary neutral for the active preset | Metadata and captions |
| `accent.reference` | Preset accent; grayscale in OldPaper | Verse numbers, active location, links |
| `accent.study` | Preset accent, paired with labels and shape | Selected layer and Draw state |
| `rule.subtle` | Preset low-emphasis neutral | Page and margin boundaries |

The palette must pass light/dark appearance review and larger Dynamic Type review before
implementation acceptance. Color never carries the only meaning; state also uses labels,
shape and VoiceOver descriptions.

### Verse presentation

Verse numbers are small but touchable targets. The Scripture text remains a continuous
reading flow; verse numbers are anchors rather than boxed cards. Chapter headings use a
clear typographic break without competing with the passage.

When a verse is tapped:

1. The entire mapped verse body and label receive a 1.5-second, non-destructive focus treatment; notes and adjacent verses do not.
2. A verse hub opens as a popover in landscape and other wide iPad layouts. In portrait
   or a narrow window it adapts to a sheet so the passage remains usable.
3. The hub shows the verse reference, a compact quote, and attached study artifacts.
4. Dismissing the hub returns the user to the same scroll position and annotation state.

The temporary focus treatment must not alter saved highlighting or ink.

### Translation comparison

Comparison is an intentional reading action, not the default screen state. The Version
control continues to choose the primary translation; a separate **Compare** action opens
one additional edition. The first implementation supports two editions at a time.

- In landscape, the primary passage remains the leading column and the comparison passage
  appears beside it. Each column has a small edition label and a make-primary/swap action.
- Columns synchronize by canonical `Book + Chapter + Verse` anchors, never by raw line
  positions. If verse segmentation differs or a direct mapping is unavailable, the app
  keeps verse labels visible and shows a quiet “alignment differs” notice.
- The primary column owns selection, Ask/Save/Share and the active annotation layer. The
  comparison column is read-only by default, preventing ambiguous ink ownership. Making
  it primary swaps the reading and annotation context explicitly.
- In portrait or a narrow window, Compare uses a Primary/Compare toggle or an adaptive
  sheet. The app does not compress both editions into unreadable columns.
- Comparison never creates a second copy of handwriting. Ink remains keyed to its
  translation, chapter and reading-layout revision; audio follows the primary edition.

## Annotation states

The selected layer and the interaction state are separate concepts. Only one layer is
visible at a time; each layer is stored by translation, canonical chapter and layout
revision. A new layer is empty and transparent.

| State | Surface | Allowed actions |
| --- | --- | --- |
| Read Hidden | Scripture only; selected ink hidden | Read, scroll, tap verse/chapter, select text, Copy/Ask/Save/Share, audio |
| Read Visible | Scripture plus selected ink, ink non-interactive | Same reading actions; ink must never intercept passage selection |
| Draw | Scripture plus selected ink and optional blank surrounding space | Pencil drawing, native Pencil palette, eraser/lasso as supported, finger navigation; Scripture selection and verse taps pause while drawing |

State transitions are reversible and preserve scroll position. Entering Draw must not
silently select a different layer. Leaving Draw flushes the current drawing transaction
before changing the layer’s interaction mode.

### Blank surrounding writing space — SP-012 owner revision

2026-09-29: the owner superseded the ruled side-column/Reserved-mode design. Margin
exposes blank space above, below and on both sides of the centered Scripture column,
with shared Pencil/text zoom and pan. New layouts preserve the ordinary reader's column
width and typography, with fixed 200-point surrounding space. Margin off crops that
space through the viewport; it does not move strokes or rewrap text. Read Hidden restores
the ordinary reader surface and preferences, including its centered column.

Annotation controls stay horizontally centered; compact icon controls fit narrow windows.
Draw starts with a compact floating palette affordance; tapping it expands the native
Pencil picker, while its chevron collapses it to a small edge tab that can restore it.
Beginning a stroke minimizes the palette again while drawing continues.
Completed handwriting autosaves without a manual Save action. Clear Ink is red and
undoable. Margin is absent in Read Hidden, which uses the ordinary reader.
Old side-column drawings keep their original layout; creating a new layer on a legacy
layout creates the new surrounding-space layout, retaining the old group for selection
and backup. No silent ink conversion or deletion.

Each new layer captures its current preset/typeface, size and exact text geometry.
The Layers menu shows a blue name and checkmark on the selected layer and muted appearance details
beside its name. The toolbar button keeps its standard appearance. Selecting one restores those settings. Deliberately changing type or
size in Read Visible or Draw updates only the selected layer's layout; existing strokes stay
intact and may need repositioning. The separate Preserved layouts and larger-text
reading actions are removed. Read Hidden can use ordinary reading preferences without
changing the saved ink layout; returning to annotation restores the layer's appearance.
Layer management appears as a separate action group with New (plus), Rename (pencil),
and red Delete (trash) buttons. Mode icons use a dark pupil for Read Visible, a
hollow pupil for Read Hidden, and the pencil for Draw. While hidden, the retained
annotation canvas skips layout validation so opening Verse Hub uses the ordinary reader
without redundant annotation layout work.

## Verse hub

The verse hub is the screen’s organizing principle: every artifact attached to a verse is
reachable from the verse itself.

```text
Romans 8:1                                      [Close]
There is now no condemnation...

[Ask Companion] [Save] [Copy] [Share]

Notes (2)                  Conversations (1)
• Grace and assurance     • Why does Paul say...

Collections (2)            Links (1)
• Assurance                • Study article
```

Sections with no items remain discoverable but collapse to a quiet empty state. The hub
distinguishes a saved verse, a gleaning and a note quote; it never merges them into one
ambiguous “bookmark” concept.

## Text selection actions

Selecting text presents a compact floating action bar with the owner-approved actions:

- **Copy:** copies the quote with its reference and translation metadata.
- **Ask:** opens the Companion panel with the selected quote, reference and translation
  as immutable context; the user’s question remains editable.
- **Save:** presents Bookmark, Gleaning and Note Quote choices with one-sentence help.
- **Share:** uses the system share sheet with quote and reference; private notes and AI
  conversations are excluded unless explicitly selected.

The action bar must not cover the selected text. On narrow windows it becomes a bottom
sheet. Keyboard and VoiceOver users receive the same actions through accessibility actions.

## Audio

Audio is attached to the current chapter and appears as a compact player, not a permanent
large card. The player shows play/pause, elapsed position, chapter progress and a clear
route back to the current verse when narration advances. Existing audio may continue while
Draw is active, but the app must state which passage is playing.

## Responsive iPad behavior

The screen supports portrait, landscape and resizable windows without changing saved
Scripture layout identity. Recommended behavior:

- Full width: Scripture column plus optional margin; verse hub as popover.
- Medium width: compact controls; preserved margin remains on its original page, reachable
  by pan/zoom. Do not detach saved handwriting into a sheet. Detailed behavior follows the
  [SP-003 rendering decision](scripture-rendering-decision.md); native verification is pending.
- Narrow width: single column; controls wrap into a scrollable control row; verse hub and
  Companion become sheets.

M2 passage and Version controls remain visible and stable during scrolling.
The duplicate book/chapter header is removed; location remains in the navigation controls
and footer. Swipe left for the next chapter and right for the previous chapter. Swipes
are suppressed while text is selected; Previous/Next buttons provide an alternative.

Reading geometry and annotation geometry are distinct. A window resize changes the viewport
transform first. It must not silently rewrite page coordinates or move existing ink.

## Accessibility and premium quality gates

The implementation is not ready for acceptance until:

- VoiceOver announces book, chapter, verse, version, layer and state with useful labels.
- The passage has a predictable reading order and verse anchors are individually reachable.
- Every essential gesture has a labeled control or accessibility action alternative.
- Dynamic Type at the largest supported size does not hide navigation or essential actions.
- Draw state announces that text selection and verse taps are paused.
- Selection actions remain reachable without relying on precise touch placement.
- Reduced motion is honored; focus changes are calm and purposeful.
- Light/dark appearance, portrait/landscape and narrow-window layouts receive visual QA.

## SwiftUI ownership map

The first implementation should remain a focused Scripture slice:

```text
Features/Scripture/
  Presentation/
    ScriptureScreen.swift
    ScriptureScreenModel.swift
    ScriptureToolbar.swift
    PassageView.swift
    VerseHubSheet.swift
    ScriptureSelectionBar.swift
    AudioMiniPlayer.swift
  Domain/
    ScriptureLocation.swift
    ReadingLayout.swift
    AnnotationState.swift
  Application/
    NavigateToPassage.swift
    ChangeTranslation.swift
    AttachStudyArtifact.swift
  Infrastructure/
    BundledScriptureRepository.swift   # temporary free-base implementation
```

`PassageView` owns presentation of passage rows and verse anchors. It does not load files
or call a provider. `ScriptureScreenModel` owns screen state and invokes application
workflows. `ReadingLayout` defines stable identity and geometry rules without importing
SwiftUI or PencilKit. The annotation bridge will be injected behind a contract when the
separate annotation implementation ticket is selected.

## Acceptance scenarios for the design review

1. Open Romans 8 in the default free translation. The reader shows the location, version,
   page context and bottom tabs without crowding the passage.
2. Open Version and switch editions. The app remains in Romans 8 and explains when a
   corresponding annotation layout is unavailable.
3. Tap Romans 8:1. The verse hub shows quote, notes, conversations, collections and links.
4. Select a phrase and choose Ask. Companion opens with the quote and reference attached.
5. Choose Save → Gleaning. The quote remains intact and a separate insight field appears.
6. Enter Read Visible, then Draw. The selected layer remains the same and drawing tools
   appear without moving the passage.
7. Enable the blank surrounding margin, draw in it, disable the margin and confirm the saved layout
   remains available without silently shifting existing ink.
8. Rotate or resize the iPad window. The passage remains readable and saved annotation
   geometry does not change.
9. Open Settings → Reading and change the Scripture typeface. The reading surface updates;
   existing ink remains attached to its preserved layout until the owner deliberately
   creates a new layout.
10. In landscape, choose Compare and open a second translation. The two passages stay
    aligned by verse reference, the comparison is read-only, and Make Primary swaps the
    active edition without duplicating ink.
11. Scroll to the chapter bottom and upward. Compact passage/Version controls stay fixed,
    and the passage button keeps the book/chapter without a misleading visible-verse counter.

## Open decisions before implementation

- Exact token values and the final curated typeface list after a visual prototype on the
  owner’s iPad.
- Whether a future release should offer Compact margin as an explicit user setting; Reserved
  is the approved default.
- M2 picker uses a navigation sheet; future annotation controls remain separate.
- Scripture renderer choice: TextKit-based layout or a provider SDK capability after SP-002
  and SP-003 research.
- First permitted bundled translation and available audio edition.
- Layer naming, creation, deletion and layout revision migration rules.

## References and inspiration

- Apple, [Elevate the design of your iPad app](https://developer.apple.com/videos/play/wwdc2025/208/): adaptive tab/sidebar navigation, non-destructive resizing, toolbars and pointer behavior.
- Apple, [Human Interface Guidelines — tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars): navigation placement and tab-bar guidance.
- Apple, [Human Interface Guidelines — split views](https://developer.apple.com/design/human-interface-guidelines/split-views): adaptive iPad content layouts.
- YouVersion, [Welcome to the Bible App](https://blog.youversion.com/getstarted/): Reader patterns including tappable Scripture, book/chapter switching, audio, font size and verse actions.

## SP-009 implemented reader scope — 2026-09-22

The first product reader now implements WEBP content, sequential Book/Chapter/Verse navigation,
Version/attribution, a single continuous selectable TextKit surface, Copy/Share, reader
settings, progress restoration and bottom navigation. A verse jump brings its label near
the top where possible and briefly highlights its full mapped text. The compact passage
and Version controls stay visible. The hub is a popover above 900 points and a sheet otherwise, with honest
empty study sections. Native TextKit 1 is the initial renderer (see the rendering decision).
Annotations, providers, audio, Ask/Save and comparison remain later; those portions above
are design intent. Physical accessibility, drag selection, dark and narrow-window visual
acceptance remain outstanding in [reader evidence](../testing/sp009-reader-evidence.md).

The owner’s 2026-09-22 physical review supersedes the older page illustrations above for
M2. Chapters have no artificial page gaps or page-number chrome. Annotation-specific
illustrations remain future design candidates pending M3 review.

## Native OldPaper refinement — 2026-09-29

The owner authorized implementation of the selected visual direction in SP-009 / M2.
The reader now uses the OldPaper surface, capsule passage/version controls, an editorial
chapter heading, restrained rules and floating bottom navigation. Settings offers all
seven named presets; their reading and supporting control fonts ship offline with OFL
notices. Midnight Library keeps its dark palette; other presets follow the selected
system/light/dark appearance. Sepia uses Caveat only for chapter headings.

The existing optional reader-preference record stores the stable preset identifier;
older saved preferences continue decoding and preserve edition, typeface, size and progress.
Changing typography restores the last observed source anchor. This is a continuous
reader refinement: the surrounding writing space, annotation states and layers remain M3
work and are not represented by nonfunctional buttons. Other feature interiors remain
at their previously recorded implementation/prototype stage. Native acceptance evidence
is recorded in the SP-009 ticket and reader evidence page.

Palette refinement: Royal Ink replaces the Ink and Linen display name; the persisted
`inkAndLinen` identifier and Libre Baskerville / Source Sans 3 pairing remain stable.
Sepia Notes is warmer yellow-orange; Quiet Sage is blue-green. Both light and dark
appearances carry these hues.

## Reader control refinement — 2026-09-29

The command surface shows the current book/chapter name and the current version
abbreviation without disclosure chevrons. The surface uses the exact same appearance
background as the reading surface; it does not create a differently tinted header band.
The page background is owned by the reader shell so the header, Scripture text, safe-area
regions and chapter controls remain one continuous surface across the full screen.
The active preset and the selected light/dark reading preference resolve through one
palette path; chooser sheets and their rows use the same paper, ink and accent tokens
instead of the platform's default gray list background.
Chapter navigation uses circular chevron buttons with accessible labels
“Previous chapter” and “Next chapter”; the header and chapter-footer rules are removed.

When Book or Version opens, the underlying reader receives a restrained focus treatment:
the text and surrounding page soften slightly while the chooser remains crisp. The
effect is intentionally light enough to preserve the current passage as spatial context;
it must not become a dark opaque scrim or obscure the reading surface.

The continuous TextKit reader keeps horizontal swipes for chapter changes. A true
finger-matched page curl with synchronized page-turn audio is deferred: it requires a
page-rendering transition model, while the current reader intentionally owns one
continuous selectable text stream. A transform or sound layered over that stream would
make selection, VoiceOver navigation and restoration less reliable. Revisit this as a
dedicated interaction ticket after the annotation layout boundary is proven.
