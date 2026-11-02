# Ignition — Interactive Plan Calendar Update (October 30, 2026)

This is a **code update** to the existing iPhone app, not a new visual concept.

## What changed

- **One screen, two surfaces:** a vertically scrolling, precise day calendar above a persistent, independently scrolling Tasks drawer.
- **Pull down the divider** between the calendar and tasks to expand the calendar; pull upward to give the task list more space. Tap the divider to toggle the larger calendar.
- **Now line:** A thin red current-time indicator updates periodically for today's calendar only. Opening Plan initially scrolls near the current hour. It does not recenter while you're exploring.
- **Stable week strip:** Select a date while keeping the days of that week in place. Navigate with previous/next day or Today.
- **Drag to schedule:** Long-press an unscheduled task and drag it to a 15-minute time slot; moving an existing movable event works the same way. The destination highlights.
- **Tap-to-schedule fallback:** Tap the calendar-plus icon on an unscheduled task to choose a precise date and time instead of dragging.
- **Edit:** Tap a scheduled event or task to edit it. Long-press an event for a context menu to shift it by 15 minutes or lengthen/shorten it. External Apple Calendar events imported as fixed remain read-only.
- **Overlapping blocks:** Events in overlapping time ranges appear in separate horizontal lanes rather than on top of each other.
- **Cross-midnight events:** An item overlapping the selected day is visible, even if it started the previous evening.
- **Voice:** The existing voice entry is reachable from the Plan header and Tasks drawer.
- **Preserved:** Now/Journey, Focus, Screen Time integration, notifications, Dynamic Island, Lock Screen Live Activity, and audio are unmodified.

## Safest installation: only two Swift files

1. Back up your current **working** Ignition Xcode project.
2. Unzip `Ignition_Interactive_Calendar_TWO_FILE_PATCH.zip`.
3. Replace the two files with identical names in your existing project's `Sources/App` directory:
   - `PlanView.swift`
   - `Domain.swift`
4. Open the **same Xcode project** you've already signed; use `Ignition-Preview` and your iPhone.
5. Choose **Product → Clean Build Folder**, then **Run**.

This avoids losing your already-working Preview Live Activity extension, signing identifiers, or Apple permissions. No new targets, assets or package dependencies are required.

Alternatively, the `Ignition_Interactive_Calendar_FULL_Xcode_Project.zip` contains the same code in a standalone project. It may require signing setup again.

## Test it on an actual iPhone

- Open Plan. Confirm it shows **Today** and scrolls near the current time; the red line matches the clock.
- Pull the separator down. Confirm the calendar grows smoothly and the tasks drawer shrinks. Pull it up to restore more task space.
- Add an unscheduled task with the + button. Confirm it appears in the lower drawer.
- Long-press the task; drop it onto 10:15 AM. Verify the task moves to that time and disappears from *To schedule*.
- Switch to *On this day* and verify it appears there, too.
- Tap the event, edit its title or duration, and save. Confirm it updates in the calendar.
- Drag it to another time; then verify tapping **Now** shows the updated scheduled landmark (if today's event).
- Create two overlapping events. Confirm both remain visible side by side.
- Try a fixed Apple Calendar import. Verify it cannot be dragged.
- Lock your phone during a focus session. Confirm that the previously working Live Activity is unchanged.

## Implementation boundaries and known limitations

- The project **has not been compiled or run against the iOS SDK here**. Swift syntax and the existing session-core tests pass, but real drag/drop and gesture behavior still require physical-iPhone validation.
- Calendar drag/drop uses Apple's `draggable` and `dropDestination` for UUID task identifiers. On iOS, begin the drag with a **long press**. It is not an immediate move-on-touch gesture.
- Event duration is currently changed in the editor or context menu; there is **no drag-to-resize bottom edge** in this iteration. Drag-to-schedule and dragging existing events *are* implemented.
- There is no model yet for putting multiple distinct tasks *inside a single focus block*. Dragging a task onto the calendar schedules that task; adding grouped blocks would require additional domain modeling and is intentionally not faked.
- The calendar displays one day on iPhone, with stable seven-day navigation; it is not the desktop two-day layout from the reference.
- This only changes the Plan tab. The existing Journey artwork remains as-is.

## Verification performed

- `swiftc -frontend -parse` on all Swift sources — PASS
- Foundation session smoke test — PASS
- 28 deterministic session-state assertions — PASS
- `plutil -lint` on Xcode project — PASS
- Full Xcode build / iOS UI tests / real drag-and-drop — NOT AVAILABLE IN THIS ENVIRONMENT
