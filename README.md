# 🍜 Hôm Nay Ăn Gì? — Series A Pitch Document

> **Tagline:** *"The AI that decides what 100 triệu người Việt eat — every single day."*

**Một dòng tóm tắt:** Hôm Nay Ăn Gì? (HNAG) là siêu ứng dụng food-decision AI-first đầu tiên dành cho người Việt — kết hợp gợi ý món ăn cá nhân hóa (AI), mạng xã hội ẩm thực, marketplace quán ăn và meal planner sức khỏe trong một trải nghiệm duy nhất.

> **Positioning V2:** *"TikTok + Google Maps + Tinder + GrabFood — cho mọi quyết định ăn uống."*
>
> Đây không phải app đặt đồ ăn. Đây là **AI Food Discovery + Social Food Entertainment platform** — nơi bạn mở mỗi ngày **dù chưa đói**, lướt món ăn như lướt TikTok, và addicted với food discovery.

---

## 🚀 Live status (2026-05-20)

**Deployment:** Self-host trên `ServerLinux` (Tailscale `100.100.210.85`) chạy chung với realm-* + Palworld trong cùng Docker stack riêng (network `hnag-internal`). Public access qua **Cloudflare Tunnel** (4 connections HKG region) — không expose port nào.

| URL | Service | Status |
|---|---|---|
| https://api.tothanhthuy.cloud | NestJS backend (60+ endpoints + 6 AI endpoints) | ✅ LIVE |
| https://api.tothanhthuy.cloud/health | Health probe (db + cache) | ✅ `{"ok":true,"db":true,"cache":true}` |
| https://dash.tothanhthuy.cloud | Owner Dashboard (Next.js 14) | ✅ LIVE |
| https://app.tothanhthuy.cloud | APK download + static landing | ✅ LIVE |
| https://app.tothanhthuy.cloud/hnag-latest.apk | Android APK (signed) | ✅ Cài trên Xiaomi Redmi Note 13 Pro+ |
| iOS app (Mapbox map + 14k quán) | Build ký + cài qua `devicectl` (`code/flutter/build-ios.example.sh`) | ✅ Cài + chạy trên iPhone Kayn |

**Real data (thật 100%, không sinh ảo):**
- **14.319 quán ăn THẬT toàn quốc** — cào từ **OpenStreetMap** (`code/ingestion/scrape_restaurants.py`, 63 tỉnh), chuẩn hoá về **62 tỉnh thành** (`gen_city_normalize.py`). Geo points (PostGIS) + cuisine tags + giờ mở; `nearby` trả `lat/lng`.
- **86 món Việt** với ảnh THẬT — 60 seed (Unsplash verify) + 26 cào từ **Wikidata/Wikimedia Commons** (ảnh có license, `scrape_foods_wikipedia.py`).
- 12 achievements, viral dish trending scores tự tính.
- ⏳ Ảnh từng quán (Google Places) — chờ cấu hình; data quán đã đầy đủ.

**AI Public endpoints (no auth, no OpenAI key needed):**
| Endpoint | Logic | Example output |
|---|---|---|
| `GET /v1/ai/suggest-public` | Time-aware: hour 6-10→breakfast, 10-14→lunch, 17-22→dinner, 22-5→latenight | Top 8 món theo bữa, sort `trending_score` |
| `GET /v1/ai/mood-suggest?mood=stress` | Map mood→tags + categories | `{theme: "Stress thì lẩu / nướng xả đi", foods: [...]}` |
| `GET /v1/ai/random?n=8` | Weighted random theo `popularity` | 8 món random cho Wheel |
| `POST /v1/ai/fridge-recipes` | Match nguyên liệu vs `name_vi/description` | Recipes có dùng được + missing items |
| `GET /v1/foods/trending?period=week` | Sort `trending_score` | Top trending |
| `GET /v1/restaurants/nearby?lat&lng` | PostGIS `ST_DWithin` (14k quán) | Quán gần có `distance_m` + `lat`/`lng` (cho map pins) |

