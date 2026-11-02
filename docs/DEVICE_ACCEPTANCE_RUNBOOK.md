# Device acceptance runbook

Nothing in `AUDIT_2026-10-31.md` is proven until it passes here on a real iPhone. For each test record **Pass / Fail / Partial**
plus what you saw. Send the table back; do not summarise. Use **Ignition-Preview** for B–D and G–J. **Ignition-Full** (paid team,
Family Controls on every signed target) is only needed for E.

Settings → "Live Activity" shows the app's own status text (`Running · <id>` or the failure reason). Screenshot it on any failure.

## A. Build
1. Replace `com.example.ignition*` and the App Group everywhere (3 places in project settings, 5 `.entitlements`, `SharedConfiguration.swift`).
2. Clean Build Folder → build **Ignition-Preview** to your iPhone. Send the first 5 compiler errors if any (the patch is uncompiled).

## B. Timer and footprints
| # | Steps | Expected |
|---|---|---|
| B1 | Start a 2-min session. At 0:30 force-quit. Reopen at ~1:30 | Focus shows ≈0:30 left, not 2:00 |
| B2 | Start 2 min, force-quit, reopen after 3 min | Close sheet appears **once**; swiping can't dismiss it; Skip then relaunch → not shown again |
| B3 | Start 2 min, stay in Focus until 0:00 | Within ~1 s Focus closes and Close sheet appears (no stuck 00:00) |
| B4 | Tap Lock-in rapidly 5× | exactly one session and one Live Activity |
| B5 | Choose "Finished" on a task session | task checked; a block session does **not** check its tasks |

## C. Footprint dot (known defect §3.1)
Lock in, End after 2 min, go to Now. **Record whether a dot is visible near the Now marker and after how many minutes it appears.**
Expected from the code: not visible until about 11–17 min (zoom Near/Hours). Also record colors seen for finished / ended-early / paused.

## D. Live Activity
| # | Steps | Expected |
|---|---|---|
| D1 | Start 25 min, lock phone | Lock Screen card ticking, within 1 s of Focus; Dynamic Island compact timer on supported models |
| D2 | Leave 60 s locked | still ticking, no frozen digits |
| D3 | Pause in app | Lock Screen freezes at the paused time; resume continues |
| D4 | Let a 2-min session expire while locked | card reads "Time reached", 00:00; tap → opens Ignition, Close sheet |
| D5 | End from app | card disappears within a few seconds |
| D6 | Kill app mid-session, relaunch | exactly **one** activity, no duplicates |
| D7 | Tap the card / island | opens the running session |

## E. Screen Time shields (Full, paid team)
| # | Steps | Expected |
|---|---|---|
| E1 | Authorize, pick one app, start **25 min** | that app shows the shield; header says "Protection applied" |
| E2 | Start **2 min** | header says timer only (Under 16 min); app **not** shielded |
| E3 | Pause | shield gone. Resume with > 16 min left → shield back; with < 16 min left → timer only |
| E4 | **Break** (patched behaviour) | shield stays. If you want it dropped during breaks, tell me |
| E5 | End / Emergency exit | shield gone immediately |
| E6 | Force-quit mid-session, wait for expiry | **record how many minutes after expiry the app unlocks**; if it never does, Settings → Release Ignition shields now must clear it |
| E7 | Settings → Release Ignition shields now | shield gone |

## G. Plan
| # | Steps | Expected |
|---|---|---|
| G1 | Add a task, drag to a time | lands on the 15-min slot under your finger |
| G2 | Drag a focus block by its title strip | moves in 15-min steps with haptics |
| G3 | **Scroll the calendar with a swipe that starts on a block title** | record whether the block moves (suspected defect §3.2) |
| G4 | Long-press an editable event | record: lifts to drag, shows context menu, or both |
| G5 | Resize a block; drag the divider | 15-min steps / snaps without fighting list scroll |
| G6 | Look for Undo after any move | expected: none (absent) |

## H. Voice
| # | Steps | Expected |
|---|---|---|
| H1 | Say "Study cardiology tomorrow at seven for one hour", tap Done | draft: title "Study cardiology", tomorrow **7:00 AM** pre-filled, 60 min, orange AM/PM warning, nothing saved yet |
| H2 | Same with "seven PM" | 7:00 PM, no warning |
| H3 | Dictate twice in a row | second recording appends; first text not erased |
| H4 | Music playing, then dictate | music pauses, then resumes after |
| H5 | Airplane mode | still transcribes (on-device) or shows a clear message |
| H6 | Confirm | saved once; Close sheet mid-draft → text is **lost** (known gap) |

## I. Notifications
1. Fresh install → first Lock-in shows the permission prompt. 2. Background the app, let a 2-min session end → banner "Focus block finished". 3. Tap it → review appears.

## J. Music
Start music, lock phone → keeps playing. Trigger Siri / a call → pauses, resumes after. Unplug headphones → pauses.

## Return this
Build errors (if any) · every row above as Pass/Fail/Partial with notes · E6 minutes-late number · Settings Live Activity status text on any D failure.
