# 13 — Restaurant Claim Flow (End-to-End)

> **Tại sao tài liệu này:** Mỗi quán "claimed" → quality score lên 0.85+, doanh thu B2B mở khóa (boost, sponsored, analytics), và data luôn fresh nhất từ chính chủ.

> **Target:** Year 1: 25% restaurants claimed (~30K). Year 3: 60%.

---

## 1. Business Value

| Metric | Unclaimed | Claimed |
|--------|-----------|---------|
| Data freshness | Stale (~30d) | Real-time |
| Menu accuracy | ~70% | ~98% |
| User trust signal | None | Verified badge |
| Boost eligibility | ❌ | ✅ |
| Live status updates | Auto-only | Manual + auto |
| Owner can respond to reviews | ❌ | ✅ |
| Revenue per restaurant | $0 | $40–500/mo |

**Series A target:** 100K claimed → $4M ARR from B2B alone.

---

## 2. Flow Overview

```
   PUBLIC RESTAURANT PAGE
            │
            ↓
   "Đây là quán của tôi?"  [CTA visible to non-owner browsing]
            │
            ↓
   ┌────────────────────────────────────┐
   │  CLAIM FORM                         │
   │  - Email / Phone                    │
   │  - Position (Chủ / Quản lý)         │
   │  - Photo of business license        │
   └────────────────┬───────────────────┘
                    ↓
   ┌────────────────────────────────────┐
   │  AUTOMATED VERIFICATION             │
   │  - Phone OTP to known business phone│
   │  - OR: License OCR match            │
   │  - OR: Geo-verified visit           │
   └────────────────┬───────────────────┘
                    ↓
            ┌───────┴───────┐
            │               │
    AUTO-APPROVED      MANUAL REVIEW
    (3 signals match)  (escalation)
            │               │
            └───────┬───────┘
                    ↓
   ┌────────────────────────────────────┐
   │  OWNER ONBOARDING (10 min)          │
   │  - Confirm/edit menu                │
   │  - Upload photos                    │
   │  - Open hours                       │
   │  - Delivery partner links           │
   │  - Connect payment for boost        │
   └────────────────┬───────────────────┘
                    ↓
   ┌────────────────────────────────────┐
   │  RESTAURANT DASHBOARD ACCESS        │
   │  Web (dash.tothanhthuy.cloud) + Mobile        │
   │  - Live orders, reviews, analytics  │
   │  - Boost campaigns                  │
   │  - Menu management                  │
   └─────────────────────────────────────┘
```

---

## 3. Verification Signals (3-tier)

A claim is approved when **≥2 of 3 signals match**.

### Signal A — Phone OTP
- We send OTP to the **business phone already on file**
- Owner must input within 5 min
- Strongest signal (weight: 0.6)

### Signal B — Business License OCR
- Upload photo of ĐKKD (Đăng ký kinh doanh) or hộ kinh doanh
- OCR extracts: Tên DN, Mã số thuế, Địa chỉ, Người đại diện
- Match against restaurant name + address (fuzzy)
- Use VinAI OCR + manual fallback
- Weight: 0.4

### Signal C — Geo-verified visit
- App detects GPS within 50m of restaurant during business hours
- Owner taps "I'm here, this is my restaurant"
- Photo of interior from owner perspective
- Weight: 0.3

### Signal D — Email at restaurant domain (bonus)
- Email matches restaurant website domain
- Weight: 0.2

**Auto-approval threshold:** sum ≥ 0.7
**Manual review:** 0.4–0.7
**Reject:** < 0.4 (with appeal)

---

## 4. Database Schema (claim-specific)

