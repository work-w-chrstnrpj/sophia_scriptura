# Activity and background music — design specification

Status: owner-approved behavior baseline, 2026-10-02. SP-020 Activity implementation
started 2026-10-03 after the owner postponed M7. Background music is a separate M8
ticket and is not implemented. Requirements: REQ-015, REQ-016, REQ-018 and REQ-025.
Milestone: M8; Activity proceeds before postponed M7.

Related: [product specification](../product-specification/product-specification.md),
[technical design](../tdd/tdd.md), and [app shell](app-shell-specification.md).

## Activity modes and records

The built-in modes are Reading, Studying, Meditating, Journaling, Memorizing Verses and
Reviewing. Reviewing is a distinct Activity type for focused review sessions, including
Quiz Me sessions launched from Companion. The quiz's score, answers and explanations remain
owned by Companion's quiz history; Activity tracks the review session's time and mode.
Every quiz completed through its final summary silently creates a linked Reviewing record,
whether timed or untimed and whether an Activity timer is running. Only active question time
counts; feedback, background and abandoned sessions are excluded. Quiz history deletion
leaves the already recorded Activity time intact. Do not duplicate quiz result data in
Activity records.

The owner may create custom modes. A mode has an ID and display name; icon/color selection
is a proposed presentation detail to review with the screen design. Historical records
must retain a useful mode label if a custom mode is removed or renamed. Archive-versus-
delete behavior for custom modes remains open.

Every saved activity has a required title, mode, activity date and duration. Timer records
also retain actual start/end instants, timezone, and pause intervals. Active duration is
calculated from elapsed time minus paused intervals; a continuously ticking counter is
display only. Backgrounding, device lock and relaunch must not add paused time or lose an
active session.

Manual entry requires title, mode and start date/time. The user supplies either an end
date/time or a duration. End derives duration; duration derives and stores the end. The
form shows the derived value before save. Description is optional. Correcting an existing
record preloads its stored start and end (including timer records with pauses) and replaces
the same record ID, interval and duration on save. A corrected paused timer becomes one
continuous interval from the chosen start to end. Known overlapping intervals are rejected;
records without clock intervals do not block a manual entry on the same day.

For Reading, store an optional structured continuous passage range and selected edition,
independent of the editable description. A generated description may read “Read John
3:16–4:18”. The initial and final references may cross chapters and books. Disconnected
ranges are separate activity records in the first delivery.

## Timed Reading flow

1. The Activity screen offers Start Activity and the six built-in modes plus custom modes.
2. Selecting Reading opens passage selection for edition, book, chapter and starting verse.
3. Title is required on the final record; a suggested title may be prefilled for quick start.
4. Starting the session routes to Scripture and applies a temporary highlight to the
   starting verse. The focus highlight fades without changing annotation visibility or ink.
5. A compact timer item appears in the shared shell control. It can be expanded, paused,
   resumed, or finished from any tab. Paused duration is excluded from active duration.
6. Finish opens a final-verse picker. The inclusive start-to-end reading range, title and
   computed duration are reviewed before save. The chosen design requires an end verse.
   Dismissing review preserves the session as unfinished so the user can return to it.
7. Non-Reading modes do not automatically navigate to another feature in the first
   delivery. They support a title, timer and optional description.

## Meditating journey (SP-022)

Starting **Meditating** from Start Activity asks whether to meditate on a **specific passage**
(same chapter, at most two consecutive verses) or to use **seven curated passages** from a bundled
seed catalog. The timer starts immediately; finishing the journey does not finish the Activity
session.

The journey is a fullscreen overlay above tab content. It hides the tab dock and other shell FABs
but keeps the **background music** floating control and the **Activity recorder** visible and
interactive. Pages:

1. Intro — large serif title: “Meditate with the word & presence of God”, with an animated swipe
   hint on the trailing edge.
2. One or seven scripture pages — reference label and large body text from the active reader
   edition; horizontal swipe moves forward and backward.
3. Closing — “God is with you. Pray & talk to Him.”
4. One more swipe forward exits the journey (Activity timer remains running until the owner finishes
   it from the recorder).

A top-trailing **X** exits the journey at any time. AI-chosen passage sets are out of scope for
SP-022; the seed file may expand without changing the flow.

One running or paused Activity session is proposed at a time. Supporting simultaneous
sessions would make elapsed-time and overlap analytics ambiguous; this limitation needs
owner review before implementation.

