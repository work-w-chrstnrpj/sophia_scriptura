# SP-022 — Meditation journey mode

Status: done; owner verified on physical iPad 2026-10-04.

Milestone: M8 Activity phase.

## Outcome

When the owner starts a **Meditating** timed session, Sophia offers an optional specific passage
(up to two consecutive verses in one chapter). Starting the session opens a fullscreen meditation
journey that hides tab content and the tab dock while keeping the **background music** and
**Activity recorder** floating controls available. The owner swipes through an intro, one or seven
large-type scripture pages, a closing prayer prompt, and then returns to the app. Exiting the
journey does **not** finish the Activity timer; the owner still saves or discards the session
manually.

## Scope

- Start Activity sheet: Meditating toggle for specific passage vs seven curated passages.
- Fullscreen overlay: “Meditate with the word & presence of God”, swipe hint, horizontal paging,
  closing “God is with you. Pray to talk to Him.”, top-trailing **X** exit.
- Bundled `meditation-passages.seed.json` catalog (no AI picker in this ticket).
- Core page builder, passage resolver against the active reader edition.

## Exclusions

- Companion-generated passage sets.
- Auto-finish Activity on journey exit.
- Persisting chosen meditation passages on the Activity record.

## Modules

- `Core/Activity/MeditationJourney.swift`
- `Features/Activity/MeditationJourneyCoordinator.swift`, `MeditationJourneyView.swift`
- `Features/Activity/ActivityView.swift`, `RootTabView.swift`
- `Features/Scripture/ReaderSession.swift` (`contentRepository`)
- `Resources/Activity/meditation-passages.seed.json`

## Verification

- Unit: `ActivityTests` meditation rules and page counts.
- Manual: start Meditating with and without specific passage; swipe full journey; exit via **X** and
  via swipe past closing; confirm music FAB and recorder remain usable; finish Activity separately.

## Gaps

- The full simulator unit suite passed 180/180, including the meditation rules and page-count tests, in `build/commit-20261004/unit-r2.xcresult` on 2026-10-04.
- Physical iPad walkthrough not yet recorded.
- AI-curated seven-passage sets deferred.
