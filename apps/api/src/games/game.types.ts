export type GameId = 'ocho' | 'pool_8_ball' | 'ludo' | 'werewolf' | 'chess' | 'four_in_a_row' | 'dice_party' | 'carrom' | 'bingo' | 'dominoes' | 'backgammon' | 'checkers' | 'mini_golf' | 'table_soccer' | 'archery' | 'bowling' | 'darts' | 'sea_battle' | 'mancala' | 'hearts' | 'spades' | 'sketch_guess' | 'trivia_battle' | 'emoji_charades' | 'word_chain' | 'memory_race' | 'impostor_light' | 'quick_challenges';

export interface GamePlayer { id: string; isBot: boolean; seat: number; team?: number; }
export interface Action { type: string; [key: string]: unknown; }
export interface GameState { [key: string]: unknown; }
export interface GameOutcome { finished: boolean; winnerIds: string[]; loserIds: string[]; draw: boolean; }
export interface GameEngine {
  readonly id: GameId;
  create(players: GamePlayer[]): GameState;
  validate(state: GameState, actorId: string, action: Action, players: GamePlayer[]): void;
  apply(state: GameState, actorId: string, action: Action, players: GamePlayer[]): GameState;
  outcome(state: GameState, players: GamePlayer[]): GameOutcome;
  botAction(state: GameState, botId: string, players: GamePlayer[]): Action;
}

export class IllegalMoveError extends Error {
  constructor(message: string) { super(message); this.name = 'IllegalMoveError'; }
}

export const asString = (value: unknown, name: string): string => {
  if (typeof value !== 'string' || !value) throw new IllegalMoveError(`${name} must be a non-empty string.`);
  return value;
};
export const asInt = (value: unknown, name: string, min: number, max: number): number => {
  if (!Number.isInteger(value) || (value as number) < min || (value as number) > max) throw new IllegalMoveError(`${name} must be an integer from ${min} to ${max}.`);
  return value as number;
};
export const nextTurn = (state: GameState, players: GamePlayer[], step = 1): string => {
  const index = Number(state.turnIndex ?? 0);
  const next = (index + step + players.length * 10) % players.length;
  return players[next].id;
};
export const rotateTurn = (state: GameState, players: GamePlayer[], step = 1): void => {
  const index = (Number(state.turnIndex ?? 0) + step + players.length * 10) % players.length;
  state.turnIndex = index;
  state.turnPlayerId = players[index].id;
};
export const randomInt = (max: number): number => Math.floor(Math.random() * max);
export const clone = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;
