import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { AdminService } from './admin.service';
import { CreateSeasonDto, CreateSeasonRewardDto, CreateShopItemDto, ResolveReportDto, ToggleDto, UpdateUserAdminDto } from './admin.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('moderator', 'admin')
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}
  @Get('overview') overview() { return this.admin.overview(); }
  @Get('users') users(@Query('q') query?: string, @Query('status') status?: string, @Query('page') page?: string) { return this.admin.users(query, status, Number(page ?? 0)); }
  @Patch('users/:id') @Roles('admin') updateUser(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: UpdateUserAdminDto) { return this.admin.updateUser(user.id, id, dto); }
  @Get('shop') shop() { return this.admin.shop(); }
  @Post('shop') @Roles('admin') createShop(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateShopItemDto) { return this.admin.createShop(user.id, dto); }
  @Patch('shop/:id') @Roles('admin') toggleShop(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: ToggleDto) { return this.admin.toggleShop(user.id, id, dto); }
  @Get('games') games() { return this.admin.games(); }
  @Patch('games/:id') @Roles('admin') toggleGame(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: ToggleDto) { return this.admin.toggleGame(user.id, id, dto); }
  @Get('reports') reports(@Query('status') status?: string) { return this.admin.reports(status); }
  @Patch('reports/:id') resolveReport(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: ResolveReportDto) { return this.admin.resolveReport(user.id, id, dto); }
  @Get('seasons') seasons() { return this.admin.seasons(); }
  @Post('seasons') @Roles('admin') createSeason(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateSeasonDto) { return this.admin.createSeason(user.id, dto); }
  @Post('seasons/:id/activate') @Roles('admin') activate(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.admin.activateSeason(user.id, id); }
  @Get('seasons/:id/rewards') rewards(@Param('id') id: string) { return this.admin.rewards(id); }
  @Post('seasons/:id/rewards') @Roles('admin') createReward(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: CreateSeasonRewardDto) { return this.admin.createReward(user.id, id, dto); }
  @Post('seasons/:id/finish') @Roles('admin') finish(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.admin.finishSeason(user.id, id); }
}
