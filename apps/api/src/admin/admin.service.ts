import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, forbidden, invalid, notFound } from '../common/errors';
import {
  AdjustWalletDto,
  BanUserDto,
  BulkToggleGamesDto,
  CreateReportNoteDto,
  CreateSeasonDto,
  CreateSeasonRewardDto,
  CreateShopItemDto,
  ResolveReportDto,
  ToggleDto,
  UnbanUserDto,
  UpdateGameDto,
  UpdateSeasonDto,
  UpdateShopItemDto,
  UpdateUserAdminDto,
} from './admin.dto';
import { RankingService } from '../ranking/ranking.service';

const PAGE_SIZE = 25;

@Injectable()
export class AdminService {
  constructor(private readonly mysql: MysqlService, private readonly ranking: RankingService) {}

  // ---------------------------------------------------------------- analytics

  async overview() {
    const [users, matches, reports, revenue, economy] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(
        `SELECT COUNT(*) AS total,
                SUM(status = 'active') AS active,
                SUM(status = 'suspended') AS suspended,
                SUM(created_at >= UTC_TIMESTAMP(3) - INTERVAL 1 DAY) AS newToday,
                SUM(created_at >= UTC_TIMESTAMP(3) - INTERVAL 7 DAY) AS newThisWeek,
                SUM(last_seen_at >= UTC_TIMESTAMP(3) - INTERVAL 1 DAY) AS activeToday,
                SUM(last_seen_at >= UTC_TIMESTAMP(3) - INTERVAL 30 DAY) AS activeThisMonth
         FROM users`,
      ),
      this.mysql.query<RowDataPacket[]>(
        `SELECT COUNT(*) AS total,
                SUM(status = 'active') AS active,
                SUM(status = 'waiting') AS waiting,
                SUM(status = 'finished') AS finished,
                SUM(created_at >= UTC_TIMESTAMP(3) - INTERVAL 1 DAY) AS startedToday
         FROM matches`,
      ),
      this.mysql.query<RowDataPacket[]>(
        `SELECT COUNT(*) AS total,
                SUM(status = 'open') AS open,
                SUM(status = 'investigating') AS investigating,
                SUM(status IN ('resolved','dismissed')) AS closed
         FROM reports`,
      ),
      this.mysql.query<RowDataPacket[]>(
        `SELECT COALESCE(SUM(amount_minor), 0) AS amountMinor,
                COALESCE(SUM(amount_minor * (completed_at >= UTC_TIMESTAMP(3) - INTERVAL 30 DAY)), 0) AS amountMinor30d,
                COUNT(*) AS orders
         FROM purchases WHERE status = 'paid'`,
      ),
      this.mysql.query<RowDataPacket[]>(`SELECT COALESCE(SUM(coins), 0) AS coins, COALESCE(SUM(pips), 0) AS pips FROM wallets`),
    ]);
    return {
      users: this.numeric(users[0]),
      matches: this.numeric(matches[0]),
      reports: this.numeric(reports[0]),
      revenue: this.numeric(revenue[0]),
      economy: this.numeric(economy[0]),
    };
  }

  /** Time series plus per-game breakdown backing the analytics dashboard. */
  async analytics(days = 14) {
    const window = Math.min(Math.max(Math.trunc(days) || 14, 1), 90);
    const [signups, matchesDaily, revenueDaily, perGame, topPlayers] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(
        `SELECT DATE(created_at) AS day, COUNT(*) AS value FROM users WHERE created_at >= UTC_TIMESTAMP(3) - INTERVAL ? DAY GROUP BY day ORDER BY day`,
        [window],
      ),
      this.mysql.query<RowDataPacket[]>(
        `SELECT DATE(created_at) AS day, COUNT(*) AS value FROM matches WHERE created_at >= UTC_TIMESTAMP(3) - INTERVAL ? DAY GROUP BY day ORDER BY day`,
        [window],
      ),
      this.mysql.query<RowDataPacket[]>(
        `SELECT DATE(completed_at) AS day, COALESCE(SUM(amount_minor), 0) AS value FROM purchases WHERE status = 'paid' AND completed_at >= UTC_TIMESTAMP(3) - INTERVAL ? DAY GROUP BY day ORDER BY day`,
        [window],
      ),
      this.mysql.query<RowDataPacket[]>(
        `SELECT g.id AS gameId, g.display_name AS displayName, g.is_active AS isActive,
                COUNT(m.id) AS matches,
                SUM(m.status = 'active') AS liveMatches,
                COALESCE(SUM(m.finished_at IS NOT NULL), 0) AS finishedMatches
         FROM games g
         LEFT JOIN matches m ON m.game_id = g.id AND m.created_at >= UTC_TIMESTAMP(3) - INTERVAL ? DAY
         GROUP BY g.id, g.display_name, g.is_active
         ORDER BY matches DESC, g.display_name`,
        [window],
      ),
      this.mysql.query<RowDataPacket[]>(
        `SELECT u.id, u.display_name AS displayName, SUM(pr.wins) AS wins, SUM(pr.games_played) AS gamesPlayed, MAX(pr.rating) AS rating
         FROM player_ratings pr JOIN users u ON u.id = pr.user_id
         WHERE u.status = 'active'
         GROUP BY u.id, u.display_name
         ORDER BY rating DESC, wins DESC
         LIMIT 10`,
      ),
    ]);
    return {
      windowDays: window,
      signups: signups.map((row) => this.numeric(row)),
      matches: matchesDaily.map((row) => this.numeric(row)),
      revenue: revenueDaily.map((row) => this.numeric(row)),
      games: perGame.map((row) => this.numeric(row)),
      topPlayers: topPlayers.map((row) => this.numeric(row)),
    };
  }

  // -------------------------------------------------------------------- users

  async users(query = '', status?: string, role?: string, page = 0) {
    const params: unknown[] = [];
    const conditions = ['1 = 1'];
    if (query.trim()) {
      conditions.push('(u.username LIKE ? OR u.display_name LIKE ? OR u.phone_e164 LIKE ? OR u.email LIKE ? OR u.id = ?)');
      const term = `%${query.trim()}%`;
      params.push(term, term, term, term, query.trim());
    }
    if (status) { conditions.push('u.status = ?'); params.push(status); }
    if (role) { conditions.push('u.role = ?'); params.push(role); }
    const where = conditions.join(' AND ');
    const [total] = await this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM users u WHERE ${where}`, params);
    const items = await this.mysql.query<RowDataPacket[]>(
      `SELECT u.id, u.username, u.display_name AS displayName, u.phone_e164 AS phone, u.email, u.role, u.status, u.level,
              u.created_at AS createdAt, u.last_seen_at AS lastSeenAt,
              COALESCE(w.coins, 0) AS coins, COALESCE(w.pips, 0) AS pips,
              (SELECT COUNT(*) FROM reports r WHERE r.reported_user_id = u.id) AS reportCount,
              b.reason AS banReason, b.expires_at AS banExpiresAt
       FROM users u
       LEFT JOIN wallets w ON w.user_id = u.id
       LEFT JOIN user_bans b ON b.id = (
         SELECT ub.id FROM user_bans ub
         WHERE ub.user_id = u.id AND ub.lifted_at IS NULL AND (ub.expires_at IS NULL OR ub.expires_at > UTC_TIMESTAMP(3))
         ORDER BY ub.created_at DESC LIMIT 1)
       WHERE ${where}
       ORDER BY u.created_at DESC LIMIT ? OFFSET ?`,
      [...params, PAGE_SIZE, Math.max(page, 0) * PAGE_SIZE],
    );
    return { page: Math.max(page, 0), pageSize: PAGE_SIZE, total: Number(total?.total ?? 0), items };
  }

  async user(userId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(
      `SELECT u.id, u.username, u.display_name AS displayName, u.phone_e164 AS phone, u.email, u.avatar_url AS avatarUrl, u.role, u.status,
              u.level, u.experience, u.created_at AS createdAt, u.last_seen_at AS lastSeenAt,
              COALESCE(w.coins, 0) AS coins, COALESCE(w.pips, 0) AS pips
       FROM users u LEFT JOIN wallets w ON w.user_id = u.id WHERE u.id = ?`,
      [userId],
    );
    if (!rows[0]) throw notFound('User not found.');
    const [bans, reportsAgainst, recentMatches] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(
        `SELECT b.id, b.reason, b.expires_at AS expiresAt, b.created_at AS createdAt, b.lifted_at AS liftedAt, b.lift_reason AS liftReason,
                issuer.display_name AS issuedByName, lifter.display_name AS liftedByName
         FROM user_bans b
         JOIN users issuer ON issuer.id = b.issued_by
         LEFT JOIN users lifter ON lifter.id = b.lifted_by
         WHERE b.user_id = ? ORDER BY b.created_at DESC LIMIT 20`,
        [userId],
      ),
      this.mysql.query<RowDataPacket[]>(
        `SELECT id, category, description, status, created_at AS createdAt FROM reports WHERE reported_user_id = ? ORDER BY created_at DESC LIMIT 20`,
        [userId],
      ),
      this.mysql.query<RowDataPacket[]>(
        `SELECT m.id, m.game_id AS gameId, m.mode, m.status, mp.result, m.created_at AS createdAt
         FROM match_players mp JOIN matches m ON m.id = mp.match_id
         WHERE mp.user_id = ? ORDER BY mp.joined_at DESC LIMIT 10`,
        [userId],
      ),
    ]);
    return { ...rows[0], bans, reportsAgainst, recentMatches, isBanned: bans.some((ban) => !ban.liftedAt && (!ban.expiresAt || new Date(`${ban.expiresAt}Z`) > new Date())) };
  }

  async updateUser(admin: { id: string; role: string }, userId: string, dto: UpdateUserAdminDto) {
    const before = await this.mysql.query<RowDataPacket[]>(`SELECT id, role, status FROM users WHERE id = ?`, [userId]);
    if (!before[0]) throw notFound('User not found.');
    if (userId === admin.id && (dto.role && dto.role !== before[0].role)) throw forbidden('An admin cannot change their own role.');
    const fields: string[] = []; const values: unknown[] = [];
    if (dto.status) { fields.push('status = ?'); values.push(dto.status); }
    if (dto.role) { fields.push('role = ?'); values.push(dto.role); }
    if (!fields.length) throw invalid('No change was supplied.');
    if (dto.role && before[0].role === 'admin' && dto.role !== 'admin') await this.assertNotLastAdmin(userId);
    await this.mysql.execute(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, [...values, userId]);
    const after = await this.mysql.query<RowDataPacket[]>(`SELECT id, role, status FROM users WHERE id = ?`, [userId]);
    await this.audit(admin.id, 'user.update', 'user', userId, before[0], after[0]);
    return after[0];
  }

  async banUser(adminId: string, userId: string, dto: BanUserDto) {
    const target = await this.mysql.query<RowDataPacket[]>(`SELECT id, role, status FROM users WHERE id = ?`, [userId]);
    if (!target[0]) throw notFound('User not found.');
    if (userId === adminId) throw forbidden('An admin cannot ban their own account.');
    if (target[0].role === 'admin') throw forbidden('Admin accounts cannot be banned. Demote the account first.');
    const id = randomUUID();
    await this.mysql.transaction(async (connection) => {
      await connection.execute(
        `INSERT INTO user_bans (id, user_id, issued_by, reason, expires_at) VALUES (?, ?, ?, ?, ${dto.durationHours ? 'UTC_TIMESTAMP(3) + INTERVAL ? HOUR' : 'NULL'})`,
        dto.durationHours ? [id, userId, adminId, dto.reason, dto.durationHours] : [id, userId, adminId, dto.reason],
      );
      await connection.execute(`UPDATE users SET status = 'suspended' WHERE id = ?`, [userId]);
      await connection.execute(`UPDATE refresh_sessions SET revoked_at = UTC_TIMESTAMP(3) WHERE user_id = ? AND revoked_at IS NULL`, [userId]);
    });
    await this.audit(adminId, 'user.ban', 'user', userId, target[0], { banId: id, reason: dto.reason, durationHours: dto.durationHours ?? null });
    return { success: true, banId: id, status: 'suspended' as const };
  }

  async unbanUser(adminId: string, userId: string, dto: UnbanUserDto) {
    const target = await this.mysql.query<RowDataPacket[]>(`SELECT id, status FROM users WHERE id = ?`, [userId]);
    if (!target[0]) throw notFound('User not found.');
    if (target[0].status === 'deleted') throw conflict('A deleted account cannot be reinstated.');
    await this.mysql.transaction(async (connection) => {
      await connection.execute(
        `UPDATE user_bans SET lifted_at = UTC_TIMESTAMP(3), lifted_by = ?, lift_reason = ? WHERE user_id = ? AND lifted_at IS NULL`,
        [adminId, dto.reason ?? null, userId],
      );
      await connection.execute(`UPDATE users SET status = 'active' WHERE id = ?`, [userId]);
    });
    await this.audit(adminId, 'user.unban', 'user', userId, target[0], { status: 'active', reason: dto.reason ?? null });
    return { success: true, status: 'active' as const };
  }

  /** Grants or removes currency with a ledger entry so the economy stays auditable. */
  async adjustWallet(adminId: string, userId: string, dto: AdjustWalletDto) {
    if (!dto.amount) throw invalid('The adjustment amount cannot be zero.');
    const balance = await this.mysql.transaction(async (connection) => {
      const [target] = await connection.query<RowDataPacket[]>(`SELECT id FROM users WHERE id = ? FOR UPDATE`, [userId]);
      if (!target[0]) throw notFound('User not found.');
      await connection.execute(`INSERT IGNORE INTO wallets (user_id) VALUES (?)`, [userId]);
      const [wallet] = await connection.query<RowDataPacket[]>(`SELECT coins, pips FROM wallets WHERE user_id = ? FOR UPDATE`, [userId]);
      const current = Number(wallet[0][dto.currency]);
      const next = current + dto.amount;
      if (next < 0) throw invalid('The adjustment would take the balance below zero.');
      await connection.execute(`UPDATE wallets SET ${dto.currency} = ? WHERE user_id = ?`, [next, userId]);
      await connection.execute(
        `INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id, metadata)
         VALUES (?, ?, ?, ?, ?, 'admin_adjustment', 'admin', ?, ?)`,
        [randomUUID(), userId, dto.currency, dto.amount, next, adminId, JSON.stringify({ reason: dto.reason })],
      );
      return next;
    });
    await this.audit(adminId, 'user.wallet.adjust', 'user', userId, null, { ...dto, balanceAfter: balance });
    return { success: true, currency: dto.currency, balanceAfter: balance };
  }

  // --------------------------------------------------------------------- shop

  async shop(query = '', category?: string) {
    const params: unknown[] = []; const conditions = ['1 = 1'];
    if (query.trim()) { conditions.push('(name LIKE ? OR sku LIKE ?)'); const term = `%${query.trim()}%`; params.push(term, term); }
    if (category) { conditions.push('category = ?'); params.push(category); }
    return this.mysql.query<RowDataPacket[]>(
      `SELECT si.id, si.sku, si.name, si.description, si.category, si.price_coins AS priceCoins, si.price_pips AS pricePips,
              si.asset_key AS assetKey, si.is_active AS isActive, si.stock, si.is_limited AS isLimited, si.is_giftable AS isGiftable,
              si.created_at AS createdAt,
              (SELECT COALESCE(SUM(quantity), 0) FROM inventory_items ii WHERE ii.shop_item_id = si.id) AS owned
       FROM shop_items si WHERE ${conditions.join(' AND ')} ORDER BY si.created_at DESC`,
      params,
    );
  }

  async createShop(adminId: string, dto: CreateShopItemDto) {
    if (dto.priceCoins === 0 && dto.pricePips === 0) throw invalid('An item must have a coin or pip price.');
    const existing = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM shop_items WHERE sku = ?`, [dto.sku]);
    if (existing[0]) throw conflict('A shop item with this SKU already exists.');
    const id = randomUUID();
    await this.mysql.execute(
      `INSERT INTO shop_items (id, sku, name, description, category, price_coins, price_pips, asset_key, stock, is_limited, is_giftable, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [id, dto.sku, dto.name, dto.description, dto.category, dto.priceCoins, dto.pricePips, dto.assetKey, dto.stock ?? null, dto.isLimited ?? false, dto.isGiftable ?? true, dto.isActive ?? true],
    );
    await this.audit(adminId, 'shop.create', 'shop_item', id, null, dto);
    return { id, ...dto };
  }

  async updateShop(adminId: string, itemId: string, dto: UpdateShopItemDto) {
    const before = await this.mysql.query<RowDataPacket[]>(
      `SELECT id, sku, name, description, category, price_coins AS priceCoins, price_pips AS pricePips, asset_key AS assetKey, stock, is_limited AS isLimited, is_giftable AS isGiftable, is_active AS isActive FROM shop_items WHERE id = ?`,
      [itemId],
    );
    if (!before[0]) throw notFound('Shop item not found.');
    const columns: Record<string, unknown> = {
      name: dto.name, description: dto.description, category: dto.category,
      price_coins: dto.priceCoins, price_pips: dto.pricePips, asset_key: dto.assetKey,
      stock: dto.stock, is_limited: dto.isLimited, is_giftable: dto.isGiftable, is_active: dto.isActive,
    };
    const fields: string[] = []; const values: unknown[] = [];
    for (const [column, value] of Object.entries(columns)) if (value !== undefined) { fields.push(`${column} = ?`); values.push(value); }
    if (!fields.length) throw invalid('No change was supplied.');
    const priceCoins = dto.priceCoins ?? Number(before[0].priceCoins);
    const pricePips = dto.pricePips ?? Number(before[0].pricePips);
    if (priceCoins === 0 && pricePips === 0) throw invalid('An item must have a coin or pip price.');
    await this.mysql.execute(`UPDATE shop_items SET ${fields.join(', ')} WHERE id = ?`, [...values, itemId]);
    await this.audit(adminId, 'shop.update', 'shop_item', itemId, before[0], dto);
    return { success: true };
  }

  async toggleShop(adminId: string, itemId: string, dto: ToggleDto) {
    const result = await this.mysql.execute(`UPDATE shop_items SET is_active = ? WHERE id = ?`, [dto.isActive, itemId]);
    if (!result.affectedRows) throw notFound('Shop item not found.');
    await this.audit(adminId, 'shop.toggle', 'shop_item', itemId, null, dto);
    return { success: true };
  }

  /**
   * Items that were already purchased or gifted are retired instead of deleted so
   * inventories and the ledger keep referring to a row that still exists.
   */
  async deleteShop(adminId: string, itemId: string) {
    const item = await this.mysql.query<RowDataPacket[]>(`SELECT id, sku, name FROM shop_items WHERE id = ?`, [itemId]);
    if (!item[0]) throw notFound('Shop item not found.');
    const [owned] = await this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM inventory_items WHERE shop_item_id = ?`, [itemId]);
    if (Number(owned?.total ?? 0) > 0) {
      await this.mysql.execute(`UPDATE shop_items SET is_active = FALSE WHERE id = ?`, [itemId]);
      await this.audit(adminId, 'shop.retire', 'shop_item', itemId, item[0], { isActive: false, reason: 'owned_by_players' });
      return { success: true, deleted: false, retired: true, message: 'Players own this item, so it was retired from the catalogue instead of deleted.' };
    }
    await this.mysql.execute(`DELETE FROM shop_items WHERE id = ?`, [itemId]);
    await this.audit(adminId, 'shop.delete', 'shop_item', itemId, item[0], null);
    return { success: true, deleted: true, retired: false };
  }

  // -------------------------------------------------------------------- games

  async games() {
    return this.mysql.query<RowDataPacket[]>(
      `SELECT g.id, g.display_name AS displayName, g.category, g.min_players AS minPlayers, g.max_players AS maxPlayers,
              g.supports_teams AS supportsTeams, g.is_active AS isActive, g.accent_color AS accentColor, g.icon_key AS iconKey, g.config,
              (SELECT COUNT(*) FROM matches m WHERE m.game_id = g.id AND m.status = 'active') AS liveMatches,
              (SELECT COUNT(*) FROM matches m WHERE m.game_id = g.id AND m.created_at >= UTC_TIMESTAMP(3) - INTERVAL 7 DAY) AS matchesThisWeek
       FROM games g ORDER BY g.display_name`,
    );
  }

  async updateGame(adminId: string, gameId: string, dto: UpdateGameDto) {
    const before = await this.mysql.query<RowDataPacket[]>(
      `SELECT id, display_name AS displayName, min_players AS minPlayers, max_players AS maxPlayers, is_active AS isActive FROM games WHERE id = ?`,
      [gameId],
    );
    if (!before[0]) throw notFound('Game not found.');
    const minPlayers = dto.minPlayers ?? Number(before[0].minPlayers);
    const maxPlayers = dto.maxPlayers ?? Number(before[0].maxPlayers);
    if (maxPlayers < minPlayers) throw invalid('The maximum player count must be at least the minimum.');
    const columns: Record<string, unknown> = { display_name: dto.displayName, min_players: dto.minPlayers, max_players: dto.maxPlayers, is_active: dto.isActive };
    const fields: string[] = []; const values: unknown[] = [];
    for (const [column, value] of Object.entries(columns)) if (value !== undefined) { fields.push(`${column} = ?`); values.push(value); }
    if (!fields.length) throw invalid('No change was supplied.');
    await this.mysql.execute(`UPDATE games SET ${fields.join(', ')} WHERE id = ?`, [...values, gameId]);
    if (dto.isActive === false) await this.cancelQueueFor(gameId);
    await this.audit(adminId, 'game.update', 'game', gameId, before[0], dto);
    return { success: true };
  }

  async toggleGame(adminId: string, gameId: string, dto: ToggleDto) {
    const result = await this.mysql.execute(`UPDATE games SET is_active = ? WHERE id = ?`, [dto.isActive, gameId]);
    if (!result.affectedRows) throw notFound('Game not found.');
    if (!dto.isActive) await this.cancelQueueFor(gameId);
    await this.audit(adminId, 'game.toggle', 'game', gameId, null, dto);
    return { success: true };
  }

  async bulkToggleGames(adminId: string, dto: BulkToggleGamesDto) {
    if (!dto.gameIds.length) throw invalid('Select at least one game.');
    const placeholders = dto.gameIds.map(() => '?').join(', ');
    const result = await this.mysql.execute(`UPDATE games SET is_active = ? WHERE id IN (${placeholders})`, [dto.isActive, ...dto.gameIds]);
    if (!dto.isActive) for (const gameId of dto.gameIds) await this.cancelQueueFor(gameId);
    await this.audit(adminId, 'game.bulk_toggle', 'game', dto.gameIds.join(','), null, dto);
    return { success: true, updated: result.affectedRows };
  }

  /** A disabled game must not leave players waiting in a queue that can never match. */
  private async cancelQueueFor(gameId: string): Promise<void> {
    await this.mysql.execute(`UPDATE matchmaking_tickets SET status = 'cancelled' WHERE game_id = ? AND status = 'queued'`, [gameId]).catch(() => undefined);
  }

  // ------------------------------------------------------------------ reports

  async reports(status?: string, category?: string, page = 0) {
    const params: unknown[] = []; const conditions = ['1 = 1'];
    if (status) { conditions.push('r.status = ?'); params.push(status); }
    if (category) { conditions.push('r.category = ?'); params.push(category); }
    const where = conditions.join(' AND ');
    const [total] = await this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM reports r WHERE ${where}`, params);
    const items = await this.mysql.query<RowDataPacket[]>(
      `SELECT r.id, r.category, r.description, r.status, r.resolution_note AS resolutionNote, r.created_at AS createdAt, r.resolved_at AS resolvedAt,
              r.match_id AS matchId,
              reporter.id AS reporterId, reporter.display_name AS reporterName,
              reported.id AS reportedUserId, reported.display_name AS reportedUserName, reported.status AS reportedUserStatus,
              resolver.display_name AS resolvedByName,
              (SELECT COUNT(*) FROM reports prior WHERE prior.reported_user_id = r.reported_user_id) AS reportedUserTotalReports,
              (SELECT COUNT(*) FROM report_notes n WHERE n.report_id = r.id) AS noteCount
       FROM reports r
       JOIN users reporter ON reporter.id = r.reporter_id
       LEFT JOIN users reported ON reported.id = r.reported_user_id
       LEFT JOIN users resolver ON resolver.id = r.resolved_by
       WHERE ${where}
       ORDER BY FIELD(r.status, 'open', 'investigating', 'resolved', 'dismissed'), r.created_at DESC
       LIMIT ? OFFSET ?`,
      [...params, PAGE_SIZE, Math.max(page, 0) * PAGE_SIZE],
    );
    return { page: Math.max(page, 0), pageSize: PAGE_SIZE, total: Number(total?.total ?? 0), items };
  }

  async reportNotes(reportId: string) {
    return this.mysql.query<RowDataPacket[]>(
      `SELECT n.id, n.body, n.created_at AS createdAt, u.display_name AS authorName FROM report_notes n JOIN users u ON u.id = n.author_id WHERE n.report_id = ? ORDER BY n.created_at`,
      [reportId],
    );
  }

  async addReportNote(adminId: string, reportId: string, dto: CreateReportNoteDto) {
    const report = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM reports WHERE id = ?`, [reportId]);
    if (!report[0]) throw notFound('Report not found.');
    const id = randomUUID();
    await this.mysql.execute(`INSERT INTO report_notes (id, report_id, author_id, body) VALUES (?, ?, ?, ?)`, [id, reportId, adminId, dto.body]);
    await this.audit(adminId, 'report.note', 'report', reportId, null, dto);
    return { id, reportId, body: dto.body };
  }

  async resolveReport(adminId: string, reportId: string, dto: ResolveReportDto) {
    const report = await this.mysql.query<RowDataPacket[]>(`SELECT id, status, reported_user_id AS reportedUserId FROM reports WHERE id = ?`, [reportId]);
    if (!report[0]) throw notFound('Report not found.');
    const closing = dto.status === 'resolved' || dto.status === 'dismissed';
    await this.mysql.execute(
      `UPDATE reports SET status = ?, resolution_note = ?, resolved_by = ?, resolved_at = ${closing ? 'UTC_TIMESTAMP(3)' : 'NULL'} WHERE id = ?`,
      [dto.status, dto.resolutionNote ?? null, closing ? adminId : null, reportId],
    );
    let moderation: unknown = null;
    const action = dto.action ?? 'none';
    if (action !== 'none') {
      if (!report[0].reportedUserId) throw invalid('This report has no reported account to action.');
      const userId = String(report[0].reportedUserId);
      if (action === 'unban') moderation = await this.unbanUser(adminId, userId, { reason: `Report ${reportId}` });
      else if (action === 'suspend') moderation = await this.banUser(adminId, userId, { reason: dto.resolutionNote ?? `Report ${reportId}`, durationHours: dto.banDurationHours ?? 24 });
      else moderation = await this.banUser(adminId, userId, { reason: dto.resolutionNote ?? `Report ${reportId}`, durationHours: dto.banDurationHours });
    }
    await this.audit(adminId, 'report.resolve', 'report', reportId, report[0], dto);
    return { success: true, status: dto.status, moderation };
  }

  // ------------------------------------------------------------------ seasons

  async seasons() {
    return this.mysql.query<RowDataPacket[]>(
      `SELECT s.id, s.name, s.starts_at AS startsAt, s.ends_at AS endsAt, s.status, s.created_at AS createdAt,
              (SELECT COUNT(*) FROM season_rewards sr WHERE sr.season_id = s.id) AS rewardCount,
              (SELECT COUNT(DISTINCT pr.user_id) FROM player_ratings pr WHERE pr.season_id = s.id) AS participants
       FROM seasons s ORDER BY s.starts_at DESC`,
    );
  }

  async createSeason(adminId: string, dto: CreateSeasonDto) {
    const startsAt = new Date(dto.startsAt); const endsAt = new Date(dto.endsAt);
    if (!Number.isFinite(startsAt.getTime()) || !Number.isFinite(endsAt.getTime()) || endsAt <= startsAt) throw invalid('Season dates are invalid.');
    const id = randomUUID();
    await this.mysql.execute(`INSERT INTO seasons (id, name, starts_at, ends_at, status) VALUES (?, ?, ?, ?, 'scheduled')`, [id, dto.name, startsAt, endsAt]);
    await this.audit(adminId, 'season.create', 'season', id, null, dto);
    return { id, ...dto, status: 'scheduled' };
  }

  async updateSeason(adminId: string, seasonId: string, dto: UpdateSeasonDto) {
    const before = await this.mysql.query<RowDataPacket[]>(`SELECT id, name, starts_at AS startsAt, ends_at AS endsAt, status FROM seasons WHERE id = ?`, [seasonId]);
    if (!before[0]) throw notFound('Season not found.');
    if (before[0].status === 'finished') throw conflict('A finished season can no longer be edited.');
    const startsAt = dto.startsAt ? new Date(dto.startsAt) : new Date(`${before[0].startsAt}Z`);
    const endsAt = dto.endsAt ? new Date(dto.endsAt) : new Date(`${before[0].endsAt}Z`);
    if (!Number.isFinite(startsAt.getTime()) || !Number.isFinite(endsAt.getTime()) || endsAt <= startsAt) throw invalid('Season dates are invalid.');
    await this.mysql.execute(`UPDATE seasons SET name = ?, starts_at = ?, ends_at = ? WHERE id = ?`, [dto.name ?? before[0].name, startsAt, endsAt, seasonId]);
    await this.audit(adminId, 'season.update', 'season', seasonId, before[0], dto);
    return { success: true };
  }

  async activateSeason(adminId: string, seasonId: string) {
    const result = await this.mysql.transaction(async (connection) => {
      await connection.execute(`UPDATE seasons SET status = 'finished' WHERE status = 'active' AND id <> ?`, [seasonId]);
      const [update] = await connection.execute<ResultSetHeader>(`UPDATE seasons SET status = 'active' WHERE id = ? AND status IN ('scheduled','active')`, [seasonId]);
      return update;
    });
    if (!result.affectedRows) throw notFound('Season not found or already finished.');
    await this.audit(adminId, 'season.activate', 'season', seasonId, null, { status: 'active' });
    return { success: true };
  }

  async rewards(seasonId: string) {
    return this.mysql.query<RowDataPacket[]>(
      `SELECT sr.id, sr.min_rank AS minRank, sr.max_rank AS maxRank, sr.coins, sr.pips, sr.shop_item_id AS shopItemId, si.name AS shopItemName
       FROM season_rewards sr LEFT JOIN shop_items si ON si.id = sr.shop_item_id WHERE sr.season_id = ? ORDER BY sr.min_rank`,
      [seasonId],
    );
  }

  async createReward(adminId: string, seasonId: string, dto: CreateSeasonRewardDto) {
    if (dto.maxRank < dto.minRank || (dto.coins === 0 && dto.pips === 0 && !dto.shopItemId)) throw invalid('A reward needs a valid rank range and at least one reward.');
    const season = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM seasons WHERE id = ?`, [seasonId]);
    if (!season[0]) throw notFound('Season not found.');
    const overlap = await this.mysql.query<RowDataPacket[]>(
      `SELECT id FROM season_rewards WHERE season_id = ? AND min_rank <= ? AND max_rank >= ? LIMIT 1`,
      [seasonId, dto.maxRank, dto.minRank],
    );
    if (overlap[0]) throw conflict('Another reward already covers part of this rank range.');
    const id = randomUUID();
    await this.mysql.execute(
      `INSERT INTO season_rewards (id, season_id, min_rank, max_rank, coins, pips, shop_item_id) VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, seasonId, dto.minRank, dto.maxRank, dto.coins, dto.pips, dto.shopItemId ?? null],
    );
    await this.audit(adminId, 'season.reward.create', 'season_reward', id, null, dto);
    return { id, seasonId, ...dto };
  }

  async deleteReward(adminId: string, rewardId: string) {
    const result = await this.mysql.execute(`DELETE FROM season_rewards WHERE id = ?`, [rewardId]);
    if (!result.affectedRows) throw notFound('Season reward not found.');
    await this.audit(adminId, 'season.reward.delete', 'season_reward', rewardId, null, null);
    return { success: true };
  }

  async finishSeason(adminId: string, seasonId: string) {
    const season = await this.mysql.query<RowDataPacket[]>(`SELECT id, status FROM seasons WHERE id = ?`, [seasonId]);
    if (!season[0]) throw notFound('Season not found.');
    if (season[0].status !== 'active') throw conflict('Only an active season can be finished.');
    await this.ranking.finishSeason(seasonId);
    await this.audit(adminId, 'season.finish', 'season', seasonId, season[0], { status: 'finished' });
    return { success: true };
  }

  // ---------------------------------------------------------------- audit log

  async auditLog(page = 0, action?: string) {
    const params: unknown[] = []; const where = action ? 'WHERE a.action = ?' : '';
    if (action) params.push(action);
    return this.mysql.query<RowDataPacket[]>(
      `SELECT a.id, a.action, a.entity_type AS entityType, a.entity_id AS entityId, a.before_json AS before, a.after_json AS after,
              a.created_at AS createdAt, u.display_name AS adminName
       FROM admin_audit_log a JOIN users u ON u.id = a.admin_id ${where}
       ORDER BY a.created_at DESC LIMIT ? OFFSET ?`,
      [...params, PAGE_SIZE * 2, Math.max(page, 0) * PAGE_SIZE * 2],
    );
  }

  private async assertNotLastAdmin(userId: string): Promise<void> {
    const [row] = await this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM users WHERE role = 'admin' AND status = 'active' AND id <> ?`, [userId]);
    if (Number(row?.total ?? 0) === 0) throw forbidden('At least one active admin must remain.');
  }

  private numeric(row: RowDataPacket | undefined): Record<string, unknown> {
    if (!row) return {};
    return Object.fromEntries(Object.entries(row).map(([key, value]) => [key, typeof value === 'string' && /^-?\d+$/.test(value) ? Number(value) : value === null ? 0 : value]));
  }

  private async audit(adminId: string, action: string, entityType: string, entityId: string, before: unknown, after: unknown) {
    await this.mysql.execute(
      `INSERT INTO admin_audit_log (admin_id, action, entity_type, entity_id, before_json, after_json) VALUES (?, ?, ?, ?, ?, ?)`,
      [adminId, action, entityType, entityId, before ? JSON.stringify(before) : null, after ? JSON.stringify(after) : null],
    );
  }
}
