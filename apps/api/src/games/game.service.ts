import { Injectable, Logger } from '@nestjs/common';
import { EventEmitter } from 'node:events';
import { randomInt as cryptoRandomInt, randomUUID } from 'node:crypto';
import { PoolConnection, RowDataPacket } from 'mysql2/promise';
import { MysqlService } from '../database/mysql.service';
import { conflict, forbidden, invalid, notFound } from '../common/errors';
import { GameActionDto } from './game.dto';
import { GameRegistry } from './game.registry';
import { Action, GamePlayer, GameState } from './game.types';
import { RankingService } from '../ranking/ranking.service';

interface MatchRow extends RowDataPacket { id: string; game_id: string; mode: 'casual' | 'ranked' | 'private'; status: 'waiting' | 'active' | 'finished' | 'cancelled'; max_players: number; state: GameState; revision: number; winner_ids: string[] | null; loser_ids: string[] | null; draw: number; created_at: string; started_at: string | null; finished_at: string | null; }
interface MatchPlayerRow extends RowDataPacket { id: string; userId: string; displayName: string; avatarUrl: string | null; seat: number; team: number | null; isBot: number; result: string; ratingBefore: number | null; ratingAfter: number | null; }

@Injectable()
export class GameService {
  private readonly logger = new Logger(GameService.name);
  private readonly updates = new EventEmitter();
  private readonly botRuns = new Set<string>();

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

  async act(matchId: string, actorId: string, dto: GameActionDto, internalBot = false) {
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
      for (let count = 0; count < 64; count += 1) {
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
    return { id: match.id, gameId: match.game_id, mode: match.mode, status: match.status, revision: Number(match.revision), viewerSeat: viewer?.seat ?? 0, state, players: players.map((player) => ({ id: player.userId, displayName: player.displayName, avatarUrl: player.avatarUrl, seat: player.seat, team: player.team, isBot: false, result: player.result, ratingBefore: player.ratingBefore, ratingAfter: player.ratingAfter })), winnerIds: this.parseJsonArray(match.winner_ids), loserIds: this.parseJsonArray(match.loser_ids), draw: Boolean(match.draw), reward, createdAt: match.created_at, startedAt: match.started_at, finishedAt: match.finished_at };
  }

  private sanitizeState(gameId: string, original: GameState, players: MatchPlayerRow[], viewerId: string, status: string): GameState {
    const state = JSON.parse(JSON.stringify(original)) as GameState;
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
