int _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

/// A coin pack from GET /iap/products. The server owns this catalog: prices shown here
/// are a display hint only, and the store sheet always shows the authoritative price.
class CoinPack {
  const CoinPack({
    required this.id,
    required this.sku,
    required this.storeProductId,
    required this.provider,
    required this.coins,
    required this.bonusCoins,
    required this.totalCoins,
    required this.priceMicros,
    required this.currency,
  });

  final String id;
  final String sku;
  final String storeProductId;
  final String provider;
  final int coins;
  final int bonusCoins;
  final int totalCoins;
  final int priceMicros;
  final String currency;

  factory CoinPack.fromJson(Map<String, dynamic> json) => CoinPack(
        id: json['id']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        storeProductId: json['storeProductId']?.toString() ?? '',
        provider: json['provider']?.toString() ?? '',
        coins: _asInt(json['coins']),
        bonusCoins: _asInt(json['bonusCoins']),
        totalCoins: _asInt(json['totalCoins']),
        priceMicros: _asInt(json['priceMicros']),
        currency: json['currency']?.toString() ?? 'USD',
      );

  bool get hasBonus => bonusCoins > 0;

  String get displayPrice {
    if (priceMicros <= 0) return '';
    final major = priceMicros / 1000000;
    final amount = major.truncateToDouble() == major ? major.toStringAsFixed(0) : major.toStringAsFixed(2);
    return currency == 'USD' ? '\$$amount' : '$amount $currency';
  }
}

/// The result of POST /iap/verify. [replayed] is true when this store transaction was
/// already credited before (safe to treat exactly like a fresh credit).
class IapPurchaseResult {
  const IapPurchaseResult({
    required this.success,
    required this.credited,
    required this.replayed,
    required this.coins,
    required this.balanceCoins,
  });

  final bool success;
  final bool credited;
  final bool replayed;
  final int coins;
  final int balanceCoins;

  factory IapPurchaseResult.fromJson(Map<String, dynamic> json) {
    final balance = json['balance'];
    return IapPurchaseResult(
      success: json['success'] == true,
      credited: json['credited'] == true,
      replayed: json['replayed'] == true,
      coins: _asInt(json['coins']),
      balanceCoins: balance is Map ? _asInt(balance['coins']) : 0,
    );
  }
}
