# IGNITION - COMPLETE FEATURE INVENTORY & CLAUDE REVIEW CONTRACT

**Snapshot:** 2 November 2026 | **Base:** `IGNITION_PLAN_DAY_MONTH_FULL_XCODE_2026-11-02.zip` | **New release:** `IGNITION_INTEGRATED_CIRCULAR_HOME_FULL_XCODE_2026-11-02.zip`

**READ FIRST - status language:** `NEW` means source code is present but NOT proven on a real iPhone. `EXISTING` means source was already present. `FOUNDATION TESTED` refers ONLY to deterministic tests runnable without Apple SDK. `DEVICE UNVERIFIED` means native UI or entitlements still need Xcode+device tests. `NOT IMPLEMENTED` means do not claim the feature works.

## Product intention
Ignition is a start-and-stay-focused iPhone app: choose a task, see a contextual daily clock, Lock In, optionally shield selected distracting apps, continue a truthful wall-clock session, pause/break/return/end safely, then review what happened. It also includes Plan (Day / Month), drag/drop, task creation and dictation, calendar links, audio, reminders, and system widgets.

**Design direction:** Home uses a circular day clock, warm sun / night palette, a prominent round blue Lock In control, selected task, duration and a quiet 2-3-item upcoming drawer. Focus stays a *separate* minimal starry dark screen with an approximately bottom-third progress, timer, task and Pause/Break/End dock. Never turn Focus into another planner.

## Feature-by-feature inventory (source-backed, not a marketing promise)

