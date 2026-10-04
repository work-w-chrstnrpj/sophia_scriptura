# SP-017 — Maintainability hardening and responsibility extraction

- Type: refactor and engineering-quality chore. Status: done; closed without implementation at M9 2026-10-04 (owner did not select).
- Milestones: cross-cutting M0/M1 engineering quality and M9 integrated acceptance.
- Requirements: supports REQ-021 quality, recovery and maintainability; no new product
  requirement or user-visible feature.
- Owners: System Architect coordinates boundaries; Frontend UI/UX Developer owns view and
  session extractions; SQA Engineer owns regression gates; Technical Documentation
  Specialist owns maps and evidence reconciliation.
- Created from read-only source assessment: 2026-10-02.
- Owner selection: closed without implementation at M9 2026-10-04. Reopen only with an explicit new selection.
- Execution branch: before any implementation edit, create and switch to the dedicated branch
  `refactor/sp-017` from the owner-approved clean
  baseline. Implementation must not begin on `main`, another feature branch or a dirty
  checkout containing uncheckpointed overlapping work.

## Purpose

Keep Sophia's current architecture understandable and inexpensive to change as Scripture,
Notes, Collections and Companion accumulate behavior. The repository has a sound high-level
shape (`Core`, `Infrastructure`, `Features`, `DesignSystem`, `AppShell`) and real repository,
validation and recovery boundaries. The risk is concentrated responsibility inside several
feature sessions and views, weak automated enforcement of the intended quality baseline,
and discovery documentation that has fallen behind implementation.

This is bounded hardening, not a rewrite. Complete it in small behavior-preserving slices.
Do not combine all work packages into one large mechanical change.

## Current evidence and findings

The 2026-10-02 audit built the exact working tree successfully for the installed iPad (A16)
Simulator / iOS 26.5. The build still emitted warnings for deprecated iOS 17 text-link
delegates, an inconsistent capture in `ScriptureView`, and an unused binding in
`AnnotationSession`. SwiftLint was not available on the audit machine.

| Priority | Finding | Current evidence | Why it matters |
| --- | --- | --- | --- |
| P0 | The current Companion implementation is uncommitted/in progress | New `Core/Companion`, `Infrastructure/Companion`, `CompanionSession`, provider settings, resources and tests exist outside the last committed baseline | Do not refactor a moving feature or mistake build success for accepted behavior |
| P1 | `NoteCanvasSurface.swift` has excessive responsibility density | About 720 lines spanning UIKit/PencilKit lifecycle, viewport synchronization, text, ink, gestures, selection, links, rendering and accessibility | Changes in one interaction mode can regress unrelated editor behavior |
| P1 | `ScriptureView.swift` is becoming a feature hub | About 559 lines spanning reader presentation, selectors, versions, Verse Hub, save/copy/share/link actions and notifications | Reader layout and study-artifact workflows no longer change independently |
| P1 | `CollectionsStore.swift` combines multiple layers | About 513 lines spanning hierarchy, membership policy, artifact commands/queries, validation and persistence scheduling | Domain rules, persistence timing and presentation queries are hard to test in isolation |
| P1 | `NotesSession.swift` coordinates too many workflows | About 335 lines spanning library/editor state, selection, history, autosave, recovery, media decoding, previews, quotation insertion and UIKit callbacks | The session is a high-change dependency and difficult to reason about as a unit |
| P1 | `RootTabView` is both navigation shell and composition root | It constructs repositories/sessions and also owns tab UI, lifecycle, cross-feature routing and annotation transition gates | Dependency construction cannot be tested or changed independently from navigation |
| P1 | Quality rules are advisory rather than enforced | Minimal `.swiftlint.yml`; SwiftLint unavailable; project language setting is `SWIFT_VERSION = 5.0`; strict-concurrency and warnings-as-errors gates are not enabled | New debt can enter without failing a normal verification command |
| P2 | Discovery maps are stale | `.ai/maps/application-map.md` still calls Collections an in-memory prototype without production persistence | Agents and contributors can make decisions from obsolete architecture claims |
| P2 | Empty Phase-era boundary markers remain | `Core/ModuleBoundaries.swift` contains empty marker protocols while concrete feature contracts now exist elsewhere | Duplicate architecture vocabulary obscures the true dependency boundaries |
| P2 | A few forced operations remain | Current Companion code uses `record!`; preview/bootstrap paths use `try!` or `preconditionFailure`; other constant URLs/fonts use force unwraps | Normal runtime paths should return typed failures; invariant-only uses must be explicit and tested |

