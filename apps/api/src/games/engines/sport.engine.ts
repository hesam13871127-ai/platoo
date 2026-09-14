import { Action, asInt, GameEngine, GameId, GameOutcome, GamePlayer, GameState, IllegalMoveError, clone, randomInt, rotateTurn } from '../game.types';

const turn = (state: GameState, actorId: string) => { if (state.finished) throw new IllegalMoveError('This game has finished.'); if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.'); };
const outcome = (state: GameState, players: GamePlayer[]): GameOutcome => { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; };

interface ArcheryState extends GameState {
  round: number;
  rounds: number;
  scores: number[];
  shots: number[];
  wind: number;
  lastShot: { playerId: string; accuracy: number; wind: number; effective: number; points: number; label: string } | null;
  history: Array<{ playerId: string; accuracy: number; wind: number; effective: number; points: number }>;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  draw?: boolean;
}

const archeryLabel = (points: number): string => {
  if (points <= 0) return 'Miss';
  if (points >= 10) return 'Bullseye!';
  if (points >= 8) return 'Gold';
  if (points >= 5) return 'Red';
  if (points >= 3) return 'Blue';
  return 'Outer ring';
};

// Fresh wind (-10..+10) is dealt for every arrow and shown before the shot, so
// archers compensate their aim instead of tapping the same spot every turn.
const dealWind = (): number => randomInt(21) - 10;

export class ArcheryEngine implements GameEngine {
  readonly id: GameId = 'archery';

  create(players: GamePlayer[]): ArcheryState {
    if (players.length < 1 || players.length > 4) throw new IllegalMoveError('Archery supports one to four players.');
    return {
      round: 1,
      rounds: 5,
      scores: players.map(() => 0),
      shots: players.map(() => 0),
      wind: dealWind(),
      lastShot: null,
      history: [],
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
    };
  }

  validate(state: ArcheryState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    turn(state, actorId);
    if (action.type !== 'shoot') throw new IllegalMoveError('Use shoot.');
    asInt(action.accuracy, 'accuracy', 0, 100);
  }

  apply(state: ArcheryState, actorId: string, action: Action, players: GamePlayer[]): ArcheryState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as ArcheryState;
    const side = players.findIndex((player) => player.id === actorId);
    const accuracy = action.accuracy as number;
    const wind = Number(next.wind) || 0;
    const effective = Math.min(100, Math.max(0, accuracy + wind));
    const points = Math.max(0, Math.round(10 - Math.abs(50 - effective) / 5));
    next.scores[side] += points;
    const shots = (Array.isArray(next.shots) ? next.shots : players.map(() => 0)) as number[];
    shots[side] = (shots[side] ?? 0) + 1;
    next.shots = shots;
    next.lastShot = { playerId: actorId, accuracy, wind, effective, points, label: archeryLabel(points) };
    next.history.push({ playerId: actorId, accuracy, wind, effective, points });
    if (shots.every((count) => count >= Number(next.rounds))) {
      next.finished = true;
      const max = Math.max(...next.scores);
      next.winnerId = players[next.scores.indexOf(max)].id;
      next.draw = next.scores.filter((score) => score === max).length > 1;
    } else {
      next.round = Math.min(...shots) + 1;
      next.wind = dealWind();
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: ArcheryState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }

  botAction(state: ArcheryState): Action {
    const wind = Number(state.wind) || 0;
    const aim = Math.min(100, Math.max(0, 50 - wind + (randomInt(13) - 6)));
    return { type: 'shoot', accuracy: aim };
  }
}

interface BowlingState extends GameState {
  frame: number;
  ball: number;
  frames: number[][][];
  totals: number[];
  scorecard: (number | null)[][];
  lastRoll: { playerId: string; frame: number; pins: number } | null;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  draw?: boolean;
}

const tenthFrameComplete = (rolls: number[]): boolean => {
  if (rolls.length < 2) return false;
  if (rolls.length >= 3) return true;
  const [first, second] = rolls;
  return first !== 10 && first + second !== 10; // An open tenth ends after two balls.
};

const bowlingFrameComplete = (rolls: number[], frameIndex: number): boolean =>
  frameIndex < 9 ? rolls[0] === 10 || rolls.length >= 2 : tenthFrameComplete(rolls);

const bowlingMaxPins = (rolls: number[], frameIndex: number): number => {
  if (frameIndex < 9) {
    if (!rolls.length) return 10;
    return rolls[0] === 10 ? 0 : 10 - rolls[0];
  }
  const [first, second] = rolls;
  if (!rolls.length) return 10;
  if (rolls.length === 1) return first === 10 ? 10 : 10 - first;
  if (first === 10 && second === 10) return 10;
  if (first === 10) return 10 - second;
  return 10; // A spare on the first two tenth-frame balls re-racks the pins.
};

const scoreBowlingFrames = (frames: number[][]): { frameScores: (number | null)[]; total: number } => {
  const balls = frames.flat();
  const frameScores: (number | null)[] = [];
  let total = 0;
  let ballIndex = 0;
  for (let frame = 0; frame < 10; frame += 1) {
    const rolls = frames[frame] ?? [];
    if (frame === 9) {
      if (tenthFrameComplete(rolls)) {
        total += rolls.reduce((sum, pins) => sum + pins, 0);
        frameScores.push(total);
      } else frameScores.push(null);
      continue;
    }
    if (!rolls.length) {
      frameScores.push(null);
      continue;
    }
    if (rolls[0] === 10) {
      if (balls.length > ballIndex + 2) {
        total += 10 + balls[ballIndex + 1] + balls[ballIndex + 2];
        frameScores.push(total);
      } else frameScores.push(null);
      ballIndex += 1;
      continue;
    }
    if (rolls.length < 2) {
      frameScores.push(null);
      ballIndex += 1;
      continue;
    }
    if (rolls[0] + rolls[1] === 10) {
      if (balls.length > ballIndex + 2) {
        total += 10 + balls[ballIndex + 2];
        frameScores.push(total);
      } else frameScores.push(null);
    } else {
      total += rolls[0] + rolls[1];
      frameScores.push(total);
    }
    ballIndex += 2;
  }
  return { frameScores, total };
};

export class BowlingEngine implements GameEngine {
  readonly id: GameId = 'bowling';

  create(players: GamePlayer[]): BowlingState {
    if (players.length < 1 || players.length > 4) throw new IllegalMoveError('Bowling supports one to four players.');
    return {
      frame: 1,
      ball: 1,
      frames: players.map(() => []),
      totals: players.map(() => 0),
      scorecard: players.map(() => Array(10).fill(null)),
      lastRoll: null,
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
    };
  }

  validate(state: BowlingState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    turn(state, actorId);
    if (action.type !== 'roll') throw new IllegalMoveError('Use roll.');
    const frameIndex = Math.max(0, Number(state.frame) - 1);
    const rolls = (state.frames[side] ?? [])[frameIndex] ?? [];
    if (bowlingFrameComplete(rolls, frameIndex)) throw new IllegalMoveError('This frame is already complete.');
    asInt(action.pins, 'pins', 0, bowlingMaxPins(rolls, frameIndex));
  }

  apply(state: BowlingState, actorId: string, action: Action, players: GamePlayer[]): BowlingState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as BowlingState;
    const side = players.findIndex((player) => player.id === actorId);
    const frameIndex = Math.max(0, Number(next.frame) - 1);
    if (!next.frames[side][frameIndex]) next.frames[side][frameIndex] = [];
    next.frames[side][frameIndex].push(action.pins as number);
    const scored = scoreBowlingFrames(next.frames[side]);
    next.totals[side] = scored.total;
    next.scorecard[side] = scored.frameScores;
    next.lastRoll = { playerId: actorId, frame: frameIndex + 1, pins: action.pins as number };
    if (bowlingFrameComplete(next.frames[side][frameIndex], frameIndex)) {
      if (frameIndex === 9 && side >= players.length - 1) {
        next.finished = true;
        const max = Math.max(...next.totals);
        next.winnerId = players[next.totals.indexOf(max)].id;
        next.draw = next.totals.filter((total) => total === max).length > 1;
      } else if (side < players.length - 1) {
        next.turnIndex = side + 1;
        next.turnPlayerId = players[side + 1].id;
        next.ball = 1;
      } else {
        next.frame = frameIndex + 2;
        next.turnIndex = 0;
        next.turnPlayerId = players[0].id;
        next.ball = 1;
      }
    } else {
      next.turnIndex = side;
      next.turnPlayerId = actorId;
      next.ball = Number(next.ball) + 1;
    }
    return next;
  }

  outcome(state: BowlingState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }

  botAction(state: BowlingState, botId: string, players: GamePlayer[]): Action {
    const index = players.findIndex((player) => player.id === botId);
    const side = index >= 0 ? index : Number(state.turnIndex);
    const frameIndex = Math.max(0, Number(state.frame) - 1);
    const rolls = ((state.frames as number[][][])[side] ?? [])[frameIndex] ?? [];
    const max = bowlingMaxPins(rolls, frameIndex);
    const skilled = randomInt(10) < 6;
    return { type: 'roll', pins: skilled ? Math.max(0, max - randomInt(4)) : randomInt(max + 1) };
  }
}

