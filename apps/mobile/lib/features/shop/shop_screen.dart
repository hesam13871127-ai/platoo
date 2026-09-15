import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';
import '../iap/coin_store_screen.dart';

final shopItemsProvider = FutureProvider<List<ShopItem>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/shop/items') as List;
  return data.map((item) => ShopItem.fromJson(Map<String, dynamic>.from(item as Map))).toList();
});
final inventoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/shop/inventory') as List;
  return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
});

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(Localizations.localeOf(context));
    final items = ref.watch(shopItemsProvider);
    final user = ref.watch(authProvider).value?.user;
    return VibePageBackground(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(shopItemsProvider);
          ref.invalidate(inventoryProvider);
          try {
            await ref.read(shopItemsProvider.future);
          } catch (_) {}
        },
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
                sliver: SliverToBoxAdapter(
                  child: Entrance(
                    child: Row(children: [
                      const VibeLogo(compact: true),
                      const SizedBox(width: 12),
                      Text(strings.shop, style: Theme.of(context).textTheme.headlineSmall),
                      const Spacer(),
                      BalancePill(value: user?.coins ?? 0, icon: Icons.circle, color: AppTheme.gold),
                      const SizedBox(width: 7),
                      BalancePill(value: user?.pips ?? 0, icon: Icons.brightness_1_rounded, color: AppTheme.violet),
                    ]),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              sliver: SliverToBoxAdapter(child: Entrance(delay: const Duration(milliseconds: 60), child: _ShopHero(strings: strings))),
            ),
            items.when(
              loading: () => const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(child: _ShopShimmer()),
              ),
              error: (error, _) => const SliverFillRemaining(hasScrollBody: false, child: StatePanel(icon: Icons.cloud_off_rounded, title: 'The shop is taking a break', message: 'We could not load the catalog. Pull down to try again.')),
              data: (list) => list.isEmpty
                  ? const SliverFillRemaining(hasScrollBody: false, child: StatePanel(icon: Icons.inventory_2_outlined, title: 'Nothing in the shop yet', message: 'New table cosmetics will appear here soon.'))
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Entrance(
                            delay: Duration(milliseconds: (index % 10) * 45),
                            child: _ItemCard(item: list[index], onBuy: () => _buy(context, ref, list[index]), onGift: list[index].isGiftable ? () => _gift(context, ref, list[index]) : null),
                          ),
                          childCount: list.length,
                        ),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 262, crossAxisSpacing: 14, mainAxisSpacing: 14),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                child: Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _inventory(context, ref), icon: const Icon(Icons.backpack_outlined), label: Text(strings.isPersian ? 'وسایل من' : 'My inventory'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinStoreScreen())), icon: const Icon(Icons.add_circle_outline), label: Text(strings.isPersian ? 'خرید سکه' : 'Get coins'))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, ShopItem item) async {
    try {
      await ref.read(apiClientProvider).post('/shop/purchase', data: {'itemId': item.id, 'idempotencyKey': '${item.id}-${DateTime.now().millisecondsSinceEpoch}'});
      ref.invalidate(inventoryProvider);
      await ref.read(authProvider.notifier).refreshProfile();
      if (context.mounted) showAppSnackBar(context, '${item.name} added to your inventory.');
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  Future<void> _gift(BuildContext context, WidgetRef ref, ShopItem item) async {
    final recipient = TextEditingController();
    final send = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(title: Text('Gift ${item.name}'), content: TextField(controller: recipient, decoration: const InputDecoration(labelText: 'Friend user ID')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))]));
    if (send != true || recipient.text.trim().isEmpty) {
      recipient.dispose();
      return;
    }
    try {
      await ref.read(apiClientProvider).post('/shop/gift', data: {'recipientId': recipient.text.trim(), 'itemId': item.id, 'quantity': 1});
      if (context.mounted) showAppSnackBar(context, 'Gift sent.');
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      recipient.dispose();
    }
  }

  void _inventory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => _InventorySheet(ref: ref));
  }
}

