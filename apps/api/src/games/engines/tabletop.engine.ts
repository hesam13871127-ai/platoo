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
    let best = legal[0];
    let bestScore = -Infinity;
    for (const token of legal) {
      const position = state.positions[side][token];
      const destination = position === LUDO_HOME ? 0 : position + die;
      // No random tiebreak: equal moves prefer the lowest token index so bot
      // play stays deterministic (the dice already provide the variety).
      let score = 0;
      if (destination === LUDO_FINISHED) {
        score += 60;
      } else if (destination >= LUDO_TRACK_SIZE) {
        score += 20 + destination;
      } else {
        const absolute = this.absolutePosition(side, destination);
        const safe = this.isSafeSquare(side, destination);
        if (safe) score += 25;
        if (position === LUDO_HOME) score += 15;
        if (!safe) score += this.captureValue(state, side, absolute, players) - this.dangerValue(state, side, absolute, players);
        score += destination / 4;
      }
      if (position >= 0 && position < LUDO_TRACK_SIZE && this.isSafeSquare(side, position) && destination < LUDO_TRACK_SIZE && !this.isSafeSquare(side, destination)) score -= 12;
      if (score > bestScore) { bestScore = score; best = token; }
    }
    return { type: 'move', token: best };
  }

  private captureValue(state: LudoState, side: number, absolute: number, players: GamePlayer[]): number {
    let value = 0;
    for (let other = 0; other < players.length; other += 1) {
      if (other === side || this.sameTeam(players, side, other)) continue;
      const matching = state.positions[other].filter((position) => position >= 0 && position < LUDO_TRACK_SIZE && this.absolutePosition(other, position) === absolute).length;
      if (matching === 1) value += 35;
    }
    return value;
  }

  private dangerValue(state: LudoState, side: number, absolute: number, players: GamePlayer[]): number {
    let danger = 0;
    for (let other = 0; other < players.length; other += 1) {
      if (other === side || this.sameTeam(players, side, other)) continue;
      for (const position of state.positions[other]) {
        if (position < 0 || position >= LUDO_TRACK_SIZE) continue;
        const behind = (absolute - this.absolutePosition(other, position) + LUDO_TRACK_SIZE) % LUDO_TRACK_SIZE;
        if (behind >= 1 && behind <= 6) danger += 8;
      }
    }
    return danger;
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
      return [];
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

interface DominoState extends GameState {
  hands: number[][][];
  handSizes: number[];
  chain: number[];
  boneyard: number[][];
  passCount: number;
  lastDrawn: number[] | null;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  winnerIds: string[];
  draw?: boolean;
}

export class DominoesEngine implements GameEngine {
  readonly id: GameId = 'dominoes';

  create(players: GamePlayer[]): DominoState {
    if (players.length < 2 || players.length > 4) throw new IllegalMoveError('Dominoes supports two to four players.');
    const deck = this.shuffle(this.fullDeck());
    const hands = players.map(() => deck.splice(0, 7));
    let starter = 0;
    let starterTile: number[] | null = null;
    let starterScore = -1;
    for (let side = 0; side < hands.length; side += 1) {
      for (const tile of hands[side]) {
        const score = tile[0] === tile[1] ? 100 + tile[0] : tile[0] + tile[1];
        if (score > starterScore) { starterScore = score; starter = side; starterTile = tile; }
      }
    }
    if (!starterTile) throw new IllegalMoveError('Could not choose an opening domino.');
    const starterIndex = hands[starter].findIndex((tile) => tile[0] === starterTile![0] && tile[1] === starterTile![1]);
    hands[starter].splice(starterIndex, 1);
    return {
      hands,
      handSizes: hands.map((hand) => hand.length),
      chain: [...starterTile],
      boneyard: deck,
      passCount: 0,
      lastDrawn: null,
      turnIndex: (starter + 1) % players.length,
      turnPlayerId: players[(starter + 1) % players.length].id,
      finished: false,
      winnerId: null,
      winnerIds: [],
    };
  }

  validate(state: DominoState, actorId: string, action: Action, players: GamePlayer[]): void {
    ensureTurn(state, actorId);
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    const legal = this.legalIndices(state.hands[side], state.chain);
    if (action.type === 'draw') {
      if (legal.length) throw new IllegalMoveError('Play a matching tile before drawing.');
      if (!state.boneyard.length) throw new IllegalMoveError('The boneyard is empty. Pass your turn.');
      return;
    }
    if (action.type === 'pass') {
      if (legal.length || state.boneyard.length) throw new IllegalMoveError('Draw or play a tile before passing.');
      return;
    }
    if (action.type !== 'play') throw new IllegalMoveError('Use play, draw, or pass.');
    const index = asInt(action.index, 'index', 0, state.hands[side].length - 1);
    const tile = state.hands[side][index];
    const leftMatch = tile.includes(state.chain[0]);
    const rightMatch = tile.includes(state.chain[state.chain.length - 1]);
    if (!leftMatch && !rightMatch) throw new IllegalMoveError('That tile does not match either end.');
    if (leftMatch && rightMatch && action.side !== 'left' && action.side !== 'right') throw new IllegalMoveError('Choose the left or right end.');
    if (action.side === 'left' && !leftMatch) throw new IllegalMoveError('That tile does not match the left end.');
    if (action.side === 'right' && !rightMatch) throw new IllegalMoveError('That tile does not match the right end.');
    if (action.side !== undefined && action.side !== 'left' && action.side !== 'right') throw new IllegalMoveError('side must be left or right.');
  }

  apply(state: DominoState, actorId: string, action: Action, players: GamePlayer[]): DominoState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as DominoState;
    const side = players.findIndex((player) => player.id === actorId);
    next.lastDrawn = null;
    if (action.type === 'draw') {
      const tile = next.boneyard.pop() as number[];
      next.hands[side].push(tile);
      next.handSizes[side] = next.hands[side].length;
      next.lastDrawn = tile;
      return next;
    }
    if (action.type === 'pass') {
      next.passCount += 1;
      if (next.passCount >= players.length) this.finishBlocked(next, players);
      else rotateTurn(next, players);
      return next;
    }
    const tile = next.hands[side].splice(action.index as number, 1)[0];
    next.handSizes[side] = next.hands[side].length;
    const place = action.side === 'left' ? 'left' : action.side === 'right' ? 'right' : tile.includes(next.chain[0]) ? 'left' : 'right';
    if (place === 'left') {
      const value = next.chain[0];
      next.chain.unshift(tile[0] === value ? tile[1] : tile[0]);
    } else {
      const value = next.chain[next.chain.length - 1];
      next.chain.push(tile[0] === value ? tile[1] : tile[0]);
    }
    next.passCount = 0;
    if (!next.hands[side].length) {
      next.finished = true;
      next.winnerId = players[side].id;
      next.winnerIds = [players[side].id];
    } else if (!this.hasAnyMove(next.hands, next.chain) && !next.boneyard.length) {
      this.finishBlocked(next, players);
    } else {
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: DominoState, players: GamePlayer[]): GameOutcome {
    return { finished: Boolean(state.finished), winnerIds: state.winnerIds, loserIds: state.winnerIds.length ? players.filter((player) => !state.winnerIds.includes(player.id)).map((player) => player.id) : [], draw: Boolean(state.draw) };
  }

  botAction(state: DominoState, botId: string, players: GamePlayer[]): Action {
    const side = players.findIndex((player) => player.id === botId);
    const legal = this.legalIndices(state.hands[side], state.chain);
    if (legal.length) {
      const hand = state.hands[side];
      const leftEnd = state.chain[0];
      const rightEnd = state.chain[state.chain.length - 1];
      let best = legal[0];
      let bestSide: 'left' | 'right' = 'right';
      let bestScore = -Infinity;
      for (const index of legal) {
        const tile = hand[index];
        const candidates: Array<'left' | 'right'> = [...(tile.includes(leftEnd) ? ['left' as const] : []), ...(tile.includes(rightEnd) ? ['right' as const] : [])];
        for (const place of candidates) {
          const matched = place === 'left' ? leftEnd : rightEnd;
          const exposed = tile[0] === matched ? tile[1] : tile[0];
          const futureOptions = hand.filter((other, otherIndex) => otherIndex !== index && other.includes(exposed)).length;
          const score = tile[0] + tile[1] + futureOptions * 2 + Math.random();
          if (score > bestScore) { bestScore = score; best = index; bestSide = place; }
        }
      }
      return { type: 'play', index: best, side: bestSide };
    }
    return state.boneyard.length ? { type: 'draw' } : { type: 'pass' };
  }

  private finishBlocked(state: DominoState, players: GamePlayer[]): void {
    const scores = state.hands.map((hand) => hand.reduce((sum, tile) => sum + tile[0] + tile[1], 0));
    const minimum = Math.min(...scores);
    const winners = scores.map((score, index) => score === minimum ? players[index].id : null).filter((id): id is string => id !== null);
    state.finished = true;
    state.winnerIds = winners;
    state.winnerId = winners[0] ?? null;
    state.draw = winners.length > 1;
  }

  private legalIndices(hand: number[][], chain: number[]): number[] {
    if (!chain.length) return hand.map((_, index) => index);
    const left = chain[0];
    const right = chain[chain.length - 1];
    return hand.map((tile, index) => tile.includes(left) || tile.includes(right) ? index : -1).filter((index) => index >= 0);
  }

  private hasAnyMove(hands: number[][][], chain: number[]): boolean { return hands.some((hand) => this.legalIndices(hand, chain).length > 0); }

  private fullDeck(): number[][] {
    const deck: number[][] = [];
    for (let first = 0; first <= 6; first += 1) for (let second = first; second <= 6; second += 1) deck.push([first, second]);
    return deck;
  }

  private shuffle<T>(values: T[]): T[] {
    for (let index = values.length - 1; index > 0; index -= 1) {
      const swap = randomInt(index + 1);
      [values[index], values[swap]] = [values[swap], values[index]];
    }
    return values;
  }
}

interface BackgammonState extends GameState {
  points: number[];
  bar: number[];
  borneOff: number[];
  dice: number[];
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
}

export class BackgammonEngine implements GameEngine {
  readonly id: GameId = 'backgammon';

  create(players: GamePlayer[]): BackgammonState {
    if (players.length !== 2) throw new IllegalMoveError('Backgammon requires exactly two players.');
    // Positive checkers move from point 0 toward 24; negative checkers move
    // from point 23 toward -1. This is the same orientation used by the
    // mobile board and keeps all move validation server-authoritative.
    const points = Array(24).fill(0) as number[];
    points[0] = 2; points[11] = 5; points[16] = 3; points[18] = 5;
    points[23] = -2; points[12] = -5; points[7] = -3; points[5] = -5;
    return { points, bar: [0, 0], borneOff: [0, 0], dice: [], turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null };
  }

  validate(state: BackgammonState, actorId: string, action: Action, players: GamePlayer[]): void {
    ensureTurn(state, actorId);
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    if (action.type === 'roll') {
      if (state.dice.length) throw new IllegalMoveError('Use all dice before rolling.');
      return;
    }
    if (action.type === 'pass') {
      if (!state.dice.length) throw new IllegalMoveError('Roll before passing.');
      if (this.legalMoves(state, side).length) throw new IllegalMoveError('You have legal moves.');
      return;
    }
    if (action.type !== 'move' || !state.dice.length) throw new IllegalMoveError('Roll before moving.');
    const from = asInt(action.from, 'from', -1, 23);
    const to = asInt(action.to, 'to', -1, 24);
    const own = side === 0 ? 1 : -1;
    if (state.bar[side] > 0 && from !== -1) throw new IllegalMoveError('Move a checker from the bar first.');
    if (from === -1 && state.bar[side] <= 0) throw new IllegalMoveError('You have no checker on the bar.');
    if (from !== -1 && Math.sign(state.points[from]) !== own) throw new IllegalMoveError('That point does not contain your checker.');

    const distance = side === 0 ? to - from : from === -1 ? 24 - to : from - to;
    if (from === -1) {
      if (!state.dice.includes(distance)) throw new IllegalMoveError('That die is not available.');
      const expected = side === 0 ? distance - 1 : 24 - distance;
      if (to !== expected || !this.isOpen(state, to, own)) throw new IllegalMoveError('That bar entry is blocked.');
      return;
    }
    const bearingOff = to === (side === 0 ? 24 : -1);
    if (bearingOff && (state.bar[side] > 0 || (side === 0 ? from < 18 : from > 5))) throw new IllegalMoveError('You may bear off only from your home board.');
    const dieIndex = bearingOff
      ? state.dice.findIndex((die) => die >= distance && this.canBearOff(state, side, from, die))
      : state.dice.indexOf(distance);
    if (dieIndex < 0) throw new IllegalMoveError('That die is not available.');
    if (bearingOff) return;
    if (to < 0 || to > 23 || state.points[to] * own < -1) throw new IllegalMoveError('That point is not an available destination.');
  }

  apply(state: BackgammonState, actorId: string, action: Action, players: GamePlayer[]): BackgammonState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as BackgammonState;
    const side = players.findIndex((player) => player.id === actorId);
    if (action.type === 'roll') {
      const first = randomInt(6) + 1;
      const second = randomInt(6) + 1;
      next.dice = first === second ? [first, first, first, first] : [first, second];
      return next;
    }
    if (action.type === 'pass') {
      next.dice = [];
      rotateTurn(next, players);
      return next;
    }

    const from = action.from as number;
    const to = action.to as number;
    const own = side === 0 ? 1 : -1;
    const distance = side === 0 ? to - from : from === -1 ? 24 - to : from - to;
    const bearingOff = to === (side === 0 ? 24 : -1);
    const dieIndex = bearingOff
      ? next.dice.findIndex((die) => die >= distance && this.canBearOff(next, side, from, die))
      : next.dice.indexOf(distance);
    if (dieIndex < 0) throw new IllegalMoveError('That die is no longer available.');
    next.dice.splice(dieIndex, 1);
    if (from === -1) next.bar[side] -= 1;
    else next.points[from] -= own;

    if (to < 0 || to > 23) {
      next.borneOff[side] += 1;
    } else {
      if (next.points[to] * own === -1) {
        next.points[to] = 0;
        next.bar[1 - side] += 1;
      }
      next.points[to] += own;
    }
    if (next.borneOff[side] === 15) {
      next.finished = true;
      next.winnerId = actorId;
    } else if (!next.dice.length) {
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: BackgammonState, players: GamePlayer[]): GameOutcome {
    const winner = typeof state.winnerId === 'string' ? state.winnerId : '';
    return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((player) => player.id !== winner).map((player) => player.id) : [], draw: false };
  }

  botAction(state: BackgammonState, botId: string, players: GamePlayer[]): Action {
    if (!state.dice.length) return { type: 'roll' };
    const side = players.findIndex((player) => player.id === botId);
    const moves = this.legalMoves(state, side);
    if (!moves.length) return { type: 'pass' };
    // Prefer a hit and then a move that bears off; a small random tie-break
    // keeps bots from making identical, easily exploitable lines.
    moves.sort((a, b) => this.moveValue(state, side, b) - this.moveValue(state, side, a) || Math.random() - 0.5);
    const move = moves[0];
    return { type: 'move', from: move[0], to: move[1] };
  }

  private legalMoves(state: BackgammonState, side: number): Array<[number, number]> {
    const moves: Array<[number, number]> = [];
    const own = side === 0 ? 1 : -1;
    const addForDie = (die: number) => {
      if (state.bar[side] > 0) {
        const to = side === 0 ? die - 1 : 24 - die;
        if (this.isOpen(state, to, own)) moves.push([-1, to]);
        return;
      }
      for (let from = 0; from < 24; from += 1) {
        if (Math.sign(state.points[from]) !== own) continue;
        const destination = side === 0 ? from + die : from - die;
        if (destination >= 0 && destination < 24) {
          if (this.isOpen(state, destination, own)) moves.push([from, destination]);
        } else if (this.canBearOff(state, side, from, die)) {
          moves.push([from, side === 0 ? 24 : -1]);
        }
      }
    };
    for (const die of state.dice) addForDie(die);
    return moves;
  }

  private isOpen(state: BackgammonState, point: number, own: number): boolean {
    return point >= 0 && point < 24 && state.points[point] * own >= -1;
  }

  private canBearOff(state: BackgammonState, side: number, from: number, die: number): boolean {
    const own = side === 0 ? 1 : -1;
    if (state.bar[side] > 0 || from < 0 || from > 23 || Math.sign(state.points[from]) !== own) return false;
    const inHome = side === 0 ? from >= 18 : from <= 5;
    if (!inHome) return false;
    const distance = side === 0 ? 24 - from : from + 1;
    if (die < distance) return false;
    // An oversized die may only bear off the furthest checker: no checker may
    // sit farther from the exit than the one being removed.
    if (die > distance) {
      for (let point = side === 0 ? from + 1 : from - 1; point >= 0 && point < 24; point += side === 0 ? 1 : -1) {
        if (Math.sign(state.points[point]) === own) return false;
      }
    }
    return true;
  }

  private moveValue(state: BackgammonState, side: number, move: [number, number]): number {
    const own = side === 0 ? 1 : -1;
    if (move[1] === (side === 0 ? 24 : -1)) return 100;
    if (move[1] >= 0 && move[1] < 24 && state.points[move[1]] * own === -1) return 70;
    return Math.random() * 8 + (side === 0 ? move[1] : 23 - move[1]);
  }
}

