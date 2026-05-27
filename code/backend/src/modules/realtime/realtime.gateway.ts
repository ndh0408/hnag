import { Logger } from '@nestjs/common';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../common/prisma/prisma.service';

const wsCorsOrigins = (process.env.CORS_ORIGINS ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

@WebSocketGateway({
  // Explicit allowlist, not '*'.
  cors: { origin: wsCorsOrigins.length ? wsCorsOrigins : false, credentials: true },
  transports: ['websocket'],
  pingInterval: 25_000,
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token = (client.handshake.auth?.token ?? client.handshake.query?.token) as string;
      if (!token) throw new Error('No token');
      const payload = await this.jwt.verifyAsync(token);
      client.data.userId = payload.sub;
      client.join(`user:${payload.sub}`);
      this.logger.debug(`WS connect user=${payload.sub}`);
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
    // Only members may join a group room (was: anyone could subscribe and read
    // every group's live votes/events).
    const member = await this.prisma.group_members.findUnique({
      where: { group_id_user_id: { group_id: body.groupId, user_id: userId } },
    });
    if (!member) return { ok: false, error: 'not_a_member' };
    client.join(`group:${body.groupId}`);
    return { ok: true };
  }

  @SubscribeMessage('subscribe:restaurant')
  async joinRestaurant(@ConnectedSocket() client: Socket, @MessageBody() body: { restaurantId: string }) {
    // Restaurant live data (crowding/wait) is public, but require an authed
    // socket. Audit hnag-audit-2026-05 #9: the previous version accepted any
    // string as a room name, polluting the namespace and giving attackers a
    // cheap way to spray room joins (memory pressure + potential future
    // logic that grants permissions based on room membership).
    if (!client.data.userId || !isUuid(body?.restaurantId)) {
      return { ok: false, error: 'bad_request' };
    }
    const r = await this.prisma.restaurants.findUnique({
      where: { id: body.restaurantId },
      select: { id: true },
    });
    if (!r) return { ok: false, error: 'not_found' };
    client.join(`restaurant:${body.restaurantId}`);
    return { ok: true };
  }

  @SubscribeMessage('vote:cast')
  // Vote is handled via REST + this is for typing/presence acknowledgement only
  voteCast(@ConnectedSocket() client: Socket, @MessageBody() body: any) {
    return { ack: true };
  }

  // --- Helpers used by services to broadcast ---

  broadcastUser(userId: string, event: string, data: unknown) {
    this.server.to(`user:${userId}`).emit(event, data);
  }
  broadcastGroup(groupId: string, event: string, data: unknown) {
    this.server.to(`group:${groupId}`).emit(event, data);
  }
  broadcastRestaurant(restaurantId: string, event: string, data: unknown) {
    this.server.to(`restaurant:${restaurantId}`).emit(event, data);
  }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function isUuid(s: unknown): s is string {
  return typeof s === 'string' && UUID_RE.test(s);
}