interface DartsState extends GameState {
  target: number;
  scores: number[];
  dartsLeft: number;
  visitDarts: number[];
  lastVisit: { playerId: string; darts: number[]; total: number } | null;
  history: Array<{ playerId: string; darts: number[]; total: number }>;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
}

export class DartsEngine implements GameEngine {
  readonly id: GameId = 'darts';

  create(players: GamePlayer[]): DartsState {
    if (players.length < 1 || players.length > 4) throw new IllegalMoveError('Darts supports one to four players.');
    return {
      target: 301,
      scores: players.map(() => 301),
      dartsLeft: 3,
      visitDarts: [],
      lastVisit: null,
      history: [],
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
    };
  }

  validate(state: DartsState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    turn(state, actorId);
    if (action.type !== 'throw') throw new IllegalMoveError('Use throw.');
    const value = asInt(action.value, 'value', 0, 60);
    const score = (state.scores as number[])[side];
    if (score - value < 0) throw new IllegalMoveError('Bust: you cannot go below zero.');
    if (score - value === 1) throw new IllegalMoveError('A score of one is a bust.');
  }

  apply(state: DartsState, actorId: string, action: Action, players: GamePlayer[]): DartsState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as DartsState;
    const side = players.findIndex((player) => player.id === actorId);
    const value = action.value as number;
    next.scores[side] -= value;
    next.visitDarts.push(value);
    next.dartsLeft = Number(next.dartsLeft) - 1;
    const visit = { playerId: actorId, darts: [...next.visitDarts], total: next.visitDarts.reduce((sum, dart) => sum + dart, 0) };
    if (next.scores[side] === 0) {
      next.lastVisit = visit;
      next.history.push(visit);
      next.finished = true;
      next.winnerId = actorId;
      return next;
    }
    if (next.dartsLeft <= 0) {
      next.lastVisit = visit;
      next.history.push(visit);
      next.visitDarts = [];
      next.dartsLeft = 3;
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: DartsState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }

