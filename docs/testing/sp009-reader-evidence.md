# SP-009 — Reader implementation and acceptance

Owner selected M2 on 2026-09-22. Status: implemented; acceptance in progress, with physical and
interactive checks outstanding. This page separates working code from verified cases.

## Implementation

- One target, with `Core/Scripture` values/protocols and a UTF-16 source map.
- Actor-isolated read-only SQLite repository, manifest/hash/schema validation and a
  four-chapter cache. Content errors never change stored progress or switch editions.
- Local-only SwiftData v1 reader progress/preferences. Failure leaves the original
  store untouched and exposes session-only reading. No automatic reset or migration.
- Scripture session owns navigation, restoration, debounced position saves and settings.
- One chapter-wide TextKit 1 selection owner with continuous vertical scrolling.
  The owner removed visible pagination after the first physical test; M3 ink geometry remains open.
- Book/chapter/verse sheets, WEB/offline information, source-note disclosures, empty verse
  hubs, curated typography, appearance and explicit collapse/expand controls.
- Accessible custom bottom navigation retains each destination's state when switching.
  This replaces native TabView to guarantee bottom placement on current iPadOS.
- Copy and system Share use only selected body runs. Labels, headings and note UI are
  excluded. Source identity, source labels and canonical anchors remain in the selection map.

Controls remain stable while scrolling, with a labeled manual collapse/expand toggle.
Left/right swipes change chapters when no text is selected. Location appears in the
navigation controls and footer, without a duplicate top title. The hub adapts to a popover above 900 points
and a sheet otherwise. Stable visible positions store a verse plus a body-block UTF-16
offset when available; matching revisions restore that offset, changed revisions fall
back to verse. Cross-chapter domain range resolution exists; the current drag selection
remains chapter-local. M3 layout preservation and annotation migration are not implemented.

## Content provenance

