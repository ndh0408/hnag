#!/bin/zsh -l
# HNAG iOS — sign in GUI Terminal context + install onto iPhone Kayn over WiFi.
#
# Why this script: the SSH-only path fails at signing because the macOS keychain
# can't be unlocked from a remote session (see memory hnag-ios-signing-flow).
# Run this from a Terminal window OPEN ON THE MAC GUI (Screen Sharing/VNC/
# locally) so the keychain unlock prompt can be answered.
#
# Prerequisites:
#  - ~/flutter@3.44.0 installed (NOT /opt/flutter)
#  - iPhone Kayn paired over WiFi + Developer Mode on
#  - Free Apple Development cert in login.keychain (team FP8Z984262)
#  - Code synced to ~/hnag-flutter
#
# Usage:
#  zsh build-ios-and-install.sh
#
# Status output goes to /tmp/hnag-install.log and stdout.

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

echo "── 3. flutter build ipa (development export, real signing)"
# Make sure the keychain is unlocked. If prompted, just hit "Always Allow".
flutter build ipa --release --export-method development

echo "── 4. locate IPA"
IPA=$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1)
if [[ -z "$IPA" ]]; then
  echo "FATAL: no IPA produced. Likely signing failed — check log above."
  exit 2
fi
echo "IPA = $IPA ($(du -h "$IPA" | cut -f1))"

echo "── 5. discover iPhone Kayn over WiFi"
DEV=$(xcrun devicectl list devices 2>/dev/null \
  | awk '/Kayn/ {print $NF}' | head -1)
if [[ -z "$DEV" ]]; then
  echo "── (devicectl couldn't list Kayn — try cabled USB or pair via Xcode)"
  echo "Available devices:"
  xcrun devicectl list devices 2>&1 | sed 's/^/   /'
  exit 3
fi
echo "iPhone Kayn UDID = $DEV"

echo "── 6. install IPA"
xcrun devicectl device install app --device "$DEV" "$IPA"

echo "── DONE $(date). Open HNAG on iPhone Kayn — Tools tab → Hi-Fi Preview"
