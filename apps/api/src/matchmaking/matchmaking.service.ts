import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { randomUUID } from 'node:crypto';
import { ResultSetHeader, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, invalid, notFound } from '../common/errors';
import { GameService } from '../games/game.service';
import { GameRegistry, isCoreGame } from '../games/game.registry';
import { JoinQueueDto } from './matchmaking.dto';

class TicketClaimLostError extends Error {}

@Injectable()
export class MatchmakingService {
  private readonly logger = new Logger(MatchmakingService.name);
  private processing = false;
  constructor(private readonly mysql: MysqlService, private readonly games: GameService, private readonly registry: GameRegistry) {}

  async join(userId: string, dto: JoinQueueDto) {
    if (!isCoreGame(dto.gameId)) throw notFound('This game is reserved for a future release.');
    const descriptor = this.registry.descriptor(dto.gameId);
    if (dto.playerCount < descriptor.minPlayers || dto.playerCount > descriptor.maxPlayers) throw invalid(`Choose between ${descriptor.minPlayers} and ${descriptor.maxPlayers} players for this game.`);
    const activeRows = await this.mysql.query<RowDataPacket[]>(`SELECT is_active AS isActive FROM games WHERE id = ? LIMIT 1`, [dto.gameId]);
    if (!activeRows[0] || !Boolean(activeRows[0].isActive)) throw notFound('This game is currently unavailable.');
    const rating = await this.rating(userId, dto.gameId);
    const id = randomUUID();
    const queuedAt = new Date().toISOString();
    // Serialize joins for the same account. The schema intentionally permits
    // historical tickets, so the active-ticket check must live in the same
    // transaction as the insert rather than relying on a non-atomic preflight.
    await this.mysql.transaction(async (connection) => {
      await connection.query<RowDataPacket[]>(`SELECT id FROM users WHERE id = ? FOR UPDATE`, [userId]);
      const [existing] = await connection.query<RowDataPacket[]>(`SELECT id FROM matchmaking_tickets WHERE user_id = ? AND status = 'queued' LIMIT 1 FOR UPDATE`, [userId]);
      if (existing[0]) throw conflict('You are already in a matchmaking queue.');
      await connection.execute(`INSERT INTO matchmaking_tickets (id, user_id, game_id, mode, desired_players, rating) VALUES (?, ?, ?, ?, ?, ?)`, [id, userId, dto.gameId, dto.mode, dto.playerCount, rating]);
    });
    return { id, gameId: dto.gameId, mode: dto.mode, playerCount: dto.playerCount, rating, queuedAt, botAfterSeconds: 15 };
  }

  async leave(userId: string, ticketId?: string) {
    const result = await this.mysql.execute(`UPDATE matchmaking_tickets SET status = 'cancelled' WHERE user_id = ? AND status = 'queued' ${ticketId ? 'AND id = ?' : ''}`, ticketId ? [userId, ticketId] : [userId]);
    if (!result.affectedRows) throw notFound('No active matchmaking ticket.');
    return { success: true };
  }

