# SP-009 — First offline Scripture reader

- Type: product implementation. Status: in progress; selected by owner request “Develop M2” on 2026-09-22.
- Milestone: M2 — Scripture reader.
- Owner: Frontend UI/UX Developer, with Backend & Database Engineer ownership of importer/repository.
- Requirements: REQ-002, REQ-003, REQ-004, REQ-005 (Copy/Share only), REQ-016,
  REQ-018, REQ-020, REQ-022.
- Design: [Scripture screen](../docs/design/scripture-screen-specification.md),
  [rendering decision](../docs/design/scripture-rendering-decision.md).
- Contracts: [content feasibility](../docs/integrations/scripture-content.md),
  [reader data contract](../docs/data/scripture-reader-contract.md).

## Required announcement

Before changing app or ingestion source for this ticket, tell the owner exactly:

> **We are now starting actual product implementation: SP-009 will deliver Sophia’s first usable offline Scripture reader.**

Explain that this is durable product code and bundled content, while Scripture handwriting,
licensed translations, Ask/Save, audio, search and completed study-data backup remain later.

## Visible outcome

On the owner’s iPad, Sophia opens a premium warm-paper reader containing the legitimate
66-book WEBP edition with no network or account. The owner can:

- navigate with compact passage/Version buttons and a Book → Chapter → Verse sheet;
- see the Version control identify WEB as bundled/offline;
- read one continuously scrolling chapter with accurate verse labels and attribution;
- select across adjacent verses and long passages and Copy or Share the exact body text;
- tap a verse number to open the initial hub with honest empty sections;
- choose a curated Scripture typeface, text size and appearance;
- leave/relaunch and return to the last passage;
- use the six primary tabs at the bottom on the target iPad layout.

This is the first daily-use product slice. Demo data, fake destinations and silent online
fallbacks are prohibited.

## Exclusions

- Pencil annotations, layers, native palette and ruled-margin writing;
- NIV/NLT/NKJV/ESV integration, YouVersion/API.Bible accounts or provider keys;
- Ask, Save, Collections/Notes/Companion routing, audio and Scripture search;
- comparison mode, red-letter decisions beyond available source structure, and final M3 pagination migration;
- full Files export/import or recovery reminders. Reader state is designed for later export.

Unavailable actions do not appear as enabled controls. Version selection may contain one
edition and explains why. The verse hub uses real passage identity with empty-state copy;
it does not seed fake attachments.

## Architecture and file ownership

Create or update these responsibilities after confirming the Xcode project references:

- `service/ingestion/`: replace the obsolete copyrighted-download stub with a deterministic,
  safe WEBP USFM importer, manifest generator and importer tests. No secrets/network calls
  occur during app runtime.
- `application/.../Resources/Scripture/`: generated, verified WEB SQLite artifact and manifest.
- `application/.../Core/Scripture/`: domain IDs, chapter/selection models, typed errors,
  `ScriptureContentRepository` and `ReaderStateRepository` protocols.
- `application/.../Infrastructure/Scripture/`: read-only SQLite repository and bundled-resource validation.
- `application/.../Infrastructure/Persistence/`: SwiftData reader-progress/preferences adapter and v1 schema.
- `application/.../Features/Scripture/`: reader store/session, TextKit surface, horizontal chapter gestures,
  navigation controls, verse hub, styles and the composed `ScriptureView`.
- `Features/Settings/SettingsView.swift`: reader settings section only.
- `RootTabView.swift`: approved bottom primary navigation without moving reader controls into the tab bar.
- Native test targets: repository/state/range/layout unit tests and focused reader UI tests.

Dependency direction is View → feature state/use cases → domain protocols → infrastructure
adapters. SQL, SwiftData and importer types must not leak into SwiftUI. Provider policy and
rendering remain separate. Review any source file approaching multiple screen/store/parser
responsibilities before adding more behavior.

## Implementation sequence

1. Acquire the exact publisher-linked `engwebp` USFM archive during the ticket, record its
   resolved source and hashes, and build the deterministic artifact. Inspect the license
   and representative chapters before committing generated content.
