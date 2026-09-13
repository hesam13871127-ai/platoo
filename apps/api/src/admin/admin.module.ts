import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AuthModule } from '../auth/auth.module';
import { RankingModule } from '../ranking/ranking.module';

@Module({ imports: [AuthModule, RankingModule], controllers: [AdminController], providers: [AdminService] })
export class AdminModule {}
