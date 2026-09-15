import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { AddGroupMemberDto, CreateGroupDto, FriendshipDto, ReportUserDto, UpdateProfileDto } from './users.dto';
import { RateLimit } from '../common/rate-limit/rate-limit.decorator';

const MINUTE = 60_000;

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('me') me(@CurrentUser() user: AuthenticatedUser) { return this.users.profile(user.id); }
  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Patch('me') update(@CurrentUser() user: AuthenticatedUser, @Body() dto: UpdateProfileDto) { return this.users.updateProfile(user.id, dto); }
  @RateLimit({ limit: 180, windowMs: MINUTE })
  @Get('search') search(@CurrentUser() user: AuthenticatedUser, @Query('q') query = '') { return this.users.search(user.id, query); }
  @RateLimit({ limit: 10, windowMs: MINUTE })
  @Post(':id/report') report(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: Omit<ReportUserDto, 'reportedUserId'>) { return this.users.report(user.id, { ...dto, reportedUserId: id }); }

  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('friends') friends(@CurrentUser() user: AuthenticatedUser) { return this.users.friends(user.id); }
  @RateLimit({ limit: 30, windowMs: MINUTE })
  @Post('friends/:id') requestFriend(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.users.requestFriend(user.id, id); }
  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Patch('friends/:id') handleFriend(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: FriendshipDto) { return this.users.handleFriend(user.id, id, dto); }

  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('groups') groups(@CurrentUser() user: AuthenticatedUser) { return this.users.groups(user.id); }
  @RateLimit({ limit: 20, windowMs: MINUTE })
  @Post('groups') createGroup(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateGroupDto) { return this.users.createGroup(user.id, dto); }
  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('groups/:id') group(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.users.group(user.id, id); }
  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Post('groups/:id/members') addMember(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: AddGroupMemberDto) { return this.users.addGroupMember(user.id, id, dto.userId); }
  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Delete('groups/:id/members/:userId') removeMember(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Param('userId') memberId: string) { return this.users.removeGroupMember(user.id, id, memberId); }
}
