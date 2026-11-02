# Ignition — Living Day map layout/motion repair

The **approved Now/Plan/Focus visual system is unchanged**. This is a targeted repair to `Sources/App/LivingDay.swift`.

## What was actually wrong

1. The old map represented a whole 24-hour day in ~526 points of vertical travel — just ~22pt per hour. Events 30 minutes apart were 11pt apart, so 45pt cards overlapped.
2. Task and block pins could represent the same work item twice.
3. Each event label was placed by alternating left/right without checking where the artwork's river actually ran, so markers could disappear under cards.
4. Session footprints had long horizontal white connectors that created visual glitches when multiple sessions were close.
5. Previously the map panning code used a predicted drag position that could overshoot and snap back.
6. Background and event placement could drift because some coordinates were based on a changing `now` instead of a stable origin.

## Implemented source changes

- The living map is a **local time window**, with a fixed scene origin. Plan remains the exact full-day calendar.
- A 30-minute separation is now 53pt instead of ~11pt; labels on the same side are packed at >=60pt spacing.
- Label side is chosen opposite the estimated river side and uses a fixed width to reduce collisions.
- The image, timestamp markers, session footprints, and Now all share **one camera offset**.
- Session dots use small circles with no misleading completion or connector lines.
- Assigned tasks are not repeated separately from their focus blocks on the same day.
- Camera drags use the actual drag distance, avoiding predicted overshoot.
- Significant system time changes reanchor the visual world.

## What is NOT fixed by this file

The `JourneyScenery.png` asset was reconstructed from a flattened mockup and already contains large blurred/inpainted patches. **The artwork cannot be made truly sharp by a gesture or layout change.** The replacement map does **not** silently swap in unapproved art. A clean, high-resolution standalone illustration or a layered original asset is still needed for true visual fidelity.

## Run

Open `Ignition.xcodeproj`, select the Preview scheme whose Live Activity already works on your phone, and build. If your signing is already working, the safest installation is to copy only `Sources/App/LivingDay.swift` into your existing project.

## Tests

- `bash Scripts/check.sh`
- `bash Scripts/check_focus_blocks.sh`
- `bash Scripts/check_block_sessions.sh`
- `python Scripts/check_home_patch.py`

These run source-level and Foundation model tests. They **do not** build the iOS UI or certify gesture smoothness. Physically test: two stops 30 minutes apart, a session footprint, drag and release, Back to Now, pan while the clock advances, choose a block, focus and return, and widget continuity.
