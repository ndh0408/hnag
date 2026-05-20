# 02 — Design System & Screen Breakdown

> **Design philosophy:** *Tasteful, Tactile, Tiền Việt.* — Hiện đại nhưng *cảm giác như nhà*. AI-futuristic nhưng warm như bữa cơm mẹ nấu.

---

## 1. Design Principles

1. **Decision in one swipe** — mọi quyết định lớn ≤ 1 gesture
2. **Show, don't tell** — ảnh món > text mô tả
3. **AI is invisible, results are magical** — không khoe AI, khoe kết quả
4. **Mobile is sacred** — thumb-zone first, one-hand operation
5. **Delight in micro** — micro-interactions ở mọi nơi
6. **Vietnamese soul** — typography, idiom, color tinh tế bản địa
7. **Speed feels premium** — perceived performance > raw performance

---

## 2. Brand Identity

### 2.1 Logo
- Wordmark + symbol: chiếc đũa tạo thành "Ä" (Á) — gợi "Ăn"
- Animated logo: 2 đũa gắp viên cơm → biến thành cờ AI sparkle
- Variants: full color, mono, app icon (squircle gradient cam-đỏ)

### 2.2 Naming
- App name: **Hôm Nay Ăn Gì?** (tagline keeps the question mark)
- Short: **HNAG**
- AI assistant: **Hà** (tên thân thiện, dễ phát âm, gợi "ha" — vị giác)

### 2.3 Voice & Tone
- **Tone:** thân thiện, dí dỏm, không trang trọng
- **Voice characteristics:** như đứa bạn thân biết ăn uống
- **Examples:**
  - ✅ "Bụng kêu rồi đó!"
  - ✅ "Thử món này coi, bao ngon"
  - ❌ "Vui lòng chọn món ăn ưa thích của quý khách"
- Never: emoji spam, kiểu cứng, Anh ngữ pha trộn không cần

---

## 3. Color System

### 3.1 Primary Palette

```
Cam Phở (Pho Orange)    #FF6B2B  ████  → CTA, brand
Đỏ Ớt (Chili Red)       #E63946  ████  → Alert, urgent, hot
Đen Mè (Sesame Black)   #0F0F12  ████  → Background dark
Trắng Bột (Rice White)  #FAFAF7  ████  → Background light
Vàng Nghệ (Turmeric)    #F4B942  ████  → Accent, badge premium
Xanh Lá Húng (Basil)    #2D8B5C  ████  → Success, healthy
```

### 3.2 Semantic Colors

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| bg/primary | #FAFAF7 | #0F0F12 | Main background |
| bg/elevated | #FFFFFF | #1A1A20 | Cards |
| bg/glass | rgba(255,255,255,0.7) | rgba(20,20,28,0.6) | Glassmorphism |
| text/primary | #0F0F12 | #FAFAF7 | Body text |
| text/secondary | #6B6B72 | #A8A8B0 | Captions |
| accent/brand | #FF6B2B | #FF7A3F | Primary CTA |
| accent/premium | gradient | gradient | Premium |
| success | #2D8B5C | #3DB374 | OK, healthy |
| warning | #F4B942 | #FFD166 | Warnings |
| danger | #E63946 | #FF5A66 | Error, allergen |

### 3.3 Gradients

```css
/* Signature */
--gradient-pho: linear-gradient(135deg, #FF6B2B 0%, #E63946 100%);

/* Premium */
--gradient-premium: linear-gradient(135deg, #F4B942 0%, #FF6B2B 50%, #E63946 100%);

/* Mood (đêm khuya) */
--gradient-late-night: linear-gradient(135deg, #1A1A40 0%, #4A1B5C 100%);

/* Mood (sáng) */
--gradient-morning: linear-gradient(135deg, #FFD166 0%, #FF6B2B 100%);

/* AI glow */
--gradient-ai: linear-gradient(135deg, #A855F7 0%, #FF6B2B 100%);
```

### 3.4 Color Usage Rules
- 60% neutral / 30% brand / 10% accent
- Never use brand orange for backgrounds (overpowering)
- Premium gradient chỉ dùng cho subscription/badge

---

## 4. Typography

### 4.1 Font Stack
- **Display + Body:** **`Be Vietnam Pro`** (Variable, Vietnamese-first)
- **Numerics + Tables:** **`SF Pro Rounded`** (iOS) / **`Roboto Mono`** (Android)
- **Accent display:** **`Sentient`** (italics for emotion)

