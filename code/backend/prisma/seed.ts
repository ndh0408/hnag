/**
 * Prisma seed — minimal demo data for local dev.
 * For full seed (60 foods, 30 restaurants), prefer running `psql -f ../sql/02_seed_data.sql`.
 */
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  console.log('🍜 Seeding demo data...');

  // Demo achievements
  await prisma.$executeRawUnsafe(`
    INSERT INTO achievements (code, name_vi, name_en, description, tier, xp_reward)
    VALUES
      ('first_review', 'Lần đầu review', 'First Review', 'Đăng review đầu tiên', 'common', 50),
      ('ten_dishes',   '10 món đã thử',   '10 Dishes Tried', 'Thử 10 món khác nhau', 'common', 100)
    ON CONFLICT (code) DO NOTHING;
  `);

  // Demo user
  await prisma.$executeRawUnsafe(`
    INSERT INTO users (id, phone, username, display_name, city, district, level, is_premium, foodie_class)
    VALUES ('d0000000-0000-0000-0000-000000000001', '+84901234567', 'thaole', 'Thảo Lê', 'TP.HCM', 'Quận 1', 12, true, 'muc')
    ON CONFLICT (id) DO NOTHING;
  `);

  await prisma.$executeRawUnsafe(`
    INSERT INTO user_preferences (user_id, allergies, diet_type, cuisines_love, spicy_tolerance, budget_min, budget_max, cook_skill, health_goal, daily_calorie)
    VALUES ('d0000000-0000-0000-0000-000000000001', ARRAY['peanut'], 'none', ARRAY['vietnamese','japanese'], 4, 30000, 100000, 'intermediate', 'maintain', 1800)
    ON CONFLICT (user_id) DO NOTHING;
  `);

  console.log('✓ Demo data seeded.');
  console.log('💡 For full catalog data, run: psql $DATABASE_URL -f ../sql/02_seed_data.sql');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
