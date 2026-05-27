// HNAG load test — AI suggest + restaurants nearby
// ---------------------------------------------------------------------------
// Audit hnag-audit-2026-05 §38 / §39: capacity at "scale to 100k MAU" is
// unknown because no load test ever ran. This script gives a quick read on
// the two hottest user-facing endpoints under sustained traffic.
//
// Targets:
//   - /v1/ai/suggest      → recommendation pipeline (LLM + ranker)
//   - /v1/restaurants/nearby → PostGIS GIST KNN lookup
//
// Usage:
//   k6 run -e BASE_URL=https://api.tothanhthuy.cloud \
//          -e TOKEN=$(./scripts/get-test-jwt.sh) \
//          code/infra/loadtest/k6-suggest.js
//
// Or against staging with the canary load profile:
//   k6 run --vus 50 --duration 5m code/infra/loadtest/k6-suggest.js
//
// CI integration (Week 6 todo): wire as a separate GitHub Actions job
// gated on `[loadtest]` in the commit message so it doesn't run on every
// PR (k6 cloud cost). See docs/99-PRODUCTION-READINESS.md §7.

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Rate } from 'k6/metrics';

const BASE = __ENV.BASE_URL || 'http://localhost:4000';
const TOKEN = __ENV.TOKEN || ''; // optional; suggest endpoint requires JWT
const HEADERS = TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {};

// Locations to randomise over — central HCMC + Hà Nội so PostGIS gets a
// realistic geographic spread, not one hot-spot.
const LOCATIONS = [
  { lat: 10.7769, lng: 106.7009 }, // Q1 HCMC
  { lat: 10.7626, lng: 106.6602 }, // Phú Nhuận
  { lat: 21.0285, lng: 105.8542 }, // Hoàn Kiếm HN
  { lat: 21.0167, lng: 105.7794 }, // Cầu Giấy HN
  { lat: 16.0544, lng: 108.2022 }, // Đà Nẵng
];

const suggestLatency = new Trend('hnag_suggest_latency_ms');
const nearbyLatency = new Trend('hnag_nearby_latency_ms');
const suggestErrors = new Rate('hnag_suggest_error_rate');
const nearbyErrors = new Rate('hnag_nearby_error_rate');

export const options = {
  // Audit §38 target: 2,000 concurrent baseline. Ramps so we can see the
  // knee-of-the-curve, not just the average.
  scenarios: {
    canary: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 50 },
        { duration: '2m',  target: 200 },
        { duration: '2m',  target: 500 },
        { duration: '1m',  target: 500 },   // hold
        { duration: '30s', target: 0 },
      ],
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    // Audit §11 target: p95 < 1.4s on suggest, p95 < 500ms on nearby.
    'hnag_suggest_latency_ms': ['p(95)<1400'],
    'hnag_nearby_latency_ms':  ['p(95)<500'],
    'hnag_suggest_error_rate': ['rate<0.01'],
    'hnag_nearby_error_rate':  ['rate<0.01'],
  },
};

export default function () {
  const loc = LOCATIONS[Math.floor(Math.random() * LOCATIONS.length)];

  group('GET /v1/restaurants/nearby', () => {
    const r = http.get(`${BASE}/v1/restaurants/nearby?lat=${loc.lat}&lng=${loc.lng}&radius=2000`, {
      tags: { endpoint: 'nearby' },
      timeout: '5s',
    });
    nearbyLatency.add(r.timings.duration);
    const ok = check(r, { 'nearby 200': (x) => x.status === 200 });
    nearbyErrors.add(!ok);
  });

  if (TOKEN) {
    group('POST /v1/ai/suggest', () => {
      const r = http.post(
        `${BASE}/v1/ai/suggest`,
        JSON.stringify({
          mode: 'quick',
          context: { location: loc, hour: new Date().getHours() },
          limit: 5,
        }),
        {
          headers: { ...HEADERS, 'Content-Type': 'application/json' },
          tags: { endpoint: 'suggest' },
          timeout: '8s',
        },
      );
      suggestLatency.add(r.timings.duration);
      const ok = check(r, { 'suggest 200': (x) => x.status === 200 });
      suggestErrors.add(!ok);
    });
  }

  // Realistic pacing — a real user does not hammer the API at 100 RPS.
  sleep(0.5 + Math.random() * 2.5);
}

export function handleSummary(data) {
  return {
    stdout: textSummary(data),
    'loadtest-summary.json': JSON.stringify(data, null, 2),
  };
}

function textSummary(d) {
  const m = d.metrics;
  const t = (k) => (m[k] ? `${m[k].values.p95?.toFixed(0) ?? '-'}ms p95 / ${m[k].values.avg?.toFixed(0) ?? '-'}ms avg` : '—');
  return `
HNAG k6 results
  suggest:  ${t('hnag_suggest_latency_ms')}  · errors: ${(m.hnag_suggest_error_rate?.values?.rate * 100 || 0).toFixed(2)}%
  nearby:   ${t('hnag_nearby_latency_ms')}   · errors: ${(m.hnag_nearby_error_rate?.values?.rate * 100 || 0).toFixed(2)}%
  http_reqs: ${m.http_reqs?.values?.count ?? '?'}  ·  rps: ${m.http_reqs?.values?.rate?.toFixed(1) ?? '?'}
`;
}
