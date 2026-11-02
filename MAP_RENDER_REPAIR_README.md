# Ignition — Blank Living Day render repair (October 30, 2026)

## What this fixes

The prior `LivingLandscape` put a multi-day timeline in a very tall SwiftUI `ZStack`, then offset that entire subtree to the current time. The user observed a completely blank pale screen, with neither scenery nor the independent **Now** marker visible. The new implementation does not use a giant world-sized view. All visible landmarks and the Now marker are projected directly into the current device viewport using immutable timestamps. The background is always a viewport-sized image (with a visible fallback if the image asset is missing).

- `Sources/App/LivingDay.swift`: viewport-only scenery and time markers, bounded panning, three zoom levels, tap-to-open event clusters, defensive artwork fallback.
- `Sources/App/JourneyMechanics.swift`: pure `JourneyViewportGeometry` shared mathematical projection.
- `Tests/JourneyViewportRegressionTest.swift`: 732 assertions on the empty-day Now marker, future and past direction, drag behavior, midnight crossing, and zoom levels.
- `Scripts/check.sh`: includes the new regression test.

## Start here

1. Unzip, open `Ignition/Ignition.xcodeproj`.
2. Select **Ignition-Preview**, your iPhone, and the signing team previously used for that target. Do not switch to **Ignition-Full** on a free personal team.
3. Clean Build Folder (`Shift+Command+K`), then Run (`Command+R`).
4. Without creating any tasks, the scenic background and **Now** pill should display. If the scenery is unavailable, a clearly visible cyan path should appear instead of a blank pane.
5. Create a future task, then inspect the event marker. Drag the landscape: camera and markers should move together; tap **Back to Now**. Pinch to change the time scale.
6. Start a Focus session, lock the phone, and confirm the already-working Live Activity is preserved. No Live Activity source files were modified.

## Verification limits

Foundation tests and Swift syntax parsing were executed on Linux. **Full SwiftUI type checking, Xcode compilation, rendering, signing, and physical iPhone testing are not available here and are not claimed as passed.** The artwork is still the existing imperfect extraction, not new pixel-perfect layered scene art.

Your uploaded 79-second recording appears to show another planner app's onboarding, not a recording of Ignition's blank home. The supplied Ignition screenshot demonstrates the blank-view regression.
