# SP-007 — Collections UI and in-memory interaction slice

- Type: implementation. Status: done (bounded in-memory prototype). Owner: Frontend UI/UX Developer.
- Milestone: M5 — Collections and full Save flow (bounded UI slice).
- Requirements: REQ-010, REQ-017 (prototype behavior only).
- Design: [Collections screen specification](../docs/design/collections-screen-specification.md),
  [App shell specification](../docs/design/app-shell-specification.md).
- Design basis: owner-confirmed nested folders and multiple memberships; detailed screen
  design remains a proposal. The previous turn interpreted “implement the next part” as
  this prototype. The current continuation finishes its verification, without approving
  every design detail or changing the production delivery order. Data contracts remain SP-005.

## Visible outcome

Replace the Collections placeholder with a reviewable iPad UI that demonstrates the proposed
interaction model using local demo data:

- collection cards with search and sorting;
- nested child folders;
- collection detail with artifact filters and descendant inclusion;
- Add Study Material membership picker;
- create collection and child-folder sheets;
- remove membership and safe folder deletion messaging;
- shared artifact identity across collections;
- warm-paper/editorial styling and accessible labels.

## Exclusions

- SwiftData, SQLite, file persistence, migrations, export/import or recovery archives;
- runtime Notes, Scripture, Companion or link repositories;
- opening artifacts in their owning feature;
- real Save-from-Scripture flow, verse-hub integration or provider content;
- final folder ordering, folder icon/color policy and production data contracts.

## Affected modules

- `application/SophiaScriptura/SophiaScriptura/Features/Collections/CollectionModels.swift`
- `application/SophiaScriptura/SophiaScriptura/Features/Collections/CollectionsStore.swift`
- `application/SophiaScriptura/SophiaScriptura/Features/Collections/CollectionsView.swift`
- Sibling `CollectionDetailView`, `CollectionCard`, `CollectionArtifactRow`,
  `CollectionArtifactPicker`, `CollectionEditorSheet`, and `CollectionStyle` files separate
  screen, component, sheet and appearance responsibilities.
- `application/SophiaScriptura/SophiaScripturaTests/CollectionsStoreTests.swift`
- `application/SophiaScriptura/SophiaScripturaUITests/CollectionsUITests.swift`

## Acceptance and verification

- The Collections tab opens populated demo folders instead of a placeholder.
- A collection can be created, a child folder can be created, and nested navigation works.
- The same artifact can be selected in more than one collection without duplicate artifact IDs.
- Direct versus descendant artifact counts remain distinct and descendant results are deduplicated.
- Removing membership does not delete the artifact; deleting a folder promotes children and
  keeps remaining artifacts safe.
- Search, sort, type filters and Include child folders update the visible result.
- `CollectionsStoreTests` pass.
- The app builds for a generic iOS destination.

## Documentation impact

The implementation is intentionally smaller than the full Collections specification. Update
this ticket with verification evidence and carry persistence, route integration and recovery
gaps into SP-005/M5 implementation planning. Do not mark M5 complete from this slice.

## Evidence

2026-09-17: Implemented the bounded Collections UI and in-memory store. Direct Swift type
checking passed for `CollectionModels.swift`, `CollectionsStore.swift`, and the SwiftUI view
with preview-only macros removed from the check. Store tests were added but could not run
through XCTest because the host could not initialize CoreSimulator/XCTest services.

The generic Xcode build reached compilation but was blocked by the host’s existing
CoreSimulator/Preview macro service failure; the normal device build is also blocked by the
missing Personal Team provisioning profile for `com.personal.SophiaScriptura`. No signing or
Xcode account settings were changed by this ticket.

2026-09-17 verification follow-up: access to Xcode services outside the sandbox restored
simulator discovery and Preview macro compilation. The earlier environment diagnosis and
view type-check claim were insufficient: a real build found an incompatible SwiftUI shape
style conditional in the membership picker. Replaced it with two Color values; the unsigned
generic iOS build then passed. Signing was not changed or tested on the physical iPad.

