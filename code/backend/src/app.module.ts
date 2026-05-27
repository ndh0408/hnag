import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { GqlThrottlerGuard } from './common/guards/gql-throttler.guard';
import { PremiumGuard } from './common/guards/premium.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { AiCooldownGuard } from './common/guards/ai-cooldown.guard';
import { AuditLogInterceptor } from './common/interceptors/audit-log.interceptor';
import { QueuesModule } from './common/queues/queues.module';
import { FeatureFlagsModule } from './common/config/feature-flags.module';
import { AnalyticsModule } from './common/analytics/analytics.module';
import { GraphQLModule } from '@nestjs/graphql';
import { ApolloDriver, ApolloDriverConfig } from '@nestjs/apollo';
import { ScheduleModule } from '@nestjs/schedule';
import { BullModule } from '@nestjs/bullmq';

import { PrismaModule } from './common/prisma/prisma.module';
import { RedisModule } from './common/redis/redis.module';
import { LoggerMiddleware } from './common/middlewares/logger.middleware';

import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { AiModule } from './modules/ai/ai.module';
import { FoodsModule } from './modules/foods/foods.module';
import { RestaurantsModule } from './modules/restaurants/restaurants.module';
import { GroupsModule } from './modules/groups/groups.module';
import { OrdersModule } from './modules/orders/orders.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { SubscriptionsModule } from './modules/subscriptions/subscriptions.module';
import { HealthModule } from './modules/health/health.module';
import { AdminModule } from './admin/admin.module';
import { CoupleModule } from './modules/couple/couple.module';
import { ChallengesModule } from './modules/challenges/challenges.module';
import { BoostModule } from './modules/boost/boost.module';
import { PostsModule } from './modules/posts/posts.module';
import { MealModule } from './modules/meal/meal.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, cache: true }),

    // Rate limiting — 100 req/min per IP global; per-route overrides via @Throttle
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]),

    // Background queues. Single source of truth = REDIS_URL so we don't drift
    // from RedisModule + RedisIoAdapter (both use REDIS_URL). The previous
    // hardcoded REDIS_HOST/PORT defaulted to localhost when only REDIS_URL
    // was set in the deploy env, crashing BullMQ at boot.
    BullModule.forRootAsync({
      useFactory: () => {
        const url = new URL(process.env.REDIS_URL ?? 'redis://localhost:6379');
        return {
          connection: {
            host: url.hostname,
            port: Number(url.port || 6379),
            password: url.password || undefined,
            username: url.username || undefined,
            db: url.pathname && url.pathname.length > 1 ? Number(url.pathname.slice(1)) : undefined,
          },
        };
      },
    }),

    // GraphQL (admin dashboard endpoint). Protected by GqlAdminGuard on every
    // resolver; introspection + playground are OFF by default in every
    // environment, including staging. Audit hnag-audit-2026-05 #11: staging
    // is often less protected than prod and was leaking the admin schema.
    // Operators can re-enable explicitly via GRAPHQL_INTROSPECTION=true (e.g.
    // inside the home network) without flipping NODE_ENV.
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: false,
      typePaths: [require('path').join(__dirname, 'admin/admin.graphql')],
      playground: process.env.GRAPHQL_PLAYGROUND === 'true',
      introspection: process.env.GRAPHQL_INTROSPECTION === 'true',
      path: '/graphql',
      context: ({ req, res }: any) => ({ req, res }),
    }),

    // Cron
    ScheduleModule.forRoot(),

    // Shared infra
    PrismaModule,
    RedisModule,

    // Domain modules
    AuthModule,
    UsersModule,
    AiModule,
    FoodsModule,
    RestaurantsModule,
    GroupsModule,
    OrdersModule,
    NotificationsModule,
    RealtimeModule,
    SubscriptionsModule,
    HealthModule,
    AdminModule,
    CoupleModule,
    ChallengesModule,
    BoostModule,
    PostsModule,
    MealModule,

    // Background workers (BullMQ). Drains otp:email + push:fcm queues so
    // the auth + notifications routes return without blocking on SMTP/FCM
    // round-trips. Audit hnag-audit-2026-05 §9.
    QueuesModule,

    // Cross-cutting concerns made injectable everywhere via @Global().
    AnalyticsModule,
    FeatureFlagsModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: GqlThrottlerGuard },
    // PremiumGuard is opt-in via @Premium() — not registered as APP_GUARD.
    // It's exported here so any module's controller can pull it in via
    // the @Premium() composite decorator without per-module provider wiring.
    PremiumGuard,
    RolesGuard,
    AiCooldownGuard,
    AuditLogInterceptor,
  ],
  exports: [PremiumGuard, RolesGuard, AiCooldownGuard, AuditLogInterceptor],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggerMiddleware).forRoutes('*');
  }
}
