import Link from 'next/link';
import {
  Sparkle, Sparkles, AlertTriangle, Bolt, Heart, Star, Download,
  Camera, Smile, Users, Calendar, Mic, Package, Grid as GridIcon, User as UserIcon,
  ArrowRight, ChevronRight,
} from 'lucide-react';
import { Badge, Button, Card, Avatar } from '@/components/ui';

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-bg text-text overflow-x-hidden">
      <Nav />
      <Hero />
      <PressStrip />
      <ProblemSection />
      <EnginesSection />
      <HowItWorksSection />
      <StatsSection />
      <TestimonialsSection />
      <CtaSection />
      <Footer />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// NAV
// ─────────────────────────────────────────────────────────────
function Nav() {
  return (
    <nav className="sticky top-0 z-40 px-12 py-3.5 bg-bg/85 backdrop-blur-xl backdrop-saturate-150 border-b border-divider">
      <div className="max-w-7xl mx-auto flex items-center gap-8">
        <Link href="/" className="flex items-center gap-2.5">
          <div className="size-8 rounded-[10px] bg-gradient-brand text-white grid place-items-center font-display font-extrabold text-[18px] shadow-[0_4px_12px_rgba(255,107,43,0.3)]">
            Ă
          </div>
          <span className="font-display font-semibold tracking-tight">Hôm Nay Ăn Gì?</span>
        </Link>
        <div className="hidden md:flex gap-7 text-[13px] text-textMuted">
          <a href="#engines" className="hover:text-text">Sản phẩm</a>
          <a href="#engines" className="hover:text-text">AI Engines</a>
          <a href="#" className="hover:text-text">Cho chủ quán</a>
          <a href="#testimonials" className="hover:text-text">Khách hàng nói</a>
          <a href="#" className="hover:text-text">Bảng giá</a>
        </div>
        <div className="flex-1" />
        <Button variant="ghost" size="sm">Đăng nhập</Button>
        <Button size="sm" iconTrailing={<ArrowRight className="size-4" />}>Tải app</Button>
      </div>
    </nav>
  );
}

// ─────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────
function Hero() {
  return (
    <section className="relative px-12 pt-20 pb-16 max-w-7xl mx-auto">
      <div className="grid md:grid-cols-[1.05fr_1fr] gap-12 items-center">
        <div>
          <Badge variant="soft">
            <Sparkle className="size-3" /> 🇻🇳 Made for Việt Nam · Series A
          </Badge>
          <h1 className="font-display font-black tracking-[-0.035em] mt-6 text-[64px] md:text-[78px] leading-[1.02]">
            Đừng đắn đo
            <br />
            <span className="bg-gradient-brand bg-clip-text text-transparent">hôm nay ăn gì</span>
            <br />
            nữa.
          </h1>
          <p className="text-[18px] text-textMuted mt-6 max-w-[520px] leading-snug">
            AI quyết định bữa ăn trong 1 vuốt. <strong className="text-text">86 món Việt curated</strong>,{' '}
            <strong className="text-text">14.319 quán thật</strong>, gợi ý theo mood, ngân sách, thời tiết.
          </p>
          <div className="flex flex-wrap gap-3 mt-8">
            <Button variant="dark" size="xl">
              <span className="text-lg"></span> App Store
            </Button>
            <Button variant="dark" size="xl">
              <span className="font-extrabold text-lg">▶</span> Google Play
            </Button>
            <Button variant="outline" size="xl" iconLeading={<Download className="size-5" />}>
              APK
            </Button>
          </div>
          <div className="flex items-center gap-8 mt-8">
            <div>
              <div className="flex items-center gap-1 text-turmeric-500">
                {[1,2,3,4,5].map((i) => <Star key={i} className="size-4 fill-current" />)}
              </div>
              <div className="text-[13px] text-textMuted mt-1">
                <strong className="text-text">4.8</strong> · 12k reviews
              </div>
            </div>
            <div className="w-px h-9 bg-borderc" />
            <div>
              <div className="font-display font-bold text-[18px]">240k+</div>
              <div className="text-[13px] text-textMuted mt-0.5">MAU đang dùng</div>
            </div>
            <div className="w-px h-9 bg-borderc" />
            <div>
              <div className="font-display font-bold text-[18px]">2.4M</div>
              <div className="text-[13px] text-textMuted mt-0.5">quyết định / tháng</div>
            </div>
          </div>
        </div>

        {/* Visual — gradient blob + mock phone stack */}
        <div className="relative h-[560px] hidden md:flex items-center justify-center">
          <div className="absolute inset-0 bg-gradient-aurora opacity-40 blur-3xl" />
          <PhoneMock variant="home" className="absolute -translate-x-[90px] translate-y-5 -rotate-8 scale-95 z-0" />
          <PhoneMock variant="cardstack" className="absolute translate-x-[90px] -translate-y-5 rotate-6 z-10" />
        </div>
      </div>
    </section>
  );
}

