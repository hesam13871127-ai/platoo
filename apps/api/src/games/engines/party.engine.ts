import { Action, asInt, asString, GameEngine, GameId, GameOutcome, GamePlayer, GameState, IllegalMoveError, clone, randomInt, rotateTurn } from '../game.types';

const checkTurn = (state: GameState, actorId: string) => { if (state.finished) throw new IllegalMoveError('This game has finished.'); if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.'); };

interface DicePartyState extends GameState {
  round: number;
  maxRounds: number;
  scores: number[];
  rolls: (number | null)[];
  lastRoll: { playerId: string; round: number; value: number } | null;
  history: Array<{ playerId: string; round: number; value: number }>;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  draw?: boolean;
}

export class DicePartyEngine implements GameEngine {
  readonly id: GameId = 'dice_party';

  create(players: GamePlayer[]): DicePartyState {
    if (players.length < 2 || players.length > 6) throw new IllegalMoveError('Dice Party supports two to six players.');
    return {
      round: 1,
      maxRounds: 5,
      scores: players.map(() => 0),
      rolls: players.map(() => null),
      lastRoll: null,
      history: [],
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
    };
  }

  validate(state: DicePartyState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    checkTurn(state, actorId);
    if (action.type !== 'roll') throw new IllegalMoveError('Use roll.');
    if (state.rolls[side] !== null) throw new IllegalMoveError('You already rolled this round.');
  }

  apply(state: DicePartyState, actorId: string, action: Action, players: GamePlayer[]): DicePartyState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as DicePartyState;
    const side = players.findIndex((player) => player.id === actorId);
    const value = randomInt(6) + 1;
    next.rolls[side] = value;
    next.scores[side] += value;
    next.lastRoll = { playerId: actorId, round: next.round, value };
    next.history.push({ playerId: actorId, round: next.round, value });
    if (next.rolls.every((roll) => roll !== null)) {
      if (Number(next.round) >= Number(next.maxRounds)) {
        next.finished = true;
        const max = Math.max(...next.scores);
        next.winnerId = players[next.scores.indexOf(max)].id;
        next.draw = next.scores.filter((score) => score === max).length > 1;
      } else {
        next.round = Number(next.round) + 1;
        next.rolls = players.map(() => null);
        next.turnIndex = 0;
        next.turnPlayerId = players[0].id;
      }
    } else rotateTurn(next, players);
    return next;
  }

  outcome(state: DicePartyState, players: GamePlayer[]): GameOutcome {
    const winner = typeof state.winnerId === 'string' ? state.winnerId : '';
    return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) };
  }

  botAction(): Action { return { type: 'roll' }; }
}

interface BingoCard { values: number[]; marked: boolean[]; }
interface BingoState extends GameState {
  cards: BingoCard[];
  called: number[];
  bag: number[];
  lastNumber: number | null;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  winnerIds: string[];
  draw?: boolean;
}

export class BingoEngine implements GameEngine {
  readonly id: GameId = 'bingo';

  create(players: GamePlayer[]): BingoState {
    if (players.length < 2 || players.length > 8) throw new IllegalMoveError('Bingo supports two to eight players.');
    return {
      cards: players.map(() => this.createCard()),
      called: [],
      bag: this.shuffle(Array.from({ length: 75 }, (_, index) => index + 1)),
      lastNumber: null,
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
      winnerIds: [],
    };
  }

  validate(state: BingoState, actorId: string, action: Action, players: GamePlayer[]): void {
    if (state.finished) throw new IllegalMoveError('This game has finished.');
    if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn to draw.');
    if (!players.some((player) => player.id === actorId)) throw new IllegalMoveError('You are not in this game.');
    if (action.type !== 'draw') throw new IllegalMoveError('Draw the next bingo number.');
    if (!state.bag.length) throw new IllegalMoveError('The bingo cage is empty.');
  }

  apply(state: BingoState, actorId: string, action: Action, players: GamePlayer[]): BingoState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as BingoState;
    const number = next.bag.shift() as number;
    next.called.push(number);
    next.lastNumber = number;
    for (const card of next.cards) {
      const position = card.values.indexOf(number);
      if (position >= 0) card.marked[position] = true;
    }
    const winnerIndexes = next.cards.map((card, index) => this.hasBingo(card.marked) ? index : -1).filter((index) => index >= 0);
    if (winnerIndexes.length) {
      next.finished = true;
      next.winnerIds = winnerIndexes.map((index) => players[index].id);
      next.winnerId = next.winnerIds[0] ?? null;
      next.draw = next.winnerIds.length > 1;
    } else if (!next.bag.length) {
      next.finished = true;
      next.draw = true;
    } else {
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: BingoState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) && state.winnerIds.length ? state.winnerIds : typeof state.winnerId === 'string' ? [state.winnerId] : [];
    return { finished: Boolean(state.finished), winnerIds: winners, loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [], draw: Boolean(state.draw) };
  }

  botAction(_state: BingoState, _botId: string, _players: GamePlayer[]): Action { return { type: 'draw' }; }

  private createCard(): BingoCard {
    const values: number[] = [];
    for (let column = 0; column < 5; column += 1) {
      const start = column * 15 + 1;
      const numbers = this.shuffle(Array.from({ length: 15 }, (_, index) => start + index)).slice(0, 5);
      for (let row = 0; row < 5; row += 1) values[row * 5 + column] = numbers[row];
    }
    values[12] = 0;
    const marked = Array(25).fill(false) as boolean[];
    marked[12] = true;
    return { values, marked };
  }

  private hasBingo(marked: boolean[]): boolean {
    return [0, 1, 2, 3, 4].some((row) => [0, 1, 2, 3, 4].every((column) => marked[row * 5 + column]))
      || [0, 1, 2, 3, 4].some((column) => [0, 1, 2, 3, 4].every((row) => marked[row * 5 + column]))
      || [0, 1, 2, 3, 4].every((index) => marked[index * 5 + index])
      || [0, 1, 2, 3, 4].every((index) => marked[index * 5 + (4 - index)]);
  }

  private shuffle<T>(values: T[]): T[] {
    for (let index = values.length - 1; index > 0; index -= 1) {
      const swap = randomInt(index + 1);
      [values[index], values[swap]] = [values[swap], values[index]];
    }
    return values;
  }
}

type WerewolfRole = 'werewolf' | 'seer' | 'doctor' | 'villager';
interface SeerResult { target: number; isWerewolf: boolean; }
interface WerewolfState extends GameState {
  roles: WerewolfRole[];
  alive: boolean[];
  phase: 'night' | 'day';
  nightTargets: Array<number | null>;
  nightActed: boolean[];
  votes: Array<number | null>;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerIds: string[];
  seerResults: Array<SeerResult | null>;
  nightNumber: number;
  lastEvent: string | null;
}

export class WerewolfEngine implements GameEngine {
  readonly id: GameId = 'werewolf';

