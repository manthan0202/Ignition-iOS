#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
swiftc Sources/Shared/SessionCore.swift Tests/BlockSessionIdentityTest.swift -o /tmp/ignition-block-session-test
/tmp/ignition-block-session-test
