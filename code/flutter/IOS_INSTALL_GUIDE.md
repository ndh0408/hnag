# HNAG iOS — Cài app lên iPhone Kayn

## Tại sao cần làm thủ công?

Mac VM (`vm` SSH alias) yêu cầu **GUI Terminal context** để unlock keychain → code-sign IPA. SSH-only session bị Apple chặn (per memory `hnag-ios-signing-flow`). Đây là constraint cứng của Free Apple Development cert.

## Cách làm

### 1. Mở GUI Terminal trên Mac VM
- Mở **Screen Sharing** (macOS Built-in) hoặc **VNC** vào VM `TAILNET_HOST`
- Đăng nhập user `ndh0408`
- Mở Terminal app (Spotlight → "Terminal")

### 2. Mở Keychain Access trước (1 lần đầu)
- Mở Keychain Access → "login" keychain → tìm "Apple Development: ndh0408@gmail.com"
- Right-click → "Get Info" → tab "Access Control" → "Allow all applications to access this item" → Save
- Nhập password keychain để confirm

Bước này chỉ làm 1 lần, để các lần sau script tự sign không bị prompt.

### 3. Chạy build + install script
```bash
zsh ~/build-ios-and-install.sh
```

Script sẽ:
1. `flutter clean` + `pub get`
2. `pod install` (iOS dependencies)
3. `flutter build ipa --release --export-method development`  
   ↑ Có thể bật popup "Codesign wants to access keychain" — bấm **Always Allow**
4. Tự discover iPhone Kayn qua `xcrun devicectl list devices`
5. `xcrun devicectl device install app` để push IPA vào điện thoại

### 4. Mở app trên iPhone Kayn
- Lần đầu cần vào **Settings → General → VPN & Device Management** → trust "Apple Development: ndh0408@gmail.com"
- Mở app HNAG → bottom-nav default đã là Hi-Fi v2 design mới
- Tools tab → "🎨 Hi-Fi Preview" có 17 screens v2 fetch real data

## Nếu lỗi

### "Codesign failed: no matching profile"
→ Cert hết hạn. Mở Xcode → Settings → Accounts → refresh team.

### "devicectl couldn't list Kayn"  
→ iPhone không cùng WiFi với Mac, hoặc Developer Mode tắt. Cắm USB cũng OK.

### Keychain prompt vẫn xuất hiện liên tục
→ Bước 2 chưa làm đúng. Mở Keychain Access lại, set "Allow all" cho cert "Apple Development".

## File log

`/tmp/hnag-install.log` — kéo từ Mac về xem nếu cần debug:
```bash
scp vm:/tmp/hnag-install.log ./
```
