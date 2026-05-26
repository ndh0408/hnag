# HNAG — Flutter App (Hi-Fi v2)

> **Hôm Nay Ăn Gì?** — AI food discovery for Vietnamese users. v2 design system live, all flows wired to real backend.

## Quick start

```bash
flutter pub get

# Run on Android emulator (x86_64)
flutter build apk --release --target-platform=android-x64
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n vn.hnag.hnag/.MainActivity

# Run on iOS (Mac VM with Free Apple cert; see build-ios-and-install.sh)
ssh vm "open -a Terminal ~/build-ios-and-install.sh"
```

## What's inside

- **~30 user-facing screens** across `lib/screens/{auth,home_v2,detail_v2,ai_v2,social_v2,profile_v2,settings_v2,premium_v2}` + V1 legacy (couple_mode, random_wheel, fridge_scan, nearby_restaurants, map_screen).
- **All wired to real backend** (`api.tothanhthuy.cloud`). No demo/fake data — see `lib/screens/_hifi_demo.dart` for the wire-up factory `Hifi.*` mapping each v2 screen to a real-data `_*Real` widget.
- **Design system** lives in `lib/design/` (tokens, gradients, typography) + `lib/widgets/ds/` (`HnagButton`, `HnagCard`, `HnagPhoto`, `HnagMobileNav`, etc.).
- **Realtime** via `socket_io_client` connecting to `wss://api.tothanhthuy.cloud` with JWT auth: `order:update` (status changes), `group.poll.updated` (live vote tally).
- **Bottom nav 5-item** (HnagMobileNav glass) + center FAB → AI Decide.

## Real flows verified (Android emulator, x86_64)

Login → 8-step Onboarding → Home (greeting + weather + stories + AI hero + trending + friends + TikTok grid) → Notifications bell → AI Decide (6 modes + sliders + location picker) → Mood Wheel → Card Stack (skip/save/detail/later/reroll with `aiFeedback` API) → Food Detail (3 tabs Công thức/Quán bán/Bài viết — all real data) → Restaurant Detail (4 tabs Menu/Reviews/Ảnh/Map + Chỉ đường→Google Maps deeplink/Gọi→tel:/Đặt bàn) → Cart (real saved foods or trending fallback) → Checkout (address picker with 6 presets, 3 delivery types, 5 payment methods) → Order Tracking (WebSocket `order:update` listener + Cancel via `POST /v1/orders/:id/status`) → Group Voting Team lunch (auto-create + poll + WS `subscribe:group` + Reveal kết quả dialog → Food Detail of winner) → TikTok Feed (real seeded posts + Like + Comments sheet with real fetch+post) → Profile (foodie class 🦐→🐉, Reviews/Saved/Photos/Badges tabs) → Share (native sheet) → Settings (8 sections + Theme/Language picker) → Settings & Tools sheet (14 entries including V1 Couple Mode, Random Wheel, Bản đồ quán gần, Quét tủ lạnh).

## Critical bug fixes (post emulator audit)

1. **OTP double-verify race** — `_verifyNow` fired twice (auto + manual tap), second call returned 401 because OTP consumed → `_busy + _verified` guard + `popUntil` on success.
2. **Prisma Decimal cast crash** — backend serializes Decimal as String; `as int?` / `as num?` casts blew up. Added `_asInt`/`_asDouble` safe helpers, replaced 24+ unsafe casts.
3. **Backend field naming** — `lat/lng` (not `latitude/longitude`), `cover_image` (not `cover_url`). Fallback both.
4. **Order intent 400 silent** — added user-visible toast "Món này chưa có quán nào hỗ trợ giao gần bạn 🥲".
5. **TikTok feed FK violation** — using food IDs as post IDs caused comment 400. Refactored to prefer real `/v1/feed?tab=trending`, fallback to trending foods only when posts empty.
6. **Tools sheet not scrollable** — `isScrollControlled: true` + `SingleChildScrollView` so all 14 entries reachable.
7. **Profile Badges hardcoded "4 unlocked"** — derive from real `user.foodieClass` order (tép→tôm→cua→mực→cá-mập→rồng).

## Project layout

```
lib/
├── api/                       # HnagApi (REST + Socket.IO), AuthService
├── design/                    # tokens, gradients, theme scope
├── widgets/ds/                # Hi-Fi design primitives (HnagButton, HnagCard, ...)
├── widgets/                   # legacy widgets (live_cooking.dart, etc.)
├── screens/
│   ├── _hifi_demo.dart        # Real-data factory wiring every v2 screen to backend
│   ├── auth/                  # Splash/Welcome/Permissions/Login/OTP/Forgot/Onboarding
│   ├── home_v2/               # Home/Search/AI Decide/Card Stack/WhySkip
│   ├── ai_v2/                 # Mood Wheel/Voice Hà
│   ├── detail_v2/             # Food/Restaurant/Cart/Checkout/Order Tracking
│   ├── social_v2/             # TikTok/Comments/Group voting/Meal Planner/Notifications/Late Night
│   ├── profile_v2/            # Profile screen v2
│   ├── premium_v2/            # Premium screen v2
│   ├── settings_v2/           # Settings screen v2
│   └── *.dart                 # V1 legacy: couple_mode, random_wheel, fridge_scan, nearby_restaurants, map
└── main.dart                  # Boot + auth gate + RootScreen with 4 tabs + FAB
```

## Backend API surface

See `code/backend/README.md` and the full audit table in repo root `README.md`. The Flutter app talks only to `https://api.tothanhthuy.cloud` (v1 prefix). WebSocket uses the same origin (`wss://`).
