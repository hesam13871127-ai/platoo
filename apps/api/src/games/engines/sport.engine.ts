import { Action, asInt, GameEngine, GameId, GameOutcome, GamePlayer, GameState, IllegalMoveError, clone, randomInt, rotateTurn } from '../game.types';

const turn = (state: GameState, actorId: string) => { if (state.finished) throw new IllegalMoveError('This game has finished.'); if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.'); };
const outcome = (state: GameState, players: GamePlayer[]): GameOutcome => { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; };

export class ArcheryEngine implements GameEngine {
  readonly id: GameId = 'archery';
  create(players: GamePlayer[]): GameState { return { round: 1, rounds: 5, scores: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action): void { turn(state, actorId); if (action.type !== 'shoot') throw new IllegalMoveError('Use shoot.'); asInt(action.accuracy, 'accuracy', 0, 100); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); const accuracy = action.accuracy as number; (next.scores as number[])[side] += Math.max(0, Math.round(10 - Math.abs(50 - accuracy) / 5)); if (Number(next.round) >= Number(next.rounds)) { next.finished = true; const max = Math.max(...(next.scores as number[])); next.winnerId = players[(next.scores as number[]).indexOf(max)].id; next.draw = (next.scores as number[]).filter((score) => score === max).length > 1; } else { next.round = Number(next.round) + 1; rotateTurn(next, players); } return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }
  botAction(): Action { return { type: 'shoot', accuracy: 50 + randomInt(31) - 15 }; }
}

export class BowlingEngine implements GameEngine {
  readonly id: GameId = 'bowling';
  create(players: GamePlayer[]): GameState { return { frame: 1, roll: 1, frames: players.map(() => []), totals: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action): void { turn(state, actorId); if (action.type !== 'roll') throw new IllegalMoveError('Use roll.'); asInt(action.pins, 'pins', 0, 10); const pins = action.pins as number; const side = Number(state.turnIndex); const rolls = (state.frames as number[][][])[side][Number(state.frame) - 1] ?? []; if (rolls.length === 1 && rolls[0] < 10 && rolls[0] + pins > 10) throw new IllegalMoveError('Pins in a frame cannot exceed ten.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); const frameIndex = Number(next.frame) - 1; const frames = next.frames as number[][][]; if (!frames[side][frameIndex]) frames[side][frameIndex] = []; frames[side][frameIndex].push(action.pins as number); (next.totals as number[])[side] += action.pins as number; const finishedFrame = frames[side][frameIndex][0] === 10 || frames[side][frameIndex].length === 2; if (finishedFrame) { if (Number(next.frame) === 10) { next.finished = true; const max = Math.max(...(next.totals as number[])); next.winnerId = players[(next.totals as number[]).indexOf(max)].id; next.draw = (next.totals as number[]).filter((score) => score === max).length > 1; } else if (Number(next.turnIndex) < players.length - 1) { next.turnIndex = Number(next.turnIndex) + 1; next.turnPlayerId = players[Number(next.turnIndex)].id; } else { next.frame = Number(next.frame) + 1; next.turnIndex = 0; next.turnPlayerId = players[0].id; } } else { next.turnIndex = side; next.turnPlayerId = actorId; } return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }
  botAction(): Action { return { type: 'roll', pins: randomInt(11) }; }
}

export class DartsEngine implements GameEngine {
  readonly id: GameId = 'darts';
  create(players: GamePlayer[]): GameState { return { target: 301, scores: players.map(() => 301), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { turn(state, actorId); if (action.type !== 'throw') throw new IllegalMoveError('Use throw.'); const value = asInt(action.value, 'value', 0, 60); const side = players.findIndex((p) => p.id === actorId); const score = (state.scores as number[])[side]; if (score - value < 0) throw new IllegalMoveError('Bust: you cannot go below zero.'); if (score - value === 1) throw new IllegalMoveError('A score of one is a bust.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); (next.scores as number[])[side] -= action.value as number; if ((next.scores as number[])[side] === 0) { next.finished = true; next.winnerId = actorId; } else rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action { const score = (state.scores as number[])[players.findIndex((p) => p.id === botId)]; return { type: 'throw', value: Math.min(score, score === 1 ? 0 : randomInt(Math.min(60, score) + 1)) }; }
}

export class MiniGolfEngine implements GameEngine {
  readonly id: GameId = 'mini_golf';
  create(players: GamePlayer[]): GameState { return { hole: 1, holes: 9, strokes: players.map(() => 0), holeStrokes: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action): void { turn(state, actorId); if (action.type !== 'putt') throw new IllegalMoveError('Use putt.'); asInt(action.strokes, 'strokes', 1, 12); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); const strokes = action.strokes as number; (next.strokes as number[])[side] += strokes; (next.holeStrokes as number[])[side] += strokes; if (Number(next.hole) >= Number(next.holes)) { next.finished = true; const min = Math.min(...(next.strokes as number[])); next.winnerId = players[(next.strokes as number[]).indexOf(min)].id; next.draw = (next.strokes as number[]).filter((score) => score === min).length > 1; } else { next.hole = Number(next.hole) + 1; next.holeStrokes = players.map(() => 0); rotateTurn(next, players); } return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }
  botAction(): Action { return { type: 'putt', strokes: 2 + randomInt(4) }; }
}

export class TableSoccerEngine implements GameEngine {
  readonly id: GameId = 'table_soccer';
  create(players: GamePlayer[]): GameState { return { goals: players.map(() => 0), target: 5, turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action): void { turn(state, actorId); if (action.type !== 'shoot') throw new IllegalMoveError('Use shoot.'); asInt(action.power, 'power', 0, 100); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); const scored = Math.random() < (action.power as number) / 125; if (scored) (next.goals as number[])[side] += 1; if ((next.goals as number[])[side] >= Number(next.target)) { next.finished = true; next.winnerId = actorId; } else rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { return outcome(state, players); }
  botAction(): Action { return { type: 'shoot', power: 70 }; }
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
