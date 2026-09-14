import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_logo.dart';
import 'iap_models.dart';
import 'iap_service.dart';
import 'store_billing.dart';

/// Coin top-up screen. Lists the server-owned packs, launches the store sheet on tap,
/// and refreshes the wallet balance once the server confirms the credit.
class CoinStoreScreen extends ConsumerWidget {
  const CoinStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(Localizations.localeOf(context));
    final packs = ref.watch(coinPacksProvider);
    final buying = ref.watch(iapControllerProvider).isLoading;
    final coins = ref.watch(authProvider).value?.user.coins ?? 0;
    final fa = strings.isPersian;
    return Scaffold(
      appBar: AppBar(
        title: Text(fa ? 'خرید سکه' : 'Get coins'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Chip(
              avatar: const Icon(Icons.circle, size: 16, color: AppTheme.gold),
              label: Text('$coins', style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(coinPacksProvider);
          try {
            await ref.read(coinPacksProvider.future);
          } catch (_) {}
        },
        child: packs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const StatePanel(
            icon: Icons.cloud_off_rounded,
            title: 'The coin store is taking a break',
            message: 'We could not load the packs. Pull down to try again.',
          ),
          data: (list) => list.isEmpty
              ? const StatePanel(
                  icon: Icons.monetization_on_outlined,
                  title: 'No coin packs yet',
                  message: 'Top-ups are not available in this build.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) return _CoinHero(fa: fa);
                    final pack = list[index - 1];
                    return _PackCard(pack: pack, buying: buying, fa: fa, onBuy: () => _buy(context, ref, pack));
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, CoinPack pack) async {
    try {
      final result = await ref.read(iapControllerProvider.notifier).buyPack(pack);
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        result.replayed ? 'This purchase was already credited to your wallet.' : '+${result.coins} coins added to your wallet.',
      );
    } on PurchaseCancelled {
      // The user dismissed the store sheet: stay silent.
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
    }
  }
}

class _CoinHero extends StatelessWidget {
  const _CoinHero({required this.fa});
  final bool fa;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(colors: [Color(0xFFF8B75B), Color(0xFFFF735C)]),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fa ? 'موجودی سکه‌ت را شارژ کن' : 'Top up your coin balance',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fa ? 'پرداخت امن از طریق اپ‌استور یا گوگل‌پلی.' : 'Secure checkout through the App Store or Google Play.',
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                ],
              ),
            ),
            const VibeLogo(compact: true),
          ],
        ),
      );
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack, required this.buying, required this.fa, required this.onBuy});
  final CoinPack pack;
  final bool buying;
  final bool fa;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.14), borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.monetization_on_rounded, color: AppTheme.gold, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+${pack.totalCoins} ${fa ? 'سکه' : 'coins'}',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pack.hasBonus
                          ? (fa ? '${pack.coins} سکه + ${pack.bonusCoins} جایزه' : '${pack.coins} coins + ${pack.bonusCoins} bonus')
                          : (fa ? 'بدون کارمزد اضافه' : 'No fees, straight to your wallet'),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: buying ? null : onBuy,
                child: buying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(pack.displayPrice.isEmpty ? (fa ? 'خرید' : 'Buy') : pack.displayPrice),
              ),
            ],
          ),
        ),
      );
}
