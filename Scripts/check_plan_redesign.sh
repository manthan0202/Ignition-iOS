#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export SWIFT_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/ignition-swift-cache"
mkdir -p "$SWIFT_MODULE_CACHE_PATH"
swiftc -frontend -parse $(find Sources -name '*.swift')
python3 Scripts/check_plan_redesign.py
python3 Scripts/verify_xcode_references.py
bash Scripts/check.sh
bash Scripts/check_focus_blocks.sh
bash Scripts/check_block_sessions.sh
bash Scripts/check_live_activity.sh
bash Scripts/check_now_refinement.sh
printf '\nPASS: all local Plan, app-core and project-structure checks\n'
printf 'UNVERIFIED HERE: Xcode compile, live event sync, iPhone gestures and frame timing\n'
