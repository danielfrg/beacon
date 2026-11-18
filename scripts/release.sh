#!/usr/bin/env bash
# Archive Beacon and upload it to App Store Connect (TestFlight).
# Usage: scripts/release.sh [--no-upload]
# Reads DEVELOPMENT_TEAM from Config/Local.xcconfig (git-ignored).
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM=$(sed -nE 's/^DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*([A-Z0-9]+).*/\1/p' Config/Local.xcconfig 2>/dev/null | head -1)
if [[ -z "$TEAM" ]]; then
  echo "error: set DEVELOPMENT_TEAM in Config/Local.xcconfig (see README)" >&2
  exit 1
fi

DEST=upload
[[ "${1:-}" == "--no-upload" ]] && DEST=export

mkdir -p build
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$DEST</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST

xcodegen generate
rm -rf build/Beacon.xcarchive
xcodebuild -project Beacon.xcodeproj -scheme Beacon -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Beacon.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/Beacon.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export \
  -allowProvisioningUpdates

if [[ "$DEST" == upload ]]; then
  echo "Uploaded. The build shows up in App Store Connect → TestFlight after processing."
else
  echo "Exported to build/export."
fi
