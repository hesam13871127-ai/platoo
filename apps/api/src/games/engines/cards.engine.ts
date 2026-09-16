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
interface TrickState extends GameState {
  hands: PlayingCard[][];
  trick: Array<{ player: number; card: PlayingCard }>;
  leadSuit: Suit | null;
  turnIndex: number;
  turnPlayerId: string;
  scores: number[];
  round: number;
  winnerId: string | null;
  winnerIds?: string[];
  finished: boolean;
  targetScore: number;
  draw?: boolean;
  // Hearts uses these flags for the first-trick/heart-breaking rules.
  heartsBroken?: boolean;
  openingLead?: boolean;
  // Spades bids before each hand and counts tricks separately from score.
  rulesActive?: boolean;
  bidPhase?: boolean;
  bids?: Array<number | null>;
  tricksWon?: number[];
  spadesBroken?: boolean;
  teamScores?: number[];
}

abstract class TrickTakingEngine implements GameEngine {
  abstract readonly id: GameId;
  protected abstract readonly targetScore: number;
  protected readonly lowScoreWins: boolean = false;
  protected abstract scoreTrick(trick: Array<{ player: number; card: PlayingCard }>): number;
  protected abstract winningPlayer(trick: Array<{ player: number; card: PlayingCard }>, lead: Suit): number;

  create(players: GamePlayer[]): TrickState {
    if (players.length < 2 || players.length > 4) throw new IllegalMoveError('This trick-taking game supports two to four players.');
    const deck = this.dealDeck(players.length);
    const hands = players.map(() => [] as PlayingCard[]);
    deck.forEach((card, index) => hands[index % players.length].push(card));
    const state: TrickState = {
      hands,
      trick: [],
      leadSuit: null,
      turnIndex: 0,
      turnPlayerId: players[0].id,
      scores: players.map(() => 0),
      round: 1,
      winnerId: null,
      winnerIds: [],
      finished: false,
      targetScore: this.targetScore,
      rulesActive: true,
      heartsBroken: false,
      openingLead: this.id === 'hearts',
      bidPhase: this.id === 'spades',
      bids: this.id === 'spades' ? players.map(() => null) : undefined,
      tricksWon: this.id === 'spades' ? players.map(() => 0) : undefined,
      spadesBroken: false,
      teamScores: this.id === 'spades' && this.usesTeams(players) ? [0, 0] : undefined,
    };
    if (this.id === 'hearts') {
      const starter = hands.findIndex((hand) => hand.some((card) => card.suit === 'C' && card.rank === 2));
      if (starter >= 0) {
        state.turnIndex = starter;
        state.turnPlayerId = players[starter].id;
      }
    }
    return state;
  }

  validate(state: TrickState, actorId: string, action: Action, players: GamePlayer[]): void {
    if (state.finished) throw new IllegalMoveError('This game has finished.');
    const side = players.findIndex((player) => player.id === actorId);
    if (side < 0) throw new IllegalMoveError('You are not in this game.');
    if (state.turnPlayerId !== actorId) throw new IllegalMoveError('It is not your turn.');
    if (this.id === 'spades' && state.bidPhase) {
      if (action.type !== 'bid') throw new IllegalMoveError('Bid before playing a card.');
      if (!Array.isArray(state.bids) || state.bids[side] !== null) throw new IllegalMoveError('You already bid this hand.');
      asInt(action.bid, 'bid', 0, state.hands[side].length);
      return;
    }
    if (action.type !== 'play') throw new IllegalMoveError('Use play.');
    const index = asInt(action.index, 'index', 0, state.hands[side].length - 1);
    const card = state.hands[side][index];
    if (!card) throw new IllegalMoveError('That card is not in your hand.');
    const lead = state.leadSuit;
    if (lead && card.suit !== lead && state.hands[side].some((candidate) => candidate.suit === lead)) throw new IllegalMoveError('You must follow the lead suit.');
    if (this.id === 'hearts') this.validateHeartsLead(state, card, state.hands[side]);
    if (this.id === 'spades' && !lead && !state.spadesBroken && card.suit === 'S' && state.hands[side].some((candidate) => candidate.suit !== 'S')) throw new IllegalMoveError('Spades have not been broken.');
  }

