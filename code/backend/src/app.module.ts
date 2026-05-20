import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
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

    // Background queues
    BullModule.forRootAsync({
      useFactory: () => ({
        connection: {
          host: process.env.REDIS_HOST ?? 'localhost',
          port: Number(process.env.REDIS_PORT ?? 6379),
        },
      }),
    }),

    // GraphQL (admin dashboard endpoint)
    GraphQLModule.forRoot<ApolloDriverConfig>({
      driver: ApolloDriver,
      autoSchemaFile: false,
      typePaths: [require('path').join(__dirname, 'admin/admin.graphql')],
      playground: process.env.NODE_ENV !== 'production',
      path: '/graphql',
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
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(LoggerMiddleware).forRoutes('*');
  }
}
