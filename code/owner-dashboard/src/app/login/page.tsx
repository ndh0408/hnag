'use client';
import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';

function LoginForm() {
  const r = useRouter();
  const params = useSearchParams();
  const next = params.get('next') || '/dashboard';

  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const emailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

  async function sendOtp() {
    setBusy(true); setError(null);
    try {
      // Same-origin route handler — tokens never touch the client.
      const res = await fetch('/api/auth/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      const j = await res.json().catch(() => null);
      if (!res.ok || !j?.success) throw new Error(j?.error || 'Gửi mã thất bại');
      setOtpSent(true);
    } catch (e: any) { setError(e.message); } finally { setBusy(false); }
  }

  async function verifyOtp() {
    setBusy(true); setError(null);
    try {
      // On success the route handler sets httpOnly cookies; nothing sensitive
      // comes back in the body, and we never write tokens to localStorage.
      const res = await fetch('/api/auth/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, code: otp }),
      });
      const j = await res.json().catch(() => null);
      if (!res.ok || !j?.success) throw new Error(j?.error || 'Mã OTP không đúng');
      r.push(next);
      r.refresh();
    } catch (e: any) { setError(e.message); } finally { setBusy(false); }
  }

  return (
    <div className="bg-white rounded-2xl shadow-xl p-8 w-full max-w-md">
      <div className="text-center mb-6">
        <div className="text-5xl mb-2">🍜</div>
        <h1 className="text-2xl font-bold">HNAG Dashboard</h1>
        <p className="text-muted-foreground text-sm">Đăng nhập với tài khoản chủ quán</p>
      </div>

      {!otpSent ? (
        <>
          <label className="text-sm font-medium">Email</label>
          <input
            type="email"
            autoComplete="email"
            inputMode="email"
            className="w-full border rounded-md px-3 py-2 mt-1 outline-none focus:ring-2 focus:ring-primary"
            placeholder="ban@quanancuaban.vn"
            value={email}
            onChange={e => setEmail(e.target.value.trim())}
            onKeyDown={e => { if (e.key === 'Enter' && emailValid && !busy) sendOtp(); }}
          />
        </>
      ) : (
        <>
          <label className="text-sm font-medium">Nhập mã OTP (đã gửi đến {email})</label>
          <input
            className="w-full border rounded-md px-3 py-3 text-center text-2xl tracking-widest mt-1 outline-none focus:ring-2 focus:ring-primary"
            maxLength={6}
            inputMode="numeric"
            autoComplete="one-time-code"
            value={otp}
            onChange={e => setOtp(e.target.value.replace(/\D/g, ''))}
            onKeyDown={e => { if (e.key === 'Enter' && otp.length === 6 && !busy) verifyOtp(); }}
          />
        </>
      )}

      {error && <p className="text-danger text-sm mt-3">{error}</p>}

      <button
        disabled={busy || (otpSent ? otp.length !== 6 : !emailValid)}
        onClick={otpSent ? verifyOtp : sendOtp}
        className="w-full mt-6 py-3 rounded-full bg-primary text-primary-foreground font-semibold disabled:opacity-50"
      >
        {busy ? 'Đang xử lý...' : otpSent ? 'Xác nhận' : 'Gửi mã OTP'}
      </button>

      {otpSent && (
        <button onClick={() => { setOtpSent(false); setOtp(''); setError(null); }} className="w-full mt-2 text-sm text-muted-foreground hover:underline">
          Đổi email khác
        </button>
      )}
    </div>
  );
}

export default function LoginPage() {
  return (
    <main className="min-h-screen flex items-center justify-center p-6 bg-muted/30">
      <Suspense fallback={<div className="text-muted-foreground text-sm">Đang tải...</div>}>
        <LoginForm />
      </Suspense>
    </main>
  );
}
