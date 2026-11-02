#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo 'Parsing all Swift sources...'
swiftc -frontend -parse $(find Sources -name '*.swift')
echo 'Compiling Foundation session tests...'
swiftc Sources/Shared/SessionCore.swift Tests/SessionSmokeTest.swift -o /tmp/ignition-session-smoke
/tmp/ignition-session-smoke
echo 'Running expanded deterministic stress suite...'
swiftc Sources/Shared/SessionCore.swift Tests/SessionStressTest.swift -o /tmp/ignition-session-stress
/tmp/ignition-session-stress
echo 'Testing Living Day viewport regression (empty day, pan, zoom, midnight)...'
swiftc Sources/App/JourneyMechanics.swift Tests/JourneyViewportRegressionTest.swift -o /tmp/ignition-journey-viewport
/tmp/ignition-journey-viewport
echo 'NOTICE: iOS APIs cannot be typechecked or run without Xcode and Apple SDK.'
