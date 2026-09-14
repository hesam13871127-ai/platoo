import { SetMetadata } from '@nestjs/common';

export interface RateLimitOptions {
  /** Max requests allowed inside the window. */
  limit: number;
  /** Window length in milliseconds. */
  windowMs: number;
  /** Identity to count against: the authenticated user, the client IP, or user-with-IP-fallback. */
  key?: 'ip' | 'user' | 'auto';
}

export const RATE_LIMIT_KEY = 'vibe_rate_limit';
export const RateLimit = (options: RateLimitOptions) => SetMetadata(RATE_LIMIT_KEY, options);

export const SKIP_RATE_LIMIT_KEY = 'vibe_skip_rate_limit';
export const SkipRateLimit = () => SetMetadata(SKIP_RATE_LIMIT_KEY, true);
