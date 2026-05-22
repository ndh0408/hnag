import { NextRequest, NextResponse } from 'next/server';
import { API_BASE_URL } from '@/lib/api';

// Token exchange must happen server-side, so this handler always runs on the server.
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/**
 * POST /api/auth/send
 * Same-origin proxy to the backend email-OTP send endpoint.
 * Body: { email: string }
 */
export async function POST(req: NextRequest) {
  let email: string | undefined;
  try {
    ({ email } = await req.json());
  } catch {
    return NextResponse.json(
      { success: false, error: 'Yêu cầu không hợp lệ' },
      { status: 400 },
    );
  }

  if (!email || typeof email !== 'string') {
    return NextResponse.json(
      { success: false, error: 'Vui lòng nhập email hợp lệ' },
      { status: 400 },
    );
  }

  try {
    const res = await fetch(`${API_BASE_URL}/v1/auth/email-otp/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
      cache: 'no-store',
    });

    if (!res.ok) {
      return NextResponse.json(
        { success: false, error: 'Không gửi được mã. Vui lòng thử lại.' },
        { status: res.status },
      );
    }

    // Backend returns { success, data: { sent: true } }. We only echo success;
    // there is nothing sensitive to forward here.
    return NextResponse.json({ success: true, data: { sent: true } });
  } catch {
    return NextResponse.json(
      { success: false, error: 'Lỗi kết nối tới máy chủ' },
      { status: 502 },
    );
  }
}
