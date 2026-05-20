import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'HNAG Dashboard',
  description: 'Quản lý quán ăn của bạn trên Hôm Nay Ăn Gì?',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body className="bg-background text-foreground antialiased">{children}</body>
    </html>
  );
}
