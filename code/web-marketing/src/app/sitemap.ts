import type { MetadataRoute } from 'next';

/**
 * /sitemap.xml
 *
 * Audit hnag-audit-2026-05 §19: "SEO deep-link cấp restaurant thiếu hoàn
 * toàn — 14k quán × indexed page là mỏ vàng long-tail."
 *
 * Strategy: serve the static marketing pages here; restaurant + food
 * sub-sitemaps live at /sitemap-restaurants.xml and /sitemap-foods.xml
 * (chunked because a single sitemap.xml cannot exceed 50k URLs / 50MB
 * per Google's spec, and we expect 14k restaurants → comfortable in one
 * sub-sitemap today but split for headroom).
 *
 * NEXT step (next session, behind backend): generate the per-restaurant /
 * per-food sitemaps at build time by querying the API. For now we point
 * at static manifest URLs that the backend OR a build hook can produce.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://tothanhthuy.cloud';
  const now = new Date();
  return [
    { url: `${base}/`, lastModified: now, changeFrequency: 'weekly', priority: 1.0 },
    { url: `${base}/pricing`, lastModified: now, changeFrequency: 'monthly', priority: 0.8 },
    { url: `${base}/showcase`, lastModified: now, changeFrequency: 'monthly', priority: 0.5 },
    // Sub-sitemap references — search engines will fetch these chunks.
    // The build hook / backend route should emit these.
    { url: `${base}/sitemap-restaurants.xml`, lastModified: now, changeFrequency: 'daily', priority: 0.9 },
    { url: `${base}/sitemap-foods.xml`, lastModified: now, changeFrequency: 'weekly', priority: 0.7 },
  ];
}
