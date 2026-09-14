import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';

final shopItemsProvider = FutureProvider<List<ShopItem>>((ref) async { final data = await ref.watch(apiClientProvider).get('/shop/items') as List; return data.map((item) => ShopItem.fromJson(Map<String, dynamic>.from(item as Map))).toList(); });
final inventoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async { final data = await ref.watch(apiClientProvider).get('/shop/inventory') as List; return data.map((item) => Map<String, dynamic>.from(item as Map)).toList(); });

class ShopScreen extends ConsumerWidget { const ShopScreen({super.key}); @override Widget build(BuildContext context, WidgetRef ref) { final strings = AppStrings(Localizations.localeOf(context)); final items = ref.watch(shopItemsProvider); final user = ref.watch(authProvider).value?.user; return RefreshIndicator(onRefresh: () async { ref.invalidate(shopItemsProvider); ref.invalidate(inventoryProvider); try { await ref.read(shopItemsProvider.future); } catch (_) {} }, child: CustomScrollView(slivers: [SliverPadding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 6), sliver: SliverToBoxAdapter(child: Row(children: [const VibeLogo(compact: true), const SizedBox(width: 12), Text(strings.shop, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), const Spacer(), BalancePill(value: user?.coins ?? 0, icon: Icons.circle, color: AppTheme.gold), const SizedBox(width: 7), BalancePill(value: user?.pips ?? 0, icon: Icons.brightness_1_rounded, color: AppTheme.violet)]))), SliverPadding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), sliver: SliverToBoxAdapter(child: _ShopHero(strings: strings))), items.when(loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())), error: (error, _) => SliverFillRemaining(hasScrollBody: false, child: StatePanel(icon: Icons.cloud_off_rounded, title: 'The shop is taking a break', message: 'We could not load the catalog. Pull down to try again.')), data: (list) => list.isEmpty ? const SliverFillRemaining(hasScrollBody: false, child: StatePanel(icon: Icons.inventory_2_outlined, title: 'Nothing in the shop yet', message: 'New table cosmetics will appear here soon.')) : SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverGrid(delegate: SliverChildBuilderDelegate((context, index) => _ItemCard(item: list[index], onBuy: () => _buy(context, ref, list[index]), onGift: list[index].isGiftable ? () => _gift(context, ref, list[index]) : null), childCount: list.length), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 242, crossAxisSpacing: 14, mainAxisSpacing: 14)))),  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 30), child: OutlinedButton.icon(onPressed: () => _inventory(context, ref), icon: const Icon(Icons.backpack_outlined), label: Text(strings.isPersian ? 'وسایل من' : 'My inventory'))))])); }
  Future<void> _buy(BuildContext context, WidgetRef ref, ShopItem item) async { try { await ref.read(apiClientProvider).post('/shop/purchase', data: {'itemId': item.id, 'idempotencyKey': '${item.id}-${DateTime.now().millisecondsSinceEpoch}'}); ref.invalidate(inventoryProvider); await ref.read(authProvider.notifier).refreshProfile(); if (context.mounted) showAppSnackBar(context, '${item.name} added to your inventory.'); } catch (error) { if (context.mounted) showAppSnackBar(context, error.toString(), isError: true); } }
  Future<void> _gift(BuildContext context, WidgetRef ref, ShopItem item) async { final recipient = TextEditingController(); final send = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: Text('Gift ${item.name}'), content: TextField(controller: recipient, decoration: const InputDecoration(labelText: 'Friend user ID')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))])); if (send != true || recipient.text.trim().isEmpty) { recipient.dispose(); return; } try { await ref.read(apiClientProvider).post('/shop/gift', data: {'recipientId': recipient.text.trim(), 'itemId': item.id, 'quantity': 1}); if (context.mounted) showAppSnackBar(context, 'Gift sent.'); } catch (error) { if (context.mounted) showAppSnackBar(context, error.toString(), isError: true); } finally { recipient.dispose(); } }
  void _inventory(BuildContext context, WidgetRef ref) { showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => _InventorySheet(ref: ref)); }
}

class _ShopHero extends StatelessWidget { const _ShopHero({required this.strings}); final AppStrings strings; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFFF8B75B), Color(0xFFFF735C)])), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(strings.isPersian ? 'حال و هوای میزت را بساز' : 'Make the table yours', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21)), const SizedBox(height: 8), Text(strings.isPersian ? 'آواتار، فریم و ایموت‌های تازه برای بازی‌های بعدی.' : 'Fresh avatars, frames and emotes for your next table.', style: const TextStyle(color: Colors.white, height: 1.35))])), const Icon(Icons.auto_awesome_rounded, size: 70, color: Color(0x66FFFFFF))])); }

class _ItemCard extends StatelessWidget { const _ItemCard({required this.item, required this.onBuy, this.onGift}); final ShopItem item; final VoidCallback onBuy; final VoidCallback? onGift; @override Widget build(BuildContext context) { final color = _color(item.category); return Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 66, height: 66, decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(20)), child: Icon(_icon(item.category), color: color, size: 34)), const Spacer(), Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 3), Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 10), Row(children: [Icon(item.pricePips > 0 ? Icons.brightness_1_rounded : Icons.circle, size: 16, color: item.pricePips > 0 ? AppTheme.violet : AppTheme.gold), const SizedBox(width: 5), Text('${item.pricePips > 0 ? item.pricePips : item.priceCoins}', style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), if (onGift != null) IconButton(onPressed: onGift, icon: const Icon(Icons.card_giftcard_rounded, size: 19)), FilledButton(onPressed: onBuy, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 13)), child: Text(AppStrings(Localizations.localeOf(context)).buy))])]))); }
  Color _color(String category) => switch (category) { 'avatar' => AppTheme.violet, 'frame' => AppTheme.coral, 'emote' => AppTheme.gold, 'table' => AppTheme.mint, 'dice' => const Color(0xFF4F7CAC), _ => const Color(0xFFF59E0B) };
  IconData _icon(String category) => switch (category) { 'avatar' => Icons.face_rounded, 'frame' => Icons.crop_square_rounded, 'emote' => Icons.emoji_emotions_rounded, 'table' => Icons.table_restaurant_rounded, 'dice' => Icons.casino_rounded, _ => Icons.auto_awesome_rounded };
}

class _InventorySheet extends ConsumerWidget {
  const _InventorySheet({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context, WidgetRef _) {
    final inventory = ref.watch(inventoryProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: inventory.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StatePanel(icon: Icons.cloud_off_rounded, title: 'Inventory unavailable', message: 'Try again in a moment.'),
          data: (items) => items.isEmpty
              ? const StatePanel(icon: Icons.backpack_outlined, title: 'Your inventory is empty', message: 'Buy a cosmetic and it will appear here.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                      title: Text(item['name']?.toString() ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Quantity ${item['quantity']}'),
                      trailing: item['equipped'] == true
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.mint)
                          : TextButton(
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
                    );
                  },
                ),
        ),
      ),
    );
  }
}
