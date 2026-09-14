import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer, WsException } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { GameService } from './game.service';
import { GameActionDto } from './game.dto';
import { SocketFloodGuard } from '../common/rate-limit/socket-flood';
import { socketCorsOrigin } from '../common/cors.util';

const MINUTE = 60_000;

@WebSocketGateway({ namespace: '/games', cors: { origin: socketCorsOrigin(), credentials: true }, transports: ['websocket'] })
export class GameGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(GameGateway.name);
  private readonly flood = new SocketFloodGuard();
  constructor(private readonly games: GameService, private readonly jwt: JwtService, private readonly config: ConfigService) {
    this.games.onMatchUpdated((matchId) => { void this.broadcast(matchId); });
  }

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
  handleDisconnect(socket: Socket): void { this.flood.release(socket.id); }

  @SubscribeMessage('match:join')
  async join(@ConnectedSocket() socket: Socket, @MessageBody() body: { matchId: string }) {
    if (!this.flood.check(socket.id, 'match:join', 60, MINUTE)) throw new WsException('Too many requests. Slow down for a moment.');
    const match = await this.games.getMatch(body.matchId, socket.data.userId as string);
    await socket.join(`match:${body.matchId}`);
    return match;
  }

  @SubscribeMessage('game:action')
  async action(@ConnectedSocket() socket: Socket, @MessageBody() body: { matchId: string; action: GameActionDto }) {
    if (!this.flood.check(socket.id, 'game:action', 180, MINUTE)) throw new WsException('Too many requests. Slow down for a moment.');
    return this.games.act(body.matchId, socket.data.userId as string, body.action);
  }

  @SubscribeMessage('game:resign')
  async resign(@ConnectedSocket() socket: Socket, @MessageBody() body: { matchId: string }) {
    if (!this.flood.check(socket.id, 'game:resign', 30, MINUTE)) throw new WsException('Too many requests. Slow down for a moment.');
    return this.games.resign(body.matchId, socket.data.userId as string);
  }

  private async broadcast(matchId: string): Promise<void> {
    const sockets = await this.server.in(`match:${matchId}`).fetchSockets();
    await Promise.all(sockets.map(async (socket) => {
      try { socket.emit('match:update', await this.games.getMatch(matchId, socket.data.userId as string)); } catch { socket.emit('match:error', { message: 'The match is no longer available.' }); }
    }));
  }
}
