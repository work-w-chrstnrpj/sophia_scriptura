# SP-013 — Canvas and Page iPad acceptance

Status: M4 was owner-accepted on the paired iPad on 2026-10-01. The final routing change
was covered by focused Notes and shell checks; the build/install evidence is recorded in
SP-013. The previous
2026-09-30 build had owner-reported Pencil-to-text, typing-exit, palette and Scribble-off
failures. Those physical failures are not closed by simulator tests. Use disposable notes
and export a Notes backup before replacement/restore tests.

1. **Choose the type:** Notes → New Note → Page or Canvas. Create both, rename, leave
   ungrouped, close/reopen and relaunch. Each must retain its type and content.
2. **Page typing and Pencil:** type several paragraphs by tapping the central body. Without
   pressing Insert, write over the text and margins with Pencil. Repeat while the keyboard
   is visible, after tapping blank space, and with Settings → Apple Pencil → Scribble both on and
   off. Pencil must never type words. Fingers must not draw in the normal device build.
3. **Fixed Page annotations:** insert text above ink, rotate, resize the window, pinch and
   hide/show Scripture. Ink stays at the same page coordinates. The column width stays
   fixed; adding body text can move the text relative to old annotations intentionally.
4. **Page attachments:** Insert → Image from Files or Table. They flow with text. Edit a
   table by tapping its inline item. Insert a URL; it is a tappable inline
   link, not a card. New Page menus do not offer floating shapes, stickers or text boxes.
5. **Canvas objects:** insert text, image, table, shape, sticker, URL card and quote. Draw
   directly with Pencil. Select drawing/text/image objects with a finger, drag, resize from
   the bottom-right handle, group/ungroup, undo/redo and relaunch. Erase part/all of ink and
   try lasso. Unchanged objects must retain geometry and drawing content. Tap a selected
   link card to open it or a selected quote to navigate Scripture.
6. **Palette and input:** inspect all native inking/eraser choices supported by the iPadOS
   version. Page excludes drawing selection; Canvas includes lasso. Dismiss/reopen tools,
   type then draw, draw then type, switch tabs and background/relaunch. Check latency and
   palm rejection. If the native palette covers bottom tabs, use Hide Pencil tools in the
   editor toolbar before switching; hidden tools must not stop Pencil drawing. Record
   iPad/iPadOS, Pencil model and Scribble setting for each result.
7. **Scripture:** hide/show with the toolbar button; passage/edition remain. Relaunch and
   confirm visibility is remembered. Select a passage → Save to note: an open note receives
   it directly; otherwise choose New Page, New Canvas or an existing note. Page gets source
   and inline citation at the end of its body, Canvas gets a quote object. Try authorized translations. Hide Scripture
   and tap the citation: it reveals and navigates to the saved edition/passage. Verse hub
   uses the same destination flow; existing linked notes reopen the same note.
8. **Legacy notes:** old object-only notes open as Canvas without altering IDs, geometry or
   local ink. Existing page-backed notes stay Page, retaining older floating items. First
   v3 save preserves the exact prior generation in `before-note-types.notes`; the older
   `before-study-page.notes` must remain untouched. No automatic cross-type conversion.
9. **Durability:** open Note options and wait for Saved, switch tabs, background/relaunch, then export to Files.
   Change a disposable note, restore the archive and recover the pre-restore version.
   Verify both types, attachments, tables, quotes and ink. Reject corrupt/unknown archives
   without replacing good data. Record the exact unsupported-data message if it returns.
10. **Usability/capacity:** VoiceOver, keyboard, narrow windows, long text, dense ink and
    images. Canvas has the existing 12,000-point bound and 200-object safety limit; it is
    not a complete Freeform clone. No measured physical capacity claim is made.

Record Pass/Fail/Not Run with steps, time and screenshot/diagnostic evidence. The original
crash, physical Pencil routing, tool availability, palm rejection and Files recovery remain
explicit acceptance gates. M4 is closed by the owner's accepted iPad review; use this guide
for future regression work.


## Workspace refinement acceptance

1. Tap the title to rename; reopen to verify. Open Note options → Paper → Dotted.
   Confirm dots and writing remain visible in light and dark modes.
2. Hide Scripture. Verify Page/Canvas extend behind the floating tab dock with no footer
   gap. Rotate and resize; text and ink retain document coordinates. Pan and zoom Canvas,
   insert at the visible location, and use Zoom → Fit content to find the objects again.
3. Insert several different shapes and emoji stickers. Select a shape: use its floating
   palette to duplicate/delete, change color/shape, and send backward/forward. Undo/redo.
   More → Select multiple, tap another object, then Group/Ungroup. Move/resize with finger.