Line count is a discovery signal, not an acceptance rule. A file fails this ticket only
when it owns unrelated reasons to change or prevents focused testing. Do not split files
into arbitrary extensions merely to reduce their size.

## Visible outcome

There is intentionally no product redesign. After completion:

- Scripture, annotations, Notes, Collections, Companion and the tab shell behave the same.
- Existing local reader, licensed-edition, annotation, Notes and Collections data reopen
  without migration or reset.
- Dependency creation is isolated from tab navigation.
- The identified feature hotspots delegate cohesive operations to named collaborators.
- Normal app code contains no unjustified forced unwrap/cast/try introduced or retained in
  the selected scope.
- The simulator build is warning-free for project-owned source, lint is reproducible, and
  concurrency checks have an explicit recorded level.
- Architecture maps describe the source that actually ships.

## Non-negotiable behavior-preservation rules

1. Do not alter persisted schemas, store locations, encryption, generation validation,
   recovery behavior, backup formats or compatibility decoding.
2. Do not change fixed-coordinate Notes behavior, PencilKit ownership, viewport mapping,
   undo/redo semantics, autosave ordering, or the Canvas/Page storage distinction.
3. Do not change licensed-content authorization, cache/lease behavior, quotation handling,
   or the data sent to external Companion providers.
4. Do not change Collections membership, No Folder virtualization, remove-versus-delete,
   or shared-artifact semantics.
5. Do not replace concrete feature contracts with a generic repository/service framework.
6. Do not add third-party architecture or dependency-injection packages. A small native
   composition value is sufficient.
7. Do not mix this ticket with UI redesign, feature requests, schema upgrades or M6/M7/M8
   implementation.
8. Preserve accessibility identifiers relied on by UI tests.

## Exclusions

- Rewriting SwiftUI/UIKit/PencilKit surfaces.
- Converting all state management to a new pattern.
- Moving the project to multiple Swift packages or framework targets.
- Changing `ObservableObject`/Observation solely for stylistic uniformity.
- Redesigning the tab dock, Verse Hub, Notes editor, Collections library or Companion.
- Replacing JSON/Core Data/SwiftData stores or consolidating their data.
- Raising deployment targets.
- Resolving deferred physical Pencil, VoiceOver or product acceptance unrelated to a
  regression caused by this ticket.
- Completing the in-progress Companion feature. Companion must reach its own selected
  ticket boundary before its internals are restructured here.

## Mandatory execution precondition — create the branch first

After the owner explicitly selects SP-017, but **before making any implementation, test,
configuration or implementation-driven documentation edit for this ticket**:

1. Inspect `git status`, the current branch, its upstream and all untracked files.
2. Finish, pause with an owner-approved recoverable checkpoint, or otherwise isolate the
   current Companion work. Do not carry uncommitted overlapping feature work into SP-017
   accidentally and do not discard it.
3. Confirm the exact owner-approved starting commit. Do not assume `main` is the correct
   baseline when a later accepted feature branch contains required work.
4. Create and switch to the dedicated `refactor/sp-017` branch before execution.
5. Verify the new branch points at the approved starting commit and has the intended clean
   or explicitly documented carried state.
6. Record the branch name and starting commit in this ticket before the first source change.

If a clean branch cannot be created without risking current work, stop. Preserve the work in
a commit or managed worktree according to the owner's direction, then create the SP-017
branch. Branch creation is an execution gate, not an optional cleanup step after coding.

## Implementation sequence

Each work package should be independently reviewable and leave the build green. Commit or
otherwise checkpoint after each package. If a package requires a schema or visible behavior
change, stop and return it to the owner as a separate ticket.

### WP0 — Freeze the baseline and reconcile concurrent work

1. Complete the mandatory branch precondition above and confirm execution is occurring on
   the dedicated SP-017 branch.
2. Record `git status`, branch/upstream, starting commit and the exact Companion work state.
3. Do not overwrite, absorb or reformat uncommitted work from another task.
4. Finish, pause or separately checkpoint the active Companion slice before refactoring
   files it touches (`RootTabView`, `SettingsView`, Companion sources and tests).
5. Run a clean simulator build and the existing full unit suite. Record existing warnings
   and failures before structural edits.
6. List storage fixtures/generations that must be preserved for reopen testing.

Exit: the dedicated branch and reproducible pre-refactor baseline are recorded and existing
failures are distinguishable from regressions.

### WP1 — Clear warnings and unsafe normal-flow operations

