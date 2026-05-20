import { MoodEngineService } from './mood-engine.service';

describe('MoodEngineService', () => {
  const m = new MoodEngineService();

  const c = (title: string, tags: string[] = []): any => ({
    title, tags, scores: {}, reasonCodes: [], cuisine: 'vietnamese', category: 'noodle',
    priceVnd: 50000, rating: { avg: 4.5, count: 100 }, popularity: 100, trendingScore: 50,
    foodId: 'x', origin: 'trending',
  });

  it('boosts sad mood comfort foods', () => {
    const out = m.bias([c('Sushi'), c('Cháo gà')], 'sad');
    expect(out[0].title).toBe('Cháo gà');
  });

  it('forbids heavy food for late_night', () => {
    const out = m.bias([c('Lẩu Thái'), c('Cháo gà'), c('Pizza')], 'late_night');
    // Cháo gà should top, Lẩu/Pizza demoted
    expect(out[0].title).toBe('Cháo gà');
    expect(out[out.length - 1].scores.moodBoost).toBeLessThan(0);
  });
});
