# IGNITION — PLAN SCREEN / LOCKED REDESIGN SPECIFICATION

**Revision:** PLAN-R1 · October 31, 2026  
**Status:** Design and interaction decisions locked for implementation; not a claim that the Swift code has already been changed or tested on a device.  
**Scope:** **Plan tab only.** Preserve the approved Living Day/Now design, Focus night scene, session engine, Shield, Live Activities and existing task/calendar data.  
**References:** User-supplied Plan screenshot (clipped cards, three row action icons, duplicate “TASKS” labels, heavy header); user's Anchor demo (quality of task-to-calendar interactions); Finalist references (confident date typography and a restrained color hierarchy). **Borrow interaction principles, not proprietary assets or exact screens.**

## 0. The decision in one sentence

**Make Plan feel like one precise, tactile workspace: a spacious, light calendar above a contrasting, deeply organized task drawer, with one clear action visible at a time.**

The purpose of Plan is to let someone capture a task, assign it to a time or focus block, adjust the plan, and begin Focus without losing the task's identity. Design should reveal that workflow rather than expose every command in advance.

### Design invariants — do not negotiate away

1. Two top-level tabs remain **Now** and **Plan**. Do not add tabs.
2. The calendar, tasks, all-day events, focus blocks, Google/Apple calendar events, voice entry, multi-task blocks, drag/drop, move/resize, and tap-to-schedule **remain functional**.
3. Keep tasks distinct from scheduled work blocks: a task can belong to several blocks, and ending a focus timer must not auto-complete any task.
4. The existing working Live Activity and Dynamic Island implementation is out of scope and must not be refactored during this screen update.
5. The design is inspired by Anchor's *fluidity* and Finalist's *typographic restraint*. It must retain Ignition's own navy/blue identity.
6. No invisible or inaccessible feature loss in exchange for visual minimalism. Secondary actions move to context menus, sheets, swipe actions, or the Add menu.

---

## 1. Final information hierarchy and composition

### A. Above the calendar — ONE compact header

