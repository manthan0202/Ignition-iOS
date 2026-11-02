# IGNITION — LOCKED PRODUCT, DESIGN & ENGINEERING SPECIFICATION

**Revision:** 2.0 (supersedes conflicting earlier briefs)  
**Date:** October 30, 2026  
**Document status:** APPROVED PRODUCT CONTRACT; NOT A CLAIM OF COMPLETED IMPLEMENTATION  
**Audience:** Claude / Xcode developer / designer / QA  
**Visual reference:** `APPROVED_NOW_REFERENCE_OCT30.png` (the THIRD Ignition Journey concept selected by the user; this is the design target, NOT a production-ready layered scene).

> **One-sentence product:** See your day as a living landscape, organize it in a beautiful calendar, start focused work instantly, protect attention where Apple allows, and return to exactly where you left off.

## 0. THIS DOCUMENT IS THE SOURCE OF TRUTH

- Preserve the current approved visual direction. **Do not generate a replacement home design.** No more substitutions of generic mountains, blue squiggles, damaged cropped screenshot assets, or plain task lists for the Journey.
- The app has only **two top-level tabs: NOW and PLAN**. Focus, Break, Shield, Return, Close, capture, and settings are flows or overlays, not additional main tabs.
- The third Journey concept is the benchmark for the NOW composition: beautiful layered valley/river, curved luminous blue/purple time-path, distinct color-coded event bubbles, prominent **NOW** pin, translucent white action sheet, navy typography, blue LOCK IN button, and restrained bottom navigation.
- Use the original approved **starry nighttime Focus screen**. Preserve the existing working Lock Screen and Dynamic Island Live Activity behavior, then improve it only without regression.
- The Plan page is a **modern, warm, compact, interactive calendar + persistent task drawer** inspired by the *quality of Anchor's interaction*, not a copy of its artwork, trademark, or entire feature set.
- Product scope in Sections 1–9 is the approved target. Work can be released in vertical slices; a not-yet-implemented feature must be marked **not implemented**, not quietly discarded or represented by a fake UI.
- **Observed versus unverified:** The user demonstrated that Live Activities and Dynamic Island were appearing in the previous Preview build. That proves the particular earlier configuration worked at that time, not that a subsequent integrated build is regression-free. Google sync, realistic 2.5D movement, and refined voice finalize are not certified working yet.

## 1. FROZEN PRODUCT DECISIONS

| Decision | Final requirement |
|---|---|
| Home design | Third approved October 30 Journey image, adapted as live layered 2.5D, not a flat screenshot |
| Default viewpoint | Camera anchored to current time at approximately 62% of available map height, with **more future visible above** |
| Exploring time | Drag path to visit earlier/later events; pinch/controls for Near, Mid, Whole-day zoom; one-tap Back to Now |
| Dense event markers | Collision-aware clusters: `2` for two, `3+` for three or more; tap to reveal events |
| Main action | One blue `LOCK IN · [duration]` per current context; target is explicit; taskless Quick Focus works |
| Tabs | `Now` and `Plan` only |
| Plan layout | Compact header + independently scrolling timeline + draggable task drawer |
| Calendar behavior | Move, create, delete, resize and duplicate-safe editing; focus blocks can contain multiple tasks |
| Sync | Apple Calendar / Google Calendar, editable where permitted, two-way with truthful status; **no promise of guaranteed 60-second background sync** |
| Voice | Stop/Done **finalizes transcription** and creates an editable draft; does not erase spoken text |
| Focus | Original dark immersive view with countdown, music, honest protection, controls, persistence |
| Timer outside app | Lock Screen and Dynamic Island when supported, same canonical timer |
| Session history | Timestamped footprints: starting or attempting is not the same as finishing |
| Differentiation claim | Beautiful integrated workflow and demonstrated reliability, not novel ownership of tasks + blocking |

## 2. NOW: LIVING DAY — EXACT INTERACTION CONTRACT

### 2.1 Visual layers (build these, do not just crop a screenshot)

