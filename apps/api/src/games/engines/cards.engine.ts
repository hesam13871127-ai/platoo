import { Action, asInt, GameEngine, GameId, GameOutcome, GamePlayer, GameState, IllegalMoveError, clone, randomInt, rotateTurn } from '../game.types';

const OCHO_COLORS = ['red', 'yellow', 'green', 'blue'] as const;
type OchoColor = (typeof OCHO_COLORS)[number];
type OchoCardColor = OchoColor | 'wild';

interface OchoCard {
  color: OchoCardColor;
  value: string;
}

interface OchoState extends GameState {
  hands: OchoCard[][];
  discard: OchoCard[];
  currentColor: string;
  direction: 1 | -1;
  turnIndex: number;
  turnPlayerId: string;
  winnerId: string | null;
  finished: boolean;
  draw: OchoCard[];
  pendingDraw: 0 | 2 | 4;
  pendingDrawSource: number | null;
  wildFourLegal: boolean | null;
  drawnCardIndex: number | null;
  awaitingColor: boolean;
}

const isOchoColor = (value: unknown): value is OchoColor => typeof value === 'string' && (OCHO_COLORS as readonly string[]).includes(value);

export class OchoEngine implements GameEngine {
  readonly id: GameId = 'ocho';

  create(players: GamePlayer[]): OchoState {
    if (players.length < 2 || players.length > 4) throw new IllegalMoveError('Ocho supports two to four players.');
    const deck = this.shuffle(this.deck());
    const hands = players.map(() => deck.splice(0, 7));
    let first = deck.pop() as OchoCard;

    // A Wild Draw Four cannot be the opening discard. Return it and draw again.
    while (first.value === 'wild4') {
      deck.unshift(first);
      first = deck.pop() as OchoCard;
    }

    const state: OchoState = {
      hands,
      draw: deck,
      discard: [first],
      currentColor: first.color === 'wild' ? '' : first.color,
      direction: 1,
      turnIndex: 0,
      turnPlayerId: players[0].id,
      winnerId: null,
      finished: false,
      pendingDraw: 0,
      pendingDrawSource: null,
      wildFourLegal: null,
      drawnCardIndex: null,
      awaitingColor: first.value === 'wild',
    };

    this.applyOpeningCard(state, first, players);
    return state;
  }

  validate(state: OchoState, actorId: string, action: Action, players: GamePlayer[]): void {
    if (state.finished) throw new IllegalMoveError('This game has finished.');
    if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.');

    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');

    if (state.awaitingColor) {
      if (action.type !== 'choose_color' || !isOchoColor(action.color)) throw new IllegalMoveError('Choose a color before playing.');
      return;
    }

    const pendingDraw = Number(state.pendingDraw ?? 0);
    if (pendingDraw > 0) {
      if (action.type === 'challenge') {
        if (pendingDraw !== 4) throw new IllegalMoveError('Only a Wild Draw Four can be challenged.');
        return;
      }
      if (action.type !== 'draw') throw new IllegalMoveError('Draw the penalty cards or challenge the Wild Draw Four.');
      return;
    }

    if (action.type === 'draw') {
      if (state.drawnCardIndex !== null) throw new IllegalMoveError('You have already drawn a card this turn.');
      return;
    }

    if (action.type === 'pass') {
      if (state.drawnCardIndex === null) throw new IllegalMoveError('You may only pass after drawing a playable card.');
      return;
    }

    if (action.type !== 'play') throw new IllegalMoveError('Use play, draw, or pass.');
    const index = asInt(action.index, 'index', 0, state.hands[side].length - 1);
    const card = state.hands[side][index];
    if (!card) throw new IllegalMoveError('That card is not in your hand.');
    if (state.drawnCardIndex !== null && index !== state.drawnCardIndex) throw new IllegalMoveError('You may only play the card you just drew.');
    if (!this.isPlayable(card, state)) throw new IllegalMoveError('That card cannot be played.');
    // Wild Draw Four may be attempted even when illegal; the next player can challenge it.
    if (card.color === 'wild' && !isOchoColor(action.color)) throw new IllegalMoveError('Choose a color for a wild card.');
  }

  apply(state: OchoState, actorId: string, action: Action, players: GamePlayer[]): OchoState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as OchoState;
    const side = players.findIndex((player) => player.id === actorId);

    if (next.awaitingColor) {
      next.currentColor = action.color as OchoColor;
      next.awaitingColor = false;
      rotateTurn(next, players, next.direction);
      return next;
    }