export class SeaBattleEngine implements GameEngine {
  readonly id: GameId = 'sea_battle';

  create(players: GamePlayer[]): GameState {
    if (players.length !== 2) throw new IllegalMoveError('Sea Battle requires exactly two players.');
    return {
      boards: players.map(() => Array.from({ length: 10 }, () => Array(10).fill(0))),
      shots: players.map(() => Array.from({ length: 10 }, () => Array(10).fill(-1))),
      fleets: players.map(() => []),
      phase: 'placing',
      turnIndex: 0,
      turnPlayerId: null,
      finished: false,
      winnerId: null,
    };
  }

  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    const sizes = [5, 4, 3, 3, 2];
    if (state.phase === 'placing') {
      if (action.type !== 'place') throw new IllegalMoveError('Place your fleet first.');
      const cells = action.cells;
      if (!Array.isArray(cells) || !cells.length) throw new IllegalMoveError('A ship needs cells.');
      const fleets = state.fleets as unknown[][][];
      if (fleets[side].length >= sizes.length) throw new IllegalMoveError('Your fleet is already placed.');
      const expected = sizes[fleets[side].length];
      if (cells.length !== expected) throw new IllegalMoveError('Incorrect ship size.');
      const coordinates = cells.map((raw) => {
        if (!Array.isArray(raw) || raw.length !== 2) throw new IllegalMoveError('Invalid ship coordinate.');
        return [asInt(raw[0], 'row', 0, 9), asInt(raw[1], 'column', 0, 9)] as [number, number];
      });
      const keys = coordinates.map(([row, column]) => `${row}:${column}`);
      if (new Set(keys).size !== keys.length) throw new IllegalMoveError('A ship cannot repeat a cell.');
      const sameRow = coordinates.every(([row]) => row === coordinates[0][0]);
      const sameColumn = coordinates.every(([, column]) => column === coordinates[0][1]);
      if (!sameRow && !sameColumn) throw new IllegalMoveError('A ship must be straight.');
      const ordered = coordinates.map(([row, column]) => sameRow ? column : row).sort((a, b) => a - b);
      if (ordered.some((value, index) => index > 0 && value !== ordered[index - 1] + 1)) throw new IllegalMoveError('Ship cells must be contiguous.');
      const board = (state.boards as number[][][])[side];
      for (const [row, column] of coordinates) if (board[row][column]) throw new IllegalMoveError('Ships may not overlap.');
      // Keep a one-cell buffer around ships. It prevents ambiguous hits and
      // matches the no-touching fleet rule used by the board UI.
      for (const [row, column] of coordinates) {
        for (let dr = -1; dr <= 1; dr += 1) for (let dc = -1; dc <= 1; dc += 1) {
          const adjacentRow = row + dr; const adjacentColumn = column + dc;
          if (adjacentRow >= 0 && adjacentRow < 10 && adjacentColumn >= 0 && adjacentColumn < 10 && board[adjacentRow][adjacentColumn]) throw new IllegalMoveError('Ships may not touch.');
        }
      }
      return;
    }
    if (state.phase !== 'battle') throw new IllegalMoveError('This game has finished.');
    if (action.type !== 'fire') throw new IllegalMoveError('Use fire to attack.');
    ensureTurn(state, actorId);
    const row = asInt(action.row, 'row', 0, 9);
    const column = asInt(action.column, 'column', 0, 9);
    const shots = (state.shots as number[][][])[side];
    if (shots[row][column] !== -1) throw new IllegalMoveError('You already fired there.');
  }

  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState {
    this.validate(state, actorId, action, players);
    const next = clone(state);
    const side = players.findIndex((player) => player.id === actorId);
    if (next.phase === 'placing') {
      const cells = action.cells as number[][];
      const board = (next.boards as number[][][])[side];
      const fleet = (next.fleets as number[][][][])[side];
      const id = fleet.length + 1;
      for (const [row, column] of cells) board[row][column] = id;
      fleet.push(cells);
      if ((next.fleets as unknown[][][]).every((ships) => ships.length === 5)) {
        next.phase = 'battle';
        next.turnPlayerId = players[0].id;
      }
      return next;
    }
    const opponent = 1 - side;
    const row = action.row as number;
    const column = action.column as number;
    const shots = (next.shots as number[][][])[side];
    const target = (next.boards as number[][][])[opponent][row][column];
    shots[row][column] = target > 0 ? 1 : 0;
    if (target > 0) (next.boards as number[][][])[opponent][row][column] = -target;
    const remaining = (next.boards as number[][][])[opponent].flat().some((cell) => cell > 0);
    if (!remaining) {
      next.finished = true;
      next.winnerId = actorId;
    } else {
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: GameState, players: GamePlayer[]): GameOutcome {
    const winner = typeof state.winnerId === 'string' ? state.winnerId : '';
    return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((player) => player.id !== winner).map((player) => player.id) : [], draw: false };
  }

  botAction(state: GameState, botId: string, players: GamePlayer[]): Action {
    const side = players.findIndex((player) => player.id === botId);
    if (state.phase === 'placing') {
      const sizes = [5, 4, 3, 3, 2];
      const ship = (state.fleets as unknown[][][])[side].length;
      const row = ship * 2;
      const size = sizes[ship];
      return { type: 'place', cells: Array.from({ length: size }, (_, index) => [row, index]) };
    }
    const shots = (state.shots as number[][][])[side];
    const candidates: Array<[number, number]> = [];
    const hits: Array<[number, number]> = [];
    for (let row = 0; row < 10; row += 1) for (let column = 0; column < 10; column += 1) {
      if (shots[row][column] === -1) candidates.push([row, column]);
      if (shots[row][column] === 1) {
        for (const [dr, dc] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nextRow = row + dr; const nextColumn = column + dc;
          if (nextRow >= 0 && nextRow < 10 && nextColumn >= 0 && nextColumn < 10 && shots[nextRow][nextColumn] === -1) hits.push([nextRow, nextColumn]);
        }
      }
    }
    const pool = hits.length ? hits : candidates;
    const [row, column] = pool[randomInt(pool.length)] ?? [0, 0];
    return { type: 'fire', row, column };
  }
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
  lastShot: { actorId: string; pocketed: number[]; scratch: boolean; legalEight: boolean; aim: number | null } | null;
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
    if (action.aim !== undefined) asInt(action.aim, 'aim', 0, 360);
    if (action.scratch !== undefined && typeof action.scratch !== 'boolean') throw new IllegalMoveError('scratch must be true or false.');
    const balls = this.pocketedBalls(action);
    if (balls.includes(8) && balls.length !== 1) throw new IllegalMoveError('The eight ball must be pocketed alone.');
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
    const aim = typeof action.aim === 'number' ? action.aim : null;
    next.lastShot = { actorId, pocketed: balls, scratch, legalEight, aim };

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
        next.phase = 'assigned';
      }
      if (!balls.length || scratch) rotateTurn(next, players);
      return next;
    }

    if (next.groups[side] === null && balls.length) {
      next.groups[side] = this.groupFor(balls[0]);
      next.groups[1 - side] = next.groups[side] === 'solids' ? 'stripes' : 'solids';
      next.phase = 'assigned';
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
    const pocket = randomInt(6);
    const power = 55 + randomInt(36);
    // Bots miss sometimes: a perfect bot would run every rack unopposed.
    const aim = randomInt(361);
    if (state.phase === 'break') return { type: 'shot', power, aim, pocket, pocketed: available.length && Math.random() < 0.6 ? [available[0]] : [] };
    if (this.canShootEight(state, side)) return { type: 'shot', power, aim, pocket, pocketed: [8] };
    const group = state.groups[side];
    const target = group === null ? available[0] : available.find((ball) => this.groupFor(ball) === group);
    const pocketed = target === undefined || Math.random() < 0.25 ? [] : [target];
    return { type: 'shot', power, aim, pocket, pocketed };
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

type CarromColor = 'white' | 'black';
interface CarromState extends GameState {
  remainingCoins: number[];
  groups: Array<CarromColor | null>;
  pocketed: number[][];
  queenRemaining: boolean;
  queenPendingFor: number | null;
  queenCoveredBy: number | null;
  scores: number[];
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  winnerIds: string[];
  lastShot: { actorId: string; pocketed: number[]; queen: boolean; foul: boolean } | null;
  draw?: boolean;
}

export class CarromEngine implements GameEngine {
  readonly id: GameId = 'carrom';

  create(players: GamePlayer[]): CarromState {
    if (players.length < 2 || players.length > 4) throw new IllegalMoveError('Carrom supports two to four players.');
    return {
      remainingCoins: Array.from({ length: 18 }, (_, index) => index + 1),
      groups: players.map(() => null),
      pocketed: players.map(() => []),
      queenRemaining: true,
      queenPendingFor: null,
      queenCoveredBy: null,
      scores: players.map(() => 0),
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
      winnerIds: [],
      lastShot: null,
    };
  }

  validate(state: CarromState, actorId: string, action: Action, players: GamePlayer[]): void {
    ensureTurn(state, actorId);
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    if (action.type !== 'strike') throw new IllegalMoveError('Use the strike action.');
    asInt(action.power, 'power', 1, 100);
    if (action.queen !== undefined && typeof action.queen !== 'boolean') throw new IllegalMoveError('queen must be true or false.');
    if (action.foul !== undefined && typeof action.foul !== 'boolean') throw new IllegalMoveError('foul must be true or false.');
    const pocketed = this.pocketedCoins(action);
    if (pocketed.length > 3) throw new IllegalMoveError('A strike may pocket at most three coins.');
    if (action.foul === true && (pocketed.length > 0 || action.queen === true)) throw new IllegalMoveError('A foul strike cannot also pocket a coin or call the queen.');
    for (const coin of pocketed) if (!state.remainingCoins.includes(coin)) throw new IllegalMoveError('That coin is no longer on the board.');
    if (action.queen === true && !state.queenRemaining) throw new IllegalMoveError('The queen is not on the board.');
    const group = this.groupForSide(state, side);
    if (group === null && pocketed.length > 1 && pocketed.some((coin) => this.coinColor(coin) !== this.coinColor(pocketed[0]))) throw new IllegalMoveError('An open strike must use one coin color.');
    if (group && pocketed.some((coin) => this.coinColor(coin) !== group)) throw new IllegalMoveError('Pocket only coins from your assigned color.');
    const finalColorCoin = group && pocketed.length > 0 && !state.remainingCoins.some((coin) => this.coinColor(coin) === group && !pocketed.includes(coin));
    if (group && state.queenRemaining && finalColorCoin && action.queen !== true) throw new IllegalMoveError('Pocket your final color coin with the queen to cover it.');
    if (action.queen === true && group && !pocketed.some((coin) => this.coinColor(coin) === group) && !state.remainingCoins.some((coin) => this.coinColor(coin) === group)) throw new IllegalMoveError('Pocket your final color coin with the queen to cover it.');
  }

  apply(state: CarromState, actorId: string, action: Action, players: GamePlayer[]): CarromState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as CarromState;
    const side = players.findIndex((player) => player.id === actorId);
    const pocketed = this.pocketedCoins(action);
    const queenShot = action.queen === true;
    const foul = action.foul === true;
    if (foul) {
      const returned = next.pocketed[side].pop();
      if (returned !== undefined) {
        next.remainingCoins.push(returned);
        next.scores[side] = Math.max(0, next.scores[side] - 1);
      }
      if (next.queenPendingFor === side) {
        next.queenRemaining = true;
        next.queenPendingFor = null;
        next.queenCoveredBy = null;
      }
      next.lastShot = { actorId, pocketed: [], queen: false, foul: true };
      rotateTurn(next, players);
      return next;
    }
    const groupBefore = this.groupForSide(next, side);
    for (const coin of pocketed) {
      next.remainingCoins = next.remainingCoins.filter((value) => value !== coin);
      next.pocketed[side].push(coin);
    }
    if (!groupBefore && pocketed.length) this.assignGroup(next, side, this.coinColor(pocketed[0]), players);
    const group = this.groupForSide(next, side);
    next.scores[side] += pocketed.filter((coin) => !group || this.coinColor(coin) === group).length;

    let keepsTurn = pocketed.length > 0;
    if (next.queenPendingFor !== null && next.queenPendingFor === side) {
      const covered = Boolean(group) && pocketed.some((coin) => this.coinColor(coin) === group);
      if (covered) {
        next.queenPendingFor = null;
        next.queenCoveredBy = side;
        next.scores[side] += 3;
        keepsTurn = true;
      } else {
        next.queenRemaining = true;
        next.queenPendingFor = null;
        next.queenCoveredBy = null;
        keepsTurn = false;
      }
    }
    if (queenShot) {
      next.queenRemaining = false;
      next.queenPendingFor = side;
      next.queenCoveredBy = null;
      keepsTurn = true;
      if (group && pocketed.some((coin) => this.coinColor(coin) === group)) {
        next.queenPendingFor = null;
        next.queenCoveredBy = side;
        next.scores[side] += 3;
      }
    }
    next.lastShot = { actorId, pocketed, queen: queenShot, foul: false };
    const winner = this.findWinner(next, players);
    if (winner.length) {
      next.finished = true;
      next.winnerIds = winner;
      next.winnerId = winner[0] ?? null;
      next.draw = winner.length > 1;
    } else if (keepsTurn) {
      next.turnPlayerId = players[side].id;
      next.turnIndex = side;
    } else {
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: CarromState, players: GamePlayer[]): GameOutcome {
    return { finished: Boolean(state.finished), winnerIds: state.winnerIds, loserIds: state.winnerIds.length ? players.filter((player) => !state.winnerIds.includes(player.id)).map((player) => player.id) : [], draw: Boolean(state.draw) };
  }

  botAction(state: CarromState, botId: string, players: GamePlayer[]): Action {
    const side = players.findIndex((player) => player.id === botId);
    const group = this.groupForSide(state, side);
    const own = state.remainingCoins.filter((coin) => !group || this.coinColor(coin) === group);
    if (state.queenPendingFor === side && own.length) return { type: 'strike', power: 65, pocketed: [own[0]], queen: false };
    // Bots miss sometimes: a perfect bot would keep the turn forever.
    if (Math.random() < 0.25) return { type: 'strike', power: 50, pocketed: [], queen: false };
    if (state.queenRemaining && own.length === 1) return { type: 'strike', power: 65, pocketed: [own[0]], queen: true };
    if (own.length) return { type: 'strike', power: 65, pocketed: [own[0]], queen: false };
    if (state.queenRemaining && state.remainingCoins.length === 0 && !group) return { type: 'strike', power: 65, pocketed: [], queen: true };
    return { type: 'strike', power: 50, pocketed: [], queen: false };
  }

  private pocketedCoins(action: Action): number[] {
    const raw = action.pocketed ?? [];
    if (!Array.isArray(raw)) throw new IllegalMoveError('pocketed must be an array of coin numbers.');
    const coins = raw.map((value) => asInt(value, 'coin', 1, 18));
    if (new Set(coins).size !== coins.length) throw new IllegalMoveError('A coin may only be pocketed once per strike.');
    return coins;
  }

  private coinColor(coin: number): CarromColor { return coin <= 9 ? 'white' : 'black'; }

  private groupForSide(state: CarromState, side: number): CarromColor | null { return state.groups[side] ?? null; }

  private assignGroup(state: CarromState, side: number, group: CarromColor, players: GamePlayer[]): void {
    const opposite = group === 'white' ? 'black' : 'white';
    const team = players[side].team;
    for (let index = 0; index < players.length; index += 1) {
      if (index === side || players.length === 4 && team !== undefined && players[index].team === team) state.groups[index] = group;
      else if (state.groups[index] === null) state.groups[index] = opposite;
    }
  }

  private findWinner(state: CarromState, players: GamePlayer[]): string[] {
    if (state.queenRemaining || state.queenPendingFor !== null) return [];
    if (state.remainingCoins.length) {
      const sides = players.map((_, index) => index).filter((index) => {
        const group = this.groupForSide(state, index);
        return group !== null && !state.remainingCoins.some((coin) => this.coinColor(coin) === group);
      });
      if (!sides.length) return [];
      const best = Math.max(...sides.map((side) => state.scores[side]));
      const winningSides = sides.filter((side) => state.scores[side] === best);
      return this.expandWinners(winningSides, players);
    }
    const best = Math.max(...state.scores);
    return this.expandWinners(state.scores.map((score, index) => score === best ? index : -1).filter((index) => index >= 0), players);
  }

  private expandWinners(sides: number[], players: GamePlayer[]): string[] {
    const winners = new Set<string>();
    for (const side of sides) {
      const team = players[side].team;
      for (let index = 0; index < players.length; index += 1) if (index === side || players.length === 4 && team !== undefined && players[index].team === team) winners.add(players[index].id);
    }
    return [...winners];
  }
}
