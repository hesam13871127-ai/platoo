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
    (state as any).discard = [{ color: 'red', value: '9' }]; (state as any).currentColor = 'red'; (state as any).turnPlayerId = 'player-0';
    (state as any).pendingDraw = 0; (state as any).drawnCardIndex = null; (state as any).awaitingColor = false;
    hand[0] = { color: 'red', value: '0' }; hand[1] = { color: 'blue', value: '0' };
    expect(() => engine.apply(state, 'player-0', { type: 'play', index: 0 }, roster)).not.toThrow();
    expect(() => engine.apply(state, 'player-0', { type: 'play', index: 1 }, roster)).toThrow();
  });

  it('deals the complete 108-card deck and keeps Wild Draw Four out of the opening discard', () => {
    const state = new OchoEngine().create(players(4)) as any;
    const cardCount = state.hands.flat().length + state.draw.length + state.discard.length;
    expect(cardCount).toBe(108);
    expect(state.discard[state.discard.length - 1].value).not.toBe('wild4');
  });

  it('lets a player play a matching card drawn during the same turn', () => {
    const engine = new OchoEngine(); const roster = players(2);
    const state = {
      hands: [[{ color: 'red', value: '1' }], [{ color: 'blue', value: '2' }]],
      draw: [{ color: 'green', value: '7' }], discard: [{ color: 'red', value: '7' }], currentColor: 'red', direction: 1,
      turnIndex: 0, turnPlayerId: 'player-0', winnerId: null, finished: false, pendingDraw: 0,
      pendingDrawSource: null, wildFourLegal: null, drawnCardIndex: null, awaitingColor: false,
    } as any;
    const drawn = engine.apply(state, 'player-0', { type: 'draw' }, roster) as any;
    expect(drawn.turnPlayerId).toBe('player-0');
    expect(drawn.drawnCardIndex).toBe(1);
    const passed = engine.apply(drawn, 'player-0', { type: 'pass' }, roster) as any;
    expect(passed.turnPlayerId).toBe('player-1');
    const redrawn = engine.apply(state, 'player-0', { type: 'draw' }, roster) as any;
    const played = engine.apply(redrawn, 'player-0', { type: 'play', index: 1, call: true }, roster) as any;
    expect(played.discard.at(-1)).toEqual({ color: 'green', value: '7' });
    expect(played.turnPlayerId).toBe('player-1');
  });

  it('resolves a successful Wild Draw Four challenge correctly', () => {
    const engine = new OchoEngine(); const roster = players(2);
    const state = {
      hands: [[{ color: 'yellow', value: '5' }, { color: 'wild', value: 'wild4' }], [{ color: 'blue', value: '2' }]],
      draw: Array.from({ length: 12 }, () => ({ color: 'green', value: '1' })), discard: [{ color: 'yellow', value: '9' }], currentColor: 'yellow', direction: 1,
      turnIndex: 0, turnPlayerId: 'player-0', winnerId: null, finished: false, pendingDraw: 0,
      pendingDrawSource: null, wildFourLegal: null, drawnCardIndex: null, awaitingColor: false,
    } as any;
    const played = engine.apply(state, 'player-0', { type: 'play', index: 1, color: 'blue', call: true }, roster) as any;
    expect(played.pendingDraw).toBe(4);
    expect(played.wildFourLegal).toBe(false);
    const challenged = engine.apply(played, 'player-1', { type: 'challenge' }, roster) as any;
    expect(challenged.hands[0]).toHaveLength(5);
    expect(challenged.turnPlayerId).toBe('player-1');
    expect(challenged.pendingDraw).toBe(0);
  });

  it('lets the Ocho bot action loop finish complete matches', () => {
    const engine = new OchoEngine(); const roster = players(2).map((player) => ({ ...player, isBot: true }));
    for (let trial = 0; trial < 10; trial += 1) {
      let state = engine.create(roster) as any;
      for (let move = 0; move < 5000 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
      }
      expect(state.finished).toBe(true);
    }
  });

  it('lets the Four in a Row bot action loop finish complete matches', () => {
    const engine = new FourInARowEngine(); const roster = players(2).map((player) => ({ ...player, isBot: true }));
    for (let trial = 0; trial < 10; trial += 1) {
      let state = engine.create(roster) as any;
      for (let move = 0; move < 100 && !state.finished; move += 1) {
        const actor = state.turnPlayerId as string;
        state = engine.apply(state, actor, engine.botAction(state, actor), roster) as any;
      }
      expect(state.finished).toBe(true);
    }
  });
});
