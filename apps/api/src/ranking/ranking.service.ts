import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import * as crypto from 'node:crypto';
import { RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { notFound } from '../common/errors';

interface RatingRow extends RowDataPacket { userId: string; displayName: string; avatarUrl: string | null; rating: number; wins: number; losses: number; draws: number; gamesPlayed: number; rankPosition: number; }

@Injectable()
export class RankingService {
  private readonly logger = new Logger(RankingService.name);
  private retryingPending = false;

  constructor(private readonly mysql: MysqlService) {}

  async currentSeason() {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, name, starts_at AS startsAt, ends_at AS endsAt, status FROM seasons WHERE status = 'active' ORDER BY starts_at DESC LIMIT 1`);
    if (!rows[0]) throw notFound('No active season.');
    return rows[0];
  }

  async leaderboard(gameId: string, limit = 50, offset = 0) {
    const season = await this.currentSeason();
    const rows = await this.mysql.query<RatingRow[]>(`SELECT u.id AS userId, u.display_name AS displayName, u.avatar_url AS avatarUrl, pr.rating, pr.wins, pr.losses, pr.draws, pr.games_played AS gamesPlayed, DENSE_RANK() OVER (ORDER BY pr.rating DESC, pr.wins DESC) AS rankPosition FROM player_ratings pr JOIN users u ON u.id = pr.user_id WHERE pr.game_id = ? AND pr.season_id = ? AND u.status = 'active' ORDER BY pr.rating DESC, pr.wins DESC LIMIT ? OFFSET ?`, [gameId, season.id, Math.min(Math.max(limit, 1), 100), Math.max(offset, 0)]);
    return { season, entries: rows.map((row) => ({ ...row, rating: Number(row.rating), wins: Number(row.wins), losses: Number(row.losses), draws: Number(row.draws), gamesPlayed: Number(row.gamesPlayed), rank: Number(row.rankPosition) })) };
  }

  async myRating(userId: string, gameId: string) {
    const season = await this.currentSeason();
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT rating, wins, losses, draws, games_played AS gamesPlayed, peak_rating AS peakRating FROM player_ratings WHERE user_id = ? AND game_id = ? AND season_id = ?`, [userId, gameId, season.id]);
    return rows[0] ?? { rating: 1000, wins: 0, losses: 0, draws: 0, gamesPlayed: 0, peakRating: 1000, seasonId: season.id };
  }

  async recordMatch(matchId: string): Promise<void> {
    await this.mysql.transaction(async (connection) => {
      const [matches] = await connection.query<RowDataPacket[]>(`SELECT id, game_id AS gameId, mode, draw FROM matches WHERE id = ? AND status = 'finished' FOR UPDATE`, [matchId]);
      const match = matches[0];
      if (!match) return;
      const [players] = await connection.query<RowDataPacket[]>(`SELECT user_id AS userId, result, is_bot AS isBot, rating_before AS ratingBefore FROM match_players WHERE match_id = ? FOR UPDATE`, [matchId]);
      const humanPlayers = players.filter((player) => !Boolean(player.isBot));
      if (!humanPlayers.length) return;
      if (humanPlayers.every((player) => player.ratingBefore !== null)) {
        for (const player of humanPlayers) await this.grantMatchReward(connection, player.userId as string, matchId, player.result as string, player.result === 'draw' || Boolean(match.draw));
        return;
      }

      const [seasons] = await connection.query<RowDataPacket[]>(`SELECT id FROM seasons WHERE status = 'active' ORDER BY starts_at DESC LIMIT 1`);
      const seasonId = seasons[0]?.id as string | undefined;
      const currentRatings = new Map<string, number>();
      if (seasonId) {
        for (const player of humanPlayers) {
          const [existing] = await connection.query<RowDataPacket[]>(`SELECT rating FROM player_ratings WHERE user_id = ? AND game_id = ? AND season_id = ? FOR UPDATE`, [player.userId, match.gameId, seasonId]);
          currentRatings.set(player.userId as string, Number(existing[0]?.rating ?? 1000));
        }
      }

      const ranked = match.mode === 'ranked';
      for (const player of humanPlayers) {
        const userId = player.userId as string;
        const oldRating = currentRatings.get(userId) ?? 1000;
        const result = player.result as string;
        const isDraw = result === 'draw' || Boolean(match.draw);
        const score = result === 'win' ? 1 : isDraw ? 0.5 : 0;
        let newRating = oldRating;
        if (seasonId && ranked) {
          const opponents = humanPlayers.filter((candidate) => candidate.userId !== userId);
          if (opponents.length) {
            const expected = opponents.reduce((sum, opponent) => sum + 1 / (1 + 10 ** (((currentRatings.get(opponent.userId as string) ?? 1000) - oldRating) / 400)), 0) / opponents.length;
            newRating = Math.max(100, Math.round(oldRating + 32 * (score - expected)));
          }
        }
        if (seasonId) {
          await connection.execute(`INSERT INTO player_ratings (user_id, game_id, season_id, rating, wins, losses, draws, games_played, peak_rating) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?) ON DUPLICATE KEY UPDATE rating = ?, wins = wins + ?, losses = losses + ?, draws = draws + ?, games_played = games_played + 1, peak_rating = GREATEST(peak_rating, ?)`, [userId, match.gameId, seasonId, newRating, result === 'win' ? 1 : 0, result === 'loss' ? 1 : 0, isDraw ? 1 : 0, newRating, newRating, result === 'win' ? 1 : 0, result === 'loss' ? 1 : 0, isDraw ? 1 : 0, newRating]);
        }
        await connection.execute(`INSERT INTO game_stats (user_id, game_id, games_played, wins, losses, draws) VALUES (?, ?, 1, ?, ?, ?) ON DUPLICATE KEY UPDATE games_played = games_played + 1, wins = wins + ?, losses = losses + ?, draws = draws + ?`, [userId, match.gameId, result === 'win' ? 1 : 0, result === 'loss' ? 1 : 0, isDraw ? 1 : 0, result === 'win' ? 1 : 0, result === 'loss' ? 1 : 0, isDraw ? 1 : 0]);
        await connection.execute(`UPDATE match_players SET rating_before = ?, rating_after = ? WHERE match_id = ? AND user_id = ?`, [oldRating, newRating, matchId, userId]);
        await this.grantMatchReward(connection, userId, matchId, result, isDraw);
      }
    });
  }

  private async grantMatchReward(connection: import('mysql2/promise').PoolConnection, userId: string, matchId: string, result: string, isDraw: boolean): Promise<void> {
    const idempotencyKey = `match:${matchId}`;
    const [existing] = await connection.query<RowDataPacket[]>(`SELECT id FROM wallet_transactions WHERE user_id = ? AND idempotency_key = ? LIMIT 1`, [userId, idempotencyKey]);
    if (existing[0]) return;
    const xp = result === 'win' ? 100 : isDraw ? 60 : 40;
    const coins = result === 'win' ? 100 : isDraw ? 50 : 25;
    await connection.execute(`INSERT IGNORE INTO wallets (user_id) VALUES (?)`, [userId]);
    const [walletRows] = await connection.query<RowDataPacket[]>(`SELECT coins FROM wallets WHERE user_id = ? FOR UPDATE`, [userId]);
    const balanceAfter = Number(walletRows[0]?.coins ?? 0) + coins;
    await connection.execute(`UPDATE wallets SET coins = ?, version = version + 1 WHERE user_id = ?`, [balanceAfter, userId]);
    await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id, idempotency_key, metadata) VALUES (?, ?, 'coins', ?, ?, 'match_reward', 'match', ?, ?, ?)`, [crypto.randomUUID(), userId, coins, balanceAfter, matchId, idempotencyKey, JSON.stringify({ xp, result: isDraw ? 'draw' : result })]);
    const [userRows] = await connection.query<RowDataPacket[]>(`SELECT experience, level FROM users WHERE id = ? FOR UPDATE`, [userId]);
    if (userRows[0]) {
      const experience = Number(userRows[0].experience ?? 0) + xp;
      const level = Math.min(100, Math.max(Number(userRows[0].level ?? 1), Math.floor(experience / 1000) + 1));
      await connection.execute(`UPDATE users SET experience = ?, level = ? WHERE id = ?`, [experience, level, userId]);
    }
  }

  @Interval(5000)
  async retryPendingMatches(): Promise<void> {
    if (this.retryingPending) return;
    this.retryingPending = true;
    try {
      const rows = await this.mysql.query<RowDataPacket[]>(`SELECT DISTINCT m.id FROM matches m JOIN match_players mp ON mp.match_id = m.id AND mp.is_bot = FALSE LEFT JOIN wallet_transactions wt ON wt.user_id = mp.user_id AND wt.idempotency_key = CONCAT('match:', m.id) WHERE m.status = 'finished' AND m.finished_at >= DATE_SUB(UTC_TIMESTAMP(3), INTERVAL 1 DAY) AND (mp.rating_before IS NULL OR wt.id IS NULL) LIMIT 100`);
      for (const row of rows) {
        try {
          await this.recordMatch(row.id as string);
        } catch (error: unknown) {
          this.logger.warn(`Could not settle completed match ${row.id as string}; it will be retried`, error instanceof Error ? error.message : String(error));
        }
      }
    } catch (error: unknown) {
      this.logger.warn('Could not scan pending match settlements', error instanceof Error ? error.message : String(error));
    } finally {
      this.retryingPending = false;
    }
  }

  async finishSeason(seasonId: string): Promise<void> {
    await this.mysql.transaction(async (connection) => {
      const [closed] = await connection.execute<import('mysql2/promise').ResultSetHeader>(`UPDATE seasons SET status = 'finished' WHERE id = ? AND status = 'active'`, [seasonId]);
      if (!closed.affectedRows) return;
      const [rewards] = await connection.query<RowDataPacket[]>(`SELECT id, min_rank AS minRank, max_rank AS maxRank, coins, pips, shop_item_id AS shopItemId FROM season_rewards WHERE season_id = ?`, [seasonId]);
      for (const reward of rewards) {
        const [entries] = await connection.query<RowDataPacket[]>(`SELECT user_id AS userId, MAX(rating) AS rating FROM player_ratings WHERE season_id = ? GROUP BY user_id ORDER BY rating DESC LIMIT ?, ?`, [seasonId, Number(reward.minRank) - 1, Number(reward.maxRank) - Number(reward.minRank) + 1]);
        for (const entry of entries) {
          await connection.execute(`INSERT IGNORE INTO wallets (user_id) VALUES (?)`, [entry.userId]);
          if (Number(reward.coins) > 0) { await connection.execute(`UPDATE wallets SET coins = coins + ? WHERE user_id = ?`, [reward.coins, entry.userId]); const [wallet] = await connection.query<RowDataPacket[]>(`SELECT coins FROM wallets WHERE user_id = ?`, [entry.userId]); await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id) VALUES (?, ?, 'coins', ?, ?, 'season_reward', 'season', ?)`, [crypto.randomUUID(), entry.userId, reward.coins, wallet[0].coins, seasonId]); }
          if (Number(reward.pips) > 0) { await connection.execute(`UPDATE wallets SET pips = pips + ? WHERE user_id = ?`, [reward.pips, entry.userId]); const [wallet] = await connection.query<RowDataPacket[]>(`SELECT pips FROM wallets WHERE user_id = ?`, [entry.userId]); await connection.execute(`INSERT INTO wallet_transactions (id, user_id, currency, amount, balance_after, type, reference_type, reference_id) VALUES (?, ?, 'pips', ?, ?, 'season_reward', 'season', ?)`, [crypto.randomUUID(), entry.userId, reward.pips, wallet[0].pips, seasonId]); }
          if (reward.shopItemId) await connection.execute(`INSERT INTO inventory_items (id, user_id, shop_item_id) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + 1`, [crypto.randomUUID(), entry.userId, reward.shopItemId]);
        }
      }
    });
  }

}
