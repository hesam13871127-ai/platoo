import { BackgammonEngine } from '../src/games/engines/tabletop.engine';
import { FourInARowEngine } from '../src/games/engines/board.engine';
import { ArcheryEngine, BowlingEngine, DartsEngine } from '../src/games/engines/sport.engine';
import { HeartsEngine, SpadesEngine } from '../src/games/engines/cards.engine';
import { WordChainEngine } from '../src/games/engines/party.engine';
import { GamePlayer } from '../src/games/game.types';
import { GameRegistry } from '../src/games/game.registry';
import { GameService } from '../src/games/game.service';

const players = (count: number): GamePlayer[] => Array.from({ length: count }, (_, seat) => ({ id: `player-${seat}`, seat, isBot: false }));
const isoAgo = (ms: number): string => new Date(Date.now() - ms).toISOString();

describe('match integrity: engine repairs', () => {
  it('finishes word chain after the word limit with unique bot words', () => {
    const engine = new WordChainEngine(); const roster = players(2); let state = engine.create(roster);
    expect(state.maxWords).toBe(16);
    for (let turn = 0; turn < 40 && !state.finished; turn += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state), roster);
    }
    const words = state.words as string[];
    expect(state.finished).toBe(true);
    expect(words.length).toBe(16);
    expect(new Set(words).size).toBe(words.length);
    expect(['player-0', 'player-1']).toContain(state.winnerId);
  });

  it('awards hearts to the lowest score and spades to the highest', () => {
    const endgame = () => ({ hands: [[{ suit: 'C', rank: 2 }], [{ suit: 'C', rank: 3 }]], trick: [], leadSuit: null, turnIndex: 0, turnPlayerId: 'player-0', scores: [99, 0], round: 9, winnerId: null, finished: false, targetScore: 100 });
    const roster = players(2);
    let hearts = endgame() as any;
    hearts = new HeartsEngine().apply(hearts, 'player-0', { type: 'play', index: 0 }, roster) as any;
    hearts = new HeartsEngine().apply(hearts, 'player-1', { type: 'play', index: 0 }, roster) as any;
    expect(hearts.finished).toBe(true); expect(hearts.winnerId).toBe('player-1');
    let spades = endgame() as any;
    spades = new SpadesEngine().apply(spades, 'player-0', { type: 'play', index: 0 }, roster) as any;
    spades = new SpadesEngine().apply(spades, 'player-1', { type: 'play', index: 0 }, roster) as any;
    expect(spades.finished).toBe(true); expect(spades.winnerId).toBe('player-0');
  });

  it('deals even hands for three-player trick-taking games', () => {
    for (const engine of [new HeartsEngine(), new SpadesEngine()]) {
      const hands = (engine.create(players(3)) as any).hands as unknown[][];
      expect(hands.map((hand) => hand.length)).toEqual([17, 17, 17]);
    }
  });

  it('gives every archer the same number of shots', () => {
    const engine = new ArcheryEngine(); const roster = players(2); let state = engine.create(roster);
    for (let turn = 0; turn < 20 && !state.finished; turn += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, { type: 'shoot', accuracy: 50 }, roster);
    }
    expect(state.finished).toBe(true);
    expect(state.shots).toEqual([5, 5]);
  });

  it('plays a full legal bowling game with bots and finishes every tenth frame', () => {
    const engine = new BowlingEngine(); const roster = players(2); let state = engine.create(roster);
    for (let turn = 0; turn < 300 && !state.finished; turn += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster);
    }
    expect(state.finished).toBe(true);
    expect((state.frames as number[][][]).map((frames) => frames.length)).toEqual([10, 10]);
  });

  it('never busts with the darts bot', () => {
    const engine = new DartsEngine(); const roster = players(2);
    for (const score of [2, 3, 5, 61, 62, 100, 301]) {
      for (let attempt = 0; attempt < 25; attempt += 1) {
        const state = { ...(engine.create(roster) as any), scores: [score, 301] };
        expect(() => engine.validate(state, 'player-0', engine.botAction(state, 'player-0', roster), roster)).not.toThrow();
      }
    }
    const one = { ...(engine.create(roster) as any), scores: [1, 301] };
    expect(engine.botAction(one, 'player-0', roster)).toEqual({ type: 'throw', value: 0, dartType: 'miss' });
  });

  it('lets backgammon re-enter from the bar on both sides and pass when blocked', () => {
    const engine = new BackgammonEngine(); const roster = players(2);
    const barSide0 = { ...(engine.create(roster) as any), bar: [1, 0], dice: [4] };
    const entered0 = engine.apply(barSide0, 'player-0', { type: 'move', from: -1, to: 3 }, roster) as any;
    expect(entered0.bar).toEqual([0, 0]); expect(entered0.dice).toEqual([]);
    const barSide1 = { ...(engine.create(roster) as any), bar: [0, 1], dice: [3], turnIndex: 1, turnPlayerId: 'player-1' };
    const entered1 = engine.apply(barSide1, 'player-1', { type: 'move', from: -1, to: 21 }, roster) as any;
    expect(entered1.bar).toEqual([0, 0]); expect(entered1.points[21]).toBe(-1);
    const blocked = { ...(engine.create(roster) as any), bar: [1, 0], dice: [1, 2] };
    blocked.points[0] = -2; blocked.points[1] = -2;
    expect(() => engine.apply(blocked, 'player-0', { type: 'move', from: -1, to: 0 }, roster)).toThrow('blocked');
    expect(engine.botAction(blocked, 'player-0', roster)).toEqual({ type: 'pass' });
    const passed = engine.apply(blocked, 'player-0', { type: 'pass' }, roster) as any;
    expect(passed.dice).toEqual([]); expect(passed.turnPlayerId).toBe('player-1');
    const botEntry = { ...(engine.create(roster) as any), bar: [0, 1], dice: [6] };
    botEntry.points = Array(24).fill(0); botEntry.points[18] = 0;
    expect(engine.botAction(botEntry, 'player-1', roster)).toEqual({ type: 'move', from: -1, to: 18 });
    const fresh = engine.apply(engine.create(roster), 'player-0', { type: 'roll' }, roster) as any;
    expect(() => engine.apply(fresh, 'player-0', { type: 'move', from: -1, to: 0 }, roster)).toThrow('no checker on the bar');

    const bearingOff = engine.create(roster) as any;
    bearingOff.points = Array(24).fill(0);
    bearingOff.points[18] = 1;
    bearingOff.points[23] = 1;
    bearingOff.borneOff = [13, 15];
    bearingOff.dice = [6];
    expect(() => engine.apply(bearingOff, 'player-0', { type: 'move', from: 18, to: 24 }, roster)).not.toThrow();

    const oversized = engine.create(roster) as any;
    oversized.points = Array(24).fill(0);
    oversized.points[18] = 1;
    oversized.points[21] = 1;
    oversized.points[23] = 1;
    oversized.borneOff = [12, 15];
    oversized.dice = [6];
    expect(() => engine.apply(oversized, 'player-0', { type: 'move', from: 21, to: 24 }, roster)).toThrow('die is not available');
  });

  it('exposes per-game turn clocks with a sketch drawing override', () => {
    const registry = new GameRegistry();
    expect(registry.turnSeconds('chess')).toBe(180);
    expect(registry.turnSeconds('four_in_a_row')).toBe(30);
    expect(registry.turnSeconds('ocho')).toBe(60);
    expect(registry.turnSeconds('sketch_guess', { phase: 'drawing' })).toBe(120);
    expect(registry.turnSeconds('sketch_guess', { phase: 'guessing' })).toBe(30);
  });
});

