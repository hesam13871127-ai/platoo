export const GAME_IDS = [
  'ocho', 'pool_8_ball', 'ludo', 'werewolf', 'chess', 'four_in_a_row',
  'dice_party', 'carrom', 'bingo', 'dominoes', 'backgammon', 'checkers',
  'mini_golf', 'table_soccer', 'archery', 'bowling', 'darts', 'sea_battle',
  'mancala', 'hearts', 'spades', 'sketch_guess', 'trivia_battle',
  'emoji_charades', 'word_chain', 'memory_race', 'impostor_light', 'quick_challenges',
] as const;

export type GameId = (typeof GAME_IDS)[number];
export type GameMode = 'casual' | 'ranked' | 'private';
export type Locale = 'en' | 'fa';
export type ThemeMode = 'light' | 'dark' | 'system';

export interface UserSummary {
  id: string;
  displayName: string;
  avatarUrl: string | null;
  level: number;
  isOnline: boolean;
}

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
  user: UserSummary & { phone: string | null; email: string | null; coins: number; pips: number };
}

export interface GameDescriptor {
  id: GameId;
  name: string;
  category: 'board' | 'cards' | 'arcade' | 'party' | 'sports';
  minPlayers: number;
  maxPlayers: number;
  supportsTeams: boolean;
  accent: string;
  icon: string;
}

export interface MatchTicket {
  id: string;
  gameId: GameId;
  mode: GameMode;
  playerCount: number;
  rating: number;
  queuedAt: string;
}

export interface MatchFound {
  matchId: string;
  gameId: GameId;
  mode: GameMode;
  players: UserSummary[];
  bot: boolean;
  reconnectUntil: string;
}

export interface GameState<T = Record<string, unknown>> {
  matchId: string;
  gameId: GameId;
  status: 'waiting' | 'active' | 'finished' | 'cancelled';
  turn: string | null;
  revision: number;
  state: T;
  winners: string[];
  loserIds: string[];
  draw: boolean;
  updatedAt: string;
}

export interface ChatMessage {
  id: string;
  conversationId: string;
  sender: UserSummary;
  body: string;
  createdAt: string;
  kind: 'text' | 'system' | 'gift';
  giftItemId?: string;
}

export interface WalletBalance { coins: number; pips: number; }

export interface ShopItem {
  id: string;
  sku: string;
  name: string;
  description: string;
  category: 'avatar' | 'frame' | 'emote' | 'table' | 'dice' | 'bundle';
  priceCoins: number;
  pricePips: number;
  assetKey: string;
  isLimited: boolean;
  isGiftable?: boolean;
  stock?: number | null;
}

export interface InventoryItem {
  id: string;
  itemId: string;
  sku: string;
  name: string;
  description: string;
  category: string;
  assetKey: string;
  quantity: number;
  equipped: boolean;
  isGiftable?: boolean;
  acquiredAt?: string;
  expiresAt?: string;
}

export interface LeaderboardEntry extends UserSummary {
  rating: number;
  wins: number;
  losses: number;
  rank: number;
}

export interface ApiError { code: string; message: string; details?: Record<string, unknown>; }
