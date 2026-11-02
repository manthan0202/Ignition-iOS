# Ignition — Plan interaction polish (October 30, 2026)

This release updates **the existing Xcode project**, not the approved design. It focuses on the feeling of Capture → Drag → Schedule → Focus. The Now landscape, Focus UI, session engine, Screen Time services, and Live Activity / Dynamic Island extensions are unchanged.

## What is actually changed

- **Native drag lift:** a task or calendar event uses a translucent, tinted custom system drag preview (instead of a generic text payload thumbnail). The payload still retains the original task/event identity.
- **Calendar feedback:** a 15-minute target highlights while a task is hovering; the chosen time is shown at the top of the calendar. Haptic selection ticks occur on crossing a different target.
- **Drop confirmation:** creating a block or adding a task to an existing block produces a compact confirmation that dismisses automatically, with a working **Focus** action leading into the current session engine. No new task is cloned.
- **Block movement:** dragging the top strip shows a snapped time preview, gives a haptic tick per quarter-hour, and animates the actual persisted schedule when released.
- **Block resizing:** dragging the bottom handle shows a duration preview, 15-minute haptic steps, bounded final duration, and an animated settling. The existing underlying focus block model remains authoritative.
- **Task completion:** a completed task leaves the visible incomplete-task list with a restrained animation and completion haptic; it is not an automatic block/session completion.
- **Calendar/task divider:** follows the finger while dragging, then settles to its nearest height using a spring; taps switch between expanded/balanced positions. The prediction blend reduces accidental long jumps.
- **Day picker, filters, and tab switch:** consistent short transitions and light selection haptics.
- **Accessibility:** drag-to-schedule has a tap-to-schedule fallback; Reduce Motion is respected for new animated interactions.

## What this does NOT claim

- No Xcode compiler or UIKit/SwiftUI runtime is available in the build container. `swiftc -frontend -parse` is a syntax check, **not a full iOS build**.
- Cross-scroll native drag pickup, calendar auto-scrolling near edges, gesture priority between resize and calendar scroll, audio/haptic feel, and device frame rate **require a physical iPhone test**.
- There is no change to the already working Live Activity or Lock Screen widget implementation, but the complete app must still be rebuilt and retested to check for integration regressions.
- This is not a new planner UI, a macOS app, or a copy of Anchor artwork. It preserves Ignition's visual identity.

## Exact iPhone acceptance test

1. Back up your signed, working project and local app data. Open this ZIP's `Ignition/Ignition.xcodeproj`, select `Ignition-Preview`, retain your working signing identifiers and team, run on the phone.
2. In Plan, add `Read paper`. Long-press its row: it should lift into a compact preview. Drag over 10:15 AM and observe slot highlighting, selected time, and gentle haptic ticks. Drop. It must create exactly one block.
3. Confirm the scheduled-message pill appears. Tap **Focus**. The real Focus screen must open, with the same task context and Live Activity behavior you already verified.
4. Return to Plan. Move the block by its top grip across three 15-minute boundaries. Its time preview should update; after release its persisted time should advance 45 minutes. Quit/relaunch and check the time again.
5. Pull the block's lower handle 30 minutes down. Preview must show an increased duration, the card should settle after release, and the updated duration must survive relaunch.
6. Add `Write summary`, then drag it over the existing focus block. Both tasks must appear inside the block; no task is duplicated in the repository.
7. Complete `Read paper`. The task must show complete wherever it appears, but the block itself must remain scheduled and the second task uncompleted.
8. Drag the divider upward and downward; release midway. It should follow the finger and settle to a sensible height without the calendar or tasks disappearing.
9. Test calendar overlap, a past day, VoiceOver controls, Reduce Motion, and a device with large text. Verify you can schedule with the explicit calendar action without dragging.
10. Switch Now → Plan repeatedly during and outside Focus. The clock, Live Activity, session history, and saved tasks must not reset.

If a case fails, record the gesture and capture the first Xcode issue. The local tests cannot prove physical interaction quality.
