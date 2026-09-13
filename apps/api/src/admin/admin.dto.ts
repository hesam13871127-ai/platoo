import { IsBoolean, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';

export class UpdateUserAdminDto {
  @IsOptional()
  @IsIn(['active', 'suspended', 'deleted'])
  status?: 'active' | 'suspended' | 'deleted';
  @IsOptional()
  @IsIn(['player', 'moderator', 'admin'])
  role?: 'player' | 'moderator' | 'admin';
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
  @IsOptional() @IsInt() @Min(0) stock?: number;
}

export class ToggleDto { @IsBoolean() isActive!: boolean; }

export class ResolveReportDto {
  @IsIn(['investigating', 'resolved', 'dismissed']) status!: 'investigating' | 'resolved' | 'dismissed';
  @IsOptional() @IsString() @MaxLength(2000) resolutionNote?: string;
}

export class CreateSeasonDto {
  @IsString() @MinLength(2) @MaxLength(80) name!: string;
  @IsString() startsAt!: string;
  @IsString() endsAt!: string;
}

export class CreateSeasonRewardDto {
  @IsInt() @Min(1) minRank!: number;
  @IsInt() @Min(1) maxRank!: number;
  @IsInt() @Min(0) coins = 0;
  @IsInt() @Min(0) pips = 0;
  @IsOptional() @IsUUID() shopItemId?: string;
}
