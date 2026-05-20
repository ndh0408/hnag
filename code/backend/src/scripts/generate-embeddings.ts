/**
 * One-shot job: generate text embeddings for all foods + store in DB.
 * Run via: docker exec hnag-backend node /app/dist/scripts/generate-embeddings.js
 * Or: ts-node scripts/generate-embeddings.ts
 *
 * Needs: OPENAI_API_KEY. Uses text-embedding-3-small (1536-dim, $0.00002 per 1K tokens).
 * Cost for 60 foods: < $0.01
 */
import { PrismaClient } from '@prisma/client';
import OpenAI from 'openai';

const prisma = new PrismaClient();
const openai = process.env.OPENAI_API_KEY ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY }) : null;

async function main() {
  if (!openai) {
    console.log('⚠ OPENAI_API_KEY not set — skipping embedding generation');
    return;
  }

  const foods = await prisma.foods.findMany({ where: { status: 'active' } });
  console.log(`Processing ${foods.length} foods...`);

  let processed = 0;
  let totalTokens = 0;

  // Batch by 20 to amortize API calls
  for (let i = 0; i < foods.length; i += 20) {
    const batch = foods.slice(i, i + 20);
    const inputs = batch.map((f) => {
      const parts = [
        f.name_vi,
        f.name_en,
        f.description,
        `cuisine: ${f.cuisine}`,
        `category: ${f.category ?? ''}`,
        `tags: ${[...(f.flavor_tags ?? []), ...(f.mood_tags ?? []), ...(f.vibe_tags ?? [])].join(', ')}`,
        `region: ${f.origin_region ?? ''}`,
      ].filter(Boolean);
      return parts.join(' · ');
    });

    const resp = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: inputs,
      dimensions: 256, // smaller = cheaper, faster cosine search
    });

    totalTokens += resp.usage?.total_tokens ?? 0;

    for (let j = 0; j < batch.length; j++) {
      const food = batch[j];
      const vec = resp.data[j].embedding;
      // Store as JSONB array in food_dna field (or new column embedding)
      await prisma.foods.update({
        where: { id: food.id },
        data: {
          // Store in the nutrition jsonb field as a workaround for now
          // Production: add `embedding vector(256)` column with pgvector
          nutrition: {
            ...((food.nutrition as any) || {}),
            __embedding: vec,
          } as any,
        },
      });
      processed++;
    }
    console.log(`  ✓ ${processed}/${foods.length} processed`);
  }

  console.log(`\n✅ Done. Total tokens: ${totalTokens}, est cost: $${(totalTokens / 1_000_000 * 0.02).toFixed(4)}`);
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