function PhoneMock({ variant, className }: { variant: 'home' | 'cardstack'; className?: string }) {
  return (
    <div
      className={`relative w-[260px] h-[540px] rounded-[40px] bg-neutral-1000 p-1.5 shadow-[0_30px_60px_-20px_rgba(20,18,15,0.4)] ${className ?? ''}`}
    >
      <div className="size-full rounded-[34px] bg-bg overflow-hidden flex flex-col">
        <div className="h-8 flex justify-center pt-2">
          <div className="w-20 h-5 rounded-full bg-black" />
        </div>
        <div className="flex-1 px-4">
          {variant === 'home' ? (
            <div className="pt-2 space-y-2">
              <div className="flex items-center gap-2">
                <Avatar name="Thảo" size={32} />
                <div>
                  <div className="text-[10px] text-textMuted">Chào trưa,</div>
                  <div className="text-[12px] font-semibold">Thảo 👋</div>
                </div>
              </div>
              <div className="aspect-[4/3] rounded-[14px] bg-gradient-to-br from-chili-500 via-brand-500 to-brand-400 mt-3" />
              <div className="grid grid-cols-3 gap-2 mt-2">
                {[1,2,3].map((i) => <div key={i} className="aspect-square rounded-[10px] bg-bgMuted" />)}
              </div>
            </div>
          ) : (
            <div className="pt-3 flex flex-col items-center">
              <div className="w-full aspect-[3/4] rounded-[18px] bg-gradient-to-br from-turmeric-500 to-brand-600" />
              <div className="flex gap-3 mt-3">
                <div className="size-10 rounded-full border-2 border-chili-500 grid place-items-center text-chili-500">✕</div>
                <div className="size-14 rounded-full bg-gradient-brand grid place-items-center shadow-glow">
                  <Heart className="size-6 text-white" />
                </div>
                <div className="size-10 rounded-full border-2 border-ai-500" />
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// PRESS STRIP
// ─────────────────────────────────────────────────────────────
function PressStrip() {
  const press = ['VnExpress', 'TechCrunch SEA', 'Forbes VN', 'Genk', 'Vietcetera', 'VnEconomy'];
  return (
    <div className="px-12 py-6 border-y border-divider flex flex-wrap items-center justify-between gap-6">
      <span className="text-[13px] text-textMuted whitespace-nowrap">Được nhắc trên</span>
      {press.map((p) => (
        <span key={p} className="font-display font-bold text-[18px] text-textFaint tracking-tight">
          {p}
        </span>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// PROBLEM
// ─────────────────────────────────────────────────────────────
function ProblemSection() {
  const cards = [
    { icon: <Package className="size-6" />, name: 'Decision fatigue', desc: '67% Gen Z "lười nghĩ" về món ăn. Não chỉ có giới hạn quyết định/ngày.' },
    { icon: <GridIcon className="size-6" />, name: 'App phân mảnh', desc: 'Mở GrabFood, Maps, Google, TikTok... vẫn không quyết được. Quá nhiều lựa chọn = không lựa chọn.' },
    { icon: <UserIcon className="size-6" />, name: 'Thiếu cá nhân hoá', desc: 'Không app nào hiểu *bạn*: mood, ngân sách, sức khoẻ, vị giác miền Việt.' },
  ];
  return (
    <section className="px-12 py-24 text-center bg-bgSunken">
      <div className="max-w-7xl mx-auto">
        <Badge>
          <AlertTriangle className="size-3" /> VẤN ĐỀ
        </Badge>
        <h2 className="font-display font-extrabold text-[42px] md:text-[56px] leading-[1.1] tracking-[-0.03em] mt-4">
          Mỗi ngày bạn mất <span className="text-brand-500">23 phút</span>
          <br />
          quyết định &quot;hôm nay ăn gì?&quot;
        </h2>
        <div className="grid md:grid-cols-3 gap-5 mt-14 text-left">
          {cards.map((c) => (
            <Card key={c.name} pad="xl">
              <div className="size-12 rounded-[14px] bg-brand-500/12 grid place-items-center text-brand-500">
                {c.icon}
              </div>
              <h3 className="font-display font-bold text-[22px] mt-4">{c.name}</h3>
              <p className="text-[16px] text-textMuted mt-2 leading-snug">{c.desc}</p>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// 6 AI ENGINES
// ─────────────────────────────────────────────────────────────
function EnginesSection() {
  const engines = [
    { icon: <Sparkles />, name: 'Food Recommender', desc: 'Context-aware engine kết hợp thời tiết, mood, ngân sách, giờ giấc, Food DNA cá nhân.', tag: 'CORE', tagBg: 'bg-brand-500/12 text-brand-500' },
    { icon: <Camera />, name: 'Fridge Vision Scan', desc: 'Vision AI nhận diện 150+ nguyên liệu Việt từ tủ lạnh → gợi món có thể nấu ngay.', tag: 'NEW', tagBg: 'bg-ai-500/12 text-ai-500' },
    { icon: <Smile />, name: 'Mood Food', desc: '8 cảm xúc · gợi món theo emotion. Stress → cay-nóng. Buồn → comfort food.', tag: 'POPULAR', tagBg: 'bg-turmeric-500/16 text-turmeric-600' },
    { icon: <Users />, name: 'Group Decision', desc: 'Voting realtime · AI tìm intersection 5 người. Hết cãi nhau hôm đi đâu.' },
    { icon: <Calendar />, name: 'Meal Planner', desc: 'Lịch 7 ngày auto-optimize macro + budget + grocery list xuất ra Bachhoa Xanh.' },
    { icon: <Mic />, name: 'Voice "Hà"', desc: '"Hey Hà, hôm nay ăn gì?" — Vietnamese NLU, hiểu giọng Bắc, Trung, Nam.', tag: 'BETA', tagBg: 'bg-text/10 text-text' },
  ];
  return (
    <section id="engines" className="px-12 py-24 bg-bg">
      <div className="max-w-7xl mx-auto">
        <div className="text-center">
          <Badge variant="ai">
            <Sparkles className="size-3" /> GIẢI PHÁP
          </Badge>
          <h2 className="font-display font-extrabold text-[42px] md:text-[56px] leading-[1.1] tracking-[-0.03em] mt-4">
            6 AI engines · 1 quyết định
          </h2>
          <p className="text-[18px] text-textMuted mt-3 max-w-[700px] mx-auto">
            Từ mood → đến tủ lạnh → đến nhóm bạn — Hà có 1 engine cho mỗi cảnh huống
          </p>
        </div>
        <div className="grid md:grid-cols-3 gap-4 mt-14">
          {engines.map((e, i) => (
            <Card key={e.name} pad="xl" hoverable className="relative">
              {e.tag && (
                <span className={`absolute top-5 right-5 px-2.5 h-6 inline-flex items-center text-[12px] font-medium rounded-full ${e.tagBg ?? ''}`}>
                  {e.tag}
                </span>
              )}
              <div className="size-14 rounded-[14px] bg-gradient-brand text-white grid place-items-center shadow-[0_8px_20px_rgba(255,107,43,0.25)] [&_svg]:size-7">
                {e.icon}
              </div>
              <h3 className="font-display font-bold text-[22px] mt-5">{e.name}</h3>
              <p className="text-[16px] text-textMuted mt-2 leading-snug">{e.desc}</p>
              <div className="font-mono text-[11px] text-textFaint mt-5">0{i + 1} / 06</div>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// HOW IT WORKS
// ─────────────────────────────────────────────────────────────
function HowItWorksSection() {
  const steps = [
    { name: 'Mở app',     desc: 'Hà đã biết bạn đói mức nào dựa trên context (thời tiết, giờ, vị trí).' },
    { name: 'Chọn mode',  desc: 'Quick / Mood / Voice / Fridge / Group. Tuỳ tình huống lúc đó.' },
    { name: 'Vuốt card',  desc: '5 món AI chọn, vuốt phải = thích, trái = bỏ. Hà học dần.' },
    { name: 'Đặt / Đi / Nấu', desc: 'Deep-link GrabFood, Apple Maps, hoặc Cooking Mode hướng dẫn realtime.' },
  ];
  return (
    <section className="px-12 py-24 bg-bgSunken">
      <div className="max-w-7xl mx-auto">
        <div className="text-center">
          <Badge>
            <Bolt className="size-3" /> CÁCH HOẠT ĐỘNG
          </Badge>
          <h2 className="font-display font-extrabold text-[42px] md:text-[56px] leading-[1.1] tracking-[-0.03em] mt-4">
            3 vuốt · 1 bữa cơm
          </h2>
        </div>
        <div className="grid md:grid-cols-4 gap-8 mt-16 max-w-5xl mx-auto">
          {steps.map((s, i) => (
            <div key={s.name} className="relative">
              <div
                className="size-16 rounded-[20px] bg-white border-2 border-text grid place-items-center font-display font-extrabold text-[32px] text-text"
                style={{ boxShadow: '6px 6px 0 0 rgb(var(--text))' }}
              >
                {i + 1}
              </div>
              <h3 className="font-display font-bold text-[18px] mt-6">{s.name}</h3>
              <p className="text-[16px] text-textMuted mt-2 leading-snug">{s.desc}</p>
              {i < 3 && (
                <ChevronRight className="hidden lg:block absolute right-[-30px] top-[26px] size-5 text-textFaint" />
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// STATS (Dark)
// ─────────────────────────────────────────────────────────────
function StatsSection() {
  const stats = [
    { v: '14.319',  l: 'quán thật toàn quốc', s: 'OpenStreetMap · 62 tỉnh' },
    { v: '86',      l: 'món Việt curated',    s: 'Wikidata + verify thủ công' },
    { v: '6',       l: 'AI engines',          s: 'GPT-4o-mini + heuristic VN' },
    { v: '< 200ms', l: 'gợi ý đầu tiên',      s: 'edge inference · CDN VN' },
    { v: '$0',     l: 'phí dùng',             s: 'core feature miễn phí' },
  ];
  return (
    <section className="relative px-12 py-20 bg-neutral-950 text-white overflow-hidden">
      <div className="absolute inset-0 bg-gradient-aurora opacity-15 blur-3xl" />
      <div className="relative max-w-7xl mx-auto grid grid-cols-2 md:grid-cols-5 gap-8 text-center">
        {stats.map((s) => (
          <div key={s.l}>
            <div className="font-display font-extrabold text-[42px] md:text-[48px] tracking-[-0.03em] bg-gradient-brand bg-clip-text text-transparent">
              {s.v}
            </div>
            <div className="text-[13px] text-white font-semibold mt-2">{s.l}</div>
            <div className="text-[13px] text-white/50 mt-1">{s.s}</div>
          </div>
        ))}
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// TESTIMONIALS
// ─────────────────────────────────────────────────────────────
function TestimonialsSection() {
  const testimonials = [
    { name: 'Thảo · 28 · Office', q: 'Tiết kiệm 20 phút mỗi ngày. Hà hiểu khẩu vị tôi sau 1 tuần dùng. Bún bò Huế mỗi sáng vẫn đúng quán tôi thích.', avatar: 'Thảo' },
    { name: 'Minh · 21 · Sinh viên', q: 'Group voting với hội bạn — không còn cãi nhau hôm đi đâu nữa! AI quyết, anh em vote, đi luôn.', avatar: 'Minh' },
    { name: 'Anh Hùng · 38 · Bố 2 con', q: 'Fridge scan đỉnh — nhìn tủ lạnh xong biết nấu gì cho con. Vợ tôi cũng cài rồi, dùng chung Couple Mode.', avatar: 'Hùng' },
  ];
  return (
    <section id="testimonials" className="px-12 py-24">
      <div className="max-w-7xl mx-auto">
        <div className="text-center">
          <Badge>
            <Heart className="size-3" /> NGƯỜI DÙNG NÓI
          </Badge>
          <h2 className="font-display font-extrabold text-[36px] md:text-[48px] leading-[1.1] tracking-[-0.03em] mt-4">
            &quot;Tôi không nghĩ về món nữa&quot;
          </h2>
        </div>
        <div className="grid md:grid-cols-3 gap-5 mt-14">
          {testimonials.map((t) => (
            <Card key={t.name} variant="raised" pad="xl" className="relative">
              <span
                className="absolute top-6 right-7 font-display font-extrabold text-[64px] leading-none text-brand-500/20 select-none"
                aria-hidden
              >
                &quot;
              </span>
              <div className="flex gap-1 text-turmeric-500">
                {[1,2,3,4,5].map((i) => <Star key={i} className="size-4 fill-current" />)}
              </div>
              <p className="text-[17px] leading-snug mt-4">{t.q}</p>
              <div className="flex items-center gap-3 mt-6">
                <Avatar name={t.avatar} size={44} />
                <div className="font-medium text-[13px]">{t.name}</div>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// CTA
// ─────────────────────────────────────────────────────────────
function CtaSection() {
  return (
    <section className="relative px-12 py-24 bg-gradient-brand text-white text-center overflow-hidden">
      <div className="absolute inset-0 bg-gradient-aurora opacity-30 blur-3xl" />
      <div className="relative max-w-3xl mx-auto">
        <h2 className="font-display font-black text-[44px] md:text-[64px] leading-[1.05] tracking-[-0.035em]">
          Sẵn sàng để Hà chọn?
        </h2>
        <p className="text-[18px] md:text-[20px] text-white/90 mt-5 max-w-[600px] mx-auto">
          Miễn phí · iOS, Android, APK trực tiếp · không cần thẻ tín dụng
        </p>
        <div className="flex flex-wrap justify-center gap-3 mt-9">
          <button className="h-14 px-7 rounded-[14px] bg-white text-text font-semibold text-[15px] inline-flex items-center gap-2">
            <span className="text-lg"></span> App Store
          </button>
          <button className="h-14 px-7 rounded-[14px] bg-white text-text font-semibold text-[15px] inline-flex items-center gap-2">
            <span className="font-extrabold text-lg">▶</span> Google Play
          </button>
          <a
            href="https://app.tothanhthuy.cloud"
            className="h-14 px-7 rounded-[14px] bg-white/15 backdrop-blur text-white font-semibold text-[15px] inline-flex items-center gap-2 border border-white/40"
          >
            <Download className="size-5" /> APK trực tiếp
          </a>
        </div>
      </div>
    </section>
  );
}

// ─────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────
function Footer() {
  const cols = [
    { h: 'Sản phẩm', items: ['App', 'Owner dashboard', 'API · Devs', 'Status'] },
    { h: 'Công ty', items: ['Về chúng tôi', 'Báo chí', 'Tuyển dụng', 'Đối tác'] },
    { h: 'Pháp lý', items: ['ToS', 'Privacy', 'Cookie', 'DPA'] },
    { h: 'Hỗ trợ', items: ['Help center', 'Liên hệ', 'Cộng đồng', 'Roadmap'] },
  ];
  return (
    <footer className="px-12 pt-16 pb-8 bg-neutral-950 text-white/65 text-[13px]">
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-[2fr_1fr_1fr_1fr_1fr] gap-10">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="size-8 rounded-[10px] bg-gradient-brand text-white grid place-items-center font-display font-extrabold text-[18px]">Ă</div>
            <span className="font-display font-bold text-[18px] text-white">HNAG</span>
          </div>
          <p className="mt-4 leading-relaxed">
            AI Food Discovery cho người Việt.<br />
            Made with ❤️ in Sài Gòn.<br />
            📧 hi@tothanhthuy.cloud · 📍 Q.1, TP.HCM
          </p>
          <div className="flex gap-2.5 mt-5">
            {['t', 'i', 'f', 'y'].map((p) => (
              <a key={p} href="#" className="size-9 rounded-full bg-white/10 grid place-items-center text-white text-[13px]">{p}</a>
            ))}
          </div>
        </div>
        {cols.map((c) => (
          <div key={c.h}>
            <div className="text-white font-semibold mb-3">{c.h}</div>
            {c.items.map((i) => (
              <a key={i} href="#" className="block mt-2 hover:text-white">{i}</a>
            ))}
          </div>
        ))}
      </div>
      <div className="max-w-7xl mx-auto border-t border-white/10 mt-12 pt-6 flex flex-col md:flex-row md:justify-between gap-2 text-white/40 font-mono text-[11px]">
        <span>© 2026 HNAG · v1.2.4 · 14.319 quán thật từ OpenStreetMap</span>
        <span>Status: ● All systems operational</span>
      </div>
    </footer>
  );
}
