import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { JoinQueueDto } from './matchmaking.dto';
import { MatchmakingService } from './matchmaking.service';

@UseGuards(JwtAuthGuard)
@Controller('matchmaking')
export class MatchmakingController {
  constructor(private readonly matchmaking: MatchmakingService) {}
  @Post('join') join(@CurrentUser() user: AuthenticatedUser, @Body() dto: JoinQueueDto) { return this.matchmaking.join(user.id, dto); }
  @Delete('leave') leave(@CurrentUser() user: AuthenticatedUser, @Query('ticketId') ticketId?: string) { return this.matchmaking.leave(user.id, ticketId); }
  @Get(':id') status(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.matchmaking.status(user.id, id); }
}