### 4.2 Type Scale (mobile)

| Token | Size/Line | Weight | Use |
|-------|-----------|--------|-----|
| display-2xl | 56/64 | 800 | Hero numbers |
| display-xl | 40/48 | 700 | Onboarding hero |
| display-lg | 32/40 | 700 | Screen titles |
| heading-md | 24/32 | 600 | Section headers |
| heading-sm | 20/28 | 600 | Card titles |
| body-lg | 17/26 | 400 | Primary body |
| body-md | 15/22 | 400 | Secondary body |
| caption | 13/18 | 500 | Tags, captions |
| label-sm | 11/14 | 600 | Badges |
| numeric-lg | 28/32 | 700 (tabular) | Prices, calo |

### 4.3 Vietnamese typography rules
- Always test diacritics (ố, ấ, ặ) — use Be Vietnam Pro to avoid clipping
- Min size 13px for Vietnamese (smaller breaks readability)
- Avoid all-caps Vietnamese (looks aggressive)
- Use ạ/ả/ã as natural emphasis, not bold

---

## 5. Spacing & Layout

### 5.1 Grid
- 4px base unit
- 8-column mobile grid, 16px gutter, 20px edge margin
- 12-column tablet/web grid

### 5.2 Spacing tokens
```
space-1: 4px    space-5: 24px
space-2: 8px    space-6: 32px
space-3: 12px   space-7: 48px
space-4: 16px   space-8: 64px
```

### 5.3 Radius
```
radius-sm: 8px    → chips, small buttons
radius-md: 16px   → cards
radius-lg: 24px   → modals, sheets
radius-xl: 32px   → hero cards
radius-full: 999px → pills, avatars
```

### 5.4 Shadows (light mode)
```
shadow-sm:  0 1px 2px rgba(15,15,18,0.04), 0 1px 3px rgba(15,15,18,0.06)
shadow-md:  0 4px 12px rgba(15,15,18,0.08)
shadow-lg:  0 12px 32px rgba(15,15,18,0.12)
shadow-xl:  0 24px 64px rgba(15,15,18,0.16)
shadow-glow: 0 0 32px rgba(255,107,43,0.4) /* CTA glow */
```

Dark mode: invert luminance, add inner highlight `inset 0 1px 0 rgba(255,255,255,0.04)`.

---

## 6. Glassmorphism Spec

```css
.glass {
  background: rgba(255, 255, 255, 0.72);
  backdrop-filter: blur(24px) saturate(1.8);
  -webkit-backdrop-filter: blur(24px) saturate(1.8);
  border: 1px solid rgba(255, 255, 255, 0.4);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.6),
              0 8px 32px rgba(15, 15, 18, 0.08);
}

.glass-dark {
  background: rgba(20, 20, 28, 0.6);
  backdrop-filter: blur(28px) saturate(1.4);
  border: 1px solid rgba(255, 255, 255, 0.08);
}
```

Use cases: bottom nav, modal headers, AI suggestion cards on photo backgrounds.

---

## 7. Component Library

### 7.1 Buttons

| Variant | Style | Use |
|---------|-------|-----|
| **Primary** | Solid brand orange + white text + shadow-glow | Main CTA |
| **Premium** | Gradient + sparkle animation | Subscribe |
| **Secondary** | Outline + neutral | Cancel, alt |
| **Ghost** | Text only | Tertiary |
| **Icon** | Circular 44px | Toolbar |
| **Floating** | Big rounded, with haptic | AI Decide (center nav) |

Sizes: sm (36), md (44), lg (52), xl (60).

### 7.2 Cards

**Food Card (large)** — used in card stack
```
┌─────────────────────────────────┐
│ [Hero image 16:9, ken-burns]    │
│                                 │
│  [Tag chip: Tự nấu]             │
├─────────────────────────────────┤
│  Bún bò Huế                     │
│  ⭐ 4.8 (1.2k) · 45k · 480 cal  │
│                                 │
│  "Trời mưa Hà Nội — món ấm      │
│   cho ngày se lạnh" — Hà ✨     │
├─────────────────────────────────┤
│  [Nấu]  [Đặt giao]  [Đi ăn]    │
└─────────────────────────────────┘
        ⬅ Skip      Save ➡
```

