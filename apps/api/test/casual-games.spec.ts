import { DicePartyEngine, EmojiCharadesEngine, ImpostorLightEngine, QuickChallengesEngine } from '../src/games/engines/party.engine';
import { ArcheryEngine, BowlingEngine, DartsEngine } from '../src/games/engines/sport.engine';
import { GamePlayer } from '../src/games/game.types';

const players = (count: number): GamePlayer[] => Array.from({ length: count }, (_, seat) => ({ id: `player-${seat}`, seat, isBot: false }));

describe('bowling: real scoring', () => {
  it('scores a perfect game at 300', () => {
    const engine = new BowlingEngine();
    const roster = players(1);
    let state = engine.create(roster) as any;
    for (let ball = 0; ball < 12; ball += 1) state = engine.apply(state, 'player-0', { type: 'roll', pins: 10 }, roster);
    expect(state.finished).toBe(true);
    expect(state.totals).toEqual([300]);
    expect(state.winnerId).toBe('player-0');
    expect(state.scorecard[0]).toEqual([30, 60, 90, 120, 150, 180, 210, 240, 270, 300]);
  });

  it('scores an all-spare game at 150 and a gutter game at 0', () => {
    const engine = new BowlingEngine();
    const spares = players(1);
    let spareGame = engine.create(spares) as any;
    for (let ball = 0; ball < 21; ball += 1) spareGame = engine.apply(spareGame, 'player-0', { type: 'roll', pins: 5 }, spares);
    expect(spareGame.finished).toBe(true);
    expect(spareGame.totals).toEqual([150]);

    const gutters = players(1);
    let gutterGame = engine.create(gutters) as any;
    for (let ball = 0; ball < 20; ball += 1) gutterGame = engine.apply(gutterGame, 'player-0', { type: 'roll', pins: 0 }, gutters);
    expect(gutterGame.finished).toBe(true);
    expect(gutterGame.totals).toEqual([0]);
  });

  it('carries strike and spare bonuses across frames without counting them early', () => {
    const engine = new BowlingEngine();
    const roster = players(1);
    let state = engine.create(roster) as any;
    state = engine.apply(state, 'player-0', { type: 'roll', pins: 10 }, roster);
    expect(state.scorecard[0][0]).toBeNull();
    expect(state.totals).toEqual([0]);
    state = engine.apply(state, 'player-0', { type: 'roll', pins: 3 }, roster);
    state = engine.apply(state, 'player-0', { type: 'roll', pins: 4 }, roster);
    expect(state.scorecard[0][0]).toBe(17);
    expect(state.totals).toEqual([24]);
  });

  it('enforces pin limits including the tenth-frame re-rack rules', () => {
    const engine = new BowlingEngine();
    const roster = players(2);
    let state = engine.create(roster) as any;
    state = engine.apply(state, 'player-0', { type: 'roll', pins: 7 }, roster);
    expect(() => engine.apply(state, 'player-0', { type: 'roll', pins: 4 }, roster)).toThrow();
    state = engine.apply(state, 'player-0', { type: 'roll', pins: 3 }, roster);
    expect(state.turnPlayerId).toBe('player-1');

    const tenth = (rolls: number[]) => ({ ...(engine.create(roster) as any), frame: 10, ball: rolls.length + 1, frames: [[[], [], [], [], [], [], [], [], [], rolls], [[], [], [], [], [], [], [], [], [], []]] });
    expect(() => engine.validate(tenth([10, 10]), 'player-0', { type: 'roll', pins: 10 }, roster)).not.toThrow();
    expect(() => engine.validate(tenth([10, 6]), 'player-0', { type: 'roll', pins: 5 }, roster)).toThrow();
    expect(() => engine.validate(tenth([10, 6]), 'player-0', { type: 'roll', pins: 4 }, roster)).not.toThrow();
    expect(() => engine.validate(tenth([7, 3]), 'player-0', { type: 'roll', pins: 10 }, roster)).not.toThrow();
  });

  it('finishes a two-player bot game with a winner and full scorecards', () => {
    const engine = new BowlingEngine();
    const roster = players(2);
    let state = engine.create(roster) as any;
    for (let turn = 0; turn < 200 && !state.finished; turn += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster);
    }
    expect(state.finished).toBe(true);
    expect(state.frames.map((frames: number[][]) => frames.length)).toEqual([10, 10]);
    expect(state.scorecard.every((row: (number | null)[]) => row.every((cell) => cell !== null))).toBe(true);
    expect(['player-0', 'player-1']).toContain(state.winnerId);
  });
});

