# Ignition — Focus Blocks, Multi-task Assignments, Drag-to-Resize

**Scope:** Plan calendar feature implementation. Based on the existing interactive calendar project; **no changes to approved scenery/Now design, Focus design, ActivityKit, Dynamic Island, or Family Controls configuration**.

## What is implemented in source

- **FocusBlock is separate from WorkItem.** A block owns a start, duration, title and ordered task ID references; a task owns its own details and completion state. A single task may be used in more than one block without duplication.
- A task dragged from the lower drawer to an empty 15-minute calendar slot creates a block with that task. A task dropped onto an existing blue focus block joins that block, without removing it from other blocks.
- Tap a blank calendar time or use the stacked-rectangle toolbar button to create an empty block.
- Move a focus block by dragging its top title strip. Resize it by dragging the **small bottom horizontal handle**. Both movements snap to 15-minute increments; resizing updates stored duration.
- Editable scheduled task cards also have a bottom drag-to-resize handle; calendar items imported as read-only stay read-only.
- Tap a block's contents to edit its title, start time, duration, and task assignments. Reorder tasks with the editor's Edit button. Complete individual tasks without automatically completing others. Move tasks between blocks using the task menu; add them through the bottom-drawer picker if dragging is difficult.
- The lower drawer has **To schedule** for tasks not placed anywhere, and **On this day** for tasks individually scheduled or included in today's blocks.
- Blocks crossing midnight appear on both affected days. Overlapping events and blocks participate in one lane layout. The current-time line renders above the cards.
- Opening a block and choosing LOCK IN starts a session with the block name and the first unfinished step; it **does not** automatically mark the block's tasks complete when the timer expires. A focus session uses the user's normal timer duration (e.g., 25 minutes) inside a longer block (e.g., 90 minutes).
- Blocks and task links persist in the existing atomic `ignition-work-v1.json` storage file. Old task-only JSON decodes with an empty block plan; task deletions remove block references. No data migration deletes old tasks.

## Not claimed

- **No full Xcode build was performed in this environment.** Swift syntax parsing and Foundation tests passed, but `SwiftUI`, EventKit and on-device drag/drop cannot be compiled or executed here.
- Calendar focus blocks are **local Ignition reservations**, not automatically exported to Apple Calendar. Existing individually scheduled tasks retain their Apple Calendar behavior. Do not pretend this is two-way calendar-block synchronization.
- Native finger drag gestures inside nested scroll views and the shape of the resize preview require a physical-iPhone test. If Xcode reports a compile error, capture the FIRST diagnostic and use the same project to fix it.
- The existing Now Journey is **not modified by this targeted Plan patch**. Adding focus-block landmarks to the Journey is a separate UI integration, so it must not be mistaken for being complete.
- Do not overwrite the user's already signed `.xcodeproj` or capabilities just to add this feature. The patch updates three Swift files only.

## How to apply the three-file patch (recommended)

1. Back up the currently working project.
2. Copy `Sources/App/Domain.swift`, `Sources/App/AppModel.swift`, `Sources/App/PlanView.swift` from the patch archive into the same paths within your existing project. This keeps bundle IDs, signing, working Live Activities, widgets, and other files untouched.
3. In Xcode, select `Ignition-Preview`, choose your physical iPhone, then **Product > Clean Build Folder** (Shift+Cmd+K), then Build/Run.
4. In Plan, add a task, hold and drop it onto empty calendar time, drop another task onto its block, drag the top bar to move it, drag the bottom handle to resize it, then close/reopen the app and verify the block and both task links remain.
5. Open the block editor, reorder tasks, complete one task and ensure it is reflected in every block containing it. Start a focus session from the block and verify your existing Live Activity still works.

## Tests run here

- Parse all application Swift files: passed.
- Existing Foundation session smoke test: passed.
- Existing 28 session-state stress assertions: passed.
- Actual extracted FocusBlockPlan implementation: **109 assertions** passed, including 75 serialization cycles, linked tasks, move, resize, old-idea behavior for shared tasks, and midnight overlaps.
- Xcode `project.pbxproj` structure: passed `plutil` validation, and the full project is the same project file as before the patch.
