import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="min-h-screen flex items-center justify-center text-center px-6 bg-gradient-aurora">
      <div className="max-w-2xl space-y-6 py-24">
        <span className="inline-block px-3 py-1 rounded-full bg-bgGlass text-text/80 backdrop-blur text-[12px] font-mono">
          tothanhthuy.cloud · v1.0
        </span>
        <h1 className="font-display text-[56px] leading-[1.05] font-extrabold tracking-tight">
          Hôm Nay Ăn Gì?
        </h1>
        <p className="text-[18px] text-textMuted max-w-lg mx-auto">
          AI quyết định bữa ăn cho người Việt — mỗi ngày. Đừng đắn đo nữa, Hà sẽ chọn cho bạn.
        </p>
        <div className="flex items-center justify-center gap-3">
          <Link
            href="/showcase"
            className="inline-flex h-12 px-5 items-center rounded-[14px] bg-gradient-brand text-white font-semibold shadow-glow"
          >
            🎨 Design Showcase
          </Link>
          <a
            href="https://github.com/ndh0408/hnag"
            target="_blank"
            rel="noreferrer"
            className="inline-flex h-12 px-5 items-center rounded-[14px] border border-borderStrong text-text font-semibold"
          >
            GitHub
          </a>
        </div>
        <p className="text-[12px] text-textFaint font-mono">
          Landing đầy đủ ở Phase 9. Hiện tại trang showcase dùng để duyệt design tokens + primitives.
        </p>
      </div>
    </main>
  );
}