describe('darts: three-dart visits', () => {
  it('rotates after three darts and records the visit', () => {
    const engine = new DartsEngine();
    const roster = players(2);
    let state = engine.create(roster) as any;
    state = engine.apply(state, 'player-0', { type: 'throw', value: 60 }, roster);
    state = engine.apply(state, 'player-0', { type: 'throw', value: 60 }, roster);
    expect(state.turnPlayerId).toBe('player-0');
    expect(state.dartsLeft).toBe(1);
    state = engine.apply(state, 'player-0', { type: 'throw', value: 60 }, roster);
    expect(state.scores).toEqual([121, 301]);
    expect(state.turnPlayerId).toBe('player-1');
    expect(state.dartsLeft).toBe(3);
    expect(state.lastVisit).toMatchObject({ playerId: 'player-0', darts: [60, 60, 60], total: 180 });
    expect(state.history).toHaveLength(1);
  });

  it('wins immediately on an exact checkout mid-visit', () => {
    const engine = new DartsEngine();
    const roster = players(2);
    let state = engine.create(roster) as any;
    state = engine.apply(state, 'player-0', { type: 'throw', value: 60 }, roster);
    state = engine.apply(state, 'player-0', { type: 'throw', value: 60 }, roster);
    state = engine.apply(state, 'player-0', { type: 'throw', value: 60 }, roster);
    state = engine.apply(state, 'player-1', { type: 'throw', value: 0 }, roster);
    state = engine.apply(state, 'player-1', { type: 'throw', value: 0 }, roster);
    state = engine.apply(state, 'player-1', { type: 'throw', value: 0 }, roster);
    // Player 0 is on 121: set up 100, then check out 60 + 40 on the second dart.
    state = engine.apply(state, 'player-0', { type: 'throw', value: 21 }, roster);
    state = engine.apply(state, 'player-0', { type: 'throw', value: 0 }, roster);
    state = engine.apply(state, 'player-0', { type: 'throw', value: 0 }, roster);
    state = engine.apply(state, 'player-1', { type: 'throw', value: 0 }, roster);
    state = engine.apply(state, 'player-1', { type: 'throw', value: 0 }, roster);
    state = engine.apply(state, 'player-1', { type: 'throw', value: 0 }, roster);
    expect(state.scores[0]).toBe(100);
    state = engine.apply(state, 'player-0', { type: 'throw', value: 60 }, roster);
    expect(state.finished).not.toBe(true);
    state = engine.apply(state, 'player-0', { type: 'throw', value: 40 }, roster);
    expect(state.finished).toBe(true);
    expect(state.winnerId).toBe('player-0');
    expect(state.visitDarts).toEqual([60, 40]);
    expect(engine.outcome(state, roster).winnerIds).toEqual(['player-0']);
  });

  it('rejects busts below zero and onto one', () => {
    const engine = new DartsEngine();
    const roster = players(2);
    const state = { ...(engine.create(roster) as any), scores: [30, 301] };
    expect(() => engine.validate(state, 'player-0', { type: 'throw', value: 31 }, roster)).toThrow('below zero');
    expect(() => engine.validate(state, 'player-0', { type: 'throw', value: 29 }, roster)).toThrow('one is a bust');
    expect(() => engine.validate(state, 'player-0', { type: 'throw', value: 30 }, roster)).not.toThrow();
  });

  it('finishes a full bot game', () => {
    const engine = new DartsEngine();
    const roster = players(2);
    let state = engine.create(roster) as any;
    for (let turn = 0; turn < 600 && !state.finished; turn += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster);
    }
    expect(state.finished).toBe(true);
    expect(['player-0', 'player-1']).toContain(state.winnerId);
  });
});

