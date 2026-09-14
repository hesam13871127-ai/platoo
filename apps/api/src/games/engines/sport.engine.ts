import { Action, asInt, GameEngine, GameId, GameOutcome, GamePlayer, GameState, IllegalMoveError, clone, randomInt, rotateTurn } from '../game.types';

const turn = (state: GameState, actorId: string) => { if (state.finished) throw new IllegalMoveError('This game has finished.'); if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.'); };
const outcome = (state: GameState, players: GamePlayer[]): GameOutcome => { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; };

export class ArcheryEngine implements GameEngine {
  readonly id: GameId = 'archery';
  create(players: GamePlayer[]): GameState { return { round: 1, rounds: 5, scores: players.map(() => 0), shots: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action): void { turn(state, actorId); if (action.type !== 'shoot') throw new IllegalMoveError('Use shoot.'); asInt(action.accuracy, 'accuracy', 0, 100); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); const accuracy = action.accuracy as number; (next.scores as number[])[side] += Math.max(0, Math.round(10 - Math.abs(50 - accuracy) / 5)); const shots = (Array.isArray(next.shots) ? next.shots : players.map(() => 0)) as number[]; shots[side] = (shots[side] ?? 0) + 1; next.shots = shots; if (shots.every((count) => count >= Number(next.rounds))) { next.finished = true; const max = Math.max(...(next.scores as number[])); next.winnerId = players[(next.scores as number[]).indexOf(max)].id; next.draw = (next.scores as number[]).filter((score) => score === max).length > 1; } else { next.round = Math.min(...shots) + 1; rotateTurn(next, players); } return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }
  botAction(): Action { return { type: 'shoot', accuracy: 50 + randomInt(31) - 15 }; }
}

export class BowlingEngine implements GameEngine {
  readonly id: GameId = 'bowling';
  create(players: GamePlayer[]): GameState { return { frame: 1, roll: 1, frames: players.map(() => []), totals: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action): void { turn(state, actorId); if (action.type !== 'roll') throw new IllegalMoveError('Use roll.'); asInt(action.pins, 'pins', 0, 10); const pins = action.pins as number; const side = Number(state.turnIndex); const rolls = (state.frames as number[][][])[side][Number(state.frame) - 1] ?? []; if (rolls.length === 1 && rolls[0] < 10 && rolls[0] + pins > 10) throw new IllegalMoveError('Pins in a frame cannot exceed ten.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); const frameIndex = Number(next.frame) - 1; const frames = next.frames as number[][][]; if (!frames[side][frameIndex]) frames[side][frameIndex] = []; frames[side][frameIndex].push(action.pins as number); (next.totals as number[])[side] += action.pins as number; const finishedFrame = frames[side][frameIndex][0] === 10 || frames[side][frameIndex].length === 2; if (finishedFrame) { if (Number(next.frame) === 10 && Number(next.turnIndex) >= players.length - 1) { next.finished = true; const max = Math.max(...(next.totals as number[])); next.winnerId = players[(next.totals as number[]).indexOf(max)].id; next.draw = (next.totals as number[]).filter((score) => score === max).length > 1; } else if (Number(next.turnIndex) < players.length - 1) { next.turnIndex = Number(next.turnIndex) + 1; next.turnPlayerId = players[Number(next.turnIndex)].id; } else { next.frame = Number(next.frame) + 1; next.turnIndex = 0; next.turnPlayerId = players[0].id; } } else { next.turnIndex = side; next.turnPlayerId = actorId; } return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action { const index = players.findIndex((p) => p.id === botId); const side = index >= 0 ? index : Number(state.turnIndex); const rolls = ((state.frames as number[][][])[side] ?? [])[Number(state.frame) - 1] ?? []; const max = rolls.length === 1 && rolls[0] < 10 ? 10 - rolls[0] : 10; return { type: 'roll', pins: randomInt(max + 1) }; }
}

export class DartsEngine implements GameEngine {
  readonly id: GameId = 'darts';
  create(players: GamePlayer[]): GameState { return { target: 301, scores: players.map(() => 301), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { turn(state, actorId); if (action.type !== 'throw') throw new IllegalMoveError('Use throw.'); const value = asInt(action.value, 'value', 0, 60); const side = players.findIndex((p) => p.id === actorId); const score = (state.scores as number[])[side]; if (score - value < 0) throw new IllegalMoveError('Bust: you cannot go below zero.'); if (score - value === 1) throw new IllegalMoveError('A score of one is a bust.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); (next.scores as number[])[side] -= action.value as number; if ((next.scores as number[])[side] === 0) { next.finished = true; next.winnerId = actorId; } else rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action { const score = (state.scores as number[])[players.findIndex((p) => p.id === botId)]; if (score <= 1) return { type: 'throw', value: Math.max(0, score) }; let value = randomInt(Math.min(60, score) + 1); if (score - value === 1) value -= 1; return { type: 'throw', value }; }
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
