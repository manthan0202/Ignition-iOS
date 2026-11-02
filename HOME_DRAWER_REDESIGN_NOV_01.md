# Ignition — Home drawer simplification / November 1, 2026

Baseline: user's **Ignition_2026-10-31_AUDITED_Xcode.zip**. This is a **targeted Home drawer revision**; it is not a redesign of the entire app.

## What changed

- **One coherent drawer rather than two changing layouts.** The action area remains fixed, regardless of how far the user drags. Its task list is below the fixed area and becomes visible when expanded. The old crossfade between compact and expanded content has been removed.
- **Two predictable positions**: compact and open. No halfway state that feels stuck. The whole 220-point action area responds to a drag (290 points for accessibility text sizing), not merely the small grab handle.
- **Prominent Lock In button first.** Beneath it: one `Focus on` selector; concise duration, truthful blocking status, and `2-min start`. No competing labels in the compact panel.
- **Simplified expanded Today list.** Scheduled tasks and focus blocks appear chronologically under one heading, with unscheduled tasks following. No repeating **Up Next / Focus Blocks / Scheduled / Anytime** headers. Tasks assigned to a focus block are not repeated on the list.
- **Consistent icons and restrained type colors.** Teal checkmark for tasks, violet calendar for fixed calendar events, blue stacked rectangles for focus blocks. Selected items receive a subtle blue highlight. The CTA stays blue.
- **Selecting an item in the expanded list collapses the sheet** so the selected focus target is visible in the compact drawer and on the map.
- Added Foundation-only regression tests of drawer drag positions, thresholds, direction, and flick behavior.

## Left deliberately unchanged

- Living Day imagery and mapping, including image seams, blurred source art, and approximate `routeX` anchors. The existing picture cannot make a fully coherent route: the upper half does not contain a visible road at all, and its top/bottom edges are not seamless. A high-quality continuous road / coordinate-matched terrain art asset is required for the next separate change.
- Plan and calendar editing, the focus session engine, Screen Time shielding, live activities and widgets, notification behavior, data persistence and signing.

## Technical checks executed in this environment

- Swift source syntax parse: passed.
- Drawer Foundation tests: 5,011 assertions passed.
- Journey time/viewport tests: 732 assertions passed.
- Session smoke tests and stress tests: passed.
- Xcode project references and compiled-source membership: passed.
- Existing release design checks adjusted for the new Today typography/two-detent hierarchy: passed.

**Not performed:** macOS / Xcode SwiftUI typecheck, simulator run, actual on-device drag testing, frame pacing, VoiceOver or Dynamic Type screenshots. Do not consider the motion polished until those tests pass.

## Test on your iPhone, one change at a time

1. Open Now. The drawer starts compact with the blue **LOCK IN** button, **Focus on** target, and one small row of useful settings.
2. Swipe upward anywhere in the top 220-point panel. It should follow the finger and settle expanded without stopping halfway. Swipe downward from the same large top area to close. Tapping the handle should also toggle.
3. With the panel open, scroll the list separately. Scrolling the task list should not move the background scenery. Select a task: the sheet should close and the task should now be selected on Home.
4. Change **25 min**, choose a task, start a session and verify the timer, protective state, return route, Lock Screen and Dynamic Island as in the earlier build.
5. Try a short flick, a slow drag, a tap on **LOCK IN**, and an accessibility font enlargement. Report any cases where button taps accidentally move the drawer or gestures feel unresponsive.
6. The map image issues from November 1 video are **not fixed by this drawer-only patch**. Do not evaluate terrain quality as part of passing this test.

## Applying the patch

A. Safest: open the included **full project ZIP** as a *new* Xcode project rather than overwriting your working version.
B. Existing project: replace the two Swift files in `Sources/App/` below. The test and check script can also be replaced if you want matching automated regression guards.

Changed files:
- `Ignition/Sources/App/NowView.swift`
- `Ignition/Sources/App/JourneyMechanics.swift`
- `Ignition/Tests/NowDrawerMechanicsTest.swift`
- `Ignition/Scripts/check_studio_release.py`

Do not merge only `NowView.swift`: it depends on the revised drawer geometry API in `JourneyMechanics.swift`.