1. **Far background:** sky, distant mountains, sunlight, atmospheric gradient. Parallax response modest.
2. **Middle environment:** hills, trees, lakes, river valley and shadows.
3. **Interactive route layer:** curved luminous blue/purple winding path, clear foreground-to-distance perspective and depth cues.
4. **World objects:** time-anchored event markers, focus-block landmarks, completed/attempted session footprints.
5. **HUD:** logo, Map/Path control, settings, Back to Now button when browsing, and floating task sheet. HUD does not move with world.

The approved image is a **visual reference**. Production requires appropriately high-resolution, separable art layers or a carefully engineered scene renderer. It must not show blurry erased text, painted-over rectangles, or artifacts of an old screenshot. Avoid using the AI mockup's status bar or printed buttons as an actual UI asset.

### 2.2 Time and perspective

- Each scheduled item has a **stable absolute timestamp** and a stable world path position `P(time)` for its day. Items always appear in chronological order. Do not move event anchors based on re-computing their positions relative to a moving current time every frame.
- `NOW` is computed from the real clock and defaults to about **62% down the visible map**, so users see the next part of the day ahead and the recent past behind.
- At startup or when tapping **Back to Now**, animate the virtual camera to the current timestamp without changing any event timestamps.
- Time changes update the Now position gradually without forcing a camera recenter while the user is actively panning, zooming, selecting an item, or dragging the sheet.
- The background and route share one scene camera. Landmarks are projected from their world locations using that camera. Only decorative depth layers receive parallax factors; markers must **never drift away from the path**.
- Three zoom presets, with pinch interpolation and accessible controls: **Near** (about 4 hours visible), **Mid** (about 8 hours visible), **Whole Day** (00:00–24:00 local day). The app may display adjacent-day event continuations clearly, but cannot falsely squeeze them into today's timestamp range.
- Depth cues: nearby route is broader and clearer; distant route narrows and softens, but event labels retain readable size. Camera movement should feel like moving through time, **not** the user dragging a flat wallpaper.
- If a day contains no scheduled events: serene map, Now marker, Quick Focus and 'Nothing scheduled yet' state; never show fake events.

### 2.3 Map navigation and performance

- One-finger pan = browse earlier/later times in a stable, continuous scene. A small **Back to Now** button appears only once the camera has meaningfully left current time; it must not cover the logo.
- Pinch zoom = scale around the gesture focal point, keep selected event anchored sensibly, clamp zoom range, no abrupt reset or oscillation.
- The task sheet and map have **separate gesture regions**. Panning the sheet must not move the map; moving the map must not drag the sheet. Touching a map marker selects its event and updates the sheet.
- Never update a giant layered scene at 60 frames per second just to refresh the displayed clock. Animate through GPU transforms, cache art, and limit expensive layout / label-placement recalculations. Target smooth native-feeling interaction on the user's iPhone, and profile rather than asserting a frame rate.
- `Reduce Motion` = no camera flying/parallax; use crossfades and explicit accessible time navigation instead.

### 2.4 Overlap and event clustering

- Event labels and markers must not overlap the Now pin, headers, action sheet, or each other. Compute collisions **after** projection into screen coordinates at the current zoom level.
- Minimum marker/label separation is based on actual rendered bounds and touch targets; as a starting rule use a roughly **64-pt marker** separation and **8-pt gap** between label cards. Tune from device testing.
- Nearby items that cannot be legibly displayed become a stacked marker, e.g. `2` or `3+`; cluster size is determined by screen-space overlap, not arbitrary event minutes alone.
- Tap the cluster: if 2–3 events, show a small anchored bubble stack with exact titles and times; if more, expand the bottom drawer to the matching group with a prominent `View all [n]` action. Each item can be selected or started (if startable).
- Zooming in may split a cluster; zooming out may merge one. No marker should randomly change its event identity during the transition.
- No bogus badge counts: a displayed `3+` means at least three actual entries; VoiceOver says the exact count.

### 2.5 Event markers and truthful focus footprints

