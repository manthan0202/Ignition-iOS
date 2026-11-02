#!/usr/bin/env python3
"""Non-UIKit structural regression gates for the Plan redesign.
NOT a substitute for Xcode typechecking or touch testing."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
plan=(root/'Sources/App/PlanView.swift').read_text()
needed={
  'compact Plan header': 'private var planHeader: some View',
  'single top-level Add menu': 'Button("New task", systemImage:',
  'calendar event creator': 'showNewEvent = true',
  'focus block creator': 'createFocusBlock()',
  'voice creator': 'showVoice = true',
  'calendar menu preserved': 'showCalendarMenu = true',
  'sync refresh preserved': 'await model.refreshCalendars()',
  'dark task drawer': '.background(PlanPalette.drawer)',
  'Inbox and Today filters': 'taskFilter("Inbox"',
  'task context actions': 'Button("Add to existing block"',
  'task drag payload': '.draggable("task:',
  'calendar drop target': '.dropDestination(for: String.self)',
  'block resize': 'CalendarDurationHandle(',
  'block membership': 'work.assign(',
  'read-only event drag restriction': 'func planDragIfEditable(',
  'all day disclosure': 'showAllDayPicker = true',
  'timeline indicator': 'TimelineView(.periodic(',
  'no duplicate event drawer': 'private var timedEvents:',
  'accessible divider': '.accessibilityAdjustableAction',
  'no competing navigation title': '.toolbar(.hidden, for: .navigationBar)',
  'native focus action': 'model.lockIn(blockID: blockID)',
  'Apple/Google event destination': 'googleCalendars: model.google.calendars',
}
for name,token in needed.items():
    if token not in plan:
        raise AssertionError(f'Missing {name}: {token}')
assert 'Text("TASKS")' not in plan, 'Duplicate TASKS scaffolding remains'
assert '"Hold & drag"' not in plan, 'Permanent helper text remains'
assert '"Pull down for more calendar"' not in plan, 'Permanent helper text remains'
assert '"Live timeline"' not in plan, 'Redundant timeline label remains'
assert len(re.findall(r'private func taskRow\(',plan))==1
assert len(re.findall(r'private var taskDrawer:',plan))==1
assert len(re.findall(r'private var dateHeader:',plan))==1
assert len(re.findall(r'private var weekPicker:',plan))==1
assert '.frame(width: timeGutter - 4, height: 23)' in plan
print(f'PASS: {len(needed)} Plan functional/visual gates; no duplicate controls; adaptive time and event cards')
