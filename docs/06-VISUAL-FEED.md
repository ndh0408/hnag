# 06 — Visual-First Feed & Video Experience

> **Philosophy:** *Show food. Don't describe food.* — Mọi recommendation là một khung hình điện ảnh, không phải một dòng text. Người dùng phải **muốn ăn ngay** chỉ trong 0.4 giây nhìn thấy.

---

## 1. Visual-First Principles

### 1.1 The 0.4-second Rule
Mọi card xuất hiện trên màn hình phải pass test sau **trong 0.4 giây**:
1. Đây là món gì? *(ảnh đủ rõ)*
2. Bao nhiêu tiền? *(price tag dễ thấy)*
3. Có gần không? *(distance pill)*
4. Có ngon không? *(rating + AI badge)*

Nếu thiếu 1 trong 4 → redesign card.

### 1.2 Hierarchy of Visual Truth
```
1. FOOD VIDEO (autoplay, muted)          ←── 70% màn hình
2. FOOD IMAGE (fallback nếu no video)
3. STILL PHOTO (cropped 4:5 hoặc 9:16)
4. AI-generated preview (last resort)
5. PLACEHOLDER (color block with food emoji) — never let user see grey square
```

### 1.3 The "Cinema Food" Aesthetic
- Mỗi món được treat như poster phim
- Hi-res, hi-contrast, hi-saturation (+8% saturation từ original)
- Subtle Ken Burns effect (zoom 1.0 → 1.04 over 8s)
- Vignette nhẹ ở mép (giúp text overlay đọc được)
- Steam, sauce drip, condensation — visible details
- Color grading consistent: warm shadows, slight crush blacks

### 1.4 Motion = Information
- Card **breathes** (scale 1.0 ↔ 1.01 mỗi 4s) — báo "still alive"
- **Tilt parallax** theo gyroscope (depth illusion)
- **Saliency loop**: hot/đông quán → pulse glow on map pin
- **Magnetic buttons** — finger gần 20px = button "hút" lại

---

## 2. The Home Feed — TikTok Explore Reimagined

### 2.1 Feed Architecture

```
┌─────────────────────────────────────────────┐
│  [Status bar — transparent]                  │
├─────────────────────────────────────────────┤
│  ▼  HCM, Quận 1 · 🌧 28°  · 12:34         │  ← Floating glass header
│                                              │
│  [👤Avatar] [🔥Trending] [📍Gần] [🤖 Hà]  │  ← Tab bar (horizontal scroll)
├─────────────────────────────────────────────┤
│                                              │
│  ╔════════════════════════════════════════╗ │
│  ║                                        ║ │
│  ║   [Hero video — 16:9, autoplay]        ║ │  ← "AI Pick of the Moment"
│  ║                                        ║ │     full-bleed, sound off
│  ║   Tinted overlay bottom 30%            ║ │
│  ║                                        ║ │
│  ║   ✨ Hà gợi ý cho bạn                  ║ │
│  ║   Bún bò Huế · Bà Hai                  ║ │
│  ║   ⭐ 4.8 · 45k ₫ · 600m · 12 phút     ║ │
│  ║                                        ║ │
│  ║   [▶ Xem 23s]  [Đặt giao]  [🗺]       ║ │
│  ╚════════════════════════════════════════╝ │
│                                              │
│  ── 🔥 Trending Near You ──────────  Xem >  │
│  [horizontal scroll cards 9:16 vertical]    │
│  [card 1] [card 2] [card 3] [card 4] ...    │
│                                              │
│  ── 🌙 Late Night (only 11pm–4am) ──        │
│  [horizontal scroll]                        │
│                                              │
│  ── 💕 Date Night ──                        │
│  [horizontal scroll]                        │
│                                              │
│  ── 💰 Dưới Ngân Sách 50K ──                │
│  [horizontal scroll, price-tag prominent]   │
│                                              │
│  ── 🎬 Viral TikTok Tuần Này ──             │
│  [grid 2-col, vertical videos]              │
│                                              │
│  ── 🌧 Trời mưa, ấm bụng ──                 │
│  [auto-shows when weather=rain]             │
│                                              │
│  ── 😌 Theo mood của bạn ──                 │
│  [horizontal scroll, mood-tagged]           │
│                                              │
│  ── 👥 Bạn bè đang ăn ──                    │
│  [Stories-style row of friends]             │
│                                              │
│  ── 💎 Hidden Gems (AI khám phá) ──         │
│  [horizontal scroll, "Hà tìm thấy" badge]   │
│                                              │
│  ── 🎲 Chưa quyết được? Quay vòng ─        │
│  [Random Wheel mini-widget embedded]        │
│                                              │
└─────────────────────────────────────────────┘
[Home] [Search] [✨AI Decide] [Social] [Profile]
```

