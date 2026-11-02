# Ignition — device acceptance checklist

Run on a real iPhone using **Ignition-Preview** first; later repeat relevant cases with **Ignition-Full** and proper Apple signing.

## Focus & native system UI
- [ ] Cold launch, tap LOCK IN, Lock Screen timer appears; Dynamic Island compact/expanded appears when supported.
- [ ] Leave app for 25 minutes, return; completed session reconciles once and presents Close without falsely completing a task.
- [ ] Pause for 60 seconds and resume: active time excludes pause; break is separately measured; screen/UI/native timers agree.
- [ ] Force-quit/reboot: session state returns correctly; no duplicate focus footprint; Lock Screen state is sensible.
- [ ] Run short 2-minute session: do not claim shielded protection unless independently confirmed.

## Living Day
- [ ] Start from Now: marker stays near 64% down viewport and more upcoming day is shown above.
- [ ] Pan slowly, release, leave for a minute: camera does not jump when Now updates. Back to Now returns cleanly.
- [ ] Pinch Near/Hours/Day; pins remain attached to actual event timestamps.
- [ ] Add events 6:00, 6:40, 7:20, 8:00: they must never chain into one deceptive cluster.
- [ ] Tap a `3+` group; full event list opens and selecting a row chooses that event.
- [ ] At 11:55 PM, tomorrow's early event is visible when in the selected zoom window.
- [ ] Start unplanned focus: dot appears at actual start time; it isn't green/completed unless explicitly marked finished.
- [ ] Pan/zoom on older hardware: no clipping, jitter, damaged content, surprising scroll capture or memory warning.

## Plan
- [ ] Empty tasks and empty calendar still allow title-only task capture and quick focus.
- [ ] Drag an unscheduled task to 10:00; create a block and attach its task.
- [ ] Drag/reschedule and bottom-edge resize a block, verify persisted time/length after relaunch.
- [ ] Add three tasks to one block, complete one in Focus, confirm only that one is complete.
- [ ] Import full-day calendar events: they appear in a separate lane without occluding timed events.
- [ ] Drag task drawer handle: calendar and task list scroll/resize independently.

## Voice
- [ ] Say “Study cardiology tomorrow at seven PM for one hour.” Tap Done; **final words remain** in editable draft.
- [ ] Stop mid-sentence: preserve available partial transcript and allow typing/correcting.
- [ ] Deny microphone or Speech permission: manual task entry still works.
- [ ] Close sheet while finalizing: no freeze, no silent saved task.

## Calendar synchronization
- [ ] Apple Calendar create, move, edit, delete via Ignition; see changes in native Calendar and back.
- [ ] Google account via iOS Calendar: edit an existing writable event in Ignition; verify its provider change appears, then reconcile.
- [ ] Optional direct Google: configure OAuth first, then test create→refresh→edit→refresh→delete with one ID and no duplicate.
- [ ] Simulate connection loss during create and again during delete: pending state survives restart and retries without duplicate events.
- [ ] Edit same event remotely while unsynced locally: conflict shown, no silent overwrite.
- [ ] Test recurrence, daylight-saving changes, cross-midnight, all-day and read-only calendar cases; known incomplete paths must be flagged.
- [ ] Verify 60-second refresh **only while Plan is open**, and manual refresh; do not expect guaranteed background polling.
