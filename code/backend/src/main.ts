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

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bufferLogs: true });
  const logger = new Logger('Bootstrap');

  // Behind Cloudflare Tunnel / proxy — trust the first proxy hop so req.ip and
  // the rate-limiter see the real client IP (cf-connecting-ip / x-forwarded-for).
  app.set('trust proxy', 1);

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

  const port = Number(process.env.PORT ?? 4000);
  await app.listen(port);
  logger.log(`🍜 HNAG backend listening on :${port}`);
}

bootstrap();