class _ShopHero extends StatelessWidget {
  const _ShopHero({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF8B75B), Color(0xFFFF735C), Color(0xFFE14E63)]), boxShadow: AppTheme.glow(AppTheme.coral, strength: .4)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              Positioned(right: -26, top: -26, child: Container(width: 104, height: 104, decoration: BoxDecoration(color: Colors.white.withOpacity(.14), shape: BoxShape.circle))),
              Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(strings.isPersian ? 'حال و هوای میزت را بساز' : 'Make the table yours', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -.3)),
                  const SizedBox(height: 8),
                  Text(strings.isPersian ? 'آواتار، فریم و ایموت‌های تازه برای بازی‌های بعدی.' : 'Fresh avatars, frames and emotes for your next table.', style: TextStyle(color: Colors.white.withOpacity(.9), height: 1.35)),
                  const SizedBox(height: 14),
                  PressableScale(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinStoreScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 12, offset: const Offset(0, 5))]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add_circle_rounded, color: AppTheme.coral, size: 18),
                        const SizedBox(width: 6),
                        Text(strings.isPersian ? 'خرید سکه' : 'Get coins', style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w900, fontSize: 13)),
                      ]),
                    ),
                  ),
                ])),
                const SizedBox(width: 10),
                const Icon(Icons.auto_awesome_rounded, size: 72, color: Color(0xB3FFFFFF)),
              ]),
            ],
          ),
        ),
      );
}

class _ShopShimmer extends StatelessWidget {
  const _ShopShimmer();
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 260 / 262,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ShimmerBox(height: 262, borderRadius: BorderRadius.all(Radius.circular(26))),
          ShimmerBox(height: 262, borderRadius: BorderRadius.all(Radius.circular(26))),
          ShimmerBox(height: 262, borderRadius: BorderRadius.all(Radius.circular(26))),
          ShimmerBox(height: 262, borderRadius: BorderRadius.all(Radius.circular(26))),
        ],
      );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onBuy, this.onGift});
  final ShopItem item;
  final VoidCallback onBuy;
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final color = _color(item.category);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outline.withOpacity(dark ? .3 : .14)),
        boxShadow: AppTheme.softShadow(dark: dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, .1)!, color, Color.lerp(color, Colors.black, .22)!]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppTheme.glow(color, strength: .35),
            ),
            child: Icon(_icon(item.category), color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -.2)),
          const SizedBox(height: 3),
          Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant)),
          const Spacer(),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: (item.pricePips > 0 ? AppTheme.violet : AppTheme.gold).withOpacity(.13), borderRadius: BorderRadius.circular(99)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(item.pricePips > 0 ? Icons.brightness_1_rounded : Icons.circle, size: 14, color: item.pricePips > 0 ? AppTheme.violet : AppTheme.gold),
                const SizedBox(width: 5),
                Text('${item.pricePips > 0 ? item.pricePips : item.priceCoins}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              ]),
            ),
            const Spacer(),
            if (onGift != null) ...[
              IconButton(onPressed: onGift, tooltip: 'Gift', icon: const Icon(Icons.card_giftcard_rounded, size: 20), color: AppTheme.pink, style: IconButton.styleFrom(minimumSize: const Size(40, 40))),
            ],
            FilledButton(onPressed: onBuy, style: FilledButton.styleFrom(minimumSize: const Size(52, 42), padding: const EdgeInsets.symmetric(horizontal: 16), textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)), child: Text(AppStrings(Localizations.localeOf(context)).buy)),
          ]),
        ],
      ),
    );
  }

  Color _color(String category) => switch (category) {
        'avatar' => AppTheme.violet,
        'frame' => AppTheme.coral,
        'emote' => AppTheme.gold,
        'table' => AppTheme.mint,
        'dice' => const Color(0xFF4F7CAC),
        _ => const Color(0xFFF59E0B),
      };
  IconData _icon(String category) => switch (category) {
        'avatar' => Icons.face_rounded,
        'frame' => Icons.crop_square_rounded,
        'emote' => Icons.emoji_emotions_rounded,
        'table' => Icons.table_restaurant_rounded,
        'dice' => Icons.casino_rounded,
        _ => Icons.auto_awesome_rounded,
      };
}

class _InventorySheet extends ConsumerWidget {
  const _InventorySheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final strings = AppStrings(Localizations.localeOf(context));
    final inventory = ref.watch(inventoryProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(strings.isPersian ? 'وسایل من' : 'My inventory', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Flexible(
              child: inventory.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator())),
                error: (error, _) => const StatePanel(icon: Icons.cloud_off_rounded, title: 'Inventory unavailable', message: 'Try again in a moment.'),
                data: (items) => items.isEmpty
                    ? const StatePanel(icon: Icons.backpack_outlined, title: 'Your inventory is empty', message: 'Buy a cosmetic and it will appear here.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          return VibeCard(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.glow(AppTheme.violet, strength: .3)), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 23)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name']?.toString() ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text('Quantity ${item['quantity']}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                item['equipped'] == true
                                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.mint, size: 26)
                                    : FilledButton.tonal(
                                        onPressed: () async {
                                          try {
                                            await ref.read(apiClientProvider).put('/shop/equip', data: {'itemId': item['itemId']});
                                            ref.invalidate(inventoryProvider);
                                          } catch (error) {
                                            if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
                                          }
                                        },
                                        child: const Text('Equip'),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
