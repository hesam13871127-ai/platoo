import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../models/models.dart';

final localGameCatalog = <GameDescriptor>[
  const GameDescriptor(id: 'ocho', name: 'Ocho', category: GameCategory.cards, minPlayers: 2, maxPlayers: 4, supportsTeams: false, accent: '#7C5CFC', icon: 'style'),
  const GameDescriptor(id: 'pool_8_ball', name: 'Pool 8-ball', category: GameCategory.sports, minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#1C9B78', icon: 'sports_bar'),
  const GameDescriptor(id: 'ludo', name: 'Ludo', category: GameCategory.board, minPlayers: 2, maxPlayers: 4, supportsTeams: true, accent: '#F36B4B', icon: 'casino'),
  const GameDescriptor(id: 'werewolf', name: 'Werewolf', category: GameCategory.party, minPlayers: 5, maxPlayers: 12, supportsTeams: false, accent: '#8B5CF6', icon: 'nightlife'),
  const GameDescriptor(id: 'chess', name: 'Chess', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#C9894B', icon: 'grid_on'),
  const GameDescriptor(id: 'four_in_a_row', name: '4 in a Row', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#E94862', icon: 'view_week'),
  const GameDescriptor(id: 'dice_party', name: 'Dice Party', category: GameCategory.party, minPlayers: 2, maxPlayers: 6, supportsTeams: false, accent: '#F2A93B', icon: 'casino'),
  const GameDescriptor(id: 'carrom', name: 'Carrom', category: GameCategory.board, minPlayers: 2, maxPlayers: 4, supportsTeams: true, accent: '#BE8B58', icon: 'radio_button_checked'),
  const GameDescriptor(id: 'bingo', name: 'Bingo', category: GameCategory.party, minPlayers: 2, maxPlayers: 8, supportsTeams: false, accent: '#EC4899', icon: 'confirmation_num'),
  const GameDescriptor(id: 'dominoes', name: 'Dominoes', category: GameCategory.board, minPlayers: 2, maxPlayers: 4, supportsTeams: false, accent: '#6B7280', icon: 'view_module'),
  const GameDescriptor(id: 'backgammon', name: 'Backgammon', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#A9673B', icon: 'casino'),
  const GameDescriptor(id: 'checkers', name: 'Checkers', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#D946EF', icon: 'grid_4x4'),
  const GameDescriptor(id: 'mini_golf', name: 'Mini Golf', category: GameCategory.sports, minPlayers: 2, maxPlayers: 4, supportsTeams: false, accent: '#22A06B', icon: 'golf_course'),
  const GameDescriptor(id: 'table_soccer', name: 'Table Soccer', category: GameCategory.sports, minPlayers: 2, maxPlayers: 4, supportsTeams: true, accent: '#159A8C', icon: 'sports_soccer'),
  const GameDescriptor(id: 'archery', name: 'Archery', category: GameCategory.sports, minPlayers: 1, maxPlayers: 4, supportsTeams: false, accent: '#E76F51', icon: 'gps_fixed'),
  const GameDescriptor(id: 'bowling', name: 'Bowling', category: GameCategory.sports, minPlayers: 1, maxPlayers: 4, supportsTeams: false, accent: '#4F7CAC', icon: 'sports'),
  const GameDescriptor(id: 'darts', name: 'Darts', category: GameCategory.sports, minPlayers: 1, maxPlayers: 4, supportsTeams: false, accent: '#B7791F', icon: 'adjust'),
  const GameDescriptor(id: 'sea_battle', name: 'Sea Battle', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#1882A5', icon: 'directions_boat'),
  const GameDescriptor(id: 'mancala', name: 'Mancala', category: GameCategory.board, minPlayers: 2, maxPlayers: 2, supportsTeams: false, accent: '#B5651D', icon: 'circle'),
  const GameDescriptor(id: 'hearts', name: 'Hearts', category: GameCategory.cards, minPlayers: 3, maxPlayers: 4, supportsTeams: false, accent: '#E04F5F', icon: 'favorite'),
  const GameDescriptor(id: 'spades', name: 'Spades', category: GameCategory.cards, minPlayers: 4, maxPlayers: 4, supportsTeams: true, accent: '#334155', icon: 'style'),
  const GameDescriptor(id: 'sketch_guess', name: 'Sketch & Guess', category: GameCategory.party, minPlayers: 3, maxPlayers: 8, supportsTeams: false, accent: '#F59E0B', icon: 'brush'),
  const GameDescriptor(id: 'trivia_battle', name: 'Trivia Battle', category: GameCategory.party, minPlayers: 2, maxPlayers: 8, supportsTeams: false, accent: '#3B82F6', icon: 'quiz'),
  const GameDescriptor(id: 'emoji_charades', name: 'Emoji Charades', category: GameCategory.party, minPlayers: 3, maxPlayers: 8, supportsTeams: false, accent: '#F97316', icon: 'emoji_emotions'),
  const GameDescriptor(id: 'word_chain', name: 'Word Chain', category: GameCategory.party, minPlayers: 2, maxPlayers: 8, supportsTeams: false, accent: '#10B981', icon: 'translate'),
  const GameDescriptor(id: 'memory_race', name: 'Memory Race', category: GameCategory.party, minPlayers: 2, maxPlayers: 6, supportsTeams: false, accent: '#8B5CF6', icon: 'memory'),
  const GameDescriptor(id: 'impostor_light', name: 'Impostor Light', category: GameCategory.party, minPlayers: 4, maxPlayers: 10, supportsTeams: false, accent: '#DC2626', icon: 'visibility_off'),
  const GameDescriptor(id: 'quick_challenges', name: 'Quick Challenges', category: GameCategory.arcade, minPlayers: 1, maxPlayers: 6, supportsTeams: false, accent: '#EAB308', icon: 'bolt'),
];

final gamesProvider = FutureProvider<List<GameDescriptor>>((ref) async { try { final data = await ref.watch(apiClientProvider).get('/games') as List; return data.map((item) => GameDescriptor.fromJson(Map<String, dynamic>.from(item as Map))).toList(); } catch (_) { return localGameCatalog; } });
