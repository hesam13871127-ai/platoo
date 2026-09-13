import { IsIn, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class SendMessageDto {
  @IsUUID()
  conversationId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(4000)
  body!: string;

  @IsOptional()
  @IsIn(['text', 'gift'])
  kind?: 'text' | 'gift';

  @IsOptional()
  @IsUUID()
  giftItemId?: string;
}

export class CreatePrivateConversationDto {
  @IsUUID()
  userId!: string;
}

export class JoinConversationDto {
  @IsUUID()
  conversationId!: string;
}
