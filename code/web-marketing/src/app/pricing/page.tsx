import Link from 'next/link';
import { Check, Sparkle, Crown, Users, ArrowRight } from 'lucide-react';
import { Badge, Button, Card } from '@/components/ui';

const PLANS = [
  {
    id: 'free',
    name: 'Free',
    price: '0₫',
    priceSub: 'mãi mãi',
    description: 'Đủ cho người ăn 1-2 lần / ngày',
    features: [
      '3 AI Decide / ngày',
      'Mood Food cơ bản',
      'Search + map cơ bản',
      'Có quảng cáo',
      'Voice "Hà" (beta)',
    ],
    cta: 'Tải app miễn phí',
    highlight: false,
  },
  {
    id: 'plus',
    name: 'HNAG+',
    price: '49k',
    priceSub: '/ tháng',
    description: 'Cho người ăn-ngoài hàng ngày',
    badge: 'PHỔ BIẾN',
    features: [
      'Unlimited AI Decide',
      'Tất cả 6 AI engines',
      'Fridge Vision + Voice Hà',
      'Không quảng cáo',
      'Premium gradient theme',
      'Meal Planner 7 ngày',
      'Late Night Mode 🌙',
    ],
    cta: 'Đăng ký HNAG+',
    highlight: true,
  },
  {
    id: 'family',
    name: 'Family',
    price: '99k',
    priceSub: '/ tháng',
    description: 'Cho gia đình 5 thành viên',
    features: [
      'Tất cả của Plus',
      '5 thành viên dùng chung',
      'Couple Mode 💞',
      'Shared meal planner',
      'Family kitchen recipes',
      'Priority support 24/7',
    ],
    cta: 'Chọn Family',
    highlight: false,
  },
];

const COMPARE = [
  { feature: 'AI Decide / ngày',          free: '3',          plus: '∞',          family: '∞' },
  { feature: 'Mood Food (8 mood)',        free: '✓ cơ bản',   plus: '✓ full',     family: '✓ full' },
  { feature: 'Fridge Vision AI',          free: '—',          plus: '✓',          family: '✓' },
  { feature: 'Voice "Hà" (vi-VN)',        free: 'beta',       plus: '✓',          family: '✓' },
  { feature: 'Meal Planner 7 ngày',       free: '—',          plus: '✓',          family: '✓' },
  { feature: 'Grocery list export',       free: '—',          plus: '✓',          family: '✓' },
  { feature: 'Group voting',              free: '✓ 3 nhóm',   plus: '∞',          family: '∞' },
  { feature: 'Late Night Mode 🌙',        free: '—',          plus: '✓',          family: '✓' },
  { feature: 'Couple Mode 💞',            free: '—',          plus: '—',          family: '✓' },
  { feature: 'Shared family kitchen',     free: '—',          plus: '—',          family: '5 người' },
  { feature: 'Quảng cáo',                 free: 'có',         plus: 'không',      family: 'không' },
  { feature: 'Priority support',          free: '—',          plus: 'email',      family: '24/7 Zalo' },
];

const FAQ = [
  { q: 'Có dùng thử HNAG+ không?', a: 'Có — 7 ngày dùng thử full features, không cần thẻ tín dụng. Tự huỷ trước hết hạn miễn phí.' },
  { q: 'Huỷ subscription thế nào?', a: 'Vào Settings → Premium → Huỷ. Có hiệu lực cuối kỳ thanh toán hiện tại, không hoàn tiền theo ngày.' },
  { q: 'Family — 5 người có gì khác?', a: 'Một tài khoản chính + 4 thành viên phụ. Mỗi người có Food DNA riêng, nhưng dùng chung Meal Planner + Couple Mode + grocery list.' },
  { q: 'Thanh toán qua đâu?', a: 'MoMo, ZaloPay, VNPay (QR + banking), thẻ Visa/Mastercard. Tất cả qua VietQR — secure HMAC verification.' },
  { q: 'Chuyển plan có mất phí?', a: 'Không. Upgrade tính prorated, downgrade có hiệu lực cuối kỳ.' },
];

