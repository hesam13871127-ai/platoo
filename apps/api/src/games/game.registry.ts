import { Injectable } from '@nestjs/common';
import { GameEngine, GameId, GameState } from './game.types';
import { OchoEngine, HeartsEngine, SpadesEngine } from './engines/cards.engine';
import { FourInARowEngine, ChessEngine, CheckersEngine, MancalaEngine } from './engines/board.engine';
import { LudoEngine, DominoesEngine, BackgammonEngine, SeaBattleEngine, PoolEngine, CarromEngine } from './engines/tabletop.engine';
import { DicePartyEngine, BingoEngine, WerewolfEngine, WordChainEngine, MemoryRaceEngine, ImpostorLightEngine, SketchGuessEngine, TriviaBattleEngine, QuickChallengesEngine, EmojiCharadesEngine } from './engines/party.engine';
import { ArcheryEngine, BowlingEngine, DartsEngine, MiniGolfEngine, TableSoccerEngine } from './engines/sport.engine';
import { GameDescriptor } from '@vibetable/contracts';

export const CORE_GAME_IDS = [
  'ocho',
  'pool_8_ball',
  'ludo',
  'chess',
  'four_in_a_row',
  'dominoes',
  'carrom',
  'backgammon',
  'checkers',
  'werewolf',
] as const satisfies readonly GameId[];

export const CORE_GAME_ID_SET = new Set<GameId>(CORE_GAME_IDS);

export const isCoreGame = (id: string): id is GameId => CORE_GAME_ID_SET.has(id as GameId);

