import { Body, Controller, Headers, Post, Put, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import { AuthService } from './auth.service';
import { RefreshTokenDto, RequestOtpDto, SocialLoginDto, UpdatePreferencesDto, VerifyOtpDto } from './auth.dto';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { CurrentUser, AuthenticatedUser } from '../common/decorators/current-user.decorator';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('otp/request')
  requestOtp(@Body() dto: RequestOtpDto) { return this.auth.requestOtp(dto); }

  @Post('otp/verify')
  verifyOtp(@Body() dto: VerifyOtpDto, @Req() request: Request) {
    return this.auth.verifyOtp(dto.challengeId, dto.code, request.headers['user-agent'], request.ip);
  }

  @Post('social')
  social(@Body() dto: SocialLoginDto, @Req() request: Request) {
    return this.auth.socialLogin(dto, request.headers['user-agent'], request.ip);
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto, @Req() request: Request) {
    return this.auth.refresh(dto.refreshToken, request.headers['user-agent'], request.ip);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  logout(@CurrentUser() user: AuthenticatedUser) { return this.auth.logout(user).then(() => ({ success: true })); }

  @Put('preferences')
  @UseGuards(JwtAuthGuard)
  preferences(@CurrentUser() user: AuthenticatedUser, @Body() dto: UpdatePreferencesDto) { return this.auth.updatePreferences(user.id, dto); }
}
