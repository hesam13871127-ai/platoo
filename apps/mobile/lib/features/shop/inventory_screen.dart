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
import 'gift_sheet.dart';
import 'item_detail_sheet.dart';
import 'shop_providers.dart';
import 'shop_visuals.dart';

enum _InventoryTab { items, gifts }

/// "My things" — one page instead of a cramped sheet: what you own, what is
/// equipped right now, and every gift in both directions.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  _InventoryTab _tab = _InventoryTab.items;
  String? _busyItemId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final fa = strings.isPersian;
    final inventory = ref.watch(inventoryProvider);
    final gifts = ref.watch(giftHistoryProvider);
    final user = ref.watch(authProvider).value?.user;
    final entries = inventory.valueOrNull ?? const <InventoryEntry>[];
    final giftEntries = gifts.valueOrNull ?? const <GiftEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(fa ? 'وسایل من' : 'My inventory'),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: BalancePill(value: user?.coins ?? 0, icon: Icons.circle, color: AppTheme.gold),
          ),
        ],
      ),
      body: VibePageBackground(
        child: RefreshIndicator(
          color: AppTheme.violet,
          onRefresh: () async {
            ref.invalidate(inventoryProvider);
            ref.invalidate(giftHistoryProvider);
            try {
              await ref.read(inventoryProvider.future);
            } catch (_) {
              // The empty state below already explains the offline case.
            }
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(child: Entrance(child: _Stats(entries: entries, gifts: giftEntries, fa: fa))),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                sliver: SliverToBoxAdapter(
                  child: SegmentedButton<_InventoryTab>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: _InventoryTab.items, icon: const Icon(Icons.inventory_2_rounded, size: 18), label: Text(fa ? 'وسایل (${entries.length})' : 'Items (${entries.length})')),
                      ButtonSegment(value: _InventoryTab.gifts, icon: const Icon(Icons.card_giftcard_rounded, size: 18), label: Text(fa ? 'هدایا (${giftEntries.length})' : 'Gifts (${giftEntries.length})')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (selection) => setState(() => _tab = selection.first),
                  ),
                ),
              ),
              if (_tab == _InventoryTab.items)
                ..._itemSlivers(strings, inventory, entries)
              else
                ..._giftSlivers(strings, gifts, giftEntries),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _itemSlivers(AppStrings strings, AsyncValue<List<InventoryEntry>> inventory, List<InventoryEntry> entries) {
    if (inventory.isLoading && entries.isEmpty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
          sliver: SliverToBoxAdapter(
            child: Column(children: [ShimmerBox(height: 82, borderRadius: BorderRadius.all(Radius.circular(22))), SizedBox(height: 10), ShimmerBox(height: 82, borderRadius: BorderRadius.all(Radius.circular(22))), SizedBox(height: 10), ShimmerBox(height: 82, borderRadius: BorderRadius.all(Radius.circular(22)))]),
          ),
        ),
      ];
    }
    if (entries.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StatePanel(
            icon: Icons.inventory_2_rounded,
            title: strings.isPersian ? 'هنوز چیزی نداری' : 'Your inventory is empty',
            message: strings.isPersian ? 'از فروشگاه یک آیتم بخر یا جایزه بگیر تا اینجا بنشیند.' : 'Buy a cosmetic in the shop (or win one) and it will land here.',
            actionLabel: strings.isPersian ? 'رفتن به فروشگاه' : 'Browse the shop',
            onAction: () => Navigator.of(context).pop(),
          ),
        ),
      ];
    }
    final slivers = <Widget>[];
    for (final category in shopCategories) {
      final rows = entries.where((entry) => entry.category == category.key).toList();
      if (rows.isEmpty) continue;
      rows.sort((a, b) => (b.equipped ? 1 : 0).compareTo(a.equipped ? 1 : 0));
      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Row(children: [
            Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: category.accent.withOpacity(.14), borderRadius: BorderRadius.circular(11)), child: Icon(category.icon, size: 16, color: category.accent)),
            const SizedBox(width: 10),
            Text(category.label(strings.isPersian), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            Text('${rows.length}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      ));
      slivers.add(SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            for (final entry in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InventoryRow(
                  entry: entry,
                  fa: strings.isPersian,
                  busy: _busyItemId == entry.itemId,
                  onEquip: entry.equippable ? () => _toggleEquip(entry) : null,
                  onGift: entry.isGiftable ? () => _gift(entry) : null,
                  onOpen: () => openShopItemSheet(context, entry.toShopItem()),
                ),
              ),
          ]),
        ),
      ));
    }
    return slivers;
  }

  List<Widget> _giftSlivers(AppStrings strings, AsyncValue<List<GiftEntry>> gifts, List<GiftEntry> entries) {
    if (gifts.isLoading && entries.isEmpty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
          sliver: SliverToBoxAdapter(
            child: Column(children: [ShimmerBox(height: 76, borderRadius: BorderRadius.all(Radius.circular(22))), SizedBox(height: 10), ShimmerBox(height: 76, borderRadius: BorderRadius.all(Radius.circular(22)))]),
          ),
        ),
      ];
    }
    if (entries.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StatePanel(
            icon: Icons.card_giftcard_rounded,
            title: strings.isPersian ? 'هدیه‌ای رد و بدل نشده' : 'No gifts yet',
            message: strings.isPersian ? 'هر هدیه‌ای که بفرستی یا بگیرد اینجا ثبت می‌شود.' : 'Everything you send or receive shows up here with its note.',
            actionLabel: strings.isPersian ? 'هدیه دادن' : 'Send a gift',
            onAction: () => Navigator.of(context).pop(),
          ),
        ),
      ];
    }
    final received = entries.where((entry) => entry.received).toList();
    final sent = entries.where((entry) => !entry.received).toList();
    return [
      for (final group in [('received', received), ('sent', sent)])
        if (group.$2.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: group.$1 == 'received' ? (strings.isPersian ? 'هدایای دریافتی' : 'Received') : (strings.isPersian ? 'هدایای ارسالی' : 'Sent'),
                subtitle: group.$1 == 'received' ? (strings.isPersian ? '${group.$2.length} هدیه' : '${group.$2.length} gift${group.$2.length == 1 ? '' : 's'}') : null,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                for (final gift in group.$2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GiftRow(entry: gift, fa: strings.isPersian),
                  ),
              ]),
            ),
          ),
        ],
    ];
  }

  Future<void> _toggleEquip(InventoryEntry entry) async {
    if (_busyItemId != null) return;
    setState(() => _busyItemId = entry.itemId);
    try {
      await ref.read(shopControllerProvider).setEquipped(entry.itemId, equipped: !entry.equipped);
      if (!mounted) return;
      showAppSnackBar(context, entry.equipped ? '${entry.name} was put away.' : '${entry.name} is now equipped.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busyItemId = null);
    }
  }

  Future<void> _gift(InventoryEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GiftItemSheet(item: entry.toShopItem()),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.entries, required this.gifts, required this.fa});
  final List<InventoryEntry> entries;
  final List<GiftEntry> gifts;
  final bool fa;

  @override
  Widget build(BuildContext context) {
    final equipped = entries.where((entry) => entry.equipped).length;
    final received = gifts.where((gift) => gift.received).length;
    return Row(children: [
      _StatChip(label: fa ? 'آیتم‌ها' : 'Items', value: '${entries.length}', icon: Icons.inventory_2_rounded, gradient: AppTheme.primaryGradient),
      const SizedBox(width: 10),
      _StatChip(label: fa ? 'فعال' : 'Equipped', value: '$equipped', icon: Icons.verified_rounded, gradient: AppTheme.mintGradient),
      const SizedBox(width: 10),
      _StatChip(label: fa ? 'هدیه گرفته' : 'Received', value: '$received', icon: Icons.card_giftcard_rounded, gradient: AppTheme.coralGradient),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.icon, required this.gradient});
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: gradient, boxShadow: AppTheme.glow(AppTheme.violet, strength: .18)),
          child: Column(children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 1),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.88), fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.entry, required this.fa, required this.busy, this.onEquip, this.onGift, required this.onOpen});
  final InventoryEntry entry;
  final bool fa;
  final bool busy;
  final VoidCallback? onEquip;
  final VoidCallback? onGift;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VibeCard(
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(children: [
        ShopItemArt(category: entry.category, assetKey: entry.assetKey, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5))),
              if (entry.quantity > 1) ...[
                const SizedBox(width: 6),
                ShopTag(label: '×${entry.quantity}', color: AppTheme.violet),
              ],
            ]),
            const SizedBox(height: 3),
            Text(
              entry.equipped
                  ? (fa ? 'الان فعال است' : 'Equipped now')
                  : (entry.acquiredAt == null || entry.acquiredAt!.isEmpty
                      ? shopCategoryLabel(entry.category, fa)
                      : (fa ? 'از ${_date(entry.acquiredAt)}' : 'Since ${_date(entry.acquiredAt)}')),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: entry.equipped ? AppTheme.mint : scheme.onSurfaceVariant),
            ),
          ]),
        ),
        if (onGift != null)
          IconButton(onPressed: busy ? null : onGift, tooltip: fa ? 'هدیه دادن' : 'Gift', icon: const Icon(Icons.card_giftcard_rounded, size: 19), color: AppTheme.pink),
        if (onEquip != null)
          busy
              ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : FilledButton.tonal(
                  onPressed: onEquip,
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 38), padding: const EdgeInsets.symmetric(horizontal: 13), textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                  child: Text(entry.equipped ? (fa ? 'برداشتن' : 'Unequip') : (fa ? 'فعال' : 'Equip')),
                ),
      ]),
    );
  }
}

class _GiftRow extends StatelessWidget {
  const _GiftRow({required this.entry, required this.fa});
  final GiftEntry entry;
  final bool fa;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final received = entry.received;
    return VibeCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          ShopItemArt(category: entry.category, assetKey: entry.assetKey, size: 44),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: received ? AppTheme.mint : AppTheme.pink, shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 2)),
              child: Icon(received ? Icons.south_west_rounded : Icons.north_east_rounded, size: 11, color: Colors.white),
            ),
          ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              received
                  ? (fa ? '${entry.counterpartName} برایت ${entry.itemName} فرستاد' : '${entry.counterpartName} sent you ${entry.itemName}')
                  : (fa ? '${entry.itemName} را برای ${entry.counterpartName} فرستادی' : 'You sent ${entry.itemName} to ${entry.counterpartName}'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.3),
            ),
            if (entry.note != null && entry.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('“${entry.note}”', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 4),
            Text(_date(entry.createdAt), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          ]),
        ),
        if (entry.quantity > 1) ShopTag(label: '×${entry.quantity}', color: received ? AppTheme.mint : AppTheme.pink),
      ]),
    );
  }
}

/// `2026-09-01 10:00:00.000` -> `1 Sep 2026`, without pulling in intl.
String _date(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}