### 2.2 The 10 Feed Sections (priority order)

| # | Section | When shown | Source |
|---|---------|------------|--------|
| 1 | **✨ AI Pick of the Moment** | Always, top hero | Personalized #1 |
| 2 | **🔥 Trending Near You** | Always | District trending |
| 3 | **🌙 Late Night** | 22:00–05:00 only | Open-now + night-tag |
| 4 | **💕 Date Night** | Fri–Sun evenings | Cuisine fit couples |
| 5 | **💰 Under Budget** | Always | User budget – 30% |
| 6 | **🎬 Viral TikTok Foods** | Always | TikTok ingestion |
| 7 | **🌧 Weather-based** | Rain/cold/hot triggers | Weather + cuisine map |
| 8 | **😌 Mood Foods** | After mood pick or inferred | Mood–food matrix |
| 9 | **👥 Friends Eating** | If user has ≥3 friends | Social graph |
| 10 | **💎 Hidden Gems** | Always | Low-pop + high-rating filter |

**Personalization weight:** sections re-ordered per user. New user sees default; after 7 days, ML picks order.

### 2.3 Feed Refresh Strategy
- **Pull-to-refresh:** runs new AI pass + fetches new content (haptic + Hà loading)
- **Auto-refresh:** every 15 min when foreground (silent)
- **Smart prefetch:** when user 60% scroll → preload next 3 sections
- **Cache:** last 50 cards stored offline → opens instantly

---

## 3. The Food Card — Complete Anatomy

### 3.1 The "Mega Card" (used in Hero + Card Stack)

```
┌─────────────────────────────────────────────┐
│                                             │
│   [VIDEO LOOPS — 9:16, autoplay muted]      │ ← 70% height
│                                             │
│   [Steam/sauce animation overlay]           │
│                                             │
│   ╔ Top-left chips ════════════════════╗    │
│   ║ 🔥 #1 Trending · 🤖 AI Pick · 4.8★ ║    │
│   ╚════════════════════════════════════╝    │
│                                             │
│   ╔ Top-right ═════════════════════════╗    │
│   ║ 🔊 (mute toggle)  🔖 (save)        ║    │
│   ╚════════════════════════════════════╝    │
│                                             │
│   ┌────────────────────────────────────┐    │
│   │ ░░░░░░ glass gradient bottom ░░░░░ │    │
│   │                                    │    │
│   │ Bún bò Huế đặc biệt                │    │
│   │ ⭐ 4.8 (1,234) · 45.000 ₫           │    │
│   │ 🗺 Bà Hai · 600m · ⏱ 12 phút giao  │    │
│   │ 🍲 Cay vừa · 🌶 480 cal · 30 phút  │    │
│   │ 🟢 Đang mở · 🔥 23 người vừa đặt   │    │
│   │                                    │    │
│   │ ✨ "Trời mưa Hà Nội — ấm bụng    │    │
│   │     cho ngày se lạnh"  — Hà        │    │
│   └────────────────────────────────────┘    │
│                                             │
│   [Nấu]    [Đặt giao]    [Đi ăn]   [🗺]    │ ← CTA bar (sticky)
│                                             │
│   ⬅ Skip    ▼ Lát tính    ▲ Chi tiết       │ ← Swipe hints (fade out)
└─────────────────────────────────────────────┘
```

### 3.2 Data Schema per Card (everything visual-ready)

