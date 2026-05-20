# 01 — Product Concept & Features

> **Mission:** Trở thành "Spotify cho ẩm thực Việt Nam" — nơi mọi quyết định ăn uống đều bắt đầu.

---

## 1. North Star Metric

> **DAU × Decisions-per-User × Conversion-to-Action**

Cụ thể: số **"hành động được kích hoạt"** mỗi ngày (đặt món, nấu món, lưu công thức, check-in quán). Year 1 target: **600K daily decisions**.

---

## 2. User Personas

### 🎓 Persona 1 — "Minh" (Gen Z student, 21)
- Sống ở TP.HCM, ngân sách 50k–80k/bữa
- Quyết định ăn gì dựa trên TikTok trend
- Cần: rẻ, viral, đẹp để post story
- **Triggers:** food challenges, group voting với bạn

### 💼 Persona 2 — "Thảo" (Office worker, 28)
- Lương 18M, đặt giao 5 lần/tuần
- Muốn ăn healthy, lười nấu
- Cần: gợi ý nhanh trong 10s, ăn lành mạnh
- **Triggers:** meal plan, calorie tracking, lưu lịch sử

### 👨‍👩‍👧 Persona 3 — "Anh Hùng" (Father, 38)
- 2 con, vợ làm tối
- Phải nấu ăn cho gia đình
- Cần: công thức theo nguyên liệu sẵn, ngân sách gia đình
- **Triggers:** fridge scan, meal planner cho cả nhà

### 💕 Persona 4 — "Linh & Bạn trai" (Couples)
- Hẹn hò cuối tuần, đi ăn ngoài
- Mâu thuẫn "anh chọn đi" — "em chọn đi"
- Cần: group decision tool, gợi ý quán hợp 2 người
- **Triggers:** couple voting, random wheel

### 🏃 Persona 5 — "Khoa" (Fitness, 25)
- Tập gym, eat clean
- Cần macro tracking, gợi ý theo mục tiêu (cut/bulk)
- **Triggers:** premium subscription, Apple Health sync

---

## 3. Full Feature List (MoSCoW)

### 🔥 MUST HAVE (MVP — Month 0–3)

#### 3.1 AI Food Recommender
**Input:**
- Cảm giác đói (slider 1–10)
- Tâm trạng (chips: vui, buồn, stress, chill, cô đơn, lười)
- Ngân sách (slider: 20k → 500k)
- Thời gian có (5min / 15min / 30min / 1h+)
- Vị trí (GPS auto)
- Diet mode (none / low-carb / vegetarian / vegan / halal / pescatarian)
- Người ăn cùng (1 người / cặp / nhóm bạn / gia đình)

**Output (Smart Card stack — vuốt như Tinder):**
- Tên món + ảnh hi-res
- Tag: "Tự nấu" / "Đặt giao" / "Đi ăn"
- Giá ước tính
- Calo + macro
- Thời gian chuẩn bị
- Lý do AI chọn ("Trời mưa Hà Nội → cháo gà giải cảm")
- 3 hành động: **Nấu / Đặt / Đi ăn**
- Swipe trái = không thích (negative feedback)
- Swipe phải = lưu (positive)
- Vuốt lên = chi tiết
- Vuốt xuống = "lát tính"

**AI logic:**
- Context features: weather API, time of day, day of week, last 7 meals
- Collaborative filtering: users tương tự
- Constraint satisfaction: budget + time + diet
- Diversity penalty: không gợi món vừa ăn

#### 3.2 AI Fridge Scan
- Mở camera, chụp tủ lạnh hoặc nguyên liệu rời
- Vision model nhận diện ≥150 loại nguyên liệu Việt (rau muống, thịt ba chỉ, cá nục, đậu hũ...)
- Confidence threshold + user confirm (chips bật/tắt)
- AI generate 3–5 recipes có thể nấu
- Tag "thiếu gì": "Cần thêm hành tím + nước mắm"
- Tích hợp với GrabMart/BachhoaXANH để mua thiếu

#### 3.3 AI Mood Food
- Mood Wheel (8 cảm xúc, animated)
- Time-of-day overlay (sáng/trưa/tối/đêm khuya)
- Cultural mapping:
  - **Buồn + đêm** → mì cay, đồ ngọt, cháo
  - **Stress** → snack, trà sữa, lẩu
  - **Chill cuối tuần** → bún bò, phở, brunch
  - **Thức khuya** → mì gói cải tiến, bánh mì
