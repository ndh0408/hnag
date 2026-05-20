# 07 — AI Engines Deep Dive

> **Thesis:** Có 5 AI engines độc lập, mỗi engine là một moat riêng. Combined → unbeatable.

```
                  ┌───────────────────────────┐
                  │   AI ORCHESTRATOR (Hà)    │
                  │   Routes & combines       │
                  └────────────┬──────────────┘
            ┌──────┬───────────┼──────────┬──────────┐
            ↓      ↓           ↓          ↓          ↓
       ┌────────┐ ┌──────┐ ┌──────┐ ┌──────────┐ ┌────────┐
       │ Taste  │ │ Mood │ │Viral │ │  Social  │ │ Fridge │
       │ Memory │ │Engine│ │Engine│ │ Matching │ │ Vision │
       └────────┘ └──────┘ └──────┘ └──────────┘ └────────┘
```

---

## 1. AI Engine #1 — Taste Memory

> **What it does:** Builds a *living model* of each user's evolving palate across 12 dimensions, updated in real-time from every interaction.

### 1.1 What it learns

| Dimension | Signal source | Update freq |
|-----------|---------------|-------------|
| **Cuisine affinity** | view, save, order, dine | Per event |
| **Spice tolerance** | rating + skip on spicy dishes | Per event |
| **Sweet/savory balance** | order patterns | Daily |
| **Texture preference** | (crunchy/soft/chewy) — implicit from saves | Daily |
| **Price sensitivity** | budget vs actual order amount | Per order |
| **Time-of-day patterns** | when user opens app + orders | Hourly |
| **Day-of-week patterns** | weekday vs weekend choices | Daily |
| **Weather affinity** | meal type vs weather correlation | Daily |
| **Social context** | what they pick alone vs group | Per group event |
| **Mood-food map** | mood tag + ate-after pairs | Per mood pick |
| **Restaurant loyalty** | repeat visits per restaurant | Per visit |
| **Novelty appetite** | new vs familiar food ratio | Weekly |

### 1.2 Taste Vector Representation

```python
# 256-dim user taste embedding
user_taste = {
  "embedding_v": [0.12, -0.04, 0.81, ...],  # 256 float
  "interpretable_dims": {
    "cuisine_vietnamese": 0.92,
    "cuisine_korean": 0.71,
    "cuisine_japanese": 0.45,
    "flavor_spicy": 0.78,
    "flavor_sweet": 0.34,
    "flavor_umami": 0.89,
    "price_range_mean": 65000,
    "price_range_std": 22000,
    "novelty_score": 0.41,  # 0=conservative, 1=adventurous
    "social_eater": 0.62,
    "health_conscious": 0.58,
    "late_night_index": 0.31,
    ...
  },
  "trajectory_30d": {  # rolling 30-day momentum
    "korean_trend": +0.15,  # learning to love Korean
    "spicy_trend": -0.05,
  }
}
```

### 1.3 Update Algorithm (Online Learning)

```python
# Pseudocode — runs on Kafka stream consumer
def on_food_interaction(event):
    user = load_user_taste(event.user_id)
    food = load_food_embedding(event.food_id)
    
    # Signal strength
    weight = {
      "viewed":   0.05,
      "saved":    0.20,
      "ordered":  0.50,
      "cooked":   0.40,
      "ate":      0.60,   # confirmed
      "rated_5":  0.80,
      "skipped":  -0.10,
      "rated_1":  -0.50,
    }[event.action]
    
    # Update embedding (exponential moving average)
    alpha = 0.05 * abs(weight)
    direction = sign(weight)
    user.embedding_v = (1-alpha) * user.embedding_v + alpha * direction * food.embedding_v
    
    # Update interpretable dims
    update_interpretable(user, food, weight)
    
    # Update trajectory
    track_trajectory(user, event)
    
    save_user_taste(user)
    publish_to_redis(user.id, user)  # for live ranking
```

### 1.4 Cold Start

