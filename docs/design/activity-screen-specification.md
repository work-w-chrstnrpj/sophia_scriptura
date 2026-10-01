# Activity and background music — design specification

Status: owner-approved behavior baseline, 2026-10-02, with Reviewing added as a built-in
activity type for Quiz Me and its linkage policy approved through SP-016. This is planning only. Activity and background
music are not implemented. Requirements: REQ-015, REQ-016, REQ-018 and REQ-025.
Milestone: M8, after Scripture narration in M7.

Related: [product specification](../product-specification/product-specification.md),
[technical design](../tdd/tdd.md), and [app shell](app-shell-specification.md).

## Activity modes and records

The built-in modes are Reading, Studying, Meditating, Journaling, Memorizing Verses and
Reviewing. Reviewing is a distinct Activity type for focused review sessions, including
Quiz Me sessions launched from Companion. The quiz's score, answers and explanations remain
owned by Companion's quiz history; Activity tracks the review session's time and mode.
Quiz setup defaults **Record this as Reviewing** on and permits opting out. A completed or
intentionally ended recorded session creates a linked Reviewing record; active quiz time
counts toward the normal goal and streak. Abandoned sessions require manual saving. Do not
duplicate quiz result data in Activity records.

The owner may create custom modes. A mode has an ID and display name; icon/color selection
is a proposed presentation detail to review with the screen design. Historical records
must retain a useful mode label if a custom mode is removed or renamed. Archive-versus-
delete behavior for custom modes remains open.

Every saved activity has a required title, mode, activity date and duration. Timer records
also retain actual start/end instants, timezone, and pause intervals. Active duration is
calculated from elapsed time minus paused intervals; a continuously ticking counter is
display only. Backgrounding, device lock and relaunch must not add paused time or lose an
active session.

Manual entry requires title, mode, date and duration. Start/end clock times are optional.
When both are supplied, duration is calculated from them. Otherwise the user enters the
duration. Description is optional. Overlap validation and how to handle manual entries
that cross midnight remain open policy decisions; the implementation must not silently
double-count an overlap.

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

One running or paused Activity session is proposed at a time. Supporting simultaneous
sessions would make elapsed-time and overlap analytics ambiguous; this limitation needs
owner review before implementation.

## Activity screen and metrics

The screen is organized around Today, Start Activity, History and Insights. Start Activity is
the Activity tab's floating action button; it opens the mode chooser. While a session exists,
its controls move to the shared Now Active cluster so they remain available on every tab.
History records can be corrected and manually entered. Local analytics include:

- active minutes by day/week/month and by activity mode;
- daily goal progress and current/best streak;
- Reading records and covered passage ranges by book.

The default goal and streak threshold are both 10 active minutes per local calendar day.
Completed timer and manual records count toward qualification. Counting custom modes uses
the same rule as the built-in modes as a proposed default; the owner has not explicitly
chosen whether any mode can be excluded. The user can change the daily goal. A single record
that crosses midnight is one activity; how its active minutes are attributed across days is
still open.

The existing request for per-book reading time needs a rule: a cross-book reading record
stores one total duration and a range, which cannot reveal minutes spent in each book.
Do not fabricate time allocation. The owner must choose explicit per-book split markers,
an even/other allocation rule, or a count/range-coverage metric before M8 acceptance.

## Proposed code ownership

These responsibilities guide the future M8 ticket; no such modules exist yet:

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
release targets a small bundled offline library; final tracks are selected after listening.
For every track retain title, composer/performer, source URL, exact license/version, license
evidence, retrieval date, and file digest. Verify both composition and sound-recording
rights before bundling. CC0 is preferred where the human creator has clearly dedicated both
rights; the [CC0 deed](https://creativecommons.org/publicdomain/zero/1.0/) is a reference,
not proof for any specific recording. No final music catalog or track has been approved.

Settings should provide track selection, play/pause, next track, volume and repeat/shuffle
preferences. Whether the first version needs shuffle or adjustable volume remains open.
The player continues across tabs, app backgrounding and screen lock after explicit playback
start. It does not autoplay on app launch. This requires background-audio behavior and
lock-screen/interruption testing on the owner's iPad.

Starting Scripture narration pauses background music. Choosing Play on music while
narration is active pauses narration first. The Activity timer is unaffected. This rule
avoids competing Sophia audio streams; behavior with external/system audio is separate.

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

SP-016 resolves the Quiz Me boundary: **Record this as Reviewing** defaults on and can be
disabled before the session. A completed or intentionally ended recorded quiz creates a
linked Reviewing record; its active question/feedback duration excludes pause/background
time and counts toward the normal goal/streak. An abandoned quiz is not recorded
automatically. Activity stores only duration/date, mode/title and quiz-session ID; answers,
scores, sources and explanations remain in Companion.

Still to decide before M8 implementation: per-book minutes allocation, midnight
accounting,
manual-entry overlap handling, simultaneous timers, custom-mode archive/delete and streak
eligibility, music track selection and whether volume/repeat/shuffle controls are needed in
v1. Proposed defaults may be refined in an implementation ticket, but must not be presented
as owner decisions.
