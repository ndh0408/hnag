import 'reflect-metadata';
// IMPORTANT: tracing must be imported AND initialized before any other code
// that creates HTTP/DB clients — OTel auto-instrumentation hooks attach at
// require-time, so a later init misses the early-boot spans.
import { initTracing } from './common/config/tracing';
initTracing();

import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { RedisIoAdapter } from './common/adapters/redis-io.adapter';
import helmet from 'helmet';

import { AppModule } from './app.module';
import { EnvelopeInterceptor } from './common/interceptors/envelope.interceptor';
import { AuditLogInterceptor } from './common/interceptors/audit-log.interceptor';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { isProd } from './common/config/secrets';
import { httpLogger } from './common/config/logger';
import { initSentry } from './common/config/sentry';

// Audit #31: BigInt comes back from `food_interactions.id` etc. but
// JSON.stringify(bigint) throws by default. Patch the prototype so any
// downstream serializer (HTTP responses, log lines) coerces to string.
// eslint-disable-next-line @typescript-eslint/no-unused-vars
(BigInt.prototype as any).toJSON = function () { return this.toString(); };

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: true,
    // Preserve the raw request body so payment webhooks can verify HMAC
    // signatures against the exact bytes the provider signed. Without this,
    // express re-serialises the parsed JSON and any whitespace or key-order
    // change breaks signature verification.
    rawBody: true,
  });
  const logger = new Logger('Bootstrap');

  // Audit #10: we sit behind Cloudflare Tunnel → nginx → backend, so there
  // are TWO proxy hops in front of Express. `trust proxy 1` makes req.ip
  // return the FIRST upstream (nginx) instead of the real client. Set to 2
  // so the rate-limiter / req.ip sees the real client IP from
  // cf-connecting-ip / x-forwarded-for. The nginx config in
  // code/infra/server/nginx.conf is updated in lock-step to forward
  // X-Forwarded-For correctly.
  app.set('trust proxy', Number(process.env.TRUST_PROXY_DEPTH ?? 2));

  // Observability: Sentry FIRST (must wrap subsequent middleware to attach
  // request scope), then structured logs (audit hnag-audit-2026-05 §23 —
  // pino was installed but not wired). Mounted before helmet so the
  // request-id is set on every response, including 4xx security rejections.
  initSentry(app);
  app.use(httpLogger);

  // Security headers. CSP enabled in production; relaxed in dev only so the
  // GraphQL playground works locally.
  app.use(
    helmet({
      contentSecurityPolicy: isProd() ? undefined : false,
    }),
  );

  // CORS: explicit allowlist only. Never '*' with credentials.
  const corsOrigins = (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  app.enableCors({
    origin: corsOrigins.length ? corsOrigins : false,
    credentials: true,
  });

  // Larger JSON body limit for the base64 image (fridge-scan) and audio (voice)
  // payloads. Bounded; abuse is limited by per-route throttling + auth.
  app.useBodyParser('json', { limit: '16mb' });

  // Global pipes / interceptors / filters
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  // Order matters: AuditLogInterceptor runs FIRST so it can observe both
  // successful + envelope-wrapped responses. Envelope runs after audit so
  // the audit log sees the unwrapped raw value.
  app.useGlobalInterceptors(
    app.get(AuditLogInterceptor),
    new EnvelopeInterceptor(),
  );
  app.useGlobalFilters(new AllExceptionsFilter());

  // API prefix
  app.setGlobalPrefix('v1', { exclude: ['/health', '/graphql', '/metrics'] });

  // WebSocket with Redis adapter (cross-pod fanout)
  const wsAdapter = new RedisIoAdapter(app);
  await wsAdapter.connectToRedis();
  app.useWebSocketAdapter(wsAdapter);

  // Swagger (dev/staging only)
  if (process.env.NODE_ENV !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('HNAG API')
      .setDescription('Hôm Nay Ăn Gì? API')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const doc = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('docs', app, doc);
  }

  // Honour SIGTERM / SIGINT so in-flight requests can drain before the
  // container is killed. Without this, every deploy interrupts whatever
  // POST /v1/orders or /v1/auth/email-otp/verify happens to be running.
  // Audit hnag-audit-2026-05 #20 (operational): 5-10s downtime per deploy.
  app.enableShutdownHooks();

  const port = Number(process.env.PORT ?? 4000);
  await app.listen(port);
  logger.log(`🍜 HNAG backend listening on :${port}`);

  for (const signal of ['SIGTERM', 'SIGINT'] as const) {
    process.once(signal, async () => {
      logger.log(`Received ${signal} — draining connections…`);
      try {
        await app.close();
        logger.log('Shutdown complete.');
        process.exit(0);
      } catch (err) {
        logger.error(`Shutdown error: ${(err as Error).message}`);
        process.exit(1);
      }
    });
  }
}

bootstrap();