**Food Card (compact)** — used in feed lists
```
┌─────┬──────────────────────────┐
│ img │ Bánh canh cua            │
│ 80x │ 50k · 320 cal · ⭐ 4.7   │
│ 80  │ 600m · Quán Bà Hai       │
└─────┴──────────────────────────┘
```

**Story Card** (24h)
```
┌────────────────┐
│ ◯ avatar       │
│                │
│   [video.mp4]  │
│                │
│ "@Minh check-  │
│  in Phở Lý..." │
└────────────────┘
```

### 7.3 Form elements
- Text input: 52px height, 16px radius, focus = brand orange ring
- Slider: custom thumb (cam tròn + glow), labels animated above
- Chip: pill shape, selectable, multi-select group
- Toggle: iOS-style, brand orange when on
- Stepper: ±, large 44px tap area

### 7.4 Navigation

**Bottom Nav** (5 items, center is floating CTA)
```
┌───┬───┬─────────────┬───┬───┐
│Home Search [AI Decide]Social Profile
└───┴───┴─────────────┴───┴───┘
              ↑
       FAB-like, 60px,
       gradient glow,
       haptic on tap
```

**Tab bar** — sticky scroll, underline animation, swipe between

**Bottom sheet** — 3 snap points (peek 30%, half 60%, full 95%)

---

## 8. Motion & Animation

### 8.1 Motion Principles
1. **Origin** — UI bay ra từ điểm tap (avoid global fade)
2. **Spring-based** — không linear, dùng spring (mass 1, damping 18, stiffness 280)
3. **Choreographed** — stagger nhau (50ms delay giữa items)
4. **Purposeful** — mỗi animation kể câu chuyện ("đang nấu", "đang nghĩ")
5. **Respectful** — accessibility: reduce-motion fallback

### 8.2 Signature Animations

**A. Logo Bloom (splash)**
- 2 đũa lướt vào từ trái-phải
- Gặp nhau ở giữa → particle explosion → form chữ "Ăn"
- Duration: 1.4s

**B. AI Thinking ("Hà đang nghĩ")**
- 3 chấm tròn nhảy lò xo
- Background: gradient AI glow di chuyển radial
- Subtle "ssh" sound effect

**C. Card Swipe**
- Tilt + scale ratio theo drag x
- Trail glow (cam = like, đỏ = nope) ở mép màn hình
- Throw physics khi release

**D. Suggestion Reveal**
- Card flips từ phía sau với 3D perspective
- Image zooms từ blurred → sharp (200ms)
- Text typewriter (60ms/char) — như AI đang gõ

**E. Random Wheel**
- Spin 4–6 vòng + ease-out cubic-bezier(0.17, 0.67, 0.32, 1)
- Slow-mo cuối + confetti khi dừng
- Haptic burst on stop

**F. Mood Selector**
- 8 cảm xúc trên vòng tròn xoay
- Mỗi mood: emoji rung, gradient background shift
- "Mood is sticky" — chọn mood → bg cả app đổi theme tạm thời

**G. Group Voting Tally**
- Avatars bay vào "vote pot"
- Bar chart count-up
- Reveal winner: stage curtains effect

**H. Cooking Timer**
- Liquid fill animation
- Steam particles từ pot icon
- Subtle wobble

### 8.3 Micro-interactions (haptics)

| Action | Haptic | Sound |
|--------|--------|-------|
| Tap CTA | Light | Soft tick |
| Swipe right (like) | Medium | "Tinkle" |
| Swipe left (nope) | Soft | "Whoosh" |
| AI suggestion reveal | None | Magic "shimmer" |
| Streak +1 | Heavy + 2 light | "Ding!" |
| Order confirmed | Success notification | "Cha-ching" |
| Error | Warning | "Buzz" |

All sounds custom-designed, ≤ 200ms, optional toggle.

### 8.4 Tools
- **Lottie** — onboarding illustrations, badges
- **Rive** — interactive animations (mood wheel, random spinner)
- **Hero animations** — Flutter Hero / Framer Layout
- **Skia shaders** — premium glow effects

---

## 9. Screen-by-Screen Breakdown

