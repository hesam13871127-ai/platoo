import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
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
        title: VibeText(fa ? 'خرید سکه' : 'Coin Store', style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(.14),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppTheme.gold.withOpacity(.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 14, color: AppTheme.gold),
                  const SizedBox(width: 6),
                  VibeText('$coins', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.gold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: VibePageBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(coinPacksProvider);
            try {
              await ref.read(coinPacksProvider.future);
            } catch (_) {}
          },
          child: packs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => StatePanel(
              icon: Icons.cloud_off_rounded,
              title: fa ? 'فروشگاه سکه موقتاً در دسترس نیست' : 'The coin store is taking a break',
              message: fa ? 'نتوانستیم بسته‌های سکه را بارگذاری کنیم.' : 'We could not load the packs. Pull down to try again.',
              actionLabel: strings.retry,
              onAction: () => ref.invalidate(coinPacksProvider),
            ),
            data: (list) => list.isEmpty
                ? StatePanel(
                    icon: Icons.monetization_on_outlined,
                    title: fa ? 'بسته‌ای برای خرید نیست' : 'No coin packs yet',
                    message: fa ? 'شارژ سکه در این نسخه فعال نیست.' : 'Top-ups are not available in this build.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) return _CoinHero(fa: fa);
                      final pack = list[index - 1];
                      return Entrance(
                        delay: Duration(milliseconds: index * 40),
                        child: _PackCard(pack: pack, buying: buying, fa: fa, onBuy: () => _buy(context, ref, pack)),
                      );
                    },
                  ),
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8B75B), Color(0xFFFF735C)],
          ),
          boxShadow: AppTheme.glow(const Color(0xFFFF735C), strength: .25),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VibeText(
                    fa ? 'موجودی سکه‌ت را شارژ کن' : 'Top up your coin balance',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  VibeText(
                    fa ? 'پرداخت امن از طریق اپ‌استور یا گوگل‌پلی.' : 'Secure checkout through the App Store or Google Play.',
                    style: const TextStyle(color: Colors.white, height: 1.35, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
  Widget build(BuildContext context) => VibeCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.gold.withOpacity(.3)),
              ),
              child: const Icon(Icons.monetization_on_rounded, color: AppTheme.gold, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VibeText('+${pack.totalCoins} ${fa ? 'سکه' : 'coins'}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      if (pack.hasBonus) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: VibeText(
                            fa ? 'ویژه' : 'BONUS',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  VibeText(
                    pack.hasBonus
                        ? (fa ? '${pack.coins} سکه + ${pack.bonusCoins} جایزه' : '${pack.coins} coins + ${pack.bonusCoins} bonus')
                        : (fa ? 'بدون کارمزد اضافه' : 'Instant credit to wallet'),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: buying ? null : onBuy,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: buying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : VibeText(pack.displayPrice.isEmpty ? (fa ? 'خرید' : 'Buy') : pack.displayPrice, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}
