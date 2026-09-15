enum AppLocale { en, fa }
enum ThemeChoice { light, dark, system }

enum GameCategory { board, cards, arcade, party, sports }

class UserProfile {
  const UserProfile({required this.id, required this.username, required this.displayName, this.phone, this.email, this.avatarUrl, required this.locale, required this.theme, required this.role, required this.level, required this.experience, required this.coins, required this.pips});
  final String id;
  final String username;
  final String displayName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final AppLocale locale;
  final ThemeChoice theme;
  final String role;
  final int level;
  final int experience;
  final int coins;
  final int pips;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    username: json['username'] as String? ?? 'player',
    displayName: json['displayName'] as String? ?? 'Vibe Player',
    phone: json['phone'] as String?, email: json['email'] as String?, avatarUrl: json['avatarUrl'] as String?,
    locale: json['locale'] == 'fa' ? AppLocale.fa : AppLocale.en,
    theme: switch (json['theme']) { 'dark' => ThemeChoice.dark, 'light' => ThemeChoice.light, _ => ThemeChoice.system },
    role: json['role'] as String? ?? 'player', level: (json['level'] as num?)?.toInt() ?? 1,
    experience: (json['experience'] as num?)?.toInt() ?? 0, coins: (json['coins'] as num?)?.toInt() ?? 0, pips: (json['pips'] as num?)?.toInt() ?? 0,
  );
}

class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.expiresAt, required this.user});
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final UserProfile user;
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String, expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ?? DateTime.now().add(const Duration(minutes: 15)), user: UserProfile.fromJson(json['user'] as Map<String, dynamic>));
}

class GameDescriptor {
  const GameDescriptor({required this.id, required this.name, required this.category, required this.minPlayers, required this.maxPlayers, required this.supportsTeams, required this.accent, required this.icon});
  final String id;
  final String name;
  final GameCategory category;
  final int minPlayers;
  final int maxPlayers;
  final bool supportsTeams;
  final String accent;
  final String icon;
  factory GameDescriptor.fromJson(Map<String, dynamic> json) => GameDescriptor(id: json['id'] as String, name: json['name'] as String, category: _category(json['category'] as String?), minPlayers: (json['minPlayers'] as num).toInt(), maxPlayers: (json['maxPlayers'] as num).toInt(), supportsTeams: json['supportsTeams'] as bool? ?? false, accent: json['accent'] as String? ?? '#7C5CFC', icon: json['icon'] as String? ?? 'casino');
  static GameCategory _category(String? value) => switch (value) { 'board' => GameCategory.board, 'cards' => GameCategory.cards, 'arcade' => GameCategory.arcade, 'sports' => GameCategory.sports, _ => GameCategory.party };
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.priceCoins,
    required this.pricePips,
    required this.assetKey,
    required this.isGiftable,
    this.isLimited = false,
    this.stock,
  });
  final String id;
  final String name;
  final String description;
  final String category;
  final int priceCoins;
  final int pricePips;
  final String assetKey;
  final bool isGiftable;
  final bool isLimited;
  final int? stock;

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? 'bundle',
    priceCoins: (json['priceCoins'] as num?)?.toInt() ?? 0,
    pricePips: (json['pricePips'] as num?)?.toInt() ?? 0,
    assetKey: json['assetKey'] as String? ?? 'bundle',
    isGiftable: _bool(json['isGiftable'], fallback: true),
    isLimited: _bool(json['isLimited'], fallback: false),
    stock: (json['stock'] as num?)?.toInt(),
  );

  static bool _bool(dynamic value, {bool fallback = false}) =>
      value is bool ? value : value is num ? value != 0 : value is String ? value == '1' || value.toLowerCase() == 'true' : fallback;
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.itemId,
    required this.sku,
    required this.name,
    required this.description,
    required this.category,
    required this.assetKey,
    required this.quantity,
    required this.equipped,
    this.isGiftable = true,
    this.acquiredAt,
    this.expiresAt,
  });
  final String id;
  final String itemId;
  final String sku;
  final String name;
  final String description;
  final String category;
  final String assetKey;
  final int quantity;
  final bool equipped;
  final bool isGiftable;
  final DateTime? acquiredAt;
  final DateTime? expiresAt;

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String? ?? '',
    itemId: json['itemId'] as String? ?? json['shop_item_id'] as String? ?? '',
    sku: json['sku'] as String? ?? '',
    name: json['name'] as String? ?? 'Item',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? 'bundle',
    assetKey: json['assetKey'] as String? ?? json['asset_key'] as String? ?? 'bundle',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    equipped: json['equipped'] == true || json['equipped'] == 1,
    isGiftable: ShopItem._bool(json['isGiftable'], fallback: true),
    acquiredAt: json['acquiredAt'] != null ? DateTime.tryParse(json['acquiredAt'].toString()) : null,
    expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'].toString()) : null,
  );
}

