# UI/UX Review — Visual Polish Pass

Branch: `ui-ux/visual-polish` (from `2ad3753`). Presentation-only changes: no store, session, persistence, or navigation logic was modified.
Device: iPad Pro 13-inch (M5) simulator, Old Paper preset, light mode (plus one dark-mode check).

- `before/` — baseline screenshots
- `after/` — same screens with this branch applied
- `compare/` — side-by-side before/after per tab

> Capture note: the tab dock auto-hides after 3 s, which is shorter than the time between simulator taps. For screenshots only, the delay was temporarily raised in the build. That change is **not** committed; `ShellChromeState.visibilityDelay` is still 3 s.

## Applied changes

| # | Area | Problem observed | Change |
|---|------|------------------|--------|
| 1 | Tab dock | Labels sat on different baselines (Companion and Settings were lower) because SF Symbols have different heights. The selected tab differed only by a faint wash. | Icons sit in a fixed 32×24 box so all labels line up. The selected tab uses the filled symbol in the accent color with a semibold label. The dock shadow is a little deeper so it separates from the page. |
| 2 | Hidden-dock handle | When the dock auto-hides, the only way back was a 28×4 pt grey line that was hard to see. | Replaced with a `chevron.compact.up` capsule on a material background. The hit area is the same or larger (72×44). |
| 3 | Cards (Settings, Activity, analytics, history detail, delete-data) | Flat 7% grey panels read as disabled or inset, not as content. | New `studyCard()` modifier: an opaque card tone (page color blended 2.5% toward ink, 6% in dark mode), a hairline border and a soft shadow in light mode only. It uses one token everywhere instead of 8 copied background/overlay pairs. |
| 4 | Note cards | Same flat grey fill. | They use the new `palette.card` tone. |
| 5 | Notes / Collections headers | 6–7 unlabeled glyphs floated loose in the header. | Grouped into one capsule command cluster. When search is open, the search field sits beside the cluster instead of inside it. The lock control now has a 44 pt hit target. |
| 6 | Settings | On a 13" iPad the cards stretched to ~1,000 pt wide. The first card (Companion) had no heading. Seventeen sections had no visual landmarks. | Content is centered at a max width of 860 pt. Added a "Companion character" heading. Each section heading has a tinted SF Symbol so the long scroll is easier to scan. |
| 7 | Companion empty state | The system title didn't match the serif empty states in Notes and Collections, and the body text ran full width. | Serif title, hierarchical tinted icon, description limited to 420 pt. |
| 8 | Copy | The empty-state button said "New Notes" while the FAB said "Add Note". | Changed to "New Note" (button and accessibility label). No tests referenced the old string. |

Files touched: `DesignSystem/StudyCard.swift` (new), `DesignSystem/ScriptureAppearance.swift` (`card` token), `RootTabView.swift`, `Features/Settings/SettingsView.swift`, `Features/Settings/SettingsDeleteDataSection.swift`, `Features/Activity/ActivityView.swift`, `Features/Activity/ActivityAnalyticsView.swift`, `Features/Activity/ActivityHistoryView.swift`, `Features/Notes/NotesView.swift`, `Features/Notes/NoteLibraryCard.swift`, `Features/Collections/CollectionsView.swift`, `Features/Companion/CompanionView.swift`.

## Recommendations not applied (they touch behavior or need your call)

1. **The dock hides after 3 s even on screens that don't scroll** (empty Notes, Companion). Consider hiding only on downward scroll in Scripture and keeping it visible elsewhere, or raising the delay to about 6 s. `ShellChromeStateTests` asserts 3 s.
2. **Three "add" affordances on one screen.** Collections shows a header `+`, an empty-state "New Collection" button and the "Add Collection" FAB. Activity shows a header `+`, an "Add or start a new activity" row and the "Start Activity" FAB. Pick one primary path per tab (the FAB) and hide the header `+` while the FAB is enabled.
3. **The floating music button covers reading text.** It sits over the scripture column (bottom-left in Scripture and Settings). Consider anchoring it inside the dock row or fading it while scrolling.
4. **Archived Plans icon (`list.bullet.rectangle`)** is hard to tell apart from a list/view toggle. Consider folding Archived Plans and Archived Collections into one "Archive" menu.
5. **The Settings scroll has 17 sections.** On iPad, a `NavigationSplitView` with a section sidebar (the same pattern Companion already uses) would remove the long scroll.
6. **Scripture passage picker** (`Genesis | WEB`) is offset from both the title and the reading column. Align it to the reading column's leading edge or center it over the chapter title.
7. **Leaving Scripture can feel slow:** tab switching awaits `annotations.prepareForNavigation()` before the selection changes. Switching the highlight first and saving afterwards would make taps feel immediate. This is a logic change, so it is listed here only.

## Verification

- `xcodebuild build` for the iPad simulator: **succeeded**.
- Each tab captured in light mode before and after; Settings also checked in dark mode (`after/07-settings-dark.png`).
- Unit and UI test suites were **not** run on this branch.
