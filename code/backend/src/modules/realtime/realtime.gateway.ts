import { Logger, UseGuards } from '@nestjs/common';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';

@WebSocketGateway({
  cors: { origin: '*' },
  transports: ['websocket'],
  pingInterval: 25_000,
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(private readonly jwt: JwtService) {}

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
  joinGroup(@ConnectedSocket() client: Socket, @MessageBody() body: { groupId: string }) {
    client.join(`group:${body.groupId}`);
    return { ok: true };
  }

  @SubscribeMessage('subscribe:restaurant')
  joinRestaurant(@ConnectedSocket() client: Socket, @MessageBody() body: { restaurantId: string }) {
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