- **Scheduled event** = planned time, never proof that it occurred.
- **Focus block** = calendar reservation containing one or more tasks.
- **Actual session footprint** = unique event written at **real session start time** once persistence succeeds. A second pause/resume of the same session does not make duplicate start dots.
- Footprint states: attempted/ended early, active, paused, timer target reached, and **explicitly user-confirmed task finished**. Timer expiration alone does not mean task completion.
- Unscheduled focus is placed at its actual start time; scheduled focus start may leave both a planned landmark and a separate actual footprint.
- Completed task updates its task record and associated representation across Plan, Now, and Focus; a focus session ending never automatically checks every block task.
- Footprints remain available after relaunch and when browsing previous days. Retain event history unless the user deletes it.

### 2.6 NOW bottom sheet

- A white/frosted sheet is **attached above the fixed Now/Plan tab bar**, not floating with a large white gap. Its handle follows the finger continuously and snaps smoothly between **Peek**, **Middle**, and **Expanded** states.
- Peek: selected task/block title or `Ready to focus?`, optional saved next action, large **LOCK IN · 25 min**, duration and honest protection status.
- Middle: current or selected task details and up to a few upcoming items.
- Expanded: Today / Later task list, selected block's assigned tasks, quick add and access to Plan. Sheet scrolls independently once fully expanded.
- Selected event and sheet title use the same ID/color; the sheet is never allowed to show an unrelated stale selection.
- One visible primary button: `LOCK IN` for new work; `Back to Focus` for active session; `Resume` for paused. Do not stack multiple identical blue primary actions.
- `Map/Path` toggle: Map = layered 2.5D scene; Path = **compact next 4–6 hours** chronological view (not an editable duplicate of Plan).

## 3. PLAN: CALENDAR + TASKS — EXACT INTERACTION CONTRACT

### 3.1 Locked visual treatment

- Reduce the current large/heavy calendar header by approximately **20–25%** without sacrificing date navigation. Display selected date, concise week strip, and a small `Today` control.
- Background: warm blue-gray / subtle off-white (example `#F3F6FA`). Navy text (example `#17284C`), blue actions (`#3269E8`), gentle white / blue-gray event surfaces, restrained shadows. Avoid an all-white, empty planner.
- Category colors differentiate events and block types. Source badges distinguish local, iCloud/Apple-account, and Google calendar events without duplicating them.
- Calendar time grid remains crisp and readable, with a **red live Now line** and timestamp label when the selected day is today. Do not show the red line on a different day.
- No imitation of Anchor's logo, images, exact marketing material, or proprietary visuals. Match smoothness and affordances, not branding.

### 3.2 Calendar and task drawer layout

- **Calendar above, tasks below**. Two separately scrollable regions, separated by a visible grab handle. On opening Plan, present a balanced state (roughly 60% calendar / 40% tasks within usable content height).
- Grab handle changes calendar height continuously with finger; snap points roughly 40%, 60%, and 85% calendar. Task drawer keeps an accessible header even at 85%; in compact-calendar mode tasks become more prominent.
- Dragging the calendar surface **scrolls calendar time**, not resizing the split. Dragging the divider **resizes the split**. Dragging a task card **starts task placement**. Distinguish these gestures by hit zones and press/drag thresholds.
- Task drawer: Unscheduled, Today, Later; add a title-only task; optional notes, checklist, duration, due date and saved next action; record completed state. Quick add and microphone prominent but not competing.
- Tap task -> detail/edit. Long press task -> lift and drop. A clearly labeled `Schedule` / `Choose time` option works without drag-and-drop and for VoiceOver.

### 3.3 Focus blocks, tasks, and external calendar events

