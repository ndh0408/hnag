import { Injectable, Inject } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import IORedis from 'ioredis';

import { PrismaService } from '../../../common/prisma/prisma.service';
import { REDIS } from '../../../common/redis/redis.module';

export interface EnrichedContext {
  hunger?: number;
  budget?: { min: number; max: number };
  timeMin?: number;
  mood?: string;
  inferredMood?: string;
  with?: 'solo' | 'couple' | 'friends' | 'family';
  diet?: string;
  cuisinePref?: string[];
  location?: { lat: number; lng: number };
  city?: string;
  district?: string;
  hour: number;
  weekday: number;
  weather: { temp: number; condition: string };
  recentFoodIds: string[];
  friendActivity?: { foodId: string; count: number }[];
  allergies: string[];
  isLateNight: boolean;
  isWeekend: boolean;
}

@Injectable()
export class ContextBuilderService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly http: HttpService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  async enrich(userId: string, raw: Record<string, unknown>): Promise<EnrichedContext> {
    const now = new Date();
    const hour = now.getHours();
    const weekday = now.getDay();

    const loc = raw.location as { lat: number; lng: number } | undefined;
    const weather = loc ? await this.getWeather(loc) : { temp: 28, condition: 'clear' };
    const reverse = loc ? await this.reverseGeo(loc) : null;

    const prefs = await this.prisma.user_preferences.findUnique({ where: { user_id: userId } });
    const recent = await this.prisma.food_interactions.findMany({
      where: { user_id: userId, action: { in: ['ate', 'ordered', 'cooked'] as any } },
      orderBy: { created_at: 'desc' },
      take: 20,
      select: { food_id: true },
    });

    return {
      hunger: typeof raw.hunger === 'number' ? raw.hunger : undefined,
      budget: raw.budget as any,
      timeMin: typeof raw.timeMin === 'number' ? raw.timeMin : undefined,
      mood: raw.mood as string | undefined,
      inferredMood: this.inferMood(hour, weekday, weather),
      with: raw.with as any,
      diet: (raw.diet as string) ?? prefs?.diet_type,
      cuisinePref: (raw.cuisinePref as string[] | undefined) ?? prefs?.cuisines_love ?? [],
      location: loc,
      city: reverse?.city,
      district: reverse?.district,
      hour,
      weekday,
      weather,
      recentFoodIds: recent.map((r) => r.food_id).filter((id): id is string => !!id),
      allergies: prefs?.allergies ?? [],
      isLateNight: hour >= 22 || hour < 5,
      isWeekend: weekday === 0 || weekday === 6,
    };
  }

  private async getWeather(loc: { lat: number; lng: number }): Promise<{ temp: number; condition: string }> {
    const cacheKey = `weather:${loc.lat.toFixed(2)}:${loc.lng.toFixed(2)}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    if (!process.env.OPENWEATHER_API_KEY) {
      return { temp: 28, condition: 'clear' };
    }
    try {
      const { data } = await firstValueFrom(
        this.http.get('https://api.openweathermap.org/data/2.5/weather', {
          params: { lat: loc.lat, lon: loc.lng, appid: process.env.OPENWEATHER_API_KEY, units: 'metric' },
          timeout: 1500,
        }),
      );
      const result = { temp: data.main.temp, condition: data.weather?.[0]?.main?.toLowerCase() ?? 'clear' };
      await this.redis.setex(cacheKey, 1800, JSON.stringify(result));
      return result;
    } catch {
      return { temp: 28, condition: 'clear' };
    }
  }

  private async reverseGeo(loc: { lat: number; lng: number }): Promise<{ city?: string; district?: string } | null> {
    // Stubbed — wire up Mapbox / Google Geocoding in prod
    return null;
  }

  /** Heuristic mood inference when user didn't pick one. */
  private inferMood(hour: number, weekday: number, weather: { temp: number; condition: string }): string | undefined {
    if (hour >= 22 || hour < 5) return 'late_night';
    if (weather.condition === 'rain') return 'chill';
    if (weekday === 0 || weekday === 6) return 'chill';
    if (hour >= 11 && hour < 14) return undefined; // lunch, neutral
    return undefined;
  }
}