  botAction(state: DartsState, botId: string, players: GamePlayer[]): Action {
    const index = players.findIndex((player) => player.id === botId);
    const side = index >= 0 ? index : Number(state.turnIndex);
    const score = (state.scores as number[])[side];
    if (score >= 1 && score <= 60) return { type: 'throw', value: score };
    if (score <= 0) return { type: 'throw', value: 0 };
    return { type: 'throw', value: randomInt(Math.min(60, Math.max(0, score - 2)) + 1) };
  }
}

interface MiniGolfState extends GameState {
  hole: number;
  holes: number;
  completedHoles: number;
  pars: number[];
  strokes: number[];
  holeStrokes: Array<number | null>;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  winnerIds: string[];
  lastStroke: { playerId: string; hole: number; strokes: number } | null;
  draw?: boolean;
}

export class MiniGolfEngine implements GameEngine {
  readonly id: GameId = 'mini_golf';

  create(players: GamePlayer[]): MiniGolfState {
    if (players.length < 2 || players.length > 4) throw new IllegalMoveError('Mini Golf supports two to four players.');
    return {
      hole: 1,
      holes: 9,
      completedHoles: 0,
      pars: [3, 4, 3, 5, 4, 3, 4, 5, 4],
      strokes: players.map(() => 0),
      holeStrokes: players.map(() => null),
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
      winnerIds: [],
      lastStroke: null,
    };
  }

  validate(state: MiniGolfState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    turn(state, actorId);
    if (action.type !== 'putt') throw new IllegalMoveError('Use putt.');
    asInt(action.strokes, 'strokes', 1, 12);
    if (state.holeStrokes[side] !== null) throw new IllegalMoveError('You already completed this hole.');
  }

  apply(state: MiniGolfState, actorId: string, action: Action, players: GamePlayer[]): MiniGolfState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as MiniGolfState;
    const side = players.findIndex((player) => player.id === actorId);
    const strokes = action.strokes as number;
    next.holeStrokes[side] = strokes;
    next.strokes[side] += strokes;
    next.lastStroke = { playerId: actorId, hole: next.hole, strokes };

