import { Module } from '@nestjs/common';
import { MatchmakingController } from './matchmaking.controller';
import { MatchmakingService } from './matchmaking.service';
import { GameModule } from '../games/game.module';

@Module({ imports: [GameModule], controllers: [MatchmakingController], providers: [MatchmakingService], exports: [MatchmakingService] })
export class MatchmakingModule {}