  create(players: GamePlayer[]): WerewolfState {
    if (players.length < 5 || players.length > 12) throw new IllegalMoveError('Werewolf supports five to twelve players.');
    const roles: WerewolfRole[] = players.map(() => 'villager');
    const order = players.map((_, index) => index);
    for (let index = order.length - 1; index > 0; index -= 1) {
      const swap = randomInt(index + 1);
      [order[index], order[swap]] = [order[swap], order[index]];
    }
    let cursor = 0;
    const wolfCount = Math.max(1, Math.floor(players.length / 4));
    for (let index = 0; index < wolfCount; index += 1) roles[order[cursor++]] = 'werewolf';
    roles[order[cursor++]] = 'seer';
    if (players.length >= 7) roles[order[cursor++]] = 'doctor';
    return {
      roles,
      alive: players.map(() => true),
      phase: 'night',
      nightTargets: players.map(() => null),
      nightActed: players.map(() => false),
      votes: players.map(() => null),
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerIds: [],
      seerResults: players.map(() => null),
      nightNumber: 1,
      lastEvent: null,
    };
  }

  validate(state: WerewolfState, actorId: string, action: Action, players: GamePlayer[]): void {
    if (state.finished) throw new IllegalMoveError('This game has finished.');
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0 || !state.alive[side]) throw new IllegalMoveError('You are out of the game.');
    if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.');

    if (state.phase === 'night') {
      if (state.nightActed[side]) throw new IllegalMoveError('You already acted this night.');
      if (action.type !== 'night') throw new IllegalMoveError('Submit your night action.');
      const role = state.roles[side];
      if (role === 'villager') {
        if (action.target !== undefined && action.target !== null && action.target !== -1) throw new IllegalMoveError('Villagers do not choose a night target.');
        return;
      }
      const target = asInt(action.target, 'target', 0, players.length - 1);
      if (!state.alive[target]) throw new IllegalMoveError('Choose a living target.');
      if ((role === 'werewolf' || role === 'seer') && target === side) throw new IllegalMoveError('Choose another living player.');
      if (role === 'werewolf' && state.roles[target] === 'werewolf') throw new IllegalMoveError('Werewolves cannot target another werewolf.');
      return;
    }

    if (action.type !== 'vote') throw new IllegalMoveError('Vote during the day.');
    const target = asInt(action.target, 'target', 0, players.length - 1);
    if (!state.alive[target] || target === side) throw new IllegalMoveError('Vote for another living player.');
    if (state.votes[side] !== null) throw new IllegalMoveError('You already voted this day.');
  }

  apply(state: WerewolfState, actorId: string, action: Action, players: GamePlayer[]): WerewolfState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as WerewolfState;
    const side = players.findIndex((player) => player.id === actorId);
    if (next.phase === 'night') {
      next.nightActed[side] = true;
      next.nightTargets[side] = next.roles[side] === 'villager' ? null : action.target as number;
      const nextActor = this.firstUnactedNightPlayer(next);
      if (nextActor >= 0) this.setTurn(next, players, nextActor);
      else this.resolveNight(next, players);
    } else {
      next.votes[side] = action.target as number;
      const nextActor = players.findIndex((player, index) => next.alive[index] && next.votes[index] === null);
      if (nextActor >= 0) this.setTurn(next, players, nextActor);
      else this.resolveDay(next, players);
    }
    return next;
  }

  outcome(state: WerewolfState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) ? state.winnerIds : [];
    return {
      finished: Boolean(state.finished),
      winnerIds: winners,
      loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [],
      draw: false,
    };
  }

  botAction(state: WerewolfState, botId: string, players: GamePlayer[]): Action {
    const side = players.findIndex((player) => player.id === botId);
    if (state.phase === 'night') {
      const role = state.roles[side];
      if (role === 'villager') return { type: 'night' };
      const previous = role === 'seer' ? state.seerResults[side]?.target : undefined;
      const candidates = players
        .map((_, index) => index)
        .filter((index) => state.alive[index] && (role !== 'werewolf' || state.roles[index] !== 'werewolf') && (role !== 'seer' || index !== side) && index !== previous);
      const pool = candidates.length
        ? candidates
        : players.map((_, index) => index).filter((index) => state.alive[index] && index !== side && (role !== 'werewolf' || state.roles[index] !== 'werewolf'));
      return { type: 'night', target: pool[randomInt(pool.length)] ?? 0 };
    }
    if (state.roles[side] === 'seer') {
      const known = state.seerResults[side];
      if (known && known.isWerewolf && state.alive[known.target] && known.target !== side) return { type: 'vote', target: known.target };
    }
    const candidates = players.map((_, index) => index).filter((index) => state.alive[index] && index !== side);
    return { type: 'vote', target: candidates[randomInt(candidates.length)] ?? 0 };
  }

  private resolveNight(state: WerewolfState, players: GamePlayer[]): void {
    const wolfTargets = state.roles.map((role, index) => role === 'werewolf' && state.alive[index] ? state.nightTargets[index] : null).filter((target): target is number => target !== null);
    const killTarget = this.majority(wolfTargets);
    const doctor = state.roles.findIndex((role, index) => role === 'doctor' && state.alive[index]);
    const protectedTarget = doctor >= 0 ? state.nightTargets[doctor] : null;
    const seer = state.roles.findIndex((role, index) => role === 'seer' && state.alive[index]);
    if (seer >= 0 && state.nightTargets[seer] !== null) {
      const target = state.nightTargets[seer] as number;
      state.seerResults[seer] = { target, isWerewolf: state.roles[target] === 'werewolf' };
    }
    if (killTarget !== null && killTarget !== protectedTarget) {
      state.alive[killTarget] = false;
      state.lastEvent = 'A player was found at dawn.';
    } else if (killTarget !== null) {
      state.lastEvent = 'The werewolves attacked, but the doctor saved the target.';
    } else {
      state.lastEvent = 'The night ended without a majority wolf vote.';
    }
    if (this.finishIfWon(state, players)) return;
    state.phase = 'day';
    state.votes = players.map(() => null);
    const first = players.findIndex((_, index) => state.alive[index]);
    this.setTurn(state, players, first);
  }

  private resolveDay(state: WerewolfState, players: GamePlayer[]): void {
    const counts = players.map((_, target) => state.votes.filter((vote) => vote === target).length);
    const max = Math.max(...counts);
    const candidates = counts.map((count, index) => count === max && state.alive[index] ? index : -1).filter((index) => index >= 0);
    if (candidates.length === 1) {
      const eliminated = candidates[0];
      state.alive[eliminated] = false;
      state.lastEvent = 'A player was voted out.';
    } else {
      state.lastEvent = 'The vote was tied. Nobody was eliminated.';
    }
    if (this.finishIfWon(state, players)) return;
    state.phase = 'night';
    state.nightNumber = Number(state.nightNumber) + 1;
    state.nightTargets = players.map(() => null);
    state.nightActed = players.map(() => false);
    const first = players.findIndex((_, index) => state.alive[index]);
    this.setTurn(state, players, first);
  }

  private finishIfWon(state: WerewolfState, players: GamePlayer[]): boolean {
    const wolves = state.roles.filter((role, index) => role === 'werewolf' && state.alive[index]).length;
    const innocents = state.alive.filter((alive, index) => alive && state.roles[index] !== 'werewolf').length;
    if (wolves > 0 && wolves < innocents) return false;
    state.finished = true;
    const winningRole = wolves === 0 ? 'innocent' : 'werewolf';
    state.winnerIds = players.filter((_, index) => winningRole === 'werewolf' ? state.roles[index] === 'werewolf' : state.roles[index] !== 'werewolf').map((player) => player.id);
    state.lastEvent = wolves === 0 ? 'The village eliminated the last werewolf.' : 'The werewolves reached parity with the village.';
    return true;
  }

  private firstUnactedNightPlayer(state: WerewolfState): number {
    return state.alive.findIndex((alive, index) => alive && !state.nightActed[index]);
  }

  private majority(targets: number[]): number | null {
    if (!targets.length) return null;
    const counts = new Map<number, number>();
    for (const target of targets) counts.set(target, (counts.get(target) ?? 0) + 1);
    const max = Math.max(...counts.values());
    const leaders = [...counts.entries()].filter(([, count]) => count === max);
    return leaders.length === 1 ? leaders[0][0] : null;
  }

  private setTurn(state: WerewolfState, players: GamePlayer[], index: number): void {
    if (index < 0) return;
    state.turnIndex = index;
    state.turnPlayerId = players[index].id;
  }
}