describe('dice party: rounds and history', () => {
  it('plays five rounds, tracks every roll, and crowns the highest total', () => {
    const engine = new DicePartyEngine();
    const roster = players(3);
    let state = engine.create(roster) as any;
    for (let turn = 0; turn < 60 && !state.finished; turn += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(), roster);
    }
    expect(state.finished).toBe(true);
    expect(state.round).toBe(5);
    expect(state.history).toHaveLength(15);
    expect(state.lastRoll).toMatchObject({ round: 5 });
    const max = Math.max(...(state.scores as number[]));
    expect(state.scores[(state.winnerId as string).split('-')[1] as any]).toBe(max);
  });

  it('rejects a second roll in the same round', () => {
    const engine = new DicePartyEngine();
    const roster = players(2);
    const state = engine.apply(engine.create(roster), 'player-0', { type: 'roll' }, roster) as any;
    expect(state.turnPlayerId).toBe('player-1');
    expect(() => engine.apply(state, 'player-0', { type: 'roll' }, roster)).toThrow('not your turn');
  });
});

describe('emoji charades: presenter and guessers', () => {
  it('scores correct guesses for the guesser and the presenter', () => {
    const engine = new EmojiCharadesEngine();
    const roster = players(3);
    let state = engine.create(roster) as any;
    const emoji = (state.clueOptions as string[])[0];
    state = engine.apply(state, 'player-0', { type: 'post_clue', emoji }, roster);
    expect(state.phase).toBe('guessing');
    expect(state.turnPlayerId).toBe('player-1');
    const answer = state.answer as number;
    state = engine.apply(state, 'player-1', { type: 'guess', answer }, roster);
    expect(state.scores).toEqual([50, 100, 0]);
    state = engine.apply(state, 'player-2', { type: 'guess', answer: (answer + 1) % 4 }, roster);
    expect(state.scores).toEqual([50, 100, 0]);
    expect(state.round).toBe(2);
    expect(state.presenterIndex).toBe(1);
    expect(state.lastRound).toMatchObject({ presenterId: 'player-0', correctIds: ['player-1'] });
  });

  it('rejects off-menu emoji, presenter guesses, and double guesses', () => {
    const engine = new EmojiCharadesEngine();
    const roster = players(3);
    const fresh = engine.create(roster) as any;
    expect(() => engine.apply(fresh, 'player-0', { type: 'post_clue', emoji: '🚫' }, roster)).toThrow('suggested emoji');
    let state = engine.apply(fresh, 'player-0', { type: 'post_clue', emoji: (fresh.clueOptions as string[])[1] }, roster);
    expect(() => engine.apply(state, 'player-0', { type: 'guess', answer: 0 }, roster)).toThrow('not your turn');
    state = engine.apply(state, 'player-1', { type: 'guess', answer: 0 }, roster);
    expect(() => engine.apply(state, 'player-1', { type: 'guess', answer: 1 }, roster)).toThrow('not your turn');
  });

  it('rotates the presenter through every seat and finishes with a winner', () => {
    const engine = new EmojiCharadesEngine();
    const roster = players(4);
    let state = engine.create(roster) as any;
    const presenters = new Set<number>();
    for (let turn = 0; turn < 100 && !state.finished; turn += 1) {
      if (state.phase === 'clue') presenters.add(state.presenterIndex as number);
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state, actor), roster);
    }
    expect(state.finished).toBe(true);
    expect(presenters).toEqual(new Set([0, 1, 2, 3]));
    expect(['player-0', 'player-1', 'player-2', 'player-3']).toContain(state.winnerId);
  });
});

