'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const r = useRouter();
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function sendOtp() {
    setBusy(true); setError(null);
    try {
      const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/v1/auth/otp/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: `+84${phone}` }),
      });
      if (!res.ok) throw new Error('Send OTP failed');
      setOtpSent(true);
    } catch (e: any) { setError(e.message); } finally { setBusy(false); }
  }

  async function verifyOtp() {
    setBusy(true); setError(null);
    try {
      const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/v1/auth/otp/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: `+84${phone}`, code: otp, device: { deviceId: 'dashboard', platform: 'web' } }),
      });
      const j = await res.json();
      if (!j.success) throw new Error('OTP không đúng');
      // Store tokens (in real app: secure cookie or httpOnly endpoint)
      localStorage.setItem('hnag_token', j.data.accessToken);
      localStorage.setItem('hnag_refresh', j.data.refreshToken);
      r.push('/dashboard');
    } catch (e: any) { setError(e.message); } finally { setBusy(false); }
  }

  return (
    <main className="min-h-screen flex items-center justify-center p-6 bg-muted/30">
      <div className="bg-white rounded-2xl shadow-xl p-8 w-full max-w-md">
        <div className="text-center mb-6">
          <div className="text-5xl mb-2">🍜</div>
          <h1 className="text-2xl font-bold">HNAG Dashboard</h1>
          <p className="text-muted-foreground text-sm">Đăng nhập với tài khoản chủ quán</p>
        </div>

        {!otpSent ? (
          <>
            <label className="text-sm font-medium">Số điện thoại</label>
            <div className="flex gap-2 mt-1">
              <span className="px-3 flex items-center bg-muted rounded-md text-sm">+84</span>
              <input
                className="flex-1 border rounded-md px-3 py-2 outline-none focus:ring-2 focus:ring-primary"
                placeholder="901 234 567"
                value={phone}
                onChange={e => setPhone(e.target.value.replace(/\D/g, ''))}
              />
            </div>
          </>
        ) : (
          <>
            <label className="text-sm font-medium">Nhập mã OTP (đã gửi đến +84{phone})</label>
            <input
              className="w-full border rounded-md px-3 py-3 text-center text-2xl tracking-widest mt-1 outline-none focus:ring-2 focus:ring-primary"
              maxLength={6}
              value={otp}
              onChange={e => setOtp(e.target.value.replace(/\D/g, ''))}
            />
          </>
        )}

        {error && <p className="text-danger text-sm mt-3">{error}</p>}

        <button
          disabled={busy || (otpSent ? otp.length !== 6 : phone.length < 9)}
          onClick={otpSent ? verifyOtp : sendOtp}
          className="w-full mt-6 py-3 rounded-full bg-primary text-primary-foreground font-semibold disabled:opacity-50"
        >
          {busy ? 'Đang xử lý...' : otpSent ? 'Xác nhận' : 'Gửi mã OTP'}
        </button>

        {otpSent && (
          <button onClick={() => { setOtpSent(false); setOtp(''); }} className="w-full mt-2 text-sm text-muted-foreground hover:underline">
            Đổi số khác
          </button>
        )}
      </div>
    </main>
  );
}