```sql
CREATE TYPE claim_status AS ENUM (
  'pending', 'verifying', 'auto_approved', 'manual_review',
  'approved', 'rejected', 'revoked', 'transferred'
);

CREATE TABLE restaurant_claims (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id   UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  claimant_user_id UUID REFERENCES users(id),
  status          claim_status DEFAULT 'pending',
  
  position        VARCHAR(40),         -- 'owner','manager','staff'
  contact_email   VARCHAR(160),
  contact_phone   VARCHAR(20),
  
  -- Verification scores
  phone_otp_passed BOOLEAN DEFAULT FALSE,
  license_url     TEXT,
  license_ocr     JSONB,
  license_score   NUMERIC(3,2),
  geo_verified    BOOLEAN DEFAULT FALSE,
  geo_visit_at    TIMESTAMPTZ,
  email_domain_match BOOLEAN DEFAULT FALSE,
  total_score     NUMERIC(3,2),
  
  -- Audit
  notes           TEXT,
  reviewed_by     UUID REFERENCES users(id),   -- HNAG ops staff
  reviewed_at     TIMESTAMPTZ,
  
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  resolved_at     TIMESTAMPTZ
);

CREATE INDEX idx_claims_status ON restaurant_claims(status);
CREATE INDEX idx_claims_pending ON restaurant_claims(created_at DESC)
  WHERE status IN ('pending','manual_review');

CREATE TABLE restaurant_owners (
  restaurant_id  UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  user_id        UUID REFERENCES users(id) ON DELETE CASCADE,
  role           VARCHAR(20) DEFAULT 'owner',  -- owner, manager, staff
  permissions    TEXT[] DEFAULT '{}',          -- ['menu','photos','boost','live','reply']
  added_at       TIMESTAMPTZ DEFAULT NOW(),
  added_by       UUID,
  PRIMARY KEY (restaurant_id, user_id)
);

-- Track all events
CREATE TABLE claim_events (
  id          BIGSERIAL PRIMARY KEY,
  claim_id    UUID REFERENCES restaurant_claims(id) ON DELETE CASCADE,
  event_type  VARCHAR(60),
  data        JSONB,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 5. API Endpoints

```
POST   /v1/restaurants/{id}/claim             Start claim
GET    /v1/restaurants/claims/me              My claims (status)
POST   /v1/restaurants/claims/{id}/verify/phone     Phone OTP verify
POST   /v1/restaurants/claims/{id}/verify/license   Upload license
POST   /v1/restaurants/claims/{id}/verify/geo       Submit geo visit
POST   /v1/restaurants/claims/{id}/cancel
GET    /v1/restaurants/claims/{id}            Claim status

# Admin endpoints
GET    /admin/claims?status=manual_review
PATCH  /admin/claims/{id}                     Approve/reject
POST   /admin/claims/{id}/note

# Owner dashboard endpoints
GET    /owner/restaurants                     My restaurants
GET    /owner/restaurants/{id}/analytics
PATCH  /owner/restaurants/{id}/menu
POST   /owner/restaurants/{id}/photos
PATCH  /owner/restaurants/{id}/live          Set crowd level, wait time
POST   /owner/restaurants/{id}/boost          Buy boost campaign
POST   /owner/restaurants/{id}/reviews/{rid}/reply
```

---

## 6. Mobile UX (User-facing)

### 6.1 Restaurant Detail — Claim CTA

On unclaimed restaurant page, show pill:

```
┌────────────────────────────────────────┐
│ ⚠ Quán này chưa được xác nhận   [Claim]│
└────────────────────────────────────────┘
```

Tap → opens claim flow.

### 6.2 Claim Flow Screens

**S1 — Intro:**
```
┌─────────────────────────────────────┐
│  ← Xác nhận quán này là của bạn?    │
│                                     │
│  [Photo of restaurant]              │
│                                     │
│  Phở Lý Quốc Sư · Hoàn Kiếm         │
│                                     │
│  Là chủ / quản lý quán này?         │
│  Xác nhận để:                       │
│  ✓ Cập nhật menu real-time          │
│  ✓ Nhận đặt giao trực tiếp          │
│  ✓ Phản hồi review                  │
│  ✓ Quảng cáo & analytics            │
│                                     │
│  [Bắt đầu xác nhận]                 │
│  [Tôi không phải chủ — báo cáo lỗi] │
└─────────────────────────────────────┘
```

**S2 — Position:**
```
Vị trí của bạn?
( ) Chủ quán
( ) Quản lý
( ) Nhân viên / Marketing
```

**S3 — Contact + OTP:**
```
Số điện thoại quán (chúng tôi gửi OTP):
[+84 _____________]

