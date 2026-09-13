import { ChessEngine, FourInARowEngine, MancalaEngine } from '../src/games/engines/board.engine';
import { OchoEngine } from '../src/games/engines/cards.engine';
import { GamePlayer } from '../src/games/game.types';
import { GameRegistry } from '../src/games/game.registry';

const players = (count: number): GamePlayer[] => Array.from({ length: count }, (_, seat) => ({ id: `player-${seat}`, seat, isBot: false }));

describe('authoritative game engines', () => {
  it('detects a four in a row win and rejects a full column', () => {
    const engine = new FourInARowEngine(); const roster = players(2); let state = engine.create(roster);
    for (const column of [0, 1, 0, 1, 0, 1, 0]) { const actor = state.turnPlayerId as string; state = engine.apply(state, actor, { type: 'drop', column }, roster); }
    expect(state.finished).toBe(true); expect(state.winnerId).toBe('player-0');
    expect(() => engine.apply(state, 'player-1', { type: 'drop', column: 0 }, roster)).toThrow();
  });

  it('starts chess with the legal opening move and rejects moving through a piece', () => {
    const engine = new ChessEngine(); const roster = players(2); let state = engine.create(roster);
    state = engine.apply(state, 'player-0', { type: 'move', fromRow: 6, fromCol: 4, toRow: 4, toCol: 4 }, roster);
    expect((state.board as unknown[][])[4][4]).toBe('P');
    expect(() => engine.apply(state, 'player-1', { type: 'move', fromRow: 0, fromCol: 0, toRow: 3, toCol: 0 }, roster)).toThrow();
  });

  it('gives the second mancala player a turn after a non-store finish', () => {
    const engine = new MancalaEngine(); const roster = players(2); const state = engine.create(roster);
    const next = engine.apply(state, 'player-0', { type: 'sow', pit: 0 }, roster);
    expect(next.turnPlayerId).toBe('player-1');
    expect((next.pits as number[][])[0].reduce((sum, value) => sum + value, 0)).toBeGreaterThan(0);
  });

  it('registers every shipped game with an isolated initial state', () => {
    const registry = new GameRegistry();
    expect(registry.list()).toHaveLength(28);
    for (const descriptor of registry.list()) {
      const roster = players(descriptor.minPlayers);
      const state = registry.engine(descriptor.id).create(roster);
      expect(state).toBeDefined();
      expect(typeof state.turnPlayerId === 'string' || state.phase === 'placing').toBe(true);
    }
  });

  it('only permits an Ocho card matching the active color or value', () => {
    const engine = new OchoEngine(); const roster = players(2); const state = engine.create(roster); const hand = (state.hands as Array<Array<{ color: string; value: string }>>)[0];
    const top = state.discard[state.discard.length - 1]; const currentColor = state.currentColor as string; const illegalColor = currentColor === 'red' ? 'blue' : 'red';
    hand[0] = { color: currentColor, value: '0' }; hand[1] = { color: illegalColor, value: top.value === '0' ? '1' : '0' };
    expect(() => engine.apply(state, 'player-0', { type: 'play', index: 0 }, roster)).not.toThrow();
    expect(() => engine.apply(state, 'player-0', { type: 'play', index: 1 }, roster)).toThrow();
  });
});