1. Replace the deprecated `UITextViewDelegate` URL interaction methods in
   `NoteCanvasSurface` and `ReaderTextSurface` with the iOS 17 text-item delegate APIs while
   preserving citation, Scripture-anchor and external-link behavior.
2. Make the `ScriptureView` annotation capture ownership explicit and remove the unused
   `AnnotationSession` layer-index binding.
3. Replace `record!` in `CompanionSession.saveProviderKey` with a single typed creation/update
   path. A missing catalog/resource in normal launch must produce an explicit contained
   failure rather than a crash. Preview-only invariants may remain only when clearly scoped.
4. Audit project-owned `try!`, `as!`, `fatalError`, `preconditionFailure` and force unwraps.
   Classify each as normal flow, impossible initializer path, preview/test fixture or static
   constant. Remove normal-flow cases and document the few retained invariants inline.

Exit: the app target builds without project-owned warnings and has no unexplained forced
operation in a normal user path.

### WP2 — Introduce a small composition root

Create a focused `AppContainer` or `AppDependencies` value near the app entry point.

It should construct and retain only long-lived dependencies such as:

- reader repositories/state and `ReaderSession`;
- annotations and Notes sessions;
- Collections repository/store;
- Companion repository, credential store, provider registry and session;
- test-specific dependency overrides already controlled by environment variables.

`SophiaScripturaApp` creates the live container and injects it into `RootTabView`.
`RootTabView` continues to own tab selection, navigation presentation, shell animation,
cross-feature route handling and scene lifecycle. Do not introduce a service locator or
allow features to pull dependencies from a global singleton.

Tests:

- construct a deterministic test container without touching production directories;
- verify live construction selects the current store locations and bundled resources;
- retain the existing `SP009_TEST_STORE` isolation behavior.

Exit: `RootTabView` no longer contains concrete production repository construction.

### WP3 — Extract cohesive Notes collaborators

Perform these as separate steps; retain `NotesSession` as the feature facade used by views.

1. `NoteHistory`: own `Edit`, bounded undo/redo stacks, byte budgeting and replay. It must
   preserve exact current object ordering, Page state and the 80-entry/24 MiB limits.
2. `NoteAutosaveCoordinator`: own revision/write serialization, delayed save scheduling,
   flush and retry state. Surfaces still never write files directly.
3. `NoteMediaImporter`: validate source bytes, decode/thumbnail images, enforce size limits
   and return a domain result; it must not mutate editor selection.
4. `SaveScriptureSelectionToNote` (or comparably specific operation): validate a quote and
   append/insert it using the established Canvas/Page rules. Keep licensed-content
   authorization outside this operation.
5. Keep selection, active note identity and user-facing editor commands in `NotesSession`.

Required characterization tests before moving logic:

- undo/redo after object insert, delete, move, grouping and Page attachment changes;
- history eviction by count and byte budget;
- autosave coalescing, flush, failure and retry;
- image limits and failed decode;
- quote append when no meaningful caret exists;
- legacy note reopen without conversion.

Exit: each extracted collaborator has focused unit tests and `NotesSession` remains the
single view-facing coordinator.

### WP4 — Decompose the production Notes surface by responsibility

Keep the SwiftUI representable and controller entry points stable. Prefer private helper
types with explicit inputs over a collection of global utilities.

Candidate ownership:

- viewport/zoom/content-offset synchronization;
- PencilKit canvas and tool-picker lifecycle;
- Canvas text-object editing;
- Page text/citation interaction;
- gesture and selection routing;
- accessibility projection;
- object rendering/layout reconciliation.

Rules:

- preserve document-coordinate storage and fixed body coordinates;
- preserve live `PKCanvasView` viewport sizing and canonical ink mapping;
- controllers retain UIKit/PencilKit lifecycle ownership;
- no collaborator may persist files or reach into unrelated feature sessions;
- avoid splitting methods that share delicate UIKit lifecycle state unless the new owner
  receives that state explicitly.

Verification must include existing Notes unit/UI suites plus rotation, zoom, theme cycle,
save/reopen and memory-sensitive ink checks. Physical Pencil acceptance remains distinct.

Exit: responsibilities are named and testable; the split is not merely cosmetic.

### WP5 — Extract Verse Hub from Scripture presentation

Move Verse Hub presentation and its local action state into a dedicated feature component,
for example `Features/Scripture/VerseHub/`, while keeping `ReaderSession` responsible for
reader/navigation state.

Separate:

- hub section composition and empty states;
- folder-name projection for bookmarks/gleanings;
- Add Link validation and No Folder command;
- copy notification timing;
- share payload/presentation;
- routing callbacks for Notes, Collections, links and future conversations.

