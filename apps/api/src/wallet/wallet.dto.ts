import { IsBoolean, IsIn, IsInt, IsOptional, IsString, IsUUID, MaxLength, Min } from 'class-validator';

export class BuyItemDto {
  @IsUUID()
  itemId!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  quantity?: number = 1;

  @IsOptional()
  @IsIn(['coins', 'pips'])
  currency?: 'coins' | 'pips';

  @IsOptional()
  @IsString()
  @MaxLength(100)
  idempotencyKey?: string;
}

export class EquipItemDto {
  @IsUUID()
  itemId!: string;

  @IsOptional()
  @IsBoolean()
  equipped?: boolean;
}

export class GiftItemDto {
  @IsUUID()
  recipientId!: string;

  @IsUUID()
  itemId!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  quantity?: number = 1;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  note?: string;

  @IsOptional()
  @IsBoolean()
  buyDirect?: boolean;
}
