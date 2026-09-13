import { IsIn, IsOptional, IsString, IsUUID, Length, Matches, MaxLength, MinLength } from 'class-validator';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  displayName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatarUrl?: string;
}

export class FriendshipDto {
  @IsIn(['accept', 'reject', 'block'])
  action!: 'accept' | 'reject' | 'block';
}

export class CreateGroupDto {
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(280)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  avatarUrl?: string;

  @IsOptional()
  isPrivate?: boolean;
}

export class AddGroupMemberDto {
  @IsUUID()
  userId!: string;
}

export class ReportUserDto {
  @IsUUID()
  reportedUserId!: string;

  @IsIn(['abuse', 'cheating', 'spam', 'safety', 'other'])
  category!: 'abuse' | 'cheating' | 'spam' | 'safety' | 'other';

  @IsString()
  @MinLength(5)
  @MaxLength(2000)
  description!: string;
}
