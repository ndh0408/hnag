import Link from 'next/link';

export default function Home() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center gap-6 p-8">
      <div className="text-6xl">🍜</div>
      <h1 className="text-4xl font-bold">HNAG Owner Dashboard</h1>
      <p className="text-muted-foreground text-center max-w-md">
        Cập nhật menu real-time, phản hồi review, chạy quảng cáo. Tất cả cho quán của bạn.
      </p>
      <div className="flex gap-3">
        <Link href="/login" className="px-6 py-3 rounded-full bg-primary text-primary-foreground font-medium hover:opacity-90">
          Đăng nhập
        </Link>
        <Link href="/onboarding" className="px-6 py-3 rounded-full border-2 border-primary text-primary font-medium hover:bg-primary/5">
          Đăng ký quán mới
        </Link>
      </div>
    </main>
  );
}