- Mỗi mood có "playlist" 12 món + ảnh aesthetic

#### 3.4 Onboarding & Profile
- Sign up: phone OTP (Vietnamese phone first), Google, Apple
- 60-second onboarding:
  1. Avatar (chọn cute illustration)
  2. Allergies (chips: tôm, đậu phộng, gluten, lactose...)
  3. Diet preference
  4. Budget range/tháng
  5. Foods you love (chọn 10 từ grid 60 món VN)
  6. Foods you hate
  7. Cook frequency (never / weekend / daily)
- Generates initial **Food DNA** profile

#### 3.5 Home AI Feed
- Personalized feed of:
  - "Hôm nay gợi ý cho bạn" — 5 món AI chọn
  - "Đang trending khu vực" — món hot quanh 3km
  - "Bạn bè đang ăn" — social proof
  - "TikTok món hot tuần" — embedded short videos
- Pull-to-refresh = AI re-roll
- Stories bar trên cùng (món ăn 24h)

#### 3.6 Restaurant Map
- Map view (Mapbox custom style)
- Filters: distance, rating, price ($/$$/$$$), category
- Card preview on tap
- "Open now" indicator
- Link to GrabFood/ShopeeFood/beFood deeplink
- Đặt bàn (qua TableNow API hoặc gọi điện)

### 🚀 SHOULD HAVE (Month 4–6)

#### 3.7 Group Voting
- Tạo "Bữa ăn nhóm" → link share
- Mỗi người chọn 3 món yêu thích
- AI tìm intersection + similarity → top 5
- Real-time voting (WebSocket)
- Animation: vote → confetti → reveal
- Mini-game: Random Wheel (gamified spinner)

#### 3.8 Social Feed (TikTok-style)
- Vertical video feed của món ăn
- Reviews + tutorials
- Like, comment, share, save
- Follow creators
- "Đang ở đâu" check-in badge
- Story (24h) với food sticker

#### 3.9 Meal Planner
- Weekly calendar view
- Drag món vào ngày/bữa
- Auto-generate grocery list
- Calorie + budget weekly summary
- Sync với Google Calendar / Apple Reminders

#### 3.10 AI Voice Assistant ("Hà")
- Wake word: "Hey Hà"
- Vietnamese ASR (Whisper fine-tuned + VinAI ASR fallback)
- Use cases:
  - "Hôm nay ăn gì?"
  - "Đặt giùm phở Lý Quốc Sư"
  - "Có gì healthy dưới 60k?"
  - "Nhắc ăn tối lúc 7h"
- Voice replies in natural Vietnamese (TTS via VBee or ElevenLabs Vietnamese)

### 🎯 COULD HAVE (Month 7–12)

#### 3.11 Premium Subscription ("HNAG+")
- 49k/tháng hoặc 399k/năm
- Unlocks:
  - Unlimited AI suggestions (free: 10/ngày)
  - Advanced meal planner (cả tháng)
  - Macro/nutrition tracking + Apple Health sync
  - Personalized AI coach voice
  - No ads
  - Exclusive recipe library (1000+ chef recipes)
  - Early access tính năng mới
  - Badge premium trên profile

#### 3.12 Foodie Profile & Gamification
- Profile public: bio, món yêu thích, số reviews, followers
- **Foodie Levels**: Tép → Tôm → Cua → Mực → Cá Mập → Rồng
- **Badges:** "Vua Phở", "Thám Hiểm Khu 1", "100 quán/tháng", "Reviewer Tin Cậy"
- Streak: ngày liên tục mở app
- Daily quests: "Thử 1 món mới", "Review 1 quán"

#### 3.13 Live Cooking Mode
- Step-by-step recipe với timer, voice instruction
- Hands-free (voice nav: "tiếp theo", "lặp lại")
- Tích hợp với HomeKit/Google Home (chế độ rảnh tay)
- Smart Watch companion

#### 3.14 Couple Mode
- Link 2 tài khoản (như Spotify Duo)
- "Bữa nay 2 đứa" → AI gợi món hợp khẩu vị cả 2
- Lịch sử ăn cùng nhau
- Memory book: "Một năm trước, chúng ta ăn lẩu Bà Hai"

### 🌟 WON'T HAVE (V1)
- AI chef robot integration (V2)
- Crypto rewards (V3)
- AR menu overlay (V2)
- B2B for restaurants (separate product line)

