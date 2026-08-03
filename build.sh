#!/bin/bash
# Peak Week — one-command build for macOS
# Builds the Swift app and assembles PeakWeek.app in this folder.
set -e
cd "$(dirname "$0")"

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift not found. Install Apple's command line tools first:"
  echo "    xcode-select --install"
  echo "…then run ./build.sh again."
  exit 1
fi

echo "▸ Building (release)…"
swift build -c release

APP="PeakWeek.app"
BIN=".build/release/PeakWeek"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PeakWeek"

cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Peak Week</string>
  <key>CFBundleDisplayName</key><string>Peak Week</string>
  <key>CFBundleIdentifier</key><string>local.peakweek.app</string>
  <key>CFBundleExecutable</key><string>PeakWeek</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSAppleEventsUsageDescription</key><string>Peak Week sends weekly training plans to your clients through Messages and Mail.</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so macOS runs it without complaints on this machine
codesign --force --deep -s - "$APP" 2>/dev/null || true

echo ""
echo "✔ Built $APP"
read -p "Install to /Applications? [y/N] " yn
if [[ "$yn" == "y" || "$yn" == "Y" ]]; then
  rm -rf "/Applications/PeakWeek.app"
  cp -R "$APP" /Applications/
  echo "✔ Installed. Find 'Peak Week' in your Applications folder / Launchpad."
else
  echo "Left in this folder — double-click PeakWeek.app to run."
fi
echo ""
echo "Your data lives at: ~/Library/Application Support/PeakWeek/data.json"