export class WordChainEngine implements GameEngine {
  readonly id: GameId = 'word_chain';
  create(players: GamePlayer[]): GameState {
    if (players.length < 2 || players.length > 8) throw new IllegalMoveError('Word Chain supports two to eight players.');
    return { words: [], used: [], requiredLetter: null, scores: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null, draw: false, maxWords: players.length * 8 };
  }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { checkTurn(state, actorId); if (action.type !== 'word') throw new IllegalMoveError('Submit a word.'); const word = asString(action.word, 'word').toLowerCase(); if (!/^[a-zA-Z\u0600-\u06ff]{2,24}$/.test(word)) throw new IllegalMoveError('Use a word with two to twenty-four letters.'); if ((state.used as string[]).includes(word)) throw new IllegalMoveError('That word has already been used.'); if (state.requiredLetter && !word.startsWith(state.requiredLetter as string)) throw new IllegalMoveError(`Your word must start with ${state.requiredLetter}.`); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState {
    this.validate(state, actorId, action, players); const next = clone(state); const word = (action.word as string).toLowerCase();
    (next.words as string[]).push(word); (next.used as string[]).push(word);
    (next.scores as number[])[players.findIndex((p) => p.id === actorId)] += word.length;
    next.requiredLetter = word[word.length - 1];
    const maxWords = Number(next.maxWords ?? 24);
    if ((next.words as string[]).length >= maxWords) {
      const scores = next.scores as number[]; const best = Math.max(...scores);
      const leaders = scores.map((score, index) => score === best ? index : -1).filter((index) => index >= 0);
      next.finished = true; next.winnerId = players[leaders[0]].id; next.draw = leaders.length > 1;
      return next;
    }
    rotateTurn(next, players); return next;
  }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; }
  botAction(state: GameState): Action {
    const letter = ((state.requiredLetter as string | null) ?? 'v').toLowerCase();
    const used = state.used as string[];
    const englishTails = ['ibe', 'ora', 'ent', 'ash', 'oom', 'ell', 'art', 'ice', 'ace', 'end'];
    const persianTails = ['ار', 'ان', 'ور', 'وش', 'ام', 'ابه', 'اده', 'ابی', 'انه', 'او'];
    const tails = /[a-z]/i.test(letter) ? englishTails : persianTails;
    for (const tail of tails) {
      const word = `${letter}${tail}`;
      if (!used.includes(word)) return { type: 'word', word };
    }
    // Use a small alphabetic search as a last resort so a long match cannot
    // make the bot repeat a used word. The generated token still obeys the
    // engine's script and length rules in both English and Persian.
    const alphabet = /[a-z]/i.test(letter) ? 'abcdefghijklmnopqrstuvwxyz' : 'ابتثجچحخدذرزژسشصضطظعغفقکگلمنوهی';
    for (let length = 1; length <= 3; length += 1) {
      const combinations = alphabet.length ** length;
      for (let index = 0; index < combinations; index += 1) {
        let value = index;
        let suffix = '';
        for (let position = 0; position < length; position += 1) {
          suffix = alphabet[value % alphabet.length] + suffix;
          value = Math.floor(value / alphabet.length);
        }
        const word = `${letter}${suffix}`;
        if (!used.includes(word)) return { type: 'word', word };
      }
    }
    throw new IllegalMoveError('No unused word is available for this letter.');
  }
}

export class MemoryRaceEngine implements GameEngine {
  readonly id: GameId = 'memory_race';

  create(players: GamePlayer[]): GameState {
    if (players.length < 2 || players.length > 6) throw new IllegalMoveError('Memory Race supports two to six players.');
    const values = Array.from({ length: 12 }, (_, index) => index).flatMap((index) => [index, index]);
    for (let index = values.length - 1; index > 0; index -= 1) {
      const swap = randomInt(index + 1);
      [values[index], values[swap]] = [values[swap], values[index]];
    }
    return { values, revealed: Array(24).fill(false), matched: Array(24).fill(false), selections: [], scores: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null, winnerIds: [] };
  }

  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void {
    checkTurn(state, actorId);
    if (!players.some((player) => player.id === actorId)) throw new IllegalMoveError('You are not in this game.');
    if (action.type !== 'flip') throw new IllegalMoveError('Flip a card.');
    const index = asInt(action.index, 'index', 0, 23);
    if ((state.revealed as boolean[])[index] || (state.matched as boolean[])[index]) throw new IllegalMoveError('That card is not available.');
    if ((state.selections as number[]).length >= 2) throw new IllegalMoveError('Finish the current pair first.');
  }

  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState {
    this.validate(state, actorId, action, players);
    const next = clone(state);
    const index = action.index as number;
    (next.revealed as boolean[])[index] = true;
    (next.selections as number[]).push(index);
    if ((next.selections as number[]).length !== 2) return next;

    const selections = next.selections as number[];
    if ((next.values as number[])[selections[0]] === (next.values as number[])[selections[1]]) {
      (next.matched as boolean[])[selections[0]] = true;
      (next.matched as boolean[])[selections[1]] = true;
      (next.scores as number[])[players.findIndex((player) => player.id === actorId)] += 1;
    } else {
      (next.revealed as boolean[])[selections[0]] = false;
      (next.revealed as boolean[])[selections[1]] = false;
      rotateTurn(next, players);
    }
    next.selections = [];
    if ((next.matched as boolean[]).every(Boolean)) {
      const scores = next.scores as number[];
      const best = Math.max(...scores);
      const winners = scores.map((score, seat) => score === best ? players[seat].id : null).filter((id): id is string => id !== null);
      next.finished = true;
      next.winnerIds = winners;
      next.winnerId = winners[0] ?? null;
      next.draw = winners.length > 1;
    }
    return next;
  }