For new users (≤ 7 interactions):
1. Use Food DNA from onboarding (initial vector)
2. Bias toward city-popular foods
3. Use demographic prior (age, location, budget tier)
4. Higher exploration rate (more diverse cards shown)
5. After 7 interactions, full personalization kicks in

### 1.5 Decay & Drift Handling

- **Decay**: weight events older than 90 days at 0.5× linearly
- **Drift detection**: if user's recent (30d) embedding ↔ historical embedding cosine < 0.7 → user palate changing
- **Drift response**: increase exploration rate, present new cuisine families

### 1.6 Explainability

Each AI recommendation tagged with WHY:
```json
{
  "reason_codes": [
    "high_cuisine_match:vietnamese:0.92",
    "weather_match:rain→warm_soup:0.85",
    "time_match:lunch:0.91",
    "novelty_introduction:hue_cuisine:0.31"
  ],
  "human_reason": "Trời mưa Hà Nội — món ấm bụng cho ngày se lạnh"
}
```

Internally we keep both: machine reasons (for debugging + experimentation) and human reason (LLM-generated).

---

## 2. AI Engine #2 — Mood Engine

> **What it does:** Maps emotional state → food universe, using both explicit picks and implicit signals.

### 2.1 The Mood–Food Matrix

```
                    │ Comfort │ Energy │ Indulge │ Refresh │ Soothe
─────────────────────┼─────────┼────────┼─────────┼─────────┼────────
Buồn (sad)           │  ████   │        │  ███    │         │  ████
Stress               │  ███    │        │  ████   │         │  ████
Cô đơn (lonely)      │  ████   │        │  ██     │         │  ███
Vui (happy)          │  ██     │  ███   │  ████   │  ██     │  ██
Chill                │  ███    │        │  ██     │  ██     │  ███
Thức khuya (late)    │  ████   │  ██    │  ███    │         │  ██
Mệt (tired)          │  ████   │  ████  │         │  ██     │  ███
Vội (rushed)         │         │  ████  │         │  ██     │
Trời mưa             │  ████   │        │  ██     │         │  ███
Cuối tháng (broke)   │         │        │         │         │  (budget filter)
```

### 2.2 Mood Signals (3 layers)

**Explicit:**
- User picks mood in Mood Wheel
- User says voice command "Tôi đang stress"

**Inferred:**
- Time of day (3am = sleep-deprived?)
- Last app activities (heavy scroll without action = indecisive?)
- Weather (rain = comfort food)
- Calendar event nearby (date night, family meal)
- Day-of-week (Monday blues, Friday celebration)

**Personal patterns:**
- "When this user opens at 10pm with budget < 50k, they usually pick noodle soup" — learned

### 2.3 Mood Engine Architecture

```
User opens Mood Picker
        ↓
Mood Wheel UI (8 emotions × time of day overlay)
        ↓
User selects: "Stress" 
        ↓
┌─────────────────────────────────────┐
│ Mood Engine:                        │
│ - Lookup mood→tag mapping           │
│ - Filter by personal mood history   │
│ - Cross with current context        │
│ - Cross with user taste vector      │
│ - Return candidate foods            │
└────────────┬────────────────────────┘
             ↓
       Pass to Ranker
             ↓
       Show "Mood Playlist" (12 cards)
       + UI changes ambiance (gradient, music optional)
```

### 2.4 Cultural Mood Mapping (Vietnamese-specific)

Critical: Western "comfort food" ≠ Vietnamese "ăn xả stress".

