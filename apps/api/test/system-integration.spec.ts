import { MatchmakingService } from '../src/matchmaking/matchmaking.service';
import { RankingService } from '../src/ranking/ranking.service';

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
});
