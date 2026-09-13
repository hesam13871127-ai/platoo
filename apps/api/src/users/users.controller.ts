import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { UsersService } from './users.service';
import { AddGroupMemberDto, CreateGroupDto, FriendshipDto, ReportUserDto, UpdateProfileDto } from './users.dto';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me') me(@CurrentUser() user: AuthenticatedUser) { return this.users.profile(user.id); }
  @Patch('me') update(@CurrentUser() user: AuthenticatedUser, @Body() dto: UpdateProfileDto) { return this.users.updateProfile(user.id, dto); }
  @Get('search') search(@CurrentUser() user: AuthenticatedUser, @Query('q') query = '') { return this.users.search(user.id, query); }
  @Post(':id/report') report(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: Omit<ReportUserDto, 'reportedUserId'>) { return this.users.report(user.id, { ...dto, reportedUserId: id }); }

  @Get('friends') friends(@CurrentUser() user: AuthenticatedUser) { return this.users.friends(user.id); }
  @Post('friends/:id') requestFriend(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.users.requestFriend(user.id, id); }
  @Patch('friends/:id') handleFriend(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: FriendshipDto) { return this.users.handleFriend(user.id, id, dto); }

  @Get('groups') groups(@CurrentUser() user: AuthenticatedUser) { return this.users.groups(user.id); }
  @Post('groups') createGroup(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateGroupDto) { return this.users.createGroup(user.id, dto); }
  @Get('groups/:id') group(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string) { return this.users.group(user.id, id); }
  @Post('groups/:id/members') addMember(@CurrentUser() user: AuthenticatedUser, @Param('id') id: string, @Body() dto: AddGroupMemberDto) { return this.users.addGroupMember(user.id, id, dto.userId); }
}
