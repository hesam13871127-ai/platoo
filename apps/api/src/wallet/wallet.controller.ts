import { Body, Controller, Get, Post, Put, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { BuyItemDto, EquipItemDto, GiftItemDto } from './wallet.dto';
import { WalletService } from './wallet.service';
import { RateLimit } from '../common/rate-limit/rate-limit.decorator';

const MINUTE = 60_000;

@UseGuards(JwtAuthGuard)
@Controller()
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('wallet') balance(@CurrentUser() user: AuthenticatedUser) { return this.wallet.balance(user.id); }
  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('wallet/ledger') ledger(@CurrentUser() user: AuthenticatedUser, @Query('limit') limit?: string) { return this.wallet.ledger(user.id, Number(limit ?? 50)); }
  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('shop/items') catalog(@CurrentUser() user: AuthenticatedUser) { return this.wallet.catalog(user.id); }
  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('shop/inventory') inventory(@CurrentUser() user: AuthenticatedUser) { return this.wallet.inventory(user.id); }
  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Get('shop/gifts') gifts(@CurrentUser() user: AuthenticatedUser, @Query('limit') limit?: string) { return this.wallet.gifts(user.id, Number(limit ?? 30)); }
  @RateLimit({ limit: 30, windowMs: MINUTE })
  @Post('shop/purchase') buy(@CurrentUser() user: AuthenticatedUser, @Body() dto: BuyItemDto) { return this.wallet.buy(user.id, dto); }
  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Put('shop/equip') equip(@CurrentUser() user: AuthenticatedUser, @Body() dto: EquipItemDto) { return this.wallet.equip(user.id, dto); }
  @RateLimit({ limit: 30, windowMs: MINUTE })
  @Post('shop/gift') gift(@CurrentUser() user: AuthenticatedUser, @Body() dto: GiftItemDto) { return this.wallet.gift(user.id, dto); }
}