Email liên hệ:
[___________________]

[Gửi OTP]
```

If OTP success → +0.6 score

**S4 — License Upload (optional but recommended):**
```
Upload ảnh giấy phép kinh doanh
(ĐKKD / Hộ kinh doanh)

[📷 Chụp ảnh]   [🖼 Thư viện]

Chúng tôi:
- Tự động OCR thông tin
- Không chia sẻ với bên thứ 3
- Xoá sau khi xác nhận xong
```

If OCR matches → +0.4 score

**S5 — Geo Visit (optional):**
```
Bạn đang ở quán?
Để chúng tôi xác nhận GPS

[📍 Tôi đang ở đây]
(button enabled only when GPS < 50m)
```

If geo verified + photo → +0.3 score

**S6 — Confirmation:**
```
🎉 Xác nhận thành công!

Quán của bạn đã được verify ✓

Tiếp theo:
1. Tạo dashboard quản lý
2. Cập nhật menu (tự động import từ public photos)
3. Mời nhân viên cộng tác

[Mở Dashboard]   [Để sau]
```

---

## 7. Auto-import Menu (Onboarding Accelerator)

Sau khi claim, HNAG **đã có data** từ scraping/Foody. Show owner:

```
┌─────────────────────────────────────┐
│  Menu của quán bạn (chúng tôi tìm thấy 42 món)│
├─────────────────────────────────────┤
│  ✓ Phở bò tái   55k                 │
│  ✓ Phở bò nạm   55k                 │
│  ✓ Phở gà       50k                 │
│  ✓ ...                              │
│  ⚠ Bún chả      ?    (giá thiếu)   │
│  ⚠ Cao lầu      40k? (review nói)   │
│                                     │
│  [Sửa tất cả]   [Thêm món mới]      │
│  [Xác nhận toàn bộ]                 │
└─────────────────────────────────────┘
```

Owner tap → quick approve / edit. Saves 80% of onboarding time.

---

## 8. Owner Dashboard

### 8.1 Stack
- **Web:** Next.js 14 + shadcn/ui + tRPC
- **Mobile:** Flutter (shared widgets with consumer app, separate flow)
- **Auth:** Reuses user JWT + role check

### 8.2 Dashboard sections

```
┌──────────────────────────────────────────────┐
│  🍜 Phở Lý Quốc Sư  ▾                ⚙  👤  │
├──────────────────────────────────────────────┤
│                                              │
│  ── Today ────────────────────────────       │
│  Orders: 47       Revenue: 2.4M VND          │
│  Rating: 4.7      Views: 1,247               │
│                                              │
│  [Set crowd: 🟢 Trống / 🟡 Vừa / 🔴 Đông]    │
│                                              │
│  ── Live orders (real-time) ─────────       │
│  • 13:42 · 3 phở bò tái · 165k · GrabFood   │
│  • 13:38 · 1 phở gà · 50k · pickup          │
│                                              │
│  ── Recent reviews ───                       │
│  ⭐ 5  Mai L. · "Ngon!"  [Reply]            │
│  ⭐ 3  Khoa  · "Hơi mặn" [Reply]            │
│                                              │
│  ── Menu                                     │
│  [42 items]  [+ Add]  [Bulk edit]            │
│                                              │
│  ── Boost campaigns                          │
│  Active: Trending Top 3 · 500k/tuần          │
│  [Manage]                                    │
└──────────────────────────────────────────────┘

