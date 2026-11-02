# Ignition Plan — Day / Month calendar (November 2, 2026)

## Scope

This adds one **Day / Month** view switch to the existing **Plan** tab. The
existing day timeline (15-minute drop slots), EventKit/Google sync, Focus Block
model, task drawer, task editor, Plan date picker, and all Now/Focus code remain
in the existing project. The Now screen has **not** been replaced with any of
the conceptual Sun Arc or circular-clock designs.

## User experience

1. Tap **Plan**. The existing **Day** view is the default.
2. Tap **Month** beside the Plan title. A full month grid appears, with muted
   adjacent-month days, a Today treatment, selected date, and colored dots for
   existing calendar events/focus blocks. The dark Inbox/Today task drawer
   remains beneath it.
3. **Tap a day** to open that date in the existing Day timeline.
4. **Long-press and drag a task from Inbox onto a date** in Month mode.
   Dropping the task *selects the date and opens Day*. It does **not** silently
   create a focus block at an arbitrary time.
5. The staging banner appears at the top of Day: **Place [task]**. Tap a
   **15-minute slot** on the timeline to schedule the task in a new focus
   block, or tap **Time** to choose an hour and minute explicitly. The model
   snaps Focus Blocks to the nearest 15 minutes as before. Cancel via **×**.
6. The original **drag a task directly onto a specific Day slot** still works.
7. Month navigation arrows go back/forward by month, Day arrows by day.
   Returning to Day restores the previous Day panel height, rather than
   forcing a redesigned split.
8. Month EventKit data is loaded with a single, authorized read-only range
   query and one cache reconciliation. This changes no external events.

## Files changed in Xcode project

- `Sources/App/PlanView.swift`: UI toggle, month grid, date drop handoff.
- `Sources/App/CalendarService.swift`: authorized calendar range read.
- `Sources/App/AppModel.swift`: month import route, no external writes.
- `Sources/App/Domain.swift`: existing EventKit day reconciliation generalized
  to an interval for one month-wide, atomic disk update.

No Xcode project membership, bundle ID, scheme, entitlement, Home screen,
Now screen, Shield extension, or Live Activity files were changed.

## Validation completed here

- `swiftc -frontend -parse` succeeded for every Swift file.
- `bash Scripts/verify_revision.sh` passed existing session, focus block,
  calendar sync, voice and geometry regression checks.
- The included interactive HTML prototype was browser-tested with a real drag
  from Inbox to November 6 in Month, automatic Day navigation, and choosing a
  10 AM slot. HTML is only a visual/behavior prototype; it does not connect to
  the Swift data repository.
- **Not compiled or run in Xcode or tested on an iPhone yet.**

## Acceptance tests in Xcode / iPhone

- [ ] `Ignition-Preview` builds and launches on your iPhone. Existing tasks persist.
- [ ] Day/Month switch animates once without changing your data.
- [ ] Month grid uses correct month, weekday order and month-length for
      February, March and November, including local DST transitions.
- [ ] Tapping any date opens Day and scrolls to useful hours; day navigation
      does not lose selection.
- [ ] Drag Inbox task onto a date; the staging banner appears and no block
      exists until a time is selected.
- [ ] Tap a 15-minute time in Day; a new Focus Block is created **once**.
- [ ] Repeat Month drop, use the Time button instead; cancel without saving.
- [ ] Drop directly from Inbox onto Day's 15-minute slot still works.
- [ ] Month shows color dots from local tasks and previously authorized Apple
      Calendar events; denied permission causes no crash or prompt loop.
- [ ] A repeating, all-day or overlapping event does not become a duplicate
      Focus Block.
- [ ] Drag gestures remain responsive when the task drawer itself scrolls.
- [ ] Now, Focus timer, Live Activity, and shielding flow are unchanged.
- [ ] Accessibility text sizes and VoiceOver labels remain usable.

## Known constraints

- Only the current visible **month's** Apple EventKit events are fetched by
  the new month loader. Google's existing cached changes remain available as
  before; Google OAuth still needs setup for direct Google syncing.
- Month drop is deliberately a **two-step transaction**: the initial drag
  ends on the date, and the time is then selected in Day. A drag cannot
  continuously span a structural view change and create a block invisibly.
- The Day grid retains the existing 24-row display and 15-minute slots; it
  does not address its separate 25-hour daylight-saving-day limitation.
- No undo functionality is introduced in this change; that is a separate
  audit recommendation and should be tackled independently.
- Always back up your current Xcode project and test the Preview scheme before
  upgrading a signed Full build.
