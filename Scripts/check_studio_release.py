from pathlib import Path
import json, subprocess
root=Path(__file__).resolve().parents[1]
src=root/'Sources/App'
app=(src/'IgnitionApp.swift').read_text()
now=(src/'NowView.swift').read_text()
plan=(src/'PlanView.swift').read_text()
focus=(src/'FocusAndReturn.swift').read_text()
settings=(src/'SettingsView.swift').read_text()
landscape=(src/'LivingDay.swift').read_text()
assert 'enum IgnitionDesign' in app and 'enum IgnitionMotion' in app
assert 'enum IgnitionFeedback' in app and 'ignition.haptics.enabled' in app
assert 'Toggle("Touch feedback", isOn: $hapticsEnabled)' in settings
assert 'NowDrawerMath.visibleHeight' in now and '.offset(y: fullHeight - visibleHeight)' in now
assert 'NowTodayList' in now and 'NowTaskCard' in now and 'NowLockButton' in now
assert 'Your day, one start at a time.' not in now
assert 'Text("Today")' in now and 'size: 24' in now
assert 'NowDrawerDetent' in now and '.half' not in now
assert 'NowWorkRow' in now and 'NowSectionHeader' not in now
assert 'Focus on' in now and '2-min start' in now
assert 'IgnitionMotion.sheet' in now and 'accessibilityReduceMotion' in now
assert 'accessibilityReduceMotion' in landscape and 'JourneyViewportGeometry' in landscape
assert 'if let next = session.nextStep' in focus and 'ignition.lockIn' in app
assert 'LiveTaskRow' in (root/'Sources/Widgets/PreviewLiveWidget.swift').read_text()
assert 'LiveTaskRow' in (root/'Sources/Widgets/IgnitionWidgets.swift').read_text()
assert 'calendarFraction' in plan and '.dropDestination(for: String.self)' in plan
contents=json.loads((root/'Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
assert contents['images'][0]['filename']=='AppIcon1024.png'
from PIL import Image
icon=Image.open(root/'Assets.xcassets/AppIcon.appiconset/AppIcon1024.png')
assert icon.size==(1024,1024) and icon.mode=='RGB'
project=(root/'Ignition.xcodeproj/project.pbxproj').read_text()
assert project.count('ASSETCATALOG_COMPILER_APPICON_NAME') == 4
assert (root/'DesignReference/APPROVED_NOW_REFERENCE_OCT30.png').exists()
print('PASS: design tokens, motion/haptics, accessibility, drawer transition, app icon, widget contents, approved artwork reference')
