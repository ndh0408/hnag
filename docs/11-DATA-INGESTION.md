# 11 — Data Ingestion Strategy

> **Tại sao tài liệu này tồn tại:** AI của HNAG chỉ tốt khi có data. Trước ngày launch, chúng ta cần **≥50K quán Việt + ≥200K menu items + ≥100K food images + ≥1M giờ TikTok food**. Không thể đợi user generate.
>
> **Mục tiêu:** Bootstrap dataset siêu lớn trong 90 ngày — sạch về pháp lý, sạch về kỹ thuật, sạch về thương mại.

---

## ⚠️ 1. Pháp lý & ToS — đọc TRƯỚC khi code

Trước khi bàn kỹ thuật, đây là **5 nguyên tắc bất biến**:

### Nguyên tắc 1 — Robots.txt + ToS không thể bỏ qua
- Đọc `robots.txt` và **Terms of Service** của mọi platform trước khi scrape
- Một số phần (vd. price, menu listing) thường được phép; một số (vd. user reviews + PII) thì không
- Khi không chắc → consult lawyer (~$2K USD cho 1 đợt audit)

### Nguyên tắc 2 — Public Data vs Private Data
- ✅ **Public, không cần login:** thường an toàn (vd. trang menu công khai của quán)
- ⚠️ **Cần login user:** vùng xám — không scrape qua tài khoản user thật
- ❌ **PII (số ĐT, email, địa chỉ nhà cá nhân):** không thu thập

### Nguyên tắc 3 — Rate limit + identify
- Set User-Agent identifying ourselves: `HNAGBot/1.0 (+https://tothanhthuy.cloud/bot)`
- Respect Crawl-delay
- 1 request/giây, không DDoS
- Cache aggressive để tránh re-fetch

### Nguyên tắc 4 — Pháp luật Việt Nam
- **Nghị định 13/2023/NĐ-CP** về bảo vệ dữ liệu cá nhân
- **Luật An ninh mạng 2018** — lưu trữ dữ liệu VN tại VN
- **Luật Sở hữu trí tuệ** — không sao chép content (chỉ metadata + fact)

### Nguyên tắc 5 — Prefer official partnerships
- Always **try API official trước** (BD outreach)
- Scraping = fallback khi không có API
- Mua data từ provider chính thức nếu có (Foody, Foursquare, Mapbox)

---

## 2. Data sources prioritized (ưu tiên từ trên xuống)

### 🥇 Tier 1 — Official partnerships (best ROI)

#### A. GrabFood / Grab Holdings
- **Approach:** Partnership BD outreach → Grab API hoặc affiliate API
- **What we get:** Restaurant list, menu, price, photos, delivery time, reviews count
- **Cost:** Revenue share (5-8% commission cho referred orders)
- **Timeline:** 2-4 tháng để sign hợp đồng
- **Contact:** affiliate@grab.com / vietnam.partnerships@grab.com
- **Backup:** Grab có public restaurant pages — fetch metadata only (no scrape orders)