Tabs (left nav):
- Dashboard
- Orders
- Reviews
- Menu
- Photos
- Boost & Ads
- Analytics
- Team
- Settings
```

### 8.3 Analytics Section

| Metric | Last 7d | Last 30d |
|--------|---------|----------|
| Profile views | 8,421 | 32,109 |
| Order conversions | 412 | 1,847 |
| Avg order value | 78k | 82k |
| Repeat customer rate | 24% | 31% |
| Review velocity | 12 | 47 |
| AI suggestion impressions | 2,401 | 9,876 |
| Peak hours | 12–13, 19–20 | same |
| Top dishes ordered | [list] | [list] |
| Demographics | Age, gender, city pie charts | |

### 8.4 Boost Products (B2B Revenue)

| Product | Price | Effect |
|---------|-------|--------|
| **Featured Pin** (map) | 200k/tuần | Map pin enlarged, glow |
| **Trending Boost** | 500k/tuần | Eligible for "Trending Near You" feed |
| **AI Suggestion Boost** | 800k/tuần | Higher weight in AI recommender (capped to avoid spam) |
| **Sponsored Card** (CPM) | 80k / 1K impressions | "Quảng cáo" badge, full-card placement |
| **Story Ad** (vertical) | 1.2M / 1K views | Story feed insertion |
| **Restaurant Verified Plus** | 199k/tháng | Premium tier with all features above + priority support |

Pricing transparent, dashboard shows ROI live.

---

## 9. Team Management

Owner can invite staff:

```sql
-- restaurant_owners table supports multiple users
-- with different permissions
```

Roles:
- **Owner** — all permissions
- **Manager** — most, except billing
- **Marketing** — reviews + boost, no menu
- **Staff** — live status only (set crowd, wait time)

Invite flow: owner enters phone → SMS invite link → user accepts.

---

## 10. Operations & Risk

### 10.1 Fraud cases
- **False claim by competitor:** Lockout for 30 days; restore to true owner
- **Stale ownership (sold restaurant):** Re-verification every 12 months
- **Multi-claim conflict:** Manual review with both parties

### 10.2 Manual review queue
- HNAG ops team reviews ~20% of claims
- SLA: 24 hours
- Tools: integrated CRM view, license OCR result, GPS history

### 10.3 Appeal process
- Rejected user can appeal once
- Provides additional evidence
- Senior ops review (48h SLA)

### 10.4 Revocation
- If verified abuse → revoke + ban from owner program
- Restaurant returns to "unclaimed" with note
- Original public data preserved

---

## 11. Live Status Updates by Owner

Owner can update **real-time**:
- Open/closed (e.g. emergency)
- Crowdedness level
- Wait time estimate
- Today's specials
- Item out-of-stock

API:
```
PATCH /owner/restaurants/{id}/live
Body: {
  crowdedness: 0.85,
  waitMinutes: 25,
  outOfStock: ["pho-bo-tai"],
  todaySpecial: "Free trà đá cho khách trước 12h"
}
```

Push to `restaurant:{id}` WS channel → users see fresh data instantly.

---

## 12. Reply to Reviews

```
POST /owner/restaurants/{id}/reviews/{review_id}/reply
Body: { content: "..." }
```

Rules:
- Tone moderation (AI check before publish — block hostile)
- Max 280 chars
- One reply per review
- Editable within 24h
- Visible publicly under review

---

## 13. Onboarding Conversion Optimization

Funnel:

```
Restaurant viewed by owner (in-app or via QR campaign)
       ↓ 8% click "Claim"
Claim started
       ↓ 65% complete S1-3
Phone OTP sent
       ↓ 80% verify
Phone verified (basic approval)
       ↓ 40% upload license (boost score)
Full verified
       ↓ 75% open dashboard
