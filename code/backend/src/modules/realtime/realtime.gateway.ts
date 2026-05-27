import { Inject, Logger } from '@nestjs/common';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import IORedis from 'ioredis';
import { PrismaService } from '../../common/prisma/prisma.service';
import { REDIS } from '../../common/redis/redis.module';

const wsCorsOrigins = (process.env.CORS_ORIGINS ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

@WebSocketGateway({
  cors: { origin: wsCorsOrigins.length ? wsCorsOrigins : false, credentials: true },
  transports: ['websocket'],
  pingInterval: 25_000,
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(RealtimeGateway.name);

  /** Audit #14, #37: cache existence lookups to avoid DB hammer on reconnect storms. */
  private static readonly MEMBERSHIP_TTL_SEC = 60;
  private static readonly RESTAURANT_TTL_SEC = 3600;
  /** Audit #3: per-socket subscribe-message rate-limit prevents room-join spray DoS. */
  private static readonly SUBSCRIBE_BUCKET_WINDOW_SEC = 60;
  private static readonly SUBSCRIBE_BUCKET_MAX = 30;
  /** Audit #13: per-handshake user-status cache TTL — short so deletions take effect fast. */
  private static readonly USER_STATUS_TTL_SEC = 60;

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: IORedis,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token = (client.handshake.auth?.token ?? client.handshake.query?.token) as string;
      if (!token) throw new Error('No token');
      const payload = await this.jwt.verifyAsync(token);
      const userId = payload.sub as string | undefined;
      if (!userId) throw new Error('Token missing sub');

      // Audit #13: verify the user still exists AND status === 'active'.
      // A deleted user holds a live JWT for up to 15 min; without this check
      // they could continue to receive WS broadcasts. We cache the
      // active-status decision for 60s to keep the check cheap.
      const active = await this.isUserActiveCached(userId);
      if (!active) throw new Error('User inactive or deleted');

      client.data.userId = userId;
      client.data.subscribeBucketAt = 0;
      client.data.subscribeBucketCount = 0;
      client.join(`user:${userId}`);
      this.logger.debug(`WS connect user=${userId}`);
    } catch (e) {
      this.logger.warn(`WS reject: ${(e as Error).message}`);
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.debug(`WS disconnect ${client.id}`);
  }

  @SubscribeMessage('subscribe:group')
  async joinGroup(@ConnectedSocket() client: Socket, @MessageBody() body: { groupId: string }) {
    const userId = client.data.userId as string | undefined;
    if (!userId || !isUuid(body?.groupId)) return { ok: false, error: 'bad_request' };

    if (!this.consumeSubscribeBudget(client)) {
      this.logger.warn(`WS subscribe rate-limit hit user=${userId}`);
      // Drop the misbehaving socket — keeps signal clean for legitimate clients.
      client.disconnect(true);
      return { ok: false, error: 'rate_limited' };
    }

    // Cache the membership check so reconnect storms don't hammer the DB.
    const isMember = await this.isGroupMemberCached(body.groupId, userId);
    if (!isMember) return { ok: false, error: 'not_a_member' };
    client.join(`group:${body.groupId}`);
    return { ok: true };
  }

  @SubscribeMessage('subscribe:restaurant')
  async joinRestaurant(@ConnectedSocket() client: Socket, @MessageBody() body: { restaurantId: string }) {
    if (!client.data.userId || !isUuid(body?.restaurantId)) {
      return { ok: false, error: 'bad_request' };
    }
    if (!this.consumeSubscribeBudget(client)) {
      this.logger.warn(`WS subscribe rate-limit hit user=${client.data.userId}`);
      client.disconnect(true);
      return { ok: false, error: 'rate_limited' };
    }
    const exists = await this.restaurantExistsCached(body.restaurantId);
    if (!exists) return { ok: false, error: 'not_found' };
    client.join(`restaurant:${body.restaurantId}`);
    return { ok: true };
  }

  @SubscribeMessage('vote:cast')
  voteCast(@ConnectedSocket() _client: Socket, @MessageBody() _body: any) {
    return { ack: true };
  }

  /** Pub-side helpers used by services to broadcast. */
  broadcastUser(userId: string, event: string, data: unknown) {
    this.server.to(`user:${userId}`).emit(event, data);
  }
  broadcastGroup(groupId: string, event: string, data: unknown) {
    this.server.to(`group:${groupId}`).emit(event, data);
  }
  broadcastRestaurant(restaurantId: string, event: string, data: unknown) {
    this.server.to(`restaurant:${restaurantId}`).emit(event, data);
  }

  // ── internals ─────────────────────────────────────────────────────────────

  /**
   * In-socket sliding window rate-limit on subscribe messages. Bucket reset
   * every 60s; > 30 subscribes in a window drops the socket. Bounds the
   * room-join spray DOS path (audit #3).
   */
  private consumeSubscribeBudget(client: Socket): boolean {
    const now = Date.now();
    const winAgo = (client.data.subscribeBucketAt ?? 0) as number;
    if (now - winAgo > RealtimeGateway.SUBSCRIBE_BUCKET_WINDOW_SEC * 1000) {
      client.data.subscribeBucketAt = now;
      client.data.subscribeBucketCount = 0;
    }
    const next = ((client.data.subscribeBucketCount ?? 0) as number) + 1;
    client.data.subscribeBucketCount = next;
    return next <= RealtimeGateway.SUBSCRIBE_BUCKET_MAX;
  }

  private async isUserActiveCached(userId: string): Promise<boolean> {
    const key = `ws:userstatus:${userId}`;
    try {
      const cached = await this.redis.get(key);
      if (cached === 'active') return true;
      if (cached === 'inactive') return false;
    } catch {/* fall through */}
    const u = await this.prisma.users.findUnique({ where: { id: userId }, select: { status: true } });
    const ok = !!u && u.status === 'active';
    try {
      await this.redis.setex(key, RealtimeGateway.USER_STATUS_TTL_SEC, ok ? 'active' : 'inactive');
    } catch {/* best-effort */}
    return ok;
  }

  private async isGroupMemberCached(groupId: string, userId: string): Promise<boolean> {
    const key = `ws:gmember:${groupId}:${userId}`;
    try {
      const cached = await this.redis.get(key);
      if (cached === '1') return true;
      if (cached === '0') return false;
    } catch {/* fall through */}
    const member = await this.prisma.group_members.findUnique({
      where: { group_id_user_id: { group_id: groupId, user_id: userId } },
    });
    const ok = !!member;
    try {
      await this.redis.setex(key, RealtimeGateway.MEMBERSHIP_TTL_SEC, ok ? '1' : '0');
    } catch {/* best-effort */}
    return ok;
  }

  private async restaurantExistsCached(restaurantId: string): Promise<boolean> {
    const key = `ws:restexists:${restaurantId}`;
    try {
      const cached = await this.redis.get(key);
      if (cached === '1') return true;
      if (cached === '0') return false;
    } catch {/* fall through */}
    const r = await this.prisma.restaurants.findUnique({
      where: { id: restaurantId },
      select: { id: true },
    });
    const ok = !!r;
    try {
      await this.redis.setex(key, RealtimeGateway.RESTAURANT_TTL_SEC, ok ? '1' : '0');
    } catch {/* best-effort */}
    return ok;
  }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function isUuid(s: unknown): s is string {
  return typeof s === 'string' && UUID_RE.test(s);
}
