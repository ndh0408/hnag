# 09 — Recommendation Architecture & Realtime Systems

> **Goal:** Surface the perfect dish in **<800ms p95**, personalized to one of 12 million users, while learning from every swipe.

---

## 1. Recommendation Architecture — Bird's Eye

```
┌─────────────────────────────────────────────────────────────────┐
│                         REQUEST PATH                             │
│  /v1/ai/suggest   ← user request                                 │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────┐                   │
│  │  1. CONTEXT BUILDER  (50ms)              │                   │
│  │  • User profile (Redis hot)              │                   │
│  │  • Taste vector (Redis)                  │                   │
│  │  • Weather, time, location               │                   │
│  │  • Last 7 meals                          │                   │
│  │  • Friend activity                       │                   │
│  └──────────────────────────────────────────┘                   │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────┐                   │
│  │  2. CANDIDATE GENERATION (300ms parallel)│                   │
│  │                                          │                   │
│  │  Two-tower model retrieval (Pinecone)   │                   │
│  │   ↓ 100 candidates                       │                   │
│  │                                          │                   │
│  │  Collaborative filtering (Redis ALS)    │                   │
│  │   ↓ 60 candidates                        │                   │
│  │                                          │                   │
│  │  Trending nearby (Elastic+H3)           │                   │
│  │   ↓ 40 candidates                        │                   │
│  │                                          │                   │
│  │  Editorial picks                        │                   │
│  │   ↓ 20 candidates                        │                   │
│  │                                          │                   │
│  │  Friend-seen boost                      │                   │
│  │   ↓ 20 candidates                        │                   │
│  │                                          │                   │
│  │  Merge + dedupe → 200 unique items      │                   │
│  └──────────────────────────────────────────┘                   │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────┐                   │
│  │  3. RANKING (200ms)                      │                   │
│  │  LightGBM model w/ 50+ features          │                   │
│  │  → top 30 ranked                         │                   │
│  └──────────────────────────────────────────┘                   │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────┐                   │
│  │  4. RE-RANKING / DIVERSITY (50ms)       │                   │
│  │  • MMR diversity injection               │                   │
│  │  • Constraint satisfaction               │                   │
│  │  • Business rules                        │                   │
│  │  → top 5 final                           │                   │
│  └──────────────────────────────────────────┘                   │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────┐                   │
│  │  5. ENRICHMENT (100ms parallel)         │                   │
│  │  • LLM reason generation (batched)       │                   │
│  │  • Video URL resolve                     │                   │
│  │  • Restaurants nearby                    │                   │
│  │  • Friend signals                        │                   │
│  │  • Viral TikTok matching                 │                   │
│  └──────────────────────────────────────────┘                   │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────┐                   │
│  │  6. CACHE + RESPOND  (10ms)              │                   │
│  │  • Redis cache 5min (user, context-hash) │                   │
│  │  • Send response                         │                   │
│  │  • Log to Kafka for training             │                   │
│  └──────────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
        TOTAL: ~700ms p50, <1.4s p95
```

---

## 2. Two-Tower Retrieval Model

### 2.1 Architecture

```
USER TOWER                    ITEM TOWER
────────────                  ────────────
Input features:               Input features:
- user_id (embed)             - food_id (embed)
- city                        - cuisine
- demographic                 - flavor tags
- diet_type                   - mood tags
- recent_history embed        - price_bucket
- mood_signal                 - cook_time
                              - calo_bucket
   │                              │
   ▼                              ▼
[Dense 128]                  [Dense 128]
[Dense 64]                   [Dense 64]
[L2-normalize]               [L2-normalize]
   │                              │
   └─────── Dot product ──────────┘
                │
              Score
```

### 2.2 Training

**Data:** Last 90 days of (user, food, action, context) tuples.
- Positive: ordered, ate, rated ≥4, saved
- Hard negative: viewed, skipped
- Easy negative: random sampled

**Loss:** In-batch sampled softmax + hard-negative mining.

**Frequency:** Re-train weekly on 100M+ events.

**Validation:** Held-out users + recent week, metric NDCG@5.

### 2.3 Serving
- User tower runs at request time (with live taste vector)
- Item tower pre-computes embeddings → Pinecone index
- Pinecone query: top-100 nearest by cosine

