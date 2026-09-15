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

bool _flag(dynamic value, {bool fallback = false}) => value is bool ? value : value is num ? value != 0 : value is String ? value == '1' || value.toLowerCase() == 'true' : fallback;
int _count(dynamic value, [int fallback = 0]) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;

/// One row of `GET /shop/items`. Besides the catalog fields it carries the
/// signed-in player's state for that item (owned / equipped), so a card can
/// decide between Buy, Equip and "already yours" without a second request.
class ShopItem {
  const ShopItem({required this.id, required this.name, required this.description, required this.category, required this.priceCoins, required this.pricePips, required this.assetKey, required this.isGiftable, this.isLimited = false, this.stock, this.owned = false, this.ownedQuantity = 0, this.equipped = false, this.equippable = true, this.bundle, this.endsAt});
  final String id; final String name; final String description; final String category; final int priceCoins; final int pricePips; final String assetKey; final bool isGiftable;
  final bool isLimited; final int? stock; final bool owned; final int ownedQuantity; final bool equipped; final bool equippable; final BundleContents? bundle; final String? endsAt;

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'bundle',
        priceCoins: _count(json['priceCoins']),
        pricePips: _count(json['pricePips']),
        assetKey: json['assetKey'] as String? ?? 'bundle',
        isGiftable: _flag(json['isGiftable'], fallback: true),
        isLimited: _flag(json['isLimited']),
        stock: json['stock'] is num ? (json['stock'] as num).toInt() : null,
        owned: _flag(json['owned']) || _count(json['ownedQuantity']) > 0,
        ownedQuantity: _count(json['ownedQuantity']),
        equipped: _flag(json['equipped']),
        equippable: _flag(json['equippable'], fallback: json['category'] != 'bundle'),
        bundle: json['bundle'] is Map ? BundleContents.fromJson(Map<String, dynamic>.from(json['bundle'] as Map)) : null,
        endsAt: json['endsAt'] as String?,
      );

  /// Inventory rows carry the same visuals but no price: this rebuilds a card
  /// for an item the player already owns (season rewards included).
  factory ShopItem.fromInventory(InventoryEntry entry) => ShopItem(
        id: entry.itemId,
        name: entry.name,
        description: entry.description,
        category: entry.category,
        priceCoins: 0,
        pricePips: 0,
        assetKey: entry.assetKey,
        isGiftable: entry.isGiftable,
        owned: true,
        ownedQuantity: entry.quantity,
        equipped: entry.equipped,
        equippable: entry.equippable,
      );

  bool get paysWithPips => pricePips > 0 && priceCoins <= 0;
  int get price => paysWithPips ? pricePips : priceCoins;
  bool get hasPrice => price > 0;
  int? get stockLeft => stock == null ? null : (stock! < 0 ? 0 : stock!);
  bool get soldOut => stockLeft == 0;
  bool get isContainer => category == 'bundle' || !equippable;
}

/// What a bundle hands over on purchase (server-side `metadata.grants`).
class BundleContents {
  const BundleContents({this.coins = 0, this.pips = 0, this.items = const []});
  final int coins; final int pips; final List<BundleContent> items;
  bool get isEmpty => coins <= 0 && pips <= 0 && items.isEmpty;
  factory BundleContents.fromJson(Map<String, dynamic> json) => BundleContents(
        coins: _count(json['coins']),
        pips: _count(json['pips']),
        items: (json['items'] as List? ?? const []).whereType<Map>().map((item) => BundleContent.fromJson(Map<String, dynamic>.from(item))).toList(),
      );
}

class BundleContent {
  const BundleContent({required this.id, required this.name, required this.category, required this.assetKey, this.quantity = 1});
  final String id; final String name; final String category; final String assetKey; final int quantity;
  factory BundleContent.fromJson(Map<String, dynamic> json) => BundleContent(id: json['id']?.toString() ?? '', name: json['name']?.toString() ?? 'Item', category: json['category']?.toString() ?? 'bundle', assetKey: json['assetKey']?.toString() ?? '', quantity: _count(json['quantity'], 1));
}

/// One owned row of `GET /shop/inventory`.
class InventoryEntry {
  const InventoryEntry({required this.id, required this.itemId, required this.name, required this.description, required this.category, required this.assetKey, required this.quantity, required this.equipped, required this.isGiftable, required this.equippable, this.acquiredAt, this.expiresAt});
  final String id; final String itemId; final String name; final String description; final String category; final String assetKey;
  final int quantity; final bool equipped; final bool isGiftable; final bool equippable; final String? acquiredAt; final String? expiresAt;
  factory InventoryEntry.fromJson(Map<String, dynamic> json) => InventoryEntry(
        id: json['id']?.toString() ?? json['itemId']?.toString() ?? '',
        itemId: json['itemId']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Item',
        description: json['description']?.toString() ?? '',
        category: json['category']?.toString() ?? 'bundle',
        assetKey: json['assetKey']?.toString() ?? '',
        quantity: _count(json['quantity'], 1),
        equipped: _flag(json['equipped']),
        isGiftable: _flag(json['isGiftable'], fallback: true),
        equippable: _flag(json['equippable'], fallback: json['category'] != 'bundle'),
        acquiredAt: json['acquiredAt']?.toString(),
        expiresAt: json['expiresAt']?.toString(),
      );
  ShopItem toShopItem() => ShopItem.fromInventory(this);
}

/// A row of `GET /shop/gifts` (either direction) so gift history can be shown
/// next to the inventory instead of being invisible after it is sent.
class GiftEntry {
  const GiftEntry({required this.id, required this.itemName, required this.category, required this.assetKey, required this.quantity, required this.direction, required this.counterpartName, this.counterpartId = '', this.note, this.createdAt});
  final String id; final String itemName; final String category; final String assetKey; final int quantity; final String direction; final String counterpartName; final String counterpartId; final String? note; final String? createdAt;
  bool get received => direction == 'received';
  factory GiftEntry.fromJson(Map<String, dynamic> json) => GiftEntry(
        id: json['id']?.toString() ?? '',
        itemName: json['itemName']?.toString() ?? 'Item',
        category: json['category']?.toString() ?? 'bundle',
        assetKey: json['assetKey']?.toString() ?? '',
        quantity: _count(json['quantity'], 1),
        direction: json['direction']?.toString() ?? 'sent',
        counterpartName: json['counterpartName']?.toString() ?? 'Player',
        counterpartId: json['counterpartId']?.toString() ?? '',
        note: json['note']?.toString(),
        createdAt: json['createdAt']?.toString(),
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
