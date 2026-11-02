# Ignition: scenery and map markers move together

**Source:** updated from the October 31 *Ignition_Plan_Refined_After_Recording* project. This is a targeted Now/Living Day fix, not a new app design.

## Root cause

The old `LivingDay.swift` projected event markers at the actual zoom scale (e.g. 88 points per hour) while `artwork()` moved the scene by just `drag * 0.10` plus a heavily clamped and reduced time delta. Marker x coordinates were also sampled from fixed *screen* y coordinates instead of the underlying scene. This created a static-looking landscape with detached moving pins.

## Source changes

- `Sources/App/JourneyMechanics.swift`: Adds Foundation-only `JourneyWorldGeometry` for time-based camera/scene phase, exact pan distance, bounded repeating tiles and texture-coordinate lookups.
- `Sources/App/LivingDay.swift`: Reuses the same camera translation for the scenery, focus footprints, events and Now marker. Marker x coordinates are attached to image-space positions, not screen-space positions. Three bounded visual tiles cover the viewport during exploration; there is no enormous offscreen scroll view. Zoom changes at Now preserve the scenery anchor. The previous 0.10x / 0.23x / 0.39x image movement and small clamps are removed.
- `Tests/JourneyWorldMotionTests.swift`: 40,748 deterministic checks covering pan/release continuity, 1:1 motion, texture-space marker anchoring, three zoom scales, day boundaries, and tile viewport coverage.

## What was deliberately left alone

Plan, Focus, the session engine, notifications, the Screen Time extensions, both Live Activity widgets, Xcode signing, and approved images. The two image assets from the earlier approved design are preserved; only the renderer changes.

## On-device acceptance tests (required)

1. Build **Ignition-Preview** on an iPhone. Open Now with one or two scheduled tasks visible. Drag the *map area* down about 100 points. The mountain/lake artwork, blue path and every task dot must move down **together**, without a dot skating across the artwork.
2. Release the drag slowly, then quickly. There should be no jump back to a different map position.
3. Drag upward; repeat after switching between Near, Hours and Day. Returning to Now should show its centered marker and the same scenery anchor for that time.
4. Open the Today drawer, drag it up and down, and check that it doesn't accidentally drag the scene underneath. Test with an empty schedule and around midnight.
5. Start a focus session, confirm a session footprint appears, and verify the already-working Lock Screen and Dynamic Island countdowns remain intact.

## What this does NOT solve

The approved master scenery PNG is a flattened, partially blurry illustration. This fix makes the actual **picture** scroll, but it uses a repeated bounded texture to cover long excursions. Very long exploration can reveal repeated scenery / seams. Truly seamless, sharp 2.5D terrain requires a newly prepared continuous world asset with independently exported foreground/background layers. No iOS runtime or physical-device rendering was available in this environment; do not treat source tests as device proof.
