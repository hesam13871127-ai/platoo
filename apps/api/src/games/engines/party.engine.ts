import { Action, asInt, asString, GameEngine, GameId, GameOutcome, GamePlayer, GameState, IllegalMoveError, clone, randomInt, rotateTurn } from '../game.types';

const checkTurn = (state: GameState, actorId: string) => { if (state.finished) throw new IllegalMoveError('This game has finished.'); if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.'); };

export class DicePartyEngine implements GameEngine {
  readonly id: GameId = 'dice_party';
  create(players: GamePlayer[]): GameState { return { round: 1, maxRounds: 5, scores: players.map(() => 0), rolls: players.map(() => null), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { checkTurn(state, actorId); if (action.type !== 'roll') throw new IllegalMoveError('Use roll.'); if ((state.rolls as unknown[])[players.findIndex((p) => p.id === actorId)] !== null) throw new IllegalMoveError('You already rolled this round.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); const value = randomInt(6) + 1; (next.rolls as (number | null)[])[side] = value; (next.scores as number[])[side] += value; const allRolled = (next.rolls as unknown[]).every((roll) => roll !== null); if (allRolled) { if (Number(next.round) >= Number(next.maxRounds)) { next.finished = true; const max = Math.max(...(next.scores as number[])); next.winnerId = players[(next.scores as number[]).indexOf(max)].id; next.draw = (next.scores as number[]).filter((score) => score === max).length > 1; } else { next.round = Number(next.round) + 1; next.rolls = players.map(() => null); next.turnIndex = 0; next.turnPlayerId = players[0].id; } } else rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; }
  botAction(): Action { return { type: 'roll' }; }
}

export class BingoEngine implements GameEngine {
  readonly id: GameId = 'bingo';
  create(players: GamePlayer[]): GameState { const cards = players.map(() => { const values = Array.from({ length: 25 }, (_, i) => i + 1).sort(() => Math.random() - 0.5); return { values, marked: Array(25).fill(false) as boolean[] }; }); return { cards, called: [], bag: Array.from({ length: 75 }, (_, i) => i + 1).sort(() => Math.random() - 0.5), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { checkTurn(state, actorId); if (action.type !== 'call') throw new IllegalMoveError('Use call.'); const number = asInt(action.number, 'number', 1, 75); if (!(state.bag as number[]).includes(number)) throw new IllegalMoveError('That number has already been called.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const number = action.number as number; next.bag = (next.bag as number[]).filter((value) => value !== number); (next.called as number[]).push(number); for (const card of next.cards as Array<{ values: number[]; marked: boolean[] }>) { const position = card.values.indexOf(number); if (position >= 0) card.marked[position] = true; } const winnerIndex = (next.cards as Array<{ values: number[]; marked: boolean[] }>).findIndex((card) => this.hasBingo(card.marked)); if (winnerIndex >= 0) { next.finished = true; next.winnerId = players[winnerIndex].id; } else if (!(next.bag as number[]).length) { next.finished = true; next.draw = true; } else rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; }
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action { const bag = state.bag as number[]; return { type: 'call', number: bag[randomInt(bag.length)] ?? 1 }; }
  private hasBingo(marked: boolean[]): boolean { return [0,1,2,3,4].some((r) => [0,1,2,3,4].every((c) => marked[r * 5 + c])) || [0,1,2,3,4].some((c) => [0,1,2,3,4].every((r) => marked[r * 5 + c])) || [0,1,2,3,4].every((i) => marked[i * 5 + i]) || [0,1,2,3,4].every((i) => marked[i * 5 + (4 - i)]); }
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
      const candidates = players.map((_, index) => index).filter((index) => state.alive[index] && (role !== 'werewolf' || state.roles[index] !== 'werewolf'));
      return { type: 'night', target: candidates[randomInt(candidates.length)] ?? 0 };
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
  create(players: GamePlayer[]): GameState { return { words: [], used: [], requiredLetter: null, scores: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null, passCount: 0 }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { checkTurn(state, actorId); if (action.type !== 'word') throw new IllegalMoveError('Submit a word.'); const word = asString(action.word, 'word').toLowerCase(); if (!/^[a-zA-Z\u0600-\u06ff]{2,24}$/.test(word)) throw new IllegalMoveError('Use a word with two to twenty-four letters.'); if ((state.used as string[]).includes(word)) throw new IllegalMoveError('That word has already been used.'); if (state.requiredLetter && !word.startsWith(state.requiredLetter as string)) throw new IllegalMoveError(`Your word must start with ${state.requiredLetter}.`); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const word = (action.word as string).toLowerCase(); (next.words as string[]).push(word); (next.used as string[]).push(word); (next.scores as number[])[players.findIndex((p) => p.id === actorId)] += word.length; next.requiredLetter = word[word.length - 1]; next.passCount = 0; rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: false }; }
  botAction(state: GameState): Action { const letter = (state.requiredLetter as string | null) ?? 'v'; return { type: 'word', word: `${letter}ibe` }; }
}

export class MemoryRaceEngine implements GameEngine {
  readonly id: GameId = 'memory_race';
  create(players: GamePlayer[]): GameState { const values = Array.from({ length: 12 }, (_, i) => i).flatMap((i) => [i, i]).sort(() => Math.random() - 0.5); return { values, revealed: Array(24).fill(false), matched: Array(24).fill(false), selections: [], scores: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { checkTurn(state, actorId); if (action.type !== 'flip') throw new IllegalMoveError('Flip a card.'); const index = asInt(action.index, 'index', 0, 23); if ((state.revealed as boolean[])[index] || (state.matched as boolean[])[index]) throw new IllegalMoveError('That card is not available.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const index = action.index as number; (next.revealed as boolean[])[index] = true; (next.selections as number[]).push(index); if ((next.selections as number[]).length === 2) { const selections = next.selections as number[]; if ((next.values as number[])[selections[0]] === (next.values as number[])[selections[1]]) { (next.matched as boolean[])[selections[0]] = true; (next.matched as boolean[])[selections[1]] = true; (next.scores as number[])[players.findIndex((p) => p.id === actorId)] += 1; } else { (next.revealed as boolean[])[selections[0]] = false; (next.revealed as boolean[])[selections[1]] = false; rotateTurn(next, players); } next.selections = []; if ((next.matched as boolean[]).every(Boolean)) { next.finished = true; const max = Math.max(...(next.scores as number[])); next.winnerId = players[(next.scores as number[]).indexOf(max)].id; } } return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: false }; }
  botAction(state: GameState): Action { const available = (state.matched as boolean[]).map((matched, i) => !matched && !(state.revealed as boolean[])[i] ? i : -1).filter((i) => i >= 0); return { type: 'flip', index: available[randomInt(available.length)] ?? 0 }; }
}

export class KnowledgeEngine implements GameEngine {
  readonly id: GameId;
  private readonly questionCount: number;
  constructor(id: GameId, questionCount = 10) { this.id = id; this.questionCount = questionCount; }
  create(players: GamePlayer[]): GameState { return { question: 1, questionCount: this.questionCount, answered: players.map(() => false), scores: players.map(() => 0), turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { checkTurn(state, actorId); if (action.type !== 'answer') throw new IllegalMoveError('Answer the current challenge.'); asInt(action.answer, 'answer', 0, 3); const side = players.findIndex((p) => p.id === actorId); if ((state.answered as boolean[])[side]) throw new IllegalMoveError('You already answered this question.'); }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); (next.answered as boolean[])[side] = true; if ((action.answer as number) === Number(next.question) % 4) (next.scores as number[])[side] += 100 + randomInt(50); if ((next.answered as boolean[]).every(Boolean)) { if (Number(next.question) >= Number(next.questionCount)) { next.finished = true; const max = Math.max(...(next.scores as number[])); next.winnerId = players[(next.scores as number[]).indexOf(max)].id; next.draw = (next.scores as number[]).filter((score) => score === max).length > 1; } else { next.question = Number(next.question) + 1; next.answered = players.map(() => false); next.turnIndex = 0; next.turnPlayerId = players[0].id; } } else rotateTurn(next, players); return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; }
  botAction(state: GameState): Action { return { type: 'answer', answer: randomInt(4) }; }
}

export class ImpostorLightEngine implements GameEngine {
  readonly id: GameId = 'impostor_light';
  create(players: GamePlayer[]): GameState { const impostor = randomInt(players.length); return { impostor, clues: players.map(() => null), votes: players.map(() => null), phase: 'clues', turnIndex: 0, turnPlayerId: players[0].id, finished: false, winnerId: null }; }
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void { checkTurn(state, actorId); const side = players.findIndex((p) => p.id === actorId); if (state.phase === 'clues' && action.type !== 'clue') throw new IllegalMoveError('Give a clue.'); if (state.phase === 'vote' && action.type !== 'vote') throw new IllegalMoveError('Vote for the impostor.'); if (state.phase === 'clues') asString(action.clue, 'clue'); else { const target = asInt(action.target, 'target', 0, players.length - 1); if (target === side) throw new IllegalMoveError('You cannot vote for yourself.'); } }
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState { this.validate(state, actorId, action, players); const next = clone(state); const side = players.findIndex((p) => p.id === actorId); if (next.phase === 'clues') { (next.clues as (string | null)[])[side] = (action.clue as string).slice(0, 100); if ((next.clues as unknown[]).every(Boolean)) { next.phase = 'vote'; next.votes = players.map(() => null); next.turnIndex = 0; next.turnPlayerId = players[0].id; } else rotateTurn(next, players); } else { (next.votes as (number | null)[])[side] = action.target as number; if ((next.votes as unknown[]).every((vote) => vote !== null)) { const target = (next.votes as number[]).sort((a, b) => (next.votes as number[]).filter((v) => v === b).length - (next.votes as number[]).filter((v) => v === a).length)[0]; next.finished = true; next.winnerId = target === Number(next.impostor) ? players.find((p) => p.id !== players[Number(next.impostor)].id)?.id ?? null : players[Number(next.impostor)].id; next.impostorCaught = target === Number(next.impostor); } else rotateTurn(next, players); } return next; }
  outcome(state: GameState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: false }; }
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action { const side = players.findIndex((p) => p.id === botId); return state.phase === 'clues' ? { type: 'clue', clue: 'bright' } : { type: 'vote', target: players.findIndex((_, i) => i !== side) }; }
}

export class EmojiCharadesEngine extends KnowledgeEngine { readonly id: GameId = 'emoji_charades'; constructor() { super('emoji_charades', 7); } }
export class SketchGuessEngine extends KnowledgeEngine { readonly id: GameId = 'sketch_guess'; constructor() { super('sketch_guess', 7); } }
export class TriviaBattleEngine extends KnowledgeEngine { readonly id: GameId = 'trivia_battle'; constructor() { super('trivia_battle', 10); } }
export class QuickChallengesEngine extends KnowledgeEngine { readonly id: GameId = 'quick_challenges'; constructor() { super('quick_challenges', 7); } }
