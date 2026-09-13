import { Body, Controller, Get, Post, Put, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { BuyItemDto, EquipItemDto, GiftItemDto } from './wallet.dto';
import { WalletService } from './wallet.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  @Get('wallet') balance(@CurrentUser() user: AuthenticatedUser) { return this.wallet.balance(user.id); }
  @Get('wallet/ledger') ledger(@CurrentUser() user: AuthenticatedUser, @Query('limit') limit?: string) { return this.wallet.ledger(user.id, Number(limit ?? 50)); }
  @Get('shop/items') catalog() { return this.wallet.catalog(); }
  @Get('shop/inventory') inventory(@CurrentUser() user: AuthenticatedUser) { return this.wallet.inventory(user.id); }
  @Post('shop/purchase') buy(@CurrentUser() user: AuthenticatedUser, @Body() dto: BuyItemDto) { return this.wallet.buy(user.id, dto); }
  @Put('shop/equip') equip(@CurrentUser() user: AuthenticatedUser, @Body() dto: EquipItemDto) { return this.wallet.equip(user.id, dto); }
  @Post('shop/gift') gift(@CurrentUser() user: AuthenticatedUser, @Body() dto: GiftItemDto) { return this.wallet.gift(user.id, dto); }
}