**Flutter app — features đã wire vào API thật (no demo data):**

| Feature | Endpoint | Screen |
|---|---|---|
| Home feed (trending + categories) | `/v1/foods/trending` + `/v1/foods` | `_HomeTab` |
| AI Decide (swipeable cards) | `/v1/ai/suggest-public` (time-aware) | `_AiDecideTab` |
| Mood selector → results | `/v1/ai/mood-suggest?mood=` | `MoodResultScreen` |
| Random Wheel | `/v1/ai/random?n=8` | `RandomWheelScreen` |
| Fridge Scan → recipes | `POST /v1/ai/fridge-recipes` | `FridgeScanScreen` |
| Voice "Hỏi Hà" (intent→mood) | `/v1/ai/mood-suggest` | `VoiceAssistantScreen` |
| Search món/quán | `/v1/foods?q=` (name + slug OR search) | `SearchScreen` |
| Quán gần đây (định vị thật) | `/v1/restaurants/nearby` | `NearbyRestaurantsScreen` (+ `geolocator`) |
| Bản đồ Mapbox (pins quán thật) | `/v1/restaurants/nearby` (lat/lng) | `FoodMapScreen` (nút "Bản đồ" ở Quán gần đây) |
| Đặt giao (deep-link) | GrabFood/ShopeeFood/Maps **search đúng tên** | `FoodDetailScreen` + AI Decide |
| Food Detail (description + recipe) | `/v1/foods/:id` | `FoodDetailScreen` |
| Notifications (AI + trending) | `aiMoodSuggest` + `trendingFoods` | `NotificationsScreen` |

**Stack runtime:** PostgreSQL 15 + PostGIS 3.4 · Redis 7 · NestJS 10 (TypeScript) · Prisma 5 · Cloudflare Tunnel · Nginx static · Next.js 14 dashboard · Flutter 3.x (Android APK signed + iOS ký/cài qua devicectl) · **Mapbox Maps SDK** trong app.

**AI engine hiện tại:** Smart heuristic (time + mood + ingredient + category) chạy server-side, **+ GPT-4o-mini đã wire** (OpenAI key cấu hình trên server cho NLU/reasoning; tự fallback heuristic nếu thiếu key). Maps & weather: **Mapbox** + **OpenWeather** key đã cấu hình. Xem [docs/07-AI-ENGINES.md](docs/07-AI-ENGINES.md).

---

## 📊 Snapshot

| | |
|---|---|
| **Stage** | Series A — gọi vốn **$8M USD** |
| **Định giá pre-money** | $32M USD |
| **Thị trường VN (TAM)** | $42B USD (food & delivery) |
| **SAM** | $6.8B (urban, 18–45 tuổi, smartphone) |
| **SOM Year 3** | $180M (2.5% SAM) |
| **Target Year 1** | 1.2M MAU |
| **Target Year 3** | 12M MAU, $48M ARR |
| **Core innovation** | AI Decision Engine + Social Food Graph |

---

## 🎯 Vấn đề (Problem)

Mỗi ngày, **người Việt mất trung bình 23 phút** để quyết định "Hôm nay ăn gì?". Đó là:

1. **Decision fatigue** — 67% Gen Z khảo sát nói họ "lười suy nghĩ" về món ăn
2. **Phân mảnh** — phải mở 4–5 app (Grab, Shopee, Be, TikTok, Google Maps) để quyết định
3. **Thiếu cá nhân hóa** — không app nào hiểu *bạn* (mood, ngân sách, sức khỏe, người đi cùng)
4. **Lãng phí thực phẩm** — 35% nguyên liệu trong tủ lạnh bị bỏ phí vì không biết nấu gì
5. **Social FOMO** — muốn ăn theo trend nhưng không biết chỗ uy tín

> **Insight:** Đây không phải vấn đề về "tìm món" — đây là vấn đề **"quyết định"**.