Do not move collection mutations into a view. Expose explicit commands/callbacks and retain
licensed-content authorization before copy/share. Preserve popover/sheet behavior on iPad.

Tests must cover folder/no-folder labels, gleaning presentation, valid/invalid link input,
brief copy confirmation, share payload, and licensed-content denial.

Exit: `ScriptureView` composes the reader and Verse Hub but does not implement all hub flows.

### WP6 — Separate Collections policy, queries and persistence coordination

Retain `CollectionsStore` as the observable view-facing facade. Extract only cohesive logic:

- `CollectionHierarchy` or equivalent pure functions: descendants, cycle prevention,
  promotion and sorted outline;
- `CollectionMembershipPolicy`: assign/move/remove, No Folder derivation and shared-artifact
  rules;
- persistence scheduling/write serialization into a small coordinator if it is currently
  coupled to every mutation;
- optional read-only projections for folder counts and artifact sections.

Do not duplicate canonical state between collaborators. Mutations should produce one new
validated snapshot that the store publishes and schedules for persistence.

Tests must retain hierarchy cycle rejection, child promotion, multiple membership, No
Folder, move/assign non-loss, personalized icons, verse-linked links and reopen behavior.

Exit: hierarchy/membership rules run as deterministic unit tests without constructing UI.

### WP7 — Review Companion after its implementation boundary stabilizes

Do not execute this package while Companion is still concurrently changing. Once its own
implementation ticket has a green baseline:

1. Keep `CompanionSession` as the view-facing coordinator.
2. Extract stream/request lifecycle if retry, cancellation and partial-response state make
   it independently testable.
3. Keep prompt construction in `CompanionContextBuilder`, credentials in Keychain
   infrastructure, provider behavior behind adapter contracts, and file generations in the
   repository.
4. Ensure no API key enters snapshots, logs, prompts, exports or test fixtures.
5. Make save/write ordering use the same explicit coordinator pattern selected elsewhere;
   do not force a shared generic abstraction.

Tests must cover missing key, connection failure, cancel, partial stream, retry, offline,
provider switch, persistence recovery and credential exclusion.

Exit: session responsibilities are cohesive and every provider adapter passes the same
contract tests.

### WP8 — Remove obsolete boundaries and repair discovery documentation

1. Compare each empty protocol in `Core/ModuleBoundaries.swift` with actual domain/repository
   contracts. Remove superseded markers. Keep or implement one only when code genuinely
   depends on it.
2. Update `.ai/maps/application-map.md`, `data-map.md`, `testing-map.md`, API map and the
   repository map in `AGENTS.md` to describe current persisted Collections and Companion
   boundaries.
3. Reconcile historical “Not Run” statements with durable ticket evidence without erasing
   honest physical-device gaps.
4. Update the TDD only for architecture decisions actually implemented by this ticket.

Exit: maps are accurate discovery aids and do not claim prototypes where production paths
exist.

### WP9 — Make quality checks reproducible and enforceable

1. Expand `.swiftlint.yml` with initially non-disruptive thresholds for type body length,
   function body length, cyclomatic complexity, nesting, force cast/try and file length.
   Baseline existing exceptions explicitly with owner/reason; do not blanket-disable rules.
2. Add the documented lint command to the normal verification workflow. If installing
   SwiftLint is intentionally optional, provide a pinned, reproducible alternative and make
   the limitation explicit.
3. Reconcile the documented Swift 5.9+ toolchain requirement with Xcode's current Swift
   language-mode setting. Record the chosen language mode; do not change it blindly merely
   because `SWIFT_VERSION = 5.0` looks old.
4. Enable strict concurrency incrementally: first compile with targeted or minimal checking,
   fix actionable warnings, then raise enforcement only when the app and test targets pass.
5. After the warning baseline is zero, enable warnings-as-errors for project-owned Debug
   builds or provide an equivalent verification command. Do not allow SDK/toolchain warnings
   outside project control to make local development unusable.
6. Keep tests out of production lint inclusion only when a separate test lint invocation
   covers them.

Exit: a clean checkout can run the documented build, tests, lint and concurrency checks and
receive the same result as the ticket evidence.

## Acceptance criteria

- Implementation began on a dedicated SP-017 branch created before the first execution
  change; the branch name and starting commit are recorded in the ticket evidence.
