# Ignition — Unified Now + Plan Release (2026-10-31)

This is a **full Xcode project** built from `Ignition_NOW_Refinement_Xcode_2026-10-31.zip`, plus an implementation of `IGNITION_PLAN_LOCKED_REDESIGN_SPEC_2026-10-31.md`. **No manual patching is required.**

## Open in Xcode

1. Back up your currently working Ignition folder and keep its signing identifiers handy.
2. Unzip this archive. Open `Ignition/Ignition.xcodeproj`.
3. Select **Ignition-Preview** (it includes the Preview Live Activity extension). Configure your Personal Team and unique bundle IDs if needed.
4. `Product` → `Clean Build Folder`, then run on your iPhone.
5. Verify Now, Plan, Focus, and the Lock Screen before replacing the app you currently use.

`Ignition-Full` still needs proper Apple Family Controls entitlements and separate device verification. The Preview target will not shield third-party apps.

## What changed in this build

Only `Sources/App/PlanView.swift` is changed relative to the latest Now refinement baseline. The Xcode target graph, app engine, Now artwork and motion, Focus, audio, Screen Time implementation, and BOTH Live Activity implementations are unchanged.

- Plan title, Add, More instead of four icons and duplicate headings
- Compact selected date + 7-day selector
- Calmer near-white calendar, correctly single-line time label and all-day lane
- Adaptive event cards and a 15-minute focus block short-card variant
- Fixed imported appointments visible on calendar without cluttering task drawer
- Deep slate task drawer with accessible Inbox/Today and one secondary actions menu per row
- Calendar/task divider has one obvious grip with 44-point hit target and accessibility adjustable action
- New event menu opens a pre-scheduled editable event rather than a blank task
- Existing task drag/drop, block membership, resize/move, iOS Calendar, Google calendar, voice, and Focus start flows retained

## Test on an actual iPhone

- [ ] Plan contains exactly one `Plan` header, one Add button and one More button.
- [ ] The date strip switches days, shows Today only when viewing another date.
- [ ] The current-time label is ONE line even at 10:03 AM. No overlapping all-day chips.
- [ ] Create a task; long-press and drop on a time: one new block, same task ID.
- [ ] Create a focus block; add multiple tasks; move and resize in 15-minute steps.
- [ ] Tap a task's `…` for Schedule / Add to block / Edit / Delete.
- [ ] Long-press a task row to drag; ordinary vertical scrolling does NOT resize the drawer.
- [ ] Drag only from the divider handle to change calendar/task heights.
- [ ] Swipe/move 20+ events with overlapping blocks; no clipped titles or cut-off time label.
- [ ] Create a calendar event using Add; choose the appropriate destination explicitly.
- [ ] Connect/sync real Apple and Google calendars; check read-only and failed-write paths.
- [ ] Voice capture, Now landscape, LOCK IN, Pause/Resume, Lock Screen and Dynamic Island remain working.
- [ ] Test with Larger Text, VoiceOver, Reduce Motion, and Accessibility haptics off.

## Verification and limitations

This environment can run Foundation logic tests, structural checks, and Swift source parsing. It does **not** have Xcode or the iOS SDK, so the full SwiftUI **typecheck/build and on-device gesture performance are not verified**. Passing local checks is not equivalent to a production-certified binary.

Run `bash Scripts/check_plan_redesign.sh` for repeatable local checks. On a Mac with Xcode installed, you can additionally run:

```bash
xcodebuild -project Ignition.xcodeproj -scheme Ignition-Preview -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

If the Xcode build shows a compiler error, the **first** error is most actionable. Rebuild within this project rather than reverting to an earlier version or changing the approved design.