---

## 💡 Giải pháp (Solution)

**HNAG là AI Decision Layer** ngồi trên toàn bộ hệ sinh thái food của Việt Nam:

```
┌───────────────────────────────────────────────────────────┐
│   HÔM NAY ĂN GÌ? — AI Decision Engine                     │
│                                                            │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│   │   Mood   │  │  Budget  │  │  Health  │  │ Weather  │ │
│   └──────────┘  └──────────┘  └──────────┘  └──────────┘ │
│         ↓            ↓            ↓             ↓         │
│   ╔══════════════════════════════════════════════════╗   │
│   ║         Personalized Food Recommendation          ║   │
│   ╚══════════════════════════════════════════════════╝   │
│         ↓            ↓            ↓             ↓         │
│   [ Tự nấu ]  [ Đặt giao ]  [ Đi ăn ]  [ Ăn cùng nhóm ] │
└───────────────────────────────────────────────────────────┘
        ↓             ↓              ↓             ↓
   Recipe DB    GrabFood/Shopee   Maps+Booking   Group Voting
```

**6 AI Engines:**
1. 🧠 **Food Recommender** — Context-aware (thời tiết, mood, ngân sách, thời gian)
2. 📸 **Fridge Scan** — Vision AI nhận diện nguyên liệu → gợi ý món
3. 💖 **Mood Food** — Emotion-driven menu (cô đơn → cháo, stress → đồ ngọt)
4. 👯 **Group Decision** — Realtime voting + AI consensus
5. 🥗 **Meal Planner** — Lịch ăn 7 ngày, tracking calo/budget
6. 🎤 **Voice Assistant** — "Hey Hà, hôm nay ăn gì?" (Vietnamese NLU)

---

## 📂 Tài liệu chi tiết

### Bộ tài liệu nền tảng (V1)

| File | Nội dung |
|---|---|
| [docs/01-PRODUCT.md](docs/01-PRODUCT.md) | Product concept, feature list, personas, UX flow, user journey |
| [docs/02-DESIGN.md](docs/02-DESIGN.md) | Design system, screen breakdown, animation, motion design |
| [docs/03-TECHNICAL.md](docs/03-TECHNICAL.md) | Architecture, DB schema, API spec, AI workflows, security, scaling |
| [docs/04-BUSINESS.md](docs/04-BUSINESS.md) | Monetization, unit economics, pricing, partnerships |
| [docs/05-GROWTH.md](docs/05-GROWTH.md) | Viral growth, retention, roadmap, expansion, team, financials |

### Bộ tài liệu chuyên sâu (V2 — Visual-first, AI-native, Social ecosystem)

| File | Nội dung |
|---|---|
| [docs/06-VISUAL-FEED.md](docs/06-VISUAL-FEED.md) | TikTok-style home feed, video-first experience, card anatomy, 10 feed sections |
| [docs/07-AI-ENGINES.md](docs/07-AI-ENGINES.md) | Deep dive: Taste Memory, Mood Engine, Viral Engine, Social Matching, Fridge Vision |
| [docs/08-MAP-SOCIAL.md](docs/08-MAP-SOCIAL.md) | Map heatmap, food zones, live crowding, social graph, creator economy |
| [docs/09-RECO-REALTIME.md](docs/09-RECO-REALTIME.md) | Two-tower reco architecture, embeddings, realtime systems, group sync |
| [docs/10-VIRAL-ENGAGE.md](docs/10-VIRAL-ENGAGE.md) | Viral mechanics, retention loops, gamification, TikTok engagement playbook |
| [docs/11-DATA-INGESTION.md](docs/11-DATA-INGESTION.md) | Data acquisition: API partnerships (GrabFood/ShopeeFood/beFood/TikTok), compliant scraping, dedup, 90-day bootstrap |
| [docs/12-LIVE-COOKING-VOICE.md](docs/12-LIVE-COOKING-VOICE.md) | Voice "Hà" pipeline (wake word → ASR → NLU → TTS) + Live Cooking mode with multi-timer & couple co-cook |
| [docs/13-RESTAURANT-CLAIM.md](docs/13-RESTAURANT-CLAIM.md) | Restaurant claim end-to-end: 3-signal verification, owner dashboard, B2B revenue products |

