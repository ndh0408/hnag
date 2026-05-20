# 04 — Business Model, Monetization & Unit Economics

> **Thesis:** The decision-layer captures value across the **entire food stack** — from groceries to delivery to dine-in. We don't compete with GrabFood; **we sit above it**.

---

## 1. Market Sizing

### 1.1 TAM (Vietnam Food Spend, 2026)
| Segment | Value (USD) |
|---------|-------------|
| Dine-in & street food | $28B |
| Groceries (consumer cooking) | $10B |
| Online food delivery | $4B |
| **Total TAM** | **$42B** |

### 1.2 SAM — addressable
- Smartphone users 18–45 in tier-1 cities: **18M people**
- Avg food spend $25/month online + $80/month dine-in/groceries adjacent
- → **$6.8B SAM**

### 1.3 SOM Year 3
- 12M MAU × $1.25 ARPU/month = **$180M ARR potential**
- Realistic Year 3: **$48M ARR** (1.3% take rate on transactions + premium + ads)

---

## 2. Revenue Streams (7-layer cake)

### 2.1 R1 — Subscription "HNAG+" (40% of revenue Y3)
- **Pricing:** 49k ₫/month or 399k ₫/year (32% discount)
- **Free trial:** 7 days
- **Conversion benchmark target:** 4% of MAU → premium
- **At 12M MAU:** 480K paying users × ~33k avg/month = **$6.4M/month → $77M ARR** (LTV-positive)

**Premium features summary:**
- Unlimited AI suggestions
- Full meal planner + grocery auto-list
- Macro tracking + Health sync
- Hà voice personalization
- Exclusive recipes (chef partnerships)
- No ads
- Priority support
- Family plan: +49k/year per family member

### 2.2 R2 — Delivery commission (20% of revenue Y3)
- Affiliate referral fee from GrabFood/ShopeeFood/beFood
- **Rate:** 5–8% of order value per referred order
- **At 600K daily orders × $4 avg × 6%:** **$144K/day → $52M/year**
- Negotiate higher rates as we control demand signal (decision layer)

### 2.3 R3 — Booking & Reservations (8%)
- Restaurant table booking integration (TableNow, ezDining, direct)
- Per-cover fee: 5–15k ₫/cover
- Cancellation insurance: 10k flat fee
- **Estimate Y3:** $4M

### 2.4 R4 — Sponsored Restaurants & Foods (15%)
- "Sponsored" slot in feed (clearly labeled)
- Performance pricing: CPM, CPC, CPA models
- Restaurant boost campaigns: 500k–10M ₫/campaign
- Brand campaigns (Heineken food pairings, etc.)
- **Estimate Y3:** $7M

### 2.5 R5 — Sponsored Recipes (Brand)
- Knorr, Maggi, Vinamilk recipes
- "Brought to you by [brand]" tasteful integration
- **Estimate Y3:** $2.5M

### 2.6 R6 — Grocery & Ingredient Affiliate (10%)
- "Mua nguyên liệu" → BachhoaXANH, GrabMart, Annam Gourmet
- 4–7% commission
- AI fridge scan increases attach rate
- **Estimate Y3:** $5M

### 2.7 R7 — Data Insights B2B (5%)
- Anonymized trend reports for restaurants/CPGs
- "What's hot in District 2 this week" — $500–2000/month subscription
- White-label decision API for restaurant chains
- **Estimate Y3:** $2.5M

### 2.8 Total Year 3 Revenue Model
```
R1 Subscription          $19.2M   (40%)
R2 Delivery commission   $9.6M    (20%)
R3 Booking               $3.8M    (8%)
R4 Sponsored             $7.2M    (15%)
R5 Brand recipes         $2.4M    (5%)
R6 Grocery affiliate     $4.8M    (10%)
R7 Data B2B              $1.2M    (2.5%)
                         ─────
                          $48M ARR
```

---

## 3. Unit Economics

### 3.1 Per Free User (monthly)

| Item | Value |
|------|-------|
| AI cost (compute) | -$0.18 |
| Infrastructure | -$0.06 |
| Push/SMS | -$0.02 |
| **Total cost** | **-$0.26/mo** |
| Ad + affiliate revenue | +$0.42 |
| **Contribution margin** | **+$0.16/mo** |

Free user pays for themselves via ads/affiliate. ✅

### 3.2 Per Premium User

| Item | Value |
|------|-------|
| Subscription revenue (avg, blended monthly) | +$1.55 |
| AI cost (heavier usage 2x) | -$0.36 |
| Infra | -$0.09 |
| Payment processing | -$0.05 |
| **Contribution margin** | **+$1.05/mo** |
| **Annualized contribution** | **+$12.6** |

