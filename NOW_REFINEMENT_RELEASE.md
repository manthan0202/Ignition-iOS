# Ignition — Now screen refinement (31 Oct 2026)

## Scope
**Only Now.** `PlanView`, `FocusAndReturn`, the entire widget/Live Activity folder, Calendar services, audio, permissions, and task/session persistence were NOT changed.

## Design decisions
- Preserve the approved Living Day composition and the blue LOCK IN action.
- Small **Ignition.** wordmark. Remove the generic subtitle.
- Expand the **Today** title to a 31-point, tighter-tracked primary heading with quiet scheduled count.
- Use distinct type levels: 23-point selected focus, 15-point task titles, 11–13-point metadata, restrained 10.5-point section labels.
- Simpler row icons: tasks, fixed calendar events, and focus blocks no longer look like the same generic square.
- White/off-white card surfaces against the richly colored Journey. Navy for content, blue only for action and selection; purple for fixed events.
- Do not claim protection is on from matching words inside a status string. Use the actual enum.
- Avoid extra label noise; the expanded drawer does not repeat TODAY as a second section heading.

## Interaction/performance changes
- The previous drawer rebuilt its height and the ScrollView's geometry with every drag-frame update.
- The new drawer keeps ONE fixed content height and slides via `.offset(y:)`. The `NowTodayList` is a dedicated subview with fixed layout dimensions.
- The handle works as a button for accessibility and as the touch drag target; compact content can also be swiped upward.
- Three bounded detents, predictive travel clamped to avoid wild jumps, with one selection haptic per *actual* change of detent.
- Removed the redundant translucent midground scenery layer and native material blur behind each map label. Cached image lookup reduces repeated texture lookup.
- Foreground scenery now uses a gentler lower-only parallax mask; one preserved source image continues as the main scene.

## Known limitation: source image quality
The approved artwork was supplied as a flattened mockup and the current asset was reconstructed by removing overlaid UI. It contains missing information, resampling and blurry erased regions. **No color filter or SwiftUI animation can reconstruct absent scene detail**. This release improves compositing and contrast, but does not replace the damaged artwork with true multilayer high-resolution art. Rebuilding a clean master image is a separate asset-production task, not evidence that the app was redesigned.

## Physical iPhone acceptance tests (not run in this environment)
1. Open Now with no events: the Landscape and Now marker must appear.
2. In compact view, swipe the handle upward slowly: the sheet should follow the finger with no sudden task-list re-layout.
3. Swipe quickly upward and down: detents should settle predictably, without a rubber-band jump to the opposite end.
4. With 30+ tasks, expand/collapse 10 times and scroll the task list. Map panning must not take over.
5. Tap LOCK IN. Session starts exactly once. Confirm previously working Dynamic Island and Lock Screen.
6. Switch Path and Map; return to Now; check no overlap with the wordmark.
7. Check fixed-event purple calendar glyph, focus-block blue stack, task checkmark glyph.
8. Check VoiceOver and Dynamic Type; enlarge text and verify key actions remain reachable.
9. Use Instruments Core Animation to look for layout spikes or frame drops during the drawer drag.
10. Compare the actual screen with the approved image; decide separately whether to commission a clean sharp landscape master.

## Automated checks
- Swift source parses.
- 5,009 deterministic drawer geometry assertions pass.
- Session/FocusBlock/Journey/Voice/Calendar tests retained and passed locally.
- Xcode pbxproj structure and source memberships checked.
- **Not performed:** full Apple SDK compilation, simulator render, real-iPhone touch/haptic evaluation.
