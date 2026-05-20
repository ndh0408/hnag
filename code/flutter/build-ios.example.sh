#!/usr/bin/env bash
# ============================================================================
# HNAG — build iOS + cài lên iPhone (1 lệnh). MẪU AN TOÀN để commit.
# Copy thành build-ios.sh (đã .gitignore) và điền giá trị thật, rồi chạy:
#   MAC_PW=your_mac_password bash code/flutter/build-ios.sh
#
# Vì sao qua phiên GUI: token Apple ID nằm trong data-protection keychain,
# chỉ Terminal GUI trên Mac đọc được → build/ký phải chạy ở đó.
# Cài thì dùng devicectl qua WiFi (iOS 26.5 + Xcode 16.2).
# ============================================================================
set -e

VM_USER_UID=501
DEVICE_UDID="${DEVICE_UDID:-YOUR_IPHONE_UDID}"   # xcrun devicectl list devices
BUNDLE=vn.hnag.hnag
MAC_PW="${MAC_PW:?Đặt biến môi trường MAC_PW (mật khẩu macOS VM), vd: MAC_PW=xxxx bash build-ios.sh}"
LOCAL_FLUTTER="$(cd "$(dirname "$0")" && pwd)"

echo "==> 1/4  Sync code lên Mac VM"
scp -q -r "$LOCAL_FLUTTER/lib" "$LOCAL_FLUTTER/pubspec.yaml" vm:/Users/ndh0408/hnag-flutter/
echo "    done."

echo "==> 2/4  Build + ký trong Terminal GUI (keychain mở ở đó)"
ssh vm "rm -f ~/hnag_build.log; echo $MAC_PW | sudo -S launchctl asuser $VM_USER_UID osascript \
  -e 'tell application \"Terminal\" to activate' \
  -e 'tell application \"Terminal\" to do script \"cd ~/hnag-flutter && export PATH=/usr/local/bin:\$PATH LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && ~/flutter/bin/flutter build ios --release 2>&1 | tee ~/hnag_build.log\"'" >/dev/null
echo "    đang build... (lần đầu ~5-8 phút, sau đó ~2 phút)"

echo "==> 3/4  Chờ build xong"
ssh vm 'LOG=~/hnag_build.log
for i in $(seq 1 100); do
  [ -f "$LOG" ] && grep -qiE "Built build/|Encountered error|Failed to build|BUILD FAILED|No Accounts" "$LOG" && break
  sleep 10
done
grep -iE "Built build/|Encountered error|No Accounts|Failed to build" "$LOG" | tail -2'

echo "==> 4/4  Cài + mở app trên iPhone (WiFi)"
ssh vm "APP=~/hnag-flutter/build/ios/iphoneos/Runner.app
[ -d \"\$APP\" ] || { echo 'BUILD CHƯA RA .app — xem log ~/hnag_build.log'; exit 1; }
for t in 1 2 3; do
  xcrun devicectl device install app --device $DEVICE_UDID \"\$APP\" 2>&1 | grep -qiE 'Complete!|App installed' && { echo 'CÀI XONG'; break; }
  echo \"thử lại \$t (tunnel WiFi)...\"; sleep 6
done
xcrun devicectl device process launch --device $DEVICE_UDID $BUNDLE 2>&1 | tail -1"

echo "==> XONG. Mở khoá iPhone là thấy app chạy."