```yaml
# config/mood_food_vi.yaml
mood_buồn:
  comfort_tier_1: [cháo gà, phở, bún bò, bún riêu]
  comfort_tier_2: [chè, kem, trà sữa]
  avoid: [fast food gây nặng bụng]
  
mood_stress:
  comfort_tier_1: [lẩu, đồ nướng, mì cay 7 cấp độ]
  comfort_tier_2: [snack mặn, hạt mix, bia + nem]
  
mood_cô_đơn:
  intimate_tier: [cơm tấm, cơm gà, mì tôm xào]
  no_judgment: [đồ ăn vặt, đồ ngọt]
  
mood_chill:
  weekend_tier: [brunch, bánh mì pate, cafe + bánh ngọt]
  
mood_thức_khuya:
  late_safe: [cháo, mì gói cao cấp, xôi mặn]
  avoid_heavy: [chiên rán, lẩu]
  late_treat: [trà sữa, kem, ăn vặt]

mood_đi_date:
  romantic_tier: [hot pot for 2, lẩu, cocktail + small plates]
  instagram_able: [rooftop bars, cafe view]
  
mood_cuối_tháng:
  budget_max: 30000
  filling_first: [cơm bụi, bún bò bình dân, bánh mì]
```

### 2.5 Mood History & Personalization

- Track: every (mood pick → food chosen → did they enjoy?) tuple
- Learn: "When this user is stressed, they actually pick lẩu, not mì cay"
- Personalize: next time, show lẩu first

### 2.6 Mood UI Changes
- Background gradient shifts to "mood color"
- Music option (optional Spotify integration: "stress → chill playlist")
- AI voice tone adjusts ("buồn" → softer, slower)
- Suggested foods carry mood badge

---

## 3. AI Engine #3 — Viral Engine

> **What it does:** Monitors social platforms (TikTok, Facebook Reels, Instagram), detects emerging food trends in Vietnam, and connects users to **nearby places** serving them.

### 3.1 Architecture

```
┌──────────────────────────────────────────────────────┐
│           VIRAL INGESTION PIPELINE                    │
│                                                       │
│  TikTok API + Web scraping (compliant)               │
│        │                                              │
│  Facebook Reels Graph API                            │
│        │                                              │
│  Instagram Hashtags + Reels                          │
│        │                                              │
│  YouTube Shorts                                      │
│        │                                              │
│  Vietnamese food hashtags watchlist                  │
│   (#monan, #anuong, #foodtour, #saigonfood...)      │
└──────────────────────┬───────────────────────────────┘
                       ↓
            ┌──────────────────────────┐
            │   Content Queue (Kafka)  │
            │   ~20K videos/day        │
            └──────────────┬───────────┘
                           ↓
            ┌──────────────────────────┐
            │  AI VIDEO ANALYSIS       │
            │                          │
            │  1. Vision (food detect) │
            │  2. ASR caption          │
            │  3. NLU dish extraction  │
            │  4. Restaurant mention   │
            │     extraction           │
            │  5. Location extraction  │
            │  6. Quality score        │
            └──────────────┬───────────┘
                           ↓
            ┌──────────────────────────┐
            │  TREND CLUSTERING        │
            │  Group by dish + region  │
            │  Detect emerging clusters│
            │  Compute viral velocity  │
            └──────────────┬───────────┘
                           ↓
            ┌──────────────────────────┐
            │  GEOLOCATION MATCH       │
            │  For each viral dish:    │
            │  Find restaurants nearby │
            │  Rank by relevance       │
            └──────────────┬───────────┘
                           ↓
            ┌──────────────────────────┐
            │  PUBLISH TO FEED         │
            │  "Viral TikTok this week"│
            │  + restaurant matching   │
            └──────────────────────────┘
```

### 3.2 Trend Detection Algorithm

**Velocity-based virality:**
```python
def virality_score(dish_cluster, window_hours=72):
    views = sum(v.view_count for v in cluster.videos[-window_hours:])
    creators = len(set(v.creator_id for v in cluster.videos[-window_hours:]))
    velocity = views / window_hours  # views/hour
    diversity = creators / max(len(cluster.videos), 1)
    
    # Boost recent
    recency_boost = exp(-hours_since_peak / 24)
    
    return (
        log10(velocity + 1) * 0.4 +
        diversity * 0.3 +
        recency_boost * 0.3
    )

# Threshold: >0.65 = mark as "viral"
# >0.85 = "🔥 Đang nổ"
```

### 3.3 Dish Identification (multi-modal)

