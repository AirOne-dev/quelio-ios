#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/QuelIO.xcodeproj"
SCHEME="QuelIO"
BUNDLE_ID="io.quel.native"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
OUTPUT_DIR="$ROOT_DIR/docs/screenshots"
SCENARIOS=(
  "loading"
  "login"
  "dashboard-closed"
  "dashboard"
  "settings"
)

mkdir -p "$OUTPUT_DIR"

echo "Building app ($SCHEME)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS Simulator" \
  build >/dev/null

DEVICE_ID="$(
  xcrun simctl list devices available | \
  awk -v name="$SIMULATOR_NAME" '
    $0 ~ "^[[:space:]]*" name " \\(" {
      split($0, parts, "(")
      if (length(parts) >= 2) {
        id = parts[2]
        sub(/\).*/, "", id)
        print id
        exit
      }
    }
  '
)"

if [[ -z "$DEVICE_ID" ]]; then
  echo "Simulator not found: $SIMULATOR_NAME" >&2
  exit 1
fi

APP_PATH="$(
  ls -td "$HOME"/Library/Developer/Xcode/DerivedData/QuelIO-*/Build/Products/Debug-iphonesimulator/QuelIO.app 2>/dev/null | \
  head -n 1
)"

if [[ -z "$APP_PATH" ]]; then
  echo "Could not locate built app in DerivedData." >&2
  exit 1
fi

open -a Simulator
xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b >/dev/null
xcrun simctl install "$DEVICE_ID" "$APP_PATH" >/dev/null

xcrun simctl status_bar "$DEVICE_ID" override \
  --time 9:41 \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100 >/dev/null

for scenario in "${SCENARIOS[@]}"; do
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID" --screenshot "$scenario" >/dev/null
  sleep 2
  xcrun simctl io "$DEVICE_ID" screenshot "$OUTPUT_DIR/$scenario.png" >/dev/null
  echo "Captured: $scenario"
done

xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl status_bar "$DEVICE_ID" clear >/dev/null

echo "Screenshots written to: $OUTPUT_DIR"
