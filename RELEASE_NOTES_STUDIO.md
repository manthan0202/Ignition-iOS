# Ignition — Studio Interaction & Visual Quality Pass

## Source of truth

This project is based on the last working **Ignition Focus + Live Activity Polish** archive and includes both Xcode schemes. The locked 2.5D sunrise Journey / Now map, the Plan calendar + task drawer, and the nighttime Focus design remain the product references. This release **does not** claim pixel-perfect conversion of those mockups. The existing landscape asset is still a flattened reconstruction with blurry regions.

## Changes implemented in source

1. **Shared presentation tokens** (`IgnitionApp.swift`): Ink, Action, muted text, off-white canvas, surfaces, accent teal, typography sizes, corner radii, motion curves, tap feedback and optional haptic preference. No proprietary fonts are included.
2. **Touch response**: primary start buttons get a larger tap area and pressed feedback; Plan drag pickup, quarter-hour snapping, commit and tab selection use a centralized, preference-respecting haptic language.
3. **Now**: the white task drawer uses continuous crossfade between compact focus controls and the expanded list while tracking a drag; detents use the common spring, and the design respects Reduce Motion. Task labels are larger, header spacing is preserved, and the 2-tab layout remains unchanged.
4. **Living Day**: larger readable event bubbles, calmer material cards, subtle selection feedback, legible Now marker, zoom and Back to Now haptics, and reduced-motion support. Existing time mapping/clustering and selected 2.5D art retained.
5. **Plan**: smaller, coordinated typography, warm blue-gray canvas, white task cards with restrained color and shadows, aligned calendar surfaces, tighter drag/touch feedback. Block data model, move/resize, task assignment and data persistence preserved.
6. **Focus**: original starry night remains. Title and next action moved into a stronger hierarchy, subtle moon/horizon glow, tighter translucent timer/control panel, larger useful body text, central haptic handling and responsive button states. Emergency exit and truthful protection indicators preserved.
7. **Live Activity**: unchanged timer/state synchronization; improved color consistency and a task-completion ring on the Lock Screen card. The ring represents **completed tasks**, not misleading elapsed-time completion. Preview and Full widget renderers remain identical.
8. **Settings & alerts**: real Touch feedback switch; less clinical settings background; more concise nonjudgmental focus notifications.
9. **App icon**: original dark-terrain/winding-path icon at 1024×1024, compiled for Preview and Full (replacing generic placeholder), not a copy of competitor artwork.

## Explicit limitations

- **Not an Apple-device-certified build.** Swift parser, Xcode project structure and Foundation tests run on Linux. These do **not** type-check SwiftUI against Apple's frameworks or exercise animations on an iPhone.
- **The approved scenery still needs native, source-layer art** for truly premium animated 2.5D terrain. Blurry inpainted regions cannot be repaired by animation code.
- **Screen Time protection** in Full requires the Apple Family Controls development entitlement and valid signing. Preview remains timer-only by design.
- **Google direct integration** requires real OAuth credentials and live-account tests; iOS cannot promise minute-by-minute background refresh.
- **Haptics cannot be observed from screen recordings.** Tune vibration intensity on a physical iPhone, and ensure the Touch feedback setting works.
- **No change to session persistence, calendar provider logic, voice completion, or Screen Time API logic** was made in this visual pass; these deserve separate end-to-end device verification before release.

## Acceptance test on iPhone

1. Start with 0 tasks. The Journey and Now marker are visible immediately, and LOCK IN starts an unnamed timer.
2. On Now, drag the bottom grabber in one smooth sweep. Text and task list fade between states; scrolling tasks doesn't move the map. Double-check when releasing at each detent.
3. On Now, pan/zoom map and select an event cluster. Tap Back to Now. Repeat with Reduce Motion enabled; no runaway spring or camera reset.
4. In Plan, capture a task, hold to lift it, drop into a calendar time, drag the block, resize by 15 minutes. Haptics tick only when crossing new slots.
5. Start Focus from Plan. Next action is readable; Pause/Resume are responsive; holding the phone screen off doesn't reset countdown.
6. With haptics turned off in Settings, repeat task drag, tab switch and Lock In: there should be no Ignition-generated vibration.
7. Lock phone and expand Dynamic Island. Task completion updates actual 0/3 → 1/3, and timer stays synchronized across Pause/Resume.
8. End focus and check that Close asks for an unselected outcome. End/Skip does not mark tasks complete.
9. Force quit and relaunch, run with poor network, large text, accessibility contrast and denied notification/Screen Time permissions.
10. Compare screenshots on the physical device against `DesignReference/APPROVED_NOW_REFERENCE_OCT30.png`; open visual gaps are bugs, not automatic design changes.
