import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { RedisIoAdapter } from './common/adapters/redis-io.adapter';
import helmet from 'helmet';

import { AppModule } from './app.module';
import { EnvelopeInterceptor } from './common/interceptors/envelope.interceptor';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { isProd } from './common/config/secrets';
import { httpLogger } from './common/config/logger';
import { initSentry } from './common/config/sentry';

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

  // Behind Cloudflare Tunnel / proxy — trust the first proxy hop so req.ip and
  // the rate-limiter see the real client IP (cf-connecting-ip / x-forwarded-for).
  app.set('trust proxy', 1);

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
  app.useGlobalInterceptors(new EnvelopeInterceptor());
  app.useGlobalFilters(new AllExceptionsFilter());

  // API prefix
  app.setGlobalPrefix('v1', { exclude: ['/health', '/graphql'] });

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