```json
{
  "card_id": "card_8f9a...",
  "type": "food_recommendation",
  "rank": 1,
  "media": {
    "primary_video": {
      "url": "cdn://video/bunbohue-001.mp4",
      "poster": "cdn://img/bbh-001-poster.avif",
      "duration_s": 18,
      "loop": true,
      "blurhash": "L9..."
    },
    "fallback_images": ["url1", "url2", "url3"],
    "creator_credit": "@phodaytay (TikTok)"
  },
  "title": "Bún bò Huế đặc biệt",
  "subtitle": "Quán Bà Hai · 12 Lê Lợi",
  "badges": [
    { "type": "trending", "text": "#1 Trending Q1", "icon": "🔥" },
    { "type": "ai_pick", "text": "Hà gợi ý", "icon": "✨" },
    { "type": "viral", "text": "Viral TikTok 24h", "icon": "🎬" }
  ],
  "price": {
    "amount": 45000,
    "currency": "VND",
    "display": "45k ₫",
    "vs_user_budget": "in_range"
  },
  "rating": { "avg": 4.8, "count": 1234, "verified": true },
  "distance": {
    "meters": 600,
    "display": "600m",
    "walk_min": 8,
    "delivery_min": 12
  },
  "calories": 480,
  "macro_summary": { "p": 28, "c": 52, "f": 18 },
  "tags": ["cay vừa", "ấm bụng", "miền trung"],
  "flavor": { "spicy": 3, "salty": 2, "umami": 5 },
  "vibe": ["truyền thống", "đông khách", "nhanh"],
  "live_status": {
    "is_open": true,
    "closing_in_min": 240,
    "crowdedness": 0.72,
    "wait_minutes": 5,
    "recent_orders_24h": 387
  },
  "ai_reason": "Trời mưa Hà Nội — ấm bụng cho ngày se lạnh",
  "actions": {
    "cook": { "enabled": true, "recipe_id": "..." },
    "order": { "primary": "grabfood", "deeplink": "...", "alt_links": [...] },
    "dine": { "navigation": "...", "book_table": false }
  },
  "social_proof": {
    "friends_been": [
      { "user_id": "u1", "avatar": "...", "name": "Mai" },
      { "user_id": "u2", "avatar": "...", "name": "Khoa" }
    ],
    "friend_count": 7,
    "trending_reviews": [
      { "text": "Ngon xuất sắc!", "avatar": "..." }
    ]
  },
  "tiktok_videos": [
    { "url": "...", "creator": "@x", "views": 240000 }
  ],
  "interaction_meta": {
    "shown_count": 0,
    "session_id": "...",
    "experiment_arm": "B"
  }
}
```

### 3.3 Compact Card Variants

**A. Vertical Story Card (9:16) — used in horizontal carousels**
```
┌──────────────┐
│              │
│  [video 9:16]│
│              │
│  ⭐ 4.8       │
│              │
│              │
│              │
│  Bún bò Huế  │
│  45k · 600m  │
│  🟢 Open     │
└──────────────┘
```

**B. Wide Card (16:9) — Feed hero**
- Same as Mega but wider crop
- 2-line title support
- 3 CTAs

**C. Mini Card (1:1) — Profile saves, search results**
```
┌────┬─────────────────────┐
│img │ Bún bò Huế          │
│ 80 │ 45k · 600m · ⭐4.8  │
│ 80 │ Hà gợi ý ·          │
└────┴─────────────────────┘
```

**D. Lockscreen Card (Live Activity iOS 16.1+)**
- Used for: Order tracking, cooking timer, group voting open
- Updates every 30s via push

**E. Widget Card (iOS/Android home screen)**
- "Hôm nay ăn gì?" widget
- 1 món + 1 CTA + auto-refresh hourly
- Tap → Open app to that card

---

## 4. Video-First Experience

### 4.1 Video Sources (priority)

1. **Creator videos** — uploaded by HNAG creators (highest engagement)
2. **TikTok embeds** — licensed/permitted via TikTok Content API
3. **Restaurant-uploaded** — by claimed restaurant owners
4. **AI-generated previews** — Sora/Veo style food b-roll (last-resort, watermarked)
5. **Curated stock footage** — for generic dishes

### 4.2 Video Specs
- **Format:** HLS adaptive (240p / 480p / 720p / 1080p)
- **Codec:** H.265 + AV1 fallback for Android
- **Aspect:** 9:16 primary, 1:1 for grid, 16:9 for hero
- **Duration:** 6–30s ideal, max 60s
- **Loop:** seamless (last frame ≈ first frame)
- **Autoplay:** muted by default, on-screen sound toggle
- **Bandwidth-aware:** start at 480p on cellular, 720p on Wi-Fi

### 4.3 Video Pipeline

```
Creator/Restaurant uploads .mp4
       ↓
Cloudflare R2 (origin storage)
       ↓
Worker: ffmpeg job queue
       ↓
HLS multi-bitrate (240/480/720/1080)
       ↓
AI vision pass:
  • Detect food items (YOLOv8)
  • Auto-tag (cuisine, flavor, mood)
  • Generate poster (best frame)
  • Generate blurhash placeholder
  • Generate AI captions (Whisper VN)
  • Moderation (NSFW, safety, fake)
       ↓
CDN (Cloudflare + AWS CloudFront)
       ↓
Manifest cached, prefetched
```