    if (next.holeStrokes.every((value) => value !== null)) {
      next.completedHoles = next.hole;
      if (next.hole >= next.holes) {
        const minimum = Math.min(...next.strokes);
        next.winnerIds = next.strokes.map((score, index) => score === minimum ? players[index].id : null).filter((id): id is string => id !== null);
        next.winnerId = next.winnerIds[0] ?? null;
        next.draw = next.winnerIds.length > 1;
        next.finished = true;
      } else {
        next.hole += 1;
        next.holeStrokes = players.map(() => null);
        next.turnIndex = 0;
        next.turnPlayerId = players[0].id;
      }
    } else {
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: MiniGolfState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) && state.winnerIds.length ? state.winnerIds : state.winnerId ? [state.winnerId] : [];
    return { finished: Boolean(state.finished), winnerIds: winners, loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [], draw: Boolean(state.draw) };
  }

  botAction(state: MiniGolfState, botId: string): Action {
    const hole = Math.max(1, Number(state.hole) || 1);
    const par = Number(state.pars[hole - 1] ?? 4);
    return { type: 'putt', strokes: Math.min(12, par + randomInt(4)) };
  }
}

interface TableSoccerState extends GameState {
  goals: number[];
  teamGoals: number[];
  teamMode: boolean;
  target: number;
  shots: number;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  winnerIds: string[];
  lastShot: { actorId: string; power: number; aim: number; scored: boolean } | null;
  draw?: boolean;
}

export class TableSoccerEngine implements GameEngine {
  readonly id: GameId = 'table_soccer';

  create(players: GamePlayer[]): TableSoccerState {
    if (players.length < 2 || players.length > 4) throw new IllegalMoveError('Table Soccer supports two to four players.');
    const teamMode = players.length === 4 && players.every((player) => player.team !== undefined);
    return {
      goals: players.map(() => 0),
      teamGoals: teamMode ? [0, 0] : [],
      teamMode,
      target: 5,
      shots: 0,
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
      winnerIds: [],
      lastShot: null,
    };
  }

  validate(state: TableSoccerState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    turn(state, actorId);
    if (action.type !== 'shoot') throw new IllegalMoveError('Use shoot.');
    asInt(action.power, 'power', 1, 100);
    if (action.aim !== undefined) asInt(action.aim, 'aim', 0, 100);
  }

  apply(state: TableSoccerState, actorId: string, action: Action, players: GamePlayer[]): TableSoccerState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as TableSoccerState;
    const side = players.findIndex((player) => player.id === actorId);
    const power = action.power as number;
    const aim = action.aim === undefined ? 50 : action.aim as number;
    const accuracy = Math.max(0, 1 - Math.abs(aim - 50) / 50);
    const chancePercent = Math.min(78, 16 + Math.round(power / 2.5) + Math.round(accuracy * 20));
    const scored = randomInt(100) < chancePercent;
    next.shots += 1;
    next.lastShot = { actorId, power, aim, scored };
    if (scored) {
      next.goals[side] += 1;
      if (next.teamMode) {
        const team = players[side].team as number;
        next.teamGoals[team] += 1;
      }
      const score = next.teamMode ? next.teamGoals[players[side].team as number] : next.goals[side];
      if (score >= next.target) {
        next.winnerIds = next.teamMode
          ? players.filter((player) => player.team === players[side].team).map((player) => player.id)
          : [actorId];
        next.winnerId = next.winnerIds[0] ?? null;
        next.finished = true;
        return next;
      }
    }
    rotateTurn(next, players);
    return next;
  }

  outcome(state: TableSoccerState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) && state.winnerIds.length ? state.winnerIds : state.winnerId ? [state.winnerId] : [];
    return { finished: Boolean(state.finished), winnerIds: winners, loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [], draw: Boolean(state.draw) };
  }

  botAction(_state: TableSoccerState, _botId: string, _players: GamePlayer[]): Action { return { type: 'shoot', power: 70, aim: 50 }; }
}

export class ScoreChallengeEngine implements GameEngine {
  readonly id: GameId;
  private readonly rounds: number;
  constructor(id: GameId, rounds = 7) { this.id = id; this.rounds = rounds; }
  create(players: GamePlayer[]): GameState { return { round: 1, rounds: this.rounds, scores: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action): void { turn(state, actorId); if (action.type !== 'challenge') throw new IllegalMoveError('Complete the challenge.'); asInt(action.score, 'score', 0, 100); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); (next.scores as number[])[side] += action.score as number; if (Number(next.round) >= Number(next.rounds)) { next.finished = true; const max = Math.max(...(next.scores as number[])); next.winnerId = players[(next.scores as number[]).indexOf(max)].id; } else { next.round = Number(next.round) + 1; rotateTurn(next, players); } return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }
  botAction(): Action { return { type: 'challenge', score: 50 + randomInt(51) }; }
}