Multi-signal:
1. Vision: object detection on key frames (YOLOv8 food)
2. Caption: NLU on creator's caption text
3. Audio: Whisper transcribes speech ("Đây là món bánh tráng nướng...")
4. Hashtags
5. Music recognition (some dishes have viral songs attached)

Cross-validation: ≥2 signals must agree for high confidence.

### 3.4 Restaurant Matching

For each viral dish:
1. Query Elasticsearch for restaurants serving exact dish
2. If creator mentioned restaurant → priority match
3. Geographic: cluster by city, then rank by user proximity
4. Quality: only verified restaurants + ≥4.0 rating

**Output card:**
```
┌─────────────────────────────────┐
│  🔥 Viral 2.4M views            │
│  [video preview]                │
│                                 │
│  "Bánh tráng cuốn thịt heo"     │
│  Đà Nẵng style                  │
│                                 │
│  📍 5 quán gần bạn bán món này │
│  Nearest: 600m · 50k · ⭐4.7    │
│                                 │
│  [Xem video] [Đi đến quán]      │
└─────────────────────────────────┘
```

### 3.5 Creator Crediting & Licensing

- TikTok/IG videos: shown via official embed (always credits creator)
- For organic ingestion: prefer Creator Marketplace agreements
- Restaurants who claim viral status: offered promo placement deals

### 3.6 Counter-trend / Anti-bubble

To avoid trend echo chamber:
- "Hidden Gems" feed counter-balances viral
- Diversity injection in main feed
- "Out of fashion but still amazing" badge for old-but-gold dishes

---

## 4. AI Engine #4 — Social Matching

> **What it does:** Multi-user food consensus. Real-time voting + AI mediation when friends disagree.

### 4.1 Group Voting Real-time

**Architecture:**
```
User A swipes "like" on Bún chả
       ↓
[Mobile] WS event → group:abc:vote {user_a, dish_x, +1}
       ↓
[Server] Update poll state in Redis
       ↓
[Server] Broadcast to all group members via Socket.io
       ↓
[All members] See live tally update
```

### 4.2 Group Consensus Algorithm

**Naive approach (just sum votes):** Doesn't work — 1 dominant person decides.

**Our approach: Pareto-optimal intersection:**

```python
def find_group_consensus(group):
    candidates = generate_pool(group.context)  # 200 dishes
    
    # Score each candidate per user
    scores = {}
    for dish in candidates:
        per_user_score = []
        for user in group.members:
            s = personalize_score(user, dish)  # 0-1
            # Apply user's hard constraints (allergies)
            if violates_constraint(user, dish):
                s = -1
            per_user_score.append(s)
        
        # Group score = min of all (Pareto-friendly)
        # + bonus for high mean
        scores[dish] = (
            min(per_user_score) * 0.6 +
            mean(per_user_score) * 0.4
        )
    
    # Diversity & price match
    top_5 = diversify(sort_by_score(scores)[:30], n=5)
    return top_5
```

**Key principle:** Better to find a dish everyone is **80% happy with** than one where 4 people LOVE and 1 person hates.

### 4.3 Tie-breaking & Mini Games

When 2+ dishes are tied:

**Option A: Random Wheel** (gamified)
- Animated wheel with tied dishes
- Group cheers via emoji reactions

**Option B: "Last Vote" round**
- 30-second tiebreaker
- Each user has 1 priority vote

**Option C: "AI Vote"** — Hà picks based on context
- "Hôm nay trời mưa, mọi người chọn lẩu nhé!" — adds context-driven tie-breaker

### 4.4 Couple Mode (Special Case)

For 2-person linked accounts (couples/best friends):
- **Shared taste vector** computed (intersection embedding)
- Recommendations always show "ăn hợp cả 2"
- Special UI: 2 avatars stacked on cards
- "Date Night Mode" — extra romantic filters

```python
def couple_taste(user_a, user_b):
    # Weighted intersection
    # Both must accept (no veto by allergy)
    # Prefers dishes both have positive history
    return {
        "embedding": 0.5 * user_a.emb + 0.5 * user_b.emb,
        "veto": user_a.allergies | user_b.allergies | user_a.hates | user_b.hates,
        "shared_loves": user_a.loves & user_b.loves
    }
```

