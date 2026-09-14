import { RowDataPacket } from 'mysql2/promise';
import type { MysqlService } from '../database/mysql.service';

/** Shared bot accounts reused by every match. Must stay in sync with database/seed.sql. */
export const BOT_POOL_SIZE = 12;
export const BOT_POOL_PREFIX = '30000000-0000-4000-8000-';
export const botPoolId = (ordinal: number): string => `${BOT_POOL_PREFIX}0000000000${String(ordinal + 1).padStart(2, '0')}`;
export const BOT_POOL_SEED: Array<[username: string, displayName: string]> = [
  ['bot_aria', 'Aria'],
  ['bot_mina', 'Mina'],
  ['bot_noah', 'Noah'],
  ['bot_sami', 'Sami'],
  ['bot_nika', 'Nika'],
  ['bot_milo', 'Milo'],
  ['bot_lina', 'Lina'],
  ['bot_raya', 'Raya'],
  ['bot_kian', 'Kian'],
  ['bot_dara', 'Dara'],
  ['bot_tara', 'Tara'],
  ['bot_eli', 'Eli'],
];

let columnReady: boolean | null = null;

/**
 * Adds users.is_bot on databases created before the bot pool existed.
 * Cached per process; returns false (instead of throwing) when DDL is not
 * permitted so callers can fall back to legacy behavior.
 */
export async function ensureUsersBotColumn(mysql: MysqlService): Promise<boolean> {
  if (columnReady !== null) return columnReady;
  try {
    const rows = await mysql.query<RowDataPacket[]>(
      `SELECT 1 AS ok FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'is_bot' LIMIT 1`,
    );
    if (!rows[0]) await mysql.execute(`ALTER TABLE users ADD COLUMN is_bot TINYINT(1) NOT NULL DEFAULT 0, ADD KEY idx_users_bot (is_bot)`);
    columnReady = true;
  } catch {
    columnReady = false;
  }
  return columnReady;
}
