import { GamePlayer } from '../src/games/game.types';
import { BackgammonEngine, SeaBattleEngine } from '../src/games/engines/tabletop.engine';
import { CheckersEngine } from '../src/games/engines/board.engine';
import { HeartsEngine, SpadesEngine } from '../src/games/engines/cards.engine';
import { MemoryRaceEngine, WordChainEngine } from '../src/games/engines/party.engine';
import { DartsEngine } from '../src/games/engines/sport.engine';
import { GameService } from '../src/games/game.service';
import { GameRegistry } from '../src/games/game.registry';

const players = (count: number): GamePlayer[] => Array.from({ length: count }, (_, seat) => ({ id: `player-${seat}`, seat, isBot: true, team: count === 4 ? seat % 2 : undefined }));

describe('closed-test rule hardening', () => {
  it('does not allow backgammon bearing off before the home board is clear', () => {
    const engine = new BackgammonEngine();
    const roster = players(2);
    const state = engine.create(roster) as any;
    state.dice = [7];
    state.points = Array(24).fill(0);
    state.points[17] = 1;
    state.points[18] = 1;
    state.borneOff = [13, 0];
    expect(() => engine.apply(state, 'player-0', { type: 'move', from: 17, to: 24 }, roster)).toThrow('home board');

    state.dice = [6];
    state.points = Array(24).fill(0);
    state.points[18] = 1;
    state.borneOff = [14, 0];
    const finished = engine.apply(state, 'player-0', { type: 'move', from: 18, to: 24 }, roster) as any;
    expect(finished.finished).toBe(true);
    expect(finished.winnerId).toBe('player-0');
  });

  it('requires contiguous, non-touching Sea Battle ships and hides enemy fleet coordinates', () => {
    const engine = new SeaBattleEngine();
    const roster = players(2);
    let state = engine.create(roster) as any;
    expect(() => engine.apply(state, 'player-0', { type: 'place', cells: [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4]] }, roster)).toThrow('straight');
    expect(() => engine.apply(state, 'player-0', { type: 'place', cells: [[0, 0], [0, 0], [0, 1], [0, 2], [0, 3]] }, roster)).toThrow('repeat');

    const fleets = [
      [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]],
      [[2, 0], [2, 1], [2, 2], [2, 3]],
      [[4, 0], [4, 1], [4, 2]],
      [[6, 0], [6, 1], [6, 2]],
      [[8, 0], [8, 1]],
    ];
    for (let ship = 0; ship < fleets.length; ship += 1) state = engine.apply(state, 'player-0', { type: 'place', cells: fleets[ship] }, roster) as any;
    for (let ship = 0; ship < fleets.length; ship += 1) state = engine.apply(state, 'player-1', { type: 'place', cells: fleets[ship].map(([row, column]: number[]) => [row, 9 - column]) }, roster) as any;
    expect(state.phase).toBe('battle');

    const service = new GameService({} as any, {} as any, {} as any);
    const view = (service as any).sanitizeState('sea_battle', state, roster.map((player) => ({ userId: player.id, seat: player.seat })), 'player-0', 'active');
    expect(view.fleets[0][0]).toEqual(fleets[0]);
    expect(view.fleets[1][0]).toEqual([null, null, null, null, null]);
  });

  it('enforces Hearts opening and broken-heart restrictions, and makes Spades bid first', () => {
    const hearts = new HeartsEngine();
    const roster = players(4);
    let state = hearts.create(roster) as any;
    const starter = state.turnIndex as number;
    const hand = state.hands[starter] as Array<{ suit: string; rank: number }>;
    const twoClubs = hand.findIndex((card) => card.suit === 'C' && card.rank === 2);
    expect(twoClubs).toBeGreaterThanOrEqual(0);
    expect(() => hearts.apply(state, roster[starter].id, { type: 'play', index: (twoClubs + 1) % hand.length }, roster)).toThrow();
    state = hearts.apply(state, roster[starter].id, { type: 'play', index: twoClubs }, roster) as any;
    expect(state.openingLead).toBe(false);

    const forcedFollow = hearts.create(roster) as any;
    forcedFollow.round = 1;
    forcedFollow.openingLead = false;
    forcedFollow.leadSuit = 'H';
    forcedFollow.heartsBroken = true;
    forcedFollow.trick = [{ player: 0, card: { suit: 'H', rank: 2 } }];
    forcedFollow.turnIndex = 1;
    forcedFollow.turnPlayerId = 'player-1';
    forcedFollow.hands[1] = [{ suit: 'C', rank: 3 }, { suit: 'H', rank: 5 }];
    expect(() => hearts.apply(forcedFollow, 'player-1', { type: 'play', index: 1 }, roster)).not.toThrow();

    const spades = new SpadesEngine();
    let spadeState = spades.create(roster) as any;
    expect(spadeState.bidPhase).toBe(true);
    expect(() => spades.apply(spadeState, 'player-0', { type: 'play', index: 0 }, roster)).toThrow('Bid');
    for (let seat = 0; seat < roster.length; seat += 1) spadeState = spades.apply(spadeState, `player-${seat}`, { type: 'bid', bid: 1 }, roster) as any;
    expect(spadeState.bidPhase).toBe(false);
    const legalOpening = spades.botAction(spadeState, spadeState.turnPlayerId, roster);
    expect(() => spades.apply(spadeState, spadeState.turnPlayerId, legalOpening, roster)).not.toThrow();
  });

  it('requires an explicit double or bull when the darts UI declares a checkout', () => {
    const engine = new DartsEngine();
    const roster = players(2);
    const state = { ...(engine.create(roster) as any), scores: [20, 301] };
    expect(() => engine.apply(state, 'player-0', { type: 'throw', value: 20, segment: 20, multiplier: 1 }, roster)).toThrow('double');
    const finished = engine.apply(state, 'player-0', { type: 'throw', value: 20, segment: 10, multiplier: 2 }, roster) as any;
    expect(finished.finished).toBe(true);
    expect(finished.winnerId).toBe('player-0');
  });

  it('keeps forced Checkers captures on the same piece and gives Persian Word Chain bots legal words', () => {
    const checkers = new CheckersEngine();
    const roster = players(2);
    const state = checkers.create(roster) as any;
    state.board = Array.from({ length: 8 }, () => Array(8).fill(null));
    state.board[5][0] = 'r'; state.board[4][1] = 'b'; state.board[2][3] = 'b';
    state.turnPlayerId = 'player-0'; state.turnIndex = 0; state.forcedFrom = { r: 3, c: 2 };
    // The fallback is legal only when it respects an active multi-jump. The
    // returned action is checked by the engine rather than trusting a client.
    state.forcedFrom = null;
    const first = checkers.botAction(state, 'player-0', roster);
    const after = checkers.apply(state, 'player-0', first, roster) as any;
    if (after.forcedFrom) {
      const next = checkers.botAction(after, 'player-0', roster);
      expect(() => checkers.validate(after, 'player-0', next, roster)).not.toThrow();
      expect(next.fromRow).toBe(after.forcedFrom.r);
      expect(next.fromCol).toBe(after.forcedFrom.c);
    }

    const words = new WordChainEngine();
    const wordState = words.create(players(2)) as any;
    wordState.requiredLetter = 'ش';
    const action = words.botAction(wordState);
    expect(() => words.validate(wordState, 'player-0', action, players(2))).not.toThrow();
  });

  it('does not expose hidden Ocho draw order and keeps Memory Race bot flips legal', () => {
    const service = new GameService({} as any, {} as any, {} as any);
    const roster = players(2).map((player) => ({ userId: player.id, seat: player.seat }));
    const view = (service as any).sanitizeState('ocho', { hands: [[{ color: 'red', value: '2' }], [{ color: 'blue', value: '7' }]], draw: [{ color: 'green', value: '9' }], wildFourLegal: false }, roster, 'player-0', 'active');
    expect(view.hands[1]).toEqual([]);
    expect(view.draw).toEqual([null]);
    expect(view.wildFourLegal).toBeUndefined();

    const memory = new MemoryRaceEngine();
    const state = memory.create(players(2)) as any;
    const first = memory.botAction(state, 'player-0');
    const afterFirst = memory.apply(state, 'player-0', first, players(2)) as any;
    const second = memory.botAction(afterFirst, 'player-0');
    expect(() => memory.validate(afterFirst, 'player-0', second, players(2))).not.toThrow();
  });

  it('runs a legal bot match for every registered engine', () => {
    const registry = new GameRegistry();
    for (const descriptor of registry.list()) {
      const roster = Array.from({ length: descriptor.minPlayers }, (_, seat) => ({ id: `${descriptor.id}-bot-${seat}`, seat, isBot: true, team: descriptor.supportsTeams ? seat % 2 : undefined })) as GamePlayer[];
      const engine = registry.engine(descriptor.id);
      let state = engine.create(roster) as any;
      let moves = 0;
      for (; moves < 5000 && !state.finished; moves += 1) {
        let actor = typeof state.turnPlayerId === 'string' ? state.turnPlayerId : roster[0].id;
        if (descriptor.id === 'sea_battle' && state.phase === 'placing') {
          actor = roster.find((player) => (state.fleets?.[player.seat]?.length ?? 0) < 5)?.id ?? actor;
        }
        state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster) as any;
      }
      expect(state.finished).toBe(true);
      expect(engine.outcome(state, roster).finished).toBe(true);
    }
  });
});
