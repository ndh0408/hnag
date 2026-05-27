import { Injectable, Logger, BadRequestException } from '@nestjs/common';
import OpenAI, { toFile } from 'openai';

import { PromptRegistry } from '../prompts/prompt-registry.service';
import {
  LlmCostTracker,
  chargeOpenaiUsage,
  chargeWhisperUsage,
} from './llm-reason.service';

const MOODS = ['happy', 'sad', 'stress', 'lonely', 'chill', 'late_night', 'tired', 'rushed', 'broke'];

/**
 * Real voice "Hỏi Hà": Whisper transcribes the audio, then GPT-4o-mini maps
 * the utterance to a mood/intent the recommender can act on.
 *
 * Audit AI-trace §C-1 + §C-6 (2026-05-27):
 *   - both Whisper + the GPT-4o-mini intent call now charge through a
 *     shared `LlmCostTracker` so org-wide kill-switch + per-user budget
 *     + ai_sessions.llm_cost_usd reflect voice spend
 *   - intent system prompt moved to PromptRegistry (versioned), with
 *     explicit role-locking against prompt-injection via voice-to-text
 */
@Injectable()
export class VoiceService {
  private readonly logger = new Logger(VoiceService.name);
  private readonly client: OpenAI | null;

  constructor(private readonly prompts: PromptRegistry) {
    this.client = process.env.OPENAI_API_KEY
      ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout: 30_000, maxRetries: 1 })
      : null;
  }

  async transcribe(
    buf: Buffer,
    filename = 'audio.m4a',
    tracker?: LlmCostTracker,
  ): Promise<string> {
    const client = this.client;
    if (!client) throw new BadRequestException('Tính năng giọng nói chưa được bật');
    const file = await toFile(buf, filename);
    const r = await client.audio.transcriptions.create({
      file,
      model: 'whisper-1',
      language: 'vi',
    });
    // Whisper bills by audio minute; we estimate duration from byte size
    // (~52kbps speech codec). Caller can override exactSeconds if known.
    chargeWhisperUsage(tracker, buf.length);
    return (r.text ?? '').trim();
  }

  /** Map a free-text utterance → { mood?, query? }. */
  async intent(text: string, tracker?: LlmCostTracker): Promise<{ mood?: string; query?: string }> {
    if (!text) return {};
    const client = this.client;
    if (!client) return { query: text };
    try {
      const prompt = this.prompts.get('voice.intent');
      const c = await client.chat.completions.create({
        model: 'gpt-4o-mini',
        response_format: { type: 'json_object' },
        temperature: 0.2,
        max_tokens: prompt.estimatedTokens.output,
        messages: [
          { role: 'system', content: prompt.system },
          { role: 'user', content: text },
        ],
      });
      chargeOpenaiUsage(tracker, c.usage, 'gpt-4o-mini');
      const p = JSON.parse(c.choices[0]?.message?.content ?? '{}');
      return { mood: MOODS.includes(p.mood) ? p.mood : undefined, query: typeof p.query === 'string' ? p.query.slice(0, 200) : text };
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
