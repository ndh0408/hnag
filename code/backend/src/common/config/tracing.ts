import { Logger } from '@nestjs/common';

/**
 * OpenTelemetry distributed tracing — lazy-require hook.
 *
 * Audit prompt-pack §8 ("Observability — distributed tracing"). Backend
 * already has structured logs (pino), error aggregation (Sentry), metrics
 * (Prometheus /metrics) — the last missing piece is tracing: per-request
 * spans across the controller → service → Prisma → external call chain
 * so we can answer "where exactly did this 4-second AI suggest spend its
 * time?" without guess-and-check.
 *
 * Pattern mirrors common/config/sentry.ts:
 *   - If @opentelemetry/sdk-node isn't installed yet → no-op, log once.
 *   - If installed but OTEL_EXPORTER_OTLP_ENDPOINT is unset → no-op.
 *   - If both present → init the SDK with sensible defaults, register
 *     standard auto-instrumentations (http, express, pg, ioredis, nestjs).
 *
 * To activate in production:
 *   1. Add to package.json:
 *        "@opentelemetry/sdk-node": "^0.55"
 *        "@opentelemetry/auto-instrumentations-node": "^0.50"
 *        "@opentelemetry/exporter-trace-otlp-http": "^0.55"
 *      (Bump majors when the OTel JS team ships.)
 *   2. Set in hnag.env:
 *        OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
 *        OTEL_SERVICE_NAME=hnag-backend
 *        OTEL_TRACES_SAMPLER_ARG=0.1     # 10% sample
 *   3. Run a collector (Jaeger / Tempo / Grafana Agent / Honeycomb).
 *
 * Backend stays bootable even if any of those steps are missing —
 * fail-open is the right call here (telemetry must never crash the app).
 *
 * Call once from main.ts BEFORE NestFactory.create — auto-instrumentation
 * hooks attach at require time, so the order matters.
 */
export function initTracing(): void {
  const logger = new Logger('OpenTelemetry');
  const endpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT;
  if (!endpoint) return;

  let NodeSDK: any;
  let OTLPTraceExporter: any;
  let getNodeAutoInstrumentations: any;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    ({ NodeSDK } = require('@opentelemetry/sdk-node'));
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    ({ OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http'));
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    ({ getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node'));
  } catch {
    logger.warn('OTEL_EXPORTER_OTLP_ENDPOINT set but @opentelemetry/sdk-node not installed — skipping');
    return;
  }

  try {
    const serviceName = process.env.OTEL_SERVICE_NAME ?? 'hnag-backend';
    const sampleRate = Number(process.env.OTEL_TRACES_SAMPLER_ARG ?? '0.1');

    const sdk = new NodeSDK({
      serviceName,
      traceExporter: new OTLPTraceExporter({ url: `${endpoint.replace(/\/$/, '')}/v1/traces` }),
      instrumentations: [
        getNodeAutoInstrumentations({
          // Don't trace static `/health` polling — UptimeRobot hits us
          // every minute, that's pure noise in the trace store.
          '@opentelemetry/instrumentation-http': {
            ignoreIncomingRequestHook: (req: any) =>
              /^\/(health|metrics)(\?|$)/.test(req.url ?? ''),
          },
          // pg auto-instrumentation captures every SQL — useful but heavy.
          // Tune sampling at the collector if it gets noisy.
        }),
      ],
    });

    sdk.start();
    logger.log(
      `OpenTelemetry initialized · service=${serviceName} endpoint=${endpoint} sample=${sampleRate}`,
    );

    // Graceful flush — give in-flight spans a chance to ship on SIGTERM.
    process.once('SIGTERM', async () => {
      try {
        await sdk.shutdown();
      } catch (err) {
        logger.warn(`OTel shutdown error: ${(err as Error).message}`);
      }
    });
  } catch (err) {
    logger.warn(`OTel init failed: ${(err as Error).message}`);
  }
}
