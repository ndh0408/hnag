import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { ACCESS_COOKIE, REFRESH_COOKIE } from '@/lib/api';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

/**
 * POST /api/auth/logout
 * Clears the httpOnly auth cookies. (Backend token revocation can be wired in
 * later; clearing the cookies immediately ends the browser session.)
 */
export async function POST() {
  const jar = cookies();
  jar.delete(ACCESS_COOKIE);
  jar.delete(REFRESH_COOKIE);
  return NextResponse.json({ success: true });
}
