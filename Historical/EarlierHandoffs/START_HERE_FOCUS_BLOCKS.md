# Open the existing Ignition app with Focus Blocks

**Safer installation:** use `Ignition_FOCUS_BLOCKS_3_FILE_PATCH.zip` to update your already working and signed Xcode project. Copy `Domain.swift`, `AppModel.swift`, and `PlanView.swift` into `Sources/App/` of your existing Ignition folder; preserve all other files including `Ignition.xcodeproj`, Widgets, and your existing signing.

**Full project:** `Ignition_FOCUS_BLOCKS_FULL_XCODE.zip` contains an openable `Ignition.xcodeproj` based on the previous interactive-calendar build. It may need your Xcode signing settings again; choose Preview to test without Family Controls entitlement.

In Xcode: Clean Build Folder (Shift-Command-K), build, and run on the same iPhone where Live Activities previously worked.

Test: Plan > add tasks > drag one onto a vacant time slot to create a focus block > drag another task onto the block > drag the **top line** to move > drag the **bottom handle** to resize > tap the block's task area to rename, reorder, and complete tasks. A task can belong to multiple blocks. Block time is different from focus-timer duration.

If the build fails, please share the first Xcode compiler diagnostic; these SwiftUI views cannot be fully typechecked without Xcode/iOS SDK.

See `FOCUS_BLOCKS_UPDATE.md` for engineering details, test limits, and outstanding Now-map integration.
