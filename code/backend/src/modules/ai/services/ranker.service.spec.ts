import { RankerService } from './ranker.service';
import type { Candidate } from './candidate-generator.service';
import type { EnrichedContext } from './context-builder.service';

describe('RankerService', () => {
  const svc = new RankerService();

  const baseCtx: EnrichedContext = {
    hour: 12, weekday: 3, weather: { temp: 28, condition: 'rain' },
    recentFoodIds: [], allergies: [], isLateNight: false, isWeekend: false,
    cuisinePref: ['vietnamese'],
    budget: { min: 30000, max: 80000 },
    mood: 'sad',
    timeMin: 30,
  };

  const cand = (over: Partial<Candidate>): Candidate => ({
    foodId: '00000000-0000-0000-0000-000000000000',
    title: 'Phở bò', cuisine: 'vietnamese', category: 'noodle',
    priceVnd: 55000, rating: { avg: 4.7, count: 1000 },
    tags: ['ấm bụng', 'comfort'],
    popularity: 1000, trendingScore: 50,
    origin: 'trending', scores: {}, reasonCodes: [],
    ...over,
  });

  it('ranks higher score first', async () => {
    const list = await svc.rank({
      userId: 'u',
      enriched: baseCtx,
      candidates: [
        cand({ title: 'Sushi',     cuisine: 'japanese',  rating: { avg: 4.3, count: 50  } }),
        cand({ title: 'Bún bò Huế', cuisine: 'vietnamese', rating: { avg: 4.8, count: 800 }, tags: ['phở', 'ấm bụng'] }),
      ],
    });
    expect(list[0].title).toContain('Bún');
  });

  it('diversifies cuisines in top 5', () => {
    const cs = [
      cand({ foodId: 'a', cuisine: 'vietnamese', title: 'Phở 1',     scores: { final: 0.9 } }),
      cand({ foodId: 'b', cuisine: 'vietnamese', title: 'Bún chả',    scores: { final: 0.85 } }),
      cand({ foodId: 'c', cuisine: 'vietnamese', title: 'Cơm tấm',    scores: { final: 0.84 } }),
      cand({ foodId: 'd', cuisine: 'vietnamese', title: 'Phở 4',     scores: { final: 0.83 } }),
      cand({ foodId: 'e', cuisine: 'korean',     title: 'Bibimbap',  scores: { final: 0.82 } }),
      cand({ foodId: 'f', cuisine: 'japanese',   title: 'Sushi',     scores: { final: 0.80 } }),
    ];
    const top = svc.diversify(cs, 5);
    const counts = top.reduce<Record<string, number>>((acc, c) => {
      acc[c.cuisine] = (acc[c.cuisine] ?? 0) + 1; return acc;
    }, {});
    expect(counts['vietnamese']).toBeLessThanOrEqual(2);
  });
});
