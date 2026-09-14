import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'iap_models.dart';
import 'store_billing.dart';

/// Swap to the real store implementation when `in_app_purchase` is integrated
/// (see [StoreBilling] docs). The dev implementation only works against a dev API.
final storeBillingProvider = Provider<StoreBilling>((ref) => DevStoreBilling());

/// Coin packs for the current platform's store, owned by the server catalog.
final coinPacksProvider = FutureProvider<List<CoinPack>>((ref) async {
  final provider = ref.watch(storeBillingProvider).provider;
  final data = await ref.watch(apiClientProvider).get('/iap/products', query: {'provider': provider}) as List;
  return data.map((item) => CoinPack.fromJson(Map<String, dynamic>.from(item as Map))).toList();
});

/// The signed-in user's top-up history (no receipts are ever exposed here).
final iapHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/iap/purchases') as List;
  return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
});

/// Runs the full top-up flow: store sheet -> server verify -> credit -> refresh.
/// Retrying after a network failure is always safe: the server treats an already
/// credited store transaction as a replay and never credits twice.
class IapController extends AsyncNotifier<IapPurchaseResult?> {
  @override
  Future<IapPurchaseResult?> build() async => null;

  Future<IapPurchaseResult> buyPack(CoinPack pack) async {
    state = const AsyncLoading();
    try {
      final userId = ref.read(authProvider).value?.user.id;
      if (userId == null || userId.isEmpty) throw Exception('Sign in first.');
      final billing = ref.read(storeBillingProvider);
      if (!await billing.isAvailable()) throw Exception('Store billing is not available on this device.');
      final purchase = await billing.buyPack(pack, userId: userId);
      if (purchase == null) throw const PurchaseCancelled();
      final data = await ref.read(apiClientProvider).post('/iap/verify', data: purchase.toVerifyJson()) as Map;
      final result = IapPurchaseResult.fromJson(Map<String, dynamic>.from(data));
      if (result.credited) {
        await billing.finishPurchase(purchase);
        await ref.read(authProvider.notifier).refreshProfile();
        ref.invalidate(iapHistoryProvider);
      }
      state = AsyncData(result);
      return result;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }
}

final iapControllerProvider = AsyncNotifierProvider<IapController, IapPurchaseResult?>(IapController.new);