- **Task:** work item, independently completable, stable ID, optionally in multiple focus blocks. Unscheduled tasks remain in task drawer.
- **Focus block:** own ID, start/end, recurrence if supported, source `local` by default, color/type, ordered assignment list of task IDs; editing block does not rewrite task identity.
- **External calendar event:** own source account, calendar ID and remote event ID. It is not an Ignition task or focus block unless the user intentionally links one.
- A 90-minute Focus block can contain three or more tasks. Starting a 25-minute session from it does not truncate the 90-minute reservation; the session is separate and references that block.
- Drag task onto empty timeline: propose a new focus block at snapped time, with task inside. Drag task onto existing block: add it, avoiding duplicate assignment to that block. Drag one task between blocks: offer move or add (reusable task model). Task completion propagates to all assignments.
- Moving a block: grab body / move handle, drag to time, display live start/end preview; snap to **15-minute** grid. Resizing: drag visible **bottom handle**, change end time in 15-minute steps, enforce minimum duration and no inverted intervals. Context-menu editor is fallback, not replacement.
- For an editable external event, make a remote write only to its actual source after permission. Read-only events cannot be changed with a fake success animation.
- Multiple simultaneous events must render side by side or as a controlled stack. Conflicts are signaled but never automatically deleted or rescheduled. Provide Undo for moves, resize, and reassignment.
- Dates spanning midnight, timezone transitions, all-day events and recurring-instance changes must preserve actual temporal semantics.

### 3.4 Core event editing flow

Tap empty slot -> choose `Task`, `Focus block`, or `Event` -> prepopulate selected start -> edit title, end/duration, destination calendar (if publishing), reminders and notes -> save -> update local Plan + Now -> enqueue external sync if applicable. Tapping a block opens its task checklist and `LOCK IN` action. The selected block remains stable across view transitions.

## 4. APPLE + GOOGLE CALENDAR — TWO-WAY SYNC CONTRACT

### 4.1 Provider strategy and duplicates

- Use **EventKit** for calendars registered in iOS Calendar (including iCloud and Google accounts surfaced through the device), after permission and per-calendar writeability checks.
- Offer **direct Google OAuth / Google Calendar API** for accounts the user chooses to connect directly. A Google account also visible through EventKit must **not** be ingested and edited through two competing writers. Choose one authoritative integration path **per calendar/account** and deduplicate using provider IDs and account mappings.
- Local Ignition tasks and focus blocks do not silently become remote events. Publishing a block to a calendar is an explicit user choice; thereafter retain a durable mapping to its remote counterpart.
- An external event is edited in its **original calendar**; don't accidentally sync one Google event into iCloud or vice versa. Moving between calendars is a deliberate user action with confirmation.

### 4.2 Required synchronization behavior

| Trigger | Required behavior |
|---|---|
| Create/edit/delete inside Ignition | Save locally immediately; show pending status; enqueue provider write; confirm synced only after successful provider response |
| Open Ignition | Refresh relevant selected calendars and reconcile pending writes |
| Open Plan | Refresh and show last-sync status |
| Plan visible, connected, network available | Request incremental refresh at approximately **60-second intervals** (not a background guarantee) |
| Pull to refresh | Request an immediate sync and show progress/result |
| Calendar changes outside Ignition | EventKit store-change signal and Google incremental retrieval on next available refresh |
| App backgrounded | Opportunistic background tasks/push where supported; **never promise every-minute delivery** |
| Offline | Keep local edits in durable write queue, show `Waiting to sync`, retry with backoff after connectivity returns |
| Provider rejects change | Keep local pending/conflicted copy and clear error; do not falsely mark synced |

- Google: initial full sync, per-calendar persisted incremental `syncToken`, correctly paginated updates including deletes, `410 Gone` recovery through safe full resync without deleting the user's independent Ignition tasks. Use conditional update/version checks (e.g. ETag and `If-Match` where supported). Respect rate limits, exponential backoff, token refresh and revoked OAuth authorization.
- EventKit: request read/write permission where needed, observe store changes, fetch stable identifiers appropriately and reconcile after external edits. An EventKit Google calendar is still Google-owned; never double-write it through direct Google API.
- Changes are reconciled by account+calendar+provider event ID, with local mapping/version timestamps. Avoid echo loops: a server echo of Ignition's write is an acknowledgement, not a new event.

### 4.3 Conflicts and safety

