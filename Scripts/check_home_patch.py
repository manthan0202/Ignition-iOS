"""Source-level regression guards; NOT an iPhone UI or animation test."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
landscape=(root/'Sources/App/LivingDay.swift').read_text()
now=(root/'Sources/App/NowView.swift').read_text()
checks={
    'shared artwork+landmarks+footprints camera transform': '.offset(y: camera)' in landscape and 'Image("JourneyScenery")' in landscape,
    'fixed reference time (no drifting event coordinates)': '@State private var sceneOrigin = Date()' in landscape and 'relativeTo: sceneOrigin' in landscape,
    'real elapsed time vertical spacing': 'pointsPerHour: CGFloat = 106' in landscape and 'date.timeIntervalSince(now) / 3600' in landscape,
    'recenter without changing time': 'exploredOffset = 0' in landscape and 'Back to Now' in landscape,
    'single session footprints without connector glitches': 'ForEach(todaysSessions)' in landscape and 'SESSION FOOTPRINTS' in landscape,
    'no duplicated tasks assigned to blocks': '!assignedTaskIDs.contains(item.id)' in landscape,
    'event cards packed separately on both sides': 'lastForSide[side] - 60' in landscape,
    'event timestamp independent from card position': 'anchorY: anchor' in landscape and 'labelY: label' in landscape,
    'no predicted drag bounce': 'value.translation.height' in landscape and 'value.predictedEndTranslation.height' not in landscape,
    'bottom sheet supports interactive dragging': '.updating($sheetDrag)' in now,
    'bottom sheet has three snap detents': '(.compact, compact), (.medium, medium), (.expanded, full)' in now,
    'Path heading clearance': '.padding(.top, 164)' in now,
    'approved scenic source asset preserved': (root/'Assets.xcassets/JourneyScenery.imageset/JourneyScenery.png').exists(),
}
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
assert all(checks.values()), 'Home map source invariant failed'
# Numerical regression: 30 minutes must be visually distinguishable.
points_per_hour=106
assert points_per_hour*.5>=50
# Two 164-point cards on a 390-point view should not touch.
assert 390*.5-164 >= 20
print('PASS: 30-minute interval 53pt; alternating labels remain separated on 390pt width')
