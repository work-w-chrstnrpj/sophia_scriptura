# SP-059 — Plan study experience

**Milestone** Collection Plans

**Status** Complete. The owner tested the final build on iPad and accepted SP-059 on 2026-11-08.

The accepted device build was 1.7.1 (build 33). The source release is
[v1.8.0](../docs/releases/v1.8.0.md), build 34. The owner confirmed the final
appearance and authorized ticket closure and publication. Physical Pencil,
system notification delivery, and live-provider behavior retain their existing
verification limits.

The v1.8.0 release snapshot passed all 525 local native tests on the iPad Air
13-inch (M4) simulator. See `build/v1.8.0/unit.xcresult`.

## Scope

- Draw the Plan’s selected character walking in place with a flickering candle between the title and date on In Progress Plan cards. Slow clouds and faster grass pass by over the card background. Reduce Motion keeps the traveler, flame and scenery still.
- Schedule one-time Activity reminders for unfinished strict Plan sections due today and tomorrow. Plan Edit supplies the initial time. Activity Reminders edits the occurrence or the Plan's future default.
- Open Scripture assignments from the Plan and its section folders in a review workspace. Review carries no completion or timer command.
- Open a dedicated Companion conversation in the Plan with a removable Scripture or typed note attachment. The attachment is composed into provider requests while the Plan conversation is open.
- Reuse the Scripture text and PencilKit surfaces. One named Plan layer belongs to each section, with chapter-specific drawings anchored to their original source edition, content revision and layout.

The owner separately authorized personal iPad installation and source release.
Broader SP-050–052 acceptance remains tracked separately.

## Behavior and durability

Strict Plans with an existing schedule use 8:00 a.m. until a time is chosen. Reminders are created in Sophia's Activity store and delivered as local notifications. Foregrounding and schedule changes reconcile the rolling window. A time override or deletion belongs to one dated section occurrence. Expired or dismissed occurrences leave the UI and suppress recreation for that day. They are removed from the store when the window advances. Lock-screen text uses a generic Sophia study reminder.

Plan review and playback use a transient ReaderSession with the ordinary reader's preferences. The shared AnnotationSession retains sole ownership of the drawing archive and its save barriers. A Plan ID and section ID identify the named layer. Chapter, edition and content revision identify its drawing. Managed drawings can only be opened through the owning Plan. Opening a section refreshes the name from the current Plan title and section number. Reset and archive retain ink. A duplicated Plan starts with its own IDs and empty layers. A missing Plan or section leaves ink inaccessible through the reader while retaining it in the archive.

Companion shows the attachment before Send. Scripture text follows the edition's AI context policy. Notes include typed page content and typed text or list objects. Both are bounded for the provider request. Ink, media, attachments and linked quotes stay local. The attached payload lives in memory for the embedded conversation. Closing the workspace clears it and restores the prior Companion selection. User messages and assistant responses follow the existing conversation persistence workflow.

## Verification

The focused native scope covers Plan reminders, transient reader state, assignment context, annotation isolation and reopen, plus playback, Activity, Companion and annotations regressions. The UI journey exercises Scripture review from Plan and section folder, first Draw and layer reuse. Physical checks cover the candle and Reduce Motion, Pencil alignment and tools, actual reminder delivery and a live Companion request.

2026-11-08 final source built for testing on the iPad Air 13-inch (M4), iPadOS 27 simulator.
The full native suite passed 520 tests with zero failures, including eight SP-059 tests.
Evidence is retained under `build/sp059/`.
The Plan UI journey passed review without progress changes, first Draw, reopening the
same layer, and opening the passage from its Day folder. The source diff passed
`git diff --check`. Physical Pencil, Reduce Motion appearance, local notification
delivery and live-provider acceptance remain open.

The initial signed Debug 1.7.1 (build 33) installed in place on iPad ni Paj.
iPadOS initially denied launch with a developer trust or signing security error.
Later builds installed and launched normally, including the build the owner accepted.
See `build/sp059/ipad-install-final.log` and `build/sp059/ipad-launch-retry.log`.

## Plan card artwork follow-up

The simulator build and the focused Plan-card UI test passed. The test checked that the
In Progress status appears after starting a Plan in Card View and is absent in List View.
The captured card shows the traveler between the title and date. Standing and walking
poses were rendered separately and checked for transparency. The physical Reduce Motion
check remains open. Evidence is under `build/sp059/traveler/`.

