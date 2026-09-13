import { ChessEngine, FourInARowEngine, MancalaEngine } from '../src/games/engines/board.engine';
import { LudoEngine } from '../src/games/engines/tabletop.engine';
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

  it('supports castling, en passant, and promotion in chess', () => {
    const engine = new ChessEngine(); const roster = players(2); let state = engine.create(roster);
    const moves = [
      ['player-0', 6, 4, 4, 4], ['player-1', 1, 4, 3, 4],
      ['player-0', 7, 6, 5, 5], ['player-1', 0, 1, 2, 2],
      ['player-0', 7, 5, 4, 2], ['player-1', 0, 6, 2, 5],
      ['player-0', 7, 4, 7, 6],
    ] as const;
    for (const [actor, fromRow, fromCol, toRow, toCol] of moves) state = engine.apply(state, actor, { type: 'move', fromRow, fromCol, toRow, toCol }, roster) as any;
    expect((state as any).board[7][6]).toBe('K'); expect((state as any).board[7][5]).toBe('R'); expect((state as any).castling.K).toBe(false);

    state = engine.create(roster);
    for (const [actor, fromRow, fromCol, toRow, toCol] of [
      ['player-0', 6, 4, 4, 4], ['player-1', 1, 0, 2, 0], ['player-0', 4, 4, 3, 4], ['player-1', 1, 3, 3, 3],
    ] as const) state = engine.apply(state, actor, { type: 'move', fromRow, fromCol, toRow, toCol }, roster) as any;
    state = engine.apply(state, 'player-0', { type: 'move', fromRow: 3, fromCol: 4, toRow: 2, toCol: 3 }, roster) as any;
    expect((state as any).board[2][3]).toBe('P'); expect((state as any).board[3][3]).toBeNull();

    const promotion = engine.create(roster) as any;
    promotion.board = Array.from({ length: 8 }, () => Array(8).fill(null)); promotion.board[7][4] = 'K'; promotion.board[0][4] = 'k'; promotion.board[1][0] = 'P';
    promotion.turnPlayerId = 'player-0'; promotion.turnIndex = 0; promotion.castling = { K: false, Q: false, k: false, q: false }; promotion.positionCounts = {};
    const promoted = engine.apply(promotion, 'player-0', { type: 'move', fromRow: 1, fromCol: 0, toRow: 0, toCol: 0, promotion: 'n' }, roster) as any;
    expect(promoted.board[0][0]).toBe('N');
  });

  it('resolves chess checkmate and stalemate', () => {
    const engine = new ChessEngine(); const roster = players(2); let state = engine.create(roster);
    for (const [actor, fromRow, fromCol, toRow, toCol] of [
      ['player-0', 6, 5, 5, 5], ['player-1', 1, 4, 3, 4], ['player-0', 6, 6, 4, 6], ['player-1', 0, 3, 4, 7],
    ] as const) state = engine.apply(state, actor, { type: 'move', fromRow, fromCol, toRow, toCol }, roster) as any;
    expect((state as any).finished).toBe(true); expect((state as any).winnerId).toBe('player-1'); expect((state as any).draw).not.toBe(true);

    const stalemate = engine.create(roster) as any;
    stalemate.board = Array.from({ length: 8 }, () => Array(8).fill(null)); stalemate.board[0][0] = 'k'; stalemate.board[2][2] = 'K'; stalemate.board[1][2] = 'Q';
    stalemate.turnPlayerId = 'player-0'; stalemate.turnIndex = 0; stalemate.castling = { K: false, Q: false, k: false, q: false }; stalemate.positionCounts = {};
    const after = engine.apply(stalemate, 'player-0', { type: 'move', fromRow: 1, fromCol: 2, toRow: 2, toCol: 1 }, roster) as any;
    expect(after.finished).toBe(true); expect(after.draw).toBe(true); expect(after.drawReason).toBe('stalemate');

    let repetition = engine.create(roster) as any;
    const repetitionMoves = [
      ['player-0', 7, 6, 5, 5], ['player-1', 0, 6, 2, 5], ['player-0', 5, 5, 7, 6], ['player-1', 2, 5, 0, 6],
      ['player-0', 7, 6, 5, 5], ['player-1', 0, 6, 2, 5], ['player-0', 5, 5, 7, 6], ['player-1', 2, 5, 0, 6],
    ] as const;
    for (const [actor, fromRow, fromCol, toRow, toCol] of repetitionMoves) repetition = engine.apply(repetition, actor, { type: 'move', fromRow, fromCol, toRow, toCol }, roster) as any;
    expect(repetition.finished).toBe(true); expect(repetition.drawReason).toBe('threefold_repetition');

    const material = engine.create(roster) as any;
    material.board = Array.from({ length: 8 }, () => Array(8).fill(null)); material.board[7][4] = 'K'; material.board[0][4] = 'k'; material.board[7][1] = 'N';
    material.turnPlayerId = 'player-0'; material.turnIndex = 0; material.castling = { K: false, Q: false, k: false, q: false }; material.positionCounts = {};
    const materialDraw = engine.apply(material, 'player-0', { type: 'move', fromRow: 7, fromCol: 1, toRow: 5, toCol: 2 }, roster) as any;
    expect(materialDraw.finished).toBe(true); expect(materialDraw.drawReason).toBe('insufficient_material');
  });

  it('applies Ludo six-roll, capture, blockade, exact finish, and bot rules', () => {
    const engine = new LudoEngine(); const roster = players(2); let state = engine.create(roster) as any;
    state.pendingRoll = 6;
    state = engine.apply(state, 'player-0', { type: 'move', token: 0 }, roster) as any;
    expect(state.positions[0][0]).toBe(0); expect(state.turnPlayerId).toBe('player-0');
    state.pendingRoll = 1; state.positions[1][0] = 40;
    state = engine.apply(state, 'player-0', { type: 'move', token: 0 }, roster) as any;
    expect(state.positions[0][0]).toBe(1); expect(state.positions[1][0]).toBe(-1); expect(state.turnPlayerId).toBe('player-1');
    state.turnPlayerId = 'player-0'; state.turnIndex = 0; state.pendingRoll = 1; state.positions[0][0] = 0; state.positions[1][0] = 40; state.positions[1][1] = 40;
    expect(() => engine.apply(state, 'player-0', { type: 'move', token: 0 }, roster)).toThrow();
    expect(engine.botAction(state, 'player-0', roster).type).toBe('pass');
    const botState = engine.create(roster) as any; botState.pendingRoll = 6;
    expect(engine.botAction(botState, 'player-0', roster)).toEqual({ type: 'move', token: 0 });

    const finish = engine.create(roster) as any; finish.pendingRoll = 1; finish.positions[0] = [56, 57, 57, 57];
    const completed = engine.apply(finish, 'player-0', { type: 'move', token: 0 }, roster) as any;
    expect(completed.finished).toBe(true); expect(completed.winnerIds).toEqual(['player-0']);

    const teamRoster = players(4).map((player) => ({ ...player, team: player.seat % 2 }));
    const teamState = engine.create(teamRoster) as any; teamState.pendingRoll = 1; teamState.positions[0] = [56, 57, 57, 57]; teamState.positions[2] = [57, 57, 57, 57];
    const teamFinished = engine.apply(teamState, 'player-0', { type: 'move', token: 0 }, teamRoster) as any;
    expect(teamFinished.finished).toBe(true); expect(teamFinished.winnerIds).toEqual(['player-0', 'player-2']);
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
