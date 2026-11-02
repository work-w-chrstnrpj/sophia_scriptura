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

## Round 2 — recommendations applied

These change shell behavior, not study data. Screenshots are in `after-r2/`, with side-by-side comparisons against the original baseline in `compare-r2/`.

| # | Recommendation | Implementation |
|---|----------------|----------------|
| R1 | The dock hid after 3 s even on screens that don't scroll | `ShellChromeState.autoHides`: the dock stays pinned on Collections, Notes, Activity and Settings. It still auto-hides (after 3 s) in Scripture, Companion chat, full-screen note editing and Plan playback. It sits behind the keyboard. New unit test: `testPinnedDockStaysVisibleUntilAutoHideResumes`. |
| R2 | Duplicate "add" affordances | When the Add/Start capsule is enabled (Settings › Tab shortcuts), the header `+` is hidden on Notes, Collections and Activity. The capsule now carries the header's accessibility ID (`notes.newNotes` / `collections.newCollection`) and opens the same sheet. With the capsule turned off, the header `+` comes back. |
| R3 | The music button covered reading text | It hides together with the dock. In Scripture it disappears once reading settles and returns when the dock is revealed. |
| R4 | The Archived Plans icon was ambiguous | Archived Collections and Archived Plans now share a single Archive menu (`collections.archive` → `.collections` / `.plans`). |
| R5 | The Settings scroll had 17 sections | At regular width, a section index sidebar jumps to any card. It uses the same glyphs as the card headings. Compact width (Split View/Slide Over) keeps the single column. |
| R6 | The passage picker was misaligned | In wide portrait it is centered over the chapter title. Compact and landscape layouts are unchanged. |
| R7 | Leaving Scripture felt slow | The tab changes immediately and the annotation save finishes in the background. If a pencil stroke or save is still in progress, the old ordering is kept (save first, then switch), so ink is never cut off. |

UI test updates: `ShellNavigationUITests.testLibraryHeadersUsePresetTitleAndExpandableSearch` now asserts that New Note and New Collection appear as the shell capsule below the header, not as items in the header row.

## Verification

- `xcodebuild build` for the iPad simulator: **succeeded**.
- Each tab captured in light mode before and after; Settings also checked in dark mode (`after/07-settings-dark.png`).
- Round 2 (rebased onto SP-058 `5d3eff3`): **512 unit tests passed, 0 failures**. `ShellNavigationUITests`: **11/12 passed**. The one failure, `testSettingsProviderKeysRowIsFullyAboveDockInBothOrientations`, also fails on the original `main` (`2ad3753`), as does `ItemProtectionUITests`, so both failures predate this branch.
- A regression found during testing was fixed before commit: the pinned dock rose above the keyboard and covered fields. The bottom shell overlay now ignores the keyboard safe area.
