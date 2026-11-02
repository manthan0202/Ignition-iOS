#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Test the actual Foundation model extracted from Domain.swift, not a duplicate.
{ printf 'import Foundation\n'; sed -n '/^\/\/ BEGIN_FOCUS_BLOCK_MODEL/,/^\/\/ END_FOCUS_BLOCK_MODEL/p' Sources/App/Domain.swift; } > /tmp/ignition-real-focus-model.swift
swiftc /tmp/ignition-real-focus-model.swift Tests/FocusBlocksStressTest.swift -o /tmp/ignition-focus-block-stress
/tmp/ignition-focus-block-stress