### 4.5 Group Chat Integration

Within a group, mini-chat enabled:
- Quick reactions (emoji)
- Voice notes ("Tao đói rồi nha")
- AI suggestion: "Hà thấy 3 người chưa vote — nhắc nhé?"

### 4.6 Anti-Friction Group Setup

Pain points solved:
- **No app needed for join** — first time joiners can vote via web link
- **No login** — auto-create guest account, prompt save later
- **Auto-detect from location** — if all in same place, suggest places nearby
- **Calendar integration** — group event auto-creates voting

---

## 5. AI Engine #5 — Fridge Vision

> **What it does:** Photo → recipe. Reduces food waste, increases home-cook habit.

### 5.1 Tech Stack
- Custom YOLOv8 fine-tuned on **HNAG-Fridge-50K** dataset
- 187 Vietnamese ingredient classes
- Segment Anything (SAM) for portion estimation
- LLM (GPT-4o-mini) for recipe generation
- Optional: GPT-4V for hard cases (low confidence)

### 5.2 Pipeline

```
[User opens camera]
       ↓
[Auto-detect fridge interior — yes/no]
       ↓
[Frame stability check — ≤30 frames]
       ↓
[Submit best frame to server]
       ↓
[YOLOv8: bounding boxes + class + conf]
       ↓
[Filter confidence ≥ 0.65]
       ↓
[SAM: segment each item for size estimate]
       ↓
[Optional: GPT-4V hard cases]
       ↓
[Return list: [{name, quantity_estimate, confidence}, ...]]
       ↓
[User confirms/edits]
       ↓
[Pass to recipe generator]
       ↓
[Hybrid recipe generation:
  1. Lookup in recipe DB (matching ingredients)
  2. LLM generates novel if no good match
  3. Rank by ingredient utilization, time, skill]
       ↓
[Top 5 recipes returned]
```

### 5.3 Dataset Strategy

**HNAG-Fridge-50K:**
- 50,000 photos of Vietnamese fridges/ingredients
- Sources: paid contributors (1,500₫/photo), affiliate creators, internal team
- Bounding box annotations (LabelBox)
- Quality control: 3 annotators per image, consensus required
- Ongoing growth: 2K new images/month

**Why VN-specific:**
- Western models (e.g., COCO) lack rau muống, măng tươi, đậu hũ, bún
- Vietnamese packaging unique
- Local ingredient sizes differ (Vietnamese chicken size vs US)

### 5.4 Edge Cases

| Case | Strategy |
|------|----------|
| Blurry image | Reject, prompt retake |
| Too dark | Auto-enhance, retry |
| Closed packaging | OCR labels to detect content |
| Mixed items | SAM segments, individual classify |
| Unknown ingredient | Fallback "Khác?" with text input |
| Empty fridge | Friendly empty state + grocery delivery prompt |

### 5.5 Recipe Generation Prompt

```
SYSTEM:
Bạn là chef Vietnamese chuyên gia. Tạo recipe tận dụng tối đa
nguyên liệu user đã có. Khoảng cách kỹ năng người dùng: {skill}.
Thời gian khả dụng: {time} phút. Phong cách: home cooking, không cầu kỳ.
Trả về JSON đúng schema.

USER:
Nguyên liệu có:
- Trứng × 4 quả
- Cà chua × 3 quả
- Hành lá × 1 bó
- Thịt heo × 200g
- ...

Tạo 3 recipe khả thi, mỗi recipe:
{
  name, description, time_min, difficulty,
  uses: ["all ingredients used"],
  missing: ["nếu cần thêm gì"],
  steps: [...],
  tip: "1 tip để ngon hơn"
}
```

### 5.6 Continuous Learning

