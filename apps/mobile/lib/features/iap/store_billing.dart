import 'dart:convert';
import 'dart:io' show Platform;

import 'iap_models.dart';

/// A purchase the on-device store reports as completed, ready for server verification.
class StorePurchase {
  const StorePurchase({
    required this.provider,
    required this.storeProductId,
    required this.transactionId,
    required this.receipt,
  });

  /// 'apple' or 'google'.
  final String provider;

  /// The store product id that was bought (must exist in the server catalog).
  final String storeProductId;

  /// StoreKit transaction id / Play order id. Globally unique per payment.
  final String transactionId;

  /// StoreKit 2 JWS transaction (or StoreKit 1 receipt blob) / Play purchase token.
  final String receipt;

  Map<String, dynamic> toVerifyJson() => {
        'provider': provider,
        'storeProductId': storeProductId,
        'transactionId': transactionId,
        'receipt': receipt,
      };
}

/// Thrown when the user dismisses the store sheet. Not an error: the UI stays silent.
class PurchaseCancelled implements Exception {
  const PurchaseCancelled();
}

/// Abstracts the on-device store (StoreKit / Play Billing) so the purchase flow is fully
/// built and testable before the store plugin is integrated.
///
/// ## Wiring the real stores (production)
///
/// 1. Add `in_app_purchase: ^3.2.0` to pubspec.yaml (see the commented line there).
/// 2. Implement this interface with the plugin's purchase stream:
///    - `queryProductDetails` for the packs from GET /iap/products?provider=...
///    - `buyConsumable`, passing the user's id as the account marker:
///      iOS `applicationUserName` (= StoreKit appAccountToken) and Android
///      `obfuscatedAccountId`. The server REJECTS purchases without a matching marker,
///      which is what stops cross-account replay of receipts.
///    - Forward `verificationData.serverVerificationData` + the transaction id to
///      POST /iap/verify, then `completePurchase` when the server reports credited.
/// 3. Swap [storeBillingProvider] to the real implementation for release builds.
abstract class StoreBilling {
  /// 'apple' on iOS, 'google' on Android.
  String get provider;

  Future<bool> isAvailable();

  /// Launches the store purchase sheet. Returns null / throws [PurchaseCancelled] when
  /// the user dismisses it without paying.
  Future<StorePurchase?> buyPack(CoinPack pack, {required String userId});

  /// Releases the purchase on the store side after the server credited it.
  Future<void> finishPurchase(StorePurchase purchase);
}

/// The store provider id for the current platform, for GET /iap/products?provider=.
String get currentStoreProvider => Platform.isIOS ? 'apple' : 'google';

/// Development-only billing: mints test receipts that the dev API accepts when
/// DEV_IAP_ENABLED=true. Enables the full buy -> verify -> credit loop in the emulator
/// with no store configuration. Never used in release builds.
class DevStoreBilling implements StoreBilling {
  @override
  String get provider => currentStoreProvider;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<StorePurchase?> buyPack(CoinPack pack, {required String userId}) async {
    final transactionId = 'dev-${pack.sku}-${DateTime.now().millisecondsSinceEpoch}';
    return StorePurchase(
      provider: provider,
      storeProductId: pack.storeProductId,
      transactionId: transactionId,
      receipt: jsonEncode({'test': true, 'transactionId': transactionId, 'productId': pack.storeProductId, 'userId': userId}),
    );
  }

  @override
  Future<void> finishPurchase(StorePurchase purchase) async {}
}
