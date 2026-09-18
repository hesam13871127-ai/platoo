import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { AdminService } from './admin.service';
import { AdjustWalletDto, BanUserDto, CreateSeasonDto, CreateSeasonRewardDto, CreateShopItemDto, ResolveReportDto, UpdateGameDto, UpdateSeasonDto, UpdateShopItemDto, UpdateUserAdminDto } from './admin.dto';
import { RateLimit } from '../common/rate-limit/rate-limit.decorator';
import { forbidden } from '../common/errors';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('moderator', 'admin')
@RateLimit({ limit: 300, windowMs: 60_000 })
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  // Dashboard
  @Get('overview') overview() { return this.admin.overview(); }
  @Get('analytics') analytics(@Query('days') days?: string) { return this.admin.analytics(Number(days ?? 30)); }
  @Get('matches/recent') recentMatches(@Query('limit') limit?: string) { return this.admin.recentMatches(Number(limit ?? 20)); }
  @Get('audit-log')
  auditLog(@Query('page') page?: string, @Query('limit') limit?: string, @Query('action') action?: string, @Query('adminId') adminId?: string) {
    return this.admin.auditLog(Number(page ?? 0), Number(limit ?? 20), action, adminId);
  }

  // Users
  @Get('users')
  users(@Query('q') query?: string, @Query('status') status?: string, @Query('role') role?: string, @Query('page') page?: string, @Query('limit') limit?: string) {
    return this.admin.users(query, status, role, Number(page ?? 0), Number(limit ?? 20));
  }
  @Get('users/:id') userDetail(@Param('id') id: string) { return this.admin.userDetail(id); }
  @Patch('users/:id') @Roles('admin') updateUser(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateUserAdminDto) { return this.admin.updateUser(user.id, id, dto); }
  @Post('users/:id/ban') @Roles('admin') banUser(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: BanUserDto) { return this.admin.banUser(user.id, id, dto); }
  @Post('users/:id/unban') @Roles('admin') unbanUser(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.admin.unbanUser(user.id, id); }
  @Post('users/:id/wallet') @Roles('admin') adjustWallet(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: AdjustWalletDto) { return this.admin.adjustWallet(user.id, id, dto); }

  // Shop
  @Get('shop') shop() { return this.admin.shop(); }
  @Post('shop') @Roles('admin') createShop(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateShopItemDto) { return this.admin.createShop(user.id, dto); }
  @Patch('shop/:id') @Roles('admin') updateShop(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateShopItemDto) { return this.admin.updateShop(user.id, id, dto); }
  @Delete('shop/:id') @Roles('admin') deleteShop(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Query('hard') hard?: string) { return this.admin.deleteShop(user.id, id, hard === 'true'); }

  // Games
  @Get('games') games() { return this.admin.games(); }
  @Patch('games/:id') @Roles('moderator', 'admin') updateGame(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateGameDto) {
    if (user.role === 'moderator' && Object.keys(dto).some((key) => key !== 'isActive')) throw forbidden('Moderators may only change game availability.');
    return this.admin.updateGame(user.id, id, dto);
  }

  // Reports & moderation
  @Get('reports')
  reports(@Query('status') status?: string, @Query('category') category?: string, @Query('reportedUserId') reportedUserId?: string, @Query('page') page?: string, @Query('limit') limit?: string) {
    return this.admin.reports(status, category, reportedUserId, Number(page ?? 0), Number(limit ?? 20));
  }
  @Get('reports/:id') reportDetail(@Param('id') id: string) { return this.admin.reportDetail(id); }
  @Patch('reports/:id') resolveReport(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: ResolveReportDto) { return this.admin.resolveReport(user.id, user.role, id, dto); }

  // Seasons
  @Get('seasons') seasons() { return this.admin.seasons(); }
  @Post('seasons') @Roles('admin') createSeason(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateSeasonDto) { return this.admin.createSeason(user.id, dto); }
  @Get('seasons/:id') seasonDetail(@Param('id') id: string) { return this.admin.seasonDetail(id); }
  @Patch('seasons/:id') @Roles('admin') updateSeason(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateSeasonDto) { return this.admin.updateSeason(user.id, id, dto); }
  @Delete('seasons/:id') @Roles('admin') deleteSeason(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.admin.deleteSeason(user.id, id); }
  @Post('seasons/:id/activate') @Roles('admin') activate(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.admin.activateSeason(user.id, id); }
  @Get('seasons/:id/rewards') rewards(@Param('id') id: string) { return this.admin.rewards(id); }
  @Post('seasons/:id/rewards') @Roles('admin') createReward(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: CreateSeasonRewardDto) { return this.admin.createReward(user.id, id, dto); }
  @Delete('seasons/:id/rewards/:rewardId') @Roles('admin') deleteReward(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Param('rewardId') rewardId: string) { return this.admin.deleteReward(user.id, id, rewardId); }
  @Post('seasons/:id/finish') @Roles('admin') finish(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.admin.finishSeason(user.id, id); }
}
