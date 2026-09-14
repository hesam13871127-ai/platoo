import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { EventEmitter } from 'node:events';
import { randomInt as cryptoRandomInt, randomUUID } from 'node:crypto';
import { PoolConnection, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, forbidden, invalid, notFound } from '../common/errors';
import { GameActionDto } from './game.dto';
import { GameRegistry } from './game.registry';
import { Action, GamePlayer, GameState } from './game.types';
import { RankingService } from '../ranking/ranking.service';

interface MatchRow extends RowDataPacket { id: string; game_id: string; mode: 'casual' | 'ranked' | 'private'; status: 'waiting' | 'active' | 'finished' | 'cancelled'; max_players: number; state: GameState; revision: number; winner_ids: string[] | null; loser_ids: string[] | null; draw: number; created_at: string; started_at: string | null; finished_at: string | null; updated_at: string; }

const SWEEP_INTERVAL_MS = 10000;
const SWEEP_CANDIDATE_IDLE_SECONDS = 30;
const STUCK_MATCH_MS = 15 * 60 * 1000;
const PLACING_TIMEOUT_MS = 10 * 60 * 1000;
const RANKED_IDLE_STRIKES = 3;
interface MatchPlayerRow extends RowDataPacket { id: string; userId: string; displayName: string; avatarUrl: string | null; seat: number; team: number | null; isBot: number; result: string; ratingBefore: number | null; ratingAfter: number | null; }

@Injectable()
export class GameService {
  private readonly logger = new Logger(GameService.name);
  private readonly updates = new EventEmitter();
  private readonly botRuns = new Set<string>();
  private sweeping = false;

  constructor(private readonly mysql: MysqlService, private readonly registry: GameRegistry, private readonly ranking: RankingService) {}

  onMatchUpdated(listener: (matchId: string) => void): () => void {
    this.updates.on('match.updated', listener);
    return () => this.updates.off('match.updated', listener);
  }

