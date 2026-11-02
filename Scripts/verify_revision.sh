#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
plutil -lint Ignition.xcodeproj/project.pbxproj
swiftc -frontend -parse $(find Sources -name '*.swift')
bash Scripts/check.sh
bash Scripts/check_focus_blocks.sh
bash Scripts/check_block_sessions.sh
swiftc Sources/App/JourneyMechanics.swift Tests/JourneyMechanicsStressTest.swift -o /tmp/ignition-journey-stress
/tmp/ignition-journey-stress
swiftc Sources/App/VoiceDraftParser.swift Tests/VoiceDraftParserTests.swift -o /tmp/ignition-voice-stress
/tmp/ignition-voice-stress
swiftc Sources/App/CalendarSyncRules.swift Tests/CalendarSyncRulesTests.swift -o /tmp/ignition-calendar-sync-rules
/tmp/ignition-calendar-sync-rules
python3 Scripts/verify_xcode_references.py
