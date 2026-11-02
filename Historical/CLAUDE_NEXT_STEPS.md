# Give this audited project to Claude on a Mac with Xcode

**Do not redesign Ignition.** Now/Living Day, Plan/Calendar, Focus nighttime and the protected Return/Close flows are the approved visual source of truth. Existing screenshots are under `DesignReference/`.

1. Read `AUDIT_RESULTS.md`, then `README.md`, then `project.yml` and every source file.
2. Run `./Scripts/check.sh`. These local tests pass, but they do **not** compile Apple frameworks.
3. On macOS, generate and compile all targets using the installed Xcode SDK. Report exact Xcode error messages with filenames/lines. Fix them one by one. Do not claim device support from compilation.
4. Verify App Group identifiers and signing, Family Controls entitlement across targets, Device Activity monitor extension, ManagedSettings shield extension, widget extension, Live Activities and notifications. Confirm `NSSupportsLiveActivities` etc. Provide one concrete reproducible build command.
5. Physical iPhone scenarios, in priority order:
   - Start 1-minute timer-only, leave the app, return after expiry; verify completed session in history and automatic Close review.
   - Start 25-minute focus with shielding, pause/resume/End/Emergency. Verify selected apps really are shielded and **released**, with correct duration in Live Activity.
   - Start a 2-minute focus with shielding and quit Ignition; verify it unblocks automatically. This Device Activity backdating strategy is *not validated*. If it fails, do not keep users locked behind it; implement an honest timer-only short-session fallback.
   - Repeat with break, restart, revoke permission, device reboot, notifications disabled, force quit.
   - Move/resize a calendar task and check Apple Calendar writeback, duplicate protection, reminder rescheduling, voice input, and widget refresh.
6. The newer direct shield-to-Ignition action is **off by default**, because it needs an SDK exposing `openParentalControlsApp`. Only enable `IGNITION_ENABLE_DIRECT_SHIELD_RETURN` for both shield targets after a real-device test; otherwise the user-visible label must remain **Close distracting app**.
7. Document per-test Pass/Fail/Not run with OS/build/device and diagnostics. No vague “works” claims.
8. Address remaining known gaps in `AUDIT_RESULTS.md` such as scenic map panning, exact background music cutoff and complex recurring calendar events. Do not quietly remove features or substitute fake behavior.

Final output should be a buildable Xcode project, real-device results, and a list of any remaining blockers. Preserve the previous code as a backup and make small, reviewable diffs.