    if (Number(next.pendingDraw ?? 0) > 0) {
      if (action.type === 'challenge') {
        this.resolveChallenge(next, side, players);
        return next;
      }
      this.drawCards(next, side, Number(next.pendingDraw));
      this.clearPenalty(next);
      next.drawnCardIndex = null;
      rotateTurn(next, players, next.direction);
      return next;
    }

    if (action.type === 'draw') {
      const drawnIndex = this.drawOne(next, side);
      if (drawnIndex === null) {
        rotateTurn(next, players, next.direction);
        return next;
      }
      const drawn = next.hands[side][drawnIndex];
      if (this.isPlayable(drawn, next) && (drawn.value !== 'wild4' || this.isWildFourLegal(next.hands[side], next.currentColor, drawnIndex))) {
        next.drawnCardIndex = drawnIndex;
      } else {
        next.drawnCardIndex = null;
        rotateTurn(next, players, next.direction);
      }
      return next;
    }

    if (action.type === 'pass') {
      next.drawnCardIndex = null;
      rotateTurn(next, players, next.direction);
      return next;
    }

    const index = action.index as number;
    const card = next.hands[side].splice(index, 1)[0];
    const wildFourLegal = card.value === 'wild4' ? this.isWildFourLegal(next.hands[side], next.currentColor, -1) : null;
    next.drawnCardIndex = null;
    next.discard.push(card);
    next.currentColor = card.color === 'wild' ? action.color as OchoColor : card.color;

    if (next.hands[side].length === 0) {
      next.finished = true;
      next.winnerId = actorId;
      return next;
    }

    // A player who reaches one card must call Ocho as part of the play action.
    if (next.hands[side].length === 1 && action.call !== true) this.drawCards(next, side, 2);

    switch (card.value) {
      case 'skip':
        rotateTurn(next, players, next.direction * 2);
        break;
      case 'reverse':
        next.direction = (next.direction * -1) as 1 | -1;
        rotateTurn(next, players, players.length === 2 ? next.direction * 2 : next.direction);
        break;
      case 'draw2':
        next.pendingDraw = 2;
        next.pendingDrawSource = side;
        rotateTurn(next, players, next.direction);
        break;
      case 'wild4':
        next.pendingDraw = 4;
        next.pendingDrawSource = side;
        next.wildFourLegal = wildFourLegal;
        rotateTurn(next, players, next.direction);
        break;
      default:
        rotateTurn(next, players, next.direction);
    }

