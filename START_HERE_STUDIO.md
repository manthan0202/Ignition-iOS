# Open the current code in Xcode

1. Back up your current working project and make sure it can be restored.
2. Unzip this download into a new folder. Open `Ignition.xcodeproj` inside the `Ignition` folder.
3. Select **Ignition-Preview** in the Xcode toolbar, your physical iPhone, and your **Personal Team** under the `IgnitionPreview` target's Signing & Capabilities. Use a unique preview bundle identifier if Xcode asks for one. `IgnitionPreviewLive` must share the corresponding prefix and valid signing.
4. Clean Build Folder (Shift-Command-K), then Run (Command-R).
5. Test the Now sheet / Plan drag / Focus / Lock Screen / Dynamic Island in that order. Follow `RELEASE_NOTES_STUDIO.md` for explicit acceptance cases.
6. The **Ignition-Full** scheme contains Screen Time extensions and requires Apple developer entitlements; it won't sign using a free Personal Team. Preview does not block apps.

**Important:** The project passed Linux checks, but Xcode compilation and tactile performance were not possible here. Do not overwrite your last working version until this build runs successfully on your phone.