### 2.4 Cold-start handling

| User type | Strategy |
|-----------|----------|
| Brand new | Use Food DNA as proxy + demographic prior |
| 1–6 interactions | Hybrid (DNA + early signals) |
| 7+ interactions | Full model |
| Returning after 60d gap | Decay old embedding, re-bootstrap |

For new items:
- Embed using item-content alone (no collab history)
- Editorial boost for first 30 days
- Track CTR — promote/demote based on early performance

---

## 3. Ranking Layer — LightGBM

### 3.1 Why LightGBM (not deep learning)
- Faster training & serving
- Easier to debug feature contributions
- Robust to feature noise
- Production-proven by Meituan, Pinterest food

### 3.2 Feature List (50+)

**User features (15):**
- Taste vector match (cosine)
- Personal cuisine love score
- Spice tolerance match
- Price affinity match
- Time-of-day pattern match
- Diet compliance (hard filter then signal)
- Days since last cuisine: vietnamese, korean, japanese...
- Novelty appetite
- Hunger signal (from explicit input)
- Mood signal
- Couple/group context flag

**Item features (15):**
- Item embedding match
- Popularity (city-adjusted)
- Recent CTR
- Rating (Bayesian-smoothed)
- Price relative to user budget
- Distance from user
- Calorie vs user goal
- Cook time vs available time
- Flavor profile match
- Vibe match
- Item age (days since added)
- Editorial boost flag
- Viral status flag

**Context features (10):**
- Weather (temp, precipitation, "feel-cold" score)
- Hour of day
- Day of week
- Special calendar (holiday, payday)
- Season
- Time since last app open

**Interaction features (10+):**
- Has friend ate this? (count)
- Has friend rated 5? (count)
- Hours since same cuisine
- Variance from recent diet
- Restaurant repeat-visit probability

### 3.3 Multi-objective Optimization

Single score is not enough. We optimize:

```python
final_score = (
    relevance      * 0.45 +   # personalized fit
    quality        * 0.20 +   # rating + verified
    business_value * 0.10 +   # commission potential
    diversity_bonus* 0.10 +   # explore new
    freshness      * 0.10 +   # new content
    locality       * 0.05     # close to user
)

# Caveat: hard constraints filter (allergies, closed, out-of-stock)
# applied BEFORE scoring
```

Business value boost is **disclosed** as "Quảng cáo" (sponsored) when applied — never deceptive.

---

## 4. Diversity & Anti-fatigue

### 4.1 MMR (Maximal Marginal Relevance)

```python
def mmr_rerank(candidates, lambda_=0.7, k=5):
    selected = []
    while len(selected) < k:
        best = None
        best_score = -inf
        for c in candidates:
            if c in selected:
                continue
            rel = c.score
            redundancy = max(cosine(c.emb, s.emb) for s in selected) if selected else 0
            mmr_score = lambda_ * rel - (1 - lambda_) * redundancy
            if mmr_score > best_score:
                best_score, best = mmr_score, c
        selected.append(best)
    return selected
```

**Result:** Top 5 cards span different cuisines, vibes, action types.

### 4.2 Action diversity
Of top 5, target: 2 "cook", 2 "order", 1 "dine-out" (adjust per user pattern).

### 4.3 Fatigue dampening
- Suppress items shown in last 24h unless user dwelled >5s
- Cuisine cap: max 2 same cuisine in top 5
- Restaurant cap: max 1 same restaurant in top 5 (different dishes)

---

## 5. Real-time Personalization

### 5.1 Live Signal Loop

```
User swipes right on Bún chả
       ↓ (Mobile WS event)
[API ingestion] → 2ms
       ↓
[Update Redis user state]
   - Add to "saved" set
   - Update taste vector delta
       ↓
[Publish to Kafka] interaction.events
       ↓
[Consumer: Online Trainer]
   - Update taste embedding (EMA, alpha=0.05)
       ↓
[Write back to Redis (1ms) + Postgres async]
       ↓
NEXT API call /v1/ai/suggest uses updated vector
```

**Result:** swipe→next-suggestion reflects new signal within ~500ms.

### 5.2 Session-Level Context

