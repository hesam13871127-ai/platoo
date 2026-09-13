import { IsInt, IsOptional, IsString, IsUUID, MaxLength, Min, MinLength } from 'class-validator';

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
