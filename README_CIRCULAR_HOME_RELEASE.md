# Ignition - Circular Home Integration (2026-11-02)

This ZIP is a complete editable Xcode project, based on the previously supplied Day/Month calendar project (November 2), not a blank app scaffold. Its existing source files, widgets, monitor and shield extensions, tests, artwork, music and configuration are retained.

## Updated in this release

1. `Sources/App/NowView.swift` - new circular Home with day clock, sun, time-specific markers, circular Lock In, contextual duration, task selector, upcoming items and expanded clock. The prior Home is retained as `LegacyNowView` in the same source file for rollback.
2. `Sources/App/FocusAudioPlayer.swift` - persistent selected sound, volume, autoplay preference, session pause/resume audio rules.
3. `Sources/App/AppModel.swift` - audio lifecycle integration; user-invoked notification action handling with cold-launch persistence.
4. `Sources/App/SettingsView.swift` - clearer sound preferences and honest Screen Time descriptions.
5. `Sources/App/FocusAndReturn.swift` - explicit Silence when the user manually stops audio inside Focus.
6. `Sources/App/PlanView.swift` - task drop confirmation with a Focus button is visible for 5 seconds (instead of 3.5).
7. `Sources/App/Notifications.swift` - "Start focus" action on scheduled task reminders; does not auto-start from delivery alone.
8. `Sources/App/IgnitionApp.swift` - consume pending notification action after app loads / resumes.

## What is already present (not newly invented)

Day and Month calendars, staged Month-to-Day drop, 15-minute grid, voice drafts, Apple Calendar, optional Google OAuth adapter, session event journal, Focus/Close, dark starry Focus screen, pause/resume/break/end, Screen Time app selection and shielding implementation, WidgetKit home widget, ActivityKit Live Activity UI for Lock Screen and Dynamic Island, local notifications, music resources and CI skeleton.

## Build gate (critical)

Tests that passed here: `bash Scripts/verify_revision.sh`, including Foundation session tests, focus-block invariants, voice parsing, date math, project references and Swift *syntax parsing*. This machine has no Xcode/iOS SDK, so an iOS semantic compile, app launch, Live Activity and Screen Time entitlement verification are still REQUIRED. **Not a production-certified build.**

Run `xcodebuild -project Ignition.xcodeproj -scheme Ignition-Preview -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` on your Mac or in the included GitHub Actions workflow. Run `Ignition-Full` only after signed Family Controls / App Group capability setup on a real iPhone.

## Important setup

- The project uses `com.example.ignition` and `group.com.example.ignition` placeholder IDs. `Scripts/configure_signing.py` can replace them when you know your actual identifiers and Apple team. Changing an existing app group may make prior data appear absent; back it up and plan migration.
- Direct Google OAuth is deliberately not preconfigured (no secrets included).
- Apple cannot be assumed to mute all system notifications merely because selected apps are shielded.
- Sessions below 16 minutes intentionally remain timer-only in the existing Full protection implementation to avoid a stuck shield without a tested release backstop.
- The source contains a Preview scheme without app shielding and a Full scheme with signed Screen Time extensions.

## Suggested Claude workflow

Read `CLAUDE_FEATURE_AUDIT_AND_DEVICE_GATES.md` and `README_CIRCULAR_HOME_RELEASE.md`, inspect the actual code, run CI, then audit and patch ONE high-priority failure at a time. Do not claim iPhone behavior from rendered browser demos or synthetic tests.