4. Draw with black or white, deselect, switch light/dark, and reopen. Ink stays readable
   with no unselected rectangle; colored strokes retain their color. Repeat after erasing.
5. Insert a YouTube URL and another webpage online. Where provided by the site, expect
   title/thumbnail; otherwise a readable domain fallback. Reopen offline: cached previews
   remain. Page URLs stay inline. Refresh through the selected card's More menu.
6. Type into a Page and a Canvas text box, then immediately draw with Pencil. No Done
   typing step is needed. Repeat Scribble on/off and check the native tool palette.

Capture any failure with note type, exact steps, iPadOS/Pencil model, orientation, theme,
and screenshot. Automatic tests do not establish physical Pencil feel or live-site metadata
availability. The SP-013 ticket records installation and launch of this refinement. Existing link cards
can fetch a thumbnail through their selected-object More → Refresh preview action.


### Theme and screen-edge regression — 2026-10-01

1. Select Spring Leaf and Dark in Settings. Visit all six tabs: status/navigation region
   and body should share green-tinted paper, with no separate reserved bottom strip.
2. In both Canvas and Page, hide Scripture and draw with neutral black/white Pencil ink.
   Switch Dark → Light → Dark. Ink must stay readable every time. Repeat after reopening
   and with colored ink; colored strokes keep their hue.
3. Rotate portrait/landscape. The note viewport reaches the bottom edge; fixed Page text
   coordinates do not change. Hide Pencil tools and let the tab dock idle-hide to inspect
   the entire writing area. Pinch/pan and type with the keyboard to check caret visibility.
4. Scroll Notes, Collections and Settings to the end; final items remain reachable above
   the floating dock. This scroll clearance must not shrink the Notes editing viewport.

Simulator finger input and pixel assertions supplement, but do not replace, this physical
Pencil check. Record remaining issues with note type and the exact theme sequence.


### Repeated Canvas drawing and pen indicator

Draw at least twenty short strokes, followed by a longer handwritten paragraph. Expect
ink to follow Pencil promptly without app exit. Repeat after zooming/panning, rotating,
and toggling the Scripture pane; old strokes must stay aligned and new ink must land at
the Pencil tip. Reopen the note to verify persistence. Toggle the Pencil toolbar: its
button changes solid/hollow and remains reachable. Repeat with Scribble enabled/disabled.
Automated finger strokes measure bounded rendering/persistence, not physical Pencil latency.

### Page opening regression

Open a new and an existing Page, draw a short annotation, switch Dark → Light → Dark, then
leave and reopen it. The Page must open without exiting and retain its text and ink.

## SP-025 physical Canvas acceptance — v0.3.0

Status: Not Run on the owner's iPad. Simulator finger input is not physical Pencil evidence.

1. Back up Notes. Open old single-stroke and 64-stroke-batch Canvas notes: check exact
   placement, colors, groups and overlaps before editing. Also inspect Page/Journal ink.
2. In a Canvas note, write beyond 64 and 300 strokes. Normal continuous writing remains
   one region. Select Strokes or the Pencil lasso: tap one stroke and loop around handwriting
   in several regions. Nearby unselected ink remains unchanged through move/color/delete.
3. Drag selected ink using Pencil and finger. Repeat at 25%, 100% and 200% zoom, including
   thin/overlapping strokes, clipped eraser masks and empty space over images/text. Test palm
   rejection and endpoint-hold refinement. Loop means fully contained visible centerlines.
4. Copy a subset, Paste from Note options, duplicate, erase partly, Undo/Redo, save/reopen,
   then export/restore. Verify independence of copies and preservation of unselected strokes.
5. Switch to Objects/Select drawing: move/resize a region and an explicit mixed group; lock
   position and verify movement is blocked. Return to Strokes and check geometry/index freshness.
6. Use New drawing region; insert text/image between writing sessions and verify layer order.
   Use a generated near-capacity fixture to cross 10,000 strokes/payload bounds: ink spills
   to an adjacent region without loss. At the overall note bound, verify rejected ink
   recovery survives quit/reopen and creates a new note without modifying the source.
7. Pan across a large note; examine raster sharpness in light/dark themes and complete
   image sharing. Selection outlines must not appear in shared output.
8. Compare the same document/device/tool/zoom with baseline using sustained writing,
   selection, pan/zoom, erase, undo and save. Record stroke/object counts, payload bytes,
   visible latency/frame stalls, peak memory and save durations. Set acceptance budgets
   against the device baseline; no measured performance improvement is inferred from tests.

Stop on lost strokes, changed legacy placement/overlaps, stale selection, interrupted
Pencil input or memory/latency regression. Record owner device results separately from CI.
