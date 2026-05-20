import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { HealthModule } from '../src/modules/health/health.module';
import { PrismaService } from '../src/common/prisma/prisma.service';
import { REDIS } from '../src/common/redis/redis.module';

describe('Health (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const mod: TestingModule = await Test.createTestingModule({
      imports: [HealthModule],
    })
      .overrideProvider(PrismaService)
      .useValue({ $queryRawUnsafe: jest.fn().mockResolvedValue([{ '?column?': 1 }]) })
      .overrideProvider(REDIS)
      .useValue({ ping: jest.fn().mockResolvedValue('PONG') })
      .compile();

    app = mod.createNestApplication();
    await app.init();
  });

  afterAll(async () => await app.close());

  it('GET /health returns ok', async () => {
    const res = await request(app.getHttpServer()).get('/health').expect(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.db).toBe(true);
    expect(res.body.cache).toBe(true);
  });
});
