import { Module } from '@nestjs/common';
import { WalletController } from './wallet.controller';
import { WalletService } from './wallet.service';
import { ChatModule } from '../chat/chat.module';

// ChatModule is imported so a delivered gift can also drop a gift card into the
// sender/recipient conversation. The dependency is optional in WalletService,
// so the shop keeps working even if chat is unavailable.
@Module({ imports: [ChatModule], controllers: [WalletController], providers: [WalletService], exports: [WalletService] })
export class WalletModule {}