Activated owner
```

Drop-off targets:
- Improve "Phone OTP send → verify" via clearer instructions
- Pre-fill data to reduce friction
- Whatsapp/Zalo channel for owners who don't read SMS

---

## 14. Off-app Outreach Channels

We don't wait for owners to discover claim. We **reach them**:

### 14.1 QR Campaign — Tier-1 cities
- Field sales team prints QR stickers
- Drops at top 10K restaurants
- Sticker says: "Quán của bạn đang được 5,000 khách Sài Gòn tìm trên HNAG. Quét để claim →"

### 14.2 Direct sales
- HCM + HN: 5 BD reps each
- Tỉnh: phone outreach
- Pitch deck for restaurant owners

### 14.3 Partner integrations
- GrabFood, ShopeeFood: cross-promote "Also claim on HNAG"
- POS partners (KiotViet, Sapo, MISA): integrate claim flow

### 14.4 Inbound
- Self-discovery via consumer app
- SEO landing pages for "HNAG cho chủ quán"
- Webinars + workshops

---

## 15. Localization Considerations

- Some informal businesses (street food cart) have **no license**
- Alternative verification: 2 customer videos confirming + neighbor confirmation + 3-month watch period
- Owner with limited tech: phone-call verification (Vietnamese ops team)

---

## 16. Roadmap

- **M3-4:** Self-service claim flow + Phone OTP
- **M5:** License OCR
- **M6:** Owner dashboard web
- **M8:** Mobile owner app
- **M10:** Team management + roles
- **M12:** Boost ads marketplace
- **M14:** POS integration (KiotViet)
- **M18:** Multi-location chains (single login, all locations)

---

## 17. Success Metrics

| Metric | Year 1 | Year 3 |
|--------|--------|--------|
| Total claimed | 30K | 180K |
| % of total restaurants | 25% | 60% |
| Avg revenue/claimed/mo | $15 | $40 |
| Owner DAU | 8K | 60K |
| Reviews replied % | 35% | 65% |
| Boost adoption % | 12% | 40% |

---

## 18. Sample API Implementation (NestJS sketch)

```typescript
// modules/restaurants/claim.controller.ts
@Controller('v1/restaurants')
export class ClaimController {
  @Post(':id/claim')
  async startClaim(@Param('id') restaurantId: string, @User() user, @Body() dto: StartClaimDto) {
    return this.claimService.start(user.id, restaurantId, dto);
  }

  @Post('claims/:claimId/verify/phone')
  async verifyPhone(@Param('claimId') id: string, @Body() body: { otp: string }) {
    return this.claimService.verifyPhone(id, body.otp);
  }

  @Post('claims/:claimId/verify/license')
  @UseInterceptors(FileInterceptor('image'))
  async uploadLicense(@Param('claimId') id: string, @UploadedFile() file) {
    return this.claimService.processLicense(id, file);
  }

  @Post('claims/:claimId/verify/geo')
  async verifyGeo(@Param('claimId') id: string, @Body() dto: GeoDto) {
    return this.claimService.verifyGeo(id, dto);
  }
}
```

```typescript
// claim.service.ts (key logic)
async tallyAndDecide(claimId: string) {
  const claim = await this.repo.findOne({ where: { id: claimId } });
  let score = 0;
  if (claim.phone_otp_passed) score += 0.6;
  score += claim.license_score ?? 0;       // 0–0.4
  if (claim.geo_verified) score += 0.3;
  if (claim.email_domain_match) score += 0.2;
  claim.total_score = score;

  if (score >= 0.7) {
    claim.status = 'approved';
    await this.grantOwnership(claim);
  } else if (score >= 0.4) {
    claim.status = 'manual_review';
    await this.notifyOps(claim);
  } else {
    claim.status = 'rejected';
  }
  claim.resolved_at = score >= 0.7 ? new Date() : null;
  return this.repo.save(claim);
}
```

---

## 19. Privacy notes

- License images: encrypted at rest, deleted 90 days after approval
- Owner phone: stored hash + ciphertext, displayed masked
- Audit log of every change
- Owner can transfer ownership to another user (with 2FA)

---

## 20. KPIs Dashboard (Internal)

```
┌──────────────────────────────────────────────┐
│  Claim funnel — Last 30d                     │
├──────────────────────────────────────────────┤
│  Claim started:        2,847                 │
│  Phone verified:       2,182  (76.6%)        │
│  License uploaded:       874  (40.0%)        │
│  Auto-approved:        1,723  (60.5%)        │
│  Manual review:          412                 │
│  Manual approved:        298  (72.3%)        │
│  Total approved:       2,021  (71.0%)        │
│  Avg time to approval:  4.2 hours            │
│  Activated dashboard:  1,627  (80.5% of OK)  │
└──────────────────────────────────────────────┘
```

---
