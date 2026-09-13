import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { randomUUID } from 'node:crypto';
import { RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, invalid, notFound } from '../common/errors';
import { GameService } from '../games/game.service';
import { GameRegistry } from '../games/game.registry';
import { JoinQueueDto } from './matchmaking.dto';

@Injectable()
export class MatchmakingService {
  private readonly logger = new Logger(MatchmakingService.name);
  private processing = false;
  constructor(private readonly mysql: MysqlService, private readonly games: GameService, private readonly registry: GameRegistry) {}

  async join(userId: string, dto: JoinQueueDto) {
    const descriptor = this.registry.descriptor(dto.gameId);
    if (dto.playerCount < descriptor.minPlayers || dto.playerCount > descriptor.maxPlayers) throw invalid(`Choose between ${descriptor.minPlayers} and ${descriptor.maxPlayers} players for this game.`);
    const existing = await this.mysql.query<RowDataPacket[]>(`SELECT id, game_id AS gameId, mode, desired_players AS desiredPlayers, queued_at AS queuedAt FROM matchmaking_tickets WHERE user_id = ? AND status = 'queued' LIMIT 1`, [userId]);
    if (existing[0]) throw conflict('You are already in a matchmaking queue.');
    const rating = await this.rating(userId, dto.gameId);
    const id = randomUUID();
    await this.mysql.execute(`INSERT INTO matchmaking_tickets (id, user_id, game_id, mode, desired_players, rating) VALUES (?, ?, ?, ?, ?, ?)`, [id, userId, dto.gameId, dto.mode, dto.playerCount, rating]);
    return { id, gameId: dto.gameId, mode: dto.mode, playerCount: dto.playerCount, rating, queuedAt: new Date().toISOString(), botAfterSeconds: 15 };
  }

  async leave(userId: string, ticketId?: string) {
    const result = await this.mysql.execute(`UPDATE matchmaking_tickets SET status = 'cancelled' WHERE user_id = ? AND status = 'queued' ${ticketId ? 'AND id = ?' : ''}`, ticketId ? [userId, ticketId] : [userId]);
    if (!result.affectedRows) throw notFound('No active matchmaking ticket.');
    return { success: true };
  }

  async status(userId: string, ticketId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, game_id AS gameId, mode, desired_players AS playerCount, status, queued_at AS queuedAt, matched_at AS matchedAt, match_id AS matchId FROM matchmaking_tickets WHERE id = ? AND user_id = ?`, [ticketId, userId]);
    if (!rows[0]) throw notFound('Matchmaking ticket not found.');
    if (rows[0].matchId) return { ...rows[0], match: await this.games.getMatch(rows[0].matchId, userId) };
    return rows[0];
  }

  @Interval(1000)
  async processQueue(): Promise<void> {
    if (this.processing) return;
    this.processing = true;
    try {
      const tickets = await this.mysql.query<RowDataPacket[]>(`SELECT id, user_id AS userId, game_id AS gameId, mode, desired_players AS desiredPlayers, rating, queued_at AS queuedAt FROM matchmaking_tickets WHERE status = 'queued' ORDER BY queued_at LIMIT 200`);
      const grouped = new Map<string, RowDataPacket[]>();
      for (const ticket of tickets) { const key = `${ticket.gameId}:${ticket.mode}:${ticket.desiredPlayers}`; const list = grouped.get(key) ?? []; list.push(ticket); grouped.set(key, list); }
      for (const [, group] of grouped) {
        const descriptor = this.registry.descriptor(group[0].gameId as string);
        while (group.length >= Number(group[0].desiredPlayers)) {
          const size = Number(group[0].desiredPlayers); const batch = group.splice(0, size); await this.createHumanMatch(batch); }
        for (const ticket of [...group]) {
          if (Date.now() - new Date(ticket.queuedAt as string).getTime() >= 15_000) { group.splice(group.indexOf(ticket), 1); await this.createBotMatch(ticket, descriptor.maxPlayers >= Number(ticket.desiredPlayers) ? Number(ticket.desiredPlayers) : descriptor.minPlayers); }
        }
      }
    } catch (error) { this.logger.error(error); } finally { this.processing = false; }
  }

  private async createHumanMatch(batch: RowDataPacket[]): Promise<void> {
    const ids = batch.map((ticket) => ticket.userId as string);
    const first = batch[0];
    const match = await this.games.createMatch(first.gameId as string, first.mode as 'casual' | 'ranked', ids, Number(first.desiredPlayers));
    await this.mysql.transaction(async (connection) => {
      for (const ticket of batch) await connection.execute(`UPDATE matchmaking_tickets SET status = 'matched', matched_at = UTC_TIMESTAMP(3), match_id = ? WHERE id = ? AND status = 'queued'`, [match.id, ticket.id]);
    });
  }

  private async createBotMatch(ticket: RowDataPacket, playerCount: number): Promise<void> {
    const match = await this.games.createMatch(ticket.gameId as string, ticket.mode as 'casual' | 'ranked', [ticket.userId as string], playerCount);
    await this.mysql.execute(`UPDATE matchmaking_tickets SET status = 'matched', matched_at = UTC_TIMESTAMP(3), match_id = ? WHERE id = ? AND status = 'queued'`, [match.id, ticket.id]);
  }

  private async rating(userId: string, gameId: string): Promise<number> {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT pr.rating FROM player_ratings pr JOIN seasons s ON s.id = pr.season_id AND s.status = 'active' WHERE pr.user_id = ? AND pr.game_id = ? LIMIT 1`, [userId, gameId]);
    return Number(rows[0]?.rating ?? 1000);
  }
}
