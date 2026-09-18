import { IsIn, IsOptional, IsString, Length, Matches } from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @Matches(/^\+[1-9]\d{7,14}$/, { message: 'phone must use E.164 format, for example +14155552671' })
  phone!: string;
}

export class VerifyOtpDto {
  @IsString()
  challengeId!: string;

  @IsString()
  @Matches(/^\d{6}$/, { message: 'code must be six digits' })
  code!: string;
}

export class SocialLoginDto {
  @IsIn(['google', 'apple'])
  provider!: 'google' | 'apple';

  @IsString()
  token!: string;

  @IsOptional()
  @IsString()
  @Length(1, 80)
  displayName?: string;
}

export class RefreshTokenDto {
  @IsString()
  refreshToken!: string;
}

export class DevAdminLoginDto {
  @IsString()
  @Length(1, 80)
  username!: string;

  @IsString()
  @Length(1, 120)
  password!: string;
}

export class UpdatePreferencesDto {
  @IsOptional()
  @IsIn(['en', 'fa'])
  locale?: 'en' | 'fa';

  @IsOptional()
  @IsIn(['light', 'dark', 'system'])
  theme?: 'light' | 'dark' | 'system';
}