Track within session (24h TTL in Redis):
- Foods viewed
- Foods skipped (count per cuisine)
- Time spent on each card
- Mood declared
- Hunger level

→ Modifies in-session ranking strongly.

### 5.3 Contextual Bandits (V2)

After basic rec stable, introduce contextual bandits for explore/exploit:
- Thompson sampling for new item exposure
- Reward: ordered/cooked
- Decreases over-exploitation of "safe" picks

---

## 6. Realtime Systems — WebSocket Layer

### 6.1 Connection Architecture

```
[Client] ─── socket.io v4 ───→ [LB sticky] ──→ [Pod cluster]
                                                    │
                              [Redis Pub/Sub adapter] ←── cross-pod fanout
                                                    │
                                            [Kafka producer]
                                                    │
                                             [Consumers: notifs, analytics]
```

### 6.2 Channels

| Channel | Purpose |
|---------|---------|
| `user:{id}` | Direct notifications, order updates |
| `group:{id}` | Group voting, group chat |
| `restaurant:{id}` | Live status broadcasts |
| `feed:{city}` | Trending updates |
| `system` | Global announcements |
| `couple:{pair_id}` | Couple-specific real-time |

### 6.3 Events Catalog

```
SUBSCRIBE (client → server)
  subscribe:user        (auto, on connect)
  subscribe:group       {groupId}
  subscribe:restaurant  {restaurantId}
  
EMIT (client → server)
  vote:cast             {pollId, optionIdx}
  presence:typing       {channel}
  reaction:add          {targetId, emoji}
  
RECEIVE (server → client)
  notification.new
  group.poll.updated    {pollId, tally}
  group.poll.closed     {pollId, winner}
  group.member.joined
  order.status.changed
  restaurant.status.changed
  ai.suggestion.ready
  live.activity.update  (live cooking)
  couple.partner.active
  streak.changed
  feed.new.trending
```

### 6.4 Reliability
- Sticky sessions (LB cookie)
- Reconnect with exponential backoff
- Server-side message buffer (last 50 per channel) for reconnect catch-up
- Heartbeat 25s
- Per-connection rate limit (100 events/min)

### 6.5 Scale
- Per pod: 10K concurrent (Node.js + uWebSockets.js)
- 50 pods → 500K concurrent peak
- Redis cluster (3 shards) for pub/sub
- Kafka 10 brokers for event firehose

---

## 7. Group Real-time Sync (Voting)

### 7.1 State Model (Redis)

```redis
HASH group_poll:{pollId}
  status       → "open"
  options      → "[{food_id, restaurant_id}, ...]"  (JSON)
  votes        → "{user_a: [0, 2], user_b: [1], ...}"  (JSON)
  closes_at    → "1700123456"
  
SET group_poll:{pollId}:active_users
  → user_a, user_b, user_c
```

### 7.2 Voting Flow

```
User taps "vote" on option 0
       ↓
WS event: vote:cast {pollId: abc, optionIdx: 0}
       ↓
Server validates (member of group? poll open?)
       ↓
Redis HASH update + atomic increment
       ↓
Compute tally
       ↓
Publish on group:{id} channel: poll.updated {tally}
       ↓
All members receive in <100ms
       ↓
UI animates new vote (avatar flies into bar)
```

### 7.3 Closing the Poll

- Timer auto-close (e.g., 5 min)
- All members voted → auto-close
- Creator can manual close

On close:
- Winner computed (with tie-break rules)
- Confetti event broadcast
- Maps deeplink offered

### 7.4 Conflict Resolution

- Vote replace (only latest counts)
- Idempotency keys on vote events
- Last-write-wins for member adds
- Server-authoritative state

---

## 8. Live Status Broadcasts

### 8.1 Restaurant Live Status

Pushed to `restaurant:{id}` channel:
- `crowded_changed` — new crowdedness level
- `wait_time_updated` — new estimated wait
- `closing_soon` — within 30 min
- `live_stream_started` (V2)

### 8.2 Friend Activity

Pushed to user's `couple` or close-friends channel:
- `friend_check_in` — friend at restaurant
- `friend_started_cooking` — opt-in only
- `partner_in_decide_flow` — couple soft-prompt

---

## 9. Caching Strategy

### 9.1 Cache Layers

