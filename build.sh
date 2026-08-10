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
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <!-- This app's whole job is an hourly timer that fires while nobody is
       looking at it. App Nap targets exactly that shape — an idle, occluded,
       background app — and coalesces its timers, so an automatic send can
       drift well past its hour. Opt out. -->
  <key>LSAppNapIsDisabled</key><true/>
</dict>
</plist>
PLIST

# App icon
[ -f assets/AppIcon.icns ] && cp assets/AppIcon.icns "$APP/Contents/Resources/"

# Signing. This matters more than it looks: macOS keys the Automation
# permission (the one that lets us drive Messages and Mail) to the app's CODE
# IDENTITY. An ad-hoc signature (-s -) derives that identity from the binary
# itself, so EVERY rebuild is a different app as far as TCC is concerned — the
# grant you gave last time no longer applies, and an unattended automatic send
# fails with "not permitted" while the app looks fine.
#
# Fix it once: make a self-signed code-signing certificate in Keychain Access
# (Keychain Access ▸ Certificate Assistant ▸ Create a Certificate…, type
# "Code Signing", self-signed), then export its name:
#     export PEAKWEEK_SIGN_ID="Peak Week Local"     # add to ~/.zshrc to keep it
# The identity is then stable across rebuilds and the grant sticks.
if [ -n "${PEAKWEEK_SIGN_ID:-}" ]; then
  echo "▸ Signing as: $PEAKWEEK_SIGN_ID"
  codesign --force --deep -s "$PEAKWEEK_SIGN_ID" "$APP"
  SIGNED_STABLE=1
else
  codesign --force --deep -s - "$APP" 2>/dev/null || true
  SIGNED_STABLE=0
fi

echo ""
echo "✔ Built $APP"
if [ "$SIGNED_STABLE" = "0" ]; then
  echo ""
  echo "⚠ Ad-hoc signed. macOS sees this as a NEW app, so the permission that"
  echo "  lets Peak Week drive Messages/Mail was just reset. After launching:"
  echo "     • send one week manually (Send ▸ Send now) and ALLOW the prompt,"
  echo "       or re-tick Peak Week under System Settings ▸ Privacy & Security"
  echo "       ▸ Automation. Automatic sends fail silently until you do."
  echo "  To stop this happening every build, see PEAKWEEK_SIGN_ID in build.sh."
fi
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
