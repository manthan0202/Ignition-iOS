# IGNITION — SOURCE AUDIT & TEST RESULTS (2026-10-30)

**This is a corrected source-code handoff, NOT an Xcode-built or physical-device-verified app.**
The approved Living Day, Plan and nighttime Focus visual designs are unchanged. Do not redesign them while resolving defects.

## Confirmed defects corrected in source

| Severity | Issue in earlier source | Correction |
|---|---|---|
| P0 | Active countdown reached zero but no foreground driver reconciled the session | Foreground deadline task reconciles persisted session; state transition ends timer and triggers cleanup |
| P0 | Background expiration wasn't consistently surfaced as a session review on reopen | Relaunch/foreground refresh identifies unreviewed elapsed session, closes Focus, presents Close after full-screen dismissal |
| P0 | Paused session had no clear break protection expiry and could keep stale label | Break re-arms a separate five-minute release lease; refresh when break expires |
| P0 | Old Device Activity monitors could remain after a re-arm or app restart | Deactivation stops every Ignition-named monitored activity and clears only Ignition's named shield store |
| P0 | Protection could be claimed with broken App Group configuration | Shield activation fails open and reports unavailable if shared App Group container missing |
| P1 | Child `WorkRepository` publishing did not propagate through `AppModel` | Combine observation forwards changes to affected view subscribers |
| P1 | Concurrent startup refreshes could race Live Activity requests and duplicate their presentations | Coalesced serialized refreshes; removed redundant initializer refresh |
| P1 | Skipping Close was not persisted, enabling repeated/unacknowledged review | Atomic review acknowledgment persisted separately from outcome/next step |
| P1 | UI attempted Close sheet while full-screen Focus still presented | Close follows Focus dismissal through explicit callback |
| P1 | Starting paused session as 2-minute task could trigger competing Close flow | Atomic paused-to-short-session pathway preserves history without review overlay |
| P1 | Corrupted task JSON silently decoded as an empty list then could be overwritten | Damaged source preserved, recovery path used, error surfaced |
| P1 | Widget could continue showing an apparently active timer after deadline | Scheduled time-reached widget timeline entry; Live Activity stale deadline and stale text |
| P1 | Editing/dragging tasks didn't consistently reschedule/cancel notifications | Notifications adjusted for changes, completion, deletion, import, and Rescue preference |
| P1 | Rapid local calendar edits could initiate concurrent first-time Apple Calendar creates | Per-task serialized sync loop avoids racing new writes with missing external identifier |
| P1 | Voice engine could remove a nonexistent mic tap when startup failed | Track installed tap; handle unavailable recognizer gracefully |
| P2 | Rapid double tap LOCK IN could produce an avoidable duplicate-start error | Main-actor starting guard and actor-side one-session invariant |
| P2 | Planning drop positions rounded all tasks to whole hours | 15-minute drop increments |
| P2 | Some screens continued to offer LOCK IN while a session already existed | Show Return to Focus instead |
| P2 | Journey's Now clock only changed when another state update triggered a redraw | Minute-timeline-driven live time display |

## Verified here

- `swiftc -frontend -parse` passes for all Swift source files.
- Original pure-Foundation smoke test compiles and runs successfully.
- Expanded pure-Foundation stress suite compiles and passes **28 assertions**; includes exact expiration, duplicate event prevention, app-state restoration from JSON, explicit outcome vs attempted work, review persistence/Skip, Pause/Break/Resume, invalid transitions, emergency stop, damaged JSON preservation and 75 successive completed sessions.
- Project XML entitlements and generated source bundle can be inspected; no production Xcode build was performed.

## NOT verified here — REQUIRED before saying "working on iPhone"

1. **Full Xcode compile/build for app + four extensions**, provisioning profiles, Family Controls entitlements and correctly configured App Groups.
2. **Actual Screen Time shields** for selected apps/web domains and immediate release on Pause/End/Emergency; iOS decides when Device Activity callbacks run.
3. **Short-session shielding** (especially 2 minutes): a backdated >=15-minute monitoring interval remains experimental; failure must run timer-only, not risk a stuck shield.
4. **Shield handoff**: default `.close` is deliberately safe and truthfully labeled. `IGNITION_ENABLE_DIRECT_SHIELD_RETURN` may be enabled only after confirming the SDK contains `openParentalControlsApp` and a real-device test proves it navigates into Ignition.
5. **Dynamic Island and Lock Screen** on a compatible iPhone, including backgrounding, force-quit, reboot and delayed ActivityKit updates. `staleDate` is a *staleness indicator*, not a server notification or guaranteed automatic end.
6. **Calendar/EventKit** permission prompts, writeback, external recurring-event behavior, imports from other calendars, deleted external events, and drag/drop on-device.
7. **Voice/Speech and microphone** denial, interruptions and transcript/date parsing on-device.
8. **Music** background playback through device lock, phone call, AirPods and exact cessation on a deadline while the app is suspended. Exact audio cutoff when the process is suspended is not guaranteed by this implementation.
9. **A meaningful, persistent map-pan interaction**: the existing Living Day drag still springs back; it remains a visual implementation gap. The user-approved design must be preserved when completing it.
10. **Race conditions under real UI interaction**, especially multiple taps, permissions changed during a focus block, overlapping external calendar edits and edits while reminders fire.
11. **Notification authorization and delivery** under Focus modes, low power, and app-termination conditions.
12. **Accessibility**: VoiceOver, contrast, larger text, reduced motion, touch targets, keyboard, and smaller iPhones.

**Decision:** This archive is a stronger engineering baseline; not a production-ready IPA, not App-Store-ready, and not a substitute for a real Mac/iPhone QA pass. Do not describe the native integrations as verified.

## Suggested physical-device acceptance tests (execute and record Pass/Fail + iOS version)

- Timer-only 25 min (no Family Controls): Start > background > lock > unlock > app reopen > 0 > Close > Skip. The attempt dot must remain; no task completion inferred.
- Timer-only 2 min: repeat with foreground and forced app kill; verify Close on next launch and no duplicate footprint.
- Authorized 25 min: tap LOCK IN; open chosen distracting app; verify real shield; Pause and verify release; Resume and verify shield reapplied; End and verify release.
- Authorized 2 min: confirm shield releases after 2 minutes *even with Ignition terminated*; if this cannot be shown reliably, disable short-session shielding rather than trapping users.
- Break at minute 9: verify active time freezes, protected 5 min break, subsequent shield release, app state reflects release and Resume reapplies for remaining active time.
- Dynamic Island & Lock Screen: verified task/title/timer during active, paused, break, and expired; tap deep link, same session not duplicate.
- Device restart and permission revocation while a session is protected: recover safely, no stuck shielding.
- Create/edit/drag/delete tasks: local item, 15-minute calendar placement, imported Apple Calendar event, rescheduled reminders and external writeback; no duplicate events on double Save.
- Dictate an event and deny permission in a second run: editable transcript preview; never silently create the wrong event.
- Original piano and noise: lock the phone, complete timer, test interruption and music stop policy.

## How to run checks locally

```bash
./Scripts/check.sh
```

On a Mac with Xcode:

```bash
brew install xcodegen
xcodegen generate
open Ignition.xcodeproj
```

First change bundle identifiers, App Group, signing and Family Controls entitlement settings. See `README.md` and `QA_CHECKLIST.md`.
