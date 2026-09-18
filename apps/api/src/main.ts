import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory, Reflector } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { corsOriginOption } from './common/cors.util';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { RequestIdInterceptor } from './common/interceptors/request-id.interceptor';
import { TrimStringsPipe } from './common/pipes/trim.pipe';
import { RateLimitGuard } from './common/rate-limit/rate-limit.guard';
import { RedisRateLimitService } from './common/rate-limit/redis-rate-limit.service';
import { ConfigService } from '@nestjs/config';
import { assertProductionReady } from './config/production-config';

async function bootstrap(): Promise<void> {
  const isProd = process.env.NODE_ENV === 'production';
  const configuredOrigins = (process.env.CORS_ORIGINS ?? '').split(',').map((o) => o.trim()).filter(Boolean);

  const corsConfig = {
    origin: corsOriginOption(configuredOrigins, isProd),
    credentials: true,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Accept', 'Authorization', 'X-Request-ID', 'X-Requested-With', 'Origin', 'Access-Control-Request-Method', 'Access-Control-Request-Headers'],
    exposedHeaders: ['Content-Range', 'X-Content-Range', 'X-Request-ID'],
    preflightContinue: false,
    optionsSuccessStatus: 204,
  };

  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
    cors: corsConfig,
  });

  const config = app.get(ConfigService);
  assertProductionReady(config);
  const production = config.get<string>('nodeEnv') === 'production';

  app.setGlobalPrefix('api/v1');
  app.enableShutdownHooks();
  app.enableCors(corsConfig);
  app.use(
    helmet({
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
      crossOriginOpenerPolicy: { policy: 'unsafe-none' },
    }),
  );
  app.getHttpAdapter().getInstance().set('trust proxy', 1);
  // NOTE: whitelist stays off on purpose — GameActionDto carries dynamic per-game
  // keys (column, pit, cells, ...) that a strip-unknown-props pipe would delete.
  // Every action payload is validated again by its authoritative game engine.
  app.useGlobalPipes(new TrimStringsPipe(), new ValidationPipe({ transform: true, whitelist: false, forbidUnknownValues: true, transformOptions: { enableImplicitConversion: true } }));
  app.useGlobalGuards(new RateLimitGuard(app.get(Reflector), config, app.get(RedisRateLimitService)));
  app.useGlobalInterceptors(new RequestIdInterceptor());
  app.useGlobalFilters(new HttpExceptionFilter());
  await app.listen(config.get<number>('port', 3000), '0.0.0.0');
}

bootstrap().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