### 9.1 Splash Screen
- 1.4s animation
- Dark mode aware (preserve battery)
- Preload: user profile, AI cache, weather
- If first-time: → Onboarding
- Else if logged out: → Login
- Else: → Home

---

### 9.2 Onboarding (8 screens, ≤60s total)

**S1: Hero Welcome**
- Animated illustration: tô phở khói nghi ngút
- Headline: "Đừng đắn đo nữa, Hà sẽ chọn cho bạn"
- Subhead: "AI hiểu khẩu vị, ngân sách, và cả tâm trạng bạn"
- CTA: "Bắt đầu" (gradient)

**S2: Notification permission** — soft sell + value prop
**S3: Location** — required, with privacy note
**S4: Allergies & diet** — chip multi-select
**S5: Budget** — slider with live preview
**S6: Foods I love** — grid 60 món, chọn ≥10
**S7: Foods I avoid** — grid same
**S8: All set!** — Food DNA reveal animation, then → Home

**Skip-able:** S2, S3 (with soft consequence shown later).

---

### 9.3 Login / Register
- **Login methods:** Phone OTP (primary), Apple, Google, Email
- Phone OTP: auto-detect VN format, 6-digit input auto-paste from SMS
- Biometric option after first login (FaceID/TouchID/Fingerprint)
- "Continue as guest" → limited features

---

### 9.4 Home AI Feed

```
┌──────────────────────────────────┐
│ ☰   Hôm Nay Ăn Gì?    🔔  👤    │  ← Header (glass when scroll)
├──────────────────────────────────┤
│ 🌧 28°C · Mưa nhẹ · Buổi trưa   │  ← Context strip
├──────────────────────────────────┤
│ [○][○][○][○][○][○][○][○]        │  ← Stories (24h food)
├──────────────────────────────────┤
│                                  │
│ 👋 Chào Thảo, đói chưa nè?      │
│                                  │
│ ╔══════════════════════════════╗ │
│ ║ Hà gợi ý                     ║ │
│ ║                              ║ │
│ ║ [Card stack — 5 cards]       ║ │
│ ║                              ║ │
│ ║ ⬅ skip   ❤️ save   ✨ chi tiết║│
│ ╚══════════════════════════════╝ │
│                                  │
│ ───  Đang trending quanh bạn  ─── │
│ [Horizontal scroll restaurants]   │
│                                  │
│ ───  Bạn bè đang ăn  ─── │
│ [Avatar + food check-in]         │
│                                  │
│ ───  TikTok món hot tuần  ─── │
│ [Video grid 2 cols]              │
└──────────────────────────────────┘
│ Home Search [✨AI] Social Profile │  ← Bottom nav
└──────────────────────────────────┘
```

**Behaviors:**
- Pull-to-refresh: AI re-generates suggestions ("Hà đang nghĩ...")
- Long-press card: preview modal with details
- Swipe up nav: AI Decide modal (peek)

---

### 9.5 AI Decide Modal (Flagship)

Mở từ center FAB hoặc swipe up từ home. Full-screen.

**Mode select tabs (top):**
- ⚡ Quick (default — 3 questions)
- 🎯 Detail (8 questions, slider + chips)
- 💖 Mood (mood wheel)
- 🎤 Voice (talk to Hà)
- 📷 Fridge (camera)
- 👥 Group (link share)

**Quick mode flow:**
1. **Đói mức nào?** Slider 1–10 with emoji
2. **Có bao nhiêu thời gian?** 4 chips (5/15/30/60+ min)
3. **Bao nhiêu tiền?** Slider 20k–500k
4. → **"Hà đang nghĩ..."** 1.8s (AI loading)
5. → **Card stack reveal** (5 cards)

**Detail mode** — adds: mood wheel, who with, diet, cuisine preference, energy level.

---

### 9.6 Card Stack (post AI suggest)

- 5 cards stacked, top visible
- Each card: hi-res photo, name, price/cal/time, AI reason, 3 actions
- **Swipe right:** save to "lưu sau" + positive signal
- **Swipe left:** dismiss + show "vì sao?" quick poll (too expensive/wrong cuisine/just no)
- **Swipe up:** full detail screen
- **Tap action button:** instant action (Nấu/Đặt/Đi)
- **Empty state after 5:** "Hết gợi ý rồi, vuốt xuống để re-roll" + Re-roll CTA

---

### 9.7 Food Detail Screen

