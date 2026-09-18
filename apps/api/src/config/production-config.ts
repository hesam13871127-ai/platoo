import { ConfigService } from '@nestjs/config';

export function productionConfigProblems(config: ConfigService): string[] {
  if (config.get<string>('nodeEnv') !== 'production') return [];
  const problems: string[] = [];
  for (const key of ['jwt.accessSecret', 'jwt.refreshSecret'] as const) {
    const value = config.get<string>(key, '');
    if (value.length < 32 || /change-me|replace-with/i.test(value)) problems.push(`${key} must be a unique secret of at least 32 characters.`);
  }
  if (!config.get<string[]>('corsOrigins', []).length) problems.push('CORS_ORIGINS must list the allowed web origins (mobile apps are unaffected).');
  if (config.get<boolean>('otp.devEnabled', false)) problems.push('DEV_OTP_ENABLED must be false in production; configure OTP_WEBHOOK_URL instead.');
  if (!config.get<string>('otp.webhookUrl', '').trim()) problems.push('OTP_WEBHOOK_URL must be configured in production; phone verification cannot log or return codes.');
  if (config.get<boolean>('iap.devEnabled', false)) problems.push('DEV_IAP_ENABLED must be false in production; configure App Store / Play credentials instead.');
  if (!config.get<string>('redisUrl', '').trim()) problems.push('REDIS_URL must be configured in production so rate limits are shared across API replicas.');
  return problems;
}

export function assertProductionReady(config: ConfigService): void {
  const problems = productionConfigProblems(config);
  if (problems.length) throw new Error(`Refusing to boot with unsafe production config:\n- ${problems.join('\n- ')}`);
  if (config.get<string>('nodeEnv') === 'production' && (config.get<string>('database.password', '') === 'vibetable' || config.get<string>('database.user', '') === 'vibetable')) {
    console.warn('WARNING: production is using the default database credentials. Set DB_USER/DB_PASSWORD or DATABASE_URL.');
  }
}
