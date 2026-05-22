// NOTE: This module is server-only — it reads httpOnly cookies via next/headers
// and must never be imported into a Client Component. (Avoiding the `server-only`
// package to not add a new dependency; keep imports of this file server-side.)
import { cookies } from 'next/headers';

/**
 * Server-side backend base URL. NEVER expose this as NEXT_PUBLIC_* — the whole
 * point of the token-exchange route handlers is that the access/refresh tokens
 * stay on the server and live in httpOnly cookies the browser cannot read.
 */
export const API_BASE_URL =
  process.env.API_BASE_URL ?? 'https://api.tothanhthuy.cloud';

export const ACCESS_COOKIE = 'hnag_at';
export const REFRESH_COOKIE = 'hnag_rt';

/**
 * Server-only fetch helper that attaches the httpOnly access cookie as a
 * Bearer token when proxying calls to the HNAG backend.
 *
 * Use this from Server Components, Route Handlers and Server Actions only —
 * it reads the cookie via next/headers and therefore cannot run in the browser.
 */
export async function backendFetch(
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  const token = cookies().get(ACCESS_COOKIE)?.value;

  const headers = new Headers(init.headers);
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (!headers.has('Content-Type') && init.body) {
    headers.set('Content-Type', 'application/json');
  }

  const url = path.startsWith('http')
    ? path
    : `${API_BASE_URL}${path.startsWith('/') ? '' : '/'}${path}`;

  return fetch(url, {
    ...init,
    headers,
    // Dashboard data should reflect current state, not a cached snapshot.
    cache: init.cache ?? 'no-store',
  });
}

/**
 * Convenience wrapper that unwraps the backend's `{ success, data }` envelope.
 * Returns `null` on any non-2xx response or unsuccessful envelope so callers
 * can fall back to a safe UI state instead of throwing during render.
 */
export async function backendJSON<T = unknown>(
  path: string,
  init: RequestInit = {},
): Promise<T | null> {
  try {
    const res = await backendFetch(path, init);
    if (!res.ok) return null;
    const json = await res.json();
    if (json && typeof json === 'object' && 'success' in json) {
      return json.success ? (json.data as T) : null;
    }
    return json as T;
  } catch {
    return null;
  }
}
