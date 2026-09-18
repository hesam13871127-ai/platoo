import { ConfigService } from '@nestjs/config';
import { RateLimitGuard } from '../src/common/rate-limit/rate-limit.guard';
import { RATE_LIMIT_KEY, SKIP_RATE_LIMIT_KEY } from '../src/common/rate-limit/rate-limit.decorator';
import { RedisRateLimitService } from '../src/common/rate-limit/redis-rate-limit.service';

function context(options: { limit: number; windowMs: number; key?: 'ip' | 'user' | 'auto' }, ip = '198.51.100.10') {
  const headers = new Map<string, string>();
  const response = { setHeader: (name: string, value: string) => headers.set(name, value) };
  const reflector = {
    getAllAndOverride: (key: string) => key === RATE_LIMIT_KEY ? options : key === SKIP_RATE_LIMIT_KEY ? false : undefined,
  };
  const execution = {
    getType: () => 'http',
    getHandler: () => function handler() {},
    getClass: () => class TestController {},
    switchToHttp: () => ({ getRequest: () => ({ ip }), getResponse: () => response }),
  };
  return { execution, reflector, headers };
}

describe('rate limiting', () => {
  it('falls back cleanly when Redis is not configured', async () => {
    const config = { get: jest.fn().mockReturnValue('') } as unknown as ConfigService;
    const service = new RedisRateLimitService(config);
    await expect(service.increment('test', 1000)).resolves.toBeNull();
    await expect(service.onApplicationShutdown()).resolves.toBeUndefined();
  });

  it('uses the distributed result when the Redis service is available', async () => {
    const { execution, reflector, headers } = context({ limit: 1, windowMs: 1000 });
    const config = { get: jest.fn().mockReturnValue(true) } as unknown as ConfigService;
    const distributed = { increment: jest.fn().mockResolvedValue({ count: 2, resetAt: Date.now() + 1000 }) };
    const guard = new RateLimitGuard(reflector as any, config, distributed as any);

    await expect(guard.canActivate(execution as any)).rejects.toMatchObject({ status: 429, response: { statusCode: 429 } });
    expect(distributed.increment).toHaveBeenCalledTimes(1);
    expect(headers.get('X-RateLimit-Remaining')).toBe('0');
  });

  it('keeps enforcing a local fixed window when Redis is unavailable', async () => {
    const { execution, reflector } = context({ limit: 2, windowMs: 60_000 });
    const config = { get: jest.fn().mockReturnValue(true) } as unknown as ConfigService;
    const distributed = { increment: jest.fn().mockResolvedValue(null) };
    const guard = new RateLimitGuard(reflector as any, config, distributed as any);

    await expect(guard.canActivate(execution as any)).resolves.toBe(true);
    await expect(guard.canActivate(execution as any)).resolves.toBe(true);
    await expect(guard.canActivate(execution as any)).rejects.toMatchObject({ status: 429, response: { statusCode: 429 } });
  });
});