| Area | Feature | Status | Implementation files | Acceptance test |
|---|---|---|---|---|
| Home | Circular daytime Home with sun marker and contextual sky | NEW - needs iPhone | `Sources/App/NowView.swift` | Check 6 AM, noon, 9 PM, midnight; sun and markers match time |
| Home | Circular Lock In control and visible task title | NEW - needs iPhone | `Sources/App/NowView.swift` | Tap Lock In with chosen duration; opens dark Focus |
| Home | 24-hour clock with task/event/block/session markers | NEW - needs iPhone | `Sources/App/NowView.swift` | Events at correct local time; tap to choose; no collisions in packed day |
| Home | Full-day clock expansion and preview | NEW - needs iPhone | `Sources/App/NowView.swift` | Expand, swipe preview, back to Now; never start at previewed time |
| Home | Context-aware suggested duration before a meeting | NEW - needs iPhone | `Sources/App/NowView.swift` | 6 min before meeting suggests 2 min; no accidental overrun |
| Home | Up to 3 upcoming items; expand for more | NEW - needs iPhone | `Sources/App/NowView.swift` | Long titles, zero tasks, accessibility size |
| Home | Persistent selected task/block vs quick focus | EXISTING - needs iPhone | `Sources/App/AppModel.swift` | Select, launch, relaunch, confirm identity persists as intended |
| Focus | Starry dark Focus screen with bottom timer dock | EXISTING - needs iPhone | `Sources/App/FocusAndReturn.swift` | Dock occupies roughly bottom third on typical iPhone |
| Focus | Pause, resume, 5-min break, end, emergency exit | FOUNDATION TESTED + device needed | `Sources/App/AppModel.swift; FocusAndReturn.swift` | Time accounting, audio, release and status across all transitions |
| Focus | Durable session events / actual elapsed time / outcomes | FOUNDATION TESTED | `Sources/Shared/SessionCore.swift` | Force quit, relaunch, expiry, break, decline review |
| Focus | First move / Start Small / Resume Anchor / Close | EXISTING - needs iPhone | `Sources/App/FocusAndReturn.swift` | Unfinished outcome saved without falsely marking task complete |
| Protection | Choose distracting apps, categories, websites | EXISTING - full signed build only | `Sources/App/ProtectionService.swift; SettingsView.swift` | Authorize, select apps, apply/read back, emergency release |
| Protection | Automatic shield during >=16-min sessions | EXISTING - full signed build only | `Sources/App/ProtectionService.swift; Sources/Monitor/Monitor.swift` | Start, pause, break, expiry and restart; no orphan shield |
| Protection | Short sessions are timer-only for safety | EXISTING - full signed build only | `Sources/App/ProtectionService.swift` | 2/5/10/15 min cannot leave stuck shield |
| Protection | System-wide Do Not Disturb / mute all notifications | NOT IMPLEMENTED / not promised | `Not in project` | Do not present Screen Time app shielding as system notification silencing |
| Live Activity | Lock Screen / Dynamic Island countdown and progress | EXISTING - device unverified | `Sources/App/LiveActivityService.swift; Sources/Widgets/IgnitionWidgets.swift` | Full + Preview signing, pause/resume, background, compact/expanded |
| Widgets | Home Screen next-focus/ongoing widget | EXISTING - device unverified | `Sources/Widgets/IgnitionWidgets.swift` | Add widget, update from app group, tap opens app |
| Widgets | Lock Screen and Dynamic Island interaction controls | PARTIAL | `Sources/Widgets/IgnitionWidgets.swift` | Current widgets link to app; independent pause/+5 Intent controls not delivered |
| Audio | Silence, piano, soft rain, brown noise | EXISTING - device unverified | `Sources/App/FocusAudioPlayer.swift` | All bundled WAV paths load; audio mixing works |
| Audio | Persist choice/volume and optional start auto-play | NEW - needs iPhone | `Sources/App/FocusAudioPlayer.swift; SettingsView.swift` | Select in settings, restart app, start focus |
| Audio | Pause on break/pause, resume with focus | NEW - needs iPhone | `Sources/App/AppModel.swift; FocusAudioPlayer.swift` | Bluetooth disconnect, Siri/dictation, background audio |
| Calendar | Day view: 15-minute timed drag/drop | EXISTING - needs iPhone | `Sources/App/PlanView.swift` | Task dragged to exact time; persistence after relaunch |
| Calendar | Month view: full month with calendar markers | EXISTING - needs iPhone | `Sources/App/PlanView.swift` | Swipe months; selected day and all-day rows correct |
| Calendar | Month drop -> chosen day -> choose exact time | EXISTING - browser tested; native unverified | `Sources/App/PlanView.swift` | Drop never silently chooses arbitrary hour |
| Calendar | Five-second in-app scheduling confirmation + Focus | UPDATED - needs iPhone | `Sources/App/PlanView.swift` | Drag task onto day; toast offers Focus, auto dismisses after 5 s |
| Calendar | Focus blocks with multiple linked tasks | FOUNDATION TESTED | `Sources/App/Domain.swift` | Reorder, assign, move/resize; no accidental task completion |
| Calendar | Apple EventKit import and local event conflict rules | EXISTING - needs iPhone | `Sources/App/CalendarService.swift; AppModel.swift` | Permission denied, calendar edits, imported read-only |
| Calendar | Optional direct Google OAuth integration | CONFIGURATION REQUIRED | `Sources/App/GoogleCalendarService.swift` | OAuth ID and callback not configured; use iOS Calendar first |
| Creation | Quick add via task sheet | EXISTING - needs iPhone | `Sources/App/PlanView.swift; TaskEditor` | Task, duration, due time, fixed event |
| Creation | Speech-to-text task and event draft with confirm | EXISTING - device unverified | `Sources/App/VoiceCapture.swift; VoiceDraftParser.swift` | Spoken time parsed, user edits before saving; mic permission |
| Alerts | Completion alert when timer expires | EXISTING - device unverified | `Sources/App/Notifications.swift` | Background, Focus mode permissions, tap to return |
| Alerts | Planned-task reminders / optional missed-start Rescue | EXISTING - device unverified | `Sources/App/Notifications.swift` | Only scheduled tasks, one Rescue, cancel after completion |
| Alerts | Start Focus action on planned task notification | NEW - needs iPhone | `Sources/App/Notifications.swift; AppModel.swift` | Tap explicit action, launch/cold launch, correct task chosen |
| Alerts | Break-over local notification | EXISTING - device unverified | `Sources/App/Notifications.swift` | Scheduled, canceled on resume |
| Preferences | Timer default and haptics toggle | EXISTING - device unverified | `Sources/App/SettingsView.swift` | App relaunch, selection consistent |
| Preferences | Screen Time permissions, selection, emergency release | EXISTING - full signed build only | `Sources/App/SettingsView.swift` | No misleading active/protected status |
| Preferences | Audio, Google/Apple Calendar, Live Activity and alerts | EXISTING + UPDATED | `Sources/App/SettingsView.swift` | Status displayed honestly, preference persists |
| Reliability | Preview/Full Xcode schemes and CI workflow | CONFIGURED - run externally | `Ignition.xcodeproj; .github/workflows` | CI xcodebuild green plus physical device acceptance |
| Reliability | Developer signing and App Group identifiers | SETUP REQUIRED | `Sources/Shared/SharedConfiguration.swift` | Replace com.example... with owned IDs, approved Family Controls |
| Accessibility | VoiceOver labels, reduced motion, large text | PARTIAL - needs audit | `NowView.swift; PlanView.swift; widgets` | Accessibility Inspector, >=XXXL Dynamic Type, reduce motion |
| Future | Siri / Action Button / Control Center direct quick start | NOT IMPLEMENTED | `Not in project` | Needs AppIntents and device verification |
| Future | User-controlled notifications muting / DND automation | NOT IMPLEMENTED / OS limited | `Not in project` | System Focus is separate; do not claim full notification suppression |