### 4.4 Video Player Behaviors

**In Feed (preview mode):**
- Autoplay muted at 480p when ≥60% visible
- Pause when ≤30% visible
- After 8s preview → loops or moves to next card
- Tap → fullscreen player

**In Fullscreen Viewer:**
- Vertical TikTok-style — swipe up for next, down for prev
- Tap & hold → pause + show details panel
- Double-tap → like with heart burst animation
- Long-press right → 2× speed
- Swipe right → share sheet
- Caption auto-shown bottom (Vietnamese)
- "Đi đến quán này" sticky CTA

### 4.5 Video Performance Targets
- **Time to first frame:** < 250ms on Wi-Fi, < 600ms on 4G
- **Rebuffer ratio:** < 0.5%
- **CDN cache hit:** > 95%
- **Bandwidth: monthly per active user:** target ≤ 350 MB

---

## 5. Cinematic Food Transitions

### 5.1 Signature Transitions

**A. "Plate Drop" — entry transition**
- Card slides up from bottom + bounces (spring)
- Steam particles spawn at top edge
- Duration: 450ms

**B. "Liquid Morph" — Hero → Detail**
- Hero image morphs into Detail screen using shared element + liquid distortion (Skia shader)
- Title text re-positions with Hero animation
- Duration: 600ms

**C. "Steam Reveal" — AI thinking → cards**
- Background fogs (Gaussian blur + steam particles)
- Cards emerge as steam clears
- Sound: subtle "pssh" + warm tone
- Duration: 1.8s

**D. "Sauce Splash" — Like animation**
- Heart pulses red → orange splash particles
- Drips down briefly
- Haptic: medium impact

**E. "Plate Spin" — Random Wheel**
- 3D plate spinning (Three.js / Flutter Skia)
- Slowdown easeOut + tilt physics
- Confetti when stops + AI announces with TTS

**F. "Restaurant Door Open" — Restaurant detail entry**
- Doors swing open animation
- "Welcome" sound (subtle bell)
- Map mini zooms in

### 5.2 Micro-Animations Library (Rive files)

| Name | Use | Trigger |
|------|-----|---------|
| `pulse-pin` | Trending pin on map | Visible |
| `breathe-card` | Card alive indicator | Always on home |
| `chopstick-loading` | Loading state | API call |
| `bowl-empty` | Empty state | No results |
| `confetti-burst` | Success | Order, streak, vote win |
| `ha-orb` | AI assistant idle | Voice mode |
| `mood-wheel-spin` | Mood selector | Tap |
| `heart-burst` | Like | Double-tap |
| `sparkle-trail` | Premium upgrade | Tap |
| `steam-rising` | Food card hover | 8s loop |
| `coin-stack` | Save money badge | Earn |
| `phone-vibrate` | Notification | Push received |

---

## 6. Glass + Gradient System

### 6.1 Glass Layers (3 levels)

**Level 1 — Light glass** (header, chips)
```css
backdrop-blur: 20px
background: rgba(255,255,255,0.6)
border: 1px solid rgba(255,255,255,0.4)
```

**Level 2 — Heavy glass** (bottom sheets, modals)
```css
backdrop-blur: 40px saturate(180%)
background: rgba(255,255,255,0.72)
shadow: 0 24px 64px rgba(15,15,18,0.16)
```

**Level 3 — Mega glass** (premium card overlay)
```css
backdrop-blur: 60px
background: linear-gradient(135deg, rgba(255,107,43,0.15), rgba(168,85,247,0.10))
border: 1px solid rgba(255,255,255,0.6)
inner-shadow: inset 0 1px 0 rgba(255,255,255,0.8)
```

### 6.2 Dynamic Gradients

Background gradient **shifts based on context**:

```
Context              Gradient
─────────────────────────────────────────────────
Morning 6–10am       #FFD166 → #FF6B2B (sunrise)
Noon 11–14           #FF6B2B → #E63946 (warm)
Afternoon 15–17      #FF8A65 → #FFB74D
Evening 18–21        #6B4FA0 → #FF6B2B (dusk)
Late Night 22–04     #1A1A40 → #4A1B5C (mauve dark)
Rain                 #4A6FA5 → #1A2F45 (cool blue)
Hot day >32°C        #FF5733 → #FFC300 (heat shimmer)
User mood: stress    #4A1B5C → #2D2D40 (calming)
User mood: chill     #5C6BC0 → #26A69A (cool teal)
Premium screens      Always premium gradient
```