  outcome(state: GameState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) && (state.winnerIds as string[]).length
      ? state.winnerIds as string[]
      : typeof state.winnerId === 'string' ? [state.winnerId] : [];
    return { finished: Boolean(state.finished), winnerIds: winners, loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [], draw: Boolean(state.draw) };
  }

  botAction(state: GameState, _botId: string): Action {
    const values = state.values as number[];
    const revealed = state.revealed as boolean[];
    const matched = state.matched as boolean[];
    const selections = state.selections as number[];
    const available = matched.map((done, index) => !done && !revealed[index] ? index : -1).filter((index) => index >= 0);
    if (selections.length === 1 && Math.random() < 0.82) {
      const partner = available.find((index) => values[index] === values[selections[0]]);
      if (partner !== undefined) return { type: 'flip', index: partner };
    }
    return { type: 'flip', index: available[randomInt(available.length)] ?? 0 };
  }
}

const IMPOSTOR_WORDS = [
  'pizza', 'rocket', 'castle', 'dragon', 'guitar', 'beach', 'forest', 'robot',
  'pirate', 'circus', 'volcano', 'submarine', 'bakery', 'library', 'stadium',
  'desert', 'island', 'garden', 'museum', 'carnival', 'lighthouse', 'waterfall',
  'spaceship', 'treehouse', 'market', 'harbor', 'meadow', 'village', 'windmill', 'aquarium',
];

const IMPOSTOR_BLUFFS = [
  'tricky one', 'I know this', 'classic', 'easy for me',
  'good luck everyone', 'hmm, interesting', 'no doubt about it', 'love this game',
];

interface ImpostorLightState extends GameState {
  impostor: number;
  word: string;
  clues: (string | null)[];
  votes: (number | null)[];
  phase: 'clues' | 'vote';
  voteCount: number;
  impostorCaught: boolean | null;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
}

export class ImpostorLightEngine implements GameEngine {
  readonly id: GameId = 'impostor_light';

  create(players: GamePlayer[]): ImpostorLightState {
    if (players.length < 4 || players.length > 10) throw new IllegalMoveError('Impostor Light supports four to ten players.');
    return {
      impostor: randomInt(players.length),
      word: IMPOSTOR_WORDS[randomInt(IMPOSTOR_WORDS.length)],
      clues: players.map(() => null),
      votes: players.map(() => null),
      phase: 'clues',
      voteCount: 0,
      impostorCaught: null,
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
    };
  }

  validate(state: ImpostorLightState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    checkTurn(state, actorId);
    if (state.phase === 'clues') {
      if (action.type !== 'clue') throw new IllegalMoveError('Give a clue.');
      asString(action.clue, 'clue');
      if ((action.clue as string).trim().length > 100) throw new IllegalMoveError('Keep your clue under 100 characters.');
    } else {
      if (action.type !== 'vote') throw new IllegalMoveError('Vote for the impostor.');
      const target = asInt(action.target, 'target', 0, players.length - 1);
      if (target === side) throw new IllegalMoveError('You cannot vote for yourself.');
    }
  }

  apply(state: ImpostorLightState, actorId: string, action: Action, players: GamePlayer[]): ImpostorLightState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as ImpostorLightState;
    const side = players.findIndex((player) => player.id === actorId);
    if (next.phase === 'clues') {
      next.clues[side] = (action.clue as string).trim().slice(0, 100);
      if (next.clues.every(Boolean)) {
        next.phase = 'vote';
        next.votes = players.map(() => null);
        next.voteCount = 0;
        next.turnIndex = 0;
        next.turnPlayerId = players[0].id;
      } else rotateTurn(next, players);
      return next;
    }
    next.votes[side] = action.target as number;
    next.voteCount = next.votes.filter((vote) => vote !== null).length;
    if (next.votes.every((vote) => vote !== null)) {
      const counts = players.map((_, seat) => (next.votes as number[]).filter((vote) => vote === seat).length);
      const top = Math.max(...counts);
      const leaders = counts.map((count, seat) => (count === top ? seat : -1)).filter((seat) => seat >= 0);
      // A tied vote lets the impostor slip away: no elimination without a plurality.
      const caught = leaders.length === 1 && leaders[0] === Number(next.impostor);
      next.impostorCaught = caught;
      next.finished = true;
      next.winnerId = caught
        ? players.find((player, seat) => seat !== Number(next.impostor))?.id ?? null
        : players[Number(next.impostor)].id;
    } else rotateTurn(next, players);
    return next;
  }

  outcome(state: ImpostorLightState, players: GamePlayer[]): GameOutcome {
    if (!state.finished) return { finished: false, winnerIds: [], loserIds: [], draw: false };
    const impostorId = players[Number(state.impostor)]?.id;
    const winners = state.impostorCaught
      ? players.filter((player) => player.id !== impostorId).map((player) => player.id)
      : impostorId ? [impostorId] : [];
    return { finished: true, winnerIds: winners, loserIds: players.filter((player) => !winners.includes(player.id)).map((player) => player.id), draw: false };
  }

  botAction(state: ImpostorLightState, botId: string, players: GamePlayer[]): Action {
    const side = players.findIndex((player) => player.id === botId);
    if (state.phase === 'clues') {
      const isImpostor = Number(state.impostor) === side;
      const word = String(state.word ?? 'mystery');
      if (!isImpostor && randomInt(100) >= 25) {
        const hints = [`starts with "${word[0].toUpperCase()}"`, `${word.length} letters`, `ends with "${word.slice(-1)}"`];
        return { type: 'clue', clue: hints[randomInt(hints.length)] };
      }
      return { type: 'clue', clue: IMPOSTOR_BLUFFS[randomInt(IMPOSTOR_BLUFFS.length)] };
    }
    let target = randomInt(players.length);
    while (target === side) target = randomInt(players.length);
    return { type: 'vote', target };
  }
}

interface EmojiEntry {
  word: string;
  clues: string[];
  distractors: string[];
}