  apply(state: TrickState, actorId: string, action: Action, players: GamePlayer[]): TrickState {
    this.validate(state, actorId, action, players);
    const next = clone(state) as TrickState;
    const side = players.findIndex((player) => player.id === actorId);
    if (this.id === 'spades' && next.bidPhase) {
      next.bids![side] = action.bid as number;
      const nextBidder = next.bids!.findIndex((bid) => bid === null);
      if (nextBidder >= 0) {
        next.turnIndex = nextBidder;
        next.turnPlayerId = players[nextBidder].id;
      } else {
        next.bidPhase = false;
        next.turnIndex = 0;
        next.turnPlayerId = players[0].id;
      }
      return next;
    }

    const card = next.hands[side].splice(action.index as number, 1)[0];
    if (!next.leadSuit) next.leadSuit = card.suit;
    if (this.id === 'hearts') {
      next.openingLead = false;
      if (card.suit === 'H' || card.suit === 'S' && card.rank === 12) next.heartsBroken = true;
    }
    if (this.id === 'spades' && card.suit === 'S') next.spadesBroken = true;
    next.trick.push({ player: side, card });

    if (next.trick.length !== players.length) {
      rotateTurn(next, players);
      return next;
    }

    const winner = this.winningPlayer(next.trick, next.leadSuit as Suit);
    const points = this.scoreTrick(next.trick);
    if (this.id === 'spades' && next.rulesActive) {
      next.tricksWon![winner] += 1;
    } else if (this.id === 'hearts' && points === 26) {
      // Shooting the moon is a strategic choice: the shooter receives zero,
      // every other player receives all 26 penalty points.
      for (let index = 0; index < next.scores.length; index += 1) if (index !== winner) next.scores[index] += 26;
    } else {
      next.scores[winner] += points;
    }
    next.trick = [];
    next.leadSuit = null;
    next.turnIndex = winner;
    next.turnPlayerId = players[winner].id;

    if (next.hands.every((hand) => hand.length === 0)) {
      if (this.id === 'spades' && next.rulesActive) this.finishSpadesHand(next, players);
      else if (this.id === 'hearts' && next.rulesActive) this.finishHeartsHand(next, players);
      else this.finishLegacyHand(next, players);
    }
    return next;
  }

  outcome(state: TrickState, players: GamePlayer[]): GameOutcome {
    const winners = Array.isArray(state.winnerIds) && state.winnerIds.length
      ? state.winnerIds
      : typeof state.winnerId === 'string' ? [state.winnerId] : [];
    return { finished: Boolean(state.finished), winnerIds: winners, loserIds: winners.length ? players.filter((player) => !winners.includes(player.id)).map((player) => player.id) : [], draw: Boolean(state.draw) };
  }

  botAction(state: TrickState, botId: string, players: GamePlayer[]): Action {
    const side = players.findIndex((player) => player.id === botId);
    if (this.id === 'spades' && state.bidPhase) return { type: 'bid', bid: this.botBid(state.hands[side]) };
    const hand = state.hands[side];
    const legal = hand.map((card, index) => {
      try {
        this.validate(state, botId, { type: 'play', index }, players);
        return index;
      } catch (_) {
        return -1;
      }
    }).filter((index) => index >= 0);
    if (!legal.length) return { type: 'play', index: 0 };
    const scored = legal.map((index) => {
      const card = hand[index];
      let value = Math.random() * 5;
      if (this.id === 'hearts') {
        if (card.suit === 'H') value -= 20;
        if (card.suit === 'S' && card.rank === 12) value -= 30;
        if (!state.leadSuit && card.suit !== 'H') value += card.rank / 4;
      } else {
        if (card.suit === 'S') value += 8 + card.rank / 4;
        if (state.leadSuit && card.suit === state.leadSuit) value += card.rank / 10;
      }
      return { index, value };
    }).sort((a, b) => b.value - a.value);
    return { type: 'play', index: scored[0].index };
  }

  private validateHeartsLead(state: TrickState, card: PlayingCard, hand: PlayingCard[]): void {
    if (state.openingLead && state.trick.length === 0 && !(card.suit === 'C' && card.rank === 2)) throw new IllegalMoveError('The 2 of clubs must lead the first trick.');
    if (state.trick.length === 0 && !state.heartsBroken && card.suit === 'H' && hand.some((candidate) => candidate.suit !== 'H')) throw new IllegalMoveError('Hearts have not been broken.');
    const mustFollowLead = Boolean(state.leadSuit && hand.some((candidate) => candidate.suit === state.leadSuit));
    if (state.round === 1 && !mustFollowLead && this.scoreTrick([{ player: 0, card }]) > 0 && hand.some((candidate) => this.scoreTrick([{ player: 0, card: candidate }]) === 0)) throw new IllegalMoveError('Point cards cannot be played on the first trick.');
  }

  private finishLegacyHand(state: TrickState, players: GamePlayer[]): void {
    state.finished = true;
    const best = this.lowScoreWins ? Math.min(...state.scores) : Math.max(...state.scores);
    state.winnerIds = state.scores.map((score, index) => score === best ? players[index].id : null).filter((id): id is string => id !== null);
    state.winnerId = state.winnerIds[0] ?? null;
    state.draw = state.winnerIds.length > 1;
  }

  private finishHeartsHand(state: TrickState, players: GamePlayer[]): void {
    if (state.scores.some((score) => score >= state.targetScore)) {
      this.finishLegacyHand(state, players);
      return;
    }
    state.round = Number(state.round) + 1;
    this.dealNextHand(state, players, false);
  }

