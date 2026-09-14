import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { VoiceService } from './voice.service';
import { VoiceTokenDto } from './voice.dto';
import { RateLimit } from '../common/rate-limit/rate-limit.decorator';

const MINUTE = 60_000;

@UseGuards(JwtAuthGuard)
@Controller('voice')
export class VoiceController {
  constructor(private readonly voice: VoiceService) {}
  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Post('token') token(@CurrentUser() user: AuthenticatedUser, @Body() dto: VoiceTokenDto) { return this.voice.token(user.id, dto.matchId, dto.conversationId); }
}