```
┌──────────────────────────────────┐
│ ←        Bún bò Huế      🤍  ⋯  │
├──────────────────────────────────┤
│                                  │
│   [Parallax hero image 4:3]      │
│                                  │
├──────────────────────────────────┤
│ Bún bò Huế                       │
│ ⭐ 4.8 (1,234 reviews)            │
│                                  │
│ 50k đ · 480 cal · 30 phút        │
│                                  │
│ #cay #mặn #ấm #miềntrung         │
│                                  │
│ ── Tabs ─────────────────────────│
│ [Công thức] [Quán] [Bài viết] │
├──────────────────────────────────┤
│ Nguyên liệu (6 người)            │
│  • Bún sợi to    500g            │
│  • Thịt nạm bò   400g            │
│  ...                             │
│                                  │
│ Cách làm (8 bước)                │
│  1. Hầm xương bò 4 tiếng...      │
│  ...                             │
│                                  │
│ Video tutorial (TikTok embed)    │
└──────────────────────────────────┘
│  [Cook now]  [Order delivery]    │  ← sticky bottom
```

---

### 9.8 Restaurant Detail

- Hero photo carousel (5–8 photos)
- Info: address, phone, hours, price range
- Menu (categories tabs)
- Reviews (sort by recent / helpful / photos)
- Map preview (tap → full)
- CTAs: **Đi bộ / Xe / Đặt giao / Đặt bàn**
- Photos by users
- Similar restaurants

---

### 9.9 Fridge Scan Screen

```
┌──────────────────────────────────┐
│ ←  Quét tủ lạnh                  │
├──────────────────────────────────┤
│                                  │
│  ┌──────────────────────────┐    │
│  │                          │    │
│  │   [Camera viewfinder]    │    │
│  │                          │    │
│  │   ┌─AI scan overlay─┐    │    │
│  │   │                 │    │    │
│  │   └─────────────────┘    │    │
│  │                          │    │
│  └──────────────────────────┘    │
│                                  │
│  Tip: Mở tủ lạnh rộng,           │
│  giữ máy ngang.                  │
│                                  │
│  [📸 Chụp]   [🖼 Thư viện]      │
└──────────────────────────────────┘
```

**After scan:**
```
┌──────────────────────────────────┐
│  Đã tìm thấy 7 nguyên liệu      │
├──────────────────────────────────┤
│  ✅ Trứng (4 quả)                │
│  ✅ Cà chua (3 quả)              │
│  ✅ Hành lá                      │
│  ✅ Thịt heo (200g)              │
│  ⚠️ Đậu hũ (chắc chắn?)         │
│  ✅ Cải xanh                     │
│  ✅ Nấm hương                    │
│                                  │
│  [Thêm tay]                      │
├──────────────────────────────────┤
│  💡 Hà gợi ý 5 món:              │
│  • Trứng chiên cà chua           │
│  • Canh cải nấm                  │
│  • Heo xào cà chua               │
│  • Omelet rau                    │
│  • Trứng chưng đặt biệt          │
│                                  │
│  [Xem tất cả gợi ý]              │
└──────────────────────────────────┘
```

---

### 9.10 Mood Food

```
┌──────────────────────────────────┐
│         Bạn đang thấy?           │
├──────────────────────────────────┤
│                                  │
│        Animated mood wheel       │
│        ┌─────────────┐           │
│      😊   😢   😴   🤯           │
│      Vui  Buồn Mệt  Stress       │
│                                  │
│      😎   🥺   🌙   🎉           │
│     Chill Cô đơn Khuya Ăn mừng   │
│        └─────────────┘           │
│                                  │
│  Tap để chọn — bg sẽ đổi màu     │
├──────────────────────────────────┤
│  ↓ Sau khi chọn ↓                │
│                                  │
│  "Stress hả? Hà chọn 8 món       │
│   chữa lành cho bạn 💛"          │
│                                  │
│  [Card carousel — 8 món]         │
└──────────────────────────────────┘
```

---

### 9.11 Group Voting Screen

