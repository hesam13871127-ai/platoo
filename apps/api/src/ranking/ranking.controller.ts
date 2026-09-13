import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { RankingService } from './ranking.service';

@UseGuards(JwtAuthGuard)
@Controller('ranking')
export class RankingController {
  constructor(private readonly ranking: RankingService) {}
  @Get('season') season() { return this.ranking.currentSeason(); }
  @Get(':gameId/leaderboard') leaderboard(@Param('gameId') gameId: string, @Query('limit') limit?: string, @Query('offset') offset?: string) { return this.ranking.leaderboard(gameId, Number(limit ?? 50), Number(offset ?? 0)); }
  @Get(':gameId/me') me(@CurrentUser() user: AuthenticatedUser, @Param('gameId') gameId: string) { return this.ranking.myRating(user.id, gameId); }
}