// Every entry: the secret word, three emoji the presenter can post, and three
// wrong options for the multiple-choice guess. Options always hold 4 words.
const EMOJI_BANK: EmojiEntry[] = [
  { word: 'pizza', clues: ['🍕', '🧀🍅', '🇮🇹'], distractors: ['burger', 'sushi', 'taco'] },
  { word: 'rocket', clues: ['🚀', '🌙🚀', '🔥🚀'], distractors: ['airplane', 'submarine', 'bicycle'] },
  { word: 'cat', clues: ['🐱', '🐈‍⬛', '🥛🐱'], distractors: ['dog', 'rabbit', 'hamster'] },
  { word: 'birthday', clues: ['🎂', '🎉🎁', '🕯️'], distractors: ['wedding', 'holiday', 'meeting'] },
  { word: 'ocean', clues: ['🌊', '🏖️', '🐠'], distractors: ['desert', 'forest', 'mountain'] },
  { word: 'soccer', clues: ['⚽', '🥅', '🏟️'], distractors: ['tennis', 'boxing', 'golf'] },
  { word: 'music', clues: ['🎵', '🎸', '🎧'], distractors: ['movie', 'book', 'painting'] },
  { word: 'airplane', clues: ['✈️', '🛫', '☁️✈️'], distractors: ['train', 'ship', 'bus'] },
  { word: 'coffee', clues: ['☕', '🫘', '🌅☕'], distractors: ['tea', 'juice', 'milk'] },
  { word: 'dragon', clues: ['🐉', '🔥🐲', '🏰'], distractors: ['unicorn', 'dinosaur', 'monster'] },
  { word: 'snowman', clues: ['☃️', '❄️⛄', '🧣'], distractors: ['scarecrow', 'robot', 'ghost'] },
  { word: 'treasure', clues: ['💰', '🗺️💎', '🏴‍☠️'], distractors: ['garbage', 'homework', 'laundry'] },
  { word: 'camera', clues: ['📷', '🤳', '📸'], distractors: ['mirror', 'lamp', 'clock'] },
  { word: 'rainbow', clues: ['🌈', '🌦️', '🦄'], distractors: ['storm', 'eclipse', 'fog'] },
  { word: 'robot', clues: ['🤖', '⚙️', '🔋'], distractors: ['alien', 'zombie', 'vampire'] },
  { word: 'popcorn', clues: ['🍿', '🎬', '🎪'], distractors: ['chips', 'candy', 'nachos'] },
  { word: 'castle', clues: ['🏰', '👑', '🐉🏰'], distractors: ['tent', 'igloo', 'cabin'] },
  { word: 'bicycle', clues: ['🚲', '🚴', '⛰️🚲'], distractors: ['motorcycle', 'skateboard', 'scooter'] },
  { word: 'ghost', clues: ['👻', '🎃', '🌙'], distractors: ['witch', 'mummy', 'skeleton'] },
  { word: 'sun', clues: ['☀️', '🌞', '🕶️'], distractors: ['moon', 'star', 'cloud'] },
  { word: 'dog', clues: ['🐶', '🦴', '🐕‍🦺'], distractors: ['cat', 'fox', 'wolf'] },
  { word: 'book', clues: ['📚', '📖', '🤓'], distractors: ['newspaper', 'magazine', 'letter'] },
  { word: 'phone', clues: ['📱', '🤳', '💬'], distractors: ['laptop', 'tablet', 'radio'] },
  { word: 'beach', clues: ['🏖️', '🦀', '🍹'], distractors: ['pool', 'lake', 'river'] },
];

const pickEmojiEntry = (used: string[]): EmojiEntry => {
  const fresh = EMOJI_BANK.filter((entry) => !used.includes(entry.word));
  const pool = fresh.length ? fresh : EMOJI_BANK;
  return pool[randomInt(pool.length)];
};

const shuffledOptions = (items: string[]): string[] => {
  const copy = [...items];
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const swap = randomInt(index + 1);
    [copy[index], copy[swap]] = [copy[swap], copy[index]];
  }
  return copy;
};

interface EmojiCharadesState extends GameState {
  round: number;
  rounds: number;
  presenterIndex: number;
  phase: 'clue' | 'guessing';
  prompt: string | null;
  clueOptions: string[];
  clue: string | null;
  options: string[];
  answer: number | null;
  guesses: (number | null)[];
  scores: number[];
  lastRound: { presenterId: string; word: string; clue: string; correctIds: string[] } | null;
  usedWords: string[];
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  draw?: boolean;
}

const dealEmojiRound = (used: string[]): { prompt: string; clueOptions: string[]; options: string[]; answer: number; usedWords: string[] } => {
  const entry = pickEmojiEntry(used);
  const options = shuffledOptions([entry.word, ...entry.distractors]);
  return { prompt: entry.word, clueOptions: [...entry.clues], options, answer: options.indexOf(entry.word), usedWords: [...used, entry.word] };
};

export class EmojiCharadesEngine implements GameEngine {
  readonly id: GameId = 'emoji_charades';

  create(players: GamePlayer[]): EmojiCharadesState {
    if (players.length < 3 || players.length > 8) throw new IllegalMoveError('Emoji Charades supports three to eight players.');
    const dealt = dealEmojiRound([]);
    return {
      round: 1,
      rounds: players.length,
      presenterIndex: 0,
      phase: 'clue',
      prompt: dealt.prompt,
      clueOptions: dealt.clueOptions,
      clue: null,
      options: dealt.options,
      answer: dealt.answer,
      guesses: players.map(() => null),
      scores: players.map(() => 0),
      lastRound: null,
      usedWords: dealt.usedWords,
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
    };
  }

  validate(state: EmojiCharadesState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    checkTurn(state, actorId);
    if (state.phase === 'clue') {
      if (action.type !== 'post_clue') throw new IllegalMoveError('Post an emoji clue.');
      const emoji = asString(action.emoji, 'emoji');
      if (!(state.clueOptions as string[]).includes(emoji)) throw new IllegalMoveError('Pick one of the suggested emoji.');
    } else {
      if (action.type !== 'guess') throw new IllegalMoveError('Guess the word.');
      if (side === Number(state.presenterIndex)) throw new IllegalMoveError('The presenter does not guess.');
      asInt(action.answer, 'answer', 0, 3);
      if (state.guesses[side] !== null) throw new IllegalMoveError('You already guessed this round.');
    }
  }

