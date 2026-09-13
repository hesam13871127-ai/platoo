import { IsIn, IsInt, IsString, Max, Min } from 'class-validator';

export class JoinQueueDto {
  @IsString()
  gameId!: string;

  @IsIn(['casual', 'ranked'])
  mode!: 'casual' | 'ranked';

  @IsInt()
  @Min(1)
  @Max(12)
  playerCount!: number;
}
