import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory, Reflector } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { RequestIdInterceptor } from './common/interceptors/request-id.interceptor';
import { TrimStringsPipe } from './common/pipes/trim.pipe';
import { RateLimitGuard } from './common/rate-limit/rate-limit.guard';
import { ConfigService } from '@nestjs/config';

function assertProductionReady(config: ConfigService): void {
  if (config.get<string>('nodeEnv') !== 'production') return;
  const problems: string[] = [];
  for (const key of ['jwt.accessSecret', 'jwt.refreshSecret'] as const) {
    const value = config.get<string>(key, '');
    if (value.length < 32 || /change-me|replace-with/i.test(value)) problems.push(`${key} must be a unique secret of at least 32 characters.`);
  }
  if (!config.get<string[]>('corsOrigins', []).length) problems.push('CORS_ORIGINS must list the allowed web origins (mobile apps are unaffected).');
  if (config.get<boolean>('otp.devEnabled', false)) problems.push('DEV_OTP_ENABLED must be false in production; configure OTP_WEBHOOK_URL instead.');
  if (problems.length) throw new Error(`Refusing to boot with unsafe production config:\n- ${problems.join('\n- ')}`);
  if (config.get<string>('database.password', '') === 'vibetable' || config.get<string>('database.user', '') === 'vibetable') {
    console.warn('WARNING: production is using the default database credentials. Set DB_USER/DB_PASSWORD or DATABASE_URL.');
  }
}

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const config = app.get(ConfigService);
  assertProductionReady(config);
  const production = config.get<string>('nodeEnv') === 'production';
  app.setGlobalPrefix('api/v1');
  app.enableShutdownHooks();
  app.use(helmet({ contentSecurityPolicy: false }));
  const configuredOrigins = config.get<string[]>('corsOrigins', []);
  app.enableCors({ origin: configuredOrigins.length ? configuredOrigins : !production, credentials: true });
  app.getHttpAdapter().getInstance().set('trust proxy', 1);
  // NOTE: whitelist stays off on purpose — GameActionDto carries dynamic per-game
  // keys (column, pit, cells, ...) that a strip-unknown-props pipe would delete.
  // Every action payload is validated again by its authoritative game engine.
  app.useGlobalPipes(new TrimStringsPipe(), new ValidationPipe({ transform: true, whitelist: false, forbidUnknownValues: true, transformOptions: { enableImplicitConversion: true } }));
  app.useGlobalGuards(new RateLimitGuard(app.get(Reflector), config));
  app.useGlobalInterceptors(new RequestIdInterceptor());
  app.useGlobalFilters(new HttpExceptionFilter());
  await app.listen(config.get<number>('port', 3000), '0.0.0.0');
}

bootstrap().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