  apply(state: EmojiCharadesState, actorId: string, action: Action, players: GamePlayer[]): EmojiCharadesState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as EmojiCharadesState;
    const side = players.findIndex((player) => player.id === actorId);
    const presenter = Number(next.presenterIndex);
    if (next.phase === 'clue') {
      next.clue = action.emoji as string;
      next.phase = 'guessing';
      const firstGuesser = (presenter + 1) % players.length;
      next.turnIndex = firstGuesser;
      next.turnPlayerId = players[firstGuesser].id;
      return next;
    }
    next.guesses[side] = action.answer as number;
    if ((action.answer as number) === Number(next.answer)) {
      next.scores[side] += 100;
      next.scores[presenter] += 50;
    }
    const pending = players.findIndex((_, seat) => seat !== presenter && next.guesses[seat] === null);
    if (pending === -1) {
      next.lastRound = {
        presenterId: players[presenter].id,
        word: String(next.prompt),
        clue: String(next.clue),
        correctIds: players.filter((_, seat) => next.guesses[seat] === Number(next.answer)).map((player) => player.id),
      };
      if (Number(next.round) >= Number(next.rounds)) {
        next.finished = true;
        const max = Math.max(...next.scores);
        next.winnerId = players[next.scores.indexOf(max)].id;
        next.draw = next.scores.filter((score) => score === max).length > 1;
      } else {
        const dealt = dealEmojiRound(next.usedWords);
        next.round = Number(next.round) + 1;
        next.presenterIndex = (presenter + 1) % players.length;
        next.phase = 'clue';
        next.prompt = dealt.prompt;
        next.clueOptions = dealt.clueOptions;
        next.clue = null;
        next.options = dealt.options;
        next.answer = dealt.answer;
        next.guesses = players.map(() => null);
        next.usedWords = dealt.usedWords;
        next.turnIndex = Number(next.presenterIndex);
        next.turnPlayerId = players[Number(next.presenterIndex)].id;
      }
      return next;
    }
    let turn = (Number(next.turnIndex) + 1) % players.length;
    if (turn === presenter) turn = (turn + 1) % players.length;
    next.turnIndex = turn;
    next.turnPlayerId = players[turn].id;
    return next;
  }

  outcome(state: EmojiCharadesState, players: GamePlayer[]): GameOutcome {
    const winner = typeof state.winnerId === 'string' ? state.winnerId : '';
    return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) };
  }

  botAction(state: EmojiCharadesState, _botId: string): Action {
    if (state.phase === 'clue') {
      const options = state.clueOptions as string[];
      return { type: 'post_clue', emoji: options[randomInt(options.length)] ?? '🎲' };
    }
    // Bots read emoji about as well as a casual player: usually right, sometimes fooled.
    const answer = Number(state.answer);
    return { type: 'guess', answer: randomInt(100) < 55 ? answer : randomInt(4) };
  }
}
interface SketchGuessState extends GameState {
  round: number;
  rounds: number;
  drawerIndex: number;
  prompt: string;
  phase: 'drawing' | 'guessing';
  drawing: number[][][];
  guesses: Array<string | null>;
  scores: number[];
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  winnerIds: string[];
  lastGuess: { playerId: string; guess: string; correct: boolean } | null;
  lastEvent: string | null;
  draw?: boolean;
}

const SKETCH_PROMPTS = [
  'sunset', 'bicycle', 'pizza', 'rocket', 'castle', 'rainbow', 'cat', 'mountain',
  'robot', 'ice cream', 'lighthouse', 'treehouse', 'camera', 'dragon', 'popcorn',
  'hot air balloon', 'snowman', 'treasure chest', 'sunglasses', 'campfire',
];

const normalizeGuess = (value: string): string => value.toLowerCase().trim().replace(/[^a-z0-9]+/g, '');

export class SketchGuessEngine implements GameEngine {
  readonly id: GameId = 'sketch_guess';

  create(players: GamePlayer[]): SketchGuessState {
    if (players.length < 3 || players.length > 8) throw new IllegalMoveError('Sketch & Guess supports three to eight players.');
    return {
      round: 1,
      rounds: players.length,
      drawerIndex: 0,
      prompt: SKETCH_PROMPTS[randomInt(SKETCH_PROMPTS.length)],
      phase: 'drawing',
      drawing: [],
      guesses: players.map(() => null),
      scores: players.map(() => 0),
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
      winnerIds: [],
      lastGuess: null,
      lastEvent: null,
    };
  }

  validate(state: SketchGuessState, actorId: string, action: Action, players: GamePlayer[]): void {
    if (state.finished) throw new IllegalMoveError('This game has finished.');
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    if (state.phase === 'drawing') {
      if (side !== state.drawerIndex || state.turnPlayerId !== actorId) throw new IllegalMoveError('Only the active drawer can submit the sketch.');
      if (action.type !== 'draw') throw new IllegalMoveError('Submit the sketch before guessing begins.');
      this.strokes(action.strokes);
      return;
    }
    if (state.turnPlayerId !== actorId) throw new IllegalMoveError('Wait for your guessing turn.');
    if (action.type !== 'guess') throw new IllegalMoveError('Submit a guess.');
    if (side === state.drawerIndex) throw new IllegalMoveError('The drawer cannot guess their own prompt.');
    if (state.guesses[side] !== null) throw new IllegalMoveError('You already guessed this drawing.');
    const guess = asString(action.guess, 'guess').trim();
    if (!guess) throw new IllegalMoveError('Guess must contain a word.');
    if (guess.length > 40) throw new IllegalMoveError('Keep guesses under forty characters.');
  }

  apply(state: SketchGuessState, actorId: string, action: Action, players: GamePlayer[]): SketchGuessState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as SketchGuessState;
    const side = players.findIndex((player) => player.id === actorId);
    if (next.phase === 'drawing') {
      next.drawing = this.strokes(action.strokes);
      next.phase = 'guessing';
      next.guesses = players.map(() => null);
      next.turnIndex = (next.drawerIndex + 1) % players.length;
      next.turnPlayerId = players[next.turnIndex].id;
      next.lastEvent = `${players[next.drawerIndex].id} submitted a sketch.`;
      return next;
    }

    const guess = (action.guess as string).trim();
    const correct = normalizeGuess(guess) === normalizeGuess(next.prompt);
    next.guesses[side] = guess;
    next.lastGuess = { playerId: actorId, guess, correct };
    if (correct) {
      next.scores[side] += 3;
      next.scores[next.drawerIndex] += 2;
      next.lastEvent = `${actorId} guessed the drawing.`;
      this.advanceRound(next, players);
      return next;
    }