    return next;
  }

  outcome(state: OchoState, players: GamePlayer[]): GameOutcome {
    const winner = typeof state.winnerId === 'string' ? state.winnerId : '';
    return {
      finished: Boolean(state.finished),
      winnerIds: winner ? [winner] : [],
      loserIds: winner ? players.filter((player) => player.id !== winner).map((player) => player.id) : [],
      draw: false,
    };
  }

  botAction(state: OchoState, botId: string, players: GamePlayer[]): Action {
    const side = players.findIndex((player) => player.id === botId);
    if (state.awaitingColor) return { type: 'choose_color', color: this.bestColor(state.hands[side]) };
    if (Number(state.pendingDraw ?? 0) === 4) return state.wildFourLegal === false ? { type: 'challenge' } : { type: 'draw' };
    if (Number(state.pendingDraw ?? 0) === 2) return { type: 'draw' };

    const hand = state.hands[side];
    if (state.drawnCardIndex !== null) {
      const drawn = hand[state.drawnCardIndex];
      return {
        type: 'play',
        index: state.drawnCardIndex,
        call: hand.length === 2,
        ...(drawn.color === 'wild' ? { color: this.bestColor(hand) } : {}),
      };
    }
    const legal = hand
      .map((card, index) => this.isPlayable(card, state) && (card.value !== 'wild4' || this.isWildFourLegal(hand, state.currentColor, index)) ? index : -1)
      .filter((index) => index >= 0);

    if (!legal.length) return { type: 'draw' };
    // Heuristic pick: keep the majority color, save wilds, and disrupt with
    // action cards when an opponent is about to go out.
    const best = this.bestColor(hand);
    const opponentsShort = players.some((player, item) => item !== side && state.hands[item].length <= 2);
    const scored = legal.map((index) => {
      const card = hand[index];
      let score = Math.random();
      if (card.color !== 'wild' && card.color === best) score += 3;
      if (card.value === 'draw2' || card.value === 'skip' || card.value === 'reverse') score += opponentsShort ? 4 : 1;
      if (card.value === 'wild4') score += opponentsShort ? 5 : -3;
      if (card.value === 'wild') score -= 2;
      return { index, score };
    }).sort((a, b) => b.score - a.score);
    const index = scored[0].index;
    const card = hand[index];
    return {
      type: 'play',
      index,
      call: hand.length === 2,
      ...(card.color === 'wild' ? { color: this.bestColor(hand) } : {}),
    };
  }

  private applyOpeningCard(state: OchoState, card: OchoCard, players: GamePlayer[]): void {
    if (card.value === 'reverse') {
      state.direction = -1;
      state.turnIndex = players.length - 1;
      state.turnPlayerId = players[state.turnIndex].id;
    } else if (card.value === 'skip') {
      state.turnIndex = players.length > 1 ? 1 : 0;
      state.turnPlayerId = players[state.turnIndex].id;
    } else if (card.value === 'draw2') {
      state.pendingDraw = 2;
      state.pendingDrawSource = null;
      state.turnIndex = players.length > 1 ? 1 : 0;
      state.turnPlayerId = players[state.turnIndex].id;
    }
  }

  private resolveChallenge(state: OchoState, challenger: number, players: GamePlayer[]): void {
    const source = state.pendingDrawSource;
    if (source === null) throw new IllegalMoveError('This Wild Draw Four cannot be challenged.');
    if (state.wildFourLegal === false) {
      this.drawCards(state, source, 4);
      this.clearPenalty(state);
      state.drawnCardIndex = null;
      state.turnIndex = challenger;
      state.turnPlayerId = players[challenger].id;
      return;
    }

    this.drawCards(state, challenger, 6);
    this.clearPenalty(state);
    state.drawnCardIndex = null;
    rotateTurn(state, players, state.direction);
  }

  private clearPenalty(state: OchoState): void {
    state.pendingDraw = 0;
    state.pendingDrawSource = null;
    state.wildFourLegal = null;
  }

  private drawCards(state: OchoState, side: number, count: number): void {
    for (let index = 0; index < count; index += 1) this.drawOne(state, side);
  }

  private drawOne(state: OchoState, side: number): number | null {
    if (!state.draw.length) this.refill(state);
    const card = state.draw.pop();
    if (!card) return null;
    state.hands[side].push(card);
    return state.hands[side].length - 1;
  }

  private refill(state: OchoState): void {
    if (state.discard.length <= 1) return;
    const top = state.discard.pop() as OchoCard;
    state.draw = this.shuffle(state.discard.splice(0));
    state.discard = [top];
  }

  private isPlayable(card: OchoCard, state: OchoState): boolean {
    const top = state.discard[state.discard.length - 1];
    return card.color === 'wild' || card.color === state.currentColor || card.value === top.value;
  }

  private isWildFourLegal(hand: OchoCard[], currentColor: string, ignoredIndex: number): boolean {
    return !hand.some((card, index) => index !== ignoredIndex && card.color !== 'wild' && card.color === currentColor);
  }

  private bestColor(hand: OchoCard[]): OchoColor {
    const counts = new Map<OchoColor, number>(OCHO_COLORS.map((color) => [color, 0]));
    for (const card of hand) if (isOchoColor(card.color)) counts.set(card.color, (counts.get(card.color) ?? 0) + 1);
    return [...counts.entries()].sort((a, b) => b[1] - a[1])[0][0];
  }

  private shuffle(cards: OchoCard[]): OchoCard[] {
    for (let index = cards.length - 1; index > 0; index -= 1) {
      const swap = randomInt(index + 1);
      [cards[index], cards[swap]] = [cards[swap], cards[index]];
    }
    return cards;
  }

  private deck(): OchoCard[] {
    const deck: OchoCard[] = [];
    for (const color of OCHO_COLORS) {
      deck.push({ color, value: '0' });
      for (let copy = 0; copy < 2; copy += 1) {
        for (const value of ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'skip', 'reverse', 'draw2']) deck.push({ color, value });
      }
    }
    for (let copy = 0; copy < 4; copy += 1) {
      deck.push({ color: 'wild', value: 'wild' });
      deck.push({ color: 'wild', value: 'wild4' });
    }
    return deck;
  }
}

type Suit = 'C' | 'D' | 'H' | 'S';
interface PlayingCard { suit: Suit; rank: number; }
interface TrickState extends GameState { hands: PlayingCard[][]; trick: Array<{ player: number; card: PlayingCard }>; leadSuit: Suit | null; turnIndex: number; turnPlayerId: string; scores: number[]; round: number; winnerId: string | null; finished: boolean; targetScore: number; }

