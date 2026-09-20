#!/bin/sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/.build/TinyLunch.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT/.build/export}"

cd "$ROOT"
xcodegen generate
xcodebuild \
  -project TinyLunch.xcodeproj \
  -scheme TinyLunch \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive

mkdir -p "$EXPORT_PATH"
if xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$ROOT/Config/ExportOptions.plist" \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates; then
  echo "IPA: $EXPORT_PATH"
else
  echo "Archive succeeded: $ARCHIVE_PATH"
  echo "Export needs an Apple Distribution certificate and an Apple ID signed into Xcode."
  echo "Open the archive in Xcode Organizer → Distribute App → App Store Connect."
  exit 0
fi
