import json, pathlib, subprocess
root=pathlib.Path(__file__).resolve().parent.parent
pbx=root/'Ignition.xcodeproj/project.pbxproj'
o=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(pbx)]))['objects']
for obj in o.values():
    if obj.get('isa')=='PBXBuildFile':
        assert obj.get('fileRef') in o, f"Dangling buildfile: {obj}"
    if obj.get('isa')=='PBXGroup':
        for ref in obj.get('children',[]): assert ref in o, f"Dangling group file: {ref}"
for target in [x for x in o.values() if x.get('isa')=='PBXNativeTarget']:
    for phase in target.get('buildPhases',[]): assert phase in o
names={}
for t in o.values():
    if t.get('isa')=='PBXNativeTarget': names[t['name']]=t
for name in ['Ignition','IgnitionPreview']:
    target=names[name]
    phases=[o[p] for p in target['buildPhases'] if o[p].get('isa')=='PBXSourcesBuildPhase']
    sourcepaths={o[o[x]['fileRef']].get('path') for phase in phases for x in phase.get('files',[])}
    for required in ['Sources/App/JourneyMechanics.swift','Sources/App/CalendarSyncRules.swift','Sources/App/VoiceDraftParser.swift','Sources/App/GoogleCalendarService.swift','Sources/App/CalendarService.swift','Sources/App/LivingDay.swift','Sources/App/PlanView.swift','Sources/App/LiveActivityService.swift']:
        assert required in sourcepaths, f"{name}: missing compiled source {required}"
        assert (root/required).is_file()
for path in ['Assets.xcassets/JourneyScenery.imageset/JourneyScenery.png',
             'Assets.xcassets/JourneyMid.imageset/JourneyMid.png',
             'Assets.xcassets/JourneyForeground.imageset/JourneyForeground.png',
             'DesignReference/APPROVED_NOW_REFERENCE_OCT30.png']:
    assert (root/path).is_file()
for path in ['Config/IgnitionPreview-Info.plist','Config/Ignition-Info.plist']:
    data=(root/path).read_text()
    assert 'IgnitionGoogleOAuthClientID' in data and 'NSSupportsLiveActivities' in data
for widget in ['Sources/Widgets/PreviewLiveWidget.swift','Sources/Widgets/IgnitionWidgets.swift']:
    assert (root/widget).is_file()
print('PASS: project IDs, compiled Swift membership for both app schemes, artwork, Info.plist, widgets')