| Layer | TTL | What |
|-------|-----|------|
| **Edge (Cloudflare)** | 5min–1h | Public restaurant pages, trending feed |
| **Redis L1** | 5min | AI suggestions, user state |
| **Redis L2** | 1h | User profile, taste vector |
| **Redis L3** | 24h | Item embeddings, restaurant metadata |
| **App-level (Postgres)** | n/a | Source of truth |
| **Client cache (Hive/IndexedDB)** | 24h | Last home feed, profile, recent cards |

### 9.2 Cache Keys

```
ai:suggest:{user_id}:{context_hash}      TTL 5min
user:taste:{user_id}                     TTL 1h
user:profile:{user_id}                   TTL 10min
food:{food_id}                           TTL 1h
restaurant:{restaurant_id}               TTL 30min
trending:district:{city}:{district}      TTL 15min
feed:home:{user_id}:{section}            TTL 10min
viral:dishes:24h                         TTL 1h
heatmap:{city}:{layer}:{15min_bucket}    TTL 15min
```

### 9.3 Invalidation
- Write-through for user updates
- Pub/sub events trigger invalidate
- Lazy expiration as primary

---

## 10. Search Architecture

### 10.1 Elasticsearch
- Vietnamese analyzer with synonym file
- Indexes: foods, restaurants, users, posts
- Tokenizer: vi_tokenizer (custom + ICU)
- Synonyms: pho/phở, banhmi/bánh mì, com/cơm

### 10.2 Query Flow
```
User types "phở bò"
       ↓
ES query: multi_match with boost
       ↓
Score: text_relevance × popularity × locality
       ↓
Top 20 → reorder with personalization (taste vector)
       ↓
Return cards
```

### 10.3 Autocomplete
- Completion suggester
- City-tailored
- Real-time as user types (debounce 80ms)

### 10.4 Semantic Search (Pinecone)
For complex queries: "món ăn vặt buổi tối dưới 30k"
- Embed query → Pinecone search foods
- Combine with structured filter

### 10.5 Visual Search Path
```
Image upload → S3
       ↓
Vision encoder (CLIP-based) → embedding
       ↓
Pinecone similarity → candidate foods
       ↓
ES enrich + filter
       ↓
Return cards
```

---

## 11. Data Pipeline (ML Training)

### 11.1 Layered Architecture

```
Mobile/Web events → Kafka (raw)
              ↓
        Schema validation → ClickHouse + S3 raw
              ↓
        Airflow batch DAGs:
          - Daily aggregations
          - Weekly model training
          - Monthly cohort analysis
              ↓
        Feature Store (Feast)
              ↓
        Training infrastructure (SageMaker)
              ↓
        Model registry (MLflow)
              ↓
        Serving (BentoML on K8s)
              ↓
        Online inference
```

### 11.2 Pipelines

**Daily:**
- User activity aggregation
- Item popularity updates
- Cohort retention compute

**Weekly:**
- Two-tower retrieval retrain
- LightGBM ranker retrain
- A/B test result analysis

**Monthly:**
- Foundation model fine-tune (food VN dataset)
- Mood model recalibration
- Vision model retrain (new ingredient classes)

### 11.3 Online vs Offline Features

| Feature | Mode | Source |
|---------|------|--------|
| User embedding | Both | Redis live + offline retrain |
| Item embedding | Offline | Pinecone (weekly refresh) |
| Popularity | Both | ClickHouse rolling sum |
| User-day pattern | Offline | Daily Airflow |
| Friend activity | Online | Redis |
| Weather | Online | API |

---

## 12. A/B Testing Framework

### 12.1 Setup
- Statsig (vendor) + Feature Flags + custom SDK
- Exposure logging in Kafka
- Power calc tool for sample size

### 12.2 Experimentation discipline
- Pre-registered hypothesis
- Sample size, power, MDE pre-declared
- One primary metric per test
- Holdout for global causal inference

### 12.3 Example: New ranker
- 5% test arm
- Metric: 30-day retention (proxy: 7-day with multiplier)
- Sample: 200K users / arm
- Duration: 14 days
- Statistical analysis: Bayesian (Statsig default)

---

## 13. Observability for ML

### 13.1 Metrics tracked

