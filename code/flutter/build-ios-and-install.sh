#!/bin/zsh -l
# HNAG iOS — build signed Runner.app + install on iPhone Kayn over WiFi.
#
# Per memory hnag-ios-signing-flow:
#  - Xcode 16.2 archive validation FAILS for iPhone Kayn (iOS 26.5)
#    because Xcode 16.2 only knows iOS ≤18.2
#  - `flutter build ios --release` (just signed Runner.app, NO archive) WORKS,
#    and `devicectl device install app` can deploy it to iOS 26.5
#
# Invoke via:  open -a Terminal ~/build-ios-and-install.sh
# Running it inside a GUI Terminal is required so the login.keychain is
# accessible (codesign needs the private key) and CocoaPods runs as the
# user (it crashes when running as root).

set -e
LOG=/tmp/hnag-install.log
exec > >(tee -a "$LOG") 2>&1
echo "=== HNAG iOS build + install — $(date) ==="

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PATH="$HOME/flutter/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

cd ~/hnag-flutter || { echo "FATAL: ~/hnag-flutter not found"; exit 1; }

echo "── 1. flutter clean + pub get"
flutter clean
flutter pub get

echo "── 2. pod install"
( cd ios && pod install )

echo "── 3. flutter build ios --release (signed Runner.app, no archive)"
flutter build ios --release

APP=~/hnag-flutter/build/ios/iphoneos/Runner.app
if [[ ! -d "$APP" ]]; then
  echo "FATAL: $APP not built — check log above for actual error."
  exit 2
fi
echo "Runner.app size = $(du -sh "$APP" | cut -f1)"

echo "── 4. install onto iPhone Kayn over WiFi"
UDID=00008130-000E31A40AFA001C
xcrun devicectl device install app --device "$UDID" "$APP"

echo "── 5. launch app on iPhone"
xcrun devicectl device process launch --device "$UDID" vn.hnag.hnag || true

echo "── DONE $(date). Mở app HNAG trên iPhone Kayn — bottom-nav default đã là Hi-Fi v2."
echo "DONE_OK"
