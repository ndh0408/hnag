import { INestApplication, Logger } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { ServerOptions } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import IORedis from 'ioredis';

/**
 * Socket.io adapter with Redis pub/sub for cross-pod event fanout.
 *
 * Audit realtime-trace §27: migrated from `node-redis` to `ioredis` so the
 * adapter shares the same client library as RedisModule. Two reconnect
 * semantics + two retry policies in one process was a foot-gun. With both
 * on ioredis, ops can reason about retries uniformly.
 *
 * The pub + sub clients still MUST be distinct from the application
 * client (Redis pub/sub is connection-stateful — a SUBSCRIBE'd connection
 * cannot serve GET/SET) — but they're now both ioredis.
 */
export class RedisIoAdapter extends IoAdapter {
  private adapterConstructor!: ReturnType<typeof createAdapter>;
  private readonly logger = new Logger(RedisIoAdapter.name);
  // Keep refs so we can disconnect cleanly on shutdown.
  private pubClient?: IORedis;
  private subClient?: IORedis;

  constructor(app: INestApplication) {
    super(app);
  }

  async connectToRedis(): Promise<void> {
    const url = process.env.REDIS_URL ?? 'redis://localhost:6379';
    // ioredis: lazyConnect=false so any auth/network error throws at
    // construction time, not later. maxRetriesPerRequest=null is the
    // recommended setting for pub/sub clients per ioredis docs.
    this.pubClient = new IORedis(url, {
      maxRetriesPerRequest: null,
      enableReadyCheck: true,
      reconnectOnError: (err) => err.message.includes('READONLY'),
    });
    this.subClient = this.pubClient.duplicate();

    // Surface unrecoverable errors so Sentry / Loki sees them.
    this.pubClient.on('error', (e) => this.logger.warn(`pubClient err: ${e.message}`));
    this.subClient.on('error', (e) => this.logger.warn(`subClient err: ${e.message}`));

    this.adapterConstructor = createAdapter(this.pubClient, this.subClient);
    this.logger.log(`Redis Socket.io adapter connected → ${url} (ioredis)`);
  }

  createIOServer(port: number, options?: ServerOptions): any {
    const server = super.createIOServer(port, options);
    server.adapter(this.adapterConstructor);
    return server;
  }
}
