import { IsBoolean, IsInt, IsOptional, IsString, IsUUID, MaxLength, Min, MinLength } from 'class-validator';

export class BuyItemDto {
  @IsUUID()
  itemId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  idempotencyKey?: string;
}

export class EquipItemDto {
  @IsUUID()
  itemId!: string;

  /** `false` takes the item off. Omitting it keeps the original equip behaviour. */
  @IsOptional()
  @IsBoolean()
  equipped?: boolean;
}

export class GiftItemDto {
  @IsUUID()
  recipientId!: string;

  @IsUUID()
  itemId!: string;

  @IsInt()
  @Min(1)
  quantity = 1;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  note?: string;
}
