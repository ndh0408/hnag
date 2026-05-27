import pino, { Logger as PinoLogger } from 'pino';
import pinoHttp from 'pino-http';
import { randomUUID } from 'crypto';
import { isProd } from './secrets';

/**
 * Structured logging setup.
 *
 * Audit hnag-audit-2026-05 §23 ("no structured logging"): pino was installed
 * but never imported. The previous logger emitted ad-hoc string lines that
 * could not be searched in Loki / Datadog / Grafana. This module exposes a
 * single pino instance + an Express middleware that:
 *   - emits one JSON line per HTTP request with method, path, status,
 *     latency, request-id, and user-id (if authenticated)
 *   - propagates `x-request-id` end-to-end (or mints a UUID if absent), so
 *     a frontend log line can be joined with the backend slice that served it
 *   - redacts auth headers and OTP-shaped fields so secrets never land in
 *     centralized logs (this is the second half of audit fix #10 — the OTP
 *     plaintext was already removed at source; this is defence in depth)
 *
 * In dev/non-prod we still emit human-readable text via pino-pretty (auto-
 * detected by pino when stdout is a TTY).
 */

const baseLevel = process.env.LOG_LEVEL || (isProd() ? 'info' : 'debug');

export const baseLogger: PinoLogger = pino({
  level: baseLevel,
  // Single redaction list — applies to every log call, including pinoHttp.
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'req.headers["x-hnag-signature"]',
      'req.headers["x-sepay-signature"]',
      'req.body.code',         // OTP verify
      'req.body.password',
      'req.body.identityToken',
      'req.body.refreshToken',
      'res.headers["set-cookie"]',
    ],
    censor: '[REDACTED]',
  },
  formatters: {
    level(label) {
      return { level: label };
    },
  },
  // ISO timestamps are friendlier in Loki than the default epoch ns.
  timestamp: pino.stdTimeFunctions.isoTime,
  base: {
    service: 'hnag-backend',
    env: process.env.NODE_ENV ?? 'development',
    version: process.env.HNAG_VERSION ?? 'dev',
  },
});

export const httpLogger = pinoHttp({
  logger: baseLogger,
  // Honour an inbound x-request-id so client traces survive across the
  // backend hop. Otherwise mint one — also sent back as a response header.
  genReqId(req, res) {
    const incoming = req.headers['x-request-id'];
    const id = (Array.isArray(incoming) ? incoming[0] : incoming) || randomUUID();
    res.setHeader('x-request-id', id);
    return id;
  },
  customLogLevel(_req, res, err) {
    if (err || res.statusCode >= 500) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  },
  customSuccessMessage(req, res, time) {
    return `${req.method} ${req.url} ${res.statusCode} ${time}ms`;
  },
  customErrorMessage(req, res, err) {
    return `${req.method} ${req.url} ${res.statusCode} err=${err.message}`;
  },
  serializers: {
    req(req) {
      return {
        id: req.id,
        method: req.method,
        url: req.url,
        // userId is populated by JwtStrategy / decorators on authed routes
        userId: (req as any).user?.sub,
      };
    },
    res(res) {
      return { statusCode: res.statusCode };
    },
  },
});
