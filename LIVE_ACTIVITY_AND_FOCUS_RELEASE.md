# Ignition — Focus / Live Activity interaction release

This version is an **in-place implementation** built from `Ignition_Plan_Interaction_Polish_Xcode_2026-10-30.zip`. It is NOT a new design for Now or Plan.

## Scope of this release (two subsystems, tested separately)

### 1) Lock Screen and Dynamic Island
- Both `IgnitionPreviewLive` and `IgnitionWidgets` render identical dark-blue/teal Live Activity components.
- Lock Screen: task title, system countdown, continuous progress, up to two tasks with genuine completion marks, and `completed/total` count. Without tasks, displays the saved next step when available.
- Expanded Island: current focus, countdown, progress, genuine task count/checklist, tap to return.
- Compact Island: restrained focus icon + countdown.
- ActivityKit uses an immutable focus deadline per running segment, avoiding unnecessary update churn. Paused time is frozen.
- Completing an assigned task updates the Live Activity immediately. It **does not** end the timer or mark other tasks complete.
- Added backward-compatible decoding for older activities with only four state fields.
- The system chooses Live Activity presentation. The app cannot force a custom-expanded Island to remain open, or visually restyle ordinary iOS notification banners beyond Apple's supported APIs.

### 2) Focus / LOCK IN responsiveness
- Starting a session now reveals Focus as soon as the session is safely committed, before the slower protection and sync reconciliation.
- The LOCK IN button has a pressed state, tap haptic, and a `Starting Focus…` busy state to prevent duplicate starts.
- Pause, Break, Resume and End have visible touch feedback and pending states; duplicate taps are blocked during pending action.
- Pause and Break publish the updated session state as soon as the engine confirms the transition.
- Retains the approved night scene, focus controls, true protection status, music and safe exit.

## Real iPhone acceptance checks — these CANNOT be verified on Linux

1. **Preview signing**: choose `Ignition-Preview`, with `IgnitionPreview` and `IgnitionPreviewLive` signed to your Personal Team. Clean build and run. Do not use `Ignition-Full` without paid Family Controls entitlement.
2. **3-task block**: make a block with 3 tasks. Start it. The Lock Screen card should show `0/3`, the title, a progressing timer and up to two tasks. Long title and small iPhone should not clip.
3. **Checklist updates**: check a task in Focus. Lock the screen; its count must show `1/3` and a checkmark for that task. All other tasks remain unchecked.
4. **Island layouts**: look at compact Island, then long-press; countdown and task summary should show. Tap to return to the running Focus view.
5. **Pause**: tap once. The icon/state should change promptly, the remaining time should remain frozen on Island/Lock Screen. Tap Resume once and confirm the countdown moves again.
6. **Rapid tapping**: tap Pause 10x rapidly; the app must not oscillate between states or duplicate a session. Press LOCK IN repeatedly; there should be one active session only.
7. **Break/End**: Break pauses focus seconds; End removes the activity and releases authorized protection. Follow up with a new focus without old information lingering.
8. **Background restart**: switch apps, lock/unlock, and force-quit/reopen Ignition; clock, task count, and state must reconcile with persisted session.
9. **No permissions**: timer-only and disabled Live Activity settings must not crash.
10. **Source asset**: Now landscape and Plan tabs should look exactly as they did before this interaction update.

## Verification limitations

- Swift parse, Foundation session and focus-block stress tests, viewport tests, Xcode reference validation, and Live Activity Codable compatibility tests run in this environment.
- **Full Xcode typecheck, UI preview rendering, haptic feel and physical iPhone checks were NOT possible here.** Do not claim this release is production-certified until these pass.
- iOS still controls Lock Screen/Island layout, rendering cadence, and permissions.

## Setup

Open `Ignition/Ignition.xcodeproj` after unzip. `Ignition-Preview` is the recommended scheme for testing Live Activities without Family Controls. Preview never shields distracting apps. The Full scheme needs the applicable Screen Time entitlement/signing.
