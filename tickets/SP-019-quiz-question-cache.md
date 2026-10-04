# SP-019 — Quiz question cache and background replenishment

- Milestone: M6 Stateful Companion.
- Type: implementation. Status: done; owner verified on physical iPad 2026-10-04.
- Selected by owner: 2026-10-02.
- Two-quiz refill follow-up selected: 2026-10-03.

## Outcome

Quiz Me now targets up to 36 prepared questions per selectable game type: 20 Easy, 10 Average, and 6 Difficult. A quiz whose selected buckets have enough questions starts from the local cache without waiting for a provider response. Consumed questions leave the cache when the session is created, including if the session is later abandoned. Missing questions are requested during in-app background work and published only after the whole response validates.

The first quiz for an empty bucket still waits for generation and is labeled “Prepare first quiz.” iOS may stop an in-app refill after suspension or termination; the app recomputes deficits on the next load or Quiz Me entry. No iOS BGTask was added.

The follow-up targets two ready quizzes per bucket (20 Easy, 10 Average, 6 Difficult per type). It fills one playable quiz across buckets before spare capacity, then reconciles again on completion, quit or foreground return as well as on start. A newer priority request interrupts the refill order at the next provider-batch boundary instead of being dropped. Failed in-app warmups retry with bounded backoff; neither an empty cache nor suspended app can guarantee a zero-wait start.

## Boundaries

- Six selectable types: Identify the Verse, Scripture or Cap, Who Said It?, Christian History, Bible Quiz, Bible or False.
- Cache scope includes provider configuration, adapter, model, edition, difficulty, type, and prompt contract version. Provider keys stay in Keychain.
- Mixed sessions allocate only the selected difficulty's total question count across selected types.
- Full latest-question lists are no longer sent to the provider. Local validation checks normalized exact and strong word-overlap duplicates against cached and historical questions.
- AI answer keys and citations remain provisional; factual and perceived-difficulty review needs a real provider and the owner.

## Acceptance and checks

- Warm start uses no provider request; questions move into a session with fresh identifiers and choice positioning.
- Cache persists in Companion schema v3; v1/v2 loads default to an empty cache.
- Refill computes the exact deficit per bucket and caps publication at the bucket target.
- Malformed/refused refill leaves the existing cache intact.
- Focused XCTest: `build/sp019-cache-final-r2.xcresult` on iPad (A16) Simulator / iOS 26.5:
  25 passed, 0 failed, 0 skipped across `CompanionTests` and `QuizMeTimerTests`.
- The signed Debug app passed strict `codesign --verify --deep --strict` and retained
  `com.personal.SophiaScriptura`. It installed in place and launched on `iPad ni Paj`
  (paired physical iPad A16) on 2026-10-02. No uninstall or data reset was performed.
- `git diff --check` passed. Real-provider quality and perceived first-run timing remain
  owner acceptance checks; installation and launch do not prove those interactions.
- Follow-up focused XCTest: `build/sp019-two-quiz-cache-final-r3.xcresult` on iPad (A16)
  Simulator / iOS 26.5: 26 passed, 0 failed, 0 skipped, including spare readiness after
  reservation and completion/quit lifecycle checks. On 2026-10-03, the signed Debug app
  passed strict signature verification, installed in place on the paired physical iPad A16,
  and launched as `com.personal.SophiaScriptura`. No uninstall or data reset was performed;
  real-provider speed and quality remain owner acceptance checks.