### 3.3 CAC / LTV

| Metric | Value |
|--------|-------|
| Blended CAC (Y1) | $1.20 |
| Blended CAC (Y3 — viral coefficient kicks in) | $0.60 |
| Free user LTV (12-mo retention) | $1.92 |
| Premium user LTV (24-mo retention) | $25.2 |
| **Blended LTV** | **$5.4** |
| **LTV/CAC (Y3)** | **9.0×** |

Healthy threshold: ≥3×. We target 6–9× by Y3.

### 3.4 Payback period
- Premium: 1.1 months (excellent)
- Free: 7 months (acceptable as funnel feeder)

---

## 4. Pricing Strategy

### 4.1 Pricing Anchors
- Spotify Premium VN: 59k/mo → we're cheaper
- Netflix VN: 70k/mo
- Headspace: 89k/mo
- Coffee at café: 45k/cup
- **Our positioning:** "1 ly cà phê / tháng đổi lấy AI quyết định giúp bạn 30 lần"

### 4.2 Tiers

**Free**
- 10 AI suggestions/day
- 3 fridge scans/day
- Basic mood food
- Standard ads
- Up to 50 saved items

**HNAG+ (49k/mo)**
- Unlimited everything
- Full meal planner
- Macro tracking + Apple Health
- Hà voice personalization
- Premium recipes
- No ads
- 500 saved items + collections
- Priority AI (faster)

**HNAG Pro Family (99k/mo, 4 seats)**
- Everything in HNAG+
- Couple mode + family planner
- Shared grocery list
- Family wallet view (budget split)

**HNAG Business (TBD — Y2)**
- For restaurants: analytics + sponsored placement
- Custom recipe library
- White-label decision API

### 4.3 Pricing experiments planned
- Annual vs monthly discount (start 32%)
- Bundle: HNAG+ × Apple Music VN
- Student pricing (50% off with .edu)
- Buy 1 give 1 (premium charity tier)

---

## 5. Partnerships

### 5.1 Delivery Partners
- **GrabFood, ShopeeFood, beFood, Loship, Now** — affiliate links + deep API for tracking
- **Tactic:** start as affiliate, prove demand value → negotiate co-marketing
- **Killer angle:** we're a *demand generator*, not competitor