```
┌──────────────────────────────────┐
│ ←  Nhóm: "Anh em bóng đá"  ⚙️    │
├──────────────────────────────────┤
│ 5 thành viên · 3 đã vote         │
│                                  │
│ Đề xuất chung — sắp xếp theo vote│
│                                  │
│ ┌──────────────────────────┐     │
│ │ 🥇 Lẩu Thái Hồng Hà      │     │
│ │ 👥 👥 👥 — 3 votes       │     │
│ │ 90k/người · 1.2km        │     │
│ │ [Vote] [Bỏ vote]         │     │
│ └──────────────────────────┘     │
│ ┌──────────────────────────┐     │
│ │ 🥈 Bún chả Hương Liên    │     │
│ │ 👥 👥 — 2 votes          │     │
│ │ ...                      │     │
│ └──────────────────────────┘     │
│                                  │
│ [+ Đề xuất món của bạn]          │
│ [🎲 Random Wheel — 9 món]        │
│                                  │
│ Realtime status: 🟢 5/5 online   │
└──────────────────────────────────┘
```

When all voted → confetti reveal + "Đi ngay" CTA → Maps deeplink.

---

### 9.12 Random Wheel

- Full-screen spinner, 8–12 slots
- User shakes phone OR taps "Quay"
- Wheel spins 5–8 vòng + slow-mo finale
- Haptic burst + confetti
- Winner card flies in: "Đi ăn món này!"
- Options: "Quay lại" / "Đặt ngay" / "Chỉ đường"

---

### 9.13 Meal Planner

Week view, drag-and-drop cards into Breakfast / Lunch / Dinner / Snacks slots.
Side panel shows: total weekly calo, budget, grocery list auto-generated.

```
┌───────────────────────────────────────────┐
│  ←  Kế hoạch tuần   📅 16/11 - 22/11  ⋯  │
├───────────────────────────────────────────┤
│   Mon Tue Wed Thu Fri Sat Sun             │
│   ┌──┬──┬──┬──┬──┬──┬──┐                 │
│ B │  │  │  │  │  │  │  │  Sáng            │
│ L │  │🍜│  │  │  │  │  │  Trưa            │
│ D │🍲│  │🥗│  │  │  │  │  Tối            │
│ S │  │  │  │  │  │  │  │  Snack          │
│   └──┴──┴──┴──┴──┴──┴──┘                 │
│                                           │
│ Tổng tuần: 12,800 cal · 1.2M ₫           │
│ Macro: P 32% · C 48% · F 20%             │
│                                           │
│ [📋 Grocery list] [✨ AI plan tuần]       │
└───────────────────────────────────────────┘
```

---

### 9.14 Social Feed (TikTok-style vertical)

- Full-bleed vertical video
- Right side: ❤️ comment 🔖 share
- Bottom: @username + caption + món + quán tag
- Top: "Theo dõi" / "Khám phá" / "Bạn bè" tabs
- Swipe horizontal to switch tab while in video

---

### 9.15 Profile

```
┌──────────────────────────────────┐
│            [Cover photo]         │
│                                  │
│              ⊙                   │
│         [Avatar 88px]            │
│                                  │
│        Thảo Lê · 🦑 Mực          │
│        @thaole                   │
│        ⭐ Foodie tin cậy         │
│                                  │
│   124       8.2K       312       │
│  reviews  followers  following   │
│                                  │
│  [Theo dõi] [Nhắn tin] [⋯]      │
├──────────────────────────────────┤
│ Bio: "Tôi review thật. 🍜"       │
│                                  │
│ Tabs: [Grid] [Bookmarks] [Stats] │
│                                  │
│ [Photo grid of food/reviews]     │
└──────────────────────────────────┘
```

Stats tab: weekly recap, top cuisines, calo/budget trends (charts).

---

### 9.16 Voice Assistant UI

```
┌──────────────────────────────────┐
│ ←   Hà — trợ lý ẩm thực          │
├──────────────────────────────────┤
│                                  │
│      [Animated waveform orb]     │
│       (lavender → orange         │
│        gradient pulse)           │
│                                  │
│     "Hà đang nghe..."            │
│                                  │
│   ── Transcript live: ──         │
│   "Hôm nay ăn gì healthy         │
│    dưới sáu mươi nghìn?"         │
│                                  │
├──────────────────────────────────┤
│                                  │
│   Hà: "Bạn thử salad cá hồi      │
│        45k tại Saladbox          │
│        cách đây 600m không?"     │
│                                  │
│   [Xem] [Đặt giao] [Chỉ đường]  │
│                                  │
│   🎤 [Bấm để nói lại]            │
└──────────────────────────────────┘
```

