import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AppConfigModule } from './config/config.module';
import { DatabaseModule } from './database/database.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { WalletModule } from './wallet/wallet.module';
import { ChatModule } from './chat/chat.module';
import { VoiceModule } from './voice/voice.module';
import { GameModule } from './games/game.module';
import { MatchmakingModule } from './matchmaking/matchmaking.module';
import { RankingModule } from './ranking/ranking.module';
import { AdminModule } from './admin/admin.module';
import { IapModule } from './iap/iap.module';
import { RateLimitModule } from './common/rate-limit/rate-limit.module';

@Module({
  imports: [AppConfigModule, DatabaseModule, ScheduleModule.forRoot(), HealthModule, AuthModule, UsersModule, WalletModule, ChatModule, VoiceModule, GameModule, MatchmakingModule, RankingModule, AdminModule, IapModule, RateLimitModule],
})
export class AppModule {}