### Code & deliverables

| Path | Content |
|---|---|
| [code/flutter/](code/flutter/) | Full Flutter app: 4 widgets + **17 screens** (Splash, Onboarding, Login, AI Decide stack, Mood, Fridge Scan, Group Voting, Random Wheel, Premium, Profile, Settings, Notifications, Search, Food/Restaurant Detail, Map, Meal Planner, Live Cooking, Voice, Claim) |
| [code/flutter/ios/](code/flutter/ios/) | Fastlane (`Fastfile` + `Appfile`) for iOS builds + `setup-on-vm.sh` for macOS VM provisioning |
| [code/backend/](code/backend/) | NestJS app (11 modules + Admin GraphQL resolvers): auth/OTP, AI orchestrator (7 services), restaurants+claim, groups+realtime voting, orders, subscriptions, notifications; Prisma; Dockerfile; **unit + e2e tests** |
| [code/owner-dashboard/](code/owner-dashboard/) | Next.js 14 + Tailwind dashboard for restaurant owners: login (phone OTP), sidebar, live status control, stats cards, orders + reviews real-time |
| [code/ingestion/](code/ingestion/) | **Scrapers đang dùng (real data):** `scrape_restaurants.py` (OSM Overpass → 14k quán), `scrape_foods_wikipedia.py` (Wikidata/Wikimedia → món + ảnh thật), `gen_city_normalize.py` (chuẩn hoá 62 tỉnh). + Airflow DAGs (TikTok/Foursquare) để dành; dedup `rapidfuzz` |
| [code/sql/](code/sql/) | PostgreSQL schema (60+ tables, PostGIS, triggers) + seed gốc (60 món, 30 quán). **DB thực tế: 14.319 quán + 86 món** đã đổ từ `code/ingestion/` |
| [code/api/openapi.yaml](code/api/openapi.yaml) | OpenAPI 3.1 spec — 60+ endpoints |
| [code/api/postman_collection.json](code/api/postman_collection.json) | Postman ready-to-run collection |
| [code/graphql/admin_schema.graphql](code/graphql/admin_schema.graphql) | Admin GraphQL schema (RBAC directives, queries/mutations/subscriptions) + working resolvers |
| [code/ai/prompts/](code/ai/prompts/) | 32 production prompts (markdown + machine-readable JSON) for Hà, mood, recipe, voice, vision |
| [code/infra/server/](code/infra/server/) | **Self-host** stack for `ServerLinux`: docker-compose.prod.yml (postgres+redis+backend+nginx+certbot+dozzle+watchtower) + bootstrap.sh + deploy.sh + nginx.conf with TLS/WS/rate-limits |
| [code/infra/k8s/](code/infra/k8s/) | Kubernetes (when scale): namespace, configmap, secret, ingress, Argo Rollouts canary 5%→25%→50%→100% with Prometheus AnalysisTemplate auto-rollback |
| [code/infra/terraform/](code/infra/terraform/) | AWS IaC (Series-A+ option): VPC + EKS + RDS Multi-AZ + ElastiCache + S3 + CloudFront + ECR |
| [code/infra/dns/](code/infra/dns/) | DNS setup script (Cloudflare/Porkbun auto-detect) for `tothanhthuy.cloud` + TLS issuance docs |
| [.github/workflows/](.github/workflows/) | 5 workflows: backend CI (lint/test/Trivy/GHCR push), server-deploy (SSH→ServerLinux via Tailscale), ios-vm-build (SSH→macOS VM, Fastlane TestFlight), mobile-ci (Android), backend-deploy (Argo K8s) |
| [pitch/PITCH_DECK.md](pitch/PITCH_DECK.md) | 15-slide Series A pitch deck with speaker notes |

