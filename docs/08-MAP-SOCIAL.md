# 08 — Map System & Social Graph

> **Map = the canvas where food meets place.** Social graph = the multiplier on every decision.

---

## PART A — THE MAP SYSTEM

## 1. Map Philosophy

The map is not just **where restaurants are** — it's a **living, breathing organism** showing:
- Where food is **hot right now**
- Where **friends are eating**
- Where **trends are bubbling up**
- Where **deals are happening**

> **Inspiration:** Google Maps × Snapchat Snap Map × Strava heatmap × Yelp.
> **Vibe:** Cyberpunk Hanoi night, neon food pins glowing.

---

## 2. Map Visual Design

### 2.1 Base Map Style

**Custom Mapbox style** built on Mapbox Streets v12:

**Dark Mode (default at night):**
- Background: deep navy (#0B0F1E)
- Roads: subtle teal lines (#1F3A5F)
- Water: darker (#060912)
- Buildings: extruded 3D, low opacity
- Text: warm white with subtle glow

**Light Mode (day):**
- Background: warm cream (#FAF6F0)
- Roads: soft beige (#E5DDD0)
- Greenspace: muted sage (#C8D4B8)
- Buildings: 3D with subtle shadow

**Late Night Mode (10pm–5am):**
- Background: deep mauve (#1A1A40)
- Neon accents on hot restaurants
- Less detail, more atmosphere

### 2.2 Food Pin Types

```
┌───────────────────────────────────────────────┐
│  Pin Type        │  Visual                    │
├───────────────────────────────────────────────┤
│  🔥 Trending     │  Glowing orange, pulsing   │
│  ⭐ Top Rated     │  Gold star, steady         │
│  👥 Friend was   │  Friend avatar circular    │
│  🆕 New Open     │  Sparkle animation 7 days  │
│  💰 Deal         │  Yellow pulse + % badge    │
│  💎 Hidden Gem   │  Diamond shape, mysterious │
│  ⏰ Open Now      │  Green dot                 │
│  🚫 Closed       │  Greyed out                │
│  📺 Live Stream  │  Red dot + camera icon     │
│  🎯 AI Pick      │  Hà logo with shimmer      │
└───────────────────────────────────────────────┘
```

### 2.3 Pin Anatomy

```
        ╱╲
       ╱  ╲
      │ 🍜 │   ← Food category emoji
      │    │
       ╲  ╱
        \/
       ◯◯◯    ← Glow pulse if trending
       
   ↓ Tap to expand
       
   ┌───────────────────┐
   │ [tiny img preview]│
   │  Bún chả Bà Hai   │
   │  45k · ⭐ 4.8     │
   │  🟢 12 đang ăn    │
   │  [Card detail >]  │
   └───────────────────┘
```

---

## 3. Food Heatmap

### 3.1 Heatmap Layers

The map can be toggled into **heatmap mode** showing density of:

1. **🔥 Order Density (last hour)** — where people are ordering now
2. **⭐ Rating Heat** — concentrations of high-rated places
3. **💰 Deal Heat** — where promotions cluster
4. **👥 Friend Activity** — where friends have been (last 7 days)
5. **📈 Viral Heat** — where viral TikTok dishes are served
6. **🌶 Cuisine-specific** — toggle filter (only Vietnamese, only Korean...)

### 3.2 Heatmap Visual

- Gradient: deep purple (low) → orange → bright red (high)
- Updates every 15 min for "live" heatmap, otherwise 1h
- Smooth animation on layer toggle

### 3.3 Tech
- Mapbox heatmap layer
- Data source: Order events aggregated to H3 hexagons (resolution 10)
- Cached in Redis per (city, layer, time-bucket)

---

## 4. Trending Zones

> **Discoverable areas with concentrated food vibe.**

### 4.1 Auto-detected Food Zones

Algorithm clusters restaurants into named zones:
- **Phố Cô Giang Bà Hạt** — "Bún chả cá đậm chất Hà Nội"
- **Thái Phiên** — "Hồ con rùa coffee & dessert"
- **Bùi Viện** — "Western food + nightlife"
- **Vinhomes Central Park** — "Sang chảnh date night"

### 4.2 Zone Display
- Light-bordered polygons overlaid on map
- Zone name fade-in when zoom level appropriate
- Tap zone → bottom sheet with zone info:
  - Average price range
  - Top 5 restaurants
  - Best time to visit (less crowded)
  - Vibe tags

### 4.3 Zone Discovery
- "Find zones near me" filter
- Curated lists: "10 best food zones HCM"
- Editorial content team writes zone guides

---

## 5. Live Crowding & Status

### 5.1 Data Sources (multi-signal)

**Direct:**
- Restaurant partner API (POS integration with chains)
- Manual restaurant owner check-ins
- Reservation count from booking partners

**Inferred:**
- App users' check-ins (last 30 min)
- Photo upload timestamps near venue
- GPS dwell-time clustering (anonymized)
- Order rates from delivery partners

### 5.2 Crowdedness Indicators

```
On Restaurant Card:
🟢 Empty      (<30% capacity)
🟡 Vừa        (30-65%)
🟠 Đông       (65-90%)
🔴 Cực đông   (>90%, ~15 min chờ)
⏱ ~X phút chờ
```

### 5.3 Wait-time prediction

For popular places (chains, hotpot, brunch):
- ML model trained on historical (hour, day, weather, event) → wait time
- Surface in card: "Lý Quốc Sư · ~15 phút chờ"
- Notify when "Hết chỗ trống — đi sớm hơn 30 phút"

### 5.4 Live Open/Close

- Time-based open/close (with holiday overrides)
- "Closed today" detection from social posts
- User-reported "đã đóng cửa" with confirmation

---

## 6. AI Route Suggestions

### 6.1 The "Food Crawl" Mode

User: "Tôi muốn đi ăn dạo ở Q1 tối nay"

Hà generates a **route**:
1. 6:30pm — Appetizer at Quán A (snacks)
2. 7:30pm — Main at Quán B (bún chả)
3. 9:00pm — Dessert at Quán C (chè)
4. 10:00pm — Coffee at Quán D (view sông Sài Gòn)

Each step:
- Walking distance ≤ 800m between
- Time alignment with opening hours
- Budget split per stop
- Personalized to taste vector

### 6.2 Multi-stop Optimization

Solver: Traveling Salesman-like, constraints:
- Total time budget
- Total money budget
- Open hours alignment
- Cuisine diversity
- Walk vs Grab vs taxi cost-benefit

### 6.3 Visualization

```
[Map view with curved animated path]
[Stops numbered 1, 2, 3...]
[Time at each stop displayed]
[Total: 3h 30min · 280k · 1.2km walk]
[Share route] [Start guide]
```

### 6.4 "Live Companion" mode during the crawl
- At each stop: tap "Đã đến" → next directions
- Hà voice can guide: "Quán kế tiếp là Lý Quốc Sư, qua đường rẽ phải nhé"

---

## 7. Map Search & Filters

### 7.1 Filter Bar (sticky on map)

```
[Mở cửa ngay] [Trong tầm 1km] [Dưới 100k] [⭐4.5+] [Có deal] [Cuisine▼]
```

### 7.2 Advanced filters bottom sheet
- Distance slider
- Price range
- Cuisine multi-select
- Diet (vegetarian, halal...)
- Vibe (date, family, work...)
- Has parking, has wifi, has AC
- Has live stream
- Reservation available
- Group friendly
- Late open / early open

### 7.3 Saved Searches
- User can save filter combinations: "Late night quick"
- Quick toggle from header

---

## 8. Map Integration with Other Modules

### 8.1 From Card → Map
- "🗺" button on any card → opens map zoomed to that pin
- Pin highlights, surrounding context shown

### 8.2 From Map → Card
- Tap pin → card peek bottom sheet
- Swipe up → full card detail

### 8.3 Friends Layer
- See where friends have been (privacy controls!)
- Toggle on/off
- "Ăn thử quán Mai vừa check-in" prompt

### 8.4 Group Voting + Map
- During group voting, map view shows all 5 candidate locations
- Members can vote on map

---

## PART B — SOCIAL GRAPH ARCHITECTURE

## 9. Social Graph Model

### 9.1 Entities & Relationships

```
USER ──follows──→ USER          (asymmetric)
USER ──friends──→ USER          (symmetric, requires accept)
USER ──couple──→ USER           (1:1, mutual link)
USER ──member_of──→ GROUP       (many-to-many)
USER ──reviews──→ FOOD / RESTAURANT
USER ──checked_in──→ RESTAURANT
USER ──posts──→ POST (video/photo/review)
USER ──likes──→ POST / REVIEW
USER ──comments_on──→ POST
USER ──saves──→ FOOD / RESTAURANT / POST
USER ──blocked──→ USER          (one-way mute)
USER ──hosts──→ EVENT (food meetup, dinner party)
```

### 9.2 Graph Storage

**Hybrid approach:**
- **PostgreSQL** — for follows, friends, blocks (relational)
- **Neo4j (optional V2)** — for graph traversal queries ("friends of friends who like Korean")
- **Redis** — hot edges (recent follows, online status)
- **Kafka** — graph change events to recommendation pipeline

### 9.3 Privacy Tiers

User can set per dimension:

| Dimension | Public | Friends Only | Private | Off |
|-----------|--------|--------------|---------|-----|
| Profile | • | | | |
| Saves | | • | | |
| Order history | | | • | |
| Location | | • | | |
| Mood | | | • | |
| Reviews | • | | | |
| Couple status | | • | | |

Default for new users: **Friends Only** for most, public for reviews.

---

## 10. Social Feed Algorithm

### 10.1 Feed Sources

Per user, blended feed from:
- **Following** — posts from people they follow
- **Friends** — posts from accepted friends
- **For You** — algorithmic personalized
- **Nearby** — recent posts in user's area
- **Trending** — globally hot

### 10.2 Ranking Signals

```python
def score_post(post, user, context):
    # Relevance
    cuisine_match = cosine(post.food_emb, user.taste_emb)
    
    # Recency (newer = better)
    age_h = (now - post.created).hours
    recency = exp(-age_h / 24)
    
    # Engagement velocity
    velocity = post.likes_recent_1h / max(post.age_h, 0.5)
    
    # Affinity
    creator_aff = follow_strength(user, post.author)
    
    # Locality
    distance_km = haversine(user.loc, post.geo)
    locality = exp(-distance_km / 5)
    
    # Diversity injection
    if same_cuisine_recent(post, user):
        diversity_penalty = 0.8
    else:
        diversity_penalty = 1.0
    
    # Final
    return (
        cuisine_match * 0.30 +
        recency * 0.20 +
        velocity * 0.15 +
        creator_aff * 0.15 +
        locality * 0.10 +
        post.quality_score * 0.10
    ) * diversity_penalty
```

### 10.3 Anti-bubble Mechanics
- Inject 1 random "Khám phá" post per 5 (different cuisine)
- "Hidden gems" boost for posts about <100-rating restaurants
- "Theo dõi gợi ý" — suggest follow new creators outside echo chamber

---

## 11. Stories System (24h ephemeral)

### 11.1 Story Types
- 📸 Photo + caption
- 🎥 Video (3–15s)
- 📍 Check-in only
- 🍜 Food tag only (quick share)
- 💬 Text reaction
- 🗳 Poll (which to eat? friends vote)

### 11.2 Story Mechanics
- 24h TTL
- View count visible
- Replies → DM
- Boost option (premium)
- Memories archive (premium)

### 11.3 Story Discovery Layer
- Story bar on home feed (top)
- Friends' stories first, then suggested
- Map view: stories pinned to location

---

## 12. Creator Economy

### 12.1 Creator Levels

| Tier | Followers | Reviews | Perks |
|------|-----------|---------|-------|
| 🥉 Bronze | 1K | 30 verified | Verified badge, basic analytics |
| 🥈 Silver | 10K | 100 | Free premium, KOC marketplace access, monthly stipend $50 |
| 🥇 Gold | 50K | 500 | Brand campaigns, $300/mo retainer, exclusive deals |
| 💎 Diamond | 200K | 1500 | Equity stipend, top promo, brand ambassador |

### 12.2 Monetization for Creators

**A. Sponsored posts**
- Pay-per-view (CPM) for branded content
- Restaurant promo (revenue share with HNAG)

**B. Tips & Gifts**
- Live food streams (cooking) — viewers send virtual gifts
- Profile tip jar (premium)

**C. Affiliate commissions**
- Every order from their content → 5–10% to creator
- Tracked via deep links

**D. Subscription**
- Creator can offer "Pro fans only" content (5k/month)
- HNAG takes 20% cut

### 12.3 Creator Dashboard

```
┌────────────────────────────────────────────────┐
│ Bảng điều khiển Creator                        │
├────────────────────────────────────────────────┤
│ 👥 Followers   📈 +12% tuần                   │
│ 📺 Views      245K tuần                       │
│ 💰 Earnings   2.4M ₫ tháng                     │
│                                                │
│ ── Recent Posts (table) ──                     │
│ Post · Views · Likes · Saves · Earnings        │
│                                                │
│ ── Brand campaigns ──                          │
│ • Highlands campaign $400 due 30/11           │
│ • Knorr cooking series $1.2K                  │
│                                                │
│ ── Audience Insights ──                        │
│ Age, gender, cities, top interests             │
└────────────────────────────────────────────────┘
```

### 12.4 Anti-spam / Quality Control
- KOC code of conduct
- Auto-flag for fake engagement
- 3 strikes → demoted tier
- Review by community team for high-stakes flags

---

## 13. Check-ins & Verified Activity

### 13.1 Check-in Flow
1. User at restaurant (GPS verified)
2. Tap "Check-in" button (auto-prompted)
3. Optional: post photo + review
4. Earns XP + Foodie credit
5. Shows up on profile, feed, map (friend visibility)

### 13.2 Verified Reviews

A review is "verified" if:
- User checked in at the location (GPS confirmed), OR
- Confirmed order via partner API, OR
- Photo metadata matches venue

Verified reviews:
- Have ✓ badge
- Weight higher in restaurant rating
- Eligible for monetization (tips, ad share)

---

## 14. Couple Mode (Deep Feature)

### 14.1 Pairing
- 2 users invite each other
- Link approved → "Couple" relationship in DB
- Optional anniversary date stored

### 14.2 Shared Features
- **Shared taste vector** — recommendations match both
- **Date Night Wizard** — Hà plans the date (restaurant + flow + budget)
- **Memory Book** — auto-archives all places visited together
- **Couple stats** — total places, top cuisine, anniversary recap
- **Notification sync** — partner ate something? You can see (consent)

### 14.3 Couple UX touches
- Specific badges (paired emojis on profile)
- "What we ate today" shared journal
- Anniversary reminders ("1 năm trước, các bạn ăn lẩu Bà Hai")
- Date night countdown widget

### 14.4 Break-up Flow (sensitive)
- Either party can dissolve
- 7-day cooldown
- Optional: archive memory book or delete
- No notification spam to ex (privacy)

---

## 15. Group System

### 15.1 Group Types
- **Bữa Ăn Nhanh** — ad-hoc, ephemeral (24h)
- **Crew Permanent** — best friend group, persistent
- **Family** — family members, special features
- **Office** — work lunch group with admin
- **Event** — dinner party, RSVP, food planning

### 15.2 Group Features
- Voting (Engine #4)
- Group chat (light, food-context)
- Shared bookmark list ("Quán muốn thử")
- Spending split tracker
- Anniversary / recurring meals reminders

### 15.3 Group Discovery
- Suggest groups based on social graph
- "Anh em đi ăn Q1" auto-suggested if many followed friends in that area

---

## 16. Food Challenges & Competitions

### 16.1 Challenge Types

**Self-challenges:**
- "Ăn 5 quán phở khác nhau trong tháng"
- "Cook 7 món healthy / tuần"
- "Visit 10 hidden gems"

**Community challenges:**
- "Tháng 10: Bún Bò Marathon" — most reviews of bún bò
- "Khám phá Đà Nẵng" — leaderboard for visiting Đà Nẵng restaurants

**Branded challenges:**
- "Knorr presents: Cook with chicken stock" — recipe contest
- Prize: vouchers, premium, brand swag

### 16.2 Mechanics
- Join button on challenge card
- Progress bar
- Leaderboard
- Badge on completion
- Optional prize redemption

---

## 17. Anti-toxicity & Moderation

### 17.1 Auto-moderation
- AI classifier for: hate speech, harassment, spam, fake review patterns
- Vietnamese-tuned (Mediabar/local services + custom)
- Image moderation: no nudity, no gore (food can be visceral, define gracefully)

### 17.2 User Reporting
- 1-tap report on any content
- Categories: spam, fake, offensive, dangerous, wrong location
- Review SLA: 1h for high severity, 24h for low

### 17.3 Community Standards
- Published, multilingual
- Strikes system (3 strikes = ban)
- Appeal process

### 17.4 Fake Review Detection
- Behavioral patterns (review velocity, similar text)
- Network analysis (cluster of new accounts reviewing same place)
- Restaurant-side flagging
- Auto-quarantine until verified

---

## 18. Push Notifications — Social

| Trigger | Push |
|---------|------|
| Friend posted | "Mai vừa review Phở Lý Quốc Sư 🍜" |
| Friend liked your post | "Khoa thích bài đăng của bạn" |
| Mentioned in comment | "@bạn được nhắc trong 1 bình luận" |
| Group invited | "Thảo mời bạn vào nhóm 'Anh em đi ăn'" |
| Vote pending | "3 người chờ vote — bạn thì sao?" |
| Story 1h before expire | "Story của bạn sắp hết" |
| Couple ping | "Bạn đang ăn gì? — anniversary 7 tháng 💕" |
| Challenge progress | "Còn 2 quán nữa hoàn thành thử thách" |

Frequency cap: 5/day per user across all categories.

---

## 19. Privacy Architecture

### 19.1 Granular Settings

```yaml
privacy:
  profile_visibility: public | friends | private
  show_real_name: true/false
  show_location_on_map: precise | district | off
  show_eating_now: friends_only | off
  show_history_to_friends: true/false
  allow_search_by_phone: true/false
  story_visibility: public | friends | close_friends
  recommendation_use_friends: true/false
  dms_open: anyone | friends | off
```

### 19.2 Block & Mute
- Block: user can't see your content + can't message
- Mute: still allowed but you don't see them
- Restrict: their content needs your approval (Insta-style)

### 19.3 Data Export & Delete
- Self-service: download all my data (zip JSON + media)
- Delete account: 30-day soft delete, then hard
- GDPR-style rights

---

## 20. Real-time Activity Indicators

### 20.1 "Đang ăn" pulse
On profile or feed: "Mai đang ăn 🍜 tại Phở Lý Quốc Sư · 5 phút trước"

### 20.2 "Đang quyết" status
When user is in AI Decide flow, optional broadcast: "Khoa đang quyết ăn gì..."

### 20.3 Live cooking
User can broadcast "Đang nấu" → followers can drop in (Premium V2)

### 20.4 Privacy
All these are opt-in. Default OFF for new users.

---

## 21. Social Graph Recommendation Signals

The social graph feeds back into recommendations:

```python
def social_boost(food, user):
    boost = 0
    for friend in user.friends:
        if friend.has_eaten(food) and friend.rating(food) >= 4:
            boost += 0.05
        if friend.has_saved(food):
            boost += 0.02
        if same_couple_history(user, friend, food):
            boost += 0.10
    
    # Couple's choices doubly weighted
    if user.couple_partner.has_eaten(food):
        boost += 0.15
    
    return min(boost, 0.4)  # cap
```

This makes social one of the strongest signals when present.

---

## 22. Map Performance & Scale

### 22.1 Performance Targets
- Map initial load: <1.2s on 4G
- Pan/zoom: 60 FPS
- Pin clustering: smooth up to 5000 pins on screen
- Heatmap render: <300ms

### 22.2 Caching
- Tile cache: Cloudflare edge
- Pin data: Redis per (city, layer, filters)
- Heatmap: pre-computed per 15-min bucket
- User personalized pins: client-side cache 5 min

### 22.3 Scale architecture
- H3 indexing for spatial queries (Uber's library)
- PostGIS for restaurant geo
- Tile server: Tegola or Vector Tiles directly from Mapbox

---

## 23. Map Future (V2+)

- **AR Map** — point phone, see floating restaurant info overlaid
- **3D city** — flyover food zones
- **Time travel** — see how zone has evolved (year over year)
- **Predicted "vibe" forecast** — "Tonight District 1 will be packed"
- **Vehicle integration** — CarPlay / Android Auto

---
