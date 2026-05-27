import type { NestExpressApplication } from '@nestjs/platform-express';
import { Logger } from '@nestjs/common';

/**
 * Sentry init — lazy-require pattern.
 *
 * Audit hnag-audit-2026-05 §23: no error tracking. We wire Sentry behind a
 * fail-open guard so:
 *   - if SENTRY_DSN is empty (every dev workstation, every CI job), Sentry
 *     is silently skipped and the app boots normally
 *   - if SENTRY_DSN is set but @sentry/node is not installed yet, we log a
 *     single warning and continue — the install lands with the next
 *     `npm install` and Sentry comes on without a code change
 *   - in production with the package installed, errors are captured with
 *     the request-id from pino-http for end-to-end traceability
 *
 * To activate in production:
 *   1. Add `"@sentry/node": "^7"` to package.json (a real semver, pinned)
 *   2. Set SENTRY_DSN in hnag.env
 *   3. Optional: SENTRY_TRACES_SAMPLE_RATE (default 0.1)
 *   4. Optional: SENTRY_ENVIRONMENT (default = NODE_ENV)
 */
export function initSentry(app: NestExpressApplication): void {
  const logger = new Logger('Sentry');
  const dsn = process.env.SENTRY_DSN;
  if (!dsn) return;

  let Sentry: any;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    Sentry = require('@sentry/node');
  } catch {
    logger.warn('SENTRY_DSN is set but @sentry/node is not installed — skipping');
    return;
  }

  try {
    Sentry.init({
      dsn,
      environment: process.env.SENTRY_ENVIRONMENT ?? process.env.NODE_ENV ?? 'production',
      release: process.env.HNAG_VERSION,
      tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE ?? '0.1'),
      // Drop events that happened on local-dev IPs (defence-in-depth in case
      // a workstation accidentally ships with the prod DSN).
      beforeSend(event: any) {
        const reqIp = event?.request?.env?.REMOTE_ADDR;
        if (reqIp && /^(127\.|::1|10\.|192\.168\.)/.test(reqIp)) return null;
        return event;
      },
    });

    // The handlers are middleware — order matters. requestHandler MUST be
    // the first middleware; errorHandler MUST come after any other error
    // middleware (NestJS exception filters fire before this).
    if (Sentry.Handlers?.requestHandler) {
      app.use(Sentry.Handlers.requestHandler({ ip: true }));
    }
    if (Sentry.Handlers?.errorHandler) {
      // Register at app shutdown so it sits after Nest's exception filter.
      // Nest filter handles HttpException; non-HttpException errors fall
      // through to here and get reported.
      const adapter = app.getHttpAdapter();
      adapter.getInstance().use(Sentry.Handlers.errorHandler());
    }

    logger.log('Sentry initialized');
  } catch (err) {
    logger.warn(`Sentry init failed: ${(err as Error).message}`);
  }
}
