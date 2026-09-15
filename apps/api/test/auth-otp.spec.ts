import { HttpStatus, Logger } from '@nestjs/common';
import { AuthService } from '../src/auth/auth.service';

function stubConfig(values: Record<string, unknown>) {
  return { get: jest.fn((key: string, defaultValue?: unknown) => (key in values ? values[key] : defaultValue)) };
}

function stubMysql() {
  return {
    query: jest.fn(async () => [{ count: 0 }]),
    execute: jest.fn(async () => ({ affectedRows: 1 })),
    transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback({})),
  };
}

const jwt = { signAsync: jest.fn(), verifyAsync: jest.fn() };

describe('OTP request delivery modes', () => {
  const realFetch = global.fetch;
  let warn: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
  });

  afterEach(() => {
    warn.mockRestore();
    global.fetch = realFetch;
  });

  it('zero-config development boot logs the code and returns devCode', async () => {
    const service = new AuthService(stubMysql() as any, jwt as any, stubConfig({ nodeEnv: 'development' }) as any);
    const result = await service.requestOtp({ phone: '+14155552671' });
    expect(result.challengeId).toMatch(/^[0-9a-f-]{36}$/);
    expect(result.devCode).toMatch(/^\d{6}$/);
    expect(warn).toHaveBeenCalledTimes(1);
    const logged = String(warn.mock.calls[0][0]);
    expect(logged).toContain('Development OTP for +14155552671:');
    expect(logged).toContain(result.devCode as string);
  });

  it('explicit DEV_OTP_ENABLED returns devCode even when a webhook exists', async () => {
    global.fetch = jest.fn(async () => ({ ok: true })) as any;
    const service = new AuthService(
      stubMysql() as any,
      jwt as any,
      stubConfig({ nodeEnv: 'staging', 'otp.devEnabled': true, 'otp.webhookUrl': 'https://sms.example/hook' }) as any,
    );
    const result = await service.requestOtp({ phone: '+14155552671' });
    expect(result.devCode).toMatch(/^\d{6}$/);
    expect(global.fetch).toHaveBeenCalledTimes(1);
  });

  it('webhook delivery posts phone and code without devCode', async () => {
    global.fetch = jest.fn(async () => ({ ok: true })) as any;
    const service = new AuthService(
      stubMysql() as any,
      jwt as any,
      stubConfig({ nodeEnv: 'development', 'otp.webhookUrl': 'https://sms.example/hook' }) as any,
    );
    const result = await service.requestOtp({ phone: '+14155552671' });
    expect(result.devCode).toBeUndefined();
    expect(global.fetch).toHaveBeenCalledWith('https://sms.example/hook', expect.objectContaining({ method: 'POST' }));
    const body = JSON.parse((global.fetch as jest.Mock).mock.calls[0][1].body as string);
    expect(body).toMatchObject({ phone: '+14155552671', code: expect.stringMatching(/^\d{6}$/) });
  });

  it('webhook network failure returns 400 instead of leaking a 500', async () => {
    global.fetch = jest.fn(async () => { throw new Error('dns down'); }) as any;
    const service = new AuthService(
      stubMysql() as any,
      jwt as any,
      stubConfig({ nodeEnv: 'development', 'otp.webhookUrl': 'https://sms.example/hook' }) as any,
    );
    const error = await service.requestOtp({ phone: '+14155552671' }).catch((e) => e);
    expect(error.getStatus()).toBe(HttpStatus.BAD_REQUEST);
    expect(error.message).toContain('could not be sent');
  });

  it('production without a webhook still fails fast with 400', async () => {
    const service = new AuthService(stubMysql() as any, jwt as any, stubConfig({ nodeEnv: 'production' }) as any);
    const error = await service.requestOtp({ phone: '+14155552671' }).catch((e) => e);
    expect(error.getStatus()).toBe(HttpStatus.BAD_REQUEST);
    expect(error.message).toContain('Phone verification is not configured.');
  });
});
