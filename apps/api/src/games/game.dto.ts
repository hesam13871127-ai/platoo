import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

export class CreateMatchDto {
  @IsString()
  gameId!: string;

  @IsIn(['casual', 'ranked', 'private'])
  mode!: 'casual' | 'ranked' | 'private';

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(12)
  desiredPlayers?: number;

  @IsOptional()
  @IsUUID('4', { each: true })
  playerIds?: string[];
}

export class GameActionDto {
  @IsString()
  type!: string;

  [key: string]: unknown;
}
