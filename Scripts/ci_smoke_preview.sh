#!/usr/bin/env bash
# CI-only Preview smoke test; does not test real iPhone shielding/Live Activity behavior.
set -euo pipefail

: "${DERIVED_DATA:?DERIVED_DATA must point at the xcodebuild derived-data directory}"
: "${CI_ARTIFACTS:?CI_ARTIFACTS must point at the logs/screenshots directory}"
mkdir -p "$CI_ARTIFACTS"
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/IgnitionPreview.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: Preview app not found at $APP" >&2
  exit 1
fi

UDID="$(xcrun simctl list -j devices available | python3 -c '
import json, sys
raw=json.load(sys.stdin)
choices=[]
for runtime, devices in raw.get("devices", {}).items():
    if "iOS" not in runtime: continue
    for device in devices:
        if device.get("isAvailable") and "iPhone" in device.get("name", ""):
            choices.append((runtime, device.get("name", ""), device.get("udid", "")))
if not choices:
    sys.exit("No available iOS iPhone simulator; Preview smoke test cannot run.")
choices.sort(reverse=True)
print(choices[0][2])
')"

echo "Selected simulator UDID: $UDID"
# Only boot if it isn't already running.
if ! xcrun simctl list devices booted | grep -q "$UDID"; then
  xcrun simctl boot "$UDID"
fi
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"

APP_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"
echo "Launching $APP_ID"
xcrun simctl launch "$UDID" "$APP_ID"
sleep 4
xcrun simctl io "$UDID" screenshot "$CI_ARTIFACTS/ignition-preview-home.png"
echo "Preview launch and screenshot completed (not a visual-quality or gesture test)."