Split the 540-line screen file by responsibility. Added a visible sample/reset notice,
search across nested folder names, adaptive dark-mode surfaces/text, a narrow-width filter
menu, and validation against nonexistent membership targets/parents. Descendant-only items
no longer offer an ineffective parent Remove action. Run 01 passed seven store tests and
the removal/descendant/filter UI journey; the create/add journey revealed a picker row whose
empty center was not tappable. Added a rectangular hit region and an explicit selected-state
assertion for verification.

Remaining product gaps: temporary data resets on relaunch, sample artifacts cannot open,
production persistence/routing is absent, and the existing shell still places tabs at the
top on iPadOS 26.5. The approved bottom-tab shell is separate unimplemented work. Physical
VoiceOver, larger text and complete visual acceptance are not claimed by this slice.

Verification follow-up after the picker hit-region fix: the saved Run 01 result bundle
records 8 passed and 1 failed test (all seven store tests and the first UI journey passed;
the create/add/delete/search journey exposed the search-field timing issue). Runs 02 and 03
reached the create/add/delete flow but still failed while exposing the iPadOS 26 searchable
field. The test now waits for and taps the iPadOS 26 Search toolbar button before waiting
for the field. A final rerun could not complete because CoreSimulatorService became
unavailable; the requested external retry was also blocked by the host usage limit. The
next verification pass must rerun both Collections test classes and record a fresh result
bundle before this ticket can move to done.

Automation attempt: Simulator was opened automatically, but CoreSimulatorService continued
to refuse connections. A non-escalated generic build also stopped in the sandbox while
Swift frontend/Preview macro services were initializing. No runtime source was changed in
response to these infrastructure failures; the pending test adjustment remains limited to
waiting for the iPadOS 26 Search toolbar button.

2026-09-17 physical-device verification: Xcode confirmed the app target and both test
targets use Christian Paje (Personal Team), repaired their managed profiles, installed the
signed build on the wired iPad A16, and launched it. The full on-device suite ran 26 tests:
20 unit tests passed; the Collections create/add/delete/search journey passed; the
Collections membership-removal journey failed when XCUITest could not expose the SwiftUI
destructive menu item on the physical iPad, even though the store removal tests passed.
The unrelated Canvas text-editing UI test also failed at its existing text assertion. This
run therefore provides useful device evidence but does not close SP-007. The next bounded
fix is to make the Collections removal interaction reliably discoverable on iPadOS, then
rerun only the Collections UI class.

2026-09-21 closure: resumed the selected verification scope using the execute-code-change
workflow. Run `build/sp007-20260921-r1.xcresult` passed eight of nine Collections tests;
the remaining failure was the test expecting the descendant-only menu explanation to be
StaticText. Its retained accessibility hierarchy exposes it as a disabled Button.
Changed only `CollectionsUITests.swift` to locate that exact explanatory label independent
of element type, and assert that neither a Button nor MenuItem offers removal for a
descendant-only item. The earlier removal Button/MenuItem fallback remains. Runtime
Collections behavior did not change.

Fresh verified results (read using `xcresulttool get test-results summary`):

- `build/sp007-20260921-r2.xcresult`: **9 passed, 0 failed, 0 skipped**, iPad A16
  simulator / iPadOS 27.0; seven Collections store tests and both UI journeys.
- `build/sp007-device-20260921.xcresult`: **2 passed, 0 failed, 0 skipped**, physical
  iPad A16 / iPadOS 27.0; both Collections UI journeys. Signed build and installation
  succeeded as part of this run. No owner intervention was needed.

Both runs used the SophiaScriptura scheme, `-parallel-testing-enabled NO`, and
`-only-testing` scoped to the named Collections classes. Simulator signing was disabled;
device signing used the already configured Personal Team. Logs and failure attachments
are retained beside the ignored result bundles. The earlier generic iOS build pass
remains applicable: this follow-up changed test source only.

Acceptance disposition: SP-007 is **done for its bounded prototype scope**. M5 remains
blocked for production integration. Temporary state resets, no artifact routing, the
unimplemented bottom-tab shell, and unverified full visual/VoiceOver/larger-text acceptance
remain explicit limitations. iPadOS 27 emitted an all-orientations Info.plist warning;
carry it into app-shell work. The September 17 Canvas text-editing UI failure remains
unresolved outside this ticket; the full application suite was not rerun or declared green.
