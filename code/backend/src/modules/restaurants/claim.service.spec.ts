import { ClaimService } from './claim.service';

describe('ClaimService - tallyAndDecide thresholds', () => {
  function buildClaim(overrides: any = {}) {
    return {
      id: 'c1', restaurant_id: 'r1', claimant_user_id: 'u1', status: 'pending',
      phone_otp_passed: false, license_score: null, geo_verified: false,
      email_domain_match: false, ...overrides,
    };
  }

  function makeService(claimRow: any) {
    const updated: any[] = [];
    const granted: any[] = [];
    const prisma: any = {
      restaurant_claims: {
        findUnique: jest.fn().mockResolvedValue(claimRow),
        update: jest.fn().mockImplementation(({ data, where }) => {
          const merged = { ...claimRow, ...data };
          updated.push(merged);
          return merged;
        }),
      },
      restaurant_owners: { upsert: jest.fn().mockImplementation((args) => { granted.push(args); return {}; }) },
      restaurants: { update: jest.fn().mockResolvedValue({}), findUnique: jest.fn() },
    };
    const otp: any = {};
    const svc = new ClaimService(prisma, otp);
    return { svc, updated, granted };
  }

  it('auto-approves when score >= 0.7 (phone+license)', async () => {
    const { svc, updated, granted } = makeService(buildClaim({
      phone_otp_passed: true, license_score: 0.4,
    }));
    await (svc as any).tallyAndDecide('c1');
    const last = updated.at(-1);
    expect(last.status).toBe('approved');
    expect(granted.length).toBe(1);
  });

  it('manual_review when 0.4 ≤ score < 0.7', async () => {
    const { svc, updated, granted } = makeService(buildClaim({
      phone_otp_passed: true,
    }));
    await (svc as any).tallyAndDecide('c1');
    expect(updated.at(-1).status).toBe('manual_review');
    expect(granted.length).toBe(0);
  });

  it('pending when score < 0.4', async () => {
    const { svc, updated, granted } = makeService(buildClaim({}));
    await (svc as any).tallyAndDecide('c1');
    expect(updated.at(-1).status).toBe('pending');
    expect(granted.length).toBe(0);
  });
});
