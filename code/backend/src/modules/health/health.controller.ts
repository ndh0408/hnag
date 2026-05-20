import { Controller, Get, Inject } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import IORedis from 'ioredis';
import { PrismaService } from '../../common/prisma/prisma.service';
import { REDIS } from '../../common/redis/redis.module';

@ApiTags('Health')
@Controller('/health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  @Get()
  async health() {
    const [db, cache] = await Promise.all([
      this.prisma.$queryRawUnsafe('SELECT 1').then(() => true).catch(() => false),
      this.redis.ping().then((r) => r === 'PONG').catch(() => false),
    ]);
    return { __raw__: true, payload: { ok: db && cache, db, cache, ts: new Date().toISOString() } };
  }
}
