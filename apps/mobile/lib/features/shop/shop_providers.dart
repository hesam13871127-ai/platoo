import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/models.dart';

/// Everything the Shop screens read. All three endpoints are user-aware: the
/// catalog comes back annotated with what the player owns, the inventory lists
/// the owned rows, and the gift history covers both directions.
final shopItemsProvider = FutureProvider<List<ShopItem>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/shop/items') as List;
  return data.map((item) => ShopItem.fromJson(Map<String, dynamic>.from(item as Map))).toList();
});

final inventoryProvider = FutureProvider<List<InventoryEntry>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/shop/inventory') as List;
  return data.map((item) => InventoryEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList();
});

final giftHistoryProvider = FutureProvider<List<GiftEntry>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/shop/gifts') as List;
  return data.map((item) => GiftEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList();
});

/// A purchase intent is born with one idempotency key and keeps it for every
/// retry, so "try again" after a timeout can never charge the player twice.
String newPurchaseKey(String itemId) => 'shop-$itemId-${DateTime.now().microsecondsSinceEpoch}';

int _int(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Result of POST /shop/purchase. [grantedItems] and [grantedCoins] are only
/// filled for bundles, which unpack their contents into the inventory instantly.
class ShopPurchaseResult {
  const ShopPurchaseResult({required this.success, required this.replayed, required this.balanceCoins, this.balancePips = 0, this.grantedCoins = 0, this.grantedPips = 0, this.grantedItems = const []});
  final bool success;
  final bool replayed;
  final int balanceCoins;
  final int balancePips;
  final int grantedCoins;
  final int grantedPips;
  final List<BundleContent> grantedItems;

  factory ShopPurchaseResult.fromJson(Map<String, dynamic> json) {
    final balance = json['balance'];
    final granted = json['granted'];
    final grantedMap = granted is Map ? Map<String, dynamic>.from(granted) : const <String, dynamic>{};
    return ShopPurchaseResult(
      success: json['success'] == true,
      replayed: json['replayed'] == true,
      balanceCoins: balance is Map ? _int(balance['coins']) : 0,
      balancePips: balance is Map ? _int(balance['pips']) : 0,
      grantedCoins: _int(grantedMap['coins']),
      grantedPips: _int(grantedMap['pips']),
      grantedItems: (grantedMap['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => BundleContent.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

/// Result of POST /shop/gift.
class ShopGiftResult {
  const ShopGiftResult({required this.itemName, required this.quantity, required this.recipientName, this.pendingPurchase = false});
  final String itemName;
  final int quantity;
  final String recipientName;
  /// True when the sender had to buy the item on the way to the gift.
  final bool pendingPurchase;
}

/// Shop writes live here, on a container-scoped ref: a sheet may be dismissed
/// mid-request without turning the following provider refreshes into errors.
class ShopController {
  ShopController(this._ref);
  final Ref _ref;

  Future<ShopPurchaseResult> purchase({required String itemId, required String idempotencyKey}) async {
    final data = await _ref.read(apiClientProvider).post('/shop/purchase', data: {'itemId': itemId, 'idempotencyKey': idempotencyKey}) as Map;
    final result = ShopPurchaseResult.fromJson(Map<String, dynamic>.from(data));
    await _refresh(profile: true, inventory: true, catalog: true);
    return result;
  }

  /// Buys an item for someone else, then immediately gifts it. The purchase is
  /// keyed, so a retry after a failed gift step never buys a second copy.
  Future<ShopGiftResult> buyAndGift({required String itemId, required String idempotencyKey, required String recipientId, required String recipientName, int quantity = 1, String? note}) async {
    await purchase(itemId: itemId, idempotencyKey: idempotencyKey);
    final sent = await sendGift(itemId: itemId, recipientId: recipientId, quantity: quantity, note: note);
    return ShopGiftResult(itemName: sent.itemName, quantity: sent.quantity, recipientName: recipientName, pendingPurchase: true);
  }

  Future<ShopGiftResult> sendGift({required String itemId, required String recipientId, int quantity = 1, String? note}) async {
    final data = await _ref.read(apiClientProvider).post('/shop/gift', data: {
      'recipientId': recipientId,
      'itemId': itemId,
      'quantity': quantity,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }) as Map;
    final json = Map<String, dynamic>.from(data);
    await _refresh(inventory: true, catalog: true, gifts: true);
    return ShopGiftResult(
      itemName: json['item']?.toString() ?? 'Item',
      quantity: _int(json['quantity'], quantity),
      recipientName: (json['recipient'] is Map ? Map<String, dynamic>.from(json['recipient'] as Map)['displayName'] : null)?.toString() ?? 'your friend',
    );
  }

  Future<void> setEquipped(String itemId, {bool equipped = true}) async {
    await _ref.read(apiClientProvider).put('/shop/equip', data: {'itemId': itemId, 'equipped': equipped});
    await _refresh(inventory: true, catalog: true);
  }

  Future<void> _refresh({bool profile = false, bool inventory = false, bool catalog = false, bool gifts = false}) async {
    if (profile) await _ref.read(authProvider.notifier).refreshProfile();
    if (inventory) _ref.invalidate(inventoryProvider);
    if (catalog) _ref.invalidate(shopItemsProvider);
    if (gifts) _ref.invalidate(giftHistoryProvider);
  }
}

final shopControllerProvider = Provider<ShopController>((ref) => ShopController(ref));

/// Live catalog lookup so a sheet keeps working from fresh data after a write.
ShopItem? shopItemById(WidgetRef ref, String itemId) {
  for (final item in ref.watch(shopItemsProvider).valueOrNull ?? const <ShopItem>[]) {
    if (item.id == itemId) return item;
  }
  return null;
}
