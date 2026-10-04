# SP-021 — Offline background music

Milestone: M8. Status: done; owner verified on physical iPad 2026-10-04. Core playback, shell cluster and Settings wiring shipped 2026-10-03; track catalog uses integration placeholders (commercial rights not approved). M7 Scripture narration is abandoned 2026-10-04.

## Usable outcome

The owner can choose from 3–5 bundled, rights-verified, human-composed instrumental ambient lo-fi tracks and listen while studying across tabs, app backgrounding and screen lock. Music starts only after Play. It does not change Activity time.

## Confirmed first-version choices

The owner selected 3–5 verified offline tracks; Play/Pause, Next and Loop with iPad
volume; and takeover rather than mixing when Sophia Play is pressed while another app
is playing audio. Loop semantics and post-interruption resume are awaiting the owner's
answer. The details below are proposed defaults until then.

## Proposed playback details

- Settings has a distinct Background Music action. Before a track is selected, it opens the library; after selection, it plays or pauses. The expanded Now Active item shows title and Next; the compact item shows Play/Pause.
- Controls are Play/Pause, Next and a loop-all toggle. The iPad's volume controls set loudness. Shuffle, repeat-one and an in-app volume control are outside this ticket.
- The chosen track and loop-all preference persist. Relaunch restores the selection in a paused state; there is no launch autoplay. Next wraps to the first track when loop-all is on. At the end of the library with loop-all off, playback stops.
- Pressing Sophia Play takes over from another app's audio; Sophia does not mix with external audio. Merely opening Sophia or selecting a track does not take over audio. If the system interrupts playback or headphones disconnect, music pauses and waits for an explicit Play to resume.
- Music can continue across tabs, app backgrounding and screen lock after explicit Play. A manually paused or narration-paused music item stays in Now Active; Stop/Clear removes it. The Activity timer remains independent.
- When M7 narration arrives, starting narration pauses music; pressing music Play pauses narration first. M7 implements its side of this shared audio coordinator rather than being pulled into SP-021.

## Track selection gate

No track is approved yet. Research a short candidate list, listen with the owner, and bundle only 3–5 accepted files with evidence for both the composition and recording. Prefer a human creator's CC0 dedication covering both rights or an explicit written reuse permission that permits bundling in the app. For each exact file retain title, composer, performer/recording owner, source URL, license text/version or permission, evidence capture date, file digest and attribution requirements. A CC0 license page by itself is not proof for a particular recording. Reject tracks with unclear ownership, vocals, AI-generated provenance, or rights limited to streaming.

## Proposed ownership and dependency direction

- `Core/Music/` owns track metadata and playback intent/state values.
- `Infrastructure/Music/` owns the bundled catalog, rights manifest validation and `AVAudioPlayer` or equivalent local playback adapter.
- `AppShell/` owns one small audio coordinator and the music item in Now Active.
- `Features/Settings/` owns library selection and the Background Music action.
- UI sends commands to the player/coordinator; Activity records never depend on music state.

These are proposed paths to reconcile against source when execution is selected. No backend, streaming service, provider key, or licensed download is in scope.

## Acceptance and verification

1. Every shipped track has reviewed provenance, composition and recording rights, exact-file digest and required attribution. The owner approves the listening shortlist before bundling.
2. Play, pause, Next, loop-all and Settings/shell state work without network access. Relaunch stays paused on the last selected track.
3. Background, lock screen, route changes, interruptions and external-audio takeover behave as stated on the owner's iPad. Playback never starts from app launch, tab navigation, timer start or track selection alone.
4. Music and Activity operate independently. The M7 coordinator contract is tested with a narration stub or model, with full narration arbitration deferred to M7 physical acceptance.
5. Automated catalog/state tests and relevant shell UI tests pass; physical listening and controls are checked at normal and larger text sizes.
6. Update the Activity/music design, app-shell specification, TDD, product and development plan, repository map, test guide, attribution page and track evidence records with implementation results.

## Stop conditions

Do not bundle a candidate with missing composition or recording permission. Do not claim lock-screen, route or interruption acceptance from simulator tests alone. Do not begin this ticket merely because it exists.
