import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { API_BASE_URL, ACCESS_COOKIE, REFRESH_COOKIE } from '@/lib/api';

// Token exchange must happen server-side, so this handler always runs on the server.
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/**
 * POST /api/auth/verify
 * Same-origin proxy to the backend email-OTP verify endpoint.
 * Body: { email: string, code: string }
 *
 * On success the access/refresh tokens are written to httpOnly, Secure,
 * SameSite=Lax cookies and are NEVER returned in the JSON body. This is the
 * core XSS mitigation: client JS can no longer read the tokens.
 */
export async function POST(req: NextRequest) {
  let email: string | undefined;
  let code: string | undefined;
  try {
    ({ email, code } = await req.json());
  } catch {
    return NextResponse.json(
      { success: false, error: 'Yêu cầu không hợp lệ' },
      { status: 400 },
    );
  }

  if (!email || !code) {
    return NextResponse.json(
      { success: false, error: 'Thiếu email hoặc mã OTP' },
      { status: 400 },
    );
  }

  try {
    const res = await fetch(`${API_BASE_URL}/v1/auth/email-otp/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email,
        code,
        device: { deviceId: `web-${crypto.randomUUID()}`, platform: 'web' },
      }),
      cache: 'no-store',
    });

    const json = await res.json().catch(() => null);

    if (!res.ok || !json?.success) {
      return NextResponse.json(
        { success: false, error: 'Mã OTP không đúng hoặc đã hết hạn' },
        { status: res.ok ? 401 : res.status },
      );
    }

    const { accessToken, refreshToken, expiresIn, user } = json.data ?? {};
    if (!accessToken || !refreshToken) {
      return NextResponse.json(
        { success: false, error: 'Phản hồi đăng nhập không hợp lệ' },
        { status: 502 },
      );
    }

    const jar = cookies();
    const secure = process.env.NODE_ENV === 'production';
    // expiresIn is seconds for the access token; fall back to 15 min.
    const accessMaxAge =
      typeof expiresIn === 'number' && expiresIn > 0 ? expiresIn : 60 * 15;

    jar.set(ACCESS_COOKIE, accessToken, {
      httpOnly: true,
      secure,
      sameSite: 'lax',
      path: '/',
      maxAge: accessMaxAge,
    });
    jar.set(REFRESH_COOKIE, refreshToken, {
      httpOnly: true,
      secure,
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 30, // 30 days
    });

    // Return only non-sensitive user info — never the tokens.
    return NextResponse.json({ success: true, data: { user: user ?? null } });
  } catch {
    return NextResponse.json(
      { success: false, error: 'Lỗi kết nối tới máy chủ' },
      { status: 502 },
    );
  }
}