    next.lastEvent = `${actorId} made a guess.`;
    const allGuessersActed = players.every((_, index) => index === next.drawerIndex || next.guesses[index] !== null);
    if (allGuessersActed) this.advanceRound(next, players);
    else this.nextGuesser(next, players);
    return next;
  }

  outcome(state: SketchGuessState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) && state.winnerIds.length ? state.winnerIds : state.winnerId ? [state.winnerId] : [];
    return { finished: Boolean(state.finished), winnerIds: winners, loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [], draw: Boolean(state.draw) };
  }

  botAction(state: SketchGuessState, botId: string): Action {
    if (state.phase === 'drawing') {
      return { type: 'draw', strokes: [[[100, 100], [900, 100], [900, 900], [100, 900], [100, 100]], [[250, 500], [750, 500]]] };
    }
    // The first guesser usually recognizes the simple sketch; later players
    // may be misled by it instead of every bot submitting the hidden prompt
    // verbatim. Keeping one informed guess per round also gives the drawer a
    // fair score and prevents a fully automated table from stalling.
    const submitted = state.guesses.filter((guess) => guess !== null).length;
    if (submitted === 0 || Math.random() < 0.65) return { type: 'guess', guess: state.prompt };
    const wrong = SKETCH_PROMPTS.find((prompt) => prompt !== state.prompt) ?? 'something else';
    return { type: 'guess', guess: wrong };
  }

  private nextGuesser(state: SketchGuessState, players: GamePlayer[]): void {
    for (let offset = 1; offset <= players.length; offset += 1) {
      const index = (state.turnIndex + offset) % players.length;
      if (index !== state.drawerIndex && state.guesses[index] === null) {
        state.turnIndex = index;
        state.turnPlayerId = players[index].id;
        return;
      }
    }
  }

  private advanceRound(state: SketchGuessState, players: GamePlayer[]): void {
    if (state.round >= state.rounds) {
      const maximum = Math.max(...state.scores);
      state.winnerIds = state.scores.map((score, index) => score === maximum ? players[index].id : null).filter((id): id is string => id !== null);
      state.winnerId = state.winnerIds[0] ?? null;
      state.draw = state.winnerIds.length > 1;
      state.finished = true;
      return;
    }
    state.round += 1;
    state.drawerIndex = (state.drawerIndex + 1) % players.length;
    state.prompt = SKETCH_PROMPTS[randomInt(SKETCH_PROMPTS.length)];
    state.phase = 'drawing';
    state.drawing = [];
    state.guesses = players.map(() => null);
    state.turnIndex = state.drawerIndex;
    state.turnPlayerId = players[state.drawerIndex].id;
  }

  private strokes(value: unknown): number[][][] {
    if (!Array.isArray(value) || value.length < 1 || value.length > 80) throw new IllegalMoveError('A sketch needs between one and eighty strokes.');
    return value.map((rawStroke) => {
      if (!Array.isArray(rawStroke) || rawStroke.length < 2 || rawStroke.length > 120) throw new IllegalMoveError('Each stroke needs between two and 120 points.');
      return rawStroke.map((rawPoint) => {
        if (!Array.isArray(rawPoint) || rawPoint.length !== 2 || typeof rawPoint[0] !== 'number' || typeof rawPoint[1] !== 'number' || !Number.isFinite(rawPoint[0]) || !Number.isFinite(rawPoint[1]) || rawPoint[0] < 0 || rawPoint[0] > 1000 || rawPoint[1] < 0 || rawPoint[1] > 1000) throw new IllegalMoveError('Sketch points must be between zero and one thousand.');
        return [rawPoint[0], rawPoint[1]];
      });
    });
  }
}

interface TriviaQuestion { prompt: string; options: string[]; answer: number; category: string; }
interface TriviaState extends GameState {
  questionBank: TriviaQuestion[];
  questionIndex: number;
  rounds: number;
  answered: boolean[];
  answers: Array<number | null>;
  scores: number[];
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  winnerIds: string[];
  lastAnswer: { correctAnswer: number; answers: Array<number | null> } | null;
  draw?: boolean;
}

const TRIVIA_QUESTIONS: TriviaQuestion[] = [
  { prompt: 'Which planet is known as the Red Planet?', options: ['Venus', 'Mars', 'Jupiter', 'Mercury'], answer: 1, category: 'Space' },
  { prompt: 'How many sides does a hexagon have?', options: ['Five', 'Six', 'Seven', 'Eight'], answer: 1, category: 'Science' },
  { prompt: 'What is the capital of Japan?', options: ['Seoul', 'Beijing', 'Tokyo', 'Bangkok'], answer: 2, category: 'Geography' },
  { prompt: 'Which animal is the largest land mammal?', options: ['Giraffe', 'Elephant', 'Rhino', 'Hippopotamus'], answer: 1, category: 'Nature' },
  { prompt: 'What is the chemical symbol for water?', options: ['CO2', 'O2', 'H2O', 'NaCl'], answer: 2, category: 'Science' },
  { prompt: 'Who painted the Mona Lisa?', options: ['Van Gogh', 'Leonardo da Vinci', 'Picasso', 'Monet'], answer: 1, category: 'Art' },
  { prompt: 'Which ocean is the largest?', options: ['Atlantic', 'Indian', 'Arctic', 'Pacific'], answer: 3, category: 'Geography' },
  { prompt: 'What is the fastest land animal?', options: ['Cheetah', 'Horse', 'Lion', 'Ostrich'], answer: 0, category: 'Nature' },
  { prompt: 'How many minutes are in one hour?', options: ['30', '45', '60', '90'], answer: 2, category: 'Everyday' },
  { prompt: 'Which instrument has black and white keys?', options: ['Violin', 'Flute', 'Piano', 'Trumpet'], answer: 2, category: 'Music' },
  { prompt: 'What do bees make?', options: ['Silk', 'Honey', 'Wax only', 'Milk'], answer: 1, category: 'Nature' },
  { prompt: 'Which shape has three sides?', options: ['Circle', 'Square', 'Triangle', 'Oval'], answer: 2, category: 'Shapes' },
];

export class TriviaBattleEngine implements GameEngine {
  readonly id: GameId = 'trivia_battle';

  create(players: GamePlayer[]): TriviaState {
    if (players.length < 2 || players.length > 8) throw new IllegalMoveError('Trivia Battle supports two to eight players.');
    const questionBank = this.shuffle(TRIVIA_QUESTIONS).slice(0, 10);
    return {
      questionBank,
      questionIndex: 0,
      rounds: questionBank.length,
      answered: players.map(() => false),
      answers: players.map(() => null),
      scores: players.map(() => 0),
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
      winnerIds: [],
      lastAnswer: null,
    };
  }

  validate(state: TriviaState, actorId: string, action: Action, players: GamePlayer[]): void {
    checkTurn(state, actorId);
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    if (action.type !== 'answer') throw new IllegalMoveError('Answer the current question.');
    asInt(action.answer, 'answer', 0, 3);
    if (state.answered[side]) throw new IllegalMoveError('You already answered this question.');
  }

  apply(state: TriviaState, actorId: string, action: Action, players: GamePlayer[]): TriviaState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as TriviaState;
    const side = players.findIndex((player) => player.id === actorId);
    const question = next.questionBank[next.questionIndex];
    const answer = action.answer as number;
    next.answered[side] = true;
    next.answers[side] = answer;
    if (answer === question.answer) next.scores[side] += 100;

    if (next.answered.every(Boolean)) {
      next.lastAnswer = { correctAnswer: question.answer, answers: [...next.answers] };
      if (next.questionIndex + 1 >= next.rounds) {
        const maximum = Math.max(...next.scores);
        next.winnerIds = next.scores.map((score, index) => score === maximum ? players[index].id : null).filter((id): id is string => id !== null);
        next.winnerId = next.winnerIds[0] ?? null;
        next.draw = next.winnerIds.length > 1;
        next.finished = true;
      } else {
        next.questionIndex += 1;
        next.answered = players.map(() => false);
        next.answers = players.map(() => null);
        next.turnIndex = 0;
        next.turnPlayerId = players[0].id;
      }
    } else {
      rotateTurn(next, players);
    }
    return next;
  }

  outcome(state: TriviaState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) && state.winnerIds.length ? state.winnerIds : state.winnerId ? [state.winnerId] : [];
    return { finished: Boolean(state.finished), winnerIds: winners, loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [], draw: Boolean(state.draw) };
  }

  botAction(state: TriviaState, _botId: string, _players: GamePlayer[]): Action {
    // The built-in question bank is intentionally elementary, so the table bot
    // plays this game as a confident trivia specialist. Its uncertainty and
    // mistakes are expressed in the other party and skill games instead of
    // making this deterministic test fixture randomly flaky.
    return { type: 'answer', answer: state.questionBank[state.questionIndex].answer };
  }

  private shuffle<T>(values: T[]): T[] {
    const copy = [...values];
    for (let index = copy.length - 1; index > 0; index -= 1) {
      const swap = randomInt(index + 1);
      [copy[index], copy[swap]] = [copy[swap], copy[index]];
    }
    return copy;
  }
}