export default function PricingPage() {
  return (
    <div className="min-h-screen bg-bg text-text">
      {/* Nav (slim) */}
      <nav className="px-12 py-4 border-b border-divider">
        <div className="max-w-7xl mx-auto flex items-center">
          <Link href="/" className="flex items-center gap-2.5">
            <div className="size-8 rounded-[10px] bg-gradient-brand text-white grid place-items-center font-display font-extrabold text-[18px]">Ă</div>
            <span className="font-display font-semibold">Hôm Nay Ăn Gì?</span>
          </Link>
          <div className="flex-1" />
          <Button variant="ghost" size="sm" asChild><Link href="/">← Trang chủ</Link></Button>
        </div>
      </nav>

      {/* Hero */}
      <section className="px-12 py-20 text-center max-w-4xl mx-auto">
        <Badge variant="soft"><Crown className="size-3" /> BẢNG GIÁ</Badge>
        <h1 className="font-display font-extrabold text-[48px] md:text-[64px] leading-[1.1] tracking-[-0.03em] mt-5">
          Free mãi mãi.<br />
          <span className="bg-gradient-brand bg-clip-text text-transparent">Plus 49k để Hà hết giới hạn.</span>
        </h1>
        <p className="text-[18px] text-textMuted mt-6 max-w-[600px] mx-auto leading-snug">
          Core feature miễn phí. Trả tiền khi bạn cần unlimited AI, Fridge Vision, Meal Planner.
        </p>
      </section>

      {/* Plan cards */}
      <section className="px-12 pb-16">
        <div className="max-w-6xl mx-auto grid md:grid-cols-3 gap-5">
          {PLANS.map((p) => (
            <Card
              key={p.id}
              variant={p.highlight ? 'gradient' : 'raised'}
              pad="xl"
              className="relative"
            >
              {p.badge && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 h-7 inline-flex items-center text-[12px] font-extrabold rounded-full bg-bgRaised text-brand-500 border border-borderc shadow-s1">
                  {p.badge}
                </span>
              )}
              <h2 className={`font-display font-bold text-[28px] ${p.highlight ? 'text-white' : 'text-text'}`}>
                {p.name}
              </h2>
              <div className="flex items-baseline gap-1.5 mt-3">
                <span className={`font-display font-extrabold text-[42px] tracking-[-0.025em] ${p.highlight ? 'text-white' : 'text-text'}`}>
                  {p.price}
                </span>
                <span className={`text-[14px] ${p.highlight ? 'text-white/80' : 'text-textMuted'}`}>
                  {p.priceSub}
                </span>
              </div>
              <p className={`text-[14px] mt-3 ${p.highlight ? 'text-white/85' : 'text-textMuted'}`}>
                {p.description}
              </p>

              <ul className="mt-6 space-y-3">
                {p.features.map((f) => (
                  <li key={f} className="flex items-start gap-2.5">
                    <div className={`size-5 rounded-full grid place-items-center shrink-0 ${p.highlight ? 'bg-white/20' : 'bg-brand-500/15'}`}>
                      <Check className={`size-3 ${p.highlight ? 'text-white' : 'text-brand-500'}`} />
                    </div>
                    <span className={`text-[14px] ${p.highlight ? 'text-white' : 'text-text'}`}>{f}</span>
                  </li>
                ))}
              </ul>

              <Button
                variant={p.highlight ? 'glass' : (p.id === 'free' ? 'outline' : 'primary')}
                size="lg"
                full
                className="mt-8"
                iconTrailing={<ArrowRight className="size-4" />}
              >
                {p.cta}
              </Button>
            </Card>
          ))}
        </div>
        <p className="text-center text-[13px] text-textFaint mt-6">
          Huỷ bất cứ lúc nào · không phí thiết lập · thanh toán an toàn qua VietQR
        </p>
      </section>

      {/* Compare table */}
      <section className="px-12 py-20 bg-bgSunken">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-center font-display font-extrabold text-[36px] md:text-[42px] tracking-[-0.02em]">
            So sánh chi tiết
          </h2>
          <Card pad="none" className="mt-10 overflow-hidden">
            <table className="w-full">
              <thead className="bg-bgMuted">
                <tr>
                  <th className="text-left px-5 py-4 font-display font-bold text-[14px]">Feature</th>
                  <th className="text-center px-5 py-4 font-display font-bold text-[14px]">Free</th>
                  <th className="text-center px-5 py-4 font-display font-bold text-[14px] bg-brand-50 dark:bg-brand-500/10 text-brand-500">HNAG+</th>
                  <th className="text-center px-5 py-4 font-display font-bold text-[14px]">Family</th>
                </tr>
              </thead>
              <tbody>
                {COMPARE.map((row, i) => (
                  <tr key={row.feature} className={i % 2 === 0 ? '' : 'bg-bgSunken'}>
                    <td className="px-5 py-3 text-[14px]">{row.feature}</td>
                    <td className="px-5 py-3 text-center text-[14px] text-textMuted">{row.free}</td>
                    <td className="px-5 py-3 text-center text-[14px] font-semibold bg-brand-50/40 dark:bg-brand-500/5">{row.plus}</td>
                    <td className="px-5 py-3 text-center text-[14px]">{row.family}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Card>
        </div>
      </section>

      {/* FAQ */}
      <section className="px-12 py-20">
        <div className="max-w-3xl mx-auto">
          <h2 className="text-center font-display font-extrabold text-[36px] md:text-[42px] tracking-[-0.02em]">
            Câu hỏi thường gặp
          </h2>
          <div className="mt-10 space-y-4">
            {FAQ.map((item) => (
              <Card key={item.q} pad="lg">
                <h3 className="font-display font-bold text-[18px]">{item.q}</h3>
                <p className="text-[15px] text-textMuted mt-2 leading-snug">{item.a}</p>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* Footer CTA */}
      <section className="px-12 py-20 text-center bg-gradient-aurora">
        <div className="max-w-2xl mx-auto">
          <h2 className="font-display font-extrabold text-[36px] md:text-[48px] tracking-[-0.025em]">
            Chọn plan & cài app trong 1 phút
          </h2>
          <div className="flex flex-wrap justify-center gap-3 mt-8">
            <Button size="xl" variant="gradient" iconLeading={<Sparkle className="size-5" />}>Bắt đầu Free</Button>
            <Button size="xl" variant="dark"><Crown className="size-5" />Đăng ký HNAG+</Button>
          </div>
        </div>
      </section>
    </div>
  );
}
