#!/bin/bash
# TestFlight release — the WORKING flow (proven 2026-08-04):
#   archive + export use the signed-in Xcode account session (Account Holder;
#   cloud signing via API key fails for distribution certs at App Manager role),
#   upload uses the ASC API key (App Manager suffices there).
set -euo pipefail
cd "$(dirname "$0")"
KEY_ID="VR94Q83STA"
ISSUER_ID="74b8fcb4-5ca4-49c7-8ea5-da28120cecfc"

xcodegen generate
rm -rf build/PeakWeekClient.xcarchive build/export
xcodebuild -project PeakWeekClient.xcodeproj -scheme PeakWeekClient \
  -destination "generic/platform=iOS" \
  -archivePath build/PeakWeekClient.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/PeakWeekClient.xcarchive \
  -exportPath build/export -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
xcrun altool --upload-app -f build/export/PeakWeekClient.ipa -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID"
echo "Uploaded. Bump CURRENT_PROJECT_VERSION in project.yml before the next run."
