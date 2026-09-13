import { Controller, Get } from '@nestjs/common';
import { MysqlService } from '../database/mysql.service';

@Controller('health')
export class HealthController {
  constructor(private readonly mysql: MysqlService) {}

  @Get()
  async health() {
    const database = await this.mysql.ping();
    return { status: database ? 'ok' : 'degraded', database, timestamp: new Date().toISOString() };
  }
}
