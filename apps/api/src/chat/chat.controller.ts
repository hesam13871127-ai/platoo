import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { ChatService } from './chat.service';
import { CreatePrivateConversationDto, SendMessageDto } from './chat.dto';

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Get('conversations') conversations(@CurrentUser() user: AuthenticatedUser) { return this.chat.conversations(user.id); }
  @Get('conversations/:id/messages') history(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Query('before') before?: string, @Query('limit') limit?: string) { return this.chat.history(user.id, id, before, Number(limit ?? 50)); }
  @Post('conversations/private') createPrivate(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreatePrivateConversationDto) { return this.chat.createPrivate(user.id, dto.userId); }
  @Post('messages') send(@CurrentUser() user: AuthenticatedUser, @Body() dto: SendMessageDto) { return this.chat.send(user.id, dto); }
  @Post('conversations/:id/read/:messageId') markRead(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Param('messageId') messageId: string) { return this.chat.markRead(user.id, id, messageId); }
}