class GiftHistoryEntry {
  const GiftHistoryEntry({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    required this.itemId,
    required this.itemName,
    required this.category,
    required this.assetKey,
    required this.quantity,
    this.note,
    this.createdAt,
    required this.isReceived,
  });
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final String itemId;
  final String itemName;
  final String category;
  final String assetKey;
  final int quantity;
  final String? note;
  final DateTime? createdAt;
  final bool isReceived;

  factory GiftHistoryEntry.fromJson(Map<String, dynamic> json, {required bool isReceived}) => GiftHistoryEntry(
    id: json['id'] as String? ?? '',
    otherUserId: (isReceived ? json['senderId'] : json['recipientId']) as String? ?? '',
    otherUserName: (isReceived ? json['senderName'] : json['recipientName']) as String? ?? 'Friend',
    otherUserAvatarUrl: (isReceived ? json['senderAvatarUrl'] : json['recipientAvatarUrl']) as String?,
    itemId: json['itemId'] as String? ?? '',
    itemName: json['itemName'] as String? ?? 'Item',
    category: json['category'] as String? ?? 'bundle',
    assetKey: json['assetKey'] as String? ?? 'bundle',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    note: json['note'] as String?,
    createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    isReceived: isReceived,
  );
}

class MatchModel {
  const MatchModel({required this.id, required this.gameId, required this.status, required this.revision, required this.viewerSeat, required this.state, required this.players, required this.winnerIds, required this.draw, this.conversationId, this.reward, this.turnSeconds = 0, this.turnDeadline, this.serverTime});
  final String id; final String gameId; final String status; final int revision; final int viewerSeat; final Map<String, dynamic> state; final List<Map<String, dynamic>> players; final List<String> winnerIds; final bool draw; final String? conversationId; final Map<String, dynamic>? reward; final int turnSeconds; final String? turnDeadline; final String? serverTime;
  factory MatchModel.fromJson(Map<String, dynamic> json) => MatchModel(id: json['id'] as String, gameId: json['gameId'] as String, status: json['status'] as String? ?? 'active', revision: (json['revision'] as num?)?.toInt() ?? 0, viewerSeat: (json['viewerSeat'] as num?)?.toInt() ?? 0, state: Map<String, dynamic>.from(json['state'] as Map? ?? const {}), players: (json['players'] as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList(), winnerIds: (json['winnerIds'] as List? ?? const []).map((item) => item.toString()).toList(), draw: json['draw'] is bool ? json['draw'] as bool : json['draw'] == 1, conversationId: json['conversationId'] as String?, reward: json['reward'] is Map ? Map<String, dynamic>.from(json['reward'] as Map) : null, turnSeconds: (json['turnSeconds'] as num?)?.toInt() ?? 0, turnDeadline: json['turnDeadline'] as String?, serverTime: json['serverTime'] as String?);
}

class FriendEntry {
  const FriendEntry({required this.id, required this.friendshipId, required this.displayName, required this.username, required this.status, required this.isOnline, required this.isRequester});
  final String id; final String friendshipId; final String displayName; final String username; final String status; final bool isOnline; final bool isRequester;
  factory FriendEntry.fromJson(Map<String, dynamic> json) => FriendEntry(id: json['userId'] as String, friendshipId: json['friendshipId'] as String? ?? '', displayName: json['displayName'] as String? ?? 'Player', username: json['username'] as String? ?? 'player', status: json['status'] as String? ?? 'pending', isOnline: json['isOnline'] as bool? ?? false, isRequester: json['isRequester'] as bool? ?? false);
}

/// Game ids with a real mobile board: a dedicated board widget (game_room
/// dispatch) or a functional inline UI (memory_race, word_chain).
/// Anything missing here falls back to the Coming Soon card in the game room,
/// and is flagged in the Admin Panel so it can be disabled.
const kGamesWithMobileBoard = <String>{
  'ocho',
  'pool_8_ball',
  'ludo',
  'werewolf',
  'chess',
  'four_in_a_row',
  'carrom',
  'bingo',
  'dominoes',
  'backgammon',
  'checkers',
  'mini_golf',
  'table_soccer',
  'sea_battle',
  'mancala',
  'hearts',
  'spades',
  'sketch_guess',
  'trivia_battle',
  'memory_race',
  'word_chain',
  'dice_party',
  'bowling',
  'darts',
  'emoji_charades',
  'impostor_light',
  'archery',
  'quick_challenges',
};

bool gameHasMobileBoard(String id) => kGamesWithMobileBoard.contains(id);