- When the same event is changed in two places before sync, do not blindly assume last local device clock wins. Compare provider version, remote modified metadata, and pending local operation; if ambiguous, present `Keep Ignition version` / `Use calendar version` with both times visible.
- Recurring event choices are explicit: `This occurrence` versus `Entire series`; obey provider limitations. Never edit entire series by accident.
- Remote deletion removes the external calendar event representation but **does not erase an independent local task or actual focus history**. Keep an audit tombstone to avoid re-importing deleted events.
- Disconnect an account: stop writes, discard credentials securely, and let the user choose whether to clear imported cached events. Local Ignition data remains intact.
- Never send Google OAuth tokens or microphone recordings to logs; store access tokens in Keychain or other appropriate secure storage.
- **Known platform limitation:** iOS `BGTaskScheduler` cannot promise a guaranteed background 60-second polling interval. Do not market guaranteed one-minute synchronization. A future server push component could improve latency but is a separate infrastructure decision.

## 5. VOICE ADD — MUST FIX CURRENT RECORDING LOSS

### 5.1 User flow

1. Tap microphone in Plan task drawer / quick add.
2. Explicit state `Listening…` with live partial transcript that stays visible. Users can type corrections while speaking is stopped.
3. Tap **Done** (or Stop recording). Stop microphone capture, **wait for the recognizer's final result**, preserve all accumulated transcript text; never clear it merely because the audio engine stopped.
4. Parse into an editable preview card in the section where the user initiated capture: `Task`, `Event`, or `Focus block`, with title/date/start/duration/checklist as inferred.
5. Show **Confirm**, **Edit**, and **Discard**. Confirm saves exactly once, closes capture UI, and places the new item into Plan (and Now if scheduled). No unexpected automatic calendar write.
6. If transcription or parsing fails, retain raw recognized words in an editable text field with `Try again` and `Save as plain task`; never silently lose the user's entry.

Example: “Study cardiology tomorrow at seven for one hour” -> `Study cardiology`, tomorrow 7 PM, 60 minutes, default proposed `Focus block` (editable). “Buy groceries” -> title-only task with **no invented schedule**.

### 5.2 Parsing and privacy

- Recognize obvious relative dates against user's current time zone and calendar locale. For ambiguity ("next Friday", "after lunch", unspecified AM/PM), request confirmation in the draft rather than silently guessing.
- Support one utterance with multiple items (e.g., “Call Anna tomorrow and read paper tonight”) by offering separate draft cards when parsing confidence permits; do not drop trailing content.
- Ask Speech/microphone permission contextually. On-device speech recognition where available; support keyboard fallback when denied/offline. Recording audio is ephemeral and not retained by default; recognized text is retained only as required for user confirmation or saved task.
- Stop/Done, Discard, navigation-away and interruptions must not perform the same destructive action. Unsaved drafts survive accidental sheet dismissal until explicitly discarded or confirmed within a bounded local draft lifecycle.

## 6. FOCUS: LOCK IN, PROTECTION, AUDIO, RETURN

### 6.1 Start and timer truth

- From Now or a Plan focus block: one tap **LOCK IN** creates a durable `FocusSession` with actual start timestamp, target seconds, optional task/block ID, intervals, status and unique event ID. Write to persistent storage before representing the start as successful.
- Focus is available without any calendar event or Screen Time authorization (`Quick focus`, `Timer only · Protection off`). No mandatory planning, account or first-step entry.
- Timer calculation uses persisted wall-clock timestamps plus pause/break intervals, not an in-memory repeating decrement. Correct after lock, app background/termination, reopening, midnight and daylight-saving changes.
- Focus screen stays our approved dark, starry, glass-dock composition. Task/next step, countdown, progress, **Break**, **Pause**, **End**, safe **Emergency Exit**, music player. Do not redesign the screen.

### 6.2 Session action semantics

