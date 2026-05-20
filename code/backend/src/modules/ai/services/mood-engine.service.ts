import { Injectable } from '@nestjs/common';
import { Candidate } from './candidate-generator.service';

const MOOD_TAG_MAP: Record<string, string[]> = {
  sad:        ['comfort', 'cháo', 'phở', 'bún bò', 'chè'],
  stress:     ['lẩu', 'mì cay', 'đồ nướng', 'snack'],
  lonely:     ['cơm tấm', 'cơm gà', 'mì gói', 'comfort'],
  happy:      ['BBQ', 'pizza', 'sushi', 'date'],
  chill:      ['brunch', 'bánh mì', 'cafe', 'tinh tế'],
  late_night: ['cháo', 'mì gói', 'xôi mặn', 'bánh mì'],
  tired:      ['cháo', 'phở', 'nhanh'],
  rushed:     ['nhanh', 'bánh mì', 'cơm văn phòng'],
  broke:      ['bình dân', 'bánh mì', 'cơm bụi'],
};

const FORBIDDEN_LATE: string[] = ['lẩu', 'BBQ', 'chiên', 'pizza']; // không gợi đêm khuya

@Injectable()
export class MoodEngineService {
  bias(candidates: Candidate[], mood: string): Candidate[] {
    const wanted = (MOOD_TAG_MAP[mood] ?? []).map((t) => t.toLowerCase());
    if (wanted.length === 0) return candidates;

    return candidates.map((c) => {
      const title = c.title.toLowerCase();
      const tags = (c.tags ?? []).map((t) => t.toLowerCase());
      const hit = wanted.some((w) => title.includes(w) || tags.includes(w));

      // Late night safety
      const forbidLate = mood === 'late_night' && FORBIDDEN_LATE.some((k) => title.includes(k));

      const moodScore = forbidLate ? -0.5 : hit ? 1 : 0.3;
      c.scores = {
        ...(c.scores ?? {}),
        moodBoost: moodScore,
      };
      if (hit && !forbidLate) c.reasonCodes.push(`mood_engine:${mood}`);
      return c;
    }).sort((a, b) => (b.scores?.moodBoost ?? 0) - (a.scores?.moodBoost ?? 0));
  }
}