## Activity screen and metrics

The SP-020 screen presents Analytics first, then Today, then a five-record History preview.
Analytics has Daily, Weekly, Monthly and Annual periods. Its default filter includes all
activity modes; selecting a mode filters both the distribution pie chart and the bar chart.
The displayed date or range is a button. Daily selects a date; Weekly selects one date and
shows its containing calendar week; Monthly and Annual select a date in the desired period.
The distribution chart uses 40% of the chart row and the horizontally scrollable time chart
uses 60%. **Print Analytics** exports the selected period, date and mode as a PNG with the
whole time axis rendered, including bars outside the on-screen scroll viewport.
The pie chart allocates active minutes by mode. Its card shows color and activity labels
without durations; tapping the card opens a distribution sheet with the pie, each type's
time and percentage. The bar chart plots time on the horizontal
axis and active minutes on the vertical axis. Daily records saved without clock times sit
in a separate **No time** bar so the chart does not imply an hour that was not recorded.
The screen uses the shared paper/soft/ink palette across its full width in light and dark
appearance.

The Today card shows its date, total completed minutes, summed daily goal and one progress
line. Tapping it opens per-activity progress and the streak details. A bottom-right
chevron expands goal editing: enter minutes for each active built-in or custom mode and
save all goals together. Zero means no goal for that mode; at least one minute must remain
across all modes. Existing single goals migrate to a Reading goal, and the total goal is
the sum of all active mode goals. Start Activity is a floating button at the bottom right,
above the tab selector, and opens the mode chooser.
While a session exists, its draggable cross-tab control shows mode and a timer icon when
collapsed. Expanded, it shows a seconds counter and pause/resume and finish icons. Finish
opens the Activity tab and its final review sheet. History's **View all** page groups
records by Today, Yesterday, This Week, This Month, This Year, then older years in descending
order. Tapping a row opens its details; a trailing swipe offers Edit and destructive Delete.
History records can also be corrected and manually entered. **Reminders** is a separate
section after History: it previews five reminders, offers a dashed-outline Add new reminder
row and View all, and gives
rows the same open and swipe Edit/Delete behavior as History. The **Auxiliary** section
has buttons for Add Manual, Custom Modes, Export Data and Restore Data. Print Analytics
is available in the Analytics header. Local analytics include:

- active minutes by day/week/month and by activity mode;
- daily goal progress and current/best streak;
- Reading records and covered passage ranges by book.

The default goal and streak threshold are both 10 Reading minutes per local calendar day;
the total threshold rises or falls with the summed per-mode goals.
The Today display starts the current streak at 1 for the first day of using Activity;
goal qualification still follows the 10-minute threshold and the best streak remains a
record of qualified days.
Completed timer and manual records count toward qualification. Counting custom modes uses
the same rule as the built-in modes as a proposed default; the owner has not explicitly
chosen whether any mode can be excluded from activity totals. The user can change each mode's
daily goal. A single record
that crosses midnight is one activity; how its active minutes are attributed across days is
still open.

The existing request for per-book reading time needs a rule: a cross-book reading record
stores one total duration and a range, which cannot reveal minutes spent in each book.
Do not fabricate time allocation. The owner must choose explicit per-book split markers,
an even/other allocation rule, or a count/range-coverage metric before M8 acceptance.

## Proposed code ownership

SP-020 follows these boundaries for Activity; music remains a later ticket:

- `Features/Activity/` owns the Activity screen, start/finish/manual-entry flows and view
  state. It calls domain operations and does not calculate analytics in SwiftUI views.
- `Core/Activity/` owns mode IDs, Activity records, pause-aware duration, continuous reading
  ranges, goal/streak rules and an inward-facing repository contract.
- `Infrastructure/Activity/` owns local persistence and Activity export/import integration
  after its schema/recovery choice is made. It does not own UI decisions or Analytics views.
- `AppShell/` owns the shared Now Active cluster. A small application audio coordinator
  arbitrates the separate Scripture narration and background-music players.
- `Features/Settings/` owns the Settings music FAB and track library UI. The playback engine
  owns media/session behavior, not Settings or Activity screens.

The implementation ticket must align file paths and storage with the then-current source
tree and M8 backup contract. It must not add a backend or send activity records online.

## Background music

