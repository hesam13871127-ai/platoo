import { IsArray, IsBoolean, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';

export class UpdateUserAdminDto {
  @IsOptional()
  @IsIn(['active', 'suspended', 'deleted'])
  status?: 'active' | 'suspended' | 'deleted';
  @IsOptional()
  @IsIn(['player', 'moderator', 'admin'])
  role?: 'player' | 'moderator' | 'admin';
}

export class BanUserDto {
  @IsString() @MinLength(3) @MaxLength(500) reason!: string;
  /** Omit for a permanent ban, otherwise the ban lifts automatically after this many hours. */
  @IsOptional() @IsInt() @Min(1) @Max(24 * 365) durationHours?: number;
}

export class UnbanUserDto {
  @IsOptional() @IsString() @MaxLength(500) reason?: string;
}

export class AdjustWalletDto {
  @IsIn(['coins', 'pips']) currency!: 'coins' | 'pips';
  @IsInt() amount!: number;
  @IsString() @MinLength(3) @MaxLength(200) reason!: string;
}

export class CreateShopItemDto {
  @IsString() @MinLength(2) @MaxLength(80) sku!: string;
  @IsString() @MinLength(2) @MaxLength(100) name!: string;
  @IsString() @MaxLength(500) description!: string;
  @IsIn(['avatar', 'frame', 'emote', 'table', 'dice', 'bundle']) category!: string;
  @IsInt() @Min(0) priceCoins = 0;
  @IsInt() @Min(0) pricePips = 0;
  @IsString() @MaxLength(160) assetKey!: string;
  @IsOptional() @IsBoolean() isGiftable?: boolean;
  @IsOptional() @IsBoolean() isLimited?: boolean;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsInt() @Min(0) stock?: number;
}

export class UpdateShopItemDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(100) name?: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsOptional() @IsIn(['avatar', 'frame', 'emote', 'table', 'dice', 'bundle']) category?: string;
  @IsOptional() @IsInt() @Min(0) priceCoins?: number;
  @IsOptional() @IsInt() @Min(0) pricePips?: number;
  @IsOptional() @IsString() @MaxLength(160) assetKey?: string;
  @IsOptional() @IsBoolean() isGiftable?: boolean;
  @IsOptional() @IsBoolean() isLimited?: boolean;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsInt() @Min(0) stock?: number;
}

export class ToggleDto { @IsBoolean() isActive!: boolean; }

export class UpdateGameDto {
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsString() @MinLength(2) @MaxLength(80) displayName?: string;
  @IsOptional() @IsInt() @Min(1) @Max(16) minPlayers?: number;
  @IsOptional() @IsInt() @Min(1) @Max(16) maxPlayers?: number;
}

export class BulkToggleGamesDto {
  @IsArray() @IsString({ each: true }) gameIds!: string[];
  @IsBoolean() isActive!: boolean;
}

export class ResolveReportDto {
  @IsIn(['open', 'investigating', 'resolved', 'dismissed']) status!: 'open' | 'investigating' | 'resolved' | 'dismissed';
  @IsOptional() @IsString() @MaxLength(2000) resolutionNote?: string;
  /** Optional moderation action applied to the reported account in the same step. */
  @IsOptional() @IsIn(['none', 'suspend', 'ban', 'unban']) action?: 'none' | 'suspend' | 'ban' | 'unban';
  @IsOptional() @IsInt() @Min(1) @Max(24 * 365) banDurationHours?: number;
}

export class CreateReportNoteDto {
  @IsString() @MinLength(1) @MaxLength(2000) body!: string;
}

export class CreateSeasonDto {
  @IsString() @MinLength(2) @MaxLength(80) name!: string;
  @IsString() startsAt!: string;
  @IsString() endsAt!: string;
}

export class UpdateSeasonDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(80) name?: string;
  @IsOptional() @IsString() startsAt?: string;
  @IsOptional() @IsString() endsAt?: string;
}

export class CreateSeasonRewardDto {
  @IsInt() @Min(1) minRank!: number;
  @IsInt() @Min(1) maxRank!: number;
  @IsInt() @Min(0) coins = 0;
  @IsInt() @Min(0) pips = 0;
  @IsOptional() @IsUUID() shopItemId?: string;
}
