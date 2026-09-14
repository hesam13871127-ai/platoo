import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { MysqlService } from '../database/mysql.service';
import { RowDataPacket } from 'mysql2/promise';

/**
 * Temporary bans are stored with an expiry instead of a timer, so a periodic sweep
 * reinstates the accounts whose suspension has run out. Accounts that were suspended
 * by a still-active or permanent ban are left untouched.
 */
@Injectable()
export class BanExpiryService {
  private readonly logger = new Logger(BanExpiryService.name);

  constructor(private readonly mysql: MysqlService) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async sweep(): Promise<void> {
    try {
      const expired = await this.mysql.query<RowDataPacket[]>(
        `SELECT DISTINCT user_id AS userId FROM user_bans
         WHERE lifted_at IS NULL AND expires_at IS NOT NULL AND expires_at <= UTC_TIMESTAMP(3)`,
      );
      if (!expired.length) return;
      for (const row of expired) {
        const userId = String(row.userId);
        await this.mysql.execute(
          `UPDATE user_bans SET lifted_at = UTC_TIMESTAMP(3), lift_reason = 'Ban duration elapsed.'
           WHERE user_id = ? AND lifted_at IS NULL AND expires_at IS NOT NULL AND expires_at <= UTC_TIMESTAMP(3)`,
          [userId],
        );
        const remaining = await this.mysql.query<RowDataPacket[]>(
          `SELECT id FROM user_bans WHERE user_id = ? AND lifted_at IS NULL AND (expires_at IS NULL OR expires_at > UTC_TIMESTAMP(3)) LIMIT 1`,
          [userId],
        );
        if (!remaining.length) await this.mysql.execute(`UPDATE users SET status = 'active' WHERE id = ? AND status = 'suspended'`, [userId]);
      }
      this.logger.log(`Lifted expired bans for ${expired.length} account(s).`);
    } catch (error) {
      this.logger.error(`Ban expiry sweep failed: ${(error as Error).message}`);
    }
  }
}