- All behavior-preservation rules above are met.
- No persistence schema/version/store-path change is present in the final diff.
- Existing owner data opens after an in-place device install; no uninstall/reset is used.
- Production simulator build completes with no project-owned warnings.
- Full unit suite passes, not only newly added collaborator tests.
- Relevant Notes, Scripture/Verse Hub, Collections, annotations, shell and Companion UI
  regressions pass for packages that touched those features.
- Focused tests exist for every extracted collaborator and failure path.
- `RootTabView` does not construct concrete production repositories.
- Views do not write files, access Keychain directly or call provider networking directly.
- Core has no UIKit, PencilKit, file-system, Keychain or provider SDK dependency.
- Infrastructure does not import feature views or mutate view state.
- No new global singleton/service locator is introduced.
- No unexplained normal-flow forced unwrap/cast/try remains in the selected scope.
- SwiftLint and concurrency commands are documented and reproducible.
- `.ai/maps/`, `AGENTS.md`, testing docs and this ticket match the final source.
- `git diff --check` passes and the staged-path audit excludes build products, result
  bundles, credentials and private local configuration.

## Required verification

Use the currently installed simulator rather than assuming a device model. Exact commands
must follow `docs/testing/test-specification.md` and `docs/deployment/deployment.md`.

Minimum gates:

1. Clean simulator build before and after each work package.
2. Full `SophiaScripturaTests` suite after each collaborator extraction.
3. Targeted suites for Notes, annotations/drawing, reader, Collections and Companion as
   their files are touched.
4. Relevant XCUITests after surface/composition changes; do not claim simulator input as
   physical Pencil acceptance.
5. SwiftLint production and test invocations with no unapproved violations.
6. Strict-concurrency diagnostic build at the ticket's recorded enforcement level.
7. `git diff --check`, documentation link/path checks and staged-path/secret audit.
8. Final signed iPad build, strict signature check and in-place install. Verify data-container
   identity is preserved.
9. Owner smoke test: launch, read/navigate Scripture, open Verse Hub, open/edit/save a Canvas
   and Page note, browse a Collection, and open/send or exercise the implemented Companion
   boundary. Record physical-only gaps separately.

Build success alone does not prove behavior preservation, persistence compatibility,
physical Pencil behavior, VoiceOver or complete user acceptance.

## Likely implementation files

- `SophiaScripturaApp.swift`, `RootTabView.swift`, and a new small composition file.
- `Features/Notes/NotesSession.swift` and new responsibility-focused Notes collaborators.
- `Features/Notes/Editor/NoteCanvasSurface.swift` plus private editor/controller helpers.
- `Features/Scripture/ScriptureView.swift` and a new `Features/Scripture/VerseHub/` group.
- `Features/Collections/CollectionsStore.swift` and pure hierarchy/membership helpers.
- `Features/Companion/CompanionSession.swift` only after its implementation baseline closes.
- `Core/ModuleBoundaries.swift`.
- Corresponding unit/UI test files.
- `.swiftlint.yml`, Xcode build settings only when justified, `.ai/maps/`, `AGENTS.md`, TDD,
  testing/deployment docs and this ticket.

Names are proposed ownership boundaries, not mandatory filenames. Inspect the exact source
again immediately before implementation because the Companion slice is actively changing.

## Risks and stop conditions

- UIKit/PencilKit extraction can subtly alter responder, gesture, tool-picker, zoom or
  coordinate behavior. Stop and reduce the slice if characterization tests cannot explain a
  difference.
- Autosave/history extraction can cause data loss despite compiling. Do not proceed without
  failure/reopen tests and preserved generation fixtures.
- Concurrency enforcement can expose isolation errors across Observation, Combine and UIKit.
  Raise the enforcement level incrementally rather than adding unchecked `Sendable` broadly.
- Composition changes can create duplicate session/store instances. Tests and Root previews
  must prove one intended live instance per app window.
- If an extraction requires a schema migration, new user behavior, dependency package or
  provider contract change, stop and create a separate owner-selected ticket.
- If concurrent uncommitted work overlaps a target file, preserve it or wait; never revert or
  overwrite it to complete this ticket.

## Completion evidence

When selected and implemented, append:

- dedicated branch name, approved starting commit and confirmation that the branch was
  created before implementation;
- implementation commit(s), organized by work package;
- pre/post warning and lint summaries;
- result-bundle paths and exact pass/fail/skip counts;
- concurrency enforcement level and command;
- signed iPad build/signature/install evidence and preserved data-container identity;
- owner smoke-test observations and remaining physical/accessibility gaps;
- documentation files reconciled;
- any deferred package with its reason.

Status: **done; closed without implementation** at M9 2026-10-04. Reopen only with an explicit new owner selection.
