import { Test } from '@nestjs/testing';
import { OtpService } from './otp.service';
import { EmailService } from './email.service';
import { REDIS } from '../../common/redis/redis.module';
import { HttpException } from '@nestjs/common';

class FakeRedis {
  store = new Map<string, string>();
  counters = new Map<string, number>();
  async setex(k: string, _ttl: number, v: string) { this.store.set(k, v); }
  async get(k: string)  { return this.store.get(k) ?? null; }
  async del(k: string)  { this.store.delete(k); this.counters.delete(k); }
  async incr(k: string) {
    const v = (this.counters.get(k) ?? 0) + 1;
    this.counters.set(k, v);
    return v;
  }
  async expire(_: string, __: number) { return 1; }
}

const EMAIL = 'foodie@example.com';
const CODE_KEY = `otp:email:login:${EMAIL}`;

describe('OtpService (email-only)', () => {
  let service: OtpService;
  let redis: FakeRedis;

  beforeEach(async () => {
    redis = new FakeRedis();
    const mod = await Test.createTestingModule({
      providers: [
        OtpService,
        { provide: REDIS, useValue: redis },
        // log-only email provider so no real mail is sent
        { provide: EmailService, useValue: { configured: () => false, sendOtp: jest.fn() } },
      ],
    }).compile();
    service = mod.get(OtpService);
  });

  it('generates a 6-digit OTP and stores it under the login namespace', async () => {
    await service.sendEmail(EMAIL);
    const stored = await redis.get(CODE_KEY);
    expect(stored).toMatch(/^\d{6}$/);
  });

  it('verifies the correct code once, then rejects reuse', async () => {
    await service.sendEmail(EMAIL);
    const code = (await redis.get(CODE_KEY))!;
    expect(await service.verifyEmail(EMAIL, code)).toBe(true);
    expect(await service.verifyEmail(EMAIL, code)).toBe(false); // single-use
  });

  it('rate-limits OTP send to 5/hour per email', async () => {
    for (let i = 0; i < 5; i++) await service.sendEmail(EMAIL);
    await expect(service.sendEmail(EMAIL)).rejects.toBeInstanceOf(HttpException);
  });

  it('locks after too many wrong verify attempts (brute-force protection)', async () => {
    await service.sendEmail(EMAIL);
    for (let i = 0; i < 5; i++) {
      expect(await service.verifyEmail(EMAIL, '000000')).toBe(false);
    }
    await expect(service.verifyEmail(EMAIL, '000000')).rejects.toBeInstanceOf(HttpException);
  });
});