### Production deployment

| Component | Target | Method |
|---|---|---|
| Backend + DB + Cache | `ServerLinux` (`100.100.210.85`, Tailscale) | docker-compose, SSH-deploy from GitHub Actions |
| Owner Dashboard | Same server | docker-compose, deployed alongside backend |
| iOS app (TestFlight) | `vm` (`100.98.136.38`, macOS, Tailscale) | Fastlane via SSH from GitHub Actions |
| Android app | GitHub Actions runner | Build → Firebase App Distribution |
| Domain & TLS | `tothanhthuy.cloud` | DNS API + Let's Encrypt (certbot auto-renew 12h) |
| Data ingestion | Same server (or separate VM) | Airflow `docker compose` |

---

## 🏗️ Tech Stack

### Currently deployed (Phase 1 — LIVE)
**Frontend:** Flutter 3.x (Android APK signed + iOS ký/cài qua devicectl) · **Mapbox Maps SDK** · Next.js 14 (owner dashboard)
**Backend:** NestJS 10 (TypeScript) · PostgreSQL 15 + PostGIS 3.4 · Redis 7 · Prisma 5
**AI:** Heuristic engine (time + mood→tag + ingredient/name) **+ GPT-4o-mini đã wire** (OpenAI key cấu hình, fallback heuristic). Maps **Mapbox** + weather **OpenWeather** đã cấu hình.
**Infra:** Self-host trên `ServerLinux` (docker-compose) · Cloudflare Tunnel (no port exposure) · DNS `tothanhthuy.cloud` (Cloudflare)

### Phase 2 roadmap (planned)
**AI upgrade:** OpenAI GPT-4o-mini cho NLU + voice intent · Vision model (YOLOv8 food fine-tune) cho Fridge Scan thật · Whisper cho voice
**Scale infra:** AWS EKS + RDS Multi-AZ + ElastiCache · S3 + CloudFront cho media · Firebase push · Datadog observability
**Realtime:** Kafka + WebSocket cho Group Voting và live presence

---

## 💰 Why now? (Timing)

1. **AI cost giảm 90%** trong 18 tháng — GPT-4o-mini đủ rẻ để cá nhân hóa cho 10M+ users
2. **Việt Nam đứng top 3 châu Á** về food content TikTok engagement
3. **Online food delivery VN** tăng trưởng 22% CAGR đến 2028
4. **Gen Z (24M người VN)** trưởng thành — họ *expect* AI assistants
5. **GrabFood/Shopee saturation** — họ là rails, không phải decision layer

---

## 👥 Team (placeholder)

- **CEO** — Ex-Grab/Shopee, 10+ năm consumer apps
- **CTO** — Ex-Google AI, PhD ML
- **CPO** — Ex-TikTok Creator Studio
- **Head of Growth** — Scaled Momo từ 5M → 25M users
- **Head of AI** — Ex-VinAI, food computer vision specialist

---

## 🚀 Use of funds ($8M)

```
Engineering (40%)     ████████████████ $3.2M  → 25 engineers, AI infra
Marketing (30%)       ████████████ $2.4M      → TikTok-first, KOL/KOC
Operations (15%)      ██████ $1.2M            → BD restaurants, content ops
Data & AI (10%)       ████ $0.8M              → Vision dataset VN, GPU
Reserve (5%)          ██ $0.4M
```

**Runway:** 24 tháng → đạt $4M MRR, ready for Series B.

---

## 📞 Contact

**Founder:** [Your Name]
**Email:** ndh0408@gmail.com
**Web:** homnayan.gi
**Deck:** [link to deck]
**Demo:** [video URL]

---

*"In Vietnam, food isn't fuel. It's identity, ritual, and conversation. We're building the AI that respects that."*
