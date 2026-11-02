# Ignition: Plan-screen revision after Oct 31 iPhone recording

This is a directly openable Xcode project. It retains the previously approved Now/Focusing screens and the existing Live Activity target. The substantive Plan redesign is in `Sources/App/PlanView.swift`. The additional natural-speech correction is in `Sources/App/VoiceDraftParser.swift`, covered by `Tests/VoiceDraftParserTests.swift`.

## What this release changes

- Simplifies Plan to **one header** with Add and More, plus a compact date/week selector.
- Uses a quiet light calendar, a contrasting slate task drawer, and one trailing actions menu per task.
- Gives cramped timeline blocks adaptive content instead of several clipped controls.
- Preserves drag-to-schedule, task/block editing, block resizing, the drawer divider, and event sync services.
- Voice request "Can you add cardiology to my schedule for tomorrow 5 PM" now proposes a calendar event titled "cardiology" at 5 PM tomorrow rather than a raw-sentence task. Confirmation remains required to prevent unintended appointments.

## Open

Unzip > `Ignition/Ignition.xcodeproj` > choose `Ignition-Preview` > choose your iPhone > configure your own existing signing identifiers and team if needed > Clean Build Folder > Run. Do not overwrite the current working copy without a backup.

## First device checks

1. Plan has no duplicated toolbar or clipped current time label.
2. Drag an unscheduled task from slate drawer to a calendar time.
3. Move and resize the resulting block and verify tasks are still attached.
4. Drag the divider independently of the task list.
5. Voice: say "Can you add cardiology to my schedule for tomorrow 5 PM", tap Done speaking, verify title/time/type, then choose Confirm and add.
6. Start Focus, lock phone, and verify existing Live Activity remains visible.

## Verification scope

`bash Scripts/check_plan_redesign.sh` and the updated Foundation voice parser tests passed on Linux. Full Xcode compilation, Apple Calendar/Google OAuth access, gesture feel, haptics, system shields, and Live Activity rendering on iPhone are NOT tested in this environment. The source is not a certified production build.
