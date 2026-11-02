# Engineering audit — last integrated pass

This report describes source changes and test evidence, **not a claim of a fully working production iPhone app**.

## Concrete changes in this revision

1. `JourneyMechanics.swift`: bounded clustering based on the *first* timestamp in a cluster, not a chain of successive short gaps; zoom-aware screen-space threshold. Clusters cannot silently span hours.
2. `LivingDay.swift`: camera holds an absolute explored position instead of drifting relative to the moving Now marker; rolling three-day coordinate envelope for midnight crossings; event positions use timestamps, cluster selection opens a native list; artwork now rendered at bounded viewport resolution with three mild depth planes rather than stretched to the entire timeline height.
3. `Assets.xcassets`: two aligned, masked parallax layers built from the **existing artwork**. Art identity preserved; flat source still limits achievable depth and detail.
4. `VoiceCapture.swift`: Done ends recording, waits for actual Speech final callback (bounded fallback), preserves transcript, and guarantees pending async continuation is released on cancellation/navigation.
5. `GoogleCalendarService.swift`: idempotent event creation via a deterministic Google-safe ID, ETag-protected updates and deletions, local-time all-day parsing; change cursor no longer commits ahead of durable local ingestion.
6. `CalendarService.swift`: EventKit event deletion to the correct existing event when writable; errors are surfaced instead of silently deleting local data.
7. `AppModel.swift`: deletion tombstones survive network failures, including a create-then-delete race; confirmed remote event ID is retained; Google cursor advances only if local snapshot write succeeded.
8. `Domain.swift`: local pending/failed/conflicted/deleting entries are protected from stale provider echoes; duplicate external-event UIDs are coalesced when possible; durable apply return value.
9. `PlanView.swift`: explicit calendar destination in editors and voice drafts; imported all-day items use their own lane instead of blocking the full hourly grid.
10. `SessionCore.swift`: nonthrowing fresh recovery constructor replaces forced `try!` when an old session file is unreadable. Original corrupted file is preserved.
11. `CalendarSyncRules.swift`: Foundation-only safety rules with a deterministic stress test; compiled in both app schemes.

## Tests actually executed here

- `plutil -lint Ignition.xcodeproj/project.pbxproj`: passed.
- Swift frontend syntax parse of all source files: passed (syntax **not** iOS typecheck).
- Foundation focus session smoke test: passed.
- Session stress checks covering expiry, background reload, pause, break, emergency, corrupt data: passed, 28 assertions.
- 109 focus-block model assertions: passed.
- Session-to-block persistence/backward compatibility: passed.
- Journey clustering/geometry with 4,000 dense events and anti-chain regression: passed.
- Voice draft parsing: 1,000 generated cases passed; recognition hardware callback **not simulated**.
- Calendar sync rules: 10,000 deterministic event IDs plus tombstone/cursor/all-day/DST rules passed.
- Xcode targets, compiled file membership, image asset catalog references: passed.
- Live Activity / widgets sources were **not modified** in this revision.

## Important non-certifications

No macOS Xcode SDK or iPhone simulator is available in this runtime. Therefore the following remain **unverified**, irrespective of source presence:

- Full Xcode compilation and SwiftUI type-checking of both schemes.
- Actual iPhone scene rendering, smooth pan/pinch, sheet gestures, event-drop/resize, battery use and memory use.
- Live Activity reinstallation / provisioning after changing targets.
- Family Controls authorization, exact short-session shield release and emergency unblocking.
- Google OAuth callback/account provisioning, actual create/update/delete, conflict/retry behavior on live accounts, recurring-instance behavior.
- EventKit account permissions and cross-device sync timing.
- Speech recognizer's final callback, audio interruptions, Bluetooth microphone and denial states.

**No verified claim of complete two-way recurring calendar synchronization, guaranteed 60-second background polling, or true geometric 3D rendering should be made.**
