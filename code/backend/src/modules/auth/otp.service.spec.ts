import { Test } from '@nestjs/testing';
import { OtpService } from './otp.service';
import { REDIS } from '../../common/redis/redis.module';
import { HttpException } from '@nestjs/common';

class FakeRedis {
  store = new Map<string, string>();
  counters = new Map<string, number>();
  async setex(k: string, _ttl: number, v: string) { this.store.set(k, v); }
  async get(k: string)  { return this.store.get(k) ?? null; }
  async del(k: string)  { this.store.delete(k); }
  async incr(k: string) {
    const v = (this.counters.get(k) ?? 0) + 1;
    this.counters.set(k, v);
    return v;
  }
  async expire(_: string, __: number) { return 1; }
}

describe('OtpService', () => {
  let service: OtpService;
  let redis: FakeRedis;

  beforeEach(async () => {
    redis = new FakeRedis();
    const mod = await Test.createTestingModule({
      providers: [OtpService, { provide: REDIS, useValue: redis }],
    }).compile();
    service = mod.get(OtpService);
  });

  it('generates 6-digit OTP and stores it', async () => {
    await service.send('+84901234567');
    const stored = await redis.get('otp:+84901234567');
    expect(stored).toMatch(/^\d{6}$/);
  });

  it('verifies correct code, rejects wrong', async () => {
    await service.send('+84901234567');
    const code = (await redis.get('otp:+84901234567'))!;
    expect(await service.verify('+84901234567', code)).toBe(true);
    expect(await service.verify('+84901234567', code)).toBe(false); // single-use
  });

  it('rate-limits OTP send to 5/hour per phone', async () => {
    for (let i = 0; i < 5; i++) await service.send('+84909999999');
    await expect(service.send('+84909999999')).rejects.toBeInstanceOf(HttpException);
  });
});
