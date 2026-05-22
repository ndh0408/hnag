import { NextRequest, NextResponse } from 'next/server';

const ACCESS_COOKIE = 'hnag_at';

/**
 * Protects /dashboard/:path*. This is only a presence check on the httpOnly
 * access cookie — it gates the UI cheaply at the edge. Real verification of the
 * token happens server-side whenever we call the backend (see src/lib/api.ts).
 */
export function middleware(req: NextRequest) {
  const hasToken = Boolean(req.cookies.get(ACCESS_COOKIE)?.value);

  if (!hasToken) {
    const loginUrl = new URL('/login', req.url);
    loginUrl.searchParams.set('next', req.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*'],
};
