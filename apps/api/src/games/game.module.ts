import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { GameController } from './game.controller';
import { GameGateway } from './game.gateway';
import { GameService } from './game.service';
import { GameRegistry } from './game.registry';
import { AuthModule } from '../auth/auth.module';
import { RankingModule } from '../ranking/ranking.module';

@Module({
  imports: [AuthModule, RankingModule, JwtModule.register({})],
  controllers: [GameController],
  providers: [GameRegistry, GameService, GameGateway],
  exports: [GameRegistry, GameService],
})
export class GameModule {}
