import { Action, asInt, GameEngine, GameId, GameOutcome, GamePlayer, GameState, IllegalMoveError, clone, nextTurn, randomInt, rotateTurn } from '../game.types';

const ensureTurn = (state: GameState, actorId: string) => { if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.'); if (state.finished) throw new IllegalMoveError('This game has finished.'); };

const LUDO_HOME = -1;
const LUDO_FINISHED = 57;
const LUDO_TRACK_SIZE = 52;

interface LudoState extends GameState {
  positions: number[][];
  pendingRoll: number | null;
  consecutiveSixes: number;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  winnerIds: string[];
  draw?: boolean;
}

export class LudoEngine implements GameEngine {
  readonly id: GameId = 'ludo';

  create(players: GamePlayer[]): LudoState {
    if (players.length < 2 || players.length > 4) throw new IllegalMoveError('Ludo supports two to four players.');
    return {
      positions: players.map(() => [LUDO_HOME, LUDO_HOME, LUDO_HOME, LUDO_HOME]),
      pendingRoll: null,
      consecutiveSixes: 0,
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
      winnerIds: [],
    };
  }

  validate(state: LudoState, actorId: string, action: Action, players: GamePlayer[]): void {
    ensureTurn(state, actorId);
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');

    if (action.type === 'roll') {
      if (state.pendingRoll !== null) throw new IllegalMoveError('Move a token before rolling again.');
      return;
    }
    if (action.type === 'pass') {
      if (state.pendingRoll === null) throw new IllegalMoveError('Roll the dice first.');
      if (this.legalTokens(state, side, Number(state.pendingRoll), players).length) throw new IllegalMoveError('You still have a legal token move.');
      return;
    }
    if (action.type !== 'move' || state.pendingRoll === null) throw new IllegalMoveError('Roll the dice first.');
    const token = asInt(action.token, 'token', 0, 3);
    if (!this.canMove(state, side, token, Number(state.pendingRoll), players)) throw new IllegalMoveError('That token cannot move with this roll.');
  }

  apply(state: LudoState, actorId: string, action: Action, players: GamePlayer[]): LudoState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as LudoState;
    const side = players.findIndex((player) => player.id === actorId);

    if (action.type === 'roll') {
      const die = randomInt(6) + 1;
      if (die === 6 && Number(next.consecutiveSixes) >= 2) {
        next.pendingRoll = null;
        next.consecutiveSixes = 0;
        rotateTurn(next, players);
      } else {
        next.pendingRoll = die;
        next.consecutiveSixes = die === 6 ? Number(next.consecutiveSixes) + 1 : 0;
      }
      return next;
    }

    const die = Number(next.pendingRoll);
    if (action.type === 'pass') {
      next.pendingRoll = null;
      if (die !== 6) {
        next.consecutiveSixes = 0;
        rotateTurn(next, players);
      }
      return next;
    }

    const token = action.token as number;
    const oldPosition = next.positions[side][token];
    const newPosition = oldPosition === LUDO_HOME ? 0 : oldPosition + die;
    next.positions[side][token] = newPosition === LUDO_FINISHED ? LUDO_FINISHED : newPosition;
    this.captureOpponents(next, side, newPosition, players);
    next.pendingRoll = null;

    const winners = this.winners(next, players);
    if (winners.length) {
      next.finished = true;
      next.winnerIds = winners;
      next.winnerId = winners[0];
      return next;
    }

    if (die !== 6) {
      next.consecutiveSixes = 0;
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: LudoState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) ? state.winnerIds : state.winnerId ? [state.winnerId] : [];
    return {
      finished: Boolean(state.finished),
      winnerIds: winners,
      loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [],
      draw: Boolean(state.draw),
    };
  }

  botAction(state: LudoState, botId: string, players: GamePlayer[]): Action {
    const side = players.findIndex((player) => player.id === botId);
    if (state.pendingRoll === null) return { type: 'roll' };
    const die = Number(state.pendingRoll);
    const legal = this.legalTokens(state, side, die, players);
    if (!legal.length) return { type: 'pass' };
    const finishing = legal.find((token) => {
      const position = state.positions[side][token];
      return (position === LUDO_HOME ? 0 : position + die) === LUDO_FINISHED;
    });
    return { type: 'move', token: finishing ?? legal[0] };
  }

  private legalTokens(state: LudoState, side: number, die: number, players: GamePlayer[]): number[] {
    return state.positions[side].map((_, token) => this.canMove(state, side, token, die, players) ? token : -1).filter((token) => token >= 0);
  }

  private canMove(state: LudoState, side: number, token: number, die: number, players: GamePlayer[]): boolean {
    const position = state.positions[side][token];
    if (position === LUDO_FINISHED) return false;
    if (position === LUDO_HOME && die !== 6) return false;
    const destination = position === LUDO_HOME ? 0 : position + die;
    if (destination > LUDO_FINISHED) return false;
    const firstTrackProgress = position === LUDO_HOME ? destination : position + 1;
    for (let progress = firstTrackProgress; progress <= Math.min(destination, LUDO_TRACK_SIZE - 1); progress += 1) {
      if (this.hasOpponentBlockade(state, side, progress, players)) return false;
    }
    return true;
  }

  private hasOpponentBlockade(state: LudoState, side: number, progress: number, players: GamePlayer[]): boolean {
    if (progress >= LUDO_TRACK_SIZE) return false;
    const absolute = this.absolutePosition(side, progress);
    const opponents = state.positions
      .map((positions, other) => other === side || this.sameTeam(players, side, other) ? 0 : positions.filter((position) => position >= 0 && position < LUDO_TRACK_SIZE && this.absolutePosition(other, position) === absolute).length)
      .reduce((sum, count) => sum + count, 0);
    return opponents >= 2;
  }

  private captureOpponents(state: LudoState, side: number, progress: number, players: GamePlayer[]): void {
    if (progress < 0 || progress >= LUDO_TRACK_SIZE || this.isSafeSquare(side, progress)) return;
    const absolute = this.absolutePosition(side, progress);
    for (let other = 0; other < players.length; other += 1) {
      if (other === side || this.sameTeam(players, side, other)) continue;
      const matching = state.positions[other].filter((position) => position >= 0 && position < LUDO_TRACK_SIZE && this.absolutePosition(other, position) === absolute);
      if (matching.length === 1) {
        const token = state.positions[other].findIndex((position) => position >= 0 && position < LUDO_TRACK_SIZE && this.absolutePosition(other, position) === absolute);
        if (token >= 0) state.positions[other][token] = LUDO_HOME;
      }
    }
  }

  private sameTeam(players: GamePlayer[], first: number, second: number): boolean {
    return players.length === 4 && players[first].team !== undefined && players[first].team === players[second].team;
  }

  private winners(state: LudoState, players: GamePlayer[]): string[] {
    const completed = (side: number) => state.positions[side].every((position) => position === LUDO_FINISHED);
    if (players.length === 4 && players.every((player) => player.team !== undefined)) {
      const teams = [...new Set(players.map((player) => player.team as number))];
      for (const team of teams) {
        const members = players.map((player, index) => player.team === team ? index : -1).filter((index) => index >= 0);
        if (members.length && members.every(completed)) return members.map((index) => players[index].id);
      }
    }
    const winner = players.findIndex((_, index) => completed(index));
    return winner >= 0 ? [players[winner].id] : [];
  }

  private absolutePosition(side: number, progress: number): number {
    return (side * 13 + progress) % LUDO_TRACK_SIZE;
  }

  private isSafeSquare(side: number, progress: number): boolean {
    if (progress < 0 || progress >= LUDO_TRACK_SIZE) return true;
    const absolute = this.absolutePosition(side, progress);
    return [0, 8, 13, 21, 26, 34, 39, 47].includes(absolute);
  }
}

