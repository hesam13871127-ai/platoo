import { Body, Controller, Headers, Post, Put, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import { AuthService } from './auth.service';
import { DevAdminLoginDto, RefreshTokenDto, RequestOtpDto, SocialLoginDto, UpdatePreferencesDto, VerifyOtpDto } from './auth.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';
import { RateLimit } from '../common/rate-limit/rate-limit.decorator';

const MINUTE = 60_000;

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('otp/request')
  @RateLimit({ limit: 5, windowMs: MINUTE, key: 'ip' })
  requestOtp(@Body() dto: RequestOtpDto) { return this.auth.requestOtp(dto); }

  @Post('otp/verify')
  @RateLimit({ limit: 10, windowMs: MINUTE, key: 'ip' })
  verifyOtp(@Body() dto: VerifyOtpDto, @Req() request: Request) {
    return this.auth.verifyOtp(dto.challengeId, dto.code, request.headers['user-agent'], request.ip);
  }

  @Post('social')
  @RateLimit({ limit: 10, windowMs: MINUTE, key: 'ip' })
  social(@Body() dto: SocialLoginDto, @Req() request: Request) {
    return this.auth.socialLogin(dto, request.headers['user-agent'], request.ip);
  }

  @Post('dev-admin')
  @RateLimit({ limit: 10, windowMs: MINUTE, key: 'ip' })
  devAdmin(@Body() dto: DevAdminLoginDto, @Req() request: Request) {
    return this.auth.devAdminLogin(dto, request.headers['user-agent'], request.ip);
  }

  @Post('refresh')
  @RateLimit({ limit: 30, windowMs: MINUTE, key: 'ip' })
  refresh(@Body() dto: RefreshTokenDto, @Req() request: Request) {
    return this.auth.refresh(dto.refreshToken, request.headers['user-agent'], request.ip);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @RateLimit({ limit: 60, windowMs: MINUTE })
  logout(@CurrentUser() user: AuthenticatedUser) { return this.auth.logout(user).then(() => ({ success: true })); }

  @Put('preferences')
  @UseGuards(JwtAuthGuard)
  @RateLimit({ limit: 60, windowMs: MINUTE })
  preferences(@CurrentUser() user: AuthenticatedUser, @Body() dto: UpdatePreferencesDto) { return this.auth.updatePreferences(user.id, dto); }
}