---

## 4. UX Flow — Master Diagram

```
┌─────────────────┐
│ Splash Screen   │ (1.5s — logo morph animation)
└────────┬────────┘
         ↓
    [First time?]
       /     \
     Yes      No
     ↓         ↓
┌────────┐ ┌──────────────┐
│Onboard │ │  Auth (FaceID│
│  60s   │ │  /biometrics)│
└────┬───┘ └──────┬───────┘
     ↓            ↓
     └─────┬──────┘
           ↓
   ┌───────────────────┐
   │   HOME AI FEED    │← Bottom Nav
   │                   │
   │  [Stories Bar]    │
   │  [AI Suggestions] │
   │  [Trending Near]  │
   │  [Friends Eating] │
   │  [TikTok Trend]   │
   └────────┬──────────┘
            ↓
        Bottom Nav: Home | Search | [+ AI Decide] | Social | Profile
                                          ↓
                                  ┌──────────────────┐
                                  │ AI DECIDE MODAL  │
                                  │ (full screen)    │
                                  │                  │
                                  │ Mode select:     │
                                  │ Quick / Detail / │
                                  │ Mood / Voice /   │
                                  │ Fridge / Group   │
                                  └────────┬─────────┘
                                           ↓
                                  ┌──────────────────┐
                                  │ Card Stack       │
                                  │ (swipeable)      │
                                  │                  │
                                  │ ⬅ skip   like ➡  │
                                  │ ⬆ details ⬇ later│
                                  └──────────────────┘
```

---

## 5. Detailed User Journey — "Ngày của Thảo"

| Time | Event | App interaction | AI signal |
|------|-------|-----------------|-----------|
| 7:30 AM | Wake up | Push: "Sáng nay trời lạnh, phở 35k gần nhà?" | weather + hour + history |
| 8:00 AM | Đặt phở qua GrabFood deeplink | Tap "Đặt giao" → tracking link | conversion logged |
| 12:00 PM | Lunch break | Open app → AI Decide → Quick → 3 cards | constraint: budget 70k, time 30min |
| 12:05 PM | Swipe right "Cơm gà Hải Nam" | Map → Đi bộ 200m | location action |
| 7:00 PM | About to cook | Fridge Scan → "Còn cà chua, trứng, hành" | vision → "Trứng chiên cà chua" |
| 7:30 PM | Cooking | Live Cooking Mode (voice) | engagement: 15min |
| 9:00 PM | Scroll feed | TikTok-style food feed → save 3 recipes | content engagement |
| 10:30 PM | Snack craving | Mood Food → "Stress" → cup mì trứng | mood→food mapping |

**Engagement total:** 8 touchpoints, ~22 minutes in app, 2 conversions (orders).

---

## 6. Gamification System

### 6.1 Progression
| Level | Name | Requirement |
|-------|------|-------------|
| 1 | 🦐 Tép | Sign up |
| 2 | 🍤 Tôm | 10 món đã thử |
| 3 | 🦀 Cua | 50 món + 10 reviews |
| 4 | 🦑 Mực | 200 món + 50 reviews + 100 followers |
| 5 | 🦈 Cá Mập | 500 món + 200 reviews + verified |
| 6 | 🐉 Rồng | Top 100 reviewer / 6 months |

### 6.2 Streaks
- 🔥 "Daily Decide" streak — mỗi ngày mở AI Decide
- 🍳 "Cook week" streak — 7 ngày nấu liên tục
- 🌟 Streak rewards: badge, discount partners, premium days

### 6.3 Quests (Daily / Weekly)
- "Khám phá": Thử 1 món chưa từng ăn
- "Foodie": Review 1 quán
- "Social": Vote trong 1 group voting
- "Healthy": Ăn ≥ 1 món rau hôm nay
- "Budget": Giữ tổng chi tiêu ngày < target

### 6.4 Badges (250+ badges)
- "Vua Phở" — review 30 quán phở
- "Thám Hiểm Quận 1" — check-in 50 quán/quận
- "Đêm Khuya" — order sau 11h x 10 lần
- "Couple Goal" — 1 năm cùng partner trên app

### 6.5 Leaderboard
- Top reviewer tuần / tháng / năm
- Top khu vực (theo quận)
- Top creator video
- Prize: voucher partners, badges, verified

---

## 7. Notification System Strategy

**3 tầng:**

