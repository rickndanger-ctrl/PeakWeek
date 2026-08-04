#!/bin/bash
# TestFlight release: archive + upload. Prereqs (Rick's clicks, one time):
#   1. Xcode → Settings → Accounts → signed in with the developer Apple ID.
#   2. App Store Connect → app record for com.peakweek.client exists.
#   3. ASC API key .p8 at ~/private/asc-key.p8 with env ASC_KEY_ID / ASC_ISSUER_ID.
set -euo pipefail
cd "$(dirname "$0")"
xcodegen generate
xcodebuild -project PeakWeekClient.xcodeproj -scheme PeakWeekClient \
  -destination "generic/platform=iOS" -archivePath build/PeakWeekClient.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath build/PeakWeekClient.xcarchive \
  -exportPath build/export -allowProvisioningUpdates \
  -exportOptionsPlist ExportOptions.plist
xcrun altool --upload-app -f build/export/PeakWeekClient.ipa -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