| Action/state | Focus time | Shield | Return |
|---|---|---|---|
| LOCK IN | Starts | Attempt authorized shield; show verified state | Active session |
| Pause | Stops accumulating | Temporarily off by current agreed default | Resume same session |
| Break | Separate break interval | Preserve protection where supported; otherwise warn and use safe tested behavior | Resume or end break |
| Resume | Continues same session | Reapply if authorized | Back to Focus |
| End | Stop | Release own shields | Show optional Close |
| Emergency Exit | Stop safely | Request immediate release, reconcile stale state | Never trap user |
| Target time reached | Mark timer elapsed, **not task completed** | Release via supported scheduling and reconcile | Offer Close |

Device Activity short-session limits and scheduled callbacks must be verified against real iOS behavior; never claim that a 2-minute protected session safely auto-unblocks on an untested workaround. Shield can't force-quit other apps or guarantee suppression of all their notifications.

### 6.3 Dynamic Island, Lock Screen and widgets

- Preserve existing validated Live Activity target wiring, including proper `NSSupportsLiveActivities` and extension inclusion. Display activity/task title, accurate timer, pause state and progress on supported screens.
- Timer projection is shared with Focus UI. On pause, the external display must **stop counting down**. On resume, continue from correct remaining seconds. On End, clear or mark activity ended promptly; use stale states appropriately.
- Tapping Live Activity returns to **the current session**, not a new session. Don't create duplicate Live Activities upon app relaunch. Home Screen widgets provide Quick Focus and next-task action when supported, with truthful permission handling.
- OS controls Live Activity delivery and presentation; detect support, user authorization, and fallback gracefully.

### 6.4 Sound and music

- Built-in choices: Silence, original/copyright-cleared solo piano, ambient piano, rain, brown noise, soft ambient. Only include original recordings or tracks with verified rights **for the exact audio recording**, not just a public-domain composition.
- Play/pause, loop and in-app volume; no music starts without user intent unless previously configured. With appropriate audio session, playback can continue during phone lock/background.
- Handle incoming calls, headphones, AirPlay, other audio playback, and volume/system interruptions. Optional Apple Music handoff or integration later; do not claim deep Spotify control if not provided.

### 6.5 Return and honest Close

- **Active:** back to the already-running session, don't reset timer.
- **Paused:** Resume the existing timer; show saved next action.
- **Ended/abandoned:** Start Again creates a new session and offers the preserved next action; optional single contextual `Start small · 2 min` variant, no multiple competing flows.
- Close choices: Finished / Made progress / Not finished / Skip; no preselection. Save optional next step/link. A session reaching zero never marks all block tasks complete. Skipped outcome remains unknown.

## 7. NOTIFICATIONS, HISTORY AND SETTINGS

- Notifications: timer finished, break completed, scheduled work, optional missed-start rescue (only when there was an actual planned time), optional return reminder. No repeated guilt nags; deduplicate and reschedule after event edits.
- History event journal: `sessionStarted`, `paused`, `resumed`, `breakStarted`, `breakEnded`, `timerElapsed`, `sessionEnded`, `outcomeSaved`, `taskCompleted`, `planEdited`, `shieldStatusChanged` with actual timestamps. Planned work and completed work remain distinct data sets.
- Settings: selected apps/websites for blocking, protection authorization status, timer durations, focus music, connected calendars and sync health, language/speech, notifications, privacy/delete/export, accessibility.
- Permission-denied mode still supports local Plan tasks, Now landscape and timer-only Focus. No forced login. Data stays local by default; cloud calendar connection is opt-in.

## 8. CANONICAL DATA MODEL & STATE INVARIANTS

Use the existing codebase, but normalize to this separation rather than storing everything as a calendar event.

