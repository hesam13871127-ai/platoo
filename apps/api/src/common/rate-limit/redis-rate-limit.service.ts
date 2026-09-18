import { Injectable, Logger, OnApplicationShutdown } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

export interface DistributedRateLimitBucket {
  count: number;
  resetAt: number;
}

/**
 * Best-effort distributed fixed-window limiter. Redis is deliberately not part of
 * the request path when it is unavailable: the HTTP guard falls back to its
 * process-local bucket so an outage does not take the API down. Production boot
 * nevertheless requires REDIS_URL so a multi-replica deployment cannot silently
 * lose its shared abuse protection.
 */
@Injectable()
export class RedisRateLimitService implements OnApplicationShutdown {
  private readonly logger = new Logger(RedisRateLimitService.name);
  private readonly redis: Redis | null;
  private warned = false;

  constructor(config: ConfigService) {
    const url = config.get<string>('redisUrl', '').trim();
    this.redis = url
      ? new Redis(url, {
          lazyConnect: true,
          enableOfflineQueue: false,
          maxRetriesPerRequest: 1,
          connectTimeout: 1500,
          retryStrategy: () => null,
        })
      : null;
    this.redis?.on('error', (error: Error) => {
      if (!this.warned) {
        this.warned = true;
        this.logger.warn(`Distributed rate limiting is unavailable; using local buckets: ${error.message}`);
      }
    });
  }

  async increment(key: string, windowMs: number): Promise<DistributedRateLimitBucket | null> {
    if (!this.redis) return null;
    const now = Date.now();
    const window = Math.floor(now / windowMs);
    const redisKey = `vibetable:rate:${key}:${window}`;
    try {
      const result = await this.redis.multi().incr(redisKey).pexpire(redisKey, windowMs + 1000).exec();
      const count = Number(result?.[0]?.[1] ?? 0);
      if (!Number.isFinite(count) || count <= 0) return null;
      return { count, resetAt: (window + 1) * windowMs };
    } catch (error: unknown) {
      if (!this.warned) {
        this.warned = true;
        this.logger.warn(`Distributed rate limiting is unavailable; using local buckets: ${error instanceof Error ? error.message : String(error)}`);
      }
      return null;
    }
  }

  async onApplicationShutdown(): Promise<void> {
    if (this.redis) await this.redis.quit().catch(() => this.redis?.disconnect());
  }
}