The signed Debug build with the traveler artwork installed in place on iPad ni Paj as
1.7.1 (build 33). iPadOS denied the first launch. A subsequent CoreDevice launch
succeeded. See `build/sp059/traveler/ipad-install.log` and `ipad-launch-retry.log` in
the same directory. Physical animation and Reduce Motion acceptance remain open.

## Companion traveler and scenery follow-up

The iPad simulator build and focused UI test passed. The test started a Plan, captured
Sophy in Card View, selected Sabinus and Sol in Settings, and captured both updated
cards. It also checked that List View omits the In Progress artwork. Visual review
confirmed all three characters and the cloud and grass bands on the card surface.
The still pose and two moving frames per character were rendered for comparison.
Physical Reduce Motion acceptance remains open. Evidence is under
`build/sp059/companion-travelers/`.

The signed Debug build with companion selection and moving scenery installed in place
and launched on iPad ni Paj. The device reported 1.7.1 (build 33) and a running Sophia
process. See `build/sp059/companion-travelers/ipad-install.log`.

## In-Plan conversation and titles follow-up

The conversation button opens a panel within the existing Plan workspace. Closing it
returns to the same assignment and restores the prior Companion selection. New Plan
conversations use the passage reference or note title. Protected sources get a generic
study title. An untitled standalone conversation takes a locally shortened first
question and updates the Collections listing. The title path uses no extra provider call.

The iPad simulator passed 56 focused native tests and the Resume conversation UI
journey with a local mock provider. The journey verified the Plan header, passage title,
attachment and return to the same assignment. Physical iPad and live-provider
acceptance remain open. Evidence is under `build/sp059/inline-conversation/`.

## Per-Plan outfit color follow-up

Plan Edit offers Outfit color using the shared Sophia palette. The optional Plan value
overrides the robe and sleeve color for any selected companion in walking and still poses.
Companion default clears the override. Older Plan records decode with the default.

The iPad simulator build, nine focused native tests and the outfit UI journey passed.
The journey checked a saved Oxblood outfit across companion switches, reopened the
picker and restored the companion default. Evidence is under `build/sp059/outfit/`.
Physical Reduce Motion acceptance remains open.

## Scenery and equipment follow-up

Holding a Plan card and choosing Edit opens the existing editor at once. Outfit color,
Scenery and Equipment are grouped under Plan card. Automatic selects Sunny or Moonlit
from Sophia’s effective light or dark appearance. Mountain terrain, Cloudy sky, Library,
Sunny, Moonlit and Rainy remain explicit choices. The scenery is transparent and clipped
to the artwork. The context menu uses a still card preview.

Candle and oil lamp carry a flame. Armor of God depicts the helmet, breastplate, belt,
shield, sandals and sword described in Ephesians 6:14–17. The selected companion keeps
their identity and wears the armor over their outfit. Existing Plans use Cloudy sky and
Candle. Reduce Motion shows the selected scene and equipment without motion.

The simulator passed nine focused native tests and the long-press Plan card journey.
The journey saved Mountain terrain and Armor of God, switched through the three
companions, reopened the editor, and saved Automatic and Lamp. The separate Scripture
review and layer-reuse regression also passed. Render checks verified fixed sun and moon
pixels while the foreground moved. Evidence is under `build/sp059/scenery/`.
Physical iPad appearance and Reduce Motion acceptance remain open.

## Per-Plan character follow-up

Plan card Edit now includes Character with Sophy, Sabinus and Sol. The stored choice
owns the card and its long-press preview independently of Companion Settings. Plans
without a saved value use Sophy. Character default restores the Plan character’s
usual outfit, and the selected character wears Armor of God when that equipment is set.

Nine focused native tests passed. The first incremental device build failed strict
signature verification before installation. A fresh device-targeted signed Debug build
passed signature and bundle checks, installed in place, and launched on iPad ni Paj.
The device reported Sophia 1.7.1 (build 33) and a running process. Evidence is under
`build/sp059/plan-character/`.
The simulator UI journey also passed. It saved Sabinus on a Plan, selected Sol in
Companion Settings, verified the Plan picker still showed Sabinus, then changed the
Plan independently. Physical interaction acceptance remains open.

## Lantern light follow-up