describe('match integrity: resign, timers, and sweeper', () => {
  const human = (id: string, seat: number, result = 'pending') => ({ userId: id, displayName: id, avatarUrl: null, seat, team: null, isBot: 0, result, ratingBefore: null, ratingAfter: null });
  const bot = (id: string, seat: number) => ({ ...human(id, seat), isBot: 1 });
  const matchRow = (overrides: Record<string, unknown> = {}) => ({ id: 'match-1', game_id: 'four_in_a_row', mode: 'casual', status: 'active', state: { turnPlayerId: 'user-1' }, revision: 3, winner_ids: null, loser_ids: null, draw: 0, created_at: '', started_at: '', finished_at: null, updated_at: isoAgo(61_000), ...overrides });
  const connectionWith = (rows: (sql: string) => unknown[][], onExecute?: (sql: string, params: unknown[]) => void) => ({
    query: jest.fn(async (sql: string, params?: unknown[]) => rows(sql)),
    execute: jest.fn(async (sql: string, params: unknown[]) => { onExecute?.(sql, params); return [{ affectedRows: 1 }, []] as any; }),
  });

  it('resigns a match with a loss for the resigner and a win for the bots', async () => {
    const executed: Array<{ sql: string; params: unknown[] }> = [];
    const row = matchRow();
    const connection = connectionWith(
      (sql) => sql.includes('FROM matches') ? [[row]] : [[human('user-1', 0), bot('bot-1', 1)]],
      (sql, params) => executed.push({ sql, params }),
    );
    const finished = { ...row, status: 'finished', revision: 4, winner_ids: ['bot-1'], loser_ids: ['user-1'] };
    const mysql = {
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
      query: jest.fn(async (sql: string) => sql.includes('FROM matches') ? [finished] : sql.includes('match_players') ? [{ ...human('user-1', 0, 'loss'), ratingBefore: 1000 }, { ...bot('bot-1', 1), result: 'win' }] : []),
    };
    const ranking = { recordMatch: jest.fn().mockResolvedValue(undefined) };
    const service = new GameService(mysql as any, { engine: jest.fn(), turnSeconds: jest.fn().mockReturnValue(30) } as any, ranking as any);
    const emitted: string[] = []; service.onMatchUpdated((id) => emitted.push(id));

    const result = await service.resign('match-1', 'user-1') as any;

    expect(executed.some(({ sql }) => sql.includes("status = 'finished'"))).toBe(true);
    expect(executed.some(({ sql, params }) => sql.includes('match_moves') && params[3] === 'resign')).toBe(true);
    expect(executed.some(({ sql }) => sql.includes('left_at = IF'))).toBe(true);
    expect(ranking.recordMatch).toHaveBeenCalledWith('match-1');
    expect(emitted).toEqual(['match-1']);
    expect(result.winnerIds).toEqual(['bot-1']);
    expect(result.status).toBe('finished');
  });

  it('awards a resignation win to the remaining humans in multiplayer', async () => {
    const executed: Array<{ sql: string; params: unknown[] }> = [];
    const row = matchRow();
    const connection = connectionWith(
      (sql) => sql.includes('FROM matches') ? [[row]] : [[human('user-1', 0), human('user-2', 1), human('user-3', 2)]],
      (sql, params) => executed.push({ sql, params }),
    );
    const mysql = {
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
      query: jest.fn(async () => []),
    };
    const ranking = { recordMatch: jest.fn().mockResolvedValue(undefined) };
    const service = new GameService(mysql as any, { engine: jest.fn(), turnSeconds: jest.fn().mockReturnValue(30) } as any, ranking as any);
    (service as any).settleCompletedMatch = jest.fn().mockResolvedValue({ status: 'finished', winnerIds: ['user-2', 'user-3'] });

    await service.resign('match-1', 'user-1');

    const update = executed.find(({ sql }) => sql.includes('UPDATE matches SET'));
    expect(JSON.parse(update?.params[1] as string)).toEqual(['user-2', 'user-3']);
  });

  it('rejects resignation from non-players and finished matches', async () => {
    const connection = {
      query: jest.fn(async (sql: string, params: unknown[]) => sql.includes('FROM matches') ? [[matchRow(params[0] === 'done' ? { status: 'finished' } : {})]] : [[human('user-1', 0)]]),
      execute: jest.fn(),
    };
    const mysql = { transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)), query: jest.fn() };
    const service = new GameService(mysql as any, {} as any, {} as any);
    await expect(service.resign('match-1', 'stranger')).rejects.toThrow('not a player');
    await expect(service.resign('done', 'user-1')).rejects.toThrow('no longer active');
  });

  it('records idle strikes on auto-moves and clears them when the human acts', async () => {
    const states: unknown[] = [];
    const row = matchRow({ state: { turnPlayerId: 'user-1', _idleStrikes: { 'user-1': 1, 'user-2': 2 } }, updated_at: new Date().toISOString() });
    const connection = connectionWith(
      (sql) => sql.includes('FROM matches') ? [[row]] : [[human('user-1', 0), human('user-2', 1)]],
      (sql, params) => { if (sql.startsWith('UPDATE matches')) states.push(JSON.parse(params[0] as string)); },
    );
    const mysql = {
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
      query: jest.fn(async () => []),
    };
    const engine = { apply: jest.fn((state: any) => ({ ...state })), outcome: jest.fn().mockReturnValue({ finished: false, winnerIds: [], loserIds: [], draw: false }) };
    const service = new GameService(mysql as any, { engine: jest.fn().mockReturnValue(engine), turnSeconds: jest.fn().mockReturnValue(30) } as any, {} as any);

    await service.act('match-1', 'user-1', { type: 'drop', column: 0 } as any, true, 2);
    expect((states[0] as any)._idleStrikes).toEqual({ 'user-1': 2, 'user-2': 2 });
    await service.act('match-1', 'user-1', { type: 'drop', column: 0 } as any);
    expect((states[1] as any)._idleStrikes).toEqual({ 'user-2': 2 });
    expect((states[1] as any).lastTimeout).toBeUndefined();
  });

  it('rejects a human action that arrives after the server deadline', async () => {
    const row = matchRow({ updated_at: isoAgo(61_000) });
    const connection = connectionWith(
      (sql) => sql.includes('FROM matches') ? [[row]] : [[human('user-1', 0), bot('bot-1', 1)]],
    );
    const mysql = {
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
      query: jest.fn(),
    };
    const engine = { apply: jest.fn(), outcome: jest.fn() };
    const service = new GameService(mysql as any, { engine: jest.fn().mockReturnValue(engine), turnSeconds: jest.fn().mockReturnValue(30) } as any, {} as any);

    await expect(service.act('match-1', 'user-1', { type: 'drop', column: 0 } as any)).rejects.toThrow('turn has expired');
    expect(engine.apply).not.toHaveBeenCalled();
  });

  it('auto-moves an idle human past the turn deadline', async () => {
    const row = matchRow();
    const mysql = { query: jest.fn(async (sql: string) => sql.includes('match_players') ? [human('user-1', 0), bot('bot-1', 1)] : [row]) };
    const botAction = jest.fn().mockReturnValue({ type: 'drop', column: 0 });
    const service = new GameService(mysql as any, { engine: jest.fn().mockReturnValue({ botAction }), turnSeconds: jest.fn().mockReturnValue(30) } as any, {} as any);
    const act = jest.spyOn(service, 'act').mockResolvedValue({} as any);
    (service as any).runBotTurns = jest.fn().mockResolvedValue(undefined);

    await service.sweepStaleMatches();

    expect(botAction).toHaveBeenCalled();
    expect(act).toHaveBeenCalledWith('match-1', 'user-1', { type: 'drop', column: 0 }, true, 1);
  });

  it('applies a legal engine action for a timed-out turn and preserves the timeout audit', async () => {
    const engine = new FourInARowEngine();
    const roster = [
      { id: 'user-1', seat: 0, isBot: false },
      { id: 'bot-1', seat: 1, isBot: true },
    ];
    const row = matchRow({ game_id: 'four_in_a_row', state: engine.create(roster), updated_at: isoAgo(61_000) });
    const executed: Array<{ sql: string; params: unknown[] }> = [];
    const connection = connectionWith(
      (sql) => sql.includes('FROM matches') ? [[row]] : [[human('user-1', 0), bot('bot-1', 1)]],
      (sql, params) => executed.push({ sql, params }),
    );
    const mysql = {
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
      query: jest.fn(async (sql: string) => sql.includes('match_players') ? [human('user-1', 0), bot('bot-1', 1)] : [row]),
    };
    const service = new GameService(mysql as any, { engine: jest.fn().mockReturnValue(engine), turnSeconds: jest.fn().mockReturnValue(30) } as any, {} as any);
    (service as any).runBotTurns = jest.fn().mockResolvedValue(undefined);

    await service.sweepStaleMatches();

    const update = executed.find(({ sql }) => sql.startsWith('UPDATE matches SET state'));
    const updated = JSON.parse(update?.params[0] as string);
    expect(updated.board.flat().filter((cell: number) => cell !== 0)).toHaveLength(1);
    expect(updated.turnPlayerId).toBe('bot-1');
    expect(updated._idleStrikes).toEqual({ 'user-1': 1 });
    expect(updated.lastTimeout).toEqual({ playerId: 'user-1', count: 1 });
    const move = executed.find(({ sql }) => sql.includes('INSERT INTO match_moves'));
    expect(move?.params[3]).toBe('drop');
    expect((service as any).runBotTurns).toHaveBeenCalledWith('match-1');
  });

  it('forfeits a ranked player on the third consecutive idle strike', async () => {
    const row = matchRow({ mode: 'ranked', state: { turnPlayerId: 'user-1', _idleStrikes: { 'user-1': 2 } } });
    const executed: Array<{ sql: string; params: unknown[] }> = [];
    const connection = connectionWith(
      (sql) => sql.includes('FROM matches') ? [[row]] : [[human('user-1', 0), bot('bot-1', 1)]],
      (sql, params) => executed.push({ sql, params }),
    );
    const mysql = {
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
      query: jest.fn(async (sql: string) => sql.includes('match_players') ? [human('user-1', 0), bot('bot-1', 1)] : [row]),
    };
    const ranking = { recordMatch: jest.fn().mockResolvedValue(undefined) };
    const service = new GameService(mysql as any, { engine: jest.fn(), turnSeconds: jest.fn().mockReturnValue(30) } as any, ranking as any);
    (service as any).settleCompletedMatch = jest.fn().mockResolvedValue({});
    const emitted: string[] = []; service.onMatchUpdated((id) => emitted.push(id));

    await service.sweepStaleMatches();

    expect(executed.some(({ sql, params }) => sql.includes('match_moves') && params[3] === 'forfeit')).toBe(true);
    const update = executed.find(({ sql }) => sql.includes('UPDATE matches SET'));
    expect(JSON.parse(update?.params[1] as string)).toEqual(['bot-1']);
    expect(ranking.recordMatch).not.toHaveBeenCalled();
    expect((service as any).settleCompletedMatch).toHaveBeenCalledWith('match-1', 'user-1');
    expect(emitted).toEqual(['match-1']);
  });

  it('forfeits the third consecutive idle turn in casual and private matches too', async () => {
    for (const mode of ['casual', 'private']) {
      const row = matchRow({ mode, state: { turnPlayerId: 'user-1', _idleStrikes: { 'user-1': 2 } } });
      const executed: Array<{ sql: string; params: unknown[] }> = [];
      const connection = connectionWith(
        (sql) => sql.includes('FROM matches') ? [[row]] : [[human('user-1', 0), bot('bot-1', 1)]],
        (sql, params) => executed.push({ sql, params }),
      );
      const mysql = {
        transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
        query: jest.fn(async (sql: string) => sql.includes('match_players') ? [human('user-1', 0), bot('bot-1', 1)] : [row]),
      };
      const service = new GameService(mysql as any, { engine: jest.fn(), turnSeconds: jest.fn().mockReturnValue(30) } as any, { recordMatch: jest.fn().mockResolvedValue(undefined) } as any);
      (service as any).settleCompletedMatch = jest.fn().mockResolvedValue({});

      await service.sweepStaleMatches();

      expect(executed.some(({ sql, params }) => sql.includes('match_moves') && params[3] === 'forfeit')).toBe(true);
      const update = executed.find(({ sql }) => sql.includes('UPDATE matches SET'));
      expect(JSON.parse(update?.params[1] as string)).toEqual(['bot-1']);
    }
  });

  it('cancels stuck matches and abandoned sea battle placement', async () => {
    const stuck = matchRow({ id: 'match-stuck', updated_at: isoAgo(16 * 60_000) });
    const placing = matchRow({ id: 'match-placing', game_id: 'sea_battle', state: { phase: 'placing', turnPlayerId: null }, updated_at: isoAgo(11 * 60_000) });
    const byId = (id: unknown) => id === 'match-placing' ? [placing] : [stuck];
    const executed: Array<{ sql: string; params: unknown[] }> = [];
    const connection = {
      query: jest.fn(async (_sql: string, params: unknown[]) => [byId(params[0])]),
      execute: jest.fn(async (sql: string, params: unknown[]) => { executed.push({ sql, params }); return [{ affectedRows: 1 }, []] as any; }),
    };
    const mysql = {
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback(connection)),
      query: jest.fn(async (sql: string, params: unknown[]) => sql.includes('INTERVAL') ? [stuck, placing] : byId(params[0])),
    };
    const service = new GameService(mysql as any, { engine: jest.fn(), turnSeconds: jest.fn().mockReturnValue(60) } as any, {} as any);
    const emitted: string[] = []; service.onMatchUpdated((id) => emitted.push(id));

    await service.sweepStaleMatches();

    expect(executed.filter(({ sql }) => sql.includes("status = 'cancelled'")).length).toBe(2);
    expect(executed.some(({ sql, params }) => sql.includes('match_events') && (params[1] as string).includes('stuck'))).toBe(true);
    expect(executed.some(({ sql, params }) => sql.includes('match_events') && (params[1] as string).includes('placing-timeout'))).toBe(true);
    expect(emitted.sort()).toEqual(['match-placing', 'match-stuck']);
  });

  it('leaves fresh matches and prompt placement alone while nudging stuck bot turns', async () => {
    const fresh = matchRow({ updated_at: isoAgo(5_000) });
    const mysql = { query: jest.fn(async (sql: string) => sql.includes('match_players') ? [human('user-1', 0), bot('bot-1', 1)] : [fresh]) };
    const service = new GameService(mysql as any, { engine: jest.fn(), turnSeconds: jest.fn().mockReturnValue(30) } as any, {} as any);
    const act = jest.spyOn(service, 'act').mockResolvedValue({} as any);
    (service as any).runBotTurns = jest.fn().mockResolvedValue(undefined);
    await service.sweepStaleMatches();
    expect(act).not.toHaveBeenCalled();

    const botTurn = matchRow({ state: { turnPlayerId: 'bot-1' } });
    (mysql as any).query = jest.fn(async (sql: string) => sql.includes('match_players') ? [human('user-1', 0), bot('bot-1', 1)] : [botTurn]);
    await service.sweepStaleMatches();
    expect((service as any).runBotTurns).toHaveBeenCalledWith('match-1');
    expect(act).not.toHaveBeenCalled();

    const placing = matchRow({ game_id: 'sea_battle', state: { phase: 'placing', turnPlayerId: null }, updated_at: isoAgo(5 * 60_000) });
    const execute = jest.fn();
    (service as any).mysql = {
      query: jest.fn(async () => [placing]),
      transaction: jest.fn(async (callback: (connection: unknown) => Promise<unknown>) => callback({ query: jest.fn(async () => [[placing]]), execute })),
    };
    await service.sweepStaleMatches();
    expect(execute).not.toHaveBeenCalled();
  });

  it('publishes turn deadlines on active matches only', async () => {
    const updatedAt = isoAgo(10_000);
    const active = matchRow({ updated_at: updatedAt });
    const mysql = {
      query: jest.fn(async (sql: string) => sql.includes('FROM matches') ? [active] : sql.includes('match_players') ? [human('user-1', 0), bot('bot-1', 1)] : []),
    };
    const service = new GameService(mysql as any, { engine: jest.fn(), turnSeconds: jest.fn().mockReturnValue(45) } as any, {} as any);
    const live = await service.getMatch('match-1', 'user-1') as any;
    expect(live.turnSeconds).toBe(45);
    expect(live.turnDeadline).toBe(new Date(Date.parse(updatedAt) + 45_000).toISOString());
    expect(typeof live.serverTime).toBe('string');

    (mysql as any).query = jest.fn(async (sql: string) => sql.includes('FROM matches') ? [{ ...active, status: 'finished' }] : sql.includes('match_players') ? [human('user-1', 0)] : []);
    const done = await service.getMatch('match-1', 'user-1') as any;
    expect(done.turnSeconds).toBe(0);
    expect(done.turnDeadline).toBeNull();
  });

  it('hides idle strikes and other trick-taking hands from viewers', () => {
    const service = new GameService({} as any, {} as any, {} as any);
    const roster = [{ userId: 'player-0', seat: 0 }, { userId: 'player-1', seat: 1 }];
    const view = (service as any).sanitizeState('hearts', { hands: [[{ suit: 'H', rank: 2 }], [{ suit: 'S', rank: 12 }]], _idleStrikes: { 'player-0': 1 } }, roster, 'player-1', 'active');
    expect(view.hands).toEqual([[], [{ suit: 'S', rank: 12 }]]);
    expect(view._idleStrikes).toBeUndefined();
    const finished = (service as any).sanitizeState('spades', { hands: [[1], [2]] }, roster, 'player-1', 'finished');
    expect(finished.hands).toEqual([[1], [2]]);
  });
});
