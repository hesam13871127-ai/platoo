import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { GameService } from './game.service';
import { GameActionDto } from './game.dto';

@WebSocketGateway({ namespace: '/games', cors: { origin: true, credentials: true }, transports: ['websocket'] })
export class GameGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(GameGateway.name);
  constructor(private readonly games: GameService, private readonly jwt: JwtService, private readonly config: ConfigService) {}

  async handleConnection(socket: Socket): Promise<void> {
    try {
      const auth = socket.handshake.auth as { token?: string };
      const token = auth?.token ?? (socket.handshake.headers.authorization?.startsWith('Bearer ') ? socket.handshake.headers.authorization.slice(7) : undefined);
      if (!token) throw new Error('missing token');
      const payload = await this.jwt.verifyAsync<{ sub: string }>(token, { secret: this.config.getOrThrow<string>('jwt.accessSecret') });
      socket.data.userId = payload.sub;
      await socket.join(`user:${payload.sub}`);
    } catch { this.logger.warn(`Rejected game socket ${socket.id}`); socket.disconnect(true); }
  }
  handleDisconnect(_socket: Socket): void { return; }

  @SubscribeMessage('match:join')
  async join(@ConnectedSocket() socket: Socket, @MessageBody() body: { matchId: string }) {
    const match = await this.games.getMatch(body.matchId, socket.data.userId as string);
    await socket.join(`match:${body.matchId}`);
    return match;
  }

  @SubscribeMessage('game:action')
  async action(@ConnectedSocket() socket: Socket, @MessageBody() body: { matchId: string; action: GameActionDto }) {
    const match = await this.games.act(body.matchId, socket.data.userId as string, body.action);
    void this.broadcast(body.matchId);
    return match;
  }

  private async broadcast(matchId: string): Promise<void> {
    const sockets = await this.server.in(`match:${matchId}`).fetchSockets();
    await Promise.all(sockets.map(async (socket) => {
      try { socket.emit('match:update', await this.games.getMatch(matchId, socket.data.userId as string)); } catch { socket.emit('match:error', { message: 'The match is no longer available.' }); }
    }));
  }
}