## P0 - blockers before calling this a working iPhone app

1. Run `bash Scripts/verify_revision.sh` (passes locally in this environment), then a **real** Xcode build of `Ignition-Preview` in GitHub Actions and on macOS. This environment has no Xcode or iOS SDK; `swiftc -frontend -parse` is syntax parsing, not iOS type checking.
2. Run `Ignition-Full` signed on a physical iPhone with a paid Apple Developer team and properly configured **Family Controls** plus matching **App Groups** on app + all extensions. Do not substitute Preview for shielding tests.
3. `Sources/Shared/SharedConfiguration.swift` and the project still use `com.example.ignition` / `group.com.example.ignition` placeholders. Use `Scripts/configure_signing.py` carefully and verify migration/backup of any existing app-group data before changing identifiers.
4. Test the Lock Screen widget, Dynamic Island expanded/compact/minimal, timer deadline, pause/resume/break while app backgrounded, device lock/unlock, reboot, force quit, and Live Activities disabled.
5. Test app shielding applied and released under permission denied, under-16-min focus, break, pause, timer expiry, app force quit, unauthorized status, manual emergency release, and monitoring extension recovery.
6. Test audio startup, manual silence, volume persistence, pause/break, return, music app coexistence, incoming calls, route changes and background continuation.
7. Test 24-hour dial across noon/midnight/DST, with 0/3/15+ events, long labels, VoiceOver, accessibility text and Reduce Motion. The expanded clock is an interaction candidate, not certified.
8. Test Plan Month -> Day drag, exact 15-minute placement, five-second actionable toast, automatic dismissal and no accidental task completion.
9. Test local notifications granted/denied and explicit Start Focus action, including cold launch. The notification may be suppressed by iOS or the user Focus mode; never claim guaranteed delivery.
10. Voice transcription and Apple/Google calendar writes require user permission, editable drafts and explicit confirmation; Google direct OAuth credentials are intentionally not bundled.

## P1 - prioritized next implementation gaps

- Add native UI screenshot tests, long-title/XL accessibility tests and performance instrumentation to CI.
- Build an explicit 24-hour dial state model instead of relying on marker collisions in crowded days; show only the next label by default.
- Improve first-move / 2-minute re-entry CTA on Home, and visually link selected task interval to the clock.
- Add genuine AppIntents for Home/Lock Screen/Action Button shortcuts only after session state and entitlement tests pass.
- Decide how to persist the calendar as a read-only intelligence source versus claiming it is the central task system.
- Consider a reusable button/action in the Live Activity (Pause / +5) but test background execution and permissions first.
- Consider protection allow-list only as an independently tested optional beta, not by silently changing the safe existing block-list default.

## Technical notes for Claude (read carefully)

- `NowView.swift` retains the earlier implementation as `LegacyNowView` for rollback; the new `NowView` is circular. Do not accidentally edit only the legacy view.
- `FocusAndReturn.swift` retains the starry Focus view and bottom dock; it was not swapped for a circular daytime scene.
- Audio track, volume and auto-play preference now use standard `UserDefaults`; manual Stop in Focus chooses Silence, while an ordinary pause holds the configured sound until resume.
- A scheduled task reminder registers an explicit Start Focus notification action, stores task ID for cold launch, and calls `AppModel.lockIn()`. It never starts focus merely because a notification arrived.
- Plan completion banner is an **in-app confirmation** visible for five seconds. It is NOT a notification guaranteed to appear when the app is backgrounded.
- Widget and Live Activity code was pre-existing. It has not been compiled or run in Xcode here. It is inaccurate to call these features verified or ready for production.
- Focus audio does not imply an app can programmatically enable system Do Not Disturb or silence all other app notifications. Selected-app shielding is a different Apple framework.

## Test reporting template

For each feature, Claude should report: `status / path and function / build evidence / test device+OS / steps / expected / actual / logs / severity / proposed patch`. Do not mark "works" from a mockup, source parsing, or a passing Foundation test alone.

## Apple documentation reference links

- Family Controls authorization and entitlement: https://developer.apple.com/documentation/familycontrols
- Live Activity lifecycle and Lock Screen/Dynamic Island: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- Live Activity interface guidance: https://developer.apple.com/design/human-interface-guidelines/live-activities
