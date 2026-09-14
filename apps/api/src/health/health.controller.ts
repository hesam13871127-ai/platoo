import { Controller, Get, HttpCode, HttpStatus, ServiceUnavailableException } from '@nestjs/common';
import { MysqlService } from '../database/mysql.service';
import { SkipRateLimit } from '../common/rate-limit/rate-limit.decorator';

@SkipRateLimit()
@Controller('health')
export class HealthController {
  private readonly startedAt = Date.now();

  constructor(private readonly mysql: MysqlService) {}

  @Get()
  @HttpCode(HttpStatus.OK)
  async health() {
    const database = await this.mysql.ping();
    return {
      status: database ? 'ok' : 'degraded',
      database,
      uptimeSeconds: Math.floor((Date.now() - this.startedAt) / 1000),
      timestamp: new Date().toISOString(),
    };
  }

  @Get('ready')
  @HttpCode(HttpStatus.OK)
  async ready() {
    const database = await this.mysql.ping();
    if (!database) throw new ServiceUnavailableException('Database is unreachable.');
    return {
      status: 'ready',
      database: true,
      uptimeSeconds: Math.floor((Date.now() - this.startedAt) / 1000),
      timestamp: new Date().toISOString(),
    };
  }
}
