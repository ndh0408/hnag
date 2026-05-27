/**
 * Per-restaurant sub-sitemap.
 *
 * Audit hnag-audit-2026-05 §19 — the 14k restaurant catalogue is the
 * single highest long-tail SEO win we can ship without paid acquisition.
 * Generated at request time (with a 6h CDN cache) by calling the
 * backend's `/v1/restaurants/sitemap` endpoint (separately implemented).
 *
 * NextResponse with text/xml + Cache-Control public so Cloudflare edge
 * caches it — Google fetches sitemap once per ~day, we don't need to
 * regenerate per request.
 */

import { NextResponse } from 'next/server';

export const revalidate = 21_600; // 6h ISR

const BASE = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://tothanhthuy.cloud';
const API_BASE_URL = process.env.API_BASE_URL ?? process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000';

interface SitemapEntry {
  id: string;
  slug?: string;
  updated_at?: string;
}

export async function GET() {
  let entries: SitemapEntry[] = [];
  try {
    // The backend endpoint should return all active restaurants (id + slug
    // + last_updated). If the endpoint doesn't exist yet, we serve an
    // empty but valid sitemap so the crawler doesn't 404.
    const res = await fetch(`${API_BASE_URL}/v1/restaurants/sitemap`, {
      next: { revalidate: 21_600 },
    });
    if (res.ok) {
      const json = await res.json();
      entries = Array.isArray(json?.data) ? json.data : Array.isArray(json) ? json : [];
    }
  } catch {/* keep empty entries */}

  const urls = entries
    .slice(0, 49_500) // sitemap protocol limit is 50k; leave headroom
    .map((r) => {
      const slug = r.slug ? `${r.slug}-${r.id}` : r.id;
      const loc = `${BASE}/r/${slug}`;
      const lastmod = r.updated_at ? new Date(r.updated_at).toISOString() : new Date().toISOString();
      return `<url><loc>${loc}</loc><lastmod>${lastmod}</lastmod><changefreq>weekly</changefreq><priority>0.7</priority></url>`;
    })
    .join('');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`;

  return new NextResponse(xml, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, s-maxage=21600, stale-while-revalidate=86400',
    },
  });
}
