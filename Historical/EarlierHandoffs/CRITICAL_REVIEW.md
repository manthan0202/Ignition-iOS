# IGNITION — Critical source review (30 October 2026)

## Decision

The old archive was **not Xcode-ready**. It had only `project.yml` and required XcodeGen, with unverified native integration and an unsafe short-session monitoring workaround. This revision is a direct-open Xcode project with a safe simulator Preview scheme, native Full scheme, the same approved design assets and tighter state handling.

## Changes in this revision

| Risk | Correction |
|---|---|
| No Xcode project | Generated real `Ignition.xcodeproj`, six target references, embedded extension build phase, shared schemes, and valid Info.plist files |
| No immediate way to inspect UI without entitlement | Added `Ignition-Preview` target with non-shielding ProtectionService; safe for preview/simulator |
| Short sessions relied on a backdated activity monitor | Removed trick; under-16-minute sessions are timer-only rather than risking unreleased shields |
| Protection reported active from a stored lease even if shield was removed | Added actual ManagedSettingsStore shield checks and kept session state honest |
| Refresh could change a timer-only session to "protection ready" | Preserved actual timer-only state while the session is ongoing |
| Expired shield could still show if Device Activity callback was delayed | Shield configuration/action extensions attempt to clear their own expired lease on subsequent access (best-effort) |
| Nested protection changes could be invisible on Now | AppModel now forwards ProtectionService publisher changes |
| Calendar drag/resize was using inconsistent write paths | Edits now go through a single local-first save and reminder/writeback queue |
| Task's saved next step could leave its reminder stale | Re-schedules reminder after next-step updates |
| Journey pan snapped back every time | Keeps pan position and provides a Back to Now control; preserve original approved aesthetic |
| Default timer duration reset on relaunch | Persisted preference to UserDefaults |
| Imported read-only calendar events were still editable | Editing controls disabled for fixed events |
| Five-minute break falsely implied protection continues | Clearly marks it as unprotected, safe-release fallback |

## Verification actually performed

- `plutil -lint` passes for the generated `project.pbxproj`; **six targets** and product references are present.
- All project object references resolved in a JSON round-trip structural audit, with **zero dangling references**.
- Every `Config/*-Info.plist` parses as an Apple property list.
- All Swift source files pass local `swiftc -frontend -parse`.
- The pure-Foundation smoke test passes.
- The expanded deterministic session stress test passes its 28 assertions and 75 repeated sessions (per inherited suite).

## Not verified or guaranteed

- Full Xcode compilation and type checking against Apple's iOS SDK: **unverified** (this environment does not have Xcode).
- Launch on iPhone simulator or physical iPhone: **unverified**.
- Family Controls entitlement/provisioning: **unverified and user/team-dependent**.
- App shielding, authorization denial/revocation, and safe background release: **unverified**.
- ActivityKit, Dynamic Island and Lock Screen: **unverified**.
- Background audio termination at countdown end: **not guaranteed while the process is suspended**.
- Pixel-identical Living Day terrain and smooth map panning: **not complete**; the visual code is an approximation of the locked reference.
- Complete bidirectional Calendar sync and recurring-event semantics: **not complete**.
- Voice capture in noisy environments and date parsing: **requires iPhone tests**.
- Usability/accessibility and real-duration torture tests across power/network/timezone changes: **not complete**.

## P0 acceptance steps on real hardware

1. Full target compiles and launches with all 4 extensions embedded and signed.
2. Family Controls authorization grant/deny/revoke behaves honestly and never traps user.
3. 25-minute protected session shields the selected app, continues through background/lock, and releases after manual End / Emergency Exit.
4. 2-minute quick focus runs timer-only, never claims to shield and cannot leave a shield installed.
5. Force-quit Ignition during protected session and wait for deadline; verify first attempted app use releases any stale protection (test real device behavior, not merely timer UI).
6. Focus session start appears on Lock Screen / Dynamic Island; reopen via deep link; same session restored.
7. Timer elapsed while app backgrounded records an attempted session, opens Close on next launch and never auto-marks task as completed.
8. Calendar drag, event move, resize, import and voice-created task review update the Journey and reminders without duplication.
9. Audio pauses/stops correctly on manual exit and after time elapsed on return; document any background cutoff limitation.

**Do not describe this project as fully working, App-Store-ready, or physically verified before the above tests pass.**