export const GAME_DESCRIPTORS: GameDescriptor[] = [
  { id: 'ocho', name: 'Ocho', category: 'cards', minPlayers: 2, maxPlayers: 4, supportsTeams: false, accent: '#7C5CFC', icon: 'style' },
  { id: 'pool_8_ball', name: 'Pool 8-ball', category: 'sports', minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#1C9B78', icon: 'sports_bar' },
  { id: 'ludo', name: 'Ludo', category: 'board', minPlayers: 2, maxPlayers: 4, supportsTeams: true, accent: '#F36B4B', icon: 'casino' },
  { id: 'werewolf', name: 'Werewolf', category: 'party', minPlayers: 5, maxPlayers: 12, supportsTeams: false, accent: '#8B5CF6', icon: 'nightlife' },
  { id: 'chess', name: 'Chess', category: 'board', minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#C9894B', icon: 'grid_on' },
  { id: 'four_in_a_row', name: '4 in a Row', category: 'board', minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#E94862', icon: 'view_week' },
  { id: 'dice_party', name: 'Dice Party', category: 'party', minPlayers: 2, maxPlayers: 6, supportsTeams: false, accent: '#F2A93B', icon: 'casino' },
  { id: 'carrom', name: 'Carrom', category: 'board', minPlayers: 2, maxPlayers: 4, supportsTeams: true, accent: '#BE8B58', icon: 'radio_button_checked' },
  { id: 'bingo', name: 'Bingo', category: 'party', minPlayers: 2, maxPlayers: 8, supportsTeams: false, accent: '#EC4899', icon: 'confirmation_num' },
  { id: 'dominoes', name: 'Dominoes', category: 'board', minPlayers: 2, maxPlayers: 4, supportsTeams: false, accent: '#6B7280', icon: 'view_module' },
  { id: 'backgammon', name: 'Backgammon', category: 'board', minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#A9673B', icon: 'casino' },
  { id: 'checkers', name: 'Checkers', category: 'board', minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#D946EF', icon: 'grid_4x4' },
  { id: 'mini_golf', name: 'Mini Golf', category: 'sports', minPlayers: 2, maxPlayers: 4, supportsTeams: false, accent: '#22A06B', icon: 'golf_course' },
  { id: 'table_soccer', name: 'Table Soccer', category: 'sports', minPlayers: 2, maxPlayers: 4, supportsTeams: true, accent: '#159A8C', icon: 'sports_soccer' },
  { id: 'archery', name: 'Archery', category: 'sports', minPlayers: 1, maxPlayers: 4, supportsTeams: false, accent: '#E76F51', icon: 'gps_fixed' },
  { id: 'bowling', name: 'Bowling', category: 'sports', minPlayers: 1, maxPlayers: 4, supportsTeams: false, accent: '#4F7CAC', icon: 'sports' },
  { id: 'darts', name: 'Darts', category: 'sports', minPlayers: 1, maxPlayers: 4, supportsTeams: false, accent: '#B7791F', icon: 'adjust' },
  { id: 'sea_battle', name: 'Sea Battle', category: 'board', minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#1882A5', icon: 'directions_boat' },
  { id: 'mancala', name: 'Mancala', category: 'board', minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#B5651D', icon: 'circle' },
  { id: 'hearts', name: 'Hearts', category: 'cards', minPlayers: 3, maxPlayers: 4, supportsTeams: false, accent: '#E04F5F', icon: 'favorite' },
  { id: 'spades', name: 'Spades', category: 'cards', minPlayers: 4, maxPlayers: 4, supportsTeams: true, accent: '#334155', icon: 'style' },
  { id: 'sketch_guess', name: 'Sketch & Guess', category: 'party', minPlayers: 3, maxPlayers: 8, supportsTeams: false, accent: '#F59E0B', icon: 'brush' },
  { id: 'trivia_battle', name: 'Trivia Battle', category: 'party', minPlayers: 2, maxPlayers: 8, supportsTeams: false, accent: '#3B82F6', icon: 'quiz' },
  { id: 'emoji_charades', name: 'Emoji Charades', category: 'party', minPlayers: 3, maxPlayers: 8, supportsTeams: false, accent: '#F97316', icon: 'emoji_emotions' },
  { id: 'word_chain', name: 'Word Chain', category: 'party', minPlayers: 2, maxPlayers: 8, supportsTeams: false, accent: '#10B981', icon: 'translate' },
  { id: 'memory_race', name: 'Memory Race', category: 'party', minPlayers: 2, maxPlayers: 6, supportsTeams: false, accent: '#8B5CF6', icon: 'memory' },
  { id: 'impostor_light', name: 'Impostor Light', category: 'party', minPlayers: 4, maxPlayers: 10, supportsTeams: false, accent: '#DC2626', icon: 'visibility_off' },
  { id: 'quick_challenges', name: 'Quick Challenges', category: 'arcade', minPlayers: 1, maxPlayers: 6, supportsTeams: false, accent: '#EAB308', icon: 'bolt' },
];

const TURN_SECONDS: Partial<Record<GameId, number>> = {
  four_in_a_row: 30, dice_party: 30, archery: 30, darts: 30, bowling: 30, memory_race: 30,
  word_chain: 30, trivia_battle: 30, emoji_charades: 30, quick_challenges: 30,
  ludo: 45, mancala: 45, dominoes: 45, mini_golf: 45, hearts: 45, spades: 45,
  ocho: 60, pool_8_ball: 60, carrom: 60, bingo: 60, backgammon: 60, checkers: 60,
  sea_battle: 60, table_soccer: 60, impostor_light: 60,
  werewolf: 90, sketch_guess: 90,
  chess: 180,
};

const DEFAULT_TURN_SECONDS = 60;

@Injectable()
export class GameRegistry {
  private readonly engines = new Map<GameId, GameEngine>([
    ['ocho', new OchoEngine()], ['pool_8_ball', new PoolEngine()], ['ludo', new LudoEngine()], ['werewolf', new WerewolfEngine()], ['chess', new ChessEngine()], ['four_in_a_row', new FourInARowEngine()], ['dice_party', new DicePartyEngine()], ['carrom', new CarromEngine()], ['bingo', new BingoEngine()], ['dominoes', new DominoesEngine()], ['backgammon', new BackgammonEngine()], ['checkers', new CheckersEngine()], ['mini_golf', new MiniGolfEngine()], ['table_soccer', new TableSoccerEngine()], ['archery', new ArcheryEngine()], ['bowling', new BowlingEngine()], ['darts', new DartsEngine()], ['sea_battle', new SeaBattleEngine()], ['mancala', new MancalaEngine()], ['hearts', new HeartsEngine()], ['spades', new SpadesEngine()], ['sketch_guess', new SketchGuessEngine()], ['trivia_battle', new TriviaBattleEngine()], ['emoji_charades', new EmojiCharadesEngine()], ['word_chain', new WordChainEngine()], ['memory_race', new MemoryRaceEngine()], ['impostor_light', new ImpostorLightEngine()], ['quick_challenges', new QuickChallengesEngine()],
  ]);
  list(): GameDescriptor[] { return GAME_DESCRIPTORS; }
  descriptor(id: string): GameDescriptor { const descriptor = GAME_DESCRIPTORS.find((game) => game.id === id); if (!descriptor) throw new Error(`Unsupported game: ${id}`); return descriptor; }
  engine(id: string): GameEngine { const engine = this.engines.get(id as GameId); if (!engine) throw new Error(`Unsupported game: ${id}`); return engine; }
  turnSeconds(id: string, state?: GameState): number {
    // Sketch & Guess guessing rounds are quick, but the drawer submits a whole
    // sketch in one action and needs a longer clock.
    if (id === 'sketch_guess' && state) return state.phase === 'drawing' ? 120 : 30;
    return TURN_SECONDS[id as GameId] ?? DEFAULT_TURN_SECONDS;
  }
}
