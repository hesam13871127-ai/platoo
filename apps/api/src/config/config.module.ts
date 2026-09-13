import { Global, Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import configuration from './configuration';

@Global()
@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true, cache: true, load: [configuration] })],
  exports: [ConfigModule],
})
export class AppConfigModule {}