Settings contains a distinct Background Music floating action button. With a track selected,
it plays or pauses; before a track is selected, it opens the music library. The owner can
change tracks there or from the expanded shell item. The app-wide player is independent of
the Activity timer and Scripture narration. Music is instrumental ambient lo-fi with no
vocals, human-composed, and starts only after the user presses Play. The first
release targets 3–5 bundled offline tracks; final tracks are selected after listening.
For every track retain title, composer/performer, source URL, exact license/version, license
evidence, retrieval date, and file digest. Verify both composition and sound-recording
rights before bundling. CC0 is preferred where the human creator has clearly dedicated both
rights; the [CC0 deed](https://creativecommons.org/publicdomain/zero/1.0/) is a reference,
not proof for any specific recording. No final music catalog or track has been approved.

The owner selected Play/Pause, Next and Loop for the first version, using iPad volume.
Shuffle, repeat-one and an in-app volume control are outside the first music ticket.
Settings provides track selection and these playback controls.
The player continues across tabs, app backgrounding and screen lock after explicit playback
start. It does not autoplay on app launch. This requires background-audio behavior and
lock-screen/interruption testing on the owner's iPad.

Starting Scripture narration pauses background music. Choosing Play on music while
narration is active pauses narration first. The Activity timer is unaffected. This rule
avoids competing Sophia audio streams. The owner selected non-mixing behavior: pressing
Play in Sophia takes over from an already playing external app. Merely opening Sophia
or selecting a track must leave external audio alone.

## Shared shell control

One collapsible Now Active cluster sits above the floating tab dock. It contains separate
items for services that are in use: an Activity session appears while running, paused, or
awaiting its final review; a music item appears after the user starts a track and remains
available while manually paused or automatically paused for narration. Stopping/clearing a
service removes its item. If neither service is in use, the cluster is absent.

The compact form shows only active service indicators and essential pause/play actions.
Expand reveals elapsed Activity time, mode, music title, and next/finish controls. The
cluster must respect safe areas and avoid obscuring the tab dock, Pencil palette, Notes
writing surface, Scripture controls and keyboard. The existing Scripture narration
mini-player remains distinct in purpose and participates in the same audio arbitration.

## Decisions and remaining questions

Confirmed by the owner: built-in modes and custom modes, including Reviewing for Quiz Me;
elapsed duration excludes timer pause intervals; one continuous cross-chapter/cross-book
reading range; disconnected
passages use separate records; an ending verse is selected during finish; only Reading
redirects to Scripture; a shared service-aware shell cluster; narration pauses music and
music Play pauses narration; music can continue in background/with screen locked; the
10-minute daily goal/streak default; and human-composed instrumental ambient lo-fi with no
vocals.

The owner revised the Quiz Me boundary on 2026-10-03: completing all questions through the
summary always creates a Reviewing record. Active question duration excludes feedback and
background time and counts toward the normal goal/streak. Abandoned quizzes do not create
one. Quiz history and Activity time can be deleted independently. Activity stores only
duration/date, mode/title and quiz-session ID; answers, scores, sources and explanations
remain in Companion.

Activity reminders are local. A reminder has title, description, date/time, activity mode,
and Once, Daily, Weekdays, Weekends or Weekly recurrence. Saving asks for notification
permission; scheduled notifications use iPad local notifications and show a banner while
Sophia is foregrounded. The reminder form closes after a successful save, has an explicit
close button, and does not dismiss by tapping outside. Each one-time reminder has its own
Delete after it fires setting; selected reminders are pruned the next time Sophia opens or
becomes active. The form contains no reminder list; View all groups recurring and dated
reminders separately. Recurring rules use the selected
time and, for Weekly, the selected weekday; Daily/Weekdays/Weekends begin on the next
matching day. Notification scheduling remains subject to device permission and the iOS
pending-request limit.

SP-020 implementation defaults under owner selection: one timer; timed minutes split at
local midnight; overlapping manual clock intervals rejected; custom modes count toward
streaks and can be archived; cross-book ranges show coverage without invented per-book
minutes. These defaults need physical/owner acceptance before SP-020 closes. Music track
selection remains for the separate music ticket. The owner selected a 3–5 track library,
Play/Pause/Next/Loop with iPad volume, and external-audio takeover on explicit Play on
2026-10-03. [SP-021](../../tickets/SP-021-background-music.md) records the planning
boundary; its track catalog and physical checks remain open.
