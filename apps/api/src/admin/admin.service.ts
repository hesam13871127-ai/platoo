import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { invalid, notFound } from '../common/errors';
import { CreateSeasonDto, CreateSeasonRewardDto, CreateShopItemDto, ResolveReportDto, ToggleDto, UpdateUserAdminDto } from './admin.dto';
import { RankingService } from '../ranking/ranking.service';

@Injectable()
export class AdminService {
  constructor(private readonly mysql: MysqlService, private readonly ranking: RankingService) {}

  async overview() {
    const [users, matches, reports, revenue] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total, SUM(status = 'active') AS active, SUM(status = 'suspended') AS suspended FROM users`),
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total, SUM(status = 'active') AS active, SUM(status = 'finished') AS finished FROM matches`),
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total, SUM(status = 'open') AS open FROM reports`),
      this.mysql.query<RowDataPacket[]>(`SELECT COALESCE(SUM(amount_minor), 0) AS amountMinor FROM purchases WHERE status = 'paid'`),
    ]);
    return { users: users[0], matches: matches[0], reports: reports[0], revenue: { amountMinor: Number(revenue[0]?.amountMinor ?? 0) } };
  }

  async users(query = '', status?: string, page = 0) {
    const params: unknown[] = []; const conditions = ['1 = 1'];
    if (query.trim()) { conditions.push('(u.username LIKE ? OR u.display_name LIKE ? OR u.phone_e164 LIKE ?)'); const term = `%${query.trim()}%`; params.push(term, term, term); }
    if (status) { conditions.push('u.status = ?'); params.push(status); }
    params.push(50, Math.max(page, 0) * 50);
    return this.mysql.query<RowDataPacket[]>(`SELECT u.id, u.username, u.display_name AS displayName, u.phone_e164 AS phone, u.email, u.role, u.status, u.level, u.created_at AS createdAt, u.last_seen_at AS lastSeenAt, COALESCE(w.coins, 0) AS coins, COALESCE(w.pips, 0) AS pips FROM users u LEFT JOIN wallets w ON w.user_id = u.id WHERE ${conditions.join(' AND ')} ORDER BY u.created_at DESC LIMIT ? OFFSET ?`, params);
  }

  async updateUser(adminId: string, userId: string, dto: UpdateUserAdminDto) {
    const before = await this.mysql.query<RowDataPacket[]>(`SELECT id, role, status FROM users WHERE id = ?`, [userId]);
    if (!before[0]) throw notFound('User not found.');
    const fields: string[] = []; const values: unknown[] = [];
    if (dto.status) { fields.push('status = ?'); values.push(dto.status); }
    if (dto.role) { fields.push('role = ?'); values.push(dto.role); }
    if (!fields.length) throw invalid('No change was supplied.');
    await this.mysql.execute(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, [...values, userId]);
    const after = await this.mysql.query<RowDataPacket[]>(`SELECT id, role, status FROM users WHERE id = ?`, [userId]);
    await this.audit(adminId, 'user.update', 'user', userId, before[0], after[0]);
    return after[0];
  }

  async shop() { return this.mysql.query<RowDataPacket[]>(`SELECT id, sku, name, description, category, price_coins AS priceCoins, price_pips AS pricePips, asset_key AS assetKey, is_active AS isActive, stock, is_giftable AS isGiftable, created_at AS createdAt FROM shop_items ORDER BY created_at DESC`); }

  async createShop(adminId: string, dto: CreateShopItemDto) {
    if (dto.priceCoins === 0 && dto.pricePips === 0) throw invalid('An item must have a coin or pip price.');
    const id = randomUUID();
    await this.mysql.execute(`INSERT INTO shop_items (id, sku, name, description, category, price_coins, price_pips, asset_key, stock, is_giftable) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, [id, dto.sku, dto.name, dto.description, dto.category, dto.priceCoins, dto.pricePips, dto.assetKey, dto.stock ?? null, dto.isGiftable ?? true]);
    await this.audit(adminId, 'shop.create', 'shop_item', id, null, dto);
    return { id, ...dto };
  }

  async toggleShop(adminId: string, itemId: string, dto: ToggleDto) {
    const result = await this.mysql.execute(`UPDATE shop_items SET is_active = ? WHERE id = ?`, [dto.isActive, itemId]);
    if (!result.affectedRows) throw notFound('Shop item not found.');
    await this.audit(adminId, 'shop.toggle', 'shop_item', itemId, null, dto);
    return { success: true };
  }

  async games() { return this.mysql.query<RowDataPacket[]>(`SELECT id, display_name AS displayName, category, min_players AS minPlayers, max_players AS maxPlayers, supports_teams AS supportsTeams, is_active AS isActive, config FROM games ORDER BY display_name`); }

  async toggleGame(adminId: string, gameId: string, dto: ToggleDto) {
    const result = await this.mysql.execute(`UPDATE games SET is_active = ? WHERE id = ?`, [dto.isActive, gameId]);
    if (!result.affectedRows) throw notFound('Game not found.');
    await this.audit(adminId, 'game.toggle', 'game', gameId, null, dto);
    return { success: true };
  }

  async reports(status?: string) {
    const params: unknown[] = []; const where = status ? 'WHERE r.status = ?' : ''; if (status) params.push(status);
    return this.mysql.query<RowDataPacket[]>(`SELECT r.id, r.category, r.description, r.status, r.resolution_note AS resolutionNote, r.created_at AS createdAt, reporter.id AS reporterId, reporter.display_name AS reporterName, reported.id AS reportedUserId, reported.display_name AS reportedUserName FROM reports r JOIN users reporter ON reporter.id = r.reporter_id LEFT JOIN users reported ON reported.id = r.reported_user_id ${where} ORDER BY r.created_at DESC LIMIT 200`, params);
  }

  async resolveReport(adminId: string, reportId: string, dto: ResolveReportDto) {
    const result = await this.mysql.execute(`UPDATE reports SET status = ?, resolution_note = ?, resolved_by = ?, resolved_at = IF(? IN ('resolved','dismissed'), UTC_TIMESTAMP(3), NULL) WHERE id = ?`, [dto.status, dto.resolutionNote ?? null, adminId, dto.status, reportId]);
    if (!result.affectedRows) throw notFound('Report not found.');
    await this.audit(adminId, 'report.resolve', 'report', reportId, null, dto);
    return { success: true, status: dto.status };
  }

  async seasons() { return this.mysql.query<RowDataPacket[]>(`SELECT id, name, starts_at AS startsAt, ends_at AS endsAt, status, created_at AS createdAt FROM seasons ORDER BY starts_at DESC`); }

  async createSeason(adminId: string, dto: CreateSeasonDto) {
    const startsAt = new Date(dto.startsAt); const endsAt = new Date(dto.endsAt);
    if (!Number.isFinite(startsAt.getTime()) || !Number.isFinite(endsAt.getTime()) || endsAt <= startsAt) throw invalid('Season dates are invalid.');
    const id = randomUUID(); await this.mysql.execute(`INSERT INTO seasons (id, name, starts_at, ends_at, status) VALUES (?, ?, ?, ?, 'scheduled')`, [id, dto.name, startsAt, endsAt]); await this.audit(adminId, 'season.create', 'season', id, null, dto); return { id, ...dto, status: 'scheduled' };
  }

  async activateSeason(adminId: string, seasonId: string) {
    const result = await this.mysql.transaction(async (connection) => { await connection.execute(`UPDATE seasons SET status = 'finished' WHERE status = 'active'`); const [update] = await connection.execute<ResultSetHeader>(`UPDATE seasons SET status = 'active' WHERE id = ? AND status IN ('scheduled','active')`, [seasonId]); return update; });
    if (!result.affectedRows) throw notFound('Season not found.'); await this.audit(adminId, 'season.activate', 'season', seasonId, null, { status: 'active' }); return { success: true };
  }

  async rewards(seasonId: string) { return this.mysql.query<RowDataPacket[]>(`SELECT sr.id, sr.min_rank AS minRank, sr.max_rank AS maxRank, sr.coins, sr.pips, sr.shop_item_id AS shopItemId, si.name AS shopItemName FROM season_rewards sr LEFT JOIN shop_items si ON si.id = sr.shop_item_id WHERE sr.season_id = ? ORDER BY sr.min_rank`, [seasonId]); }

  async createReward(adminId: string, seasonId: string, dto: CreateSeasonRewardDto) {
    if (dto.maxRank < dto.minRank || (dto.coins === 0 && dto.pips === 0 && !dto.shopItemId)) throw invalid('A reward needs a valid rank range and at least one reward.');
    const season = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM seasons WHERE id = ?`, [seasonId]);
    if (!season[0]) throw notFound('Season not found.');
    const id = randomUUID();
    await this.mysql.execute(`INSERT INTO season_rewards (id, season_id, min_rank, max_rank, coins, pips, shop_item_id) VALUES (?, ?, ?, ?, ?, ?, ?)`, [id, seasonId, dto.minRank, dto.maxRank, dto.coins, dto.pips, dto.shopItemId ?? null]);
    await this.audit(adminId, 'season.reward.create', 'season_reward', id, null, dto);
    return { id, seasonId, ...dto };
  }

  async finishSeason(adminId: string, seasonId: string) { await this.ranking.finishSeason(seasonId); await this.audit(adminId, 'season.finish', 'season', seasonId, null, { status: 'finished' }); return { success: true }; }

  private async audit(adminId: string, action: string, entityType: string, entityId: string, before: unknown, after: unknown) { await this.mysql.execute(`INSERT INTO admin_audit_log (admin_id, action, entity_type, entity_id, before_json, after_json) VALUES (?, ?, ?, ?, ?, ?)`, [adminId, action, entityType, entityId, before ? JSON.stringify(before) : null, after ? JSON.stringify(after) : null]); }
}
