import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { RateLimit } from '../common/rate-limit/rate-limit.decorator';
import { invalid } from '../common/errors';
import { IapProvider, VerifyPurchaseDto } from './iap.dto';
import { IapService } from './iap.service';

const MINUTE = 60_000;

@UseGuards(JwtAuthGuard)
@Controller()
export class IapController {
  constructor(private readonly iap: IapService) {}

  @RateLimit({ limit: 120, windowMs: MINUTE })
  @Get('iap/products') products(@Query('provider') provider?: string) {
    if (provider !== undefined && provider !== 'apple' && provider !== 'google') throw invalid('Unknown provider. Use apple or google.');
    return this.iap.products(provider as IapProvider | undefined);
  }

  @RateLimit({ limit: 10, windowMs: MINUTE, key: 'user' })
  @Post('iap/verify') verify(@CurrentUser() user: AuthenticatedUser, @Body() dto: VerifyPurchaseDto) {
    return this.iap.verify(user.id, dto);
  }

  @RateLimit({ limit: 60, windowMs: MINUTE })
  @Get('iap/purchases') history(@CurrentUser() user: AuthenticatedUser, @Query('limit') limit?: string) {
    return this.iap.history(user.id, Number(limit ?? 50));
  }
}
