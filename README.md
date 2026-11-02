> **AUDITED COPY (2026-11-01):** Read `docs/AUDIT_2026-10-31.md` first. 7 source files differ from the delivered build (`docs/ignition_audit_fixes.patch`). Not compiled; not device-tested.

> **CURRENT BUILD (2026-10-31):** Read `START_HERE_PLAN_REDESIGN.md` first. This combines the approved Now refinement and the new Plan design. `PLAN_LOCAL_TEST_RESULTS.txt` explains local verification and device limits.

# Ignition — Integrated Xcode source (October 30, 2026)

**Open `Ignition.xcodeproj` directly.** The project retains the approved two-tab **Now / Plan** design direction and the working Focus / Live Activity source. This is the latest merged source baseline, **not an App Store-certified release**.

## Choose the right scheme

- **Ignition-Preview**: select this first on your iPhone. It includes the app, Lock Screen Live Activity and Dynamic Island extension, but deliberately has **no Screen Time shielding**. Select your Personal Team and keep your existing Preview bundle identifier if you want to preserve on-device data.
- **Ignition-Full**: app plus Live Activity, Device Activity monitor, ShieldConfig and ShieldAction. Requires proper Apple Developer entitlements, signing for all targets, and on-device validation. A free Personal Team cannot sign Family Controls (Development).

Open `Ignition.xcodeproj` in Xcode, select **Ignition-Preview**, select your iPhone, **Product > Clean Build Folder**, then Run. Configure Personal Team in the **IgnitionPreview** and **IgnitionPreviewLive** targets if asked. Do not select the full `Ignition` target merely because its Signing panel is visible.

**Back up your working project before replacing it.** Changing the bundle identifier creates a separate app and does *not* automatically move your existing tasks and history into the new one.

## Features included and their verification status

| Feature | Source status | Verification |
|---|---|---|
| Focus timer, Pause/Break/Return, persistence | Existing code preserved | Foundation model tests pass; previous user iPhone sessions confirmed timer runs |
| Lock Screen / Dynamic Island | Existing source unchanged | Previously observed working on the user's iPhone; re-check after installation |
| Living Day scenic Now | Three scene planes; fixed-position browsing; Near/Hours/Day zoom; timestamped footprints; bounded clusters opening a list; rolling multi-day timeline | Pure date/cluster tests pass; iPhone motion not independently verified |
| Plan, tasks and focus blocks | Hour timeline, all-day lane, separate tasks drawer, drag/drop, resize, multi-task blocks | Model tests pass; iPhone gestures not independently verified |
| Voice task/event entry | Waits for `SFSpeechRecognizer` final result with bounded fallback and editable confirmation draft | Parser tests pass; microphone callback not tested on device here |
| Apple/iOS Calendar | EventKit read, save, delete; keeps unsynced local edits | Platform code present; requires device/account validation |
| Google via iPhone Calendar account | EventKit route (preferred) | Requires adding Google account in iOS Settings and testing |
| Direct Google Calendar API | OAuth PKCE sign-in, fetch, create, patch with ETag, delete, stable IDs, durable token checkpoint | **OAuth client ID + callback must be configured**; not tested against a live Google account; recurring exceptions incomplete |
| Music | Bundled audio and background audio configuration | Source present; verify actual lock/background audio route |
| App shielding | Family Controls + Device Activity extensions | Full scheme requires Apple entitlements; short sessions may be timer-only |

The third approved Journey image remains in `DesignReference/APPROVED_NOW_REFERENCE_OCT30.png`. The bundled scenic asset was extracted from a flattened picture and remains imperfect; the code adds bounded parallax, **not genuine 3D terrain**.

## Quality controls

Run `bash Scripts/verify_revision.sh` from the project folder to re-run the local tests and project checks on a Mac with Swift installed. These tests do **not** replace a full Xcode build or physical-device testing. See `ENGINEERING_REPORT.md` and `DEVICE_QA_CHECKLIST.md`.

## Important provider limitations

- Google direct OAuth needs the correct `IgnitionGoogleOAuthClientID` and registered reversed URL scheme in `Config/IgnitionPreview-Info.plist` and `Config/Ignition-Info.plist`. No account secrets are included in this repository.
- When a Google calendar is already exposed via Apple EventKit, **don't also enable direct Google API for the same calendar**. Dedupe by iCalendar UID is a best effort, not guaranteed for every provider exception.
- Foreground refresh is about every 60 seconds while Plan is shown, plus user refresh, scene/calendar change and immediate in-app writes; **iOS cannot guarantee 1-minute background sync**.
- Existing focus blocks are local planning reservations; they are not themselves guaranteed externally synchronized calendar events. Editable external calendar events are a separate entity.
- Recurring Google event expansion, timezone edge cases across all providers, and network conflict UX must be validated and extended before commercial release.