Gradient transitions: 800ms cubic-bezier(0.4, 0, 0.2, 1) when context changes.

---

## 7. Magnetic UI Behaviors

### 7.1 Magnetic Buttons
- Finger ≤ 30px → button scales 1.06 + slight lean toward finger
- Haptic light tick on enter "magnetic zone"
- Haptic medium on tap

### 7.2 Snappy Lists
- Horizontal carousels snap to card center
- Velocity-aware (fast flick → multi-card jump)
- "Edge resistance" — bounce on overscroll

### 7.3 Card Stack Physics
- Drag rotates card up to ±15°
- Throw at >800px/s = auto-decide (like/skip)
- Stack peek of next 2 cards visible behind
- Z-depth scale: top 1.0, next 0.92, then 0.85

### 7.4 Pressure-sensitive (3D Touch / Long-press)
- Long-press card 0.5s → preview modal (peek)
- Press harder (iOS) → committed open
- Haptic stages: light → medium → heavy

---

## 8. Smart Header (Context Strip)

The header is **alive** — changes every minute.

```
┌────────────────────────────────────────────────┐
│ HCM, Q1 · 🌧 28°C, Mưa nhẹ · 12:34 trưa       │
│                                                │
│ "Mưa rồi đó — tô nóng nhé?"   [✨ Hà tư vấn]  │
└────────────────────────────────────────────────┘
```

**Behaviors:**
- Glass effect when scrolling (intensifies with scroll velocity)
- Weather icon animates (rain drops, sun rays, etc.)
- Greeting line is **AI-generated** mỗi giờ, contextual
- Tap "Hà tư vấn" → opens AI chat mini-modal

**Greeting examples:**
- 7am: "Chào buổi sáng Thảo, đói chưa nè?"
- 12pm + rain: "Trưa mưa Hà Nội, tô bún bò chứ?"
- 5pm + Friday: "Cuối tuần rồi, ăn gì sang chảnh?"
- 11pm: "Đêm khuya rồi, snack nhẹ thôi nhé"
- After payday: "Lương về, đãi bản thân món xịn đi!"

---

## 9. Search & Discovery — Visual

### 9.1 Search Screen

```
┌──────────────────────────────────────────────┐
│ ← [🎤] [🔍 Tìm món, quán, người...]  [📷]   │
├──────────────────────────────────────────────┤
│                                              │
│ ── Đề xuất Hà ────────────────────────       │
│ "phở bò ngon dưới 60k"                       │
│ "quán date sang chảnh"                       │
│ "ăn healthy không quá 500 cal"               │
│                                              │
│ ── Trending tuần này ──                      │
│ [grid 2-col video preview]                   │
│                                              │
│ ── Categories ──                             │
│ 🍜 Phở   🍚 Cơm   🍢 Đồ nướng  ☕ Cafe       │
│ 🍰 Tráng miệng   🥤 Đồ uống   🍔 Fast food   │
│                                              │
│ ── Recent searches ──                        │
│ "bún chả gần đây"                            │
│ "lẩu thái"                                   │
│                                              │
└──────────────────────────────────────────────┘
```

### 9.2 Visual Search

- Tap camera icon → open camera
- Point at food → realtime AI detection box
- Capture → identify + show similar dishes
- Or upload from gallery
- Also accepts: paste TikTok/IG link → AI extracts food

### 9.3 Voice Search

- Tap mic → "Bạn muốn ăn gì nè?"
- Voice waveform live
- Natural language: "tìm quán phở bò Bắc gần đây, mở 24/7"
- Or paste link mode: "ăn gì giống video TikTok này"

---

## 10. The "Ăn gì giống video này?" Feature

### 10.1 Flow
1. User copies TikTok/IG/Facebook reel link → pastes in app (auto-detect from clipboard with permission prompt)
2. AI extracts video metadata + downloads thumbnail
3. Vision model identifies dish in video
4. Search nearby restaurants serving it
5. Show side-by-side: TikTok video ↔ Card of restaurant nearest