Publisher: [WEBP download listing](https://ebible.org/find/details.php?id=engwebp).
Unmodified archives are retained in ignored `build/sp009/source/`:
`engwebp_usfm.zip` and `engwebp_vpl.zip`.

The checked-in `Resources/Scripture/web-engwebp.manifest.json` records both source hashes,
retrieval/source URLs, source byte count, generation time, generator version, edition,
reference system, content revision, book-set digest and output hash. Runtime reads only
bundled content; no URLSession, provider SDK or credential path is present in the reader.
Publisher links in Settings/Version open only on explicit owner action.

The importer preserves FRT/GLO and license/support files separately in `source_supplement`.
Exactly 66 canonical book IDs, 39 OT/27 NT, yield 1,189 chapters. All 31,103 source passage
keys compare against the independent publisher VPL export after whitespace normalization.
Explicit VPL projection rules translate its alternate book codes and account for Psalm
superscriptions, acrostic headings, inline Song speaker labels and Selah spacing. These
rules do not delete words or alter the structured USFM content. No unexplained differences.

Two imports from identical input yielded byte-identical SQLite artifacts:
`b9124cef01b11c953f36704404a2e3fb058d0bdf1e927988864da414a9bf962c`.
Comparison reports are retained alongside generated artifacts under `build/sp009/`.

## Automated evidence

- `python3 -m unittest discover -s service/ingestion -v`: 4 passed. Unsafe archive paths,
  duplicate files, missing/extra books, malformed markers, notes, Unicode and bridge labels.
- Two importer builds plus `cmp`: passed. Generation timestamps are outside SQLite bytes.
- Native unit/model suite: 28 passed, zero failures, iPad A16 simulator / iOS 26.5.
  `build/sp009/reader-unit.xcresult` and `build/sp009/test.log`. Includes 8 new reader tests,
  13 existing canvas tests and 7 existing Collections tests.
- Existing Collections UI (2 cases) and Notes edit/reopen smoke (1 case) passed in
  `reader-ui.xcresult`. That initial run failed the new reader test because book search
  was not exposed; the app was fixed with an explicit search field.
- Refined reader run: 8 reader unit tests plus 1 reader UI test passed in
  `reader-refined.xcresult`. Final adaptive-hub UI test passed in `reader-final-ui.xcresult`.
  Navigation to Romans 8:28, relaunch, settings access, rotation/frame checks, bottom tabs,
  manual control collapse/expand and opening the verse hub are covered.
- Final navigation refinement: 8 reader unit tests plus 1 reader UI test passed in
  `reader-navigation-final-r2.xcresult`. Verse jumps now reveal the target near the top,
  with a temporary focus highlight. A new geometry assertion verifies the target position.
  An intermediate compile failure used an AppKit-only temporary-attribute API; it was
  corrected to UIKit text-storage attributes before this passing run.
- Signed generic iOS build passed: `build/sp009/verified-device-build.log`.
- Final verified signed installation over the existing owner iPad app succeeded
  (`build/sp009/final-install.log`). CoreDevice launch was
  rejected because the device was locked; no physical reading/airplane-mode pass is claimed.
- Portrait and full-screen landscape captures visually reviewed. App-only landscape
  screenshots cropped incorrectly; `reader-screen-capture.xcresult` uses XCUIScreen and
  shows all six bottom tabs, complete reader controls and the centered Scripture column.
  Settings portrait also reviewed. Dark/largest-type/narrow-window review remains open.

Tests use injected repositories, in-memory SwiftData or UUID-scoped DEBUG reader stores.
They do not delete/reset normal reader or Notes stores.

## Acceptance matrix

| Case | Evidence / remaining work |
| --- | --- |
| READER-DATA-01 | Passed: byte-identical imports and independent VPL comparison. |
| READER-DATA-02 | Partial: importer malformed/unsafe/missing/extra/duplicate checks and native missing/corrupt/future-schema checks. More adversarial fixtures remain. |
| READER-DATA-03 | Passed automated: all 66 books' first/last chapters load and resolve passages. All source passages independently compared. |
| READER-DATA-04 | Partial: canonical cross-book overlap, reversed-range rejection and cross-chapter resolution tested; bridge/missing full repository fixtures remain. |
| READER-DATA-05 | Partial: combining characters, emoji, repeated prose, partial selection, bridge anchors and programmatic cross-page Copy pass. Current continuous-selection unit checks also pass; native drag/Share interaction remains. |
| READER-DATA-06 | Partial: revision/missing-verse/invalid-block recovery tested; UI relaunch to Romans 8:28 passed; offset restore implemented, detailed physical scroll restoration still unverified. |
| READER-DATA-07 | Partial: SwiftData round-trip and non-destructive invalid preference defaults pass; complete settings UI relaunch checks remain. |
| READER-DATA-08 | Partial: missing/corrupt resources reject; state is separate and never reset. Combined UI recovery case remains. |
| READER-DATA-09 | Partial: injected save/load failures preserve previous state and permit reading; physical disk-failure simulation not performed. |
| READER-DATA-10 | Not run: physical airplane-mode cold launch, Copy/Share, navigation and background/relaunch. |
| READER-DATA-11 | Not run: physical VoiceOver, largest Dynamic Type and narrow-window acceptance. |
| READER-DATA-12 | Code inspection: no runtime network/credential/provider path. Network instrumentation not performed. |
| LAYOUT-01–03 | Partial: one continuous text owner and programmatic long-passage selection pass. The owner removed the page-break gate; native drag, touch targeting and all window sizes remain. |

M2 is not complete until remaining required cases pass or the owner explicitly accepts
bounded deferrals. M3 is not started.

## Physical walkthrough

1. Install the signed build over the existing app; never delete the app to update it.
2. Enable airplane mode, terminate Sophia, then cold launch. Read Genesis 1 and navigate
   to Revelation 22; inspect source edition and attribution.
3. Open Psalms 119. Scroll down, long-press a phrase and extend selection beyond one viewport. Copy to a scratch note and verify exact body text, without verse numbers
   or note markers. Share through the system sheet, cancel without sending.
4. Tap a verse number; check the reference/quote and honest empty sections. Tap a note marker.
5. Navigate to Romans 8:28, scroll, background and relaunch. Confirm the nearest visible verse.
6. Change typeface, size and appearance; relaunch and inspect light/dark, portrait/landscape,
   largest text size and a narrow window. Confirm all six tabs remain at the bottom.
7. Enable VoiceOver and verify book/chapter/verse controls, source notes, reading order,
   Copy/Share alternatives and bottom tabs. Record observations separately from simulator tests.

## Owner feedback and continuous-reader revision — 2026-09-22

Physical observation: the owner reported a bouncing glitch when scrolling to the bottom.
This is a failed interaction observation, not evidence of offline or VoiceOver acceptance.
Source review found that scroll direction resized chrome during deceleration, which could
change the scrollable extent and trigger the opposite direction. Confidence: medium until
the revised build is retested on the physical iPad.

The owner replaced visible pagination with continuous chapters and requested horizontal
chapter swipes and no duplicate top location heading. These are implemented with stable
chrome and selection-aware gestures; no content/database migration is required.
Automated regression: **10 reader unit tests and 2 UI tests passed** on iPad A16 simulator
/ iOS 26.5, `build/sp009/continuous-reader-r2.xcresult`. Checks include one continuous
text container without exclusion bands, exact selection/Copy, verse reveal, swipe direction
and selection rejection, book/canon boundaries, repeated bottom scrolling with an unchanged
viewport frame, native left/right chapter swipes, navigation/relaunch and bottom tabs.
The initial compile attempt needed the UIView gesture override keyword; that was corrected
before this passing run. Reader screenshots were inspected after the UI run.
Physical retest remains pending; do not infer it from simulator success.

Retest: scroll all the way to the chapter end repeatedly, swipe left/right between chapters,
and select text before trying a horizontal drag. Controls must stay still while scrolling;
selected text must not trigger chapter navigation. Confirm the original bounce is gone.

Signed generic iOS build succeeded (`build/sp009/continuous-device-build.log`); installation
over the existing iPad app succeeded (`build/sp009/continuous-install.log`). No user data
or Scripture artifact was replaced beyond the normal application update; no schema migration.

Launch of the continuous-reader build was blocked by the device with a signing/entitlement/
profile-trust error (`build/sp009/continuous-launch.log`). Host verification with macOS trust
services passed: signature valid on disk and designated requirement satisfied; the embedded
profile includes the iPad and expires 2026-09-29 05:49:55 UTC. Device trust/online verification
is the next check; the precise device-side cause is not yet established. Earlier restricted
host verification could not access trust services and is not an app-signature failure.

## Compact passage picker and full-verse focus — 2026-09-22

Owner feedback: the separate live Verse control appeared to stop at 22 near the bottom of
Genesis 1. Source inspection shows it displayed the topmost visible restoration anchor;
it did not describe the last verse present. M2 now shows only passage (book/chapter) and
Version buttons, with Books → Chapters → Verses in a navigation sheet. Back/cancel preserve
the reader; Read chapter is an optional shortcut. All mapped verses are offered, including
Genesis 1:31. Full mapped verse text and its label receive transient 1.5-second focus;
notes and adjacent verses are excluded, and rapid jumps clear previous focus.

Verification: **12 reader unit tests and 3 UI tests passed**, zero failures, in
`build/sp009/passage-picker.xcresult` (`passage-picker.log`). Added checks cover multipart
Unicode verse focus, bridged references, note exclusion, rapid replacement/timed clearing,
nonmutating picker previews, final verse availability, Back/cancellation and Read chapter.
Existing scoped checks cover content/state recovery, Copy, bottom scrolling, chapter swipes,
relaunch, Settings and rotation. Screenshot inspection confirmed full Genesis 1:31 focus
and compact controls in portrait/landscape; exports are in `build/sp009/picker-attachments/`.
Xcode reported a post-test diagnostic-collection simctl lookup warning; the test action
returned success and its result bundle was exported successfully.

Signed build succeeded (`picker-device-build.log`) and installation over the existing iPad
app succeeded (`picker-install.log`). No content or persisted-schema migration was needed.
The old controlsExpanded field remains decodable but its Settings toggle is removed.
Physical acceptance remains pending: choose Genesis → 1 → 31, observe the whole verse flash,
check Back/cancel, scroll to the bottom, and swipe between chapters. Also test native verse
links/hub, VoiceOver and offline cold launch; simulator checks do not establish those gates.

Device launch was denied because the iPad is locked (`build/sp009/picker-launch.log`,
CoreDevice 10002 / FBS Locked). This run did not report the earlier trust failure. Unlock
and open Sophia for the physical retest. Documentation local-link and diff-whitespace
checks passed.

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

### Reader control refinement — 2026-09-29

The top controls now show the current book/chapter name and version abbreviation without
disclosure chevrons. The command surface uses the exact reader background, with no
separate tinted header band. The previous/next chapter controls are circular
chevron buttons with accessible chapter labels. Header and footer border rules were
removed. Xcode rebuilt and relaunched the updated scheme on the paired physical iPad
after these changes.

The reader shell now owns one continuous appearance background across the header, safe
areas, Scripture text and chapter controls. Opening Book or Version applies only a light
material/dim focus layer to the underlying page, keeping the text legible as context while
the chooser remains visually primary.

The shell, header controls, Book sheet and Version sheet now resolve their paper/ink/accent
tokens from the same active preset and reading theme. Platform-default gray list surfaces
are hidden so chooser rows follow the selected appearance.

The continuous TextKit reader still changes chapters at the end of a horizontal swipe.
A finger-matched page curl and synchronized sound effect remain deferred because the
current reader has one continuous selectable text stream rather than page surfaces;
adding a visual transform over it would compromise selection, VoiceOver navigation and
restoration. This is recorded as a future interaction ticket rather than a partial
implementation.
