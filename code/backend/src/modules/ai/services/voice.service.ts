import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import OpenAI, { toFile } from 'openai';

const MOODS = ['happy', 'sad', 'stress', 'lonely', 'chill', 'late_night', 'tired', 'rushed', 'broke'];

/**
 * Real voice "Hỏi Hà": Whisper transcribes the audio, then GPT-4o-mini maps the
 * utterance to a mood/intent the recommender can act on.
 */
@Injectable()
export class VoiceService {
  private readonly logger = new Logger(VoiceService.name);
  private readonly client: OpenAI | null;

  constructor() {
    this.client = process.env.OPENAI_API_KEY
      ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 30_000, maxRetries: 1 })
      : null;
  }

  async transcribe(buf: Buffer, filename = 'audio.m4a'): Promise<string> {
    const client = this.client;
    if (!client) throw new BadRequestException('Tính năng giọng nói chưa được bật');
    const file = await toFile(buf, filename);
    const r = await client.audio.transcriptions.create({
      file,
      model: 'whisper-1',
      language: 'vi',
    });
    return (r.text ?? '').trim();
  }

  /** Map a free-text utterance → { mood?, query? }. */
  async intent(text: string): Promise<{ mood?: string; query?: string }> {
    if (!text) return {};
    const client = this.client;
    if (!client) return { query: text };
    try {
      const c = await client.chat.completions.create({
        model: 'gpt-4o-mini',
        response_format: { type: 'json_object' },
        temperature: 0.2,
        max_tokens: 120,
        messages: [
          {
            role: 'system',
            content: `Phân tích câu nói về ăn uống của người Việt. Trả JSON {"mood": một trong [${MOODS.join(', ')}] hoặc null, "query": "tóm tắt món/khẩu vị muốn ăn"}.`,
          },
          { role: 'user', content: text },
        ],
      });
      const p = JSON.parse(c.choices[0]?.message?.content ?? '{}');
      return { mood: MOODS.includes(p.mood) ? p.mood : undefined, query: p.query ?? text };
    } catch (e) {
      this.logger.warn(`voice intent failed: ${(e as Error).message}`);
      return { query: text };
    }
  }
}

export function audioExtFromMime(mime?: string): string {
  switch ((mime ?? '').toLowerCase()) {
    case 'audio/mp4':
    case 'audio/x-m4a':
    case 'audio/m4a': return 'm4a';
    case 'audio/webm': return 'webm';
    case 'audio/mpeg':
    case 'audio/mp3': return 'mp3';
    case 'audio/wav':
    case 'audio/x-wav': return 'wav';
    case 'audio/ogg': return 'ogg';
    default: return 'm4a';
  }
}