- User feedback: "Đã nấu" / "Ngon" / "Không hợp" → improves recipe ranking
- "Đã ăn" tracking for fridge inventory (decrement)
- Auto-reminder: "Cà chua sắp hết hạn — nấu món sau dùm nha"

---

## 6. AI Orchestrator — "Hà"

> The unified persona that connects all engines. **The AI everyone interacts with.**

### 6.1 Hà's Personality

```yaml
personality:
  name: Hà
  tone: thân thiện, dí dỏm, không trang trọng
  age_persona: 25 (relatable peer)
  vocal_style: Vietnamese natural, có thể chọn Bắc/Trung/Nam accent
  
  rules:
    - Never use English unless user does
    - Max 25 words per voice response
    - Use playful imagery: "tô ấm bụng", "bao ngon", "ngon hết sảy"
    - Never patronize
    - Asks 1 question at a time, never bombards
    - Acknowledges emotions ("Stress hả? OK, Hà hiểu mà")
    - Self-deprecates lightly: "Hà nghĩ sai à? Sorry Hà sẽ học"
    - Uses Vietnamese particles: nhé, nha, đó, mà, ạ (formal mode)
  
  forbidden:
    - Medical advice (food can be unhealthy → soft prompt: gặp chuyên gia)
    - Judgmental tone
    - Marketing pushiness
    - Fake urgency
```

### 6.2 Hà's Interaction Modes

**Mode 1 — Reactive (default)**
- Activates on tap "AI Decide" or voice
- Quick Q&A, 3 questions max
- Returns cards

**Mode 2 — Proactive (push)**
- "Buổi sáng Thảo ơi, đói chưa?" (7:30am)
- 1–3 push/day, tuned per user

**Mode 3 — Companion (open chat)**
- Premium feature
- Free-form chat about food
- Hà remembers past conversations (RAG over user history)

**Mode 4 — Voice-only**
- Hands-free
- Wake word: "Hey Hà"
- Streaming ASR + TTS
- Adjusts tone (calm if user sounds stressed)

### 6.3 Orchestration Logic

```python
async def ha_handle_request(user, query, context):
    intent = classify_intent(query)  # LLM intent classifier
    
    if intent == "suggest_food":
        # Route through Taste + Mood
        candidates = await taste_engine.candidates(user, context)
        if has_mood_signal(query):
            candidates = mood_engine.bias(candidates, mood)
        if has_viral_signal(query):
            candidates = viral_engine.augment(candidates)
        ranked = ranker.rank(candidates, user)
        return cards(ranked[:5])
    
    elif intent == "group_decision":
        return await social_matcher.start_group(query.group)
    
    elif intent == "what_to_cook":
        if has_fridge_image(query):
            return await fridge_vision.process(query.image)
        else:
            return cook_recommender.cook_only(user, context)
    
    elif intent == "find_viral_dish":
        return await viral_engine.match_by_link(query.url)
    
    elif intent == "chat" or intent == "ambiguous":
        return await llm_chat(user, query, context, memory)
    
    elif intent == "remind" or intent == "plan":
        return await meal_planner.handle(user, query)
```

### 6.4 Memory System (long-term)

Hà must remember things across sessions:
- User's name, preferences, allergies
- Past 30 food decisions
- Past conversations (key facts only, not full text)
- User's stated preferences ("Hà ơi, tao không thích phở")

**Implementation:**
- Short-term: Redis (session context, last 50 messages)
- Long-term: Vector DB (Pinecone) — embed and retrieve relevant context (RAG)
- Structured memory: PostgreSQL `user_preferences` updated by Hà's tool calls

### 6.5 Tool Use (Function Calling)

Hà can invoke:
```
get_user_taste()
suggest_foods(context)
search_restaurants(query, location)
match_viral_dish(url)
analyze_fridge(image)
create_meal_plan(week)
update_user_preference(key, value)
book_table(restaurant_id, time)
place_order_intent(food, partner)
remind_at(time, message)
analyze_mood(text)
get_calendar_events(date)
get_weather(location)
```

Each tool returns structured data → Hà phrases response in natural Vietnamese.

