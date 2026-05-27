import type { MetadataRoute } from 'next';

/**
 * /robots.txt
 *
 * Audit hnag-audit-2026-05 §19 (SEO): no robots.txt, no sitemap, no
 * canonical strategy. Public marketing surface + 14k restaurant
 * detail pages = long-tail SEO that's currently zero.
 *
 * Strategy:
 *   - allow everything on the marketing site
 *   - explicitly disallow the dashboard subdomain crawl paths (those
 *     are owner-only UIs, no business being indexed)
 *   - point at the sitemap
 */
export default function robots(): MetadataRoute.Robots {
  const base = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://tothanhthuy.cloud';
  return {
    rules: [
      { userAgent: '*', allow: '/', disallow: ['/api/', '/dashboard/', '/_next/'] },
      // Block AI scrapers that don't honor robots well from training on our
      // restaurant catalogue. Adjust if a deal changes our mind.
      { userAgent: ['GPTBot', 'ClaudeBot', 'CCBot', 'Google-Extended'], disallow: '/' },
    ],
    sitemap: `${base}/sitemap.xml`,
    host: base,
  };
}
