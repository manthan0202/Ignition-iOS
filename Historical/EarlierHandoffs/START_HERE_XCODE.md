# IGNITION — Open directly in Xcode

**This is a genuine Xcode project.** No XcodeGen, Homebrew or code generation is necessary.

## Open the project

1. Unzip `Ignition_Xcode_Project_2026-10-30.zip`.
2. Open **`Ignition.xcodeproj`** (double-click it). Do not open `project.pbxproj` directly.
3. In Xcode's scheme menu select **`Ignition-Preview`**, choose an iPhone simulator, then press **Run (▶)**.
4. This Preview build intentionally runs **timer-only**, without app shielding or signed app extensions. It preserves the Now/Living Day, Plan, Focus, Return, Close, voice/calendar, and local focus audio source.
5. When it works, select `Ignition-Full` to build the app with widgets, Lock Screen/Dynamic Island Live Activity and Screen Time extensions. This requires an Apple Developer Team and valid Family Controls and App Groups capabilities, then actual physical-iPhone testing.

**Why two schemes?** Previous archives had no `.xcodeproj` and attempted to depend on entitlements even when simply previewing the UI. The Preview scheme is separate so you can open and inspect the app without signing five extension targets. It **does not verify** the Full scheme.

## To sign the Full scheme

Choose an Apple Developer Team for `Ignition`, `IgnitionWidgets`, `IgnitionDeviceMonitor`, `IgnitionShieldConfig`, and `IgnitionShieldAction` targets. Create unique bundle identifiers and an App Group in the Developer portal; all targets share that App Group. Family Controls capabilities require Apple's approval/entitlements as applicable.

Optional one-time identifier helper (from this folder):

```sh
python3 Scripts/configure_signing.py com.YOURCOMPANY.ignition YOUR10CHARTEAMID
```

Review Signing & Capabilities in Xcode afterward. This script does not grant Apple entitlements and cannot install or run on your iPhone for you.

## Files you need

- `Ignition.xcodeproj`: real multi-target Xcode project.
- `Sources/App`: SwiftUI UI and integrations.
- `Sources/Shared`: timestamp-driven session engine, event and Widget/Live Activity data.
- `Sources/Widgets`: Lock Screen/Dynamic Island Live Activity + home widgets.
- `Sources/Monitor`, `Sources/ShieldConfig`, `Sources/ShieldAction`: native Screen Time extensions.
- `Assets`: three original synthesized focus-audio files.
- `DesignReference`: unchanged approved visual references. The coded landscape is a vector approximation, not a pixel-identical rendering.
- `Scripts/check.sh`: test the pure-Foundation engine on any Mac with Swift.
- `CRITICAL_REVIEW.md`: what was fixed, what is still unverified and why.

## Known limitations (please read)

- **This project opens directly in Xcode but has NOT undergone a successful Xcode/iOS build in this environment.** Local Swift syntax parsing and Foundation tests are not an Apple SDK typecheck.
- A two-minute or five-minute focus session is **timer-only** by design: Apple's Device Activity minimum monitoring interval is 15 minutes. We removed the previous unverified backdated-interval workaround rather than risk trapping users behind stale shields.
- Five-minute Break now **releases protection** for safety; Pause also releases protection. Full-length focus tries to protect selected apps when authorized.
- Device Activity end callbacks run when iOS invokes them, not on a guaranteed exact second. The main app and shield extensions have additional stale-lease cleanup, but no precise auto-release guarantee can be claimed without iPhone testing.
- An iOS Screen Time shield cannot force-quit another app or silence all notifications.
- Lock Screen/Dynamic Island behavior requires a supported device, system setting and native activity permission. An expired Live Activity can become stale until iOS or the app updates it.
- Music looping and exact background audio cutoff at the timer deadline are not yet verified on an iPhone.
- Apple Calendar sync is opt-in and local-first; recurrence and bidirectional conflict resolution are incomplete.
- Voice transcription is permission-dependent and must be confirmed before it creates tasks/events.

## Before calling the app finished

Run `./Scripts/check.sh`, compile both schemes in Xcode, install Full on a physical iPhone, then carry out `QA_CHECKLIST.md` and record results. A Preview build cannot establish that app shields or Live Activities work.
