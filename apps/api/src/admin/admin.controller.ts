import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { AdminService } from './admin.service';
import {
  AdjustWalletDto,
  BanUserDto,
  BulkToggleGamesDto,
  CreateReportNoteDto,
  CreateSeasonDto,
  CreateSeasonRewardDto,
  CreateShopItemDto,
  ResolveReportDto,
  ToggleDto,
  UnbanUserDto,
  UpdateGameDto,
  UpdateSeasonDto,
  UpdateShopItemDto,
  UpdateUserAdminDto,
} from './admin.dto';

/**
 * Every route is admin-only by default. Moderators are opted in explicitly on the
 * read-only and moderation endpoints they are allowed to use.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  // Session bootstrap so the client can render the right tabs for the signed-in staff member.
  @Get('me') @Roles('moderator', 'admin') me(@CurrentUser() user: AuthenticatedUser) {
    return { id: user.id, role: user.role, permissions: user.role === 'admin' ? ['users', 'shop', 'games', 'reports', 'seasons', 'analytics', 'audit'] : ['users:read', 'reports', 'analytics'] };
  }

  // ------------------------------------------------------------- analytics
  @Get('overview') @Roles('moderator', 'admin') overview() { return this.admin.overview(); }
  @Get('analytics') @Roles('moderator', 'admin') analytics(@Query('days') days?: string) { return this.admin.analytics(Number(days ?? 14)); }

  // ----------------------------------------------------------------- users
  @Get('users') @Roles('moderator', 'admin') users(@Query('q') query?: string, @Query('status') status?: string, @Query('role') role?: string, @Query('page') page?: string) {
    return this.admin.users(query, status, role, Number(page ?? 0));
  }
  @Get('users/:id') @Roles('moderator', 'admin') user(@Param('id') id: string) { return this.admin.user(id); }
  @Patch('users/:id') updateUser(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateUserAdminDto) { return this.admin.updateUser(user, id, dto); }
  @Post('users/:id/ban') @Roles('moderator', 'admin') ban(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: BanUserDto) { return this.admin.banUser(user.id, id, dto); }
  @Post('users/:id/unban') @Roles('moderator', 'admin') unban(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UnbanUserDto) { return this.admin.unbanUser(user.id, id, dto); }
  @Post('users/:id/wallet') adjustWallet(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: AdjustWalletDto) { return this.admin.adjustWallet(user.id, id, dto); }

  // ------------------------------------------------------------------ shop
  @Get('shop') @Roles('moderator', 'admin') shop(@Query('q') query?: string, @Query('category') category?: string) { return this.admin.shop(query, category); }
  @Post('shop') createShop(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateShopItemDto) { return this.admin.createShop(user.id, dto); }
  @Patch('shop/:id') updateShop(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateShopItemDto) { return this.admin.updateShop(user.id, id, dto); }
  @Patch('shop/:id/active') toggleShop(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: ToggleDto) { return this.admin.toggleShop(user.id, id, dto); }
  @Delete('shop/:id') deleteShop(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.admin.deleteShop(user.id, id); }

  // ----------------------------------------------------------------- games
  @Get('games') @Roles('moderator', 'admin') games() { return this.admin.games(); }
  @Patch('games/bulk') bulkGames(@CurrentUser() user: AuthenticatedUser, @Body() dto: BulkToggleGamesDto) { return this.admin.bulkToggleGames(user.id, dto); }
  @Patch('games/:id') updateGame(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateGameDto) { return this.admin.updateGame(user.id, id, dto); }

  // --------------------------------------------------------------- reports
  @Get('reports') @Roles('moderator', 'admin') reports(@Query('status') status?: string, @Query('category') category?: string, @Query('page') page?: string) {
    return this.admin.reports(status, category, Number(page ?? 0));
  }
  @Get('reports/:id/notes') @Roles('moderator', 'admin') reportNotes(@Param('id') id: string) { return this.admin.reportNotes(id); }
  @Post('reports/:id/notes') @Roles('moderator', 'admin') addReportNote(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: CreateReportNoteDto) { return this.admin.addReportNote(user.id, id, dto); }
  @Patch('reports/:id') @Roles('moderator', 'admin') resolveReport(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: ResolveReportDto) { return this.admin.resolveReport(user.id, id, dto); }

  // ---------------------------------------------------------------- seasons
  @Get('seasons') @Roles('moderator', 'admin') seasons() { return this.admin.seasons(); }
  @Post('seasons') createSeason(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateSeasonDto) { return this.admin.createSeason(user.id, dto); }
  @Patch('seasons/:id') updateSeason(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateSeasonDto) { return this.admin.updateSeason(user.id, id, dto); }
  @Post('seasons/:id/activate') activate(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.admin.activateSeason(user.id, id); }
  @Post('seasons/:id/finish') finish(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.admin.finishSeason(user.id, id); }
  @Get('seasons/:id/rewards') @Roles('moderator', 'admin') rewards(@Param('id') id: string) { return this.admin.rewards(id); }
  @Post('seasons/:id/rewards') createReward(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: CreateSeasonRewardDto) { return this.admin.createReward(user.id, id, dto); }
  @Delete('seasons/rewards/:rewardId') deleteReward(@CurrentUser() user: AuthenticatedUser, @Param('rewardId') rewardId: string) { return this.admin.deleteReward(user.id, rewardId); }

  // -------------------------------------------------------------- audit log
  @Get('audit') auditLog(@Query('page') page?: string, @Query('action') action?: string) { return this.admin.auditLog(Number(page ?? 0), action); }
}
