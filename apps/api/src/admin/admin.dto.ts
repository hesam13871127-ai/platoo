import { IsBoolean, IsIn, IsInt, IsObject, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min, MinLength, ValidateIf } from 'class-validator';

export class UpdateUserAdminDto {
  @IsOptional()
  @IsIn(['active', 'suspended', 'deleted'])
  status?: 'active' | 'suspended' | 'deleted';
  @IsOptional()
  @IsIn(['player', 'moderator', 'admin'])
  role?: 'player' | 'moderator' | 'admin';
}

export class BanUserDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class AdjustWalletDto {
  @IsOptional()
  @IsInt()
  coins?: number;
  @IsOptional()
  @IsInt()
  pips?: number;
  @IsString()
  @MinLength(3)
  @MaxLength(280)
  reason!: string;
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
  @IsOptional() @IsInt() @Min(0) stock?: number;
}

export class UpdateShopItemDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(80) sku?: string;
  @IsOptional() @IsString() @MinLength(2) @MaxLength(100) name?: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsOptional() @IsIn(['avatar', 'frame', 'emote', 'table', 'dice', 'bundle']) category?: string;
  @IsOptional() @IsInt() @Min(0) priceCoins?: number;
  @IsOptional() @IsInt() @Min(0) pricePips?: number;
  @IsOptional() @IsString() @MaxLength(160) assetKey?: string;
  @IsOptional() @IsBoolean() isGiftable?: boolean;
  @IsOptional() @IsBoolean() isLimited?: boolean;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional()
  @ValidateIf((_object, value) => value !== null)
  @IsInt()
  @Min(0)
  stock?: number | null;
}

export class ToggleDto { @IsBoolean() isActive!: boolean; }

export class UpdateGameDto {
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsString() @MinLength(2) @MaxLength(80) displayName?: string;
  @IsOptional() @IsInt() @Min(1) @Max(12) minPlayers?: number;
  @IsOptional() @IsInt() @Min(1) @Max(12) maxPlayers?: number;
  @IsOptional() @IsBoolean() supportsTeams?: boolean;
  @IsOptional() @IsString() @Matches(/^#[0-9a-fA-F]{6}$/) accentColor?: string;
  @IsOptional() @IsString() @MaxLength(40) iconKey?: string;
  @IsOptional() @IsObject() config?: Record<string, unknown>;
}

export class ResolveReportDto {
  @IsIn(['investigating', 'resolved', 'dismissed']) status!: 'investigating' | 'resolved' | 'dismissed';
  @IsOptional() @IsString() @MaxLength(2000) resolutionNote?: string;
  @IsOptional() @IsIn(['none', 'warn', 'suspend_reported']) moderationAction?: 'none' | 'warn' | 'suspend_reported';
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