2. Implement immutable domain models, manifest validation and the read-only repository.
   Pass READER-DATA-01–04/08/12 before binding UI.
3. Implement SwiftData progress/preferences with injected test containers. Pass
   READER-DATA-06/07/09.
4. Implement the reader shell, continuous chapters, navigation, attribution and error/empty states.
5. Implement native selection and Copy/Share. Satisfy SP-008 LAYOUT-01–03 and
   READER-DATA-05 in the product surface; record deviations before changing architecture.
6. Implement reader Settings and bottom navigation, then run accessibility, offline,
   relaunch, rotation, narrow-window and physical-iPad acceptance.

Each step leaves the project buildable. Do not defer content integrity or state recovery
until after visual work.

## Acceptance and verification

- All twelve READER-DATA cases in the contract have evidence or an explicit owner-accepted
  deferral. LAYOUT-01–03 pass in the product reader.
- Clean generic iOS build and scoped XCTest/XCUITest suites pass on an installed iPad simulator.
- Signed installation and READER-DATA-10/11 pass on the owner’s iPad A16.
- Airplane-mode cold launch proves WEB content is bundled. Network instrumentation/code
  review finds no runtime content request in the WEB path.
- Visual review covers light/dark, portrait/landscape, largest supported text size,
  long labels, chapter ends, compact controls and bottom-tab/palette-safe-area planning.
- Generated artifact manifest records source and output hashes; all 66 books are indexed.
- No existing Notes/Collections behavior is regressed; run their smallest relevant smoke tests.
- Documentation, project structure, test evidence and this ticket are updated accurately.

Do not mark M2 complete merely because the text displays. Failed selection mapping,
missing offline evidence, corrupt-state data loss, inaccessible navigation or top-only tabs
are acceptance failures.

## Risks and fallback

- If TextKit 2 cannot provide continuous page-boundary selection, pause only the selection
  slice and record evidence. Evaluate TextKit 1 multi-container layout or a custom logical
  selection owner without discarding the working content/navigation product code.
- If the source archive differs from the pinned metadata/book set, stop ingestion and
  update SP-002 evidence; never trim or rewrite Scripture silently.
- If iPadOS native TabView will not honor the approved bottom position, use a documented
  accessible custom bottom navigation container and test keyboard/safe-area behavior.

## Completion handoff

Report implemented behavior, files/responsibilities, source provenance, exact automated
and physical evidence, visual/accessibility gaps and status. Return to the owner before
starting M3 annotations or any provider integration.

## Implementation evidence — 2026-09-22

Implemented the WEBP importer/artifact, domain/repository/state layers, native reader and bottom navigation. See [acceptance evidence and remaining gaps](../docs/testing/sp009-reader-evidence.md). Execution followed the existing ticket plan. TextKit 1 is the documented first renderer; the initial controls collapsed on scroll (superseded by the revisions below) and the hub adapts by available width. M2 is not complete, and physical evidence is not inferred from builds or simulator tests.

## Owner feedback revision — 2026-09-22

The owner reported a bouncing glitch at the bottom of the physical reader and requested
continuous chapters, left/right chapter swipes and removal of the duplicate Book/Chapter
header. This explicitly replaces M2’s earlier visible-page requirement. The native surface
now has no exclusion bands/page rules; chrome never resizes in response to scrolling.
Left swipe advances, right swipe returns, with selection protection and button alternatives.
Reader state/content remain compatible. The exact physical root cause remains unconfirmed;
scroll-driven chrome resizing was the likely feedback path found in source. Record the
new regression and physical retest separately in the evidence page.

The request about additional versions is being answered with verified source options;
this revision does not silently select, license or install a second edition.

Revision verification: 10 reader unit tests and 2 UI tests passed in
`build/sp009/continuous-reader-r2.xcresult`; signed iOS build and iPad update succeeded.
Physical bottom-scroll/selection/swipe retest is pending. Status remains in progress.

## Owner passage-picker revision — 2026-09-22

