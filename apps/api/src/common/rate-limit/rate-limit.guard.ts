import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { Response } from 'express';
import { rateLimited } from '../errors';
import { RATE_LIMIT_KEY, RateLimitOptions, SKIP_RATE_LIMIT_KEY } from './rate-limit.decorator';

interface Bucket {
  count: number;
  resetAt: number;
}

/**
 * Fixed-window HTTP rate limiter. In-memory by design: correct for a single
 * API instance (current soft-launch topology) with zero new dependencies.
 * Move the buckets to Redis when the API scales past one replica.
 */
@Injectable()
export class RateLimitGuard implements CanActivate {
  private readonly buckets = new Map<string, Bucket>();

  constructor(private readonly reflector: Reflector, private readonly config: ConfigService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') return true;
    if (this.config.get('rateLimit.enabled', true) === false) return true;
    const skip = this.reflector.getAllAndOverride<boolean>(SKIP_RATE_LIMIT_KEY, [context.getHandler(), context.getClass()]);
    if (skip) return true;
    const options = this.reflector.getAllAndOverride<RateLimitOptions>(RATE_LIMIT_KEY, [context.getHandler(), context.getClass()]);
    if (!options) return true;
    const request = context.switchToHttp().getRequest<{ user?: { id?: string }; ip?: string }>();
    const response = context.switchToHttp().getResponse<Response>();
    const identity = options.key === 'ip' ? request.ip ?? 'unknown' : request.user?.id ?? request.ip ?? 'unknown';
    const scope = `${context.getClass().name}.${String(context.getHandler().name)}`;
    const key = `rl:${scope}:${options.key ?? 'auto'}:${identity}`;
    const now = Date.now();
    let bucket = this.buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      bucket = { count: 0, resetAt: now + options.windowMs };
      this.buckets.set(key, bucket);
    }
    bucket.count += 1;
    response.setHeader('X-RateLimit-Limit', String(options.limit));
    response.setHeader('X-RateLimit-Remaining', String(Math.max(options.limit - bucket.count, 0)));
    response.setHeader('X-RateLimit-Reset', String(Math.ceil(bucket.resetAt / 1000)));
    this.sweep(now);
    if (bucket.count > options.limit) {
      response.setHeader('Retry-After', String(Math.max(Math.ceil((bucket.resetAt - now) / 1000), 1)));
      throw rateLimited();
    }
    return true;
  }

  private sweep(now: number): void {
    if (this.buckets.size < 2000 && Math.random() > 0.01) return;
    for (const [key, bucket] of this.buckets) if (bucket.resetAt <= now) this.buckets.delete(key);
  }
}
