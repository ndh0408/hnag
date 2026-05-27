import './globals.css';
import type { Metadata } from 'next';
import { Inter, Urbanist, JetBrains_Mono } from 'next/font/google';

const inter    = Inter({ subsets: ['latin', 'vietnamese'], variable: '--font-inter' });
const urbanist = Urbanist({ subsets: ['latin'], variable: '--font-urbanist' });
const mono     = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono' });

// Audit hnag-audit-2026-05 §19 — full SEO metadata (title template, OG,
// Twitter card, canonical, robots directives, keyword set).
export const metadata: Metadata = {
  title: {
    default: 'HNAG — Hôm Nay Ăn Gì? · AI quyết định bữa ăn cho người Việt',
    template: '%s · HNAG',
  },
  description:
    'Đừng đắn đo nữa, Hà sẽ chọn cho bạn. AI khám phá & quyết định bữa ăn, mood-based, fridge scan, voice — cho người Việt.',
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? 'https://tothanhthuy.cloud'),
  applicationName: 'HNAG',
  keywords: [
    'hôm nay ăn gì',
    'gợi ý món ăn',
    'AI ăn uống',
    'food discovery vietnam',
    'mood food',
    'quán ăn gần đây',
    'recommendation',
  ],
  alternates: {
    canonical: '/',
    languages: { 'vi-VN': '/' },
  },
  openGraph: {
    type: 'website',
    locale: 'vi_VN',
    siteName: 'HNAG',
    url: 'https://tothanhthuy.cloud',
    title: 'HNAG — Hôm Nay Ăn Gì? · AI quyết định bữa ăn cho người Việt',
    description: 'AI khám phá & quyết định bữa ăn cho người Việt — 14k+ quán, 86 món curated.',
    images: [
      { url: '/og-default.png', width: 1200, height: 630, alt: 'HNAG — AI quyết định hôm nay ăn gì' },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'HNAG — Hôm Nay Ăn Gì?',
    description: 'AI khám phá & quyết định bữa ăn cho người Việt.',
    images: ['/og-default.png'],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-image-preview': 'large',
      'max-video-preview': -1,
      'max-snippet': -1,
    },
  },
};

/**
 * Audit web-marketing-SEO: schema.org JSON-LD for Organization +
 * WebSite + MobileApplication. Lets Google show rich results (sitelink
 * searchbox, app card with download CTA). Embedded server-side once at
 * root layout. Update `sameAs` when social handles land.
 */
const jsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'Organization',
      '@id': 'https://tothanhthuy.cloud/#organization',
      name: 'HNAG',
      alternateName: 'Hôm Nay Ăn Gì?',
      url: 'https://tothanhthuy.cloud',
      logo: 'https://tothanhthuy.cloud/og-default.png',
      sameAs: [],
    },
    {
      '@type': 'WebSite',
      '@id': 'https://tothanhthuy.cloud/#website',
      url: 'https://tothanhthuy.cloud',
      name: 'HNAG — Hôm Nay Ăn Gì?',
      description: 'AI khám phá & quyết định bữa ăn cho người Việt.',
      publisher: { '@id': 'https://tothanhthuy.cloud/#organization' },
      inLanguage: 'vi-VN',
      potentialAction: {
        '@type': 'SearchAction',
        target: 'https://tothanhthuy.cloud/?q={search_term_string}',
        'query-input': 'required name=search_term_string',
      },
    },
    {
      '@type': 'MobileApplication',
      name: 'HNAG — Hôm Nay Ăn Gì?',
      operatingSystem: 'iOS, Android',
      applicationCategory: 'FoodAndDrinkApplication',
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'VND' },
      downloadUrl: 'https://app.tothanhthuy.cloud/',
      url: 'https://tothanhthuy.cloud',
      author: { '@id': 'https://tothanhthuy.cloud/#organization' },
    },
  ],
};

/**
 * Audit web-marketing-SEO: explicit `viewport` so Lighthouse mobile-
 * friendly check is satisfied + sets the iOS Safari address-bar theme.
 */
export const viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
  themeColor: '#FF6B2B',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={`${inter.variable} ${urbanist.variable} ${mono.variable}`} suppressHydrationWarning>
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
