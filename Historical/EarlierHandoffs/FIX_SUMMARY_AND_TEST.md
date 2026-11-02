# Ignition — Live Activity and approved scenery repair

## Concrete faults in previous project

1. `Ignition-Preview` contained no WidgetKit extension. `LiveActivityService` could request an ActivityKit activity, but the system had no installed `ActivityConfiguration` to render it on the Lock Screen / Dynamic Island.
2. The approved scenic PNG did not load in the installed Preview app (observed as a pale blank background). The prior project copied a standalone PNG. This repair adds `Assets.xcassets/JourneyScenery.imageset/JourneyScenery.png` to the **Preview and Full** app resource build phases and loads it with an explicit `UIImage` resource check. If unavailable, a visible error replaces the silent blank scene.
3. `Back to Now` visually overlapped the header when the user dragged the map. Its placement is moved below the header.
4. ActivityKit authorization / request failures were silently logged. Live Activity status is now visible in Ignition Settings.

## What changed

- New Xcode target `IgnitionPreviewLive` (no Screen Time or App Group entitlement). Its extension is embedded in **IgnitionPreview.app**. It contains `ActivityConfiguration` with Lock Screen, Dynamic Island compact, expanded, minimal layouts.
- Existing `IgnitionWidgets` and Full scheme preserved unchanged for paid/entitled future testing.
- `NSSupportsLiveActivities` already exists in the Preview app Info.plist.
- Added approved scenery image asset catalog to both app targets.
- Added Settings diagnostics for Live Activity permission and request outcome.

## How to run on your iPhone

1. Unzip this package; open `Ignition.xcodeproj`.
2. Select the `Ignition-Preview` scheme and your **physical iPhone**, not Ignition-Full.
3. Under `TARGETS > IgnitionPreview > Signing & Capabilities`, select your Personal Team and a unique bundle identifier, e.g. `com.yourname.ignition.preview`.
4. Under `TARGETS > IgnitionPreviewLive > Signing & Capabilities`, select the SAME Personal Team. Set its bundle identifier to the **app identifier plus `.live`**, e.g. `com.yourname.ignition.preview.live`.
5. Product > Clean Build Folder; run on the iPhone.
6. On the phone, allow Live Activities for the Preview app in Settings (if offered). Start LOCK IN (25 minutes), return to Home Screen, and lock the device.
7. Check both Lock Screen and Dynamic Island. If missing, open Ignition Settings and read the `Live Activity · Lock Screen and Dynamic Island` section for status. Report first Xcode error or this status.

## Actual verification done here

- Swift syntax parsing: pass.
- Foundation session-engine smoke test: pass.
- Session stress test: 28 assertions passed.
- `plutil` project validation: pass; no dangling project references.
- Approved scenic PNG present under asset catalog referenced by both app targets.
- Preview target embeds new widget extension and declares target dependency.

## Not verified / remaining constraints

- Xcode/iOS SDK compilation **not available** in this runtime.
- Installation, Personal Team signing for new preview widget, and iPhone Live Activity display **not tested**.
- Full Screen Time shielding still needs Family Controls entitlements and a real-device test. Preview deliberately runs timer-only.
- Scene is cropped from a flattened approved concept, not exact layered artwork; the visual reference is unchanged, but fidelity still requires an on-device screenshot check.
- Does not implement all advanced features or certify the full app as production-ready.

## Important

Do **not** change to `Ignition-Full` simply to test Live Activities: it includes restricted Family Controls capabilities and will fail signing on a free Personal Team. `Ignition-Preview` now has an entitlement-free Live Activity extension so this subsystem can be tested separately.
