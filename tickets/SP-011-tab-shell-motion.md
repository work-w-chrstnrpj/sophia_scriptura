# SP-011 — Quiet tab dock and navigation motion

- Type: product UI refinement. Status: in_progress; implemented and verified, owner physical motion review pending. Selected 2026-09-29.
- Milestone: shared-shell refinement between accepted SP-008 validation and M3 production ink.
- Owner: Frontend UI/UX Developer.
- Requirements: REQ-016/018/020; owner refinement to the bottom-navigation decision D-11.
- Design: [App shell](../docs/design/app-shell-specification.md).
- Dependencies: existing six-tab shell, reader appearance tokens and retained tab state.

## Owner request and visible outcome

After reporting all SP-008 validation criteria successful, the owner requested a bottom
menu that appears for five seconds, hides, and returns on scrolling, plus sliding tab
changes and a glow treatment. This ticket owns that request; production annotations
remain the next separately scoped M3 implementation.

- Show the menu on launch/resume, finger pans/scrolls, manual reveal and tab taps.
- Hide after five seconds without another observed finger pan or navigation interaction.
- Leave a small, 44-point-tall touch target to reveal navigation on non-scrolling screens.
- Slide between tabs in their left/right order; keep screens mounted to retain state.
- Animate the theme-colored selected-tab glow between destinations.
- Use a fade without lateral travel or glow animation when Reduce Motion is enabled.
- Keep the bottom content inset stable through hide/reveal, avoiding reader/ink reflow.

## Ownership and boundaries

`application/SophiaScriptura/SophiaScriptura/`:

- `RootTabView.swift`: tab presentation, dock styling, reveal handle and scene lifecycle.
- `AppShell/ShellChromeState.swift`: monotonic idle deadline and cancellable timer.
- `AppShell/ScrollActivityObserver.swift`: passive direct-finger observation across SwiftUI
  and UIKit surfaces. Does not recognize a competing gesture or accept Pencil strokes.

The observer sees finger movement, including panning/selection drags; it does not start
navigation or provider work. Only existing tab selection saves reader position. No
provider, persistence schema, annotation-store or content changes. Existing experiment
code and user data remain independent. The bar keeps its reserved space when hidden;
full-screen ink must not change geometry when navigation returns.

## Acceptance and verification

| Case | Expected result | Evidence |
| --- | --- | --- |
| SHELL-01 | Five-second idle hide, finger-scroll reveal and another idle hide | UI test passed |
| SHELL-02 | Small reveal handle works from an empty/non-scrolling destination | UI test passed |
| SHELL-03 | Tab slide retains nested navigation and reading location | UI/reader regressions passed |
| SHELL-04 | Stable content frame when menu hides/reappears | UI test passed |
| SHELL-05 | Theme glow fits portrait/landscape; Reduce Motion fades | Simulator screenshots reviewed; physical feel/Reduce Motion walkthrough pending |
| SHELL-06 | Native scroll and chapter swipes remain usable | Reader regression passed |
| SHELL-07 | New activity extends deadline; cancellation cannot trigger a stale hide | Unit tests passed |
| SHELL-08 | Final scroll content fully clears the retained footer, including Settings experiment | Simulator and physical Settings checks passed; Collections/Notes and reader regressions passed |

Checks: focused shell unit/UI tests plus affected reader navigation/scroll tests, signed
build, in-place physical installation, Markdown path validation and `git diff --check`.
Retain artifacts under ignored `build/sp011/`. Physical visual review establishes whether
the motion/glow feels right; simulator screenshots cannot prove that preference.

## Verification and delivery — 2026-09-29

Seven distinct focused checks passed on iPad A16 Simulator / iOS 26.5 across the final
runs: two timer unit tests, three shell UI journeys, and two reader UI regressions.
`build/sp011/shell-r1.xcresult` passed six of seven; its hide test incorrectly equated
retained-view existence with visibility. The corrected hit-reachability check and full
hide → scroll reveal → idle hide → manual reveal journey passed in
`build/sp011/hide-reveal-r2.xcresult`. Landscape screenshot capture now waits for rotation
and uses the full screen; that case passed again in `build/sp011/landscape-r3.xcresult`.
Screenshots in `build/sp011/screenshots-r2/` and `screenshots-r3/` were visually reviewed
for hidden/revealed navigation, light/dark appearance and landscape fit.

The final signed build and local signature verification passed. It installed over the
existing physical iPad app and launched successfully. Evidence:
`build/sp011/device-final-build.log`, `device-final-install.log`, `device-launch.log`.
The final Reduce Motion refinement uses distinct highlight identities to prevent a
selection glide as well as disabling screen travel and glow. The physical Reduce Motion
walkthrough and subjective motion/glow acceptance are not claimed by simulator results.
Markdown local paths and `git diff --check` passed. Existing all-orientation/deprecated
UIKit warnings remain outside this ticket. No data migration or translation sync ran.

Owner review: open Sophia, pause five seconds, scroll to reveal the menu, then switch
among tabs in both directions. Check that slide/glow feels right. The tiny bottom handle
reveals the menu from non-scrolling destinations. This implementation keeps the content
inset constant rather than expanding/reflowing content when the menu disappears.

## Footer reachability follow-up — 2026-09-29

The owner reported the last Settings experiment was obscured when scrolling to the end
and asked to retain the footer while making every tab's content reachable. The focused
baseline UI test reproduced the problem: the final row still extended into the footer
after maximum scrolling (`build/sp011/footer/baseline-r1.xcresult`, failing as expected).
A hittable part of a row is insufficient evidence that its whole content is visible.

RootTabView now stacks the bounded tab viewport and intrinsically sized dock as separate
vertical layout regions, instead of reserving the dock through an outer safe-area inset
that nested Form layout could outgrow. All descendant SwiftUI scroll surfaces receive
20 points of bottom content clearance. Native reader/canvas views receive the bounded
viewport and keep their own content insets. Dock hide/reveal still retains its height.
Settings, Collections and Notes expose stable UI identifiers for end-of-content checks.

Verification covers the full Settings experiment row in portrait/landscape and opening
it, final Collections/Notes content in landscape, reader scroll/chapter swipes and stable
reader geometry through menu hide/reveal. Results: `build/sp011/footer/fix-r2.xcresult` passed 3/3 simulator cases (Settings,
reader gestures, stable menu geometry). `other-tabs-r5.xcresult` passed the Collections/
Notes landscape check. `ipad-r6.xcresult` passed the Settings portrait/landscape check on
the actual iPad, including opening the experiment. Earlier additional runs stopped on
platform-specific scroll-container queries; these queries were corrected without changing
the whole-element footer assertions.

Simulator Settings screenshots and both physical screenshots were reviewed. The signed
fixed app was installed in place by the physical test run, passed local signature
verification and relaunched normally without test environment variables
(`build/sp011/footer/normal-launch.log`). The reader test store was isolated by UUID;
no personal reader preferences, study data or licensed content were replaced. Markdown
paths and `git diff --check` passed. This closes the footer bug; subjective motion review
for the wider SP-011 ticket remains open.


### Owner superseding footer policy — 2026-10-01

The owner subsequently requested removal of reserved footer space everywhere. The
SP-013 theme/workspace correction overlays the dock across all tabs and extends Notes
through the bottom safe area. List scroll clearance retains final-row reachability;
viewport height no longer reserves the dock. All five `ShellNavigationUITests` passed in
`build/sp013/theme-edge/verification.xcresult`, including the prior reachability cases.
This supersedes the separate footer layout above; subjective motion acceptance is unchanged.