- Always-listening mode (opt-in, with visible mic indicator)
- Hands-free conversation
- Vietnamese natural — Hà có cá tính (dí dỏm, hỏi lại khi mơ hồ)

---

### 9.17 Premium Subscription

```
┌──────────────────────────────────┐
│  ←                               │
│                                  │
│   ✨ HNAG+ — Hà cá nhân của bạn  │
│                                  │
│   [Animated premium card]        │
│                                  │
│   Unlock:                        │
│   ✓ AI không giới hạn            │
│   ✓ Meal plan cả tháng           │
│   ✓ Macro tracking + Apple Health│
│   ✓ Hà voice tùy chỉnh           │
│   ✓ Không quảng cáo              │
│   ✓ 1000+ công thức chef         │
│   ✓ Early access tính năng       │
│   ✓ Badge premium                │
│                                  │
│   ┌──────┬──────┬──────────┐     │
│   │1 năm │1 tháng│7 ngày   │     │
│   │399k  │ 49k  │free trial│     │
│   │MOST  │      │          │     │
│   │POPULAR│     │          │     │
│   └──────┴──────┴──────────┘     │
│                                  │
│   [Đăng ký HNAG+]                │
│                                  │
│   Hủy bất cứ lúc nào             │
└──────────────────────────────────┘
```

---

### 9.18 Notifications Center

- Categorized: AI / Social / Orders / Streaks / System
- Live activity inline (cooking timer, order tracking)
- Swipe to dismiss
- Group by day

---

### 9.19 Settings

- Account
- Privacy & Data
- AI personalization toggles
- Diet & Allergies (always editable)
- Notifications preferences
- Language: Tiếng Việt / English
- Appearance: Light / Dark / Auto / Late Night mode
- Voice settings (Hà accent: Bắc/Trung/Nam)
- Connected accounts: GrabFood, Shopee, Apple Health, Google Calendar
- About, ToS, Privacy Policy, Delete account

---

### 9.20 Search

- Sticky search bar (glass)
- Recents + trending searches
- Tabs: Tất cả / Món / Quán / Người / Recipes
- Voice search button
- AI-powered search ("món rẻ healthy cho buổi trưa")
- Visual search (upload food photo)

---

## 10. Empty States, Loading, Errors

### 10.1 Empty states (illustrated)
- "Chưa có gì để xem" với illustration cute (bowl trống đợi)
- CTA: "Khám phá ngay"

### 10.2 Loading
- Skeleton screens (not spinners) cho lists
- AI thinking: dotted waveform + "Hà đang nghĩ..."
- Image loading: blurhash → progressive

### 10.3 Errors
- Friendly Vietnamese: "Ối! Có gì đó không ổn, thử lại nhé"
- Retry button + report option
- Offline banner: "Bạn đang offline — Hà sẽ dùng dữ liệu cũ"

---

## 11. Dark Mode / Late Night Mode

**Dark mode:** thông thường, áp dụng cả ngày.

**Late Night Mode** (auto-activate 10pm–5am):
- Background gradient mauve (#1A1A40 → #4A1B5C)
- Reduced animations
- "Đêm khuya muộn — chỉ gợi món nhẹ + an toàn"
- Notifications muted by default

---

## 12. Accessibility & Localization

- All text in Vietnamese first, English secondary
- Future locales: Thai, Indonesian, Filipino (SEA expansion)
- VoiceOver labels Vietnamese
- High contrast mode option
- Reduce motion respects OS setting

---

## 13. Asset Pipeline

- **Image format:** AVIF (web), HEIC (iOS), WebP (Android)
- **Hero images:** 1080×1350 (4:5) min, 3x DPR
- **Lazy loading:** blurhash placeholder + LQIP
- **CDN:** Cloudflare R2 + Cloudflare Images for resize
- **Lottie:** export as .json, <100KB
- **Rive:** .riv binary, <50KB

---

## 14. Design Tools & Workflow

- **Figma** — primary, with Auto Layout 5.0
- **Variables:** semantic tokens synced to code via Tokens Studio
- **Component library:** versioned, in shared library
- **Prototyping:** Figma + Origami for complex motion
- **Handoff:** Dev Mode + Specs annotations + Code Connect
- **Design system docs:** Zeroheight

---
