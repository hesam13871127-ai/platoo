import { IsOptional, IsUUID } from 'class-validator';

export class VoiceTokenDto {
  @IsOptional()
  @IsUUID()
  matchId?: string;

  @IsOptional()
  @IsUUID()
  conversationId?: string;
}