### 7.1 Push (FCM/APNs)
- **Smart timing:** ML predict thời điểm user open (10:45 AM, 5:30 PM, 9 PM)
- **Personalized copy:** AI-generated, Vietnamese natural
- Max 3 push/ngày (anti-fatigue)
- Categories:
  - Suggestion ("Trời mưa, lẩu nhé?")
  - Social ("Hà vừa review món bạn save")
  - Streak ("Còn 30 phút giữ streak 12 ngày!")
  - Order tracking
  - Friend invite

### 7.2 In-app
- Story bar on home
- Notification center (heart icon)
- Live activity (cooking timer)
- Realtime group voting

### 7.3 Email/Zalo
- Weekly recap ("Bạn đã thử 12 món tuần này, tiết kiệm 240k so với tháng trước")
- Onboarding sequence

---

## 8. Notification Copy Examples (Vietnamese, tone Gen Z)

- "Bụng đói rồi đó 😋 Có 3 món healthy dưới 60k gần bạn nè"
- "Hà ơi, trời đang mưa to 🌧 Phở Lý Quốc Sư 200m thôi nha"
- "Stress phải không? Mở app, có món chữa lành đợi bạn 💛"
- "Bạn Mai vừa review quán bạn save! Xem ngay 👀"
- "🔥 Streak 12 ngày — đừng để rớt! Mở AI Decide nha"
- "🥚 Còn trứng + cà chua trong tủ? Đây là 3 cách nấu sang chảnh"

---

## 9. Onboarding "Food DNA" (Deep dive)

Mục tiêu: trong 60 giây, AI hiểu user đủ để cá nhân hóa từ session đầu.

### 9.1 Câu hỏi
1. **Tên bạn?** (skip-able)
2. **Bạn bao nhiêu tuổi?** (range chip)
3. **Bạn sống ở đâu?** (auto GPS + confirm)
4. **Bạn dị ứng gì?** (multi-select)
5. **Bạn ăn chay không?** (radio: không / chay trường / chay kỳ / pescatarian)
6. **Ngân sách ăn / ngày?** (slider 50k–500k)
7. **Bạn có nấu ăn không?** (never / cuối tuần / hàng ngày)
8. **Chọn 10 món bạn YÊU** (grid 60 món VN — visual)
9. **Chọn 5 món bạn KHÔNG ăn** (same grid)
10. **Mục tiêu sức khỏe?** (chips: giảm cân / tăng cân / giữ dáng / khỏe / không quan tâm)

### 9.2 Output: Food DNA profile
```json
{
  "user_id": "u_123",
  "food_dna": {
    "cuisine_preference": ["vietnamese:0.8", "korean:0.6", "japanese:0.4"],
    "flavor_profile": {"spicy": 0.7, "sweet": 0.3, "umami": 0.9},
    "diet_tags": ["high_protein"],
    "budget_per_meal": {"min": 30000, "max": 80000, "avg": 55000},
    "allergies": ["peanut"],
    "cook_skill": "intermediate",
    "goal": "maintain_weight",
    "embeddings": [0.12, -0.04, ...] // 1536-dim
  }
}
```

Profile được cập nhật mỗi tuần dựa trên hành vi thực tế (implicit feedback).

---

## 10. Edge Cases & Edge UX

| Case | Behavior |
|------|----------|
| Không có internet | Cache last 20 suggestions, queue actions để sync |
| GPS off | Default theo địa chỉ saved hoặc IP, prompt enable |
| Out of budget AI suggestions | Auto-relax constraints với explanation |
| User dị ứng | HARD constraint — không bao giờ gợi món có allergen |
| Tỉnh không có quán | Fallback sang công thức tự nấu + grocery delivery |
| Đêm khuya (>11pm) | Mode "Late Night" — UI tối hơn, gợi món nhẹ |
| Ramadan (Halal users) | Auto-detect, only show halal restaurants |
| Tết / Lễ | Curated content, recipes truyền thống |

---

## 11. Accessibility (WCAG AA+)

- **Color contrast:** 4.5:1 minimum
- **Dynamic type:** support hệ thống font size
- **Voice control:** full app navigable bằng voice (đặc biệt cho người khiếm thị)
- **Reduced motion:** tắt parallax/spring animations khi user request
- **Screen reader:** semantic labels Vietnamese cho VoiceOver/TalkBack
- **Color blind safe:** không dùng red/green làm signal đơn lẻ

---
