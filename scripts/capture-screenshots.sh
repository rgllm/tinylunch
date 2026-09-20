#!/bin/sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT/docs/screenshots}"

DEVICE_ID="${DEVICE_ID:-}"
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID=$(xcrun simctl list -j devices available | python3 -c '
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    if "iOS-27-0" not in runtime and "iOS 27" not in runtime:
        continue
    for device in devices:
        if device.get("name") == "iPhone 17 Pro Max" and device.get("isAvailable"):
            print(device["udid"])
            raise SystemExit
raise SystemExit("No iOS 27 iPhone 17 Pro Max simulator")
')
fi
DESTINATION="${DESTINATION:-platform=iOS Simulator,id=$DEVICE_ID}"

cd "$ROOT"
mkdir -p "$SCREENSHOT_DIR"
xcodegen generate

xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$DEVICE_ID" override \
  --time "9:41" \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100 \
  --operatorName "" || true

export SCREENSHOT_DIR
export TEST_RUNNER_SCREENSHOT_DIR="$SCREENSHOT_DIR"
export TEST_RUNNER_CAPTURE_APP_STORE_SCREENSHOTS=1
export CAPTURE_APP_STORE_SCREENSHOTS=1

xcodebuild \
  -project TinyLunch.xcodeproj \
  -scheme TinyLunch \
  -destination "$DESTINATION" \
  -derivedDataPath "$ROOT/.build" \
  -only-testing:TinyLunchUITests/ScreenshotTests \
  test

for image in "$SCREENSHOT_DIR"/0*.png; do
  [ -f "$image" ] || continue
  bmp="${image%.png}.bmp"
  sips -s format bmp "$image" --out "$bmp" >/dev/null
  sips -s format png "$bmp" --out "$image" >/dev/null
  rm -f "$bmp"
done

echo "Screenshots: $SCREENSHOT_DIR"
sips -g pixelWidth -g pixelHeight "$SCREENSHOT_DIR"/0*.png
xcrun simctl ui "$DEVICE_ID" appearance light >/dev/null 2>&1 || true
