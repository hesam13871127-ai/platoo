import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { ConnectedSocket, MessageBody, OnGatewayConnection, OnGatewayDisconnect, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatService } from './chat.service';
import { UsersService } from '../users/users.service';
import { SendMessageDto } from './chat.dto';

interface SocketAuth { token?: string; }

@WebSocketGateway({ namespace: '/chat', cors: { origin: true, credentials: true }, transports: ['websocket'] })
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server!: Server;
  private readonly logger = new Logger(ChatGateway.name);

  constructor(private readonly chat: ChatService, private readonly users: UsersService, private readonly jwt: JwtService, private readonly config: ConfigService) {}

  async handleConnection(socket: Socket): Promise<void> {
    try {
      const auth = socket.handshake.auth as SocketAuth;
      const header = socket.handshake.headers.authorization;
      const token = auth?.token ?? (header?.startsWith('Bearer ') ? header.slice(7) : undefined);
      if (!token) throw new Error('missing token');
      const payload = await this.jwt.verifyAsync<{ sub: string }>(token, { secret: this.config.getOrThrow<string>('jwt.accessSecret') });
      socket.data.userId = payload.sub;
      await socket.join(`user:${payload.sub}`);
      await this.users.touchPresence(payload.sub);
    } catch {
      this.logger.warn(`Rejected chat socket ${socket.id}`);
      socket.disconnect(true);
    }
  }

  async handleDisconnect(socket: Socket): Promise<void> {
    if (socket.data.userId) await this.users.touchPresence(socket.data.userId as string);
  }

  @SubscribeMessage('conversation:join')
  async join(@ConnectedSocket() socket: Socket, @MessageBody() body: { conversationId: string }) {
    await this.chat.assertMember(socket.data.userId as string, body.conversationId);
    await socket.join(`conversation:${body.conversationId}`);
    return { success: true, conversationId: body.conversationId };
  }

  @SubscribeMessage('message:send')
  async message(@ConnectedSocket() socket: Socket, @MessageBody() dto: SendMessageDto) {
    const message = await this.chat.send(socket.data.userId as string, dto);
    this.server.to(`conversation:${dto.conversationId}`).emit('message:new', message);
    return message;
  }

  @SubscribeMessage('conversation:read')
  async read(@ConnectedSocket() socket: Socket, @MessageBody() body: { conversationId: string; messageId: string }) {
    return this.chat.markRead(socket.data.userId as string, body.conversationId, body.messageId);
  }

  @SubscribeMessage('typing')
  async typing(@ConnectedSocket() socket: Socket, @MessageBody() body: { conversationId: string; isTyping: boolean }) {
    await this.chat.assertMember(socket.data.userId as string, body.conversationId);
    socket.to(`conversation:${body.conversationId}`).emit('typing', { userId: socket.data.userId, isTyping: body.isTyping });
    return { success: true };
  }
}
