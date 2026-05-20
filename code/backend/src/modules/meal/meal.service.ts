import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma/prisma.service';

type Slot = 'breakfast' | 'lunch' | 'dinner' | 'snack';
const DAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

@Injectable()
export class MealService {
  constructor(private readonly prisma: PrismaService) {}

  async getCurrent(userId: string) {
    const weekStart = mondayOf(new Date());
    const rows: any[] = await this.prisma.$queryRawUnsafe(
      `SELECT id, week_start, plan_json, total_calorie, total_budget, shopping_list
       FROM meal_plans WHERE user_id = $1::uuid AND week_start = $2::date LIMIT 1`,
      userId, weekStart.toISOString().slice(0, 10),
    );
    return rows[0] ?? null;
  }

  /**
   * Generate a 7-day meal plan respecting the user's budget + meal type tags.
   * Pure heuristic — no LLM. Picks from active foods, avoids repeats within a day.
   */
  async generate(userId: string, opts: { budgetPerDay?: number; diet?: string } = {}) {
    const budgetPerDay = opts.budgetPerDay ?? 150_000;

    const foods = await this.prisma.foods.findMany({
      where: { status: 'active' },
      select: {
        id: true, name_vi: true, primary_image: true, category: true,
        meal_types: true, avg_calories: true, avg_price_vnd: true, diet_tags: true,
      },
    });

    const byMeal: Record<Slot, typeof foods> = {
      breakfast: foods.filter(f => (f.meal_types ?? []).includes('breakfast')),
      lunch: foods.filter(f => (f.meal_types ?? []).includes('lunch')),
      dinner: foods.filter(f => (f.meal_types ?? []).includes('dinner')),
      snack: foods.filter(f => (f.meal_types ?? []).includes('snack')),
    };
    // Fallback pools if a meal type is sparse
    const anyPool = foods;
    const pick = (slot: Slot, used: Set<string>) => {
      const pool = (byMeal[slot].length >= 3 ? byMeal[slot] : anyPool).filter(f => !used.has(f.id));
      if (pool.length === 0) return null;
      const f = pool[Math.floor(Math.random() * pool.length)];
      used.add(f.id);
      return f;
    };

    const plan: Record<string, any> = {};
    let totalCal = 0;
    let totalBudget = 0;
    const groceryAgg = new Map<string, { name: string; count: number }>();

    for (const day of DAYS) {
      const used = new Set<string>();
      const dayPlan: Record<string, any> = {};
      const slots: Slot[] = ['breakfast', 'lunch', 'dinner', 'snack'];
      let dayBudget = 0;
      for (const slot of slots) {
        const f = pick(slot, used);
        if (!f) continue;
        // Respect budget: skip snack if day already over budget
        if (slot === 'snack' && dayBudget > budgetPerDay) continue;
        const price = f.avg_price_vnd ?? 0;
        dayBudget += price;
        totalBudget += price;
        totalCal += f.avg_calories ?? 0;
        dayPlan[slot] = {
          foodId: f.id, name: f.name_vi, image: f.primary_image,
          calories: f.avg_calories, priceVnd: price, category: f.category,
        };
      }
      plan[day] = dayPlan;
    }

    // Build grocery list from chosen foods' ingredients
    const chosenIds = new Set<string>();
    for (const day of Object.values(plan)) {
      for (const slot of Object.values(day as Record<string, any>)) {
        if (slot?.foodId) chosenIds.add(slot.foodId);
      }
    }
    const chosen = await this.prisma.foods.findMany({
      where: { id: { in: [...chosenIds] } },
      select: { ingredients: true },
    });
    for (const f of chosen) {
      const ings = (f.ingredients as any[]) ?? [];
      for (const ing of ings) {
        const name = (typeof ing === 'string' ? ing : ing?.name)?.toString().trim();
        if (!name) continue;
        const key = name.toLowerCase();
        const cur = groceryAgg.get(key);
        if (cur) cur.count++;
        else groceryAgg.set(key, { name, count: 1 });
      }
    }
    const shoppingList = [...groceryAgg.values()].sort((a, b) => b.count - a.count);

    const weekStart = mondayOf(new Date()).toISOString().slice(0, 10);
    await this.prisma.$executeRawUnsafe(
      `INSERT INTO meal_plans (user_id, week_start, plan_json, total_calorie, total_budget, shopping_list)
       VALUES ($1::uuid, $2::date, $3::jsonb, $4, $5, $6::jsonb)
       ON CONFLICT (user_id, week_start) DO UPDATE SET
         plan_json = EXCLUDED.plan_json,
         total_calorie = EXCLUDED.total_calorie,
         total_budget = EXCLUDED.total_budget,
         shopping_list = EXCLUDED.shopping_list,
         updated_at = NOW()`,
      userId, weekStart, JSON.stringify(plan), Math.round(totalCal), totalBudget, JSON.stringify(shoppingList),
    );
    return {
      week_start: weekStart,
      plan_json: plan,
      total_calorie: Math.round(totalCal),
      total_budget: totalBudget,
      shopping_list: shoppingList,
    };
  }
}

function mondayOf(d: Date): Date {
  const date = new Date(d);
  const day = date.getDay(); // 0 Sun .. 6 Sat
  const diff = (day === 0 ? -6 : 1) - day;
  date.setDate(date.getDate() + diff);
  date.setHours(0, 0, 0, 0);
  return date;
}