#### B. ShopeeFood (Sea Group)
- **Approach:** Shopee Partner Program + Sea Group Vietnam BD
- **What we get:** Tương tự GrabFood
- **Cost:** Commission-based
- **Note:** Shopee có chương trình affiliate marketplace API — apply qua [Shopee Open Platform](https://open.shopee.com/)

#### C. beFood (Be Group)
- **Approach:** Be Group Vietnam BD
- **What we get:** Vietnam-native data, often deeper coverage tỉnh
- **Advantage:** Be sẵn sàng cooperate hơn (smaller, hungrier)

#### D. Gojek / GoFood Vietnam
- **Status:** Đã rút khỏi VN 2021, nhưng dataset cũ có thể mua qua [Gojek Data Partners](https://www.gojek.com/about/)

#### E. Foursquare API (global)
- **API:** [Places API](https://developer.foursquare.com/)
- **Pricing:** $0–$1000/tháng (free tier 50K calls/mo)
- **What we get:** 100M+ POIs toàn cầu, có rich data VN
- **Use case:** Bootstrap initial restaurant list, geocoding, photos

#### F. Google Places API
- **Pricing:** $17 per 1K Place Details requests (đắt at scale)
- **Coverage:** Tốt cho VN tỉnh + photos + reviews count
- **Use case:** Enrichment, không phải primary source

#### G. Foody.vn (Now Group / GoBiz)
- **Status:** Hiện sáp nhập vào Shopee — có thể access qua deal
- **Dataset:** 500K+ restaurants VN — lớn nhất

### 🥈 Tier 2 — Public scraping (cẩn thận pháp lý)

#### H. TikTok Content API
- **Official:** [TikTok for Developers](https://developers.tiktok.com/) — Content Posting + Research APIs
- **Research API:** Hashtag, video metadata, captions
- **Free tier:** Tối đa 1000 requests/ngày
- **Compliance:** Phải apply + signed agreement, KHÔNG scrape direct
- **What we get:** Viral food videos, trends, creator info

#### I. Facebook Graph API
- **Pages API:** Cho phép fetch public Page posts (restaurant Facebook pages)
- **Approval required:** App review
- **What we get:** Restaurant photos, menu posts, opening hours, events

#### J. Instagram Basic Display API
- **Use:** Connect creator accounts (with their permission) for content
- **Note:** Cannot scrape public Instagram

#### K. YouTube Data API
- **Free tier:** 10K units/day
- **What we get:** Cooking videos, recipe tutorials, food vlogs

### 🥉 Tier 3 — Permitted public scraping (chỉ metadata, không content)

#### L. Restaurant websites + review aggregators
- Foody, Lozi, Diadiemanuong, TripAdvisor VN
- Scrape **public restaurant info** (name, address, hours, phone) — facts
- KHÔNG sao chép review content full text (copyright)
- KHÔNG scrape sau login

#### M. Wikipedia / Wikivoyage
- Open license — free to use
- Source for cuisine knowledge, food history, regional info

#### N. Government / open data
- TP.HCM open data portal: `https://data.hochiminhcity.gov.vn/`
- Tổng cục Du lịch VN
- Bộ Y tế (nutrition facts cho món Việt)

### Tier 4 — User-generated (sau khi launch)

- User uploads (reviews + photos)
- Creator program contributions
- Verified restaurant claim (owner adds menu)
- Affiliate partners share back

---

## 3. Architecture đề xuất

```
                  ┌─────────────────────────────────────┐
                  │   INGESTION ORCHESTRATOR (Airflow)  │
                  │   - Schedules jobs                  │
                  │   - Retry / dedup                   │
                  │   - Rate limit per source           │
                  └─────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
┌───────▼────────┐         ┌────────▼────────┐         ┌────────▼────────┐
│ Partner APIs   │         │ Public scrapers │         │ Open datasets   │
│ - GrabFood     │         │ - Foody (meta)  │         │ - Foursquare    │
│ - ShopeeFood   │         │ - Lozi (meta)   │         │ - Wikipedia     │
│ - beFood       │         │ - FB pages      │         │ - Gov open data │
│ - TikTok       │         │ - Google places │         │                 │
└───────┬────────┘         └────────┬────────┘         └────────┬────────┘
        │                           │                           │
        └───────────────────────────┼───────────────────────────┘
                                    │
                          ┌─────────▼──────────┐
                          │   RAW LAKE (S3)    │
                          │   immutable        │
                          │   per source/date  │
                          └─────────┬──────────┘
                                    │
                          ┌─────────▼──────────────┐
                          │   NORMALIZATION        │
                          │   - schema mapping     │
                          │   - geocoding          │
                          │   - dedup (fuzzy match)│
                          │   - quality scoring    │
                          └─────────┬──────────────┘
                                    │
                          ┌─────────▼──────────────┐
                          │   ENRICHMENT           │
                          │   - AI tagging         │
                          │   - cuisine classify   │
                          │   - mood/vibe inferred │
                          │   - vision (food/menu) │
                          │   - embeddings         │
                          └─────────┬──────────────┘
                                    │
                          ┌─────────▼──────────────┐
                          │   CANONICAL STORE      │
                          │   - PostgreSQL master  │
                          │   - Pinecone vectors   │
                          │   - Elasticsearch index│
                          └────────────────────────┘
```

---

## 4. Data schema (canonical)

### 4.1 Restaurant canonical record

```json
{
  "canonical_id": "uuid",
  "name": "Phở Lý Quốc Sư",
  "name_normalized": "pho ly quoc su",
  "address": "...",
  "city": "Hà Nội",
  "district": "Hoàn Kiếm",
  "location": { "lat": 21.0306, "lng": 105.8504 },
  "phone": "...",
  "open_hours": { "mon": "6:00-22:00", ... },
  "sources": [
    { "source": "grabfood", "source_id": "abc123", "url": "...", "first_seen": "2026-01-15", "last_synced": "2026-05-19" },
    { "source": "foody",    "source_id": "xyz789", "url": "..." },
    { "source": "foursquare", "source_id": "fs_...", "fsq_categories": [...] }
  ],
  "quality_score": 0.92,
  "verification_status": "auto" | "manual" | "claimed",
  "merged_from": ["uuid1", "uuid2"]
}
```

### 4.2 Food/menu item canonical

```json
{
  "canonical_id": "uuid",
  "name_vi": "Phở bò tái",
  "aliases": ["pho bo tai", "phở bò tái nạm"],
  "category": "noodle",
  "cuisine": "vietnamese",
  "region": "bac",
  "embeddings_id": "pinecone:foods:abc",
  "image_urls": ["s3://...", "cdn://..."],
  "menu_appearances": [
    { "restaurant_id": "...", "price_vnd": 55000, "last_seen": "..." }
  ]
}
```

### 4.3 Source raw record (immutable)

```json
{
  "source": "grabfood",
  "source_id": "restaurant_abc123",
  "raw_payload": { ... },  // exactly what we got
  "fetched_at": "2026-05-19T10:30:00Z",
  "url": "https://...",
  "fetch_method": "api" | "scrape",
  "checksum": "sha256:..."
}
```

---

## 5. Deduplication strategy

Mỗi quán có thể xuất hiện ở 5+ nguồn với tên/địa chỉ hơi khác. Dedup quan trọng.

### 5.1 Multi-signal matching

```python
def match_score(a, b):
    name_sim = fuzzy_ratio(normalize_vi(a.name), normalize_vi(b.name))  # 0-1
    addr_sim = address_similarity(a.address, b.address)
    geo_dist = haversine(a.location, b.location)  # meters
    phone_match = a.phone == b.phone if both else None
    
    score = 0
    if phone_match == True: score += 0.5
    if geo_dist < 50: score += 0.3       # within 50m = same building
    elif geo_dist < 200: score += 0.15
    score += name_sim * 0.3
    score += addr_sim * 0.2
    
    return score  # >0.75 = likely match
```

### 5.2 Confirmation logic
- Score > 0.85 → auto-merge
- Score 0.65–0.85 → flag for human review
- Score < 0.65 → keep separate

### 5.3 Vietnamese-specific normalization
- Strip diacritics (phở → pho) for matching, but preserve in display
- Common abbreviations: Q.1 → Quận 1, P.Bến Thành → Phường Bến Thành
- Address standardization: TP.HCM = HCM = Saigon = Sài Gòn

---

## 6. AI enrichment pipeline

Mỗi quán/món được enrich tự động:

### 6.1 Restaurant enrichment
```python
def enrich_restaurant(r):
    r.cuisine_tags     = classify_cuisine_from_name_menu(r)
    r.vibe_tags        = infer_vibe_from_reviews_photos(r)
    r.price_level      = compute_from_menu_prices(r)
    r.feature_tags     = detect_features(r)  # wifi, parking, ...
    r.mood_match       = mood_inference(r.reviews, r.photos)
    r.embedding        = generate_embedding(r)
    r.description_ai   = llm_summarize(r)
    r.quality_score    = compute_quality(r)
    return r
```

### 6.2 Menu/food enrichment
```python
def enrich_food(f):
    f.flavor_tags     = vision_food_classify(f.image)
    f.allergens       = detect_allergens(f.ingredients_text)
    f.diet_tags       = classify_diet(f)
    f.mood_tags       = mood_food_map(f)
    f.calorie_estimate= llm_estimate_cal(f)
    f.embedding       = generate_embedding(f.name + f.description)
    return f
```

### 6.3 Image processing
```python
def process_image(url):
    img = download(url)
    if is_blurry(img): skip()
    if is_food(img):
        bboxes = yolo_detect(img)
        tags   = clip_classify(img)
        save_to_cdn(img, variants=['480','720','1080'])
        return { 'url': cdn_url, 'tags': tags, 'bboxes': bboxes }
```

---

## 7. Scraper implementation patterns (template)

### 7.1 General scraping rules

```python
class BaseScraper:
    rate_limit_qps = 1.0
    user_agent     = "HNAGBot/1.0 (+https://tothanhthuy.cloud/bot)"
    cache_ttl_h    = 168  # 7 days
    
    async def fetch(self, url):
        # Check cache first
        cached = await self.cache.get(url)
        if cached and not cached.stale: return cached.body
        
        # Respect robots.txt
        if not await self.robots.allowed(url):
            raise RobotsBlocked(url)
        
        # Rate limit
        async with self.rate_limiter:
            resp = await self.client.get(url, headers={'User-Agent': self.user_agent})
        
        if resp.status >= 400: handle_error()
        
        await self.cache.set(url, resp.body)
        return resp.body
```

### 7.2 Foody scraper sketch (public pages only)

```python
class FoodyScraper(BaseScraper):
    base = "https://www.foody.vn"
    
    async def list_restaurants_in_district(self, city, district):
        url = f"{self.base}/an-uong/{slugify(city)}/{slugify(district)}"
        html = await self.fetch(url)
        return parse_restaurant_links(html)
    
    async def restaurant_metadata(self, url):
        html = await self.fetch(url)
        return {
            'name': extract_name(html),
            'address': extract_address(html),
            'phone': extract_phone(html),
            'hours': extract_hours(html),
            'photos_urls': extract_photo_urls(html),
            # DO NOT extract review text — copyright
        }
```

### 7.3 Restaurant menu OCR pipeline

Many restaurants don't expose menu API. We OCR public menu photos:

```python
async def ocr_menu(photo_url):
    img = download(photo_url)
    text = await ocr_api(img)  # Google Cloud Vision OCR
    items = llm_extract_menu_items(text)  # Use prompt to parse
    for item in items:
        item.price = parse_vnd(item.price_text)
        item.canonical_food_id = match_to_food_catalog(item.name)
    return items
```

---

## 8. TikTok / viral ingestion (compliant)

### 8.1 Official TikTok Research API

```python
class TikTokIngestion:
    endpoint = "https://open.tiktokapis.com/v2/research/video/query/"
    
    async def search_food_videos(self, hashtag, since, until):
        body = {
            "query": {
                "and": [
                    {"operation": "IN", "field_name": "hashtag_name", "field_values": [hashtag]},
                    {"operation": "GTE", "field_name": "create_date", "field_values": [since]},
                    {"operation": "LTE", "field_name": "create_date", "field_values": [until]}
                ]
            },
            "fields": ["id", "video_description", "create_time", "username", "view_count", "like_count"],
            "max_count": 100
        }
        return await self.client.post(self.endpoint, json=body, headers=self.auth)
```

### 8.2 Vietnamese food hashtags watchlist

```yaml
# Curated watchlist — auto-updated
hashtags:
  - monan
  - anuong
  - foodtour
  - saigonfood
  - hanoifood
  - reviewquan
  - lokoton           # Saigon street food
  - vietnamesefood
  - andongngon        # ăn đông ngon
  - banhmiviet
  - phohanoi
  - quanngon
  - taynguyenfood
  - mientay
  # add 50+ more
```

### 8.3 Video analysis pipeline

```python
async def analyze_video(tiktok_video):
    # 1. Get keyframes
    frames = extract_keyframes(tiktok_video.url, n=5)
    
    # 2. Vision analysis
    detections = [yolo_detect_food(f) for f in frames]
    
    # 3. Caption analysis
    caption_dishes = nlu_extract_dishes(tiktok_video.description)
    
    # 4. ASR audio
    transcript = whisper(tiktok_video.audio, lang='vi')
    audio_dishes = nlu_extract_dishes(transcript)
    
    # 5. Restaurant mention
    mentions = extract_restaurant_mentions(transcript + tiktok_video.description)
    
    # 6. Cross-validate
    dish_consensus = consensus(detections, caption_dishes, audio_dishes)
    
    return ViralVideoAnalysis(
        dish=dish_consensus,
        confidence=...,
        restaurants_mentioned=mentions,
        quality_score=...,
    )
```

### 8.4 Match viral → local restaurants

After detecting "Bánh tráng cuốn thịt heo" is trending:
```python
def find_nearby_serving_dish(dish_name, user_location, radius_km=5):
    # Search ES for restaurants whose menu contains this dish
    candidates = es.search(
        index='menu_items',
        query={'match': {'name_vi': dish_name}},
        filter={'geo_distance': {'distance': f'{radius_km}km', 'location': user_location}}
    )
    # Rank by rating + recent_orders + verified
    return rank(candidates)
```

---

## 9. Data quality framework

### 9.1 Quality score formula

```python
def quality_score(restaurant):
    score = 0
    # Completeness (50%)
    score += 0.05 if r.name else 0
    score += 0.10 if r.address else 0
    score += 0.05 if r.phone else 0
    score += 0.05 if r.hours else 0
    score += 0.10 if len(r.photos) >= 3 else (0.05 if r.photos else 0)
    score += 0.10 if r.menu_items_count >= 5 else 0
    score += 0.05 if r.cuisine_tags else 0
    
    # Verification (20%)
    score += 0.10 if r.is_verified else 0
    score += 0.05 if r.claimed_by_owner else 0
    score += 0.05 if r.gps_verified else 0
    
    # Cross-source agreement (15%)
    sources_count = len(r.sources)
    score += min(sources_count * 0.05, 0.15)
    
    # Recency (10%)
    days_since_update = (now - r.last_synced).days
    score += max(0, 0.10 - days_since_update * 0.001)
    
    # Engagement (5%)
    score += min(r.rating_count / 100 * 0.05, 0.05)
    
    return score
```

### 9.2 Filtering

- **For public display:** quality ≥ 0.45
- **For AI recommendations:** quality ≥ 0.6
- **For featured/sponsored slots:** quality ≥ 0.8 + verified
- Below 0.3: archived, not shown

---

## 10. Refresh cadence

| Data type | Refresh frequency |
|-----------|-------------------|
| Restaurant master record | Monthly |
| Open hours / closed status | Weekly + user report |
| Menu items + prices | Bi-weekly |
| Restaurant photos | Monthly |
| Reviews count + avg rating | Daily |
| TikTok viral videos | Hourly |
| Order volume (partner data) | Real-time webhook |
| Weather context | 1 hour |

---

## 11. Infrastructure & cost

### 11.1 Compute

| Component | Type | Monthly cost |
|-----------|------|--------------|
| Airflow scheduler | t3.medium | $40 |
| Scraper workers | 4× t3.large | $240 |
| OCR processing | Google Vision API | $300 (50K menus/mo) |
| Vision inference (GPU) | g4dn.xlarge | $380 |
| Storage S3 raw | 500 GB | $12 |
| Storage CDN images | 2 TB | $180 |
| Pinecone vector DB | Standard | $200 |
| Elasticsearch | r6g.xlarge | $250 |
| Datadog scraping monitor | — | $80 |
| **Total** | | **~$1700/mo** |

### 11.2 LLM costs for enrichment

| Task | Volume | Cost/mo |
|------|--------|---------|
| Restaurant description AI | 5K/mo | $50 |
| Menu OCR + parse | 50K items | $400 |
| TikTok video analysis | 20K videos | $300 |
| Quality scoring | All records | $50 |
| **Total** | | **$800/mo** |

### 11.3 Data partner costs

| Partner | Setup | Monthly |
|---------|-------|---------|
| Foursquare API | — | $500 |
| Google Places | — | $1000 (variable) |
| Foody dataset license | $20K one-time | — |
| TikTok Research API | $0 | $0 |
| Mapbox Maps | — | $400 |

**Total Year 1 ingestion budget:** **~$60K** + Foody one-time.

---

## 12. Privacy & compliance checklist

- [ ] All scraping respects robots.txt
- [ ] User-Agent identifies HNAGBot
- [ ] No PII collected from public scrapes
- [ ] DPA signed with each partner API
- [ ] VN data stored in VN region (per Cybersecurity Law)
- [ ] Restaurant owner takedown request → SLA 48h
- [ ] Annual third-party data audit
- [ ] Privacy policy lists all sources
- [ ] Legal opinion letter on file for ambiguous sources
- [ ] Crawl-delay respected (min 1s between requests to same host)

---

## 13. Restaurant claim & feedback loop

Once a restaurant is in our DB, **owners can claim**:

```
"This is my restaurant" → verify via:
  - Phone OTP to business phone on file
  - Photo of business license
  - Geo-verified visit
       ↓
Owner gets dashboard:
  - Edit menu, hours, photos
  - Mark items unavailable in real-time
  - Respond to reviews
  - Boost campaigns (paid)
```

This gives us **highest-quality data** AND a revenue stream.

---

## 14. Crowdsourcing layer

Power users (Foodie level Cua+) can:
- Submit new restaurants (XP reward)
- Photo upload (XP)
- Correct existing data
- Mark "closed permanently"
- Flag incorrect info

**Quality control:** every edit triggers review queue + reputation-weighted approval.

---

## 15. Bootstrap roadmap (first 90 days)

### Month 1
- [ ] Foursquare integration → 100K POI VN
- [ ] Foody dataset purchase + import → 500K restaurants
- [ ] BD outreach: Grab, Shopee, Be (parallel)
- [ ] TikTok Research API access (apply day 1)
- [ ] Build scraper infra

### Month 2
- [ ] Foody scraper for missing fields (hours, phones)
- [ ] Menu OCR from public photos
- [ ] Vision enrichment pipeline (50K food images)
- [ ] Deduplication run #1
- [ ] First Grab API integration (if signed)

### Month 3
- [ ] TikTok ingestion live + viral detection
- [ ] Quality scores rolled out
- [ ] 20 restaurant claim onboarding (manual + system)
- [ ] Coverage map (any gaps in tỉnh?)
- [ ] Public launch with ≥80% restaurant coverage in HCM + HN

**Target end of Month 3:**
- 100K+ restaurants, 200K+ menu items, 100K+ food images
- 80% have ≥3 sources confirming
- 60% quality ≥ 0.6

---

## 16. Vendor evaluation matrix (decisions log)

| Source | Coverage VN | Cost | Legal | Latency | Decision |
|--------|-------------|------|-------|---------|----------|
| Foursquare | 90% | $$ | Clean | Real-time | ✅ Year 1 baseline |
| Google Places | 95% | $$$ | Clean | Real-time | ✅ Enrichment |
| Foody (license) | 99% | $$$$ one-time | Clean | Batch | ✅ Bootstrap |
| GrabFood API | 100% chains | Rev share | Clean | Real-time | 🎯 Sign partnership |
| ShopeeFood | 100% chains | Rev share | Clean | Real-time | 🎯 Sign partnership |
| Direct scrape (Foody) | 99% | Free | ⚠️ ToS check | Slow | ⚠️ Tier 2 fallback |
| Crowdsource | Growing | Free | Clean | Slow | ✅ Year 1 secondary |
| TikTok Research | Trending only | Free | Clean | API quota | ✅ For viral engine |

---

## 17. Failure scenarios & mitigations

| Risk | Mitigation |
|------|-----------|
| GrabFood denies partnership | Plan B: Foursquare + Foody + crowdsource |
| Foody license too expensive | Negotiate or scrape public only |
| TikTok API quota too low | Buy enhanced tier ($5K/mo) |
| Scraper banned (IP block) | Rotating proxy pool (Smartproxy) |
| Data quality below threshold | Manual review team (5 ops staff) |
| Legal challenge | Lawyer on retainer; immediate takedown SLA |
| Source goes down (Foursquare outage) | Multi-source resilience — never single point |

---

## 18. KPIs for data team

| Metric | Target Month 3 | Year 1 |
|--------|---------------|--------|
| Restaurants in DB | 100K | 300K |
| Restaurants with quality ≥ 0.6 | 60K | 240K |
| Menu items | 200K | 1M |
| Food images | 100K | 500K |
| Viral dishes detected/week | 50 | 200 |
| Avg sources per restaurant | 2.0 | 3.5 |
| Daily refresh latency p95 | 24h | 12h |
| Restaurant owner claim rate | 5% | 25% |

---

## 19. Sample API integration code

### 19.1 Foursquare integration

```typescript
// services/ingestion/foursquare.ts
import axios from 'axios';

export async function fetchVietnamRestaurants(city: string, near: GeoPoint) {
  const resp = await axios.get('https://api.foursquare.com/v3/places/search', {
    headers: { Authorization: process.env.FSQ_API_KEY! },
    params: {
      ll: `${near.lat},${near.lng}`,
      radius: 50000,             // 50km
      categories: '13065',        // Restaurants
      limit: 50,
      fields: 'fsq_id,name,location,categories,tel,hours,rating,photos,website'
    }
  });
  return resp.data.results.map(toCanonicalRestaurant);
}
```

### 19.2 GrabFood-style partner webhook receiver

```typescript
// services/ingestion/grab_webhook.ts
app.post('/webhook/grab', verifyHmac, async (req, res) => {
  const event = req.body;
  switch (event.type) {
    case 'restaurant.updated':
      await upsertRestaurant(event.data);
      break;
    case 'menu.updated':
      await refreshMenu(event.restaurant_id);
      break;
    case 'order.completed':
      await recordOrderEvent(event.data);
      break;
  }
  res.json({ ok: true });
});
```

### 19.3 TikTok ingestion job (Airflow DAG)

```python
# dags/tiktok_viral_food_vn.py
from airflow import DAG
from airflow.operators.python import PythonOperator

with DAG('tiktok_viral_food_vn', schedule='0 */1 * * *') as dag:
    fetch = PythonOperator(task_id='fetch', python_callable=fetch_food_hashtag_videos)
    analyze = PythonOperator(task_id='analyze', python_callable=analyze_videos)
    cluster = PythonOperator(task_id='cluster', python_callable=cluster_trending_dishes)
    notify = PythonOperator(task_id='notify_engine', python_callable=publish_to_viral_engine)
    
    fetch >> analyze >> cluster >> notify
```

---

## 20. Closing notes

The fundamental insight:
> **Our recommendation AI is only as good as our data.**
> **Our data is only as good as our ingestion pipeline.**
> **Our ingestion pipeline is what separates us from yet-another-food-app.**

Investing $60K/year in data + 3 data engineers gets us a moat that takes competitors 3+ years to replicate.

This is where Series A money meaningfully goes. **Get this right, everything else compounds.**

---

**See also:**
- [docs/03-TECHNICAL.md](03-TECHNICAL.md) — infrastructure context
- [docs/07-AI-ENGINES.md](07-AI-ENGINES.md) — how data feeds AI
- [docs/08-MAP-SOCIAL.md](08-MAP-SOCIAL.md) — map layer needs this data
- [docs/04-BUSINESS.md](04-BUSINESS.md) — partnership economics
