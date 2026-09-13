import { MatchmakingService } from '../src/matchmaking/matchmaking.service';
import { RankingService } from '../src/ranking/ranking.service';
import { GameService } from '../src/games/game.service';

const executeResult = [{ affectedRows: 1 }, []] as any;

describe('core game system integration', () => {
  it('claims a timed-out queue ticket before creating its invisible bot match', async () => {
    const ticket = { id: 'ticket-1', userId: 'user-1', gameId: 'chess', mode: 'ranked', desiredPlayers: 2, rating: 1000, queuedAt: new Date(Date.now() - 16_000).toISOString() };
    const connection = { execute: jest.fn().mockResolvedValue(executeResult) };
    const mysql = {
      execute: jest.fn().mockResolvedValue(executeResult),
      query: jest.fn().mockResolvedValue([ticket]),
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
    };
    const games = { createMatch: jest.fn().mockResolvedValue({ id: 'ticket-1' }) };
    const registry = { descriptor: jest.fn().mockReturnValue({ minPlayers: 2, maxPlayers: 2 }) };
    const service = new MatchmakingService(mysql as any, games as any, registry as any);

    await service.processQueue();

    expect(games.createMatch).toHaveBeenCalledWith('chess', 'ranked', ['user-1'], 2, 'ticket-1');
    expect(connection.execute).toHaveBeenCalledTimes(2);
    expect(connection.execute.mock.calls[0][0]).toContain("status = 'matched'");
    expect(connection.execute.mock.calls[1][0]).toContain('match_id = ?');
  });

  it('applies a finished human result and makes a repeated completion a no-op', async () => {
    let processed = false;
    const executed: Array<{ sql: string; params: unknown[] }> = [];
    const connection = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('FROM matches')) return [[{ id: 'match-1', gameId: 'ocho', mode: 'ranked', draw: 0 }]];
        if (sql.includes('FROM match_players')) return [[{ userId: 'user-1', result: 'win', isBot: 0, ratingBefore: processed ? 1000 : null }, { userId: 'bot-1', result: 'loss', isBot: 1, ratingBefore: null }]];
        if (sql.includes('FROM seasons')) return [[{ id: 'season-1' }]];
        if (sql.includes('FROM player_ratings')) return [[]];
        if (sql.includes('FROM wallet_transactions')) return [processed ? [{ id: 'reward-1' }] : []];
        if (sql.includes('FROM wallets')) return [[{ coins: 1000 }]];
        if (sql.includes('FROM users')) return [[{ experience: 0, level: 1 }]];
        return [[]];
      }),
      execute: jest.fn(async (sql: string, params: unknown[]) => { executed.push({ sql, params }); return executeResult; }),
    };
    const mysql = { transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)) };
    const service = new RankingService(mysql as any);

    await service.recordMatch('match-1');
    processed = true;
    await service.recordMatch('match-1');

    expect(mysql.transaction).toHaveBeenCalledTimes(2);
    expect(executed.some(({ sql }) => sql.includes("type, reference_type, reference_id, idempotency_key"))).toBe(true);
    expect(executed.some(({ sql, params }) => sql.includes('UPDATE wallets SET coins') && params[0] === 1100)).toBe(true);
    expect(executed.some(({ sql, params }) => sql.includes('UPDATE users SET experience') && params[0] === 100)).toBe(true);
    expect(executed.filter(({ sql }) => sql.includes('game_stats')).length).toBe(1);
  });

  it('recovers a stale matchmaking claim before grouping new queue tickets', async () => {
    const mysql = {
      execute: jest.fn().mockResolvedValue(executeResult),
      query: jest.fn().mockResolvedValue([]),
      transaction: jest.fn(),
    };
    const service = new MatchmakingService(mysql as any, {} as any, { descriptor: jest.fn() } as any);

    await service.processQueue();

    expect(mysql.execute).toHaveBeenCalledWith(expect.stringContaining("status = 'queued'"));
    expect(mysql.execute.mock.calls[0][0]).toContain('matched_at < DATE_SUB');
  });

  it('serializes queue joins so one user cannot create duplicate active tickets', async () => {
    const connection = {
      query: jest.fn()
        .mockResolvedValueOnce([[], []])
        .mockResolvedValueOnce([[{ id: 'existing-ticket' }], []]),
      execute: jest.fn(),
    };
    const mysql = {
      query: jest.fn()
        .mockResolvedValueOnce([{ isActive: 1 }])
        .mockResolvedValueOnce([]),
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
    };
    const service = new MatchmakingService(mysql as any, {} as any, { descriptor: jest.fn().mockReturnValue({ minPlayers: 2, maxPlayers: 2 }) } as any);

    await expect(service.join('user-1', { gameId: 'chess', mode: 'ranked', playerCount: 2 })).rejects.toThrow('already in a matchmaking queue');
    expect(connection.execute).not.toHaveBeenCalled();
  });

  it('does not apply an action from an obsolete client revision', async () => {
    const connection = {
      query: jest.fn(async (sql: string) => {
        if (sql.includes('FROM matches')) return [[{ id: 'match-1', game_id: 'four_in_a_row', mode: 'casual', status: 'active', state: { turnPlayerId: 'user-1' }, revision: 4, winner_ids: null, loser_ids: null, draw: 0, created_at: '', started_at: '', finished_at: null }]];
        if (sql.includes('FROM match_players')) return [[{ userId: 'user-1', displayName: 'User', avatarUrl: null, seat: 0, team: null, isBot: 0, result: 'pending', ratingBefore: null, ratingAfter: null }]];
        return [[]];
      }),
      execute: jest.fn(),
    };
    const mysql = { transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)) };
    const engine = { apply: jest.fn(), outcome: jest.fn(), create: jest.fn(), validate: jest.fn(), botAction: jest.fn() };
    const service = new GameService(mysql as any, { engine: jest.fn().mockReturnValue(engine) } as any, {} as any);

    await expect(service.act('match-1', 'user-1', { type: 'drop', column: 0, revision: 3 } as any)).rejects.toThrow('table changed');
    expect(engine.apply).not.toHaveBeenCalled();
    expect(connection.execute).not.toHaveBeenCalled();
  });

  it('sanitizes hidden Sketch prompts and Trivia answers per viewer', () => {
    const service = new GameService({} as any, {} as any, {} as any);
    const players = [
      { userId: 'player-0', seat: 0 },
      { userId: 'player-1', seat: 1 },
    ];
    const trivia = {
      questionBank: [{ prompt: 'Question', options: ['A', 'B', 'C', 'D'], answer: 2, category: 'Test' }],
      questionIndex: 0,
      answers: [null, 1],
    };
    const hidden = (service as any).sanitizeState('trivia_battle', trivia, players, 'player-1', 'active');
    expect(hidden.questionBank).toBeUndefined();
    expect(hidden.currentQuestion).toEqual({ prompt: 'Question', options: ['A', 'B', 'C', 'D'], category: 'Test' });
    expect(hidden.answers).toEqual([null, 1]);
    expect(JSON.stringify(hidden)).not.toContain('answer":2');

    const sketch = { prompt: 'rocket', drawerIndex: 0, drawing: [], guesses: [null, null] };
    const guesserView = (service as any).sanitizeState('sketch_guess', sketch, players, 'player-1', 'active');
    expect(guesserView.prompt).toBeNull();
    const drawerView = (service as any).sanitizeState('sketch_guess', sketch, players, 'player-0', 'active');
    expect(drawerView.prompt).toBe('rocket');
  });

  it('retries a stale invisible-bot action against freshly loaded state', async () => {
    const active = { id: 'match-1', game_id: 'four_in_a_row', status: 'active', state: { turnPlayerId: 'bot-1' }, revision: 1 };
    const finished = { ...active, status: 'finished' };
    const bot = { userId: 'bot-1', displayName: 'Bot', avatarUrl: null, seat: 1, team: null, isBot: 1, result: 'pending', ratingBefore: null, ratingAfter: null };
    const matchRows = [active, active, finished];
    const mysql = {
      query: jest.fn(async (sql: string) => sql.includes('SELECT * FROM matches') ? [matchRows.shift() ?? finished] : [bot]),
    };
    const engine = { botAction: jest.fn().mockReturnValue({ type: 'drop', column: 0 }) };
    const service = new GameService(mysql as any, { engine: jest.fn().mockReturnValue(engine) } as any, {} as any);
    (service as any).sleep = jest.fn().mockResolvedValue(undefined);
    const act = jest.spyOn(service, 'act').mockRejectedValueOnce(new Error('It is not your turn.')).mockResolvedValueOnce({} as any);

    await (service as any).runBotTurns('match-1');

    expect(act).toHaveBeenCalledTimes(2);
    expect(engine.botAction).toHaveBeenCalledTimes(2);
  });
});