abstract class TrickTakingEngine implements GameEngine {
  abstract readonly id: GameId;
  protected abstract readonly targetScore: number;
  protected readonly lowScoreWins: boolean = false;
  protected abstract scoreTrick(trick: Array<{ player: number; card: PlayingCard }>): number;
  protected abstract winningPlayer(trick: Array<{ player: number; card: PlayingCard }>, lead: Suit): number;
  create(players: GamePlayer[]): TrickState { const deck = this.deck(); const hands = players.map(() => [] as PlayingCard[]); deck.forEach((card, i) => hands[i % players.length].push(card)); const even = Math.min(...hands.map((hand) => hand.length)); const trimmed = hands.map((hand) => hand.slice(0, even)); return { hands: trimmed, trick: [], leadSuit: null, turnIndex: 0, turnPlayerId: players[0].id, scores: players.map(() => 0), round: 1, winnerId: null, finished: false, targetScore: this.targetScore }; }
  validate(state: TrickState, actorId: string, action: Action, players: GamePlayer[]): void { if (state.finished) throw new IllegalMoveError('This game has finished.'); if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.'); if (action.type !== 'play') throw new IllegalMoveError('Use play.'); const side = players.findIndex((p) => p.id === actorId); const index = asInt(action.index, 'index', 0, state.hands[side].length - 1); const card = state.hands[side][index]; if (state.leadSuit && card.suit !== state.leadSuit && state.hands[side].some((candidate) => candidate.suit === state.leadSuit)) throw new IllegalMoveError('You must follow the lead suit.'); }
  apply(state: TrickState, actorId: string, action: Action, players: GamePlayer[]): TrickState { this.validate(state, actorId, action, players); const next = clone(state) as TrickState; const side = players.findIndex((p) => p.id === actorId); const card = next.hands[side].splice(action.index as number, 1)[0]; if (!next.leadSuit) next.leadSuit = card.suit; next.trick.push({ player: side, card }); if (next.trick.length === players.length) { const winner = this.winningPlayer(next.trick, next.leadSuit as Suit); next.scores[winner] += this.scoreTrick(next.trick); next.trick = []; next.leadSuit = null; next.turnIndex = winner; next.turnPlayerId = players[winner].id; if (next.scores.some((score) => score >= next.targetScore) || next.hands.every((hand) => !hand.length)) { next.finished = true; const best = this.lowScoreWins ? Math.min(...next.scores) : Math.max(...next.scores); const winners = next.scores.map((score, i) => score === best ? players[i].id : null).filter((id): id is string => Boolean(id)); next.winnerId = winners[0] ?? null; next.draw = winners.length > 1; } } else rotateTurn(next, players); return next; }
  outcome(state: TrickState, players: GamePlayer[]): GameOutcome { const winner = typeof state.winnerId === 'string' ? state.winnerId : ''; return { finished: Boolean(state.finished), winnerIds: winner ? [winner] : [], loserIds: winner ? players.filter((p) => p.id !== winner).map((p) => p.id) : [], draw: Boolean(state.draw) }; }
  botAction(state: TrickState, botId: string, players: GamePlayer[]): Action { const side = players.findIndex((p) => p.id === botId); const hand = state.hands[side]; const legal = hand.map((card, index) => (!state.leadSuit || card.suit === state.leadSuit || !hand.some((candidate) => candidate.suit === state.leadSuit)) ? index : -1).filter((index) => index >= 0); return { type: 'play', index: legal[randomInt(legal.length)] ?? 0 }; }
  private deck(): PlayingCard[] { const deck: PlayingCard[] = []; for (const suit of ['C','D','H','S'] as Suit[]) for (let rank = 2; rank <= 14; rank += 1) deck.push({ suit, rank }); return deck.sort(() => Math.random() - 0.5); }
}

export class HeartsEngine extends TrickTakingEngine { readonly id: GameId = 'hearts'; protected readonly targetScore = 100; protected readonly lowScoreWins = true; protected scoreTrick(trick: Array<{ player: number; card: PlayingCard }>): number { return trick.reduce((sum, item) => sum + (item.card.suit === 'H' ? 1 : item.card.suit === 'S' && item.card.rank === 12 ? 13 : 0), 0); } protected winningPlayer(trick: Array<{ player: number; card: PlayingCard }>, lead: Suit): number { return trick.filter((item) => item.card.suit === lead).sort((a, b) => b.card.rank - a.card.rank)[0].player; } }
export class SpadesEngine extends TrickTakingEngine { readonly id: GameId = 'spades'; protected readonly targetScore = 500; protected scoreTrick(trick: Array<{ player: number; card: PlayingCard }>): number { return 1; } protected winningPlayer(trick: Array<{ player: number; card: PlayingCard }>, lead: Suit): number { const spades = trick.filter((item) => item.card.suit === 'S'); const pool = spades.length ? spades : trick.filter((item) => item.card.suit === lead); return pool.sort((a, b) => b.card.rank - a.card.rank)[0].player; } }