  private finishSpadesHand(state: TrickState, players: GamePlayer[]): void {
    const teamMode = this.usesTeams(players);
    if (teamMode) {
      const teamBids = [0, 0]; const teamTricks = [0, 0];
      for (let index = 0; index < players.length; index += 1) {
        const team = players[index].team as number;
        teamBids[team] += state.bids![index] ?? 0;
        teamTricks[team] += state.tricksWon![index] ?? 0;
      }
      if (!state.teamScores) state.teamScores = [0, 0];
      for (let team = 0; team < 2; team += 1) state.teamScores[team] += teamTricks[team] >= teamBids[team] ? teamBids[team] * 10 + (teamTricks[team] - teamBids[team]) : -teamBids[team] * 10;
      for (let index = 0; index < players.length; index += 1) state.scores[index] = state.teamScores[players[index].team as number];
      if (state.teamScores.some((score) => score >= state.targetScore)) {
        const best = Math.max(...state.teamScores);
        state.winnerIds = players.filter((player) => player.team === state.teamScores!.indexOf(best)).map((player) => player.id);
        state.winnerId = state.winnerIds[0] ?? null;
        state.draw = state.teamScores.filter((score) => score === best).length > 1;
        state.finished = true;
        return;
      }
    } else {
      for (let index = 0; index < players.length; index += 1) {
        const bid = state.bids![index] ?? 0; const tricks = state.tricksWon![index] ?? 0;
        state.scores[index] += tricks >= bid ? bid * 10 + (tricks - bid) : -bid * 10;
      }
      if (state.scores.some((score) => score >= state.targetScore)) {
        this.finishLegacyHand(state, players);
        return;
      }
    }
    state.round = Number(state.round) + 1;
    this.dealNextHand(state, players, true);
  }

  private dealNextHand(state: TrickState, players: GamePlayer[], spades: boolean): void {
    const deck = this.dealDeck(players.length);
    state.hands = players.map(() => [] as PlayingCard[]);
    deck.forEach((card, index) => state.hands[index % players.length].push(card));
    state.trick = [];
    state.leadSuit = null;
    state.heartsBroken = false;
    state.openingLead = this.id === 'hearts';
    state.spadesBroken = false;
    if (spades) {
      state.bidPhase = true;
      state.bids = players.map(() => null);
      state.tricksWon = players.map(() => 0);
      state.turnIndex = Number(state.round - 1) % players.length;
    } else {
      state.turnIndex = state.hands.findIndex((hand) => hand.some((card) => card.suit === 'C' && card.rank === 2));
      if (state.turnIndex < 0) state.turnIndex = 0;
    }
    state.turnPlayerId = players[state.turnIndex].id;
  }

  private dealDeck(playerCount: number): PlayingCard[] {
    const deck = this.deck();
    // Three-player deals use 51 cards so every hand is equal. Remove 2♦
    // rather than 2♣ so Hearts always has an unambiguous opening lead.
    while (deck.length % playerCount !== 0) {
      const index = deck.findIndex((card) => card.suit === 'D' && card.rank === 2);
      deck.splice(index >= 0 ? index : deck.length - 1, 1);
    }
    return deck;
  }

  private usesTeams(players: GamePlayer[]): boolean {
    return this.id === 'spades' && players.length === 4 && players.every((player) => player.team !== undefined);
  }

  private botBid(hand: PlayingCard[]): number {
    const strong = hand.reduce((score, card) => score + (card.suit === 'S' ? (card.rank >= 13 ? 2 : card.rank >= 11 ? 1 : 0.25) : card.rank === 14 ? 1 : 0), 0);
    return Math.max(0, Math.min(hand.length, Math.round(strong + (randomInt(5) === 0 ? (randomInt(3) - 1) : 0))));
  }

  private deck(): PlayingCard[] {
    const deck: PlayingCard[] = [];
    for (const suit of ['C', 'D', 'H', 'S'] as Suit[]) for (let rank = 2; rank <= 14; rank += 1) deck.push({ suit, rank });
    for (let index = deck.length - 1; index > 0; index -= 1) {
      const swap = randomInt(index + 1);
      [deck[index], deck[swap]] = [deck[swap], deck[index]];
    }
    return deck;
  }
}

export class HeartsEngine extends TrickTakingEngine {
  readonly id: GameId = 'hearts';
  protected readonly targetScore = 100;
  protected readonly lowScoreWins = true;
  protected scoreTrick(trick: Array<{ player: number; card: PlayingCard }>): number { return trick.reduce((sum, item) => sum + (item.card.suit === 'H' ? 1 : item.card.suit === 'S' && item.card.rank === 12 ? 13 : 0), 0); }
  protected winningPlayer(trick: Array<{ player: number; card: PlayingCard }>, lead: Suit): number { return trick.filter((item) => item.card.suit === lead).sort((a, b) => b.card.rank - a.card.rank)[0].player; }
}

export class SpadesEngine extends TrickTakingEngine {
  readonly id: GameId = 'spades';
  protected readonly targetScore = 500;
  protected scoreTrick(_trick: Array<{ player: number; card: PlayingCard }>): number { return 1; }
  protected winningPlayer(trick: Array<{ player: number; card: PlayingCard }>, lead: Suit): number {
    const spades = trick.filter((item) => item.card.suit === 'S');
    const pool = spades.length ? spades : trick.filter((item) => item.card.suit === lead);
    return pool.sort((a, b) => b.card.rank - a.card.rank)[0].player;
  }
}