```text
TaskRecord(id, title, notes, nextAction?, dueDate?, completedAt?, color, links[])
FocusBlock(id, localStart, localEnd, timeZoneID, category, taskIDs[] ordered, recurrence?, calendarPublishLink?)
ExternalEvent(id, provider, accountID, calendarID, remoteID, title, startUTC, endUTC, timeZoneID,
              writable, recurringMasterID?, instanceID?, providerVersion, lastRemoteUpdate)
FocusSession(id, taskID?, focusBlockID?, startedAtUTC, targetSeconds, activeIntervals[], pauseIntervals[],
             breakIntervals[], state, protectionState, endedAtUTC?, outcome?, nextActionSnapshot?)
FocusEvent(id, sessionID?, taskID?, blockID?, occurredAtUTC, kind, payload)
CalendarSyncJob(id, provider, accountID, remoteID?, operation, payload, baseVersion?, createdAt,
                attempts, status, lastError?)
VoiceDraft(id, transcript, proposedType, extractedFields, ambiguityFlags, createdAt)
MapScene(cameraTime, zoomLevel, selectedEventID?, userIsExploring)
```

**Absolute-time persistence; local-time presentation.** Preserve stable IDs, migrations, original calendar provenance, and sync operation idempotency.

Non-negotiable invariants:

1. At most one active focus session; multiple taps cannot create duplicate footprints or Live Activities.
2. Task completion is explicitly driven by task/user action, never by timer elapsed.
3. Plan edits and remote sync cannot destroy prior FocusEvent history.
4. Event blocks appear in correct chronological order; camera changes never change timestamps.
5. Scene art, path, markers, and footprints use one camera/projection pipeline.
6. Local calendar edits are committed before remote submission; pending/failed state remains visible.
7. One integration writer per external event; no Apple/Google synchronization echo loops.
8. Speech draft never disappears on Stop; only Confirm or Discard resolves it.
9. Denied permissions must not crash or disable unrelated functionality.
10. UI never says `Protection on`, `Synced`, or `Completed` unless the corresponding event/state is verified.

## 9. MUST-PASS ACCEPTANCE TESTS

### A. Visual and map

- [ ] On iPhone, NOW resembles `APPROVED_NOW_REFERENCE_OCT30.png`: actual clean layered landscape, no blurry filled rectangles or flattened screenshot UI.
- [ ] Camera starts around Now, shows more future than past, and does not constantly recenter during manual exploration.
- [ ] Pan both directions, pinch through near/mid/whole day, tap Back to Now: no flicker, jitter, reversed time or changing relative event order.
- [ ] Event marker remains on its route point as scene pans/zooms; background parallax cannot detach it.
- [ ] Two nearby entries cluster; four nearby entries become `3+`; tap reveals all exact items and returns selected event to sheet.
- [ ] Empty day / 20 events / 100 events all display without overlapping headers or frozen interaction; measure frame time on real device.
- [ ] Actual quick-focus attempt creates **one** footprint at start time; early exit does not display completion.
- [ ] Sheet follows finger continuously at all 3 snap points, never conflicts with map gesture; no blank gap above tab bar.

### B. Plan and task/block editing

- [ ] Plan header compact, warm-blue-gray theme, red Now line appears today only.
- [ ] Scroll calendar independently; expand/collapse split while drawer stays reachable.
- [ ] Create task by typing; drag to 10:15; makes one block with task attached; same task ID everywhere.
- [ ] Drag second task onto existing block; block now contains 2 tasks; no duplicate.
- [ ] Move block, resize bottom handle, 15-minute snapping, Undo; block start/end survive relaunch.
- [ ] Link same task to two blocks; completing it once updates both, without completing other tasks.
- [ ] Drag task back to unscheduled / reassign between blocks without deleting task or actual focus history.
- [ ] One 90-minute calendar block can start a 25-minute Focus session without changing reservation duration.

### C. Apple / Google Calendar

- [ ] Connect iCloud calendar through EventKit; create/edit writable event; change visible in Apple Calendar.
- [ ] Connect Google calendar via chosen route; create/edit writable event; change visible in Google Calendar.
- [ ] External edit appears in Ignition on next refresh; while Plan visible, poll ~60 seconds; manual refresh works.
- [ ] A Google account also present in EventKit does **not** display or write duplicate events.
- [ ] Offline edit shows Pending, retries safely online, and never creates two remote copies.
- [ ] Same event edited on two devices raises clear conflict; remote deletion never erases local independent task/session history.
- [ ] Correct timezone/DST/all-day/overnight/recurrence and read-only behavior. Background one-minute guarantee is **not** advertised.

