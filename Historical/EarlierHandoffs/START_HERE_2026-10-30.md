# Ignition — integrated Xcode handoff (October 30, 2026)

**Open `Ignition.xcodeproj` directly in Xcode.** This package supersedes earlier ZIPs/patches. It does not need Claude or XcodeGen.

## What was changed in this revision

- NOW / Journey: one time-coordinate system tied to the current day, Now anchor weighted toward the lower part of the viewport, near/mid/day zoom including pinch gestures, time-based `2+`/`3+` clustering with expandable native list, more future context, scene/pin movement from a common camera.
- PLAN: a smaller header, slate-blue/warm-off-white surfaces and existing calendar/task drawer. Retains existing drag task to block, move/resize, multiple tasks per block, 15-minute snap and actual Now line.
- Voice add: `Done speaking` stops the mic without immediately canceling the recognizer; retains final transcript, parses common dates and durations, and presents an editable Task / Focus Block / Event draft. Nothing is saved until Confirm.
- Calendar: EventKit import AND write for iCloud / Google calendars registered in iOS Calendar, foreground refresh on Plan open/date change/EventKit notification and ~60-second visible-screen polling, stable identity and pending write states. Imported remote deletion/movement is reconciled only inside the selected day and does not touch standalone tasks or actual sessions.
- Direct Google API (advanced): added OAuth PKCE / Keychain token refresh, paginated calendar/event reading and incremental sync, token-expiration recovery, ETag-conditional edit, and explicit 412 conflict selection. **This path needs Google Cloud OAuth configuration and is not functional out of the box.** The simpler supported route is to add the Google account in iPhone Settings → Calendar, then enable Apple Calendar in Ignition; EventKit can read/write that calendar.
- Existing focus engine, Live Activities, widgets, Screen Time and audio files remain unchanged. The user has observed Dynamic Island/Lock Screen working in a previous build; regression on this updated build still requires device testing.

## Running on an iPhone

1. Back up your existing Xcode project and its local app data.
2. Open `Ignition.xcodeproj`, select **Ignition-Preview**, select your iPhone.
3. Under **TARGETS → IgnitionPreview → Signing & Capabilities**, choose your Personal Team and unique bundle ID; likewise configure the **IgnitionPreviewLive** extension.
4. Press Shift-Command-K (Clean Build Folder), then Command-R.
5. Start a session and test the Lock Screen/Dynamic Island again. **Do not switch to Ignition-Full** unless your Apple team can use Family Controls.
6. Add your Google account under iPhone Settings → Calendar → Accounts to enable Google-through-EventKit without Google Cloud setup. In Ignition Settings tap **Connect or refresh Apple Calendar**. Grant full calendar access.
7. Use Plan: drag/resize blocks, add tasks, tap microphone → speak → **Done speaking** → review → confirm. Pull to expand calendar. Test zoom/cluster on Now with several close events.

## Direct Google API optional setup

You must create an iOS OAuth client in your own Google Cloud project, enable Google Calendar API, configure OAuth consent/test users, set `IgnitionGoogleOAuthClientID` in **both** app Info.plists to the client ID, and register the Google reversed client ID callback URL scheme in each `CFBundleURLTypes`, e.g. `com.googleusercontent.apps.<id>`. No client secret. These credentials cannot be fabricated or prebundled for your account. Then connect in Settings. Avoid connecting the exact same Google calendar both via EventKit and direct API; event UID-based deduplication is best effort, not a guarantee.

## Must-pass device checks before treating anything as finished

- Start a focus session; move to another app, lock device; Live Activity countdown remains correct; finish and relaunch without stale protection.
- NOW: pinch zoom, drag backward/forward; Now marker should not jump; 3 nearby events cluster and can be selected; no hidden or duplicated task landmarks; footprints remain tied to actual start time.
- PLAN: resize block, drag one task into a multi-task block, change date, scroll to Now; force-quit and relaunch; edits still there.
- Voice: dictate, tap Done speaking, verify the final recognized words remain; edit draft; confirm once; deny mic permission and use keyboard.
- Calendar: iCloud and Google via EventKit—import, edit, verify in source Calendar app; make an external edit, reopen Plan/pull refresh; test offline, permission revocation and conflicting edits.
- Direct Google OAuth/API—cannot be certified until you configure a real Google client and account. Test first/next pages, 410 expired token, 412 version conflict, disconnect and reconnection.

## Known limitations (do not claim full functionality)

- No Xcode/iPhone SDK is available in this environment: Swift files were syntax-parsed and Foundation code tested, but **full iOS compilation and UI behavior remain unverified**.
- The background artwork is still a previously extracted flattened image with softness/blur in places. Zoom/perspective of pins is a **2.5D-like navigation treatment**, not true layered 3D terrain or a replacement of the approved third visual reference.
- iOS cannot guarantee a background calendar refresh every minute; 60 seconds is only a foreground polling target.
- Direct Google API currently imports and conditionally edits existing Google events; creating new events via the *direct Google API*, advanced recurrence editing, and robust cross-path deduplication still require further engineering/real-account tests. Creating a calendar event through **EventKit** works for an iPhone-registered Google calendar when it is the selected writable destination.
- Apple Screen Time shielding still requires the Family Controls entitlement/physical-device verification; Preview is timer-only.
- Voice parser covers common English dates/times and single-item drafts, not arbitrary natural language or multi-command utterances.

This package is a functional development candidate, **not a claim of production readiness**. Existing approved visual reference: `DesignReference/APPROVED_NOW_REFERENCE_OCT30.png`.