describe('impostor light: bluffing and team justice', () => {
  const playClues = (engine: ImpostorLightEngine, roster: GamePlayer[]) => {
    let state = engine.create(roster) as any;
    for (let turn = 0; turn < roster.length; turn += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster);
    }
    expect(state.phase).toBe('vote');
    return state;
  };

  it('crowns the whole crew when the impostor is caught', () => {
    const engine = new ImpostorLightEngine();
    const roster = players(4);
    let state = playClues(engine, roster);
    const impostor = state.impostor as number;
    for (let seat = 0; seat < roster.length; seat += 1) {
      const target = seat === impostor ? (impostor + 1) % roster.length : impostor;
      state = engine.apply(state, `player-${seat}`, { type: 'vote', target }, roster);
    }
    expect(state.finished).toBe(true);
    expect(state.impostorCaught).toBe(true);
    const outcome = engine.outcome(state, roster);
    expect(outcome.winnerIds).toHaveLength(3);
    expect(outcome.winnerIds).not.toContain(`player-${impostor}`);
    expect(outcome.loserIds).toEqual([`player-${impostor}`]);
  });

  it('lets the impostor win alone when the crew votes wrong', () => {
    const engine = new ImpostorLightEngine();
    const roster = players(4);
    let state = playClues(engine, roster);
    const impostor = state.impostor as number;
    const scapegoat = (impostor + 1) % roster.length;
    for (let seat = 0; seat < roster.length; seat += 1) {
      const target = seat === scapegoat ? (scapegoat + 1) % roster.length : scapegoat;
      state = engine.apply(state, `player-${seat}`, { type: 'vote', target }, roster);
    }
    expect(state.impostorCaught).toBe(false);
    const outcome = engine.outcome(state, roster);
    expect(outcome.winnerIds).toEqual([`player-${impostor}`]);
  });

  it('lets the impostor escape on a tied vote', () => {
    const engine = new ImpostorLightEngine();
    const roster = players(4);
    let state = playClues(engine, roster);
    const votes = [1, 0, 0, 1];
    for (let seat = 0; seat < roster.length; seat += 1) state = engine.apply(state, `player-${seat}`, { type: 'vote', target: votes[seat] }, roster);
    expect(state.impostorCaught).toBe(false);
    expect(engine.outcome(state, roster).winnerIds).toHaveLength(1);
  });

  it('rejects self votes and off-phase actions', () => {
    const engine = new ImpostorLightEngine();
    const roster = players(4);
    const fresh = engine.create(roster) as any;
    expect(() => engine.apply(fresh, 'player-0', { type: 'vote', target: 1 }, roster)).toThrow('clue');
    const voting = playClues(engine, roster);
    expect(() => engine.apply(voting, 'player-0', { type: 'vote', target: 0 }, roster)).toThrow('yourself');
  });

  it('plays a full bot game with clues, votes, and a verdict', () => {
    const engine = new ImpostorLightEngine();
    const roster = players(5);
    let state = engine.create(roster) as any;
    expect(typeof state.word).toBe('string');
    for (let turn = 0; turn < 40 && !state.finished; turn += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state, actor, roster), roster);
    }
    expect(state.finished).toBe(true);
    expect(state.voteCount).toBe(5);
    expect(typeof state.impostorCaught).toBe('boolean');
  });
});

describe('archery: wind compensation', () => {
  it('pushes arrows by the wind and rewards compensation', () => {
    const engine = new ArcheryEngine();
    const roster = players(2);
    const windy = { ...(engine.create(roster) as any), wind: 10 };
    let state = engine.apply(windy, 'player-0', { type: 'shoot', accuracy: 40 }, roster) as any;
    expect(state.lastShot).toMatchObject({ accuracy: 40, wind: 10, effective: 50, points: 10, label: 'Bullseye!' });
    expect(state.scores[0]).toBe(10);

    const windy2 = { ...(engine.create(roster) as any), wind: -8 };
    state = engine.apply(windy2, 'player-0', { type: 'shoot', accuracy: 50 }, roster) as any;
    expect(state.lastShot).toMatchObject({ effective: 42, points: 8, label: 'Gold' });
  });

  it('clamps wild shots and calls a miss a miss', () => {
    const engine = new ArcheryEngine();
    const roster = players(1);
    const state = engine.apply({ ...(engine.create(roster) as any), wind: 10 }, 'player-0', { type: 'shoot', accuracy: 95 }, roster) as any;
    expect(state.lastShot).toMatchObject({ effective: 100, points: 0, label: 'Miss' });
  });

  it('gives every archer five arrows and finishes with a winner', () => {
    const engine = new ArcheryEngine();
    const roster = players(3);
    let state = engine.create(roster) as any;
    for (let turn = 0; turn < 60 && !state.finished; turn += 1) {
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state), roster);
    }
    expect(state.finished).toBe(true);
    expect(state.shots).toEqual([5, 5, 5]);
    expect(state.history).toHaveLength(15);
    expect(['player-0', 'player-1', 'player-2']).toContain(state.winnerId);
  });
});