  async listGames() {
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT id, is_active AS isActive FROM games`);
    const active = new Map(rows.map((row) => [row.id as string, Boolean(row.isActive)]));
    return this.registry.list().filter((game) => active.get(game.id) !== false);
  }

  async createMatch(gameId: string, mode: 'casual' | 'ranked' | 'private', playerIds: string[], desiredPlayers?: number, idempotencyKey?: string) {
    const descriptor = this.registry.descriptor(gameId);
    const activeRows = await this.mysql.query<RowDataPacket[]>(`SELECT is_active AS isActive FROM games WHERE id = ?`, [gameId]);
    if (!activeRows[0] || !Boolean(activeRows[0].isActive)) throw notFound('This game is currently unavailable.');
    const unique = [...new Set(playerIds)];
    if (!unique.length) throw invalid('A match needs at least one player.');
    if (idempotencyKey) {
      const existing = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM matches WHERE id = ? LIMIT 1`, [idempotencyKey]);
      if (existing[0]) return this.getMatch(existing[0].id as string, unique[0]);
    }
    const users = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM users WHERE id IN (${unique.map(() => '?').join(',')}) AND status = 'active'`, unique);
    if (users.length !== unique.length) throw notFound('One or more players could not be found.');
    if (unique.length < descriptor.minPlayers && mode === 'private') throw invalid(`This game needs at least ${descriptor.minPlayers} players.`);
    const playerCount = Math.min(Math.max(desiredPlayers ?? descriptor.minPlayers, descriptor.minPlayers), descriptor.maxPlayers);
    if (unique.length > playerCount) throw invalid('Too many players for this match.');
    const botCount = playerCount - unique.length;
    const players: GamePlayer[] = unique.map((id, seat) => ({ id, seat, isBot: false, team: descriptor.supportsTeams ? seat % 2 : undefined }));
    for (let i = 0; i < botCount; i += 1) players.push({ id: await this.createBotUser(i), seat: players.length, isBot: true, team: descriptor.supportsTeams ? players.length % 2 : undefined });
    const engine = this.registry.engine(gameId);
    const state = engine.create(players);
    const matchId = idempotencyKey ?? randomUUID();
    await this.mysql.transaction(async (connection) => {
      await connection.execute(`INSERT INTO matches (id, game_id, mode, status, max_players, state, started_at) VALUES (?, ?, ?, 'active', ?, ?, UTC_TIMESTAMP(3))`, [matchId, gameId, mode, players.length, JSON.stringify(state)]);
      for (const player of players) await connection.execute(`INSERT INTO match_players (match_id, user_id, seat, team, is_bot) VALUES (?, ?, ?, ?, ?)`, [matchId, player.id, player.seat, player.team ?? null, player.isBot]);
      const conversationId = randomUUID();
      await connection.execute(`INSERT INTO conversations (id, type, match_id, title) VALUES (?, 'match', ?, ?)`, [conversationId, matchId, descriptor.name]);
      for (const player of players.filter((candidate) => !candidate.isBot)) await connection.execute(`INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?)`, [conversationId, player.id]);
    });
    const result = await this.getMatch(matchId, unique[0]);
    void this.runBotTurns(matchId).catch((error: unknown) => this.logger.error(`Bot turn failed for ${matchId}`, error));
    return result;
  }

  async getMatch(matchId: string, viewerId: string) {
    const rows = await this.mysql.query<MatchRow[]>(`SELECT * FROM matches WHERE id = ? LIMIT 1`, [matchId]);
    if (!rows[0]) throw notFound('Match not found.');
    const players = await this.players(matchId);
    if (!players.some((player) => player.userId === viewerId && !player.isBot)) throw forbidden('You are not a player in this match.');
    const conversations = await this.mysql.query<RowDataPacket[]>(`SELECT id FROM conversations WHERE match_id = ? LIMIT 1`, [matchId]);
    return { ...this.publicMatch(rows[0], players, viewerId), conversationId: conversations[0]?.id ?? null };
  }

  async act(matchId: string, actorId: string, dto: GameActionDto, internalBot = false, idleStrike?: number) {
    let completed = false;
    let resultViewerId = actorId;
    let result: ReturnType<GameService['publicMatch']> | undefined;
    await this.mysql.transaction(async (connection) => {
      const [matchRows] = await connection.query<MatchRow[]>(`SELECT * FROM matches WHERE id = ? LIMIT 1 FOR UPDATE`, [matchId]);
      const match = matchRows[0];
      if (!match) throw notFound('Match not found.');
      const players = await this.playersOnConnection(connection, matchId);
      resultViewerId = players.find((player) => !Boolean(player.isBot))?.userId ?? actorId;
      const actor = players.find((player) => player.userId === actorId);
      if (!actor || (!internalBot && actor.isBot)) throw forbidden('You are not a player in this match.');
      if (match.status !== 'active') throw conflict('This match is no longer active.');
      const expectedRevision = (dto as unknown as { revision?: unknown }).revision;
      if (expectedRevision !== undefined && (!Number.isInteger(expectedRevision) || Number(expectedRevision) !== Number(match.revision))) throw conflict('The table changed before this move arrived. Refresh the match and try again.');
      const enginePlayers: GamePlayer[] = players.map((player) => ({ id: player.userId, isBot: Boolean(player.isBot), seat: player.seat, team: player.team ?? undefined }));
      const engine = this.registry.engine(match.game_id);
      const currentState = this.parseState(match.state);
      const updated = engine.apply(currentState, actorId, dto as Action, enginePlayers);
      if (idleStrike !== undefined) {
        const strikes = { ...((updated._idleStrikes as Record<string, number> | undefined) ?? {}) };
        strikes[actorId] = idleStrike;
        updated._idleStrikes = strikes;
      } else if (!internalBot && updated._idleStrikes !== undefined) {
        const strikes = { ...((updated._idleStrikes as Record<string, number> | undefined) ?? {}) };
        delete strikes[actorId];
        if (Object.keys(strikes).length) updated._idleStrikes = strikes; else delete updated._idleStrikes;
      }
      const outcome = engine.outcome(updated, enginePlayers);
      const nextRevision = Number(match.revision) + 1;
      const status = outcome.finished ? 'finished' : 'active';
      await connection.execute(`UPDATE matches SET state = ?, revision = ?, status = ?, winner_ids = ?, loser_ids = ?, draw = ?, finished_at = IF(? = 'finished', UTC_TIMESTAMP(3), NULL) WHERE id = ?`, [JSON.stringify(updated), nextRevision, status, JSON.stringify(outcome.winnerIds), JSON.stringify(outcome.loserIds), outcome.draw, status, matchId]);
      await connection.execute(`INSERT INTO match_moves (match_id, revision, user_id, action, payload, state_after) VALUES (?, ?, ?, ?, ?, ?)`, [matchId, nextRevision, actorId, dto.type, JSON.stringify(dto), JSON.stringify(updated)]);
      if (outcome.finished) {
        for (const player of enginePlayers) {
          const result = outcome.draw ? 'draw' : outcome.winnerIds.includes(player.id) ? 'win' : 'loss';
          await connection.execute(`UPDATE match_players SET result = ? WHERE match_id = ? AND user_id = ?`, [result, matchId, player.id]);
        }
        completed = true;
      }
      const refreshed = { ...match, state: updated, revision: nextRevision, status, winner_ids: outcome.winnerIds, loser_ids: outcome.loserIds, draw: outcome.draw ? 1 : 0 } as MatchRow;
      const visiblePlayers = outcome.finished ? players.map((player) => ({ ...player, result: outcome.draw ? 'draw' : outcome.winnerIds.includes(player.userId) ? 'win' : 'loss' })) : players;
      result = this.publicMatch(refreshed, visiblePlayers, resultViewerId);
    });
    if (completed) {
      try {
        result = await this.settleCompletedMatch(matchId, resultViewerId);
      } catch (error: unknown) {
        this.logger.error(`Match completion side effects failed for ${matchId}`, error);
      }
    }
    if (result) this.updates.emit('match.updated', matchId);
    if (result && !internalBot) void this.runBotTurns(matchId).catch((error: unknown) => this.logger.error(`Bot turn failed for ${matchId}`, error));
    return result;
  }

  async resign(matchId: string, actorId: string) {
    let result: ReturnType<GameService['publicMatch']> | undefined;
    await this.mysql.transaction(async (connection) => {
      const [matchRows] = await connection.query<MatchRow[]>(`SELECT * FROM matches WHERE id = ? LIMIT 1 FOR UPDATE`, [matchId]);
      const match = matchRows[0];
      if (!match) throw notFound('Match not found.');
      if (match.status !== 'active') throw conflict('This match is no longer active.');
      const players = await this.playersOnConnection(connection, matchId);
      if (!players.some((player) => player.userId === actorId && !player.isBot)) throw forbidden('You are not a player in this match.');
      const walkover = await this.walkoverOnConnection(connection, match, players, actorId, 'resign');
      const refreshed = { ...match, status: 'finished', revision: walkover.revision, winner_ids: walkover.winnerIds, loser_ids: walkover.loserIds, draw: 0 } as MatchRow;
      const visiblePlayers = players.map((player) => ({ ...player, result: walkover.winnerIds.includes(player.userId) ? 'win' : 'loss' }));
      result = this.publicMatch(refreshed, visiblePlayers, actorId);
    });
    if (result) {
      try {
        result = await this.settleCompletedMatch(matchId, actorId);
      } catch (error: unknown) {
        this.logger.error(`Match completion side effects failed for ${matchId}`, error);
      }
      this.updates.emit('match.updated', matchId);
    }
    return result;
  }

  async replay(matchId: string, viewerId: string) {
    await this.getMatch(matchId, viewerId);
    const rows = await this.mysql.query<RowDataPacket[]>(`SELECT revision, user_id AS userId, action, payload, state_after AS stateAfter, created_at AS createdAt FROM match_moves WHERE match_id = ? ORDER BY revision`, [matchId]);
    return rows.map((row) => ({ ...row, payload: typeof row.payload === 'string' ? JSON.parse(row.payload) : row.payload, stateAfter: typeof row.stateAfter === 'string' ? JSON.parse(row.stateAfter) : row.stateAfter }));
  }

  private async settleCompletedMatch(matchId: string, viewerId: string): Promise<ReturnType<GameService['publicMatch']>> {
    let lastError: unknown;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        await this.ranking.recordMatch(matchId);
        return await this.getMatch(matchId, viewerId) as ReturnType<GameService['publicMatch']>;
      } catch (error: unknown) {
        lastError = error;
        if (attempt < 2) await this.sleep(250 * (attempt + 1));
      }
    }
    throw lastError instanceof Error ? lastError : new Error('Could not settle completed match.');
  }

  private async runBotTurns(matchId: string): Promise<void> {
    if (this.botRuns.has(matchId)) return;
    this.botRuns.add(matchId);
    let shouldRetry = false;
    let consecutiveErrors = 0;
    try {
      // Eight-player Trivia Battle can legitimately need eighty bot answers;
      // keep the guard above any shipped match's maximum automated turn count.
      for (let count = 0; count < 256; count += 1) {
        let rows: MatchRow[];
        try {
          rows = await this.mysql.query<MatchRow[]>(`SELECT * FROM matches WHERE id = ? LIMIT 1`, [matchId]);
          if (!rows[0] || rows[0].status !== 'active') return;
          const playerRows = await this.players(matchId);
          const currentState = this.parseState(rows[0].state);
          const currentId = typeof currentState.turnPlayerId === 'string' ? currentState.turnPlayerId : null;
          const bot = currentId ? playerRows.find((player) => player.userId === currentId && Boolean(player.isBot)) : rows[0].game_id === 'sea_battle' ? playerRows.find((player) => Boolean(player.isBot) && ((currentState.fleets as unknown[][][])[player.seat]?.length ?? 0) < 5) : undefined;
          if (!bot) return;
          await this.sleep(650 + cryptoRandomInt(850));
          const enginePlayers = playerRows.map((player) => ({ id: player.userId, isBot: Boolean(player.isBot), seat: player.seat, team: player.team ?? undefined }));
          const action = this.registry.engine(rows[0].game_id).botAction(currentState, bot.userId, enginePlayers);
          await this.act(matchId, bot.userId, action as GameActionDto, true);
          consecutiveErrors = 0;
        } catch (error: unknown) {
          shouldRetry = true;
          consecutiveErrors += 1;
          this.logger.debug(`Bot turn for ${matchId} will be retried (${consecutiveErrors})`, error instanceof Error ? error.message : String(error));
          if (consecutiveErrors >= 3) break;
          await this.sleep(250);
        }
      }
      shouldRetry = true;
    } catch (error: unknown) {
      shouldRetry = true;
      this.logger.error(`Bot turn loop failed for ${matchId}`, error);
    } finally {
      this.botRuns.delete(matchId);
    }
    if (shouldRetry) setTimeout(() => { void this.runBotTurns(matchId).catch((error: unknown) => this.logger.error(`Bot turn failed for ${matchId}`, error)); }, 500);
  }

  @Interval(SWEEP_INTERVAL_MS)
  async sweepStaleMatches(): Promise<void> {
    if (this.sweeping) return;
    this.sweeping = true;
    try {
      const rows = await this.mysql.query<MatchRow[]>(`SELECT * FROM matches WHERE status = 'active' AND updated_at < DATE_SUB(UTC_TIMESTAMP(3), INTERVAL ? SECOND) LIMIT 50`, [SWEEP_CANDIDATE_IDLE_SECONDS]);
      for (const row of rows) {
        try {
          await this.sweepMatch(row.id);
        } catch (error: unknown) {
          this.logger.warn(`Stale-match sweep failed for ${row.id}`, error instanceof Error ? error.message : String(error));
        }
      }
    } catch (error: unknown) {
      this.logger.warn('Stale-match sweep failed', error instanceof Error ? error.message : String(error));
    } finally {
      this.sweeping = false;
    }
  }

  private async sweepMatch(matchId: string): Promise<void> {
    const rows = await this.mysql.query<MatchRow[]>(`SELECT * FROM matches WHERE id = ? LIMIT 1`, [matchId]);
    const match = rows[0];
    if (!match || match.status !== 'active') return;
    const idleMs = Date.now() - new Date(String(match.updated_at)).getTime();
    if (!Number.isFinite(idleMs) || idleMs < 0) return;
    const state = this.parseState(match.state);
    if (idleMs >= STUCK_MATCH_MS) {
      await this.cancelStaleMatch(match.id, 'stuck');
      return;
    }
    const turnId = typeof state.turnPlayerId === 'string' ? state.turnPlayerId : null;
    if (!turnId) {
      if (match.game_id === 'sea_battle' && state.phase === 'placing' && idleMs >= PLACING_TIMEOUT_MS) await this.cancelStaleMatch(match.id, 'placing-timeout');
      return;
    }
    if (idleMs < this.registry.turnSeconds(match.game_id, state) * 1000) return;
    const playerRows = await this.players(match.id);
    const turnPlayer = playerRows.find((player) => player.userId === turnId);
    if (!turnPlayer) return;
    if (turnPlayer.isBot) {
      void this.runBotTurns(match.id).catch((error: unknown) => this.logger.error(`Bot turn failed for ${match.id}`, error));
      return;
    }
    const strikes = (state._idleStrikes as Record<string, number> | undefined) ?? {};
    const count = (strikes[turnId] ?? 0) + 1;
    if (match.mode === 'ranked' && count >= RANKED_IDLE_STRIKES) {
      await this.forfeitIdlePlayer(match.id, turnId);
      return;
    }
    await this.autoMoveForIdlePlayer(match.id, match.game_id, turnId, count);
  }

  private async autoMoveForIdlePlayer(matchId: string, gameId: string, userId: string, count: number): Promise<void> {
    const rows = await this.mysql.query<MatchRow[]>(`SELECT * FROM matches WHERE id = ? LIMIT 1`, [matchId]);
    const match = rows[0];
    if (!match || match.status !== 'active') return;
    const state = this.parseState(match.state);
    if (state.turnPlayerId !== userId) return;
    const playerRows = await this.players(matchId);
    const enginePlayers: GamePlayer[] = playerRows.map((player) => ({ id: player.userId, isBot: Boolean(player.isBot), seat: player.seat, team: player.team ?? undefined }));
    let action: Action;
    try {
      action = this.registry.engine(gameId).botAction(state, userId, enginePlayers);
    } catch {
      return;
    }
    try {
      await this.act(matchId, userId, action as GameActionDto, true, count);
    } catch {
      return;
    }
    void this.runBotTurns(matchId).catch((error: unknown) => this.logger.error(`Bot turn failed for ${matchId}`, error));
  }

  private async forfeitIdlePlayer(matchId: string, userId: string): Promise<void> {
    let forfeited = false;
    await this.mysql.transaction(async (connection) => {
      const [matchRows] = await connection.query<MatchRow[]>(`SELECT * FROM matches WHERE id = ? LIMIT 1 FOR UPDATE`, [matchId]);
      const match = matchRows[0];
      if (!match || match.status !== 'active') return;
      const state = this.parseState(match.state);
      if (state.turnPlayerId !== userId || match.mode !== 'ranked') return;
      const strikes = (state._idleStrikes as Record<string, number> | undefined) ?? {};
      if ((strikes[userId] ?? 0) + 1 < RANKED_IDLE_STRIKES) return;
      const players = await this.playersOnConnection(connection, matchId);
      await this.walkoverOnConnection(connection, match, players, userId, 'forfeit');
      forfeited = true;
    });
    if (forfeited) {
      try {
        await this.settleCompletedMatch(matchId, userId);
      } catch (error: unknown) {
        this.logger.error(`Match completion side effects failed for ${matchId}`, error);
      }
      this.updates.emit('match.updated', matchId);
    }
  }

  private async cancelStaleMatch(matchId: string, reason: 'stuck' | 'placing-timeout'): Promise<void> {
    let cancelled = false;
    await this.mysql.transaction(async (connection) => {
      const [matchRows] = await connection.query<MatchRow[]>(`SELECT * FROM matches WHERE id = ? LIMIT 1 FOR UPDATE`, [matchId]);
      const match = matchRows[0];
      if (!match || match.status !== 'active') return;
      const idleMs = Date.now() - new Date(String(match.updated_at)).getTime();
      const threshold = reason === 'stuck' ? STUCK_MATCH_MS : PLACING_TIMEOUT_MS;
      if (!Number.isFinite(idleMs) || idleMs < threshold) return;
      if (reason === 'placing-timeout') {
        const state = this.parseState(match.state);
        if (match.game_id !== 'sea_battle' || state.phase !== 'placing' || typeof state.turnPlayerId === 'string') return;
      }
      await connection.execute(`UPDATE matches SET status = 'cancelled', finished_at = UTC_TIMESTAMP(3) WHERE id = ?`, [matchId]);
      await connection.execute(`INSERT INTO match_events (match_id, event_type, actor_id, payload) VALUES (?, 'match.cancelled', NULL, ?)`, [matchId, JSON.stringify({ reason })]);
      cancelled = true;
    });
    if (cancelled) this.updates.emit('match.updated', matchId);
  }

  private async walkoverOnConnection(connection: PoolConnection, match: MatchRow, players: MatchPlayerRow[], resignerId: string, action: 'resign' | 'forfeit'): Promise<{ revision: number; winnerIds: string[]; loserIds: string[] }> {
    const enginePlayers: GamePlayer[] = players.map((player) => ({ id: player.userId, isBot: Boolean(player.isBot), seat: player.seat, team: player.team ?? undefined }));
    const otherHumans = enginePlayers.filter((player) => !player.isBot && player.id !== resignerId);
    const winnerIds = otherHumans.length ? otherHumans.map((player) => player.id) : enginePlayers.filter((player) => player.isBot).map((player) => player.id);
    const nextRevision = Number(match.revision) + 1;
    await connection.execute(`UPDATE matches SET status = 'finished', revision = ?, winner_ids = ?, loser_ids = ?, draw = 0, finished_at = UTC_TIMESTAMP(3) WHERE id = ?`, [nextRevision, JSON.stringify(winnerIds), JSON.stringify([resignerId]), match.id]);
    for (const player of enginePlayers) {
      const result = winnerIds.includes(player.id) ? 'win' : 'loss';
      await connection.execute(`UPDATE match_players SET result = ?, left_at = IF(user_id = ?, UTC_TIMESTAMP(3), left_at) WHERE match_id = ? AND user_id = ?`, [result, resignerId, match.id, player.id]);
    }
    await connection.execute(`INSERT INTO match_moves (match_id, revision, user_id, action, payload, state_after) VALUES (?, ?, ?, ?, ?, ?)`, [match.id, nextRevision, resignerId, action, JSON.stringify({ type: action }), JSON.stringify(this.parseState(match.state))]);
    return { revision: nextRevision, winnerIds, loserIds: [resignerId] };
  }

  private async players(matchId: string): Promise<MatchPlayerRow[]> {
    return this.mysql.query<MatchPlayerRow[]>(`SELECT mp.user_id AS userId, u.display_name AS displayName, u.avatar_url AS avatarUrl, mp.seat, mp.team, mp.is_bot AS isBot, mp.result, mp.rating_before AS ratingBefore, mp.rating_after AS ratingAfter FROM match_players mp JOIN users u ON u.id = mp.user_id WHERE mp.match_id = ? ORDER BY mp.seat`, [matchId]);
  }

  private async playersOnConnection(connection: PoolConnection, matchId: string): Promise<MatchPlayerRow[]> {
    const [rows] = await connection.query<MatchPlayerRow[]>(`SELECT mp.user_id AS userId, u.display_name AS displayName, u.avatar_url AS avatarUrl, mp.seat, mp.team, mp.is_bot AS isBot, mp.result, mp.rating_before AS ratingBefore, mp.rating_after AS ratingAfter FROM match_players mp JOIN users u ON u.id = mp.user_id WHERE mp.match_id = ? ORDER BY mp.seat`, [matchId]);
    return rows;
  }

  private publicMatch(match: MatchRow, players: MatchPlayerRow[], viewerId: string) {
    const parsed = this.parseState(match.state);
    const state = this.sanitizeState(match.game_id, parsed, players, viewerId, match.status);
    const viewer = players.find((player) => player.userId === viewerId);
    const reward = match.status === 'finished' && viewer && viewer.result !== 'pending' && viewer.ratingBefore !== null ? { result: viewer.result, xp: viewer.result === 'win' ? 100 : viewer.result === 'draw' || Boolean(match.draw) ? 60 : 40, coins: viewer.result === 'win' ? 100 : viewer.result === 'draw' || Boolean(match.draw) ? 50 : 25 } : null;
    const turnSeconds = match.status === 'active' ? this.registry.turnSeconds(match.game_id, parsed) : 0;
    const updatedMs = new Date(String(match.updated_at)).getTime();
    const turnDeadline = match.status === 'active' && typeof parsed.turnPlayerId === 'string' && Number.isFinite(updatedMs) ? new Date(updatedMs + turnSeconds * 1000).toISOString() : null;
    return { id: match.id, gameId: match.game_id, mode: match.mode, status: match.status, revision: Number(match.revision), viewerSeat: viewer?.seat ?? 0, state, players: players.map((player) => ({ id: player.userId, displayName: player.displayName, avatarUrl: player.avatarUrl, seat: player.seat, team: player.team, isBot: false, result: player.result, ratingBefore: player.ratingBefore, ratingAfter: player.ratingAfter })), winnerIds: this.parseJsonArray(match.winner_ids), loserIds: this.parseJsonArray(match.loser_ids), draw: Boolean(match.draw), turnSeconds, turnDeadline, serverTime: new Date().toISOString(), reward, createdAt: match.created_at, startedAt: match.started_at, finishedAt: match.finished_at };
  }

  private sanitizeState(gameId: string, original: GameState, players: MatchPlayerRow[], viewerId: string, status: string): GameState {
    const state = JSON.parse(JSON.stringify(original)) as GameState;
    delete state._idleStrikes;
    if ((gameId === 'hearts' || gameId === 'spades') && Array.isArray(state.hands)) { const viewerSeat = players.find((player) => player.userId === viewerId)?.seat ?? 0; state.hands = (state.hands as unknown[]).map((hand, index) => index === viewerSeat || status === 'finished' ? hand : []); }
    if (gameId === 'ocho' && Array.isArray(state.hands)) { const viewerSeat = players.find((player) => player.userId === viewerId)?.seat ?? 0; state.hands = (state.hands as unknown[]).map((hand, index) => index === viewerSeat || status === 'finished' ? hand : []); delete state.wildFourLegal; }
    if (gameId === 'sea_battle' && Array.isArray(state.boards)) { const viewerSeat = players.find((player) => player.userId === viewerId)?.seat ?? 0; state.boards = (state.boards as unknown[]).map((board, index) => index === viewerSeat || status === 'finished' ? board : (board as number[][]).map((row) => row.map((cell) => cell < 0 ? -1 : 0))); }
    if (gameId === 'bingo' && Array.isArray(state.cards)) {
      const viewerSeat = players.find((player) => player.userId === viewerId)?.seat ?? 0;
      if (status !== 'finished') {
        state.cards = (state.cards as unknown[]).map((card, index) => index === viewerSeat ? card : { values: [], marked: [] });
        if (Array.isArray(state.bag)) state.bag = [];
      }
    }
    if (gameId === 'dominoes' && Array.isArray(state.hands)) {
      const viewerSeat = players.find((player) => player.userId === viewerId)?.seat ?? 0;
      state.handSizes = (state.hands as unknown[]).map((hand) => Array.isArray(hand) ? hand.length : 0);
      if (status !== 'finished') {
        state.hands = (state.hands as unknown[]).map((hand, index) => index === viewerSeat ? hand : []);
        if (Array.isArray(state.boneyard)) state.boneyard = state.boneyard.map(() => null);
        state.lastDrawn = null;
      }
    }
    if (gameId === 'werewolf' && Array.isArray(state.roles)) {
      const viewerSeat = players.find((player) => player.userId === viewerId)?.seat ?? 0;
      if (status !== 'finished') {
        state.roles = (state.roles as unknown[]).map((role, index) => index === viewerSeat ? role : 'hidden');
        if (Array.isArray(state.nightTargets)) state.nightTargets = (state.nightTargets as unknown[]).map((target, index) => index === viewerSeat ? target : null);
        if (Array.isArray(state.votes)) state.votes = (state.votes as unknown[]).map((vote, index) => index === viewerSeat ? vote : null);
        if (Array.isArray(state.seerResults)) state.seerResults = (state.seerResults as unknown[]).map((result, index) => index === viewerSeat ? result : null);
      }
    }
    if (gameId === 'sketch_guess' && typeof state.prompt === 'string' && status !== 'finished') {
      const viewerSeat = players.find((player) => player.userId === viewerId)?.seat ?? 0;
      if (Number(state.drawerIndex) !== viewerSeat) state.prompt = null;
    }
    if (gameId === 'trivia_battle' && Array.isArray(state.questionBank)) {
      const viewerSeat = players.find((player) => player.userId === viewerId)?.seat ?? 0;
      const bank = state.questionBank as Array<{ prompt: string; options: string[]; category: string; answer?: number }>;
      const question = bank[Number(state.questionIndex)];
      if (question) state.currentQuestion = { prompt: question.prompt, options: question.options, category: question.category };
      if (status !== 'finished') {
        state.answers = Array.isArray(state.answers) ? (state.answers as unknown[]).map((answer, index) => index === viewerSeat ? answer : null) : [];
        delete state.questionBank;
      }
    }
    if (gameId === 'memory_race' && Array.isArray(state.values)) { state.values = (state.values as unknown[]).map((value, index) => (state.revealed as boolean[])[index] || (state.matched as boolean[])[index] ? value : null); }
    return state;
  }

  private parseState(value: GameState | string): GameState { return typeof value === 'string' ? JSON.parse(value) as GameState : value; }
  private parseJsonArray(value: string[] | string | null): string[] {
    if (!value) return [];
    const parsed = Array.isArray(value) ? value : JSON.parse(value) as unknown;
    return Array.isArray(parsed) ? parsed.map((item) => String(item)) : [];
  }

  private async createBotUser(ordinal: number): Promise<string> {
    const id = randomUUID();
    const username = `player_${id.replace(/-/g, '').slice(0, 20)}`;
    const names = ['Ari', 'Mina', 'Noah', 'Sami', 'Nika', 'Milo', 'Lina', 'Raya'];
    const displayName = names[(cryptoRandomInt(names.length) + ordinal) % names.length];
    await this.mysql.execute(`INSERT INTO users (id, username, display_name, role, status) VALUES (?, ?, ?, 'player', 'active')`, [id, username, displayName]);
    await this.mysql.execute(`INSERT INTO wallets (user_id, coins, pips) VALUES (?, 0, 0)`, [id]);
    return id;
  }

  private sleep(milliseconds: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, milliseconds));
  }
}
