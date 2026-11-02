# Ignition: Living Day interaction repair (October 30, 2026)

This is a **targeted revision of the actual Xcode source**, not a redesign. It leaves the working focus session engine, Live Activities, Dynamic Island, Lock Screen and iOS widget extensions unchanged.

## Confirmed defects in the previous build

1. `LivingDay.swift` translated the task and session overlays but left `JourneyScenery` fixed. The marker positions were calculated from *relative time*, so the map illustration and the markers had incompatible coordinate systems.
2. The `Now` marker remained fixed even during a map exploration gesture and appeared detached from the terrain.
3. The sheet only recognized the **end** of a swipe. It jumped between collapsed/expanded heights rather than tracking the finger.
4. The Path title overlapped the permanent Ignition header.
5. A freshly started session dot could be hidden behind the Now label.
6. The prior implementation reloaded/checks the image asset during body updates; the new version uses the asset-catalog `Image` view.

## Source changes

### `Sources/App/LivingDay.swift`
- **One stable day coordinate system**: each event's Y coordinate is determined by its actual timestamp and the current day's start and duration, including daylight-saving changes.
- **One camera translation**: image, session footprints, task markers and the Now label all reside in one translated landscape group.
- **Follow-Now camera**, inertial manual panning, bounded scroll, and a fixed **Back to Now** control that returns to the actual moment.
- **Visible session footprints**: the time is marked by a small connected dot next to the path, preventing the new dot from being buried under the Now label.
- Precomputed day boundaries and single asset-catalog image instead of repeated image lookup on drag updates.

### `Sources/App/NowView.swift`
- Interactive sheet drag implemented with `@GestureState`, actual intermediate heights, and spring snapping to **compact / medium / expanded**.
- In compact mode, drag on the whole sheet. When expanded, drag on the handle so task-list scrolling remains usable.
- The Path view heading has more spacing under the fixed header.

## Important limitation: approved scene artwork

`JourneyScenery.png` is an imperfect, single flattened extraction from the approved mockup. This patch **does not pretend** to restore missing image detail, create parallax layers, or create a real terrain renderer. It makes the **existing image move as one surface with its dots**, which is the functional issue reported. A genuinely premium layered illustration will require clean source artwork, not more SwiftUI gesture adjustments.

## Safest installation: patch your working Xcode project

**Do not replace your signed working project.** Keep the Xcode project on your Mac that already displays the working Live Activity. Back up that folder first. Replace only these two files (using the same paths):

- `Sources/App/LivingDay.swift`
- `Sources/App/NowView.swift`

Restart Xcode if it has cached the files, run Product → Clean Build Folder, then run **Ignition-Preview** on the same iPhone. None of your signing or widget targets needs to change for this patch.

The full direct-open Xcode project is also included for reference, but replacing the two source files in your currently signed project minimizes risk.

## Mandatory physical-iPhone acceptance tests

1. **Map:** Drag the landscape upward and downward. The picture, task stops, session dots and Now label must move at exactly the same speed; no markers should slide separately.
2. **Camera:** While exploring, Back to Now appears away from the header. Tapping it recenters smoothly. It must not change the real clock or session state.
3. **Sheet:** Start with the compact sheet, slowly swipe upward on its body. It must follow your finger without jumping. Let go near the middle; it should snap there. Drag the handle higher for full height. Pull down to collapse.
4. **Scroll:** At full sheet height, scroll the task list. The task list should scroll independently instead of moving the background or closing the sheet.
5. **Task dot:** Add a task in Plan for today and switch to Now. Drag the map until its label is visible. Tap it; the selected task should update without moving the landscape unexpectedly.
6. **Session footprint:** Start an unnamed quick focus; return to Now. A blue connected dot should appear at the actual start time. End without marking Finished; the dot should remain but not claim task completion.
7. **Widgets:** Start focus, lock iPhone and open Dynamic Island. Verify the same countdown still works; this patch deliberately does not touch Live Activity code.
8. **Cold restart:** Force quit Ignition, reopen and explore map/sheet. Verify no crash, missing scene, or incorrect session dot.
9. **Day change:** Test around midnight (or with simulator time controls) for correct date boundaries, including DST transitions.
10. **Performance:** In Xcode Instruments use Animation Hitches / Time Profiler while rapidly panning with 10+ tasks and 50+ historical sessions. Visual lag cannot be measured here.

## Verification performed outside Xcode

- Swift syntax parsing of all source files: **passed**.
- Foundation smoke test: **passed**.
- 28 deterministic session stress assertions: **passed**.
- Xcode project OpenStep syntax validation: **passed**.
- Source project references: no new sources or targets were added, so the existing Xcode project file is unchanged.

**Not verified:** iOS semantic compilation (requires Xcode), actual gestures/performance on a device, pixel-fidelity to the approved visual, and any Screen Time entitlement behaviors.
