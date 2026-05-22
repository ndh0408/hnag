/**
 * Centralised, fail-fast access to security-critical secrets.
 *
 * In production a weak/missing JWT secret is fatal — we refuse to boot rather
 * than silently sign tokens with a guessable key (which would let anyone forge
 * an admin/premium identity).
 */

export function isProd(): boolean {
  return process.env.NODE_ENV === 'production';
}

let cachedJwtSecret: string | null = null;

export function getJwtSecret(): string {
  if (cachedJwtSecret) return cachedJwtSecret;
  const s = process.env.JWT_SECRET;
  if (!s || s.length < 32) {
    if (isProd()) {
      throw new Error(
        'FATAL: JWT_SECRET is missing or too short (need >= 32 chars) in production. Refusing to start.',
      );
    }
    // Non-production only: a clearly-labelled insecure fallback so local dev works.
    // eslint-disable-next-line no-console
    console.warn('[secrets] JWT_SECRET weak/missing — using INSECURE dev fallback (non-prod only).');
    cachedJwtSecret = s && s.length > 0 ? s : 'dev-only-insecure-secret-please-change-me-0123456789';
    return cachedJwtSecret;
  }
  cachedJwtSecret = s;
  return cachedJwtSecret;
}

/** Emails allowed to access the admin GraphQL endpoint (comma-separated). */
export function getAdminEmails(): string[] {
  return (process.env.ADMIN_EMAILS ?? '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
}
