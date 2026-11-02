# Start here — fix the current installed Ignition without losing its working widgets

**Recommended:** apply the **2-file patch** to the already-signed Xcode project on your Mac. Avoid swapping out a project you finally got signed and working.

1. Save a backup copy of your currently working Ignition project folder.
2. From `Ignition_Home_Motion_2_File_PATCH.zip`, replace these exact files inside your current project:
   - `Sources/App/LivingDay.swift`
   - `Sources/App/NowView.swift`
3. Open your original `Ignition.xcodeproj`. Keep the same **Ignition-Preview** scheme, bundle identifier, Personal Team, and connected iPhone.
4. Choose **Product → Clean Build Folder** (Shift–Command–K), then **Run** (Command–R).
5. Test landscape pan and bottom sheet drag. Lock the phone during focus to confirm the previously working Live Activity still works.

There are NO changes to ActivityKit, WidgetKit, app group, signing, focus session engine, protection, notification, or audio files in this patch. All other project functionality stays as it was.

If you prefer a complete project, `Ignition_Home_Interaction_Full_Xcode_Project.zip` contains the same 2-file changes in the full source tree. This **may require signing settings again** because it is a separate local copy; the two-file patch is safer.

Read `HOME_INTERACTION_FIX.md` for verified defects, limits and the 10-point iPhone QA checklist.

**Critical limitation:** Swift source parsing and Foundation tests passed here. A full iOS build and smoothness on your actual iPhone cannot be confirmed from this environment. The approved image is still a flattened, partly blurry extraction, NOT a layered 2.5D landscape.