### 6.6 Safety Guards

- Allergy never overridable by LLM
- Cost ceiling: any user can max $X/month in AI spend, then degraded mode
- Prompt injection guard: system prompt + user data clearly separated
- Hate speech / bad content filter
- Disordered eating signal detection → soft prompt resource

---

## 7. Cost & Performance Profile

| Engine | Avg latency | Cost/request | Cache hit |
|--------|-------------|--------------|-----------|
| Taste Memory lookup | 20ms | $0.0001 | 95% |
| Mood Engine | 50ms | $0.0001 | 70% |
| Viral Engine match | 300ms | $0.002 | 60% |
| Social Matching | 100ms (real-time WS) | $0.0005 | n/a |
| Fridge Vision | 1.4s | $0.018 | 0% |
| Hà LLM call (mini) | 700ms | $0.0008 | 40% |
| Hà LLM call (full) | 2.2s | $0.012 | 20% |
| TTS Vietnamese | 800ms | $0.003 | 50% (common phrases) |
| ASR streaming | live | $0.006/min | 0% |

**Optimization tactics:**
- Embeddings cached, re-computed weekly
- LLM batch calls (5 cards in 1 prompt)
- Mini model for simple tasks
- Self-host Whisper at scale
- Pre-generated common TTS phrases ("Đặt giao", "Đi đến quán")

---

## 8. AI Quality Eval Framework

### 8.1 Golden Evaluation Sets

- **Recommendation eval:** 500 (user × context) pairs with human-curated "good answers"
- **Mood eval:** 200 (mood × time × user) cases
- **Vietnamese language eval:** 1000 generated responses, scored by native team
- **Fridge vision eval:** 2000 photos, IoU + class accuracy
- **Viral matching eval:** 100 TikTok links, ground-truth restaurants

### 8.2 Continuous Monitoring

| Metric | Source | Threshold alert |
|--------|--------|-----------------|
| Suggestion CTR | analytics | <8% per session |
| Skip rate per card | analytics | >65% |
| User reported "bad rec" | feedback | >2% / week |
| LLM cost / DAU | finance | >$0.022 |
| Fridge vision conf avg | logs | <0.78 |
| Hà response time p95 | APM | >2.5s |

### 8.3 A/B Test Discipline

Every algorithm change:
- 1% traffic test for 7 days
- Primary metric: 30-day retention
- Secondary: CTR, time-to-decide, premium conversion
- Statistical power calculated (min 5k users per arm)

---

## 9. Privacy & AI Ethics

### 9.1 Data Boundaries
- User taste vector: stored locally + server (encrypted)
- Voice recordings: not stored beyond ASR processing (≤24h debug)
- Image fridge scans: stripped EXIF, blurred faces auto, deleted after 30 days
- Anonymization: no PII in training datasets

### 9.2 User Control
- Settings: "Reset Taste Memory" button (start over)
- Settings: "Pause AI personalization for 7 days" (try fresh recs)
- Granular: "Don't use mood data for recommendations"
- Right to download all AI data about them

### 9.3 Algorithmic Transparency
- Every card has an AI explanation
- Premium users can see "Why this rec?" detailed view (top 5 reason codes)
- Yearly transparency report published

---

## 10. AI Roadmap

| Quarter | New Engine / Improvement |
|---------|--------------------------|
| Q1 2026 | Taste Memory v1, Mood Engine v1, Hà LLM v1, basic Fridge Vision |
| Q2 2026 | Viral Engine v1 (TikTok), Social Matching v1, Hà Voice |
| Q3 2026 | Fridge Vision v2 (edge/offline), Hà Memory v2 (RAG long-term) |
| Q4 2026 | Health AI (macro coach), Meal Planner AI auto |
| Q1 2027 | Generative recipes (novel), AR menu translation |
| Q2 2027 | Multi-language Hà (Indonesian, Thai) |
| Q3 2027 | Smart appliance integration (LG/Samsung) |
| Q4 2027 | On-device AI (privacy-first, offline rec) |

---