  async status(userId: string, ticketId: string) {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, game_id AS gameId, mode, desired_players AS playerCount, status, queued_at AS queuedAt, matched_at AS matchedAt, match_id AS matchId FROM matchmaking_tickets WHERE id = ? AND user_id = ?`, [ticketId, userId]);
    if (!rows[0]) throw notFound('Matchmaking ticket not found.');
    const ticket = { ...rows[0], queuedAt: this.utcIso(rows[0].queuedAt), matchedAt: this.utcIso(rows[0].matchedAt) } as unknown as RowDataPacket & { matchId: string | null };
    if (ticket.matchId) return { ...ticket, match: await this.games.getMatch(ticket.matchId, userId) };
    return ticket;
  }

  @Interval(1000)
  async processQueue(): Promise<void> {
    if (this.processing) return;
    this.processing = true;
    try {
      await this.recoverStaleClaims();
      const tickets = await this.mysql.query<RowDataPacket[]>(`SELECT id, user_id AS userId, game_id AS gameId, mode, desired_players AS desiredPlayers, rating, queued_at AS queuedAt FROM matchmaking_tickets WHERE status = 'queued' ORDER BY queued_at LIMIT 200`);
      const grouped = new Map<string, RowDataPacket[]>();
      for (const ticket of tickets) { const key = `${ticket.gameId}:${ticket.mode}:${ticket.desiredPlayers}`; const list = grouped.get(key) ?? []; list.push(ticket); grouped.set(key, list); }
      for (const [, group] of grouped) {
        const descriptor = this.registry.descriptor(group[0].gameId as string);
        while (group.length >= Number(group[0].desiredPlayers)) {
          const size = Number(group[0].desiredPlayers); const batch = group.splice(0, size); await this.createHumanMatch(batch); }
        for (const ticket of [...group]) {
          if (this.ticketAge(ticket.queuedAt) >= 15_000) { group.splice(group.indexOf(ticket), 1); await this.createBotMatch(ticket, descriptor.maxPlayers >= Number(ticket.desiredPlayers) ? Number(ticket.desiredPlayers) : descriptor.minPlayers); }
        }
      }
    } catch (error) { this.logger.error(error); } finally { this.processing = false; }
  }

  private async createHumanMatch(batch: RowDataPacket[]): Promise<void> {
    const first = batch[0];
    if (!await this.claimTickets(batch)) return;
    let matchCreated = false;
    try {
      const ids = batch.map((ticket) => ticket.userId as string);
      const match = await this.games.createMatch(first.gameId as string, first.mode as 'casual' | 'ranked', ids, Number(first.desiredPlayers), first.id as string);
      matchCreated = true;
      await this.markMatched(batch, match.id as string);
    } catch (error) {
      if (!matchCreated) await this.releaseTickets(batch);
      throw error;
    }
  }

  private async createBotMatch(ticket: RowDataPacket, playerCount: number): Promise<void> {
    if (!await this.claimTickets([ticket])) return;
    let matchCreated = false;
    try {
      const match = await this.games.createMatch(ticket.gameId as string, ticket.mode as 'casual' | 'ranked', [ticket.userId as string], playerCount, ticket.id as string);
      matchCreated = true;
      await this.markMatched([ticket], match.id as string);
    } catch (error) {
      if (!matchCreated) await this.releaseTickets([ticket]);
      throw error;
    }
  }

  private async claimTickets(tickets: RowDataPacket[]): Promise<boolean> {
    try {
      await this.mysql.transaction(async (connection) => {
        for (const ticket of tickets) {
          const [result] = await connection.execute<ResultSetHeader>(`UPDATE matchmaking_tickets SET status = 'matched', matched_at = UTC_TIMESTAMP(3), match_id = NULL WHERE id = ? AND status = 'queued'`, [ticket.id]);
          if (!result.affectedRows) throw new TicketClaimLostError('A matchmaking ticket was already claimed.');
        }
      });
      return true;
    } catch (error) {
      if (error instanceof TicketClaimLostError) return false;
      throw error;
    }
  }

  private async markMatched(tickets: RowDataPacket[], matchId: string): Promise<void> {
    await this.mysql.transaction(async (connection) => {
      for (const ticket of tickets) {
        const [result] = await connection.execute<ResultSetHeader>(`UPDATE matchmaking_tickets SET match_id = ? WHERE id = ? AND status = 'matched' AND match_id IS NULL`, [matchId, ticket.id]);
        if (!result.affectedRows) throw new Error('Could not finalize a matchmaking ticket.');
      }
    });
  }

  private async releaseTickets(tickets: RowDataPacket[]): Promise<void> {
    try {
      const ids = tickets.map((ticket) => ticket.id as string);
      await this.mysql.execute(`UPDATE matchmaking_tickets SET status = 'queued', matched_at = NULL WHERE id IN (${ids.map(() => '?').join(',')}) AND status = 'matched' AND match_id IS NULL`, ids);
    } catch (error) {
      this.logger.error('Could not release claimed matchmaking tickets', error);
    }
  }

  private async recoverStaleClaims(): Promise<void> {
    // A claim is only a short-lived hand-off. Recovery stays well above the
    // normal match-creation latency but does not strand a queue for minutes
    // after a worker dies between claim and finalization.
    await this.mysql.execute(`UPDATE matchmaking_tickets SET status = 'queued', matched_at = NULL WHERE status = 'matched' AND match_id IS NULL AND matched_at < DATE_SUB(UTC_TIMESTAMP(3), INTERVAL 30 SECOND)`);
  }

  private ticketAge(value: unknown): number {
    const parsed = Date.parse(this.utcIso(value) ?? '');
    return Number.isFinite(parsed) ? Date.now() - parsed : 0;
  }

  private utcIso(value: unknown): string | null {
    if (value === null || value === undefined) return null;
    if (value instanceof Date) return value.toISOString();
    const raw = String(value);
    const normalized = raw.includes('T') ? raw : `${raw.replace(' ', 'T')}Z`;
    const parsed = Date.parse(normalized);
    return Number.isFinite(parsed) ? new Date(parsed).toISOString() : raw;
  }

  private async rating(userId: string, gameId: string): Promise<number> {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT pr.rating FROM player_ratings pr JOIN seasons s ON s.id = pr.season_id AND s.status = 'active' WHERE pr.user_id = ? AND pr.game_id = ? LIMIT 1`, [userId, gameId]);
    return Number(rows[0]?.rating ?? 1000);
  }
}
