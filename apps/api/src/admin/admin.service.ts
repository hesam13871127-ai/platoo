import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, forbidden, invalid, notFound } from '../common/errors';
import { AdjustWalletDto, BanUserDto, CreateSeasonDto, CreateSeasonRewardDto, CreateShopItemDto, ResolveReportDto, ToggleDto, UpdateGameDto, UpdateSeasonDto, UpdateShopItemDto, UpdateUserAdminDto } from './admin.dto';
import { RankingService } from '../ranking/ranking.service';

export interface Paginated<T> { items: T[]; page: number; limit: number; total: number; totalPages: number; }

@Injectable()
export class AdminService {
  constructor(private readonly mysql: MysqlService, private readonly ranking: RankingService) {}

  // ---------------------------------------------------------------- overview & analytics

  async overview() {
    const [users, matches, reports, revenue, today, games, season] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total, SUM(status = 'active') AS active, SUM(status = 'suspended') AS suspended, SUM(status = 'deleted') AS deleted, SUM(role = 'moderator') AS moderators, SUM(role = 'admin') AS admins, SUM(status = 'active' AND last_seen_at >= DATE_SUB(UTC_TIMESTAMP(3), INTERVAL 1 DAY)) AS dau, SUM(created_at >= CURDATE()) AS newToday, SUM(created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)) AS newWeek FROM users`),
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total, SUM(status = 'waiting') AS waiting, SUM(status = 'active') AS active, SUM(status = 'finished') AS finished, SUM(created_at >= CURDATE()) AS today FROM matches`),
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total, SUM(status = 'open') AS open, SUM(status = 'investigating') AS investigating, SUM(status = 'resolved') AS resolved FROM reports`),
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS count, COALESCE(SUM(amount_minor), 0) AS amountMinor, COALESCE(SUM(created_at >= CURDATE()), 0) AS countToday, COALESCE(SUM(IF(created_at >= CURDATE(), amount_minor, 0)), 0) AS amountMinorToday FROM purchases WHERE status = 'paid'`),
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(DISTINCT mp.user_id) AS activePlayers FROM matches m JOIN match_players mp ON mp.match_id = m.id AND mp.is_bot = FALSE WHERE m.created_at >= CURDATE()`),
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total, SUM(is_active = TRUE) AS active FROM games`),
      this.mysql.query<RowDataPacket[]>(`SELECT id, name, status, ends_at AS endsAt FROM seasons WHERE status = 'active' ORDER BY starts_at DESC LIMIT 1`),
    ]);
    return {
      users: this.num(users[0], ['total', 'active', 'suspended', 'deleted', 'moderators', 'admins', 'dau', 'newToday', 'newWeek']),
      matches: this.num(matches[0], ['total', 'waiting', 'active', 'finished', 'today']),
      reports: this.num(reports[0], ['total', 'open', 'investigating', 'resolved']),
      revenue: { ...this.num(revenue[0], ['count', 'amountMinor', 'countToday', 'amountMinorToday']) },
      activity: this.num(today[0], ['activePlayers']),
      games: this.num(games[0], ['total', 'active']),
      season: season[0] ?? null,
    };
  }

  async analytics(days = 30) {
    const windowDays = Math.min(Math.max(days || 30, 7), 90);
    const [signups, matches, revenue, activePlayers, matchesByGame, reportsByStatus] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(`SELECT DATE(created_at) AS day, COUNT(*) AS value FROM users WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY) GROUP BY DATE(created_at) ORDER BY day`, [windowDays]),
      this.mysql.query<RowDataPacket[]>(`SELECT DATE(created_at) AS day, COUNT(*) AS value FROM matches WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY) GROUP BY DATE(created_at) ORDER BY day`, [windowDays]),
      this.mysql.query<RowDataPacket[]>(`SELECT DATE(created_at) AS day, COALESCE(SUM(amount_minor), 0) AS value FROM purchases WHERE status = 'paid' AND created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY) GROUP BY DATE(created_at) ORDER BY day`, [windowDays]),
      this.mysql.query<RowDataPacket[]>(`SELECT DATE(m.created_at) AS day, COUNT(DISTINCT mp.user_id) AS value FROM matches m JOIN match_players mp ON mp.match_id = m.id AND mp.is_bot = FALSE WHERE m.created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY) GROUP BY DATE(m.created_at) ORDER BY day`, [windowDays]),
      this.mysql.query<RowDataPacket[]>(`SELECT m.game_id AS gameId, g.display_name AS gameName, COUNT(*) AS matches FROM matches m JOIN games g ON g.id = m.game_id WHERE m.created_at >= DATE_SUB(CURDATE(), INTERVAL ? DAY) GROUP BY m.game_id, g.display_name ORDER BY matches DESC LIMIT 10`, [windowDays]),
      this.mysql.query<RowDataPacket[]>(`SELECT status, COUNT(*) AS value FROM reports GROUP BY status`),
    ]);
    return {
      days: windowDays,
      signupsByDay: this.series(signups),
      matchesByDay: this.series(matches),
      revenueByDay: this.series(revenue),
      activePlayersByDay: this.series(activePlayers),
      matchesByGame: matchesByGame.map((row) => ({ gameId: row.gameId, gameName: row.gameName, matches: Number(row.matches) })),
      reportsByStatus: reportsByStatus.map((row) => ({ status: row.status, value: Number(row.value) })),
    };
  }

  async recentMatches(limit = 20) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT m.id, m.game_id AS gameId, g.display_name AS gameName, m.mode, m.status, m.max_players AS maxPlayers, m.created_at AS createdAt, m.finished_at AS finishedAt, (SELECT COUNT(*) FROM match_players mp WHERE mp.match_id = m.id) AS playerCount FROM matches m JOIN games g ON g.id = m.game_id ORDER BY m.created_at DESC LIMIT ?`, [Math.min(Math.max(limit, 1), 50)]);
    return rows.map((row) => ({ ...row, maxPlayers: Number(row.maxPlayers), playerCount: Number(row.playerCount) }));
  }

  // ---------------------------------------------------------------- users

  async users(query = '', status?: string, role?: string, page = 0, limit = 20): Promise<Paginated<RowDataPacket>> {
    const safePage = Math.max(page || 0, 0);
    const safeLimit = Math.min(Math.max(limit || 20, 1), 100);
    const params: unknown[] = [];
    const conditions = ['1 = 1'];
    if (query.trim()) { conditions.push('(u.username LIKE ? OR u.display_name LIKE ? OR u.phone_e164 LIKE ? OR u.email LIKE ?)'); const term = `%${query.trim()}%`; params.push(term, term, term, term); }
    if (status) { conditions.push('u.status = ?'); params.push(status); }
    if (role) { conditions.push('u.role = ?'); params.push(role); }
    const where = conditions.join(' AND ');
    const [countRows, items] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM users u WHERE ${where}`, [...params]),
      this.mysql.query<RowDataPacket[]>(`SELECT u.id, u.username, u.display_name AS displayName, u.phone_e164 AS phone, u.email, u.role, u.status, u.level, u.experience, u.created_at AS createdAt, u.last_seen_at AS lastSeenAt, COALESCE(w.coins, 0) AS coins, COALESCE(w.pips, 0) AS pips FROM users u LEFT JOIN wallets w ON w.user_id = u.id WHERE ${where} ORDER BY u.created_at DESC LIMIT ? OFFSET ?`, [...params, safeLimit, safePage * safeLimit]),
    ]);
    const total = Number(countRows[0]?.total ?? 0);
    return { items: items.map((row) => ({ ...row, level: Number(row.level), experience: Number(row.experience), coins: Number(row.coins), pips: Number(row.pips) })), page: safePage, limit: safeLimit, total, totalPages: Math.ceil(total / safeLimit) };
  }

  async userDetail(userId: string) {
    const users = await this.mysql.query<RowDataPacket[]>(`SELECT u.id, u.username, u.display_name AS displayName, u.phone_e164 AS phone, u.email, u.avatar_url AS avatarUrl, u.locale, u.theme, u.role, u.status, u.level, u.experience, u.created_at AS createdAt, u.last_seen_at AS lastSeenAt, COALESCE(w.coins, 0) AS coins, COALESCE(w.pips, 0) AS pips FROM users u LEFT JOIN wallets w ON w.user_id = u.id WHERE u.id = ?`, [userId]);
    if (!users[0]) throw notFound('User not found.');
    const [recentMatches, reportsAgainst, reportsFiled, counts] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(`SELECT m.id, m.game_id AS gameId, g.display_name AS gameName, m.mode, m.status, mp.result, m.created_at AS createdAt FROM matches m JOIN match_players mp ON mp.match_id = m.id AND mp.user_id = ? JOIN games g ON g.id = m.game_id ORDER BY m.created_at DESC LIMIT 10`, [userId]),
      this.mysql.query<RowDataPacket[]>(`SELECT r.id, r.category, r.status, r.created_at AS createdAt, reporter.display_name AS reporterName FROM reports r JOIN users reporter ON reporter.id = r.reporter_id WHERE r.reported_user_id = ? ORDER BY r.created_at DESC LIMIT 20`, [userId]),
      this.mysql.query<RowDataPacket[]>(`SELECT r.id, r.category, r.status, r.created_at AS createdAt, reported.display_name AS reportedUserName FROM reports r LEFT JOIN users reported ON reported.id = r.reported_user_id WHERE r.reporter_id = ? ORDER BY r.created_at DESC LIMIT 20`, [userId]),
      this.mysql.query<RowDataPacket[]>(`SELECT (SELECT COUNT(*) FROM inventory_items WHERE user_id = ?) AS inventoryItems, (SELECT COUNT(*) FROM friendships WHERE (requester_id = ? OR addressee_id = ?) AND status = 'accepted') AS friends, (SELECT COUNT(*) FROM match_players WHERE user_id = ?) AS matchesPlayed`, [userId, userId, userId, userId]),
    ]);
    return { user: { ...users[0], level: Number(users[0].level), experience: Number(users[0].experience), coins: Number(users[0].coins), pips: Number(users[0].pips) }, recentMatches, reportsAgainst, reportsFiled, stats: this.num(counts[0], ['inventoryItems', 'friends', 'matchesPlayed']) };
  }

  async updateUser(adminId: string, userId: string, dto: UpdateUserAdminDto) {
    const before = await this.mysql.query<RowDataPacket[]>(`SELECT id, username, role, status FROM users WHERE id = ?`, [userId]);
    if (!before[0]) throw notFound('User not found.');
    if (!dto.status && !dto.role) throw invalid('No change was supplied.');
    if (userId === adminId) {
      if (dto.status && dto.status !== 'active') throw invalid('You cannot suspend or delete your own account.');
      if (dto.role && dto.role !== before[0].role) throw invalid('You cannot change your own role. Ask another admin.');
    }
    if (dto.role && before[0].role === 'admin' && dto.role !== 'admin') await this.ensureNotLastAdmin(userId);
    if (dto.status && dto.status === 'suspended' && before[0].status !== 'suspended' && before[0].role === 'admin') {
      throw forbidden('Admin accounts cannot be suspended. Demote the account first.');
    }
    await this.mysql.transaction(async (connection) => {
      const fields: string[] = []; const values: string[] = [];
      if (dto.status) { fields.push('status = ?'); values.push(dto.status); }
      if (dto.role) { fields.push('role = ?'); values.push(dto.role); }
      await connection.execute(`UPDATE users SET ${fields.join(', ')} WHERE id = ?`, [...values, userId]);
      if (dto.status === 'suspended') {
        await connection.execute(`UPDATE refresh_sessions SET revoked_at = UTC_TIMESTAMP(3) WHERE user_id = ? AND revoked_at IS NULL`, [userId]);
        await connection.execute(`INSERT INTO notifications (id, user_id, type, title, body) VALUES (?, ?, 'moderation', 'Account suspended', 'Your account was suspended by moderation. Contact support if you think this is a mistake.')`, [randomUUID(), userId]);
      }
    });
    const after = await this.mysql.query<RowDataPacket[]>(`SELECT id, username, role, status FROM users WHERE id = ?`, [userId]);
    await this.audit(adminId, 'user.update', 'user', userId, before[0], after[0]);
    return after[0];
  }

  async banUser(adminId: string, userId: string, dto: BanUserDto) {
    const target = await this.mysql.query<RowDataPacket[]>(`SELECT id, username, role, status FROM users WHERE id = ?`, [userId]);
    if (!target[0]) throw notFound('User not found.');
    if (userId === adminId) throw invalid('You cannot ban your own account.');
    if (target[0].role === 'admin') throw forbidden('Admin accounts cannot be banned. Demote the account first.');
    if (target[0].status === 'suspended') return { ...target[0], alreadyBanned: true };
    const reason = dto.reason?.trim() || 'Violation of community rules.';
    await this.mysql.transaction(async (connection) => {
      await connection.execute(`UPDATE users SET status = 'suspended' WHERE id = ?`, [userId]);
      await connection.execute(`UPDATE refresh_sessions SET revoked_at = UTC_TIMESTAMP(3) WHERE user_id = ? AND revoked_at IS NULL`, [userId]);
      await connection.execute(`INSERT INTO notifications (id, user_id, type, title, body) VALUES (?, ?, 'moderation', 'Account suspended', ?)`, [randomUUID(), userId, `Your account was suspended by moderation: ${reason}`]);
    });
    const after = await this.mysql.query<RowDataPacket[]>(`SELECT id, username, role, status FROM users WHERE id = ?`, [userId]);
    await this.audit(adminId, 'user.ban', 'user', userId, target[0], { ...after[0], reason });
    return { ...after[0], alreadyBanned: false };
  }

  async unbanUser(adminId: string, userId: string) {
    const target = await this.mysql.query<RowDataPacket[]>(`SELECT id, username, role, status FROM users WHERE id = ?`, [userId]);
    if (!target[0]) throw notFound('User not found.');
    if (target[0].status === 'active') return { ...target[0], alreadyActive: true };
    await this.mysql.transaction(async (connection) => {
      await connection.execute(`UPDATE users SET status = 'active' WHERE id = ?`, [userId]);
      await connection.execute(`INSERT INTO notifications (id, user_id, type, title, body) VALUES (?, ?, 'moderation', 'Account reinstated', 'Your account is active again. Thanks for playing fair.')`, [randomUUID(), userId]);
    });
    const after = await this.mysql.query<RowDataPacket[]>(`SELECT id, username, role, status FROM users WHERE id = ?`, [userId]);
    await this.audit(adminId, 'user.unban', 'user', userId, target[0], after[0]);
    return { ...after[0], alreadyActive: false };
  }

  async adjustWallet(adminId: string, userId: string, dto: AdjustWalletDto) {
    const coins = Math.trunc(dto.coins ?? 0);
    const pips = Math.trunc(dto.pips ?? 0);
    if (!coins && !pips) throw invalid('Provide a non-zero coin or pip adjustment.');
    const reason = dto.reason.trim();
    return this.mysql.transaction(async (connection) => {
      const [users] = await connection.query<RowDataPacket[]>(`SELECT id, status FROM users WHERE id = ? FOR UPDATE`, [userId]);
      if (!users[0]) throw notFound('User not found.');
      if (users[0].status === 'deleted') throw invalid('Deleted accounts cannot receive adjustments.');
      await connection.execute(`INSERT IGNORE INTO wallets (user_id) VALUES (?)`, [userId]);
      const [wallets] = await connection.query<RowDataPacket[]>(`SELECT coins, pips FROM wallets WHERE user_id = ? FOR UPDATE`, [userId]);
      const nextCoins = Number(wallets[0]?.coins ?? 0) + coins;
      const nextPips = Number(wallets[0]?.pips ?? 0) + pips;
      if (nextCoins < 0 || nextPips < 0) throw invalid('The adjustment would make a balance negative.');
      await connection.execute(`UPDATE wallets SET coins = ?, pips = ?, version = version + 1 WHERE user_id = ?`, [nextCoins, nextPips, userId]);
      const metadata = JSON.stringify({ reason, by: adminId });
      if (coins) await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id, metadata) VALUES (?, ?, 'coins', ?, ?, 'admin_adjustment', 'admin', ?, ?)`, [randomUUID(), userId, coins, nextCoins, adminId, metadata]);
      if (pips) await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id, metadata) VALUES (?, ?, 'pips', ?, ?, 'admin_adjustment', 'admin', ?, ?)`, [randomUUID(), userId, pips, nextPips, adminId, metadata]);
      await connection.execute(`INSERT INTO admin_audit_log (admin_id, action, entity_type, entity_id, before_json, after_json) VALUES (?, 'wallet.adjust', 'user', ?, ?, ?)`, [adminId, userId, JSON.stringify({ coins: Number(wallets[0]?.coins ?? 0), pips: Number(wallets[0]?.pips ?? 0) }), JSON.stringify({ coins: nextCoins, pips: nextPips, reason })]);
      return { userId, coins: nextCoins, pips: nextPips };
    });
  }

  // ---------------------------------------------------------------- shop

  async shop() {
    return this.mysql.query<RowDataPacket[]>(`SELECT id, sku, name, description, category, price_coins AS priceCoins, price_pips AS pricePips, asset_key AS assetKey, is_active AS isActive, is_limited AS isLimited, stock, is_giftable AS isGiftable, created_at AS createdAt, updated_at AS updatedAt FROM shop_items ORDER BY created_at DESC`);
  }

  async createShop(adminId: string, dto: CreateShopItemDto) {
    if (dto.priceCoins === 0 && dto.pricePips === 0) throw invalid('An item must have a coin or pip price.');
    const id = randomUUID();
    try {
      await this.mysql.execute(`INSERT INTO shop_items (id, sku, name, description, category, price_coins, price_pips, asset_key, stock, is_limited, is_giftable) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, [id, dto.sku.trim(), dto.name.trim(), dto.description.trim(), dto.category, dto.priceCoins, dto.pricePips, dto.assetKey.trim(), dto.stock ?? null, dto.isLimited ?? false, dto.isGiftable ?? true]);
    } catch (error) {
      if (this.isDuplicateEntry(error)) throw conflict('An item with this SKU already exists.');
      throw error;
    }
    await this.audit(adminId, 'shop.create', 'shop_item', id, null, dto);
    return { id, ...dto };
  }

  async updateShop(adminId: string, itemId: string, dto: UpdateShopItemDto) {
    const before = await this.mysql.query<RowDataPacket[]>(`SELECT * FROM shop_items WHERE id = ?`, [itemId]);
    if (!before[0]) throw notFound('Shop item not found.');
    const fields: string[] = []; const values: unknown[] = [];
    if (dto.sku !== undefined) { fields.push('sku = ?'); values.push(dto.sku.trim()); }
    if (dto.name !== undefined) { fields.push('name = ?'); values.push(dto.name.trim()); }
    if (dto.description !== undefined) { fields.push('description = ?'); values.push(dto.description.trim()); }
    if (dto.category !== undefined) { fields.push('category = ?'); values.push(dto.category); }
    if (dto.priceCoins !== undefined) { fields.push('price_coins = ?'); values.push(dto.priceCoins); }
    if (dto.pricePips !== undefined) { fields.push('price_pips = ?'); values.push(dto.pricePips); }
    if (dto.assetKey !== undefined) { fields.push('asset_key = ?'); values.push(dto.assetKey.trim()); }
    if (dto.stock !== undefined) { fields.push('stock = ?'); values.push(dto.stock); }
    if (dto.isGiftable !== undefined) { fields.push('is_giftable = ?'); values.push(dto.isGiftable); }
    if (dto.isLimited !== undefined) { fields.push('is_limited = ?'); values.push(dto.isLimited); }
    if (dto.isActive !== undefined) { fields.push('is_active = ?'); values.push(dto.isActive); }
    if (!fields.length) throw invalid('No change was supplied.');
    const effectiveCoins = dto.priceCoins ?? Number(before[0].price_coins);
    const effectivePips = dto.pricePips ?? Number(before[0].price_pips);
    if (effectiveCoins === 0 && effectivePips === 0) throw invalid('An item must have a coin or pip price.');
    try {
      await this.mysql.execute(`UPDATE shop_items SET ${fields.join(', ')} WHERE id = ?`, [...values, itemId]);
    } catch (error) {
      if (this.isDuplicateEntry(error)) throw conflict('An item with this SKU already exists.');
      throw error;
    }
    const after = await this.mysql.query<RowDataPacket[]>(`SELECT id, sku, name, description, category, price_coins AS priceCoins, price_pips AS pricePips, asset_key AS assetKey, is_active AS isActive, is_limited AS isLimited, stock, is_giftable AS isGiftable, updated_at AS updatedAt FROM shop_items WHERE id = ?`, [itemId]);
    await this.audit(adminId, 'shop.update', 'shop_item', itemId, this.slimShop(before[0]), after[0]);
    return after[0];
  }

  async toggleShop(adminId: string, itemId: string, dto: ToggleDto) {
    return this.updateShop(adminId, itemId, { isActive: dto.isActive });
  }

  async deleteShop(adminId: string, itemId: string, hard = false) {
    const before = await this.mysql.query<RowDataPacket[]>(`SELECT id, sku, name FROM shop_items WHERE id = ?`, [itemId]);
    if (!before[0]) throw notFound('Shop item not found.');
    const refs = await this.mysql.query<RowDataPacket[]>(`SELECT (SELECT COUNT(*) FROM inventory_items WHERE shop_item_id = ?) + (SELECT COUNT(*) FROM gift_transactions WHERE shop_item_id = ?) + (SELECT COUNT(*) FROM season_rewards WHERE shop_item_id = ?) + (SELECT COUNT(*) FROM messages WHERE gift_item_id = ?) AS refs`, [itemId, itemId, itemId, itemId]);
    const referenced = Number(refs[0]?.refs ?? 0) > 0;
    if (hard) {
      if (referenced) throw conflict('This item is owned or referenced by players, so it can only be deactivated (soft delete).');
      await this.mysql.execute(`DELETE FROM shop_items WHERE id = ?`, [itemId]);
      await this.audit(adminId, 'shop.delete', 'shop_item', itemId, before[0], { hard: true });
      return { success: true, hard: true };
    }
    await this.mysql.execute(`UPDATE shop_items SET is_active = FALSE WHERE id = ?`, [itemId]);
    await this.audit(adminId, 'shop.delete', 'shop_item', itemId, before[0], { hard: false, isActive: false });
    return { success: true, hard: false };
  }

  // ---------------------------------------------------------------- games

  async games() {
    return this.mysql.query<RowDataPacket[]>(`SELECT id, display_name AS displayName, category, min_players AS minPlayers, max_players AS maxPlayers, supports_teams AS supportsTeams, accent_color AS accentColor, icon_key AS iconKey, is_active AS isActive, config FROM games ORDER BY display_name`);
  }

  async toggleGame(adminId: string, gameId: string, dto: ToggleDto) {
    return this.updateGame(adminId, gameId, { isActive: dto.isActive });
  }

  async updateGame(adminId: string, gameId: string, dto: UpdateGameDto) {
    const before = await this.mysql.query<RowDataPacket[]>(`SELECT * FROM games WHERE id = ?`, [gameId]);
    if (!before[0]) throw notFound('Game not found.');
    const minPlayers = dto.minPlayers ?? Number(before[0].min_players);
    const maxPlayers = dto.maxPlayers ?? Number(before[0].max_players);
    if (minPlayers < 1 || maxPlayers < minPlayers) throw invalid('The player range is invalid.');
    const fields: string[] = []; const values: unknown[] = [];
    if (dto.displayName !== undefined) { fields.push('display_name = ?'); values.push(dto.displayName.trim()); }
    if (dto.minPlayers !== undefined) { fields.push('min_players = ?'); values.push(dto.minPlayers); }
    if (dto.maxPlayers !== undefined) { fields.push('max_players = ?'); values.push(dto.maxPlayers); }
    if (dto.supportsTeams !== undefined) { fields.push('supports_teams = ?'); values.push(dto.supportsTeams); }
    if (dto.accentColor !== undefined) { fields.push('accent_color = ?'); values.push(dto.accentColor); }
    if (dto.iconKey !== undefined) { fields.push('icon_key = ?'); values.push(dto.iconKey.trim()); }
    if (dto.isActive !== undefined) { fields.push('is_active = ?'); values.push(dto.isActive); }
    if (dto.config !== undefined) {
      const current = this.parseJson<Record<string, unknown>>(before[0].config, {});
      fields.push('config = ?'); values.push(JSON.stringify({ ...current, ...dto.config }));
    }
    if (!fields.length) throw invalid('No change was supplied.');
    await this.mysql.execute(`UPDATE games SET ${fields.join(', ')} WHERE id = ?`, [...values, gameId]);
    const after = await this.mysql.query<RowDataPacket[]>(`SELECT id, display_name AS displayName, category, min_players AS minPlayers, max_players AS maxPlayers, supports_teams AS supportsTeams, accent_color AS accentColor, icon_key AS iconKey, is_active AS isActive, config FROM games WHERE id = ?`, [gameId]);
    await this.audit(adminId, dto.isActive !== undefined && fields.length === 1 ? 'game.toggle' : 'game.update', 'game', gameId, { isActive: Boolean(before[0].is_active) }, after[0]);
    return after[0];
  }

  // ---------------------------------------------------------------- reports & moderation

  async reports(status?: string, category?: string, reportedUserId?: string, page = 0, limit = 20): Promise<Paginated<RowDataPacket>> {
    const safePage = Math.max(page || 0, 0);
    const safeLimit = Math.min(Math.max(limit || 20, 1), 100);
    const params: unknown[] = []; const conditions = ['1 = 1'];
    if (status) { conditions.push('r.status = ?'); params.push(status); }
    if (category) { conditions.push('r.category = ?'); params.push(category); }
    if (reportedUserId) { conditions.push('r.reported_user_id = ?'); params.push(reportedUserId); }
    const where = conditions.join(' AND ');
    const [countRows, items] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM reports r WHERE ${where}`, [...params]),
      this.mysql.query<RowDataPacket[]>(`SELECT r.id, r.category, r.description, r.status, r.match_id AS matchId, r.resolution_note AS resolutionNote, r.created_at AS createdAt, r.resolved_at AS resolvedAt, reporter.id AS reporterId, reporter.display_name AS reporterName, reported.id AS reportedUserId, reported.display_name AS reportedUserName, reported.status AS reportedUserStatus, resolver.display_name AS resolvedByName FROM reports r JOIN users reporter ON reporter.id = r.reporter_id LEFT JOIN users reported ON reported.id = r.reported_user_id LEFT JOIN users resolver ON resolver.id = r.resolved_by WHERE ${where} ORDER BY r.created_at DESC LIMIT ? OFFSET ?`, [...params, safeLimit, safePage * safeLimit]),
    ]);
    const total = Number(countRows[0]?.total ?? 0);
    return { items, page: safePage, limit: safeLimit, total, totalPages: Math.ceil(total / safeLimit) };
  }

  async reportDetail(reportId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT r.id, r.category, r.description, r.status, r.match_id AS matchId, r.resolution_note AS resolutionNote, r.created_at AS createdAt, r.resolved_at AS resolvedAt, reporter.id AS reporterId, reporter.display_name AS reporterName, reporter.username AS reporterUsername, reported.id AS reportedUserId, reported.display_name AS reportedUserName, reported.username AS reportedUsername, reported.status AS reportedUserStatus, resolver.display_name AS resolvedByName, m.game_id AS gameId, m.mode AS matchMode FROM reports r JOIN users reporter ON reporter.id = r.reporter_id LEFT JOIN users reported ON reported.id = r.reported_user_id LEFT JOIN users resolver ON resolver.id = r.resolved_by LEFT JOIN matches m ON m.id = r.match_id WHERE r.id = ?`, [reportId]);
    if (!rows[0]) throw notFound('Report not found.');
    const report = rows[0];
    const history = report.reportedUserId
      ? await this.mysql.query<RowDataPacket[]>(`SELECT id, category, status, created_at AS createdAt FROM reports WHERE reported_user_id = ? AND id <> ? ORDER BY created_at DESC LIMIT 5`, [report.reportedUserId as string, reportId])
      : [];
    return { ...report, priorReports: history };
  }

  async resolveReport(adminId: string, adminRole: string, reportId: string, dto: ResolveReportDto) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT r.id, r.status, r.reported_user_id AS reportedUserId, reported.role AS reportedRole, reported.status AS reportedStatus FROM reports r LEFT JOIN users reported ON reported.id = r.reported_user_id WHERE r.id = ?`, [reportId]);
    if (!rows[0]) throw notFound('Report not found.');
    const moderationAction = dto.moderationAction ?? 'none';
    if (moderationAction !== 'none' && !rows[0].reportedUserId) throw invalid('This report has no reported user to moderate.');
    if (moderationAction === 'suspend_reported') {
      if (adminRole !== 'admin') throw forbidden('Only admins can suspend accounts from a report.');
      if (rows[0].reportedUserId === adminId) throw invalid('You cannot suspend your own account.');
      if (rows[0].reportedRole === 'admin') throw forbidden('Admin accounts cannot be suspended.');
    }
    const note = dto.resolutionNote?.trim() || null;
    await this.mysql.transaction(async (connection) => {
      await connection.execute(`UPDATE reports SET status = ?, resolution_note = ?, resolved_by = ?, resolved_at = IF(? IN ('resolved','dismissed'), UTC_TIMESTAMP(3), NULL) WHERE id = ?`, [dto.status, note, adminId, dto.status, reportId]);
      const reportedUserId = rows[0].reportedUserId as string | null;
      if (moderationAction === 'warn' && reportedUserId) {
        await connection.execute(`INSERT INTO notifications (id, user_id, type, title, body) VALUES (?, ?, 'moderation_warning', 'Moderation warning', ?)`, [randomUUID(), reportedUserId, note ?? 'Your behavior was flagged by moderation. Further violations may lead to suspension.']);
      }
      if (moderationAction === 'suspend_reported' && reportedUserId && rows[0].reportedStatus !== 'suspended') {
        await connection.execute(`UPDATE users SET status = 'suspended' WHERE id = ?`, [reportedUserId]);
        await connection.execute(`UPDATE refresh_sessions SET revoked_at = UTC_TIMESTAMP(3) WHERE user_id = ? AND revoked_at IS NULL`, [reportedUserId]);
        await connection.execute(`INSERT INTO notifications (id, user_id, type, title, body) VALUES (?, ?, 'moderation', 'Account suspended', ?)`, [randomUUID(), reportedUserId, note ? `Your account was suspended by moderation: ${note}` : 'Your account was suspended by moderation.']);
      }
    });
    await this.audit(adminId, 'report.resolve', 'report', reportId, { status: rows[0].status }, { status: dto.status, moderationAction });
    return { success: true, status: dto.status, moderationAction };
  }

  // ---------------------------------------------------------------- seasons

  async seasons() {
    return this.mysql.query<RowDataPacket[]>(`SELECT s.id, s.name, s.starts_at AS startsAt, s.ends_at AS endsAt, s.status, s.created_at AS createdAt, (SELECT COUNT(*) FROM season_rewards sr WHERE sr.season_id = s.id) AS rewardsCount, (SELECT COUNT(DISTINCT user_id) FROM player_ratings pr WHERE pr.season_id = s.id) AS participantCount FROM seasons s ORDER BY s.starts_at DESC`);
  }

  async seasonDetail(seasonId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, name, starts_at AS startsAt, ends_at AS endsAt, status, created_at AS createdAt FROM seasons WHERE id = ?`, [seasonId]);
    if (!rows[0]) throw notFound('Season not found.');
    const [rewardList, topPlayers, participantRows] = await Promise.all([
      this.rewards(seasonId),
      this.mysql.query<RowDataPacket[]>(`SELECT pr.user_id AS userId, u.display_name AS displayName, MAX(pr.rating) AS rating, SUM(pr.wins) AS wins, SUM(pr.games_played) AS gamesPlayed FROM player_ratings pr JOIN users u ON u.id = pr.user_id WHERE pr.season_id = ? GROUP BY pr.user_id, u.display_name ORDER BY rating DESC LIMIT 5`, [seasonId]),
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(DISTINCT user_id) AS total FROM player_ratings WHERE season_id = ?`, [seasonId]),
    ]);
    return { ...rows[0], rewards: rewardList, topPlayers: topPlayers.map((row) => ({ ...row, rating: Number(row.rating), wins: Number(row.wins), gamesPlayed: Number(row.gamesPlayed) })), participantCount: Number(participantRows[0]?.total ?? 0) };
  }

  async createSeason(adminId: string, dto: CreateSeasonDto) {
    const startsAt = new Date(dto.startsAt); const endsAt = new Date(dto.endsAt);
    if (!Number.isFinite(startsAt.getTime()) || !Number.isFinite(endsAt.getTime()) || endsAt <= startsAt) throw invalid('Season dates are invalid.');
    const id = randomUUID(); await this.mysql.execute(`INSERT INTO seasons (id, name, starts_at, ends_at, status) VALUES (?, ?, ?, ?, 'scheduled')`, [id, dto.name.trim(), startsAt, endsAt]); await this.audit(adminId, 'season.create', 'season', id, null, dto); return { id, ...dto, status: 'scheduled' };
  }

  async updateSeason(adminId: string, seasonId: string, dto: UpdateSeasonDto) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, name, starts_at AS startsAt, ends_at AS endsAt, status FROM seasons WHERE id = ?`, [seasonId]);
    if (!rows[0]) throw notFound('Season not found.');
    if (rows[0].status === 'finished') throw invalid('Finished seasons cannot be edited.');
    if (!dto.name && !dto.startsAt && !dto.endsAt) throw invalid('No change was supplied.');
    if (rows[0].status === 'active' && dto.startsAt) throw invalid('An active season already started; only its name and end date can change.');
    const startsAt = dto.startsAt ? new Date(dto.startsAt) : new Date(rows[0].startsAt as string);
    const endsAt = dto.endsAt ? new Date(dto.endsAt) : new Date(rows[0].endsAt as string);
    if (!Number.isFinite(startsAt.getTime()) || !Number.isFinite(endsAt.getTime()) || endsAt <= startsAt) throw invalid('Season dates are invalid.');
    const fields: string[] = []; const values: unknown[] = [];
    if (dto.name) { fields.push('name = ?'); values.push(dto.name.trim()); }
    if (dto.startsAt) { fields.push('starts_at = ?'); values.push(startsAt); }
    if (dto.endsAt) { fields.push('ends_at = ?'); values.push(endsAt); }
    await this.mysql.execute(`UPDATE seasons SET ${fields.join(', ')} WHERE id = ?`, [...values, seasonId]);
    const after = await this.mysql.query<RowDataPacket[]>(`SELECT id, name, starts_at AS startsAt, ends_at AS endsAt, status FROM seasons WHERE id = ?`, [seasonId]);
    await this.audit(adminId, 'season.update', 'season', seasonId, rows[0], after[0]);
    return after[0];
  }

  async deleteSeason(adminId: string, seasonId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, name, status FROM seasons WHERE id = ?`, [seasonId]);
    if (!rows[0]) throw notFound('Season not found.');
    if (rows[0].status !== 'scheduled') throw conflict('Only scheduled seasons can be deleted. Finish an active season instead.');
    await this.mysql.execute(`DELETE FROM seasons WHERE id = ?`, [seasonId]);
    await this.audit(adminId, 'season.delete', 'season', seasonId, rows[0], null);
    return { success: true };
  }

  async activateSeason(adminId: string, seasonId: string) {
    const result = await this.mysql.transaction(async (connection) => { await connection.execute(`UPDATE seasons SET status = 'finished' WHERE status = 'active'`); const [update] = await connection.execute<ResultSetHeader>(`UPDATE seasons SET status = 'active' WHERE id = ? AND status IN ('scheduled','active')`, [seasonId]); return update; });
    if (!result.affectedRows) throw notFound('Season not found.');
    await this.audit(adminId, 'season.activate', 'season', seasonId, null, { status: 'active' }); return { success: true };
  }

  async rewards(seasonId: string) { return this.mysql.query<RowDataPacket[]>(`SELECT sr.id, sr.min_rank AS minRank, sr.max_rank AS maxRank, sr.coins, sr.pips, sr.shop_item_id AS shopItemId, si.name AS shopItemName FROM season_rewards sr LEFT JOIN shop_items si ON si.id = sr.shop_item_id WHERE sr.season_id = ? ORDER BY sr.min_rank`, [seasonId]); }

  async createReward(adminId: string, seasonId: string, dto: CreateSeasonRewardDto) {
    if (dto.maxRank < dto.minRank || (dto.coins === 0 && dto.pips === 0 && !dto.shopItemId)) throw invalid('A reward needs a valid rank range and at least one reward.');
    const season = await this.mysql.query<RowDataPacket[]>(`SELECT id, status FROM seasons WHERE id = ?`, [seasonId]);
    if (!season[0]) throw notFound('Season not found.');
    if (season[0].status === 'finished') throw invalid('Rewards cannot be added to a finished season.');
    const id = randomUUID();
    await this.mysql.execute(`INSERT INTO season_rewards (id, season_id, min_rank, max_rank, coins, pips, shop_item_id) VALUES (?, ?, ?, ?, ?, ?, ?)`, [id, seasonId, dto.minRank, dto.maxRank, dto.coins, dto.pips, dto.shopItemId ?? null]);
    await this.audit(adminId, 'season.reward.create', 'season_reward', id, null, dto);
    return { id, seasonId, ...dto };
  }

  async deleteReward(adminId: string, seasonId: string, rewardId: string) {
    const season = await this.mysql.query<RowDataPacket[]>(`SELECT id, status FROM seasons WHERE id = ?`, [seasonId]);
    if (!season[0]) throw notFound('Season not found.');
    if (season[0].status === 'finished') throw invalid('Rewards of a finished season are locked.');
    const result = await this.mysql.execute(`DELETE FROM season_rewards WHERE id = ? AND season_id = ?`, [rewardId, seasonId]);
    if (!result.affectedRows) throw notFound('Reward not found.');
    await this.audit(adminId, 'season.reward.delete', 'season_reward', rewardId, { seasonId }, null);
    return { success: true };
  }

  async finishSeason(adminId: string, seasonId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, status FROM seasons WHERE id = ?`, [seasonId]);
    if (!rows[0]) throw notFound('Season not found.');
    if (rows[0].status !== 'active') throw invalid('Only the active season can be finished.');
    await this.ranking.finishSeason(seasonId);
    await this.audit(adminId, 'season.finish', 'season', seasonId, null, { status: 'finished' });
    return { success: true };
  }

  // ---------------------------------------------------------------- audit log

  async auditLog(page = 0, limit = 20, action?: string, adminId?: string): Promise<Paginated<Record<string, unknown>>> {
    const safePage = Math.max(page || 0, 0);
    const safeLimit = Math.min(Math.max(limit || 20, 1), 100);
    const params: unknown[] = []; const conditions = ['1 = 1'];
    if (action?.trim()) { conditions.push('l.action LIKE ?'); params.push(`%${action.trim()}%`); }
    if (adminId?.trim()) { conditions.push('l.admin_id = ?'); params.push(adminId.trim()); }
    const where = conditions.join(' AND ');
    const [countRows, items] = await Promise.all([
      this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM admin_audit_log l WHERE ${where}`, [...params]),
      this.mysql.query<RowDataPacket[]>(`SELECT l.id, l.admin_id AS adminId, u.display_name AS adminName, l.action, l.entity_type AS entityType, l.entity_id AS entityId, l.before_json AS beforeJson, l.after_json AS afterJson, l.created_at AS createdAt FROM admin_audit_log l JOIN users u ON u.id = l.admin_id WHERE ${where} ORDER BY l.id DESC LIMIT ? OFFSET ?`, [...params, safeLimit, safePage * safeLimit]),
    ]);
    const total = Number(countRows[0]?.total ?? 0);
    return { items: items.map((row) => ({ id: row.id, adminId: row.adminId, adminName: row.adminName, action: row.action, entityType: row.entityType, entityId: row.entityId, before: this.parseJson(row.beforeJson, null), after: this.parseJson(row.afterJson, null), createdAt: row.createdAt })), page: safePage, limit: safeLimit, total, totalPages: Math.ceil(total / safeLimit) };
  }

  // ---------------------------------------------------------------- helpers

  private async ensureNotLastAdmin(excludeUserId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT COUNT(*) AS total FROM users WHERE role = 'admin' AND id <> ? AND status = 'active'`, [excludeUserId]);
    if (Number(rows[0]?.total ?? 0) < 1) throw forbidden('This is the last active admin account. Promote another admin first.');
  }

  private async audit(adminId: string, action: string, entityType: string, entityId: string, before: unknown, after: unknown) { await this.mysql.execute(`INSERT INTO admin_audit_log (admin_id, action, entity_type, entity_id, before_json, after_json) VALUES (?, ?, ?, ?, ?, ?)`, [adminId, action, entityType, entityId, before ? JSON.stringify(before) : null, after ? JSON.stringify(after) : null]); }

  private isDuplicateEntry(error: unknown): boolean { return (error as { code?: string } | null)?.code === 'ER_DUP_ENTRY'; }

  private num<T extends RowDataPacket>(row: T | undefined, keys: string[]): Record<string, number> {
    const result: Record<string, number> = {};
    for (const key of keys) result[key] = Number((row as RowDataPacket | undefined)?.[key] ?? 0);
    return result;
  }

  private series(rows: RowDataPacket[]): Array<{ day: string; value: number }> {
    return rows.map((row) => ({ day: typeof row.day === 'string' ? row.day.slice(0, 10) : String(row.day), value: Number(row.value ?? 0) }));
  }

  private slimShop(row: RowDataPacket): Record<string, unknown> {
    return { id: row.id, sku: row.sku, name: row.name, category: row.category, priceCoins: Number(row.price_coins), pricePips: Number(row.price_pips), isActive: Boolean(row.is_active) };
  }

  private parseJson<T>(value: unknown, fallback: T): T {
    if (value === null || value === undefined) return fallback;
    if (typeof value !== 'string') return value as T;
    try { return JSON.parse(value) as T; } catch { return fallback; }
  }
}