**Top row** (approx. 52 pt content height, within safe area):
- Left: **Plan** in large SF Pro semibold, 30 pt (up to 32 pt according to Dynamic Type). No icon preceding the title.
- Right: **Add** (`plus`, 44×44 touch target), **More** (`ellipsis`, 44×44 touch target). No permanently visible mic, calendar-import icon, stack-block icon, and second plus.
- **Add menu:** New task; New event; New focus block; Add with voice. All four actions remain available, each with a textual label and a consistent SF Symbol.
- **More menu:** Connected calendars; Refresh; Calendar visibility; Day settings (and the app's broader Settings entry if previously exposed here). Refresh errors show state; no fake “synced” label.

**Date row** (approx. 40 pt):
- Left: **Sat, Oct 31** (20 pt semibold), with optional smaller *October 2026* only when its information is not already represented elsewhere. **Do not show both a giant date and a redundant long date in competing font sizes.**
- Right: chevrons to move one day at a time. Show a small **Today** pill **only when viewing a different day** (or as an unobtrusive action if testing finds it necessary).
- Use locale-aware date formatting and accessibility full-date labels.

**Week strip** (approx. 47–52 pt):
- Seven days, centered and evenly spaced.
- Each day shows weekday initial and date, with the selected day in a compact blue rounded pill (not a giant rectangular tile).
- Light haptic selection on a change. Never animate the entire screen for a date tap.
- Day strip follows the chosen week; no duplicate calendar headers.

**REMOVE** the permanent “Live timeline” label, the separate calendar import glyph, the second large “Tasks”/“TASKS” heading combination, and the instructional sentence “Pull down for more calendar.” A live-time line is self-explanatory; drag handles communicate movement.

### B. Calendar — the primary precise surface

- Surface: near-white calendar on a cool, slightly darker page canvas. Thin separators, no heavy rounded panels around the grid.
- Timeline axis: 56 pt gutter (minimum; scale for localized formats and text sizes), 11–12 pt tabular/monospaced digits, 1-hour labels, and subtle 30-minute rules. Quarter-hour snap locations remain functional without drawing 96 high-contrast lines.
- Default calendar occupies around **54–58%** of the *available Plan content area*, with task drawer occupying the rest. Actual heights adapt to device size.
- On today's date, first entry to Plan scrolls near current time, showing some context before and after. Don't forcibly recenter as the user scrolls or drags.
- Current-time indicator: one coral line with one compact **10:03** label (AM/PM in accessibility text), not “10:03 A” on one line and “M” on the next. A narrow time label must never wrap.
- All-day events occupy a compact lane above timed events. Show at most two chips and `+N` if needed; tapping shows a list.
- Focus blocks and ordinary calendar events use distinct, consistent visual treatments (section 3).
- Overlapping events can share lanes until legibility fails. If an individual lane is too narrow for a meaningful label, replace the tiny content with a clean color strip/compact `2 events` disclosure for that collision group; never render chopped words and repeated tiny icons.

### C. Task drawer — the secondary, always reachable surface

**Final design decision: use a deep slate/navy task drawer** to create controlled contrast with the light calendar. This is a **functional surface contrast**, not a copy of Anchor's black panels.

- Default background: deep slate #1B293D; rows: #24354B; text: #F8FAFE; secondary text: #A9B8CB; selected/filter accents: muted Ignition blue.
- Top edge has 20–24 pt continuous corners and one small centered grip. **No large extra bar labeled `TASKS`.** The drawer itself has one header: **Tasks** (22 pt semibold) and one **+** action (44×44 touch target).
- `+` opens Task / Voice quick capture. The same Add menu is reachable from the top header; this is intentional contextual redundancy, not four always-visible icons.
- Under the header, only two filters: **Inbox** (unscheduled actionable tasks) and **Today** (tasks linked to the selected date). Remove “Hold & drag” instruction after onboarding; preserve a one-time education hint for first use only.
- Each row: a 24–28 pt hollow completion circle; task title (16 pt medium/semibold); **one** status line if useful; optionally a small trailing chevron or no icon. No calendar-plus, stack-plus, and reorder lines side by side.
- Whole row is a tap target for task details, and native long-press pickup for dragging. Swipe actions/context menu reveal **Schedule**, **Add to block**, **Edit**, **Move**, **Delete** where allowed.
- Example subtitle: `Not scheduled` or `Today · 2:30 PM`. Don't show “in 7 blocks” on the main row; show block memberships in task details.
- Reorder controls appear only in an explicit Reorder mode, if the underlying repository supports persisted ordering; otherwise don't display a decorative grip.
- Empty state: **Nothing in Inbox** / **Add a task or speak one.** Exactly one primary add action, no confetti/streaks.

### D. The divider between calendar and tasks

- One **44-point-high interactive grab region**, with a small visible 36×5 pt grip; the visible line is not the full hit target.
- Drawer follows the finger in real time. Detents as target fractions of available height: calendar **0.32 / 0.56 / 0.79** (initial target; adjust for safe areas and minimum task height).
- The calendar and drawer must not compete for the same drag: **only drags beginning on the grip region change the split**, task rows scroll or pick up tasks; calendar drags scroll or move an item.
- During a drag, avoid expensive re-layout of every calendar cell/task row. Keep heavyweight children stable and use a composited translation/clip or cached geometry where practical.
- On release, settle with one spring and one detent haptic; no repeated haptics while a finger moves within a detent.
- Header and bottom navigation remain pinned; the calendar and task list scroll independently.

---

## 2. Typography and geometry: single source of truth

Use the **system SF Pro text family** for readable native UI, with `.monospacedDigit()` for times and durations. The current Ignition wordmark remains its own brand treatment on **Now**, not added to Plan. No new proprietary font is required. Support Dynamic Type using styles/relative scaling rather than treating pt sizes as immutable.

| Role | Nominal size / weight | Rule |
|---|---|---|
| Main `Plan` title | 30 pt / semibold | One per screen; no leading calendar glyph |
| Selected date | 20 pt / semibold | Main navigational context |
| Drawer `Tasks` title | 22 pt / semibold | Only one drawer heading |
| Weekday initial / metadata | 11–12 pt / medium | Never the same weight as a task title |
| Week date | 14–15 pt / semibold | In compact selected pill |
| Event or focus-block title | 13–14 pt / semibold | Adaptive by width/height |
| Task row title | 16 pt / medium or semibold | Two lines max in drawer at default size |
| Task row subtitle | 12–13 pt / regular | Low-contrast but accessible |
| Calendar time gutter | 11 pt / medium, tabular digits | Single line, no clipped AM/PM |
| Primary menu/confirmation action | 15–16 pt / semibold | Clear labels, 44+ pt touch target |

**Spacing:** horizontal margins 16–18 pt; 8 pt between micro-elements; 12–14 pt between rows; 18–24 pt between major sections. Standard corner radii: 12 for event cards, 16 for task rows, 22 for drawer. Avoid giving every control an independently oversized pill.

### Color semantics — actual meaning, not decoration

| Token | Proposed hex | Use |
|---|---|---|
| `plan.canvas` | `#F3F5F8` | Page behind calendar |
| `plan.surface` | `#FBFCFE` | Timeline field |
| `plan.ink` | `#172947` | Primary text on light |
| `plan.muted` | `#65758B` | Times and supporting metadata |
| `plan.divider` | `#E4E9F1` | Hairlines |
| `plan.action` | `#376BE6` | Today selection, focus/primary actions |
| `plan.drawer` | `#1B293D` | Task workspace |
| `plan.drawerRow` | `#24354B` | Task row |
| `plan.drawerText` | `#F8FAFE` | Primary text on drawer |
| `plan.drawerMuted` | `#A9B8CB` | Secondary drawer text |
| `plan.focusBlock` | `#DCE8FF` | Focus time reservation |
| `plan.focusEdge` | `#416BD4` | Focus block identity stripe |
| `plan.meeting` | `#E8F4EC` | External or fixed event fill |
| `plan.personal` | `#F8EEDB` | Personal event fill |
| `plan.otherEvent` | `#F0E9FB` | Other event fill |
| `plan.now` | `#E45864` | Current time, not arbitrary urgency |

These are initial locked **semantic roles**; ensure contrast against actual backgrounds meets accessibility. Theme colors must not convey required meaning without text/shape. Calendar provider identity (Apple vs Google) can appear as **one small source label in details**, not as more icons on the timeline.

---

## 3. Adaptive event and focus-block cards — no more clipped nonsense

**Must adapt to BOTH available height and lane width.** One component should not show three text rows inside a 35-pt-tall or 90-pt-wide block.

| Effective card size | Visible content |
|---|---|
| Height < 32 pt or width < 82 pt | Small colored bar, optional single abbreviated title; full detail on tap/VoiceOver |
| Height 32–55 pt | **One-line title only** with stable inset |
| Height 56–95 pt and width ≥ 110 pt | Title + compact start/time or duration |
| Height 96–145 pt and width ≥ 140 pt | Title + time range + task count (blocks only) |
| Height ≥ 146 pt and width ≥ 160 pt | Above + first task preview if space permits |

- Use title `lineLimit(1)` only when genuinely necessary. Avoid `minimumScaleFactor` that shrinks text to illegibility.
- If a long title won't fit, render a readable one-line truncation and let a **tap expand into a detail sheet**. Don't place a half-cut time alongside it.
- Fixed imported events: fill with muted category color, minimal event glyph only if width permits. No resize handle if not writable.
- Focus blocks: slight filled accent, small 3–4 pt edge stripe. Block title is primary. The resize grabber appears only during selection, long-press, or when there is sufficient space; **do not show bright blue resize pills permanently on every block**.
- Selected/moving item lifts subtly; otherwise shadows are nearly invisible. Focus blocks shouldn't resemble a giant button.
- Overlapping blocks: maintain chronological alignment and correct event identity. Collapse dense piles to a disclosure rather than making every lane less than 82 pt wide.
- Calendar “Now” line crosses behind cards safely; current time label is topmost and never squeezed to a multiline bubble.

---

## 4. Interaction contract / motion / haptics

The objective is **physical continuity**, not gratuitous animation. Animations must never delay data persistence or timer start. `Reduce Motion` disables spatial motion while preserving state feedback.

| Interaction | Real-time feedback | On release / commit |
|---|---|---|
| Task long-press pickup | Elevate/scale ~1.02 and add gentle shadow; light haptic once | Task stays attached to finger |
| Task moving over timeline | Highlight the exact destination slot; show `10:15 AM` preview | No repeated buzz every frame |
| Cross a new 15-minute slot | Update time indicator; at most one selection tick per *new* slot | Maintain drag without scrolling glitches |
| Drop onto empty time | Create one focus block with that task ID | Single success tick; card settles into slot |
| Drop onto existing focus block | Assign same task ID, do not duplicate task | Block count updates; one success tick |
| Invalid drop | Visual return to origin | No data mutation; subtle error feedback only if useful |
| Move block | Item follows the finger using a transient overlay; calendar may edge-scroll | 15-min snapped new start; persist once |
| Resize block | Live end time and duration preview; minimum valid duration | 15-min snapped duration; persist once |
| Pull drawer grip | One surface follows finger continuously | Settle to nearest detent; one gentle haptic |
| Complete task | Circle fills and row state updates immediately | Persistence; short success feedback |
| Select date | Highlight moves quickly | Calendar scroll updates without losing task drawer scroll unnecessarily |

**Target feel (tune on iPhone):** tap feedback within one frame; simple fades ~120–170 ms; move/drop settling ~220–320 ms with damped spring. Avoid nested springs, excessive bounce, constant blur changes, and haptic bursts.

**Gesture arbitration (non-negotiable):**
1. Drawer drag starts **on its handle**, not from any task row or calendar card.
2. Task scrolling is allowed everywhere else in the drawer.
3. Long-press of a task starts the drag; short tap opens details.
4. Calendar empty-space drag scrolls; a selected block's move handle moves it; its bottom edge resizes it.
5. Drop-zone geometry is resolved in the timeline's coordinate space; scrolling doesn't shift time mappings under the finger.
6. The map/Now, Focus and Live Activity behavior is unaffected by this work.

Accessible equivalent: tap a task → **Schedule** → choose start and block. For block resize: edit duration in its detail sheet. VoiceOver must never require drag/drop to schedule.

---

## 5. User-facing strings to KEEP / REMOVE

| Current wording/control | Replace with / action |
|---|---|
| Redundant `TASKS` plus `Tasks` | One **Tasks** heading |
| `Live timeline` above red dot | Remove; preserve current-time rule |
| `Pull down for more calendar` | Remove persistent instruction; visible grip and one-time education |
| `Hold & drag` in drawer header | Remove after onboarding |
| `To schedule` / `On this day` | **Inbox** / **Today** |
| Three right-side row glyphs | No more than one; use context menu for secondary actions |
| Giant selected day + multiple date headers | One date row + compact week strip |
| `Unscheduled · in 7 blocks` | `Not scheduled`; block memberships in detail screen |
| `Focus blo…` in tiny event | Adaptive title-only small card; full name in detail |
| Mic + new block + calendar + add in header | One **Add** menu plus **More** |

### Header menu behavior

**Add** actions: `Task`, `Calendar event`, `Focus block`, `Speak to add`. The task drawer's + opens the same actions with Task first. **More** actions: `Calendars`, `Refresh`, `View settings`, `Settings`. No feature removed, only relocated.

### Sync / permission states

- Sync shouldn't crowd Plan's main header. Show a minimal warning dot on More when attention is required; a readable Sync screen exposes pending/success/failure/conflict per provider.
- Never show “Synced” unless the last pull/write has actually succeeded.
- Google/Apple calendar identity remains preserved when dragging/resizing; read-only events don't pretend to be movable.
- Failed provider writes must remain queued and visible; moving UI controls cannot silently alter external events without honoring the existing sync safeguards.

---

## 6. Architecture and implementation map for CURRENT code

**Audited source**: `Ignition_Studio_Design_Interaction_Xcode_2026-10-31.zip`, path `Ignition/Sources/App/PlanView.swift` (~1,522 lines). The target file is doing too much. The change should **not** be a one-off patch of font sizes; separate concerns and reuse existing repository/session logic.

| Current code | Work required |
|---|---|
| `PlanView.body` | Replace stacked toolbar/layout with Plan shell; preserve existing navigation and sheets |
| `dateHeader`, `weekPicker` | Combine into one compact date hierarchy, Dynamic Type safe |
| `calendarSurface`, `calendarGrid` | Simplify rules/header, preserve actual timestamp geometry; improve 96-slot drop targeting and current-time label |
| `focusBlockLayer`, `FocusBlockCalendarCard` | Adaptive content layout, selection-only handles, small overlap fallback |
| `eventCard` | Same adaptive density; fixed-event restrictions |
| `resizeHandle` | True 44 pt accessible grip, detents; no duplicate instructional labels |
| `taskDrawer`, `taskFilter`, `taskRow` | Unified dark drawer, single contextual action, strong type hierarchy |
| `showVoice`, `showNew`, `editingBlock`, `assigningTask` | Retain behaviors, route to Add/context menu rather than permanent icon sprawl |
| `PlanOverlapLayout` | Preserve overlap correctness, add minimum-readable-width fallback |
| `PlanMotion` / `PlanFeedback` | Route through existing shared `IgnitionMotion` and `IgnitionFeedback`, not new duplicate systems |
| `model.refreshCalendars()` | Preserve permission handling, foreground sync, conflict rules, and stable event IDs |

**Suggested extracted Swift components** (names may vary):
- `PlanScreen.swift`: shell and navigation state.
- `PlanHeader.swift`: compact title/date/week selector.
- `PlanTimeline.swift`: scrollable grid, current time, all-day lane, drop projection.
- `PlanCalendarItemView.swift`: adaptive event/block display.
- `PlanTaskDrawer.swift`: filters, task rows, grip and transitions.
- `PlanDragCoordinator.swift`: ephemeral drag state, hit testing, snapping, commit/cancel.
- `PlanDesignTokens.swift`: semantic colors/typography/geometry; reuse `IgnitionDesign` instead of creating incompatible global styles.

**Data must NOT be rewritten** to achieve the redesign. Continue using `AppModel`, `WorkRepository`, `WorkItem`, `FocusBlock`, `PlanOverlapLayout` or an equivalent tested replacement. Task completion always updates one underlying task ID, and a block association doesn't create another task.

### Performance rules

- No continuous heavy blur or multiple offscreen materials on scrolling lists.
- No full 24-hour grid recomputation for a simple drawer finger movement.
- Minimize observable invalidations by isolating drag state from repository mutations; commit at drop/end, not every finger delta.
- Use cached stable event geometry and overlay-based drag feedback.
- Avoid rebuilding task rows when only the clock updates. The current-time line can update independently.
- Test on a physical iPhone in Instruments for dropped frames and main-thread stalls; passing compilation tests is insufficient.

---

## 7. Edge cases and required behavior

1. **No tasks / no events:** Calendar remains clean, drawer shows one add prompt, no huge empty cards.
2. **10+ timed events and overlaps:** readable lanes or compact disclosure; no cut-off text or overlapping controls.
3. **Event near midnight:** correct day and placement; no negative heights.
4. **All-day imported event:** appears in its lane, not over the hourly grid.
5. **An external calendar is read-only:** edit/drag controls disabled, reason conveyed.
6. **An offline edit is pending:** local UI remains stable; retry/conflict state preserved.
7. **One task in multiple blocks:** task title and completion are consistent everywhere; no duplicated records.
8. **Zoomed Dynamic Type / VoiceOver / landscape iPhone:** text never collides with system status or bottom tab bar; accessible alternative to every drag.
9. **Reduce Motion / haptics off:** same functionality, less or no motion, no vibration.
10. **Heavy scroll while resizing:** gestures don't compete; no accidental block create/edit.
11. **App background/foreground during drag:** cancel transient gesture without committing an unintended movement.
12. **Short, 15-min block:** valid adaptive card with tappable detail; no oversized resize handle covering text.
13. **DST transition and unusual locale/12–24h time:** time labels do not wrap or map to incorrect wall times.
14. **Failed voice recognition:** typed fallback preserves the transcript and can still create a task.

---

## 8. Acceptance criteria (real iPhone required)

The Plan redesign is **not complete** until it passes all these tests on a physical iPhone, with screenshots/video from the actual running app:

- [ ] The top area shows **Plan**, one Add button, one More button, one date row, and a compact week strip. No duplicate headings.
- [ ] At the screen size in the supplied screenshot, `10:03 AM` does not split across lines; no label overlaps or clips.
- [ ] All-day, regular events, and focus blocks are visually distinguishable without three icons per item.
- [ ] Short and overlapping blocks use adaptive content; no “Focus blo…” cut-offs from overpacked card metadata.
- [ ] The light calendar and deep-slate task drawer look like one intentional design, not two unrelated screens.
- [ ] Drawer follows the finger without visible jumps; a swipe from the task list scrolls tasks rather than resizing the drawer.
- [ ] Task long-press creates one lifted preview; dropping onto an empty slot creates **exactly one** focus block with the original task ID.
- [ ] Dropping a task onto an existing block increases membership once; no duplicated task.
- [ ] Moving/resizing block snaps at 15-min intervals; task lists do not flicker or reset.
- [ ] Tap-to-schedule, accessible editing, and voice capture remain available despite hidden secondary icons.
- [ ] Today button/chevrons/day strip remain correct when switching dates.
- [ ] Imported Apple/Google events don't lose provider identity or bypass existing sync/conflict safeguards.
- [ ] View remains responsive with at least 30 sample events, 30 tasks, and overlapping blocks; inspect with Instruments and compare to baseline.
- [ ] At larger Dynamic Type and Reduce Motion, essential text/actions remain accessible and no control requires a gesture-only path.
- [ ] Now, Focus, Live Activity, and Lock Screen are regression-tested and unchanged.

### Required visual review deliverables before declaring completion

1. One screenshot of **Plan balanced state**, showing calendar and task drawer.
2. One screenshot of **calendar expanded**, showing overlapping events and current-time line.
3. One screenshot of **tasks expanded**, showing Inbox/Today and uncluttered rows.
4. One 15–30 sec **device recording**: task pickup → time hover → drop → resize → start Focus.
5. A short log distinguishing **compiled**, **tested on device**, and **not yet verified**. No “fully working” claim based only on Swift syntax parsing.

---

## 9. Explicitly out of scope for this pass

- Replacing the approved Now Journey scenery or rethinking its design.
- Redesigning the Focus night screen or changing timer/protection semantics.
- Rebuilding Live Activity / Dynamic Island code.
- Adding new accounts, AI assistance, game mechanics, or a third tab.
- Changing Google/Apple calendar provider semantics as part of a cosmetic refactor.
- Copying Anchor's exact copyrighted layouts, icons, font assets, or animation resources.

**End state:** A precise light timeline and a tactile dark-slate task workspace that feel like one app. One visible primary action at a time; power remains in context menus and detail views. All existing functionality preserved. The visual goal is premium, not maximal.
