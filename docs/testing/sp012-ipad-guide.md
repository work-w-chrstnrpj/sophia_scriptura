# SP-012 — Actual Scripture annotation acceptance

Use the Scripture tab, not Settings → SP-008 experiment. Owner selected SP-012 on
2026-09-29. Physical acceptance below is pending; prior SP-008 results do not pass it.
VoiceOver is waived, not passed. Use test handwriting until this recovery drill succeeds.

1. Open WEB John 3. Layers → New layer. Draw with Pencil over the text; enable Margin for blank space around all four sides;
   check native palette pen, eraser and lasso. Finger pan and pinch zoom should move both
   text and ink; resting palm should not draw. Wait for Saved.
2. Select Read Visible. Tap verse labels and select text → Copy/Share. Read Hidden hides
   ink and restores the normal centered reader. Draw disables Scripture taps/selection; chapter
   controls finish the stroke and save before leaving.
3. Create/rename two layers, write different marks, select each and Undo/Redo. History
   belongs to each loaded layer; reopening resets it. Clear ink then Undo should restore
   only the selected layer. Delete a layer; Recently Deleted → Restore recovers its ink.
4. Rotate and resize the window; pan/zoom and toggle blank Margin space. The selected
   layer's saved geometry remains fixed until its font settings are deliberately changed.
   Settings font changes update that selected layer and may shift old ink; selecting
   another layer restores that layer's own preset/typeface and size.
5. Visit another chapter, translation and tab, then return. Ink stays with its original
   edition/chapter/layout. Available licensed editions work without automatic sync.
   Locked/unavailable backgrounds retain handwriting and never overlay approximate text.
6. Background/lock/reopen and fully close/relaunch. Acknowledged Saved handwriting returns.
   An abrupt exit during an active unsaved stroke may lose that stroke. A save failure
   keeps dirty handwriting in memory, shows Retry and blocks leaving it unsaved.
7. Ink backup → Export annotation backup to Files. Change/delete a test layer, then
   Restore annotation backup → Replace annotations. Confirm original drawing and deleted
   layers return. Recover annotations from before last restore returns the pre-import
   generation. Cancel import/replacement and check no data changed. This replaces all
   annotations; use test data and retain the exported backup.
8. Open Psalm 119, create dense test handwriting, scroll to both ends and repeatedly zoom,
   erase/lasso and reopen. Record font, layout dimensions, stroke count/sample size, time
   to open/save, visible stalls and memory observation. Simulator stress is not this pass.

Record each ANN-01–09 as passed/failed/not-run with actual iPadOS/Pencil model. Capture
screenshots where helpful; never retain licensed text or private study data in logs.
Backup format is versioned JSON with base64 native drawings; it contains no Scripture text
or credentials. Limits: 128 groups, 256 layers/group, 32 MiB per drawing, 64 MiB combined
native drawings, 128 MiB archive, 200,000-point chapter height. Layer names max 80 characters.
Current/previous/pre-import generations are retained. After corruption recovery, originals
remain retained without automatic cleanup; repairing a fully damaged store retains a
separate `Annotation-recovery-UUID` copy in Application Support before replacing it.
No permanent tombstone purge is provided in this ticket.

Owner-revision check: controls centered in portrait/landscape/narrow windows; no ruled
right column. Read Hidden matches the normal reader's width, typography and alignment.
Start writing: palette minimizes but drawing continues; the compact affordance expands it. Lift Pencil and
wait for Saved automatically, relaunch and check ink returns. Existing v1 handwriting
is preserved; New layer creates the surrounding-space layout without moving old strokes.

Latest owner-revision check: New layer should show a compact palette affordance in Draw;
collapse it to the edge tab and restore it, then tap it to expand the native picker.
Start a stroke and check it minimizes while ink
continues. The toolbar layer button should look like the other controls; the Layers menu
should mark the selected name and checkmark in blue and show gray
`Layer name — preset/typeface, size` details. Create two layers under different presets
and sizes, then select each and confirm Settings and text geometry return to that
layer's saved values. Change the font while a layer is selected: that layer updates and
warns if existing marks may shift; the other layer retains its settings. Read Hidden
omits Margin, there is no larger-text reading or Preserved layouts menu, and Clear Ink
appears red and remains undoable. Record physical results separately from simulator tests.

After creating a layer, switch directly to Read Hidden and tap a verse number. Verse Hub
should respond promptly. Check that the layer picker has separate New, Rename, and red
Delete buttons with plus, pencil, and trash icons. The mode menu and current-mode button
should use an eye with a dark pupil for Read Visible, a hollow pupil for Read Hidden,
and pencil for Draw.
