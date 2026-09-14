import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { CreateMatchDto, GameActionDto } from './game.dto';
import { GameService } from './game.service';
import { RateLimit } from '../common/rate-limit/rate-limit.decorator';

const MINUTE = 60_000;

@UseGuards(JwtAuthGuard)
@Controller()
export class GameController {
  constructor(private readonly games: GameService) {}
  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('games') list() { return this.games.listGames(); }
  @RateLimit({ limit: 20, windowMs: MINUTE })
  @Post('matches') create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateMatchDto) { return this.games.createMatch(dto.gameId, dto.mode, [user.id, ...(dto.playerIds ?? []).filter((id) => id !== user.id)], dto.desiredPlayers); }
  @RateLimit({ limit: 300, windowMs: MINUTE })
  @Get('matches/:id') match(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.games.getMatch(id, user.id); }
  @RateLimit({ limit: 180, windowMs: MINUTE })
  @Post('matches/:id/actions') action(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: GameActionDto) { return this.games.act(id, user.id, dto); }
  @RateLimit({ limit: 30, windowMs: MINUTE })
  @Post('matches/:id/resign') resign(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.games.resign(id, user.id); }
  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Get('matches/:id/replay') replay(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.games.replay(id, user.id); }
}