interface DominoState extends GameState { hands: number[][][]; chain: number[]; boneyard: number[][]; turnIndex: number; turnPlayerId: string; finished: boolean; winnerId: string | null; draw?: boolean; }
export class DominoesEngine implements GameEngine {
  readonly id: GameId = 'dominoes';
  create(players: GamePlayer[]): DominoState { const deck: number[][] = []; for (let a = 0; a <= 6; a += 1) for (let b = a; b <= 6; b += 1) deck.push([a, b]); for (let i = deck.length - 1; i > 0; i -= 1) { const j = randomInt(i + 1); [deck[i], deck[j]] = [deck[j], deck[i]]; } const hands = players.map(() => deck.splice(0, 7)); return { hands, chain: [], boneyard: deck, turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: DominoState, actorId: string, action: Action, players: GamePlayer[]): void { ensureTurn(state, actorId); const side = players.findIndex((p) => p.id === actorId); if (action.type === 'draw') { if (!state.boneyard.length) throw new IllegalMoveError('The boneyard is empty.'); return; } if (action.type !== 'play') throw new IllegalMoveError('Use play or draw.'); const index = asInt(action.index, 'index', 0, state.hands[side].length - 1); const tile = state.hands[side][index]; const left = state.chain[0]; const right = state.chain[state.chain.length - 1]; if (state.chain.length && tile[0] !== left && tile[1] !== left && tile[0] !== right && tile[1] !== right) throw new IllegalMoveError('That tile does not match either end.'); if (action.side !== undefined && action.side !== 'left' && action.side !== 'right') throw new IllegalMoveError('side must be left or right.'); }
  apply(state: DominoState, actorId: string, action: Action, players: GamePlayer[]): DominoState { this.validate(state, actorId, action, players); const next = clone(state) as DominoState; const side = players.findIndex((p) => p.id === actorId); if (action.type === 'draw') { next.hands[side].push(next.boneyard.pop() as number[]); return next; } const tile = next.hands[side].splice(action.index as number, 1)[0]; if (!next.chain.length) next.chain.push(...tile); else { const place = action.side === 'left' ? 'left' : action.side === 'right' ? 'right' : tile.includes(next.chain[0]) ? 'left' : 'right'; if (place === 'left') { const value = next.chain[0]; const oriented = tile[0] === value ? [tile[1], tile[0]] : [tile[0], tile[1]]; next.chain.unshift(...oriented); } else { const value = next.chain[next.chain.length - 1]; const oriented = tile[0] === value ? tile : [tile[1], tile[0]]; next.chain.push(...oriented); } } if (!next.hands[side].length) { next.finished = true; next.winnerId = actorId; } else if (!this.hasAnyMove(next.hands, next.chain) && !next.boneyard.length) { next.finished = true; const scores = next.hands.map((hand) => hand.reduce((sum, tile) => sum + tile[0] + tile[1], 0)); const min = Math.min(...scores); const winner = scores.indexOf(min); next.winnerId = players[winner].id; next.draw = scores.filter((score) => score === min).length > 1; } else rotateTurn(next, players); return next; }
  outcome(state: DominoState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; }
  botAction(state: DominoState, botId: string, players: GamePlayer[]): Action { const side = players.findIndex((p) => p.id === botId); const legal = state.hands[side].map((tile, index) => ({ tile, index })).filter(({ tile }) => !state.chain.length || tile.some((v) => v === state.chain[0] || v === state.chain[state.chain.length - 1])); return legal.length ? { type: 'play', index: legal[0].index, side: 'right' } : { type: 'draw' }; }
  private hasAnyMove(hands: number[][][], chain: number[]): boolean { return hands.some((hand) => hand.some((tile) => !chain.length || tile.some((v) => v === chain[0] || v === chain[chain.length - 1]))); }
}

interface BackgammonState extends GameState { points: number[]; bar: number[]; borneOff: number[]; dice: number[]; turnIndex: number; turnPlayerId: string; finished: boolean; winnerId: string | null; }
export class BackgammonEngine implements GameEngine {
  readonly id: GameId = 'backgammon';
  create(players: GamePlayer[]): BackgammonState { const points = Array(24).fill(0); points[0] = 2; points[11] = 5; points[16] = 3; points[18] = 5; points[23] = -2; points[12] = -5; points[7] = -3; points[5] = -5; return { points, bar: [0, 0], borneOff: [0, 0], dice: [], turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: BackgammonState, actorId: string, action: Action, players: GamePlayer[]): void { ensureTurn(state, actorId); const side = players.findIndex((p) => p.id === actorId); if (action.type === 'roll') { if (state.dice.length) throw new IllegalMoveError('Use all dice before rolling.'); return; } if (action.type !== 'move' || !state.dice.length) throw new IllegalMoveError('Roll before moving.'); const from = asInt(action.from, 'from', -1, 23); const to = asInt(action.to, 'to', -1, 24); const points = state.points; const own = side === 0 ? 1 : -1; if (state.bar[side] > 0 && from !== -1) throw new IllegalMoveError('Move a checker from the bar first.'); if (from !== -1 && Math.sign(points[from]) !== own) throw new IllegalMoveError('That point does not contain your checker.'); const distance = side === 0 ? to - from : from - to; if (!state.dice.includes(distance)) throw new IllegalMoveError('That die is not available.'); if (to >= 0 && to < 24 && points[to] * own < -1) throw new IllegalMoveError('That point is blocked.'); }
  apply(state: BackgammonState, actorId: string, action: Action, players: GamePlayer[]): BackgammonState { this.validate(state, actorId, action, players); const next = clone(state) as BackgammonState; const side = players.findIndex((p) => p.id === actorId); if (action.type === 'roll') { const a = randomInt(6) + 1; const b = randomInt(6) + 1; next.dice = a === b ? [a, a, a, a] : [a, b]; return next; } const from = action.from as number; const to = action.to as number; const own = side === 0 ? 1 : -1; const die = side === 0 ? to - from : from - to; const dieIndex = next.dice.indexOf(die); next.dice.splice(dieIndex, 1); if (from === -1) next.bar[side] -= 1; else next.points[from] -= own; if (to < 0 || to > 23) next.borneOff[side] += 1; else { if (next.points[to] * own === -1) { next.points[to] = 0; next.bar[1 - side] += 1; } next.points[to] += own; } if (next.borneOff[side] === 15) { next.finished = true; next.winnerId = actorId; } else if (!next.dice.length) rotateTurn(next, players); return next; }
  outcome(state: BackgammonState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: false }; }
  botAction(state: BackgammonState, botId: string, players: GamePlayer[]): Action { if (!state.dice.length) return { type: 'roll' }; const side = players.findIndex((p) => p.id === botId); const own = side === 0 ? 1 : -1; for (let from = 0; from < 24; from += 1) if (state.points[from] * own > 0) for (const die of state.dice) { const to = side === 0 ? from + die : from - die; if ((to < 0 || to > 23 || state.points[to] * own >= -1) && (to < 0 || to > 23 || Math.sign(state.points[to]) === own || state.points[to] === 0 || state.points[to] * own === -1)) return { type: 'move', from, to }; } return { type: 'move', from: -1, to: side === 0 ? state.dice[0] - 1 : 24 - state.dice[0] }; }
}

export class SeaBattleEngine implements GameEngine {
  readonly id: GameId = 'sea_battle';
  create(players: GamePlayer[]): GameState { return { boards: players.map(() => Array.from({ length: 10 }, () => Array(10).fill(0))), shots: players.map(() => Array.from({ length: 10 }, () => Array(10).fill(-1))), fleets: players.map(() => []), phase: 'placing', turnIndex: 0, turnPlayerId: null, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { const side = players.findIndex((p) => p.id === actorId); if (side < 0) throw new IllegalMoveError('You are not in this game.'); if (state.phase === 'placing') { if (action.type !== 'place') throw new IllegalMoveError('Place your fleet first.'); const cells = action.cells; if (!Array.isArray(cells) || !cells.length) throw new IllegalMoveError('A ship needs cells.'); const sizes = [5, 4, 3, 3, 2]; const fleets = state.fleets as unknown[][][]; if (fleets[side].length >= sizes.length) throw new IllegalMoveError('Your fleet is already placed.'); const expected = sizes[fleets[side].length]; if (cells.length !== expected) throw new IllegalMoveError('Incorrect ship size.'); const board = (state.boards as number[][][])[side]; for (const raw of cells) { if (!Array.isArray(raw) || raw.length !== 2) throw new IllegalMoveError('Invalid ship coordinate.'); const r = asInt(raw[0], 'row', 0, 9); const c = asInt(raw[1], 'column', 0, 9); if (board[r][c]) throw new IllegalMoveError('Ships may not overlap.'); } return; } if (action.type !== 'fire') throw new IllegalMoveError('Use fire to attack.'); ensureTurn(state, actorId); asInt(action.row, 'row', 0, 9); asInt(action.column, 'column', 0, 9); const shots = (state.shots as number[][][])[side]; if (shots[action.row as number][action.column as number] !== -1) throw new IllegalMoveError('You already fired there.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); if (next.phase === 'placing') { const cells = action.cells as number[][]; const board = (next.boards as number[][][])[side]; const fleet = (next.fleets as number[][][][])[side]; const id = fleet.length + 1; for (const [r, c] of cells) board[r][c] = id; fleet.push(cells); if ((next.fleets as unknown[][][]).every((ships) => ships.length === 5)) { next.phase = 'battle'; next.turnPlayerId = players[0].id; } return next; } const opponent = 1 - side; const row = action.row as number; const column = action.column as number; const shots = (next.shots as number[][][])[side]; const target = (next.boards as number[][][])[opponent][row][column]; shots[row][column] = target ? 1 : 0; if (target) (next.boards as number[][][])[opponent][row][column] = -target; const remaining = (next.boards as number[][][])[opponent].flat().some((cell) => cell > 0); if (!remaining) { next.finished = true; next.winnerId = actorId; } else rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: false }; }
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action { const side = players.findIndex((p) => p.id === botId); if (state.phase === 'placing') { const sizes = [5,4,3,3,2]; const size = sizes[(state.fleets as unknown[][][])[side].length]; const row = (state.fleets as unknown[][][])[side].length; return { type: 'place', cells: Array.from({ length: size }, (_, i) => [row, i]) }; } const shots = (state.shots as number[][][])[side]; const open: Array<[number, number]> = []; for (let r = 0; r < 10; r += 1) for (let c = 0; c < 10; c += 1) if (shots[r][c] === -1) open.push([r, c]); const [row, column] = open[randomInt(open.length)] ?? [0, 0]; return { type: 'fire', row, column }; }
}

type PoolGroup = 'solids' | 'stripes';

interface PoolState extends GameState {
  remainingBalls: number[];
  groups: Array<PoolGroup | null>;
  pocketed: number[][];
  phase: 'break' | 'open' | 'assigned';
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  winnerIds: string[];
  shots: number;
  lastShot: { actorId: string; pocketed: number[]; scratch: boolean; legalEight: boolean } | null;
}

export class PoolEngine implements GameEngine {
  readonly id: GameId = 'pool_8_ball';

  create(players: GamePlayer[]): PoolState {
    if (players.length !== 2) throw new IllegalMoveError('Pool 8-ball requires exactly two players.');
    return {
      remainingBalls: Array.from({ length: 15 }, (_, index) => index + 1),
      groups: [null, null],
      pocketed: [[], []],
      phase: 'break',
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
      winnerIds: [],
      shots: 0,
      lastShot: null,
    };
  }

  validate(state: PoolState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    ensureTurn(state, actorId);
    if (action.type !== 'shot') throw new IllegalMoveError('Use the shot action.');
    asInt(action.power, 'power', 1, 100);
    asInt(action.pocket, 'pocket', 0, 5);
    if (action.scratch !== undefined && typeof action.scratch !== 'boolean') throw new IllegalMoveError('scratch must be true or false.');
    const balls = this.pocketedBalls(action);
    for (const ball of balls) if (!state.remainingBalls.includes(ball)) throw new IllegalMoveError('That ball is no longer on the table.');
    if (state.phase === 'break') {
      if (balls.includes(8) && balls.length !== 1) throw new IllegalMoveError('The eight ball must be the only ball called on a break.');
      return;
    }
    const group = state.groups[side];
    const ownRemaining = this.ownRemaining(state, side);
    const objectBalls = balls.filter((ball) => ball !== 8);
    if (group === null && objectBalls.length > 1 && objectBalls.some((ball) => this.groupFor(ball) !== this.groupFor(objectBalls[0]))) throw new IllegalMoveError('Open-table shots must use one group.');
    if (group !== null && ownRemaining > 0 && objectBalls.some((ball) => this.groupFor(ball) !== group)) throw new IllegalMoveError('You must hit your assigned group.');
    if (group !== null && ownRemaining === 0 && objectBalls.length) throw new IllegalMoveError('Your group is cleared. Call the eight ball.');
  }

  apply(state: PoolState, actorId: string, action: Action, players: GamePlayer[]): PoolState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as PoolState;
    const side = players.findIndex((player) => player.id === actorId);
    const balls = this.pocketedBalls(action);
    const scratch = action.scratch === true;
    const legalEight = balls.length === 1 && balls[0] === 8 && !scratch && next.phase !== 'break' && this.canShootEight(next, side);
    next.shots = Number(next.shots) + 1;
    next.remainingBalls = next.remainingBalls.filter((ball) => !balls.includes(ball));
    next.pocketed[side].push(...balls);
    next.lastShot = { actorId, pocketed: balls, scratch, legalEight };

    if (balls.includes(8)) {
      next.finished = true;
      next.winnerId = legalEight || (next.phase === 'break' && !scratch) ? actorId : players[1 - side].id;
      next.winnerIds = [next.winnerId];
      return next;
    }

    if (next.phase === 'break') {
      next.phase = 'open';
      if (balls.length && !next.remainingBalls.some((ball) => ball !== 8)) {
        const firstGroup = this.groupFor(balls[0]);
        next.groups[side] = firstGroup;
        next.groups[1 - side] = firstGroup === 'solids' ? 'stripes' : 'solids';
      }
      if (!balls.length || scratch) rotateTurn(next, players);
      return next;
    }

    if (next.groups[side] === null && balls.length) {
      next.groups[side] = this.groupFor(balls[0]);
      next.groups[1 - side] = next.groups[side] === 'solids' ? 'stripes' : 'solids';
    }
    if (!balls.length || scratch) rotateTurn(next, players);
    return next;
  }

  outcome(state: PoolState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) && state.winnerIds.length ? state.winnerIds : state.winnerId ? [state.winnerId] : [];
    return {
      finished: Boolean(state.finished),
      winnerIds: winners,
      loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [],
      draw: false,
    };
  }

  botAction(state: PoolState, botId: string, players: GamePlayer[]): Action {
    const side = players.findIndex((player) => player.id === botId);
    const available = state.remainingBalls.filter((ball) => ball !== 8);
    if (state.phase === 'break') return { type: 'shot', power: 75, pocket: 0, pocketed: available.length ? [available[0]] : [] };
    const group = state.groups[side];
    const target = group === null
      ? available[0]
      : available.find((ball) => this.groupFor(ball) === group) ?? (this.canShootEight(state, side) ? 8 : undefined);
    return { type: 'shot', power: 65, pocket: 0, pocketed: target === undefined ? [] : [target] };
  }

  private pocketedBalls(action: Action): number[] {
    const raw = action.pocketed === undefined
      ? action.ball === undefined || action.ball === null ? [] : [action.ball]
      : action.pocketed;
    if (!Array.isArray(raw)) throw new IllegalMoveError('pocketed must be an array of ball numbers.');
    const balls = raw.map((value) => asInt(value, 'ball', 1, 15));
    if (new Set(balls).size !== balls.length) throw new IllegalMoveError('A ball may only be pocketed once per shot.');
    return balls;
  }

  private groupFor(ball: number): PoolGroup {
    return ball <= 7 ? 'solids' : 'stripes';
  }

  private ownRemaining(state: PoolState, side: number): number {
    const group = state.groups[side];
    return group === null ? 0 : state.remainingBalls.filter((ball) => ball !== 8 && this.groupFor(ball) === group).length;
  }

  private canShootEight(state: PoolState, side: number): boolean {
    return state.groups[side] !== null && this.ownRemaining(state, side) === 0;
  }
}

export class CarromEngine implements GameEngine {
  readonly id: GameId = 'carrom';
  create(players: GamePlayer[]): GameState { return { coinsRemaining: 19, queenRemaining: true, scores: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { ensureTurn(state, actorId); if (action.type !== 'strike') throw new IllegalMoveError('Use strike.'); asInt(action.power, 'power', 1, 100); asInt(action.pocketed, 'pocketed', 0, 3); if (Number(state.coinsRemaining) <= 0) throw new IllegalMoveError('The board has no coins left.'); if (!players.some((p) => p.id === actorId)) throw new IllegalMoveError('You are not in this game.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); const pocketed = Math.min(Number(action.pocketed), Number(next.coinsRemaining)); next.coinsRemaining = Number(next.coinsRemaining) - pocketed; (next.scores as number[])[side] += pocketed; if (action.queen === true && next.queenRemaining && pocketed > 0) { next.queenRemaining = false; (next.scores as number[])[side] += 3; } if ((next.scores as number[])[side] >= 9 || (Number(next.coinsRemaining) === 0 && !next.queenRemaining)) { next.finished = true; next.winnerId = actorId; } else if (pocketed === 0) rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: false }; }
  botAction(): Action { return { type: 'strike', power: 65, pocketed: 1, queen: false }; }
}
