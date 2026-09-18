import { assertProductionReady, productionConfigProblems } from '../src/config/production-config';

function config(values: Record<string, unknown>) {
  return {
    get: (key: string, fallback?: unknown) => key in values ? values[key] : fallback,
  } as any;
}

describe('production configuration gate', () => {
  it('does not apply production-only requirements in development', () => {
    expect(productionConfigProblems(config({ nodeEnv: 'development' }))).toEqual([]);
  });

  it('requires secrets, SMS delivery, Redis, and real purchase mode in production', () => {
    const problems = productionConfigProblems(config({ nodeEnv: 'production', 'jwt.accessSecret': 'short', 'jwt.refreshSecret': 'short', corsOrigins: [], 'otp.devEnabled': true, 'iap.devEnabled': true }));
    expect(problems).toEqual(expect.arrayContaining([
      expect.stringContaining('jwt.accessSecret'),
      expect.stringContaining('jwt.refreshSecret'),
      expect.stringContaining('CORS_ORIGINS'),
      expect.stringContaining('DEV_OTP_ENABLED'),
      expect.stringContaining('OTP_WEBHOOK_URL'),
      expect.stringContaining('DEV_IAP_ENABLED'),
      expect.stringContaining('REDIS_URL'),
    ]));
    expect(() => assertProductionReady(config({ nodeEnv: 'production' }))).toThrow('unsafe production config');
  });

  it('accepts a complete production configuration', () => {
    const complete = config({
      nodeEnv: 'production',
      'jwt.accessSecret': 'a'.repeat(64),
      'jwt.refreshSecret': 'b'.repeat(64),
      corsOrigins: ['https://vibetable.example'],
      'otp.devEnabled': false,
      'otp.webhookUrl': 'https://sms.example/send',
      'iap.devEnabled': false,
      redisUrl: 'redis://redis:6379',
      'database.user': 'vibetable_prod',
      'database.password': 'not-default',
    });
    expect(() => assertProductionReady(complete)).not.toThrow();
  });
});