### D. Voice capture

- [ ] Say “Study cardiology tomorrow at seven for one hour”; tap Done; transcript remains, fields populate, preview appears.
- [ ] Edit field then Confirm -> exactly one task or block in correct place; Cancel/Discard removes only the draft.
- [ ] Say ambiguous time -> human confirmation, not silently invented date.
- [ ] Deny mic, go offline, app background during recording, or recognizer errors -> fallback preserves recognized text or clearly explains loss.

### E. Focus, protection, Live Activity

- [ ] Start 25-minute session, lock iPhone, Dynamic Island/Lock Screen show same remaining time and correct title.
- [ ] Pause externally reflected; Resume continues same session; End clears external activity and releases requested shields.
- [ ] Focus app terminated/relaunched: state reconstructs correctly, no ghost timers, no duplicates.
- [ ] Timer reaches zero while backgrounded: user sees accurate elapsed state on return; task outcome not auto-selected.
- [ ] Permission denied: Timer-only mode still works; no false `Protection on` claim.
- [ ] Screen Time full entitlement test: selected apps shield during protected session and release safely after exit and deadline; no stuck shield.
- [ ] Licensed/original audio plays in background and stops/ducks properly for calls and external audio.

## 10. BUILD HANDOFF AND DELIVERY GATES

**Do not start by generating another full mockup or rebuilding the Xcode project.** Begin by auditing the current project and documenting which requirements are already implemented, which are broken, and which are missing.

Implementation order:

1. Freeze design assets and create a reproducible iPhone screenshot comparison. Extract art layers or rebuild scenic renderer correctly. Preserve the existing working ActivityKit extension.
2. Normalize canonical time-based scene projection, camera, event clustering and footprint accuracy. Fix map performance/gestures.
3. Complete Plan split-view gestures, focus-block assignment, move/resize and task integrity.
4. Complete two-way EventKit and Google provider adapter with explicit account mapping, pending queue, conflict resolution and sync diagnostics.
5. Fix voice Done-to-draft behavior and parsing/confirmation.
6. Regression-test start/protect/timer/Live Activity/return/music/accessibility, then integrate remaining features.

A feature is **DONE** only after (a) implementation code exists, (b) complete Xcode target builds, (c) user flow succeeds on a physical iPhone, (d) relevant error/permission states are tested, and (e) tests / screenshots are documented. Syntax parse or a Markdown summary **is not** proof of working iOS behavior.

The user should get **one direct-open Xcode project**, not an endless series of patches, after the requested changes are actually integrated. Do not alter approved visuals without a fresh explicit user decision. Report any unresolved Apple entitlement or API limitation with an honest fallback and reproducible steps.

## 11. EXCLUSIONS — DO NOT ADD WITHOUT APPROVAL

- No third main tab; no Plan replacement with a basic checklist; no Journey removal or new visual identity.
- No punitive streaks, artificial nature-world resets, fabricated completion data, made-up automatic first steps or auto-playing copyrighted tracks.
- No claims of guaranteed 60-second iOS background sync, forced closure of another app, universal blocking of notifications, or guaranteed Live Activity placement.
- No hidden upload of calendar data or voice audio; no unprompted publishing of a local block to Google/iCloud.
- No "Done" button in a mockup that silently discards the transcript or a drag affordance that only opens an editor.

## 12. OFFICIAL TECHNICAL REFERENCES

- Apple EventKit full access: https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui
- Apple ActivityKit / Live Activities: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- Apple Background Tasks: https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app
- Apple Family Controls entitlement: https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement
- Google incremental calendar sync: https://developers.google.com/workspace/calendar/api/guides/sync
- Google Calendar API errors: https://developers.google.com/workspace/calendar/api/guides/errors

**End of approved specification.** Earlier proposals remain research history where they conflict with this document. This is a product/design/engineering contract and does not itself certify a working iOS application.