### 5.2 Restaurant Partners
- Tier 1: chain restaurants (Pizza 4P's, Highlands, The Coffee House) — direct API
- Tier 2: mid-size — TableNow / direct claim
- Tier 3: street food — community-sourced (gamified by users)

### 5.3 Brand Partners
- CPG: Knorr, Maggi, Ajinomoto, Vinamilk, TH True Milk
- Beverages: Heineken, Coca-Cola for food pairings
- Health: Decathlon (fitness gear bundle for users with goal=lose-weight)

### 5.4 Content Creators / KOC
- 500 micro food KOCs in Year 1
- Profit share: tips, paid reviews, exclusive deals
- "HNAG Creator Program" — verified creators with revenue share

### 5.5 Payment & FinTech
- Momo, ZaloPay, VNPay — subscription payment
- Apple Pay / Google Pay for iOS/Android
- Stripe for international card

### 5.6 Health & Wellness
- Apple Health, Google Fit, Samsung Health, Garmin
- VinMec (telehealth food consults — Y2)

### 5.7 Data Partners
- Weather: OpenWeather, AccuWeather
- Maps: Mapbox + Vietmap fallback
- TikTok content API (limited)

---

## 6. Funnel & Conversion

```
App Install            100,000 (CAC $1.20 each)
  ↓ 75% complete onboarding
Onboarded              75,000
  ↓ 60% try AI suggest within first session
First Decision         45,000
  ↓ 40% return Day 2
Day-2 retained         18,000
  ↓ 35% retained Day 30
MAU                    15,750
  ↓ 4% convert to premium
Paying Premium         630
  ↓ 70% retain Year 1
Long-term Premium      441
```

**Cost per paying user (Y1):** ~$190
**LTV paying user:** $25 (24-mo)
**Net loss per user Y1:** -$165 → recouped via free-user ads + sponsored + organic referral

Year 3 with viral loop: CPU drops to $35 → LTV/CAC > 7×.

---

## 7. Cost Structure (Year 1 actual budget)

```
People (20 FTE avg):                            $1.6M
  - Engineering 10                $720K
  - Design 3                      $216K
  - Product 2                     $192K
  - AI/ML 3                       $270K
  - Ops/BD 2                      $96K

Marketing:                                       $1.2M
  - Performance ads               $720K
  - KOL/KOC sponsorships          $300K
  - Content production            $180K

Infrastructure & AI:                            $0.45M
  - AWS                            $180K
  - OpenAI/Anthropic API           $144K
  - 3rd party (Mapbox, FCM...)    $80K
  - Datadog/Sentry                $45K

Operations:                                     $0.32M
  - Restaurant data acquisition   $120K
  - Customer support              $96K
  - Legal/Compliance              $60K
  - Office, misc                  $45K

Other:                                          $0.18M

TOTAL Year 1:                                   $3.75M
Revenue Year 1:                                 $1.2M
Burn Year 1:                                    $2.55M
```

---

## 8. Burn Plan (24 months on $8M raise)

```
Quarter   Burn      Cum Burn   Revenue   ARR    MAU
Q1        $0.6M     $0.6M      $0       $0     100K
Q2        $0.7M     $1.3M      $30K     $360K   300K
Q3        $0.9M     $2.2M      $120K    $1.2M   600K
Q4        $1.0M     $3.2M      $260K    $2.4M   1.2M
Q5        $1.1M     $4.3M      $420K    $4.0M   2.0M
Q6        $1.2M     $5.5M      $640K    $6.5M   3.0M
Q7        $1.2M     $6.7M      $900K    $9.6M   4.2M
Q8        $1.3M     $8.0M      $1.25M   $14M    5.5M
```

End of month 24: **$14M ARR, 5.5M MAU, ready for Series B ($30M)**.

---

## 9. Comparable Exits / Valuation Multiples

| Company | Region | Stage | Valuation | Multiple |
|---------|--------|-------|-----------|----------|
| Mealime (US) | recipe app | Acquired Stripe | undisclosed |
| Yummly | US | Whirlpool acq. | $700M | 12x rev |
| HelloFresh | DE | Public | $4B | 1.5x rev |
| Grubhub | US | Acq. JustEat | $7.3B | 5x rev |
| Cookpad | JP | Public | $200M (down) | 3x rev |
| Foodpanda APAC | Acq. by Delivery Hero | $3.8B | 4x rev |

**HNAG benchmark exit (Year 5):** $300M–$800M, 6–12× ARR multiple given AI premium + SEA expansion.

---

## 10. Why we win

### 10.1 Strategic moat (3 layers)

1. **Data flywheel** — every swipe trains the model. Competitors need years to catch up to our food-VN dataset.
2. **Social graph** — friends, couples, families link accounts. Switching cost = leaving your circle.
3. **Decision habit** — daily "Hôm nay ăn gì?" muscle memory. Like Spotify's daily Discover.

### 10.2 Competitive landscape

| Competitor | Strength | Weakness vs HNAG |
|------------|----------|-------------------|
| GrabFood | Delivery scale | No decision help, optimized for impulse |
| ShopeeFood | Cheap delivery | Lower brand, no AI |
| Cookpad VN | Recipe library | Old UX, no personalization |
| TikTok food | Discovery, virality | No transaction layer |
| Google Maps | Restaurant data | No mood/social/recipe |
| Beli (US) | Restaurant reviews | English, not VN-specific |
| Foodvisor | Calorie tracking | No social, no recommendation |

**HNAG's wedge:** *AI Decision* is currently unowned. Everyone fights for the order; nobody owns the decision.

---

## 11. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| GrabFood/Shopee build similar feature | High | High | Move fast, build social moat first |
| AI cost spikes | Medium | Medium | Hybrid open-source, caching |
| Restaurant data scarcity | High | Medium | Crowdsource via foodies + paid scrape |
| Regulation (PDPR) | Medium | High | Compliance officer Y1 |
| Founder burnout | Medium | High | Hire COO + therapy stipend |
| Vietnamese ASR accuracy | Medium | Medium | Multi-model + retry |
| Low premium conversion | Medium | High | Pricing tests + freemium tuning |
| Photo moderation costs | Medium | Medium | AI mod + community report |

---

## 12. Pricing Internationalization (Y3+)

Markets in priority order:
1. Indonesia ($300M food market, 270M people)
2. Thailand
3. Philippines
4. Malaysia + Singapore

Each market needs:
- Local food dataset (3–6 month build)
- Local payment integration
- Local KOL partnerships
- Local language LLM fine-tune

---

## 13. Ethical & Trust Pillars

- No dark patterns
- Honest sponsored labeling (always badge "Quảng cáo")
- AI explanations always visible
- Calorie/health data: prompt user to consult doctor for medical needs
- Disordered-eating guardrails: if patterns detected → soft prompt to wellness resource
- Open data corner: monthly transparency report

---