type QuickKind = 'stop' | 'highlow' | 'cups';

interface QuickChallengeState extends GameState {
  round: number;
  rounds: number;
  challenge: { kind: QuickKind; zone?: [number, number]; card?: number };
  scores: number[];
  acted: boolean[];
  lastResult: { playerId: string; kind: string; detail: string; points: number } | null;
  history: Array<{ playerId: string; round: number; kind: string; points: number }>;
  turnIndex: number;
  turnPlayerId: string;
  finished: boolean;
  winnerId: string | null;
  draw?: boolean;
}

const cardName = (rank: number): string => (rank === 1 ? 'A' : rank === 11 ? 'J' : rank === 12 ? 'Q' : rank === 13 ? 'K' : String(rank));

// Every turn deals a fresh public mini-challenge. Anything hidden (the next card,
// the prize cup) is drawn inside apply and revealed in lastResult, so the state
// never stores a secret and needs no per-viewer sanitizing.
const dealChallenge = (): { kind: QuickKind; zone?: [number, number]; card?: number } => {
  const roll = randomInt(3);
  if (roll === 0) {
    const center = 20 + randomInt(61);
    return { kind: 'stop', zone: [center - 5, center + 5] };
  }
  if (roll === 1) return { kind: 'highlow', card: 1 + randomInt(13) };
  return { kind: 'cups' };
};

export class QuickChallengesEngine implements GameEngine {
  readonly id: GameId = 'quick_challenges';

  create(players: GamePlayer[]): QuickChallengeState {
    if (players.length < 1 || players.length > 6) throw new IllegalMoveError('Quick Challenges supports one to six players.');
    return {
      round: 1,
      rounds: 7,
      challenge: dealChallenge(),
      scores: players.map(() => 0),
      acted: players.map(() => false),
      lastResult: null,
      history: [],
      turnIndex: 0,
      turnPlayerId: players[0].id,
      finished: false,
      winnerId: null,
    };
  }

  validate(state: QuickChallengeState, actorId: string, action: Action, players: GamePlayer[]): void {
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    checkTurn(state, actorId);
    if (action.type !== 'play') throw new IllegalMoveError('Play the challenge.');
    if (state.acted[side]) throw new IllegalMoveError('You already played this round.');
    const kind = state.challenge.kind;
    if (kind === 'stop') asInt(action.value, 'value', 0, 100);
    else if (kind === 'highlow') {
      const guess = asString(action.guess, 'guess');
      if (guess !== 'high' && guess !== 'low') throw new IllegalMoveError('Guess high or low.');
    } else if (kind === 'cups') asInt(action.cup, 'cup', 0, 3);
    else throw new IllegalMoveError('Unknown challenge.');
  }

  apply(state: QuickChallengeState, actorId: string, action: Action, players: GamePlayer[]): QuickChallengeState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as QuickChallengeState;
    const side = players.findIndex((player) => player.id === actorId);
    const kind = next.challenge.kind;
    let points = 0;
    let detail = '';
    if (kind === 'stop') {
      const value = action.value as number;
      const [lo, hi] = (next.challenge.zone ?? [45, 55]) as number[];
      if (value >= lo && value <= hi) {
        points = 100;
        detail = `Stopped at ${value} — dead in the zone!`;
      } else {
        const distance = Math.min(Math.abs(value - lo), Math.abs(value - hi));
        points = Math.max(0, 60 - distance * 2);
        detail = `Stopped at ${value} (zone ${lo}-${hi})`;
      }
    } else if (kind === 'highlow') {
      const card = Number(next.challenge.card) || 7;
      const nextCard = 1 + randomInt(13);
      const guessHigh = (action.guess as string) === 'high';
      if (nextCard === card) {
        points = 50;
        detail = `${cardName(card)} then ${cardName(nextCard)} — a push!`;
      } else if ((nextCard > card) === guessHigh) {
        points = 100;
        detail = `${cardName(card)} then ${cardName(nextCard)} — called it!`;
      } else {
        detail = `${cardName(card)} then ${cardName(nextCard)} — wrong way.`;
      }
    } else {
      const prize = randomInt(4);
      const cup = action.cup as number;
      if (cup === prize) {
        points = 100;
        detail = `Cup ${cup + 1} hid the prize!`;
      } else {
        points = 10;
        detail = `The prize was under cup ${prize + 1}.`;
      }
    }
    next.scores[side] += points;
    next.acted[side] = true;
    next.lastResult = { playerId: actorId, kind, detail, points };
    next.history.push({ playerId: actorId, round: Number(next.round), kind, points });
    if (next.acted.every(Boolean)) {
      if (Number(next.round) >= Number(next.rounds)) {
        next.finished = true;
        const max = Math.max(...next.scores);
        next.winnerId = players[next.scores.indexOf(max)].id;
        next.draw = next.scores.filter((score) => score === max).length > 1;
      } else {
        next.round = Number(next.round) + 1;
        next.acted = players.map(() => false);
        next.turnIndex = 0;
        next.turnPlayerId = players[0].id;
        next.challenge = dealChallenge();
      }
    } else {
      rotateTurn(next, players);
      next.challenge = dealChallenge();
    }
    return next;
  }

  outcome(state: QuickChallengeState, players: GamePlayer[]): GameOutcome {
    const winner = typeof state.winnerId === 'string' ? state.winnerId : '';
    return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) };
  }

  botAction(state: QuickChallengeState): Action {
    const challenge = state.challenge;
    if (challenge.kind === 'stop') {
      const [lo, hi] = (challenge.zone ?? [45, 55]) as number[];
      const center = Math.round((lo + hi) / 2);
      return { type: 'play', value: Math.min(100, Math.max(0, center + (randomInt(11) - 5))) };
    }
    if (challenge.kind === 'highlow') {
      const card = Number(challenge.card) || 7;
      if (card < 7) return { type: 'play', guess: 'high' };
      if (card > 7) return { type: 'play', guess: 'low' };
      return { type: 'play', guess: randomInt(2) === 0 ? 'high' : 'low' };
    }
    return { type: 'play', cup: randomInt(4) };
  }
}
