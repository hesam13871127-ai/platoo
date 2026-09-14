import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { CreateMatchDto, GameActionDto } from './game.dto';
import { GameService } from './game.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class GameController {
  constructor(private readonly games: GameService) {}
  @Get('games') list() { return this.games.listGames(); }
  @Post('matches') create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateMatchDto) { return this.games.createMatch(dto.gameId, dto.mode, [user.id, ...(dto.playerIds ?? []).filter((id) => id !== user.id)], dto.desiredPlayers); }
  @Get('matches/:id') match(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.games.getMatch(id, user.id); }
  @Post('matches/:id/actions') action(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: GameActionDto) { return this.games.act(id, user.id, dto); }
  @Post('matches/:id/resign') resign(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.games.resign(id, user.id); }
  @Get('matches/:id/replay') replay(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.games.replay(id, user.id); }
}
