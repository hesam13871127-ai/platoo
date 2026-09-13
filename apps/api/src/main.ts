import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { RequestIdInterceptor } from './common/interceptors/request-id.interceptor';
import { TrimStringsPipe } from './common/pipes/trim.pipe';
import { ConfigService } from '@nestjs/config';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const config = app.get(ConfigService);
  app.setGlobalPrefix('api/v1');
  app.enableShutdownHooks();
  app.use(helmet({ contentSecurityPolicy: false }));
  const configuredOrigins = config.get<string[]>('corsOrigins', []);
  app.enableCors({ origin: configuredOrigins.length ? configuredOrigins : true, credentials: true });
  app.getHttpAdapter().getInstance().set('trust proxy', 1);
  app.useGlobalPipes(new TrimStringsPipe(), new ValidationPipe({ transform: true, whitelist: false, forbidUnknownValues: true, transformOptions: { enableImplicitConversion: true } }));
  app.useGlobalInterceptors(new RequestIdInterceptor());
  app.useGlobalFilters(new HttpExceptionFilter());
  await app.listen(config.get<number>('port', 3000), '0.0.0.0');
}

bootstrap().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