describe('quick challenges: arcade trio', () => {
  it('scores a bullseye stop at 100 and near misses by distance', () => {
    const engine = new QuickChallengesEngine();
    const roster = players(2);
    const stop = { ...(engine.create(roster) as any), challenge: { kind: 'stop', zone: [45, 55] } };
    let state = engine.apply(stop, 'player-0', { type: 'play', value: 50 }, roster) as any;
    expect(state.lastResult).toMatchObject({ kind: 'stop', points: 100 });
    expect(state.scores[0]).toBe(100);

    const stop2 = { ...(engine.create(roster) as any), challenge: { kind: 'stop', zone: [45, 55] } };
    state = engine.apply(stop2, 'player-0', { type: 'play', value: 30 }, roster) as any;
    expect(state.lastResult.points).toBe(30);
  });

  it('plays high-low and cups without ever throwing on legal moves', () => {
    const engine = new QuickChallengesEngine();
    const roster = players(2);
    for (let trial = 0; trial < 20; trial += 1) {
      const highlow = { ...(engine.create(roster) as any), challenge: { kind: 'highlow', card: 1 + (trial % 13) } };
      const done = engine.apply(highlow, 'player-0', engine.botAction(highlow), roster) as any;
      expect([0, 50, 100]).toContain(done.lastResult.points);
      expect(done.lastResult.detail).toContain('then');
      const cups = { ...(engine.create(roster) as any), challenge: { kind: 'cups' } };
      const cupped = engine.apply(cups, 'player-0', engine.botAction(cups), roster) as any;
      expect([10, 100]).toContain(cupped.lastResult.points);
    }
  });

  it('rejects wrong-challenge payloads and double plays', () => {
    const engine = new QuickChallengesEngine();
    const roster = players(2);
    const stop = { ...(engine.create(roster) as any), challenge: { kind: 'stop', zone: [45, 55] } };
    expect(() => engine.apply(stop, 'player-0', { type: 'play', cup: 1 }, roster)).toThrow('value');
    const highlow = { ...(engine.create(roster) as any), challenge: { kind: 'highlow', card: 7 } };
    expect(() => engine.apply(highlow, 'player-0', { type: 'play', guess: 'sideways' }, roster)).toThrow('high or low');
    const played = engine.apply(stop, 'player-0', { type: 'play', value: 50 }, roster) as any;
    expect(played.turnPlayerId).toBe('player-1');
    expect(() => engine.apply(played, 'player-0', { type: 'play', value: 50 }, roster)).toThrow('not your turn');
  });

  it('rotates seven rounds and finishes a full bot game', () => {
    const engine = new QuickChallengesEngine();
    const roster = players(3);
    let state = engine.create(roster) as any;
    const kinds = new Set<string>();
    for (let turn = 0; turn < 120 && !state.finished; turn += 1) {
      kinds.add((state.challenge as { kind: string }).kind);
      const actor = state.turnPlayerId as string;
      state = engine.apply(state, actor, engine.botAction(state), roster);
    }
    expect(state.finished).toBe(true);
    expect(state.round).toBe(7);
    expect(state.history).toHaveLength(21);
    expect(kinds.size).toBeGreaterThan(1);
    expect(['player-0', 'player-1', 'player-2']).toContain(state.winnerId);
  });
});