Lamp now draws a brass lantern with a loop handle, glass chamber and crossed guards.
A warm glow lights the path beneath the traveler’s feet, inspired by Psalm 119:105.
Reduce Motion holds the lantern and its light steady. The focused simulator suite passed
nine tests. Render checks confirmed the localized ground glow and stable still frame.
See `build/sp059/lantern/`. Physical appearance acceptance remains open.

## Shield carry and outfit swatches follow-up

Armor of God now slings the shield on the traveler’s back. A shoulder strap shows the
attachment and leaves the free arm clear to swing. The outfit picker uses filled swatches
from the same palette as the artwork and adds Crimson.

Nine focused native tests and the simulator Crimson picker journey passed. The swatch
capture showed distinct palette colors, and rendered walk poses showed the shield on
the back for all three travelers. The combined signed Debug build passed signature
verification, installed in place, and launched on iPad ni Paj as 1.7.1 (build 33).
See `build/sp059/back-shield/` and `build/sp059/crimson/`.

## Shield fit follow-up

The shield sits high and close to the back, angled to show its rim. Leather straps
secure it at the shoulder and waist. The shield moves with the torso, and the free
hand swings below it.

Reviewed three walk poses and the Reduce Motion pose for each traveler. Nine focused
native tests passed. The signed Debug build installed in place and launched on
iPad ni Paj as 1.7.1 (build 33). Owner review of the appearance on iPad remains open.
See `build/sp059/shield-fit/`.

## Forward shield stance

The supplied reference guides the three-quarter stance. The far arm braces a curved
shield forward. The near hand carries the sword low across the waist, with the
blade and hilt following the hand as the traveler walks.

Reviewed three walk poses and the Reduce Motion pose for each character, including
a card-scale render. Nine focused native tests passed. The signed Debug build
installed and launched on iPad ni Paj as 1.7.1 (build 33). Owner review of the
appearance on iPad remains open. See `build/sp059/forward-shield/`.

## Traveler position follows Plan progress

The In Progress card positions the traveler's torso by the fraction of completed
Days or Sections. Half complete is centered. Two-thirds complete is two-thirds
across. Edge clearance keeps the equipment and lantern glow inside the card.
Reduce Motion draws the still pose at the same progress position.

Ten focused native tests passed, including saved Plans with partially completed
sections and fractions of one-half and two-thirds. Card-scale renders confirmed
the positions and edge clearance in a walk pose and a still pose. The signed Debug
build installed in place and launched on iPad ni Paj as 1.7.1 (build 33). Owner
review of progress on the physical card remains open.
See `build/sp059/traveler-progress/`.

## Walk on return to the Plan card

The card holds its departure position while the Plan is open. After dismissal,
forward progress plays one walk to the new position. The last walk reaches the
end before the existing Completed stamp animates. Reduce Motion shows the result
immediately.

Eleven focused native tests and the simulator return journey passed. The first
UI run used the wrong stamp identifier. The rerun found the stamp by its
accessibility label. The simulator recording shows the walk to the midpoint,
the final walk, and the stamp landing in that order. The signed Debug build
installed in place and launched on iPad ni Paj as 1.7.1 (build 33). Owner review
of the animation on the iPad remains open.
See `build/sp059/traveler-walk/`.

## Sunny and Moonlit clouds

A few small, faint clouds drift through Sunny and Moonlit scenery. The sun and moon
stay fixed, and Reduce Motion holds the clouds still.

Eleven focused native tests passed. Render checks confirmed cloud movement, fixed
sun and moon positions, and stable still frames. The signed build installed in place
and launched on iPad ni Paj as 1.7.1 (build 33). Owner review of the scenery on iPad
remains open. See `build/sp059/clear-sky-clouds/`.

## Sunny and Moonlit glow

Sunny has a soft amber halo and gently pulsing rays. Moonlit has a cool halo and
stars that twinkle at staggered intervals. The sun and crescent stay fixed. Reduce
Motion holds the rays, stars, and scenery in a still pose.

Eleven focused native tests passed. Render checks confirmed the fixed bodies,
changing rays and stars, fading halos, and stable still frames. The signed build
installed in place and launched on iPad ni Paj as 1.7.1 (build 33). The owner tested
and accepted the final appearance on 2026-11-08. See `build/sp059/sky-glow/`.
