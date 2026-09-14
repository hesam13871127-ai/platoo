import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { ChatService } from './chat.service';
import { CreatePrivateConversationDto, SendMessageDto } from './chat.dto';
import { RateLimit } from '../common/rate-limit/rate-limit.decorator';

const MINUTE = 60_000;

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('conversations') conversations(@CurrentUser() user: AuthenticatedUser) { return this.chat.conversations(user.id); }
  @RateLimit({ limit: 300, windowMs: MINUTE })
  @Get('conversations/:id/messages') history(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Query('before') before?: string, @Query('limit') limit?: string) { return this.chat.history(user.id, id, before, Number(limit ?? 50)); }
  @RateLimit({ limit: 20, windowMs: MINUTE })
  @Post('conversations/private') createPrivate(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreatePrivateConversationDto) { return this.chat.createPrivate(user.id, dto.userId); }
  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Post('messages') send(@CurrentUser() user: AuthenticatedUser, @Body() dto: SendMessageDto) { return this.chat.send(user.id, dto); }
  @RateLimit({ limit: 300, windowMs: MINUTE })
  @Post('conversations/:id/read/:messageId') markRead(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Param('messageId') messageId: string) { return this.chat.markRead(user.id, id, messageId); }
}
