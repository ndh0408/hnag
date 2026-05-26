import Link from 'next/link';
import { Crown, ChevronRight, Lock, Sparkle, ArrowRight, MessageCircle } from 'lucide-react';
import { Badge, Button, Card } from '@/components/ui';

export default function OwnerLanding() {
  return (
    <main className="min-h-screen flex">
      {/* Left brand panel */}
      <div className="hidden md:flex flex-col flex-[0_0_540px] relative overflow-hidden px-14 py-14 text-white"
        style={{ background: 'linear-gradient(135deg, #F04E0B 0%, #9F310F 100%)' }}
      >
        <div className="absolute inset-0 bg-gradient-aurora opacity-30 blur-3xl" />
        <div className="relative flex flex-col h-full">
          <div className="flex items-center gap-2.5">
            <div className="size-10 rounded-[12px] bg-white text-brand-500 grid place-items-center font-display font-extrabold text-[22px]">Ă</div>
            <span className="font-display font-bold text-[18px]">HNAG Owner</span>
          </div>

          <div className="flex-1 flex flex-col justify-center">
            <h1 className="font-display font-black text-[44px] md:text-[56px] leading-[1.05] tracking-[-0.03em]">
              Quán của bạn,<br />data minh bạch.
            </h1>
            <p className="text-[18px] text-white/85 mt-5 max-w-[400px] leading-snug">
              Theo dõi đơn realtime, trả lời review, sửa menu, push KM tới 240k+ users đang đói.
            </p>

            <div className="grid grid-cols-2 gap-4 mt-9">
              {[
                { v: '14.319', l: 'quán đã join' },
                { v: '+47%',   l: 'đơn / tháng TB' },
                { v: '24/7',   l: 'hỗ trợ Zalo' },
                { v: '$0',     l: 'phí setup' },
              ].map((s) => (
                <div key={s.l}>
                  <div className="font-display font-extrabold text-[32px] leading-none">{s.v}</div>
                  <div className="text-[13px] text-white/70 mt-0.5">{s.l}</div>
                </div>
              ))}
            </div>
          </div>

          <p className="text-[13px] text-white/50 leading-relaxed">
            &quot;Đơn HNAG ổn định nhất, support nhanh nhất so với 4 app khác.&quot;<br />
            <strong className="text-white">— Anh Tú, Phở Lý Quốc Sư</strong>
          </p>
        </div>
      </div>

      {/* Right form */}
      <div className="flex-1 flex flex-col justify-center px-8 md:px-20 py-10">
        <div className="max-w-md w-full">
          <Badge variant="soft">
            <Lock className="size-3" /> DASHBOARD CHỦ QUÁN
          </Badge>
          <h2 className="font-display font-bold text-[32px] mt-4 tracking-[-0.025em]">
            Đăng nhập
          </h2>
          <p className="text-[16px] text-textMuted mt-2">
            Số điện thoại đã đăng ký claim quán
          </p>

          <div className="mt-8 flex flex-col gap-3">
            <Link
              href="/login"
              className="h-13 px-4 rounded-[14px] border border-borderc bg-bgElev hover:bg-bgMuted flex items-center justify-center gap-3 font-semibold text-[15px] transition-colors"
            >
              Đăng nhập với số điện thoại
              <ArrowRight className="size-4" />
            </Link>
            <Link
              href="/dashboard"
              className="h-13 px-4 rounded-[14px] bg-gradient-brand text-white flex items-center justify-center gap-2 font-semibold text-[15px] shadow-glow"
            >
              <Sparkle className="size-4" />
              Vào dashboard demo
            </Link>
            <div className="flex items-center gap-3.5 my-1">
              <div className="flex-1 h-px bg-divider" />
              <span className="text-[13px] text-textMuted">hoặc</span>
              <div className="flex-1 h-px bg-divider" />
            </div>
            <button className="h-13 px-4 rounded-[14px] border border-borderc bg-bgElev hover:bg-bgMuted flex items-center justify-center gap-2 font-semibold text-[15px] transition-colors">
              Sign in with SSO
            </button>
          </div>

          <div className="my-8 h-px bg-divider" />

          <Card variant="soft" pad="md" className="flex items-center gap-3">
            <div className="size-10 rounded-[10px] bg-gradient-brand grid place-items-center">
              <Crown className="size-5 text-white" />
            </div>
            <div className="flex-1">
              <div className="text-[14px] font-semibold">Chưa join HNAG?</div>
              <div className="text-[13px] text-textMuted mt-0.5">Claim quán miễn phí · 5 phút</div>
            </div>
            <Button size="sm" iconTrailing={<ChevronRight className="size-4" />}>Claim</Button>
          </Card>

          <p className="text-[13px] text-textFaint mt-7 leading-relaxed">
            Bằng việc đăng nhập, bạn đồng ý{' '}
            <a href="#" className="text-text underline">Điều khoản</a> và{' '}
            <a href="#" className="text-text underline">Chính sách riêng tư</a>
          </p>

          <div className="mt-7 flex items-center gap-2 text-[12px] text-textMuted">
            <MessageCircle className="size-4" />
            <span>Cần hỗ trợ? Zalo +84 901 234 567 · hỗ trợ 24/7</span>
          </div>
        </div>
      </div>
    </main>
  );
}