```
┌────────────────────┬───────────────────────┐
│                    │                       │
│  [TikTok video]    │   Nearest match:      │
│  (embedded)        │                       │
│                    │   ╔═══════════════╗   │
│                    │   ║ [restaurant]  ║   │
│  Detected:         │   ║               ║   │
│  "Bánh tráng cuốn  │   ║ Bánh tráng    ║   │
│   thịt heo Đà Nẵng"│   ║ Đệ Nhất       ║   │
│                    │   ║ ⭐4.7 · 600m   ║   │
│  By @khoailangthang│   ║ 60k · 8 phút  ║   │
│  2.4M views        │   ║ [Đi] [Đặt]    ║   │
│                    │   ╚═══════════════╝   │
│                    │                       │
│                    │   5 quán khác →       │
└────────────────────┴───────────────────────┘
```

---

## 11. Empty States — Visual

**No results:**
```
┌──────────────────────┐
│                      │
│   [Lottie: empty     │
│    bowl with chopsticks
│    looking around]   │
│                      │
│  Hmm... chưa tìm     │
│  được gì hợp 🤔      │
│                      │
│  Thử mở rộng:        │
│  [+] Tăng ngân sách  │
│  [+] Mở rộng 1km     │
│  [+] Bỏ giới hạn diet│
└──────────────────────┘
```

**Offline:**
- Soft yellow banner top: "Bạn đang offline · Hà dùng dữ liệu cũ"
- Cached cards still browsable
- Save actions queue for sync

**First-time empty (new user):**
- "Hà chưa biết bạn đủ. Trả lời 60 giây để bắt đầu" → Onboarding redo CTA

---

## 12. Notification Visual Standards

### 12.1 Rich Push (iOS Notification Service Extension + Android Big Picture)

```
┌──────────────────────────────────────────┐
│ 🍜 Hôm Nay Ăn Gì?              now       │
├──────────────────────────────────────────┤
│ [Food hero image — wide 4:1]             │
│                                          │
│ Trời mưa rồi đó 🌧                       │
│ Phở Lý Quốc Sư cách 200m,                │
│ 35k, mở đến 11pm — đi không?             │
│                                          │
│ [Đi ngay]  [Đặt giao]  [Để lát]          │
└──────────────────────────────────────────┘
```

### 12.2 In-app banner (when notif arrives while app open)
- Slides down from top, 4s auto-dismiss
- Glass background, food image thumbnail
- Tap → navigate to relevant content

### 12.3 Live Activity (iOS Dynamic Island)
- Order tracking with progress
- Cooking timer
- Group voting countdown

---

## 13. Performance Targets (Visual Quality vs FPS)

| Scenario | Target FPS |
|----------|-----------|
| Home feed scroll | 60 (90 on ProMotion) |
| Card stack swipe | 60 |
| Video autoplay (1 active) | 60 |
| Video autoplay (multiple) | 30 minimum |
| Map pan/zoom | 60 |
| Fullscreen video viewer | 60 |
| Animations (Rive) | 60 |
| AI thinking loader | 60 |

**Quality degradation strategy:**
1. Reduce video active simultaneously: 3 → 1
2. Pause Rive offscreen
3. Replace Ken Burns with static
4. Reduce blur radius
5. Disable parallax tilt

Triggered by: low battery, thermal throttle, low RAM device class.

---

## 14. Accessibility-Compatible Visuals

- **Reduce motion:** disable Ken Burns, breathing, parallax — keep transitions <100ms
- **Increase contrast:** swap glass to solid backgrounds
- **Large text:** scale up to 200% without breaking layouts (auto-layout reflows)
- **Color-blind safe:** never red/green as sole signal — always paired with icon/label
- **Voice-over:** every visual element has semantic Vietnamese label
- **Subtitles:** every video has VN auto-captions (Whisper + manual review)

---

## 15. Visual QA Checklist (per release)

- [ ] Every screen tested on iPhone SE (small) + iPad (large) + Galaxy S24 + Pixel 8 + foldable
- [ ] Dark mode + Light mode parity
- [ ] Late Night mode auto-triggers and looks distinct
- [ ] Glass effects render correctly on Android <12 (fallback solid)
- [ ] Video autoplay works on cellular
- [ ] No janks during scroll (Flutter DevTools profile)
- [ ] All animations <16ms frame budget
- [ ] No layout shift on image load (blurhash placeholder)
- [ ] Empty states illustrated, not placeholder text
- [ ] Loading states never spinner-only (skeleton screens)

---
