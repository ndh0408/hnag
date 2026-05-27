import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient, Prisma } from '@prisma/client';

/**
 * Prisma client + observability hooks.
 *
 * Closes audit prompt-pack §8 / production-killer §6 "DB performance metrics":
 *   - `$on('query', …)` captures every executed SQL with its duration.
 *   - Anything above SLOW_QUERY_MS_THRESHOLD (default 200ms) is logged at
 *     warn level with the params truncated — feeds Loki/Grafana for
 *     "what's slow this hour" dashboards.
 *   - Anything above SLOW_QUERY_BLOCK_MS (default 2000ms) gets an `error`
 *     log so on-call gets paged.
 *
 * The middleware is opt-in: set PRISMA_QUERY_LOG=true to enable. Off by
 * default in production to keep Loki ingestion cost down — flip on when
 * investigating a latency incident.
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);
  private readonly slowMs = Number(process.env.SLOW_QUERY_MS_THRESHOLD ?? '200');
  private readonly criticalMs = Number(process.env.SLOW_QUERY_BLOCK_MS ?? '2000');
  private readonly fullQueryLog = process.env.PRISMA_QUERY_LOG === 'true';

  constructor() {
    super({
      log: [
        { emit: 'event', level: 'query' },
        { emit: 'event', level: 'warn'  },
        { emit: 'event', level: 'error' },
      ],
    });
  }

  async onModuleInit(): Promise<void> {
    // Wire query-level observability. Prisma emits one event per executed
    // statement; we filter by duration so the log is only loud for slow ones.
    (this as any).$on('query', (e: Prisma.QueryEvent) => {
      const dur = e.duration;
      if (dur >= this.criticalMs) {
        // Pager-worthy slow query — surfaces in Sentry/Loki at error level
        // so alert rules can match on it.
        this.logger.error(
          `slow-query CRITICAL ${dur}ms ${truncate(e.query, 200)} params=${truncate(e.params, 120)}`,
        );
      } else if (dur >= this.slowMs) {
        this.logger.warn(
          `slow-query ${dur}ms ${truncate(e.query, 200)} params=${truncate(e.params, 120)}`,
        );
      } else if (this.fullQueryLog) {
        this.logger.debug(`query ${dur}ms ${truncate(e.query, 200)}`);
      }
    });
    (this as any).$on('warn', (e: any) => this.logger.warn(`prisma warn: ${e.message}`));
    (this as any).$on('error', (e: any) => this.logger.error(`prisma error: ${e.message}`));

    await this.$connect();
    this.logger.log(
      `Prisma connected · slow-threshold=${this.slowMs}ms critical=${this.criticalMs}ms full-log=${this.fullQueryLog}`,
    );
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}

function truncate(s: string | undefined, max: number): string {
  if (!s) return '';
  return s.length > max ? `${s.slice(0, max)}…` : s;
}