Replaced the separate selectors with book/chapter and WEB buttons; added sequential
book/chapter/verse browsing, Back/cancel, Read chapter, and whole-verse temporary focus.
The reported verse-22 limit came from displaying the viewport's topmost restoration anchor;
the picker now lists mapped verses independently and exposes no scrolling verse counter.
Picker preview stays in the feature session through the repository contract and does not
persist reading state. No content/state migration or translation integration is included.
See the reader evidence page for this revision's checks and remaining physical acceptance.

Picker revision verification: 12 unit tests and 3 UI tests passed in
`build/sp009/passage-picker.xcresult`; portrait/landscape and Genesis 1:31 focus screenshots
were inspected. Signed build and iPad installation succeeded. Physical acceptance remains
pending; status remains in progress.

## OldPaper reader and seven presets — 2026-09-29

Owner authorized the selected UI direction as an SP-009 / M2 refinement. Implemented
OldPaper reader styling, capsule passage/version controls, editorial chapter heading,
floating bottom navigation and seven named Settings presets. Nine font families and
OFL notices are bundled for offline operation. The optional preset preference preserves
schema-1 decoding; typography changes restore the latest observed source anchor.

Verification on iPad Pro 13-inch (M5) Simulator / iOS 26.5:
- 16 unit tests passed (12 existing reader + 4 appearance tests), zero failures:
  `build/oldpaper/appearance-tests.xcresult`.
- 4 reader UI tests passed, zero failures, including preset selection/relaunch,
  passage browsing, continuous scroll stability and chapter swipes:
  `build/oldpaper/reader-ui.xcresult`.
- OldPaper portrait/landscape and Midnight Library screenshots inspected; fonts, passage
  controls and bottom tabs render coherently. Attachments exported under
  `build/oldpaper/screenshots/`.
- Signed device build, installation over the existing app and normal launch succeeded
  on the paired iPad A16. Logs: `build/oldpaper/device-build.log`, `install.log`, `launch.log`.

The UI run reported a simulator diagnostic-collection warning about finding simctl;
its result bundle and all four test outcomes were produced successfully. Existing
orientation and TextKit deprecation warnings remain. These checks do not establish
VoiceOver, largest Dynamic Type, narrow-window or owner physical visual acceptance.
Annotation layers/ruled writing remain M3; other feature interiors retain their existing
prototype/placeholder scope. SP-009/M2 remain in progress for their outstanding gates.

### Palette refinement — 2026-09-29

Owner requested Ink and Linen → Royal Ink with muted purple, warmer yellow-orange
Sepia Notes, and blue-green Quiet Sage. Updated light/dark tokens and design docs;
font pairings and the persisted `inkAndLinen` identifier remain unchanged. Four existing
appearance tests passed with zero failures in `build/oldpaper/palette-refinement.xcresult`.
Signed device build and installation over the existing iPad app succeeded; logs are
`build/oldpaper/palette-device-build.log` and `palette-install.log`. Owner visual review
of the revised shades remains pending. No new feature scope or annotation changes.
### Glass reader shell refinement — 2026-09-29

The bottom tab selector now uses a translucent continuous material surface without an
opaque palette-colored footer behind it. The active tab uses a restrained translucent
selection treatment. The Scripture command surface uses the same material language and
the reader header spacing is reduced to keep the passage visually primary. Settings and
the root shell extend the active appearance background behind the safe-area inset so the
footer does not retain a stale color when changing tabs.

After the owner restarted the Mac, Xcode built the `SophiaScriptura` scheme and launched
it on the paired physical iPad A16. Xcode showed **Running SophiaScriptura on iPad ni Paj**.
Existing system warnings about all-orientation support and pointer handlers remain; they
did not block installation or launch. Final owner visual review of material translucency
on the physical device remains the acceptance check.

### Continuous page surface and restrained chooser focus — 2026-09-29

The reader shell now owns the appearance background for the header, safe-area regions,
Scripture text and chapter controls, preventing a separate-colored header band. Opening
Book or Version applies a lighter material/dim layer to the underlying reader so the text
remains recognizable while the chooser stays primary. No reader state, annotation
contract or navigation behavior changed.

The shell and both chooser sheets now resolve one active preset palette, including the
explicit light/dark preference. Their list backgrounds and controls no longer fall back to
the platform gray surface, so OldPaper and each named preset retain their own colors.