| Metric | Why |
|--------|-----|
| Model inference latency p50/p95/p99 | SLO |
| Feature freshness | Staleness alert |
| Prediction distribution shift | Detect data drift |
| Score distribution per arm | A/B sanity |
| Online CTR vs offline NDCG | Train/serve skew |
| Coverage (% items shown) | Long-tail health |
| Error rate (model unavailable) | Reliability |

### 13.2 Drift detection
- PSI (Population Stability Index) on features
- KL divergence on prediction distributions
- Alerts when drift > threshold → manual review

### 13.3 Online evaluation
- Random 1% traffic with "shadow" model (logs but doesn't serve)
- Compare champion vs challenger before promotion

---

## 14. Realtime Personalization for First Session

Critical: new user's **first 30 seconds** decides retention.

```
Open app → Quick onboarding done
       ↓ (food DNA submitted)
[Pre-warm cache] Server pre-computes initial recommendations
       ↓
[Show home feed]
       ↓
First card lands → user reacts
       ↓
[Aggressive learning rate alpha=0.15 for first 20 events]
       ↓
By event 5, personalization noticeably improving
       ↓
By event 20, alpha decays to normal 0.05
```

Bonus: "Cold-start prompt" — surface "Tell Hà more about you" if patterns ambiguous.

---

## 15. Fallback & Degraded Modes

When systems fail, gracefully degrade:

| Component down | Fallback |
|----------------|----------|
| Pinecone | Use cached recommendations + ES + popularity |
| LightGBM serving | Use score from two-tower alone |
| LLM API down | Skip AI reason, show "Hà gợi ý" generic |
| Weather API | Default neutral context |
| Restaurant API | Show cached status |
| Search backend | Use Postgres LIKE fallback |
| WebSocket | Fall back to polling (every 5s) |

Never show a blank screen — always have content.

---

## 16. Multi-region & Latency

### 16.1 Year 1 — Single region
- AWS Singapore (ap-southeast-1)
- Best for Vietnam latency
- 80–120ms RTT VN → SG

### 16.2 Year 2 — Edge + read replicas
- Cloudflare Workers for read-mostly endpoints (restaurant detail, feed)
- Postgres read replica in Hong Kong (ap-east-1)
- Reduces p95 latency 30%

### 16.3 Year 3 — Multi-region active
- Write replication via logical decoding
- Region routing by user location
- Conflict resolution (last-write-wins for user state)

---

## 17. Performance Budget per Endpoint

| Endpoint | p50 | p95 | p99 |
|----------|-----|-----|-----|
| /ai/suggest | 700ms | 1.4s | 2.5s |
| /feed/home | 350ms | 800ms | 1.5s |
| /restaurants/nearby | 200ms | 500ms | 900ms |
| /foods/{id} | 80ms | 200ms | 400ms |
| /search?q=... | 250ms | 600ms | 1.2s |
| /reviews?restaurant=... | 200ms | 500ms | 900ms |
| /me | 50ms | 150ms | 300ms |
| /fridge/scan (sync vision) | 1.4s | 2.5s | 4s |

---

## 18. Data Volume Estimates (Year 2)

| Stream | Volume/day |
|--------|------------|
| API requests | 50M |
| Recommendation requests | 8M |
| Feed events | 80M |
| Search queries | 4M |
| Order events | 600K |
| Photo uploads | 800K |
| Video views | 30M |
| WebSocket messages | 200M |
| Push notifications | 10M |

**Kafka throughput:** ~10K msgs/s avg, 50K peak.
**ClickHouse storage:** ~12 TB total (with compression).

---

## 19. Cost-aware Engineering

Every ML call has a cost. Track:
- $ per recommendation
- $ per LLM call
- $ per voice query
- $ per fridge scan

Budget per DAU/month: **$0.45**.
Mitigate via caching, batching, mini-model routing.

---

## 20. Future Tech Bets

| Bet | Year | Why |
|-----|------|-----|
| On-device taste model | Y3 | Privacy + zero-latency |
| Generative recipes | Y2 | Novel content moat |
| Voice always-on | Y3 | Hand-free habit |
| Multimodal search | Y2 | Photo+text query |
| Federated learning | Y3 | Improve without raw data |
| Wearable integration | Y2 | Heartrate as hunger signal |

---
