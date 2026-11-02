#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT
swiftc -frontend -parse $(find Sources -name '*.swift')
swiftc Sources/App/JourneyMechanics.swift Tests/NowDrawerMechanicsTest.swift -o "$TMPROOT/now-drawer"
"$TMPROOT/now-drawer"
python3 Scripts/check_studio_release.py
python3 Scripts/verify_xcode_references.py
plutil -lint Ignition.xcodeproj/project.pbxproj
echo 'NOTE: Real Xcode typechecking and iPhone frame pacing remain UNVERIFIED here.'
