import './globals.css';
import type { Metadata } from 'next';
import { Inter, Urbanist, JetBrains_Mono } from 'next/font/google';

const inter    = Inter({ subsets: ['latin', 'vietnamese'], variable: '--font-inter' });
const urbanist = Urbanist({ subsets: ['latin'], variable: '--font-urbanist' });
const mono     = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono' });

export const metadata: Metadata = {
  title: 'HNAG — Hôm Nay Ăn Gì? · AI quyết định bữa ăn cho người Việt',
  description:
    'Đừng đắn đo nữa, Hà sẽ chọn cho bạn. AI khám phá & quyết định bữa ăn, mood-based, fridge scan, voice — cho người Việt.',
  metadataBase: new URL('https://tothanhthuy.cloud'),
  openGraph: {
    type: 'website',
    locale: 'vi_VN',
    siteName: 'HNAG',
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={`${inter.variable} ${urbanist.variable} ${mono.variable}`} suppressHydrationWarning>
      <body>{children}</body>
    </html>
  );
}
