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
import 'inventory_screen.dart';
import 'item_detail_sheet.dart';
import 'shop_providers.dart';
import 'shop_visuals.dart';

enum _ShopSort { curated, cheap, pricey, owned }

/// The store front: a spotlight rail of the headline items, category filters,
/// search, and a grid of product cards that always say what the player can do
/// with an item (buy, equip, or "it is already yours").
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  _ShopSort _sort = _ShopSort.curated;
  bool _affordableOnly = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(shopItemsProvider);
    ref.invalidate(inventoryProvider);
    try {
      await ref.read(shopItemsProvider.future);
    } catch (_) {
      // The error state below already offers a retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final fa = strings.isPersian;
    final items = ref.watch(shopItemsProvider);
    final user = ref.watch(authProvider).value?.user;
    final owned = ref.watch(inventoryProvider).valueOrNull?.length ?? 0;
    final coins = user?.coins ?? 0;
    final pips = user?.pips ?? 0;
    final catalog = items.valueOrNull ?? const <ShopItem>[];
    final filtered = _applyFilters(catalog, coins: coins, pips: pips);

    return VibePageBackground(
      child: RefreshIndicator(
        color: AppTheme.violet,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                sliver: SliverToBoxAdapter(
                  child: Entrance(child: _header(context, strings, coins: coins, pips: pips, owned: owned)),
                ),
              ),
            ),
            if (catalog.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                sliver: SliverToBoxAdapter(child: Entrance(delay: const Duration(milliseconds: 60), child: _spotlight(context, strings, catalog))),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: Entrance(delay: const Duration(milliseconds: 90), child: _filters(context, strings, catalog))),
            ),
            if (items.isLoading && catalog.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
                sliver: SliverToBoxAdapter(child: _ShopShimmer()),
              )
            else if (items.hasError && catalog.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StatePanel(
                  icon: Icons.cloud_off_rounded,
                  title: fa ? 'فروشگاه در دسترس نیست' : 'The shop is taking a break',
                  message: fa ? 'کاتالوگ بارگذاری نشد. برای تلاش دوباره پایین بکش.' : 'We could not load the catalog. Pull down to try again.',
                  actionLabel: strings.retry,
                  onAction: _refresh,
                ),
              )
            else if (catalog.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StatePanel(
                  icon: Icons.storefront_rounded,
                  title: fa ? 'هنوز چیزی در فروشگاه نیست' : 'Nothing in the shop yet',
                  message: fa ? 'آواتارها و قاب‌های تازه به‌زودی اینجا می‌آیند.' : 'New cosmetics land here as soon as the next drop is live.',
                  actionLabel: fa ? 'خرید سکه' : 'Get coins',
                  onAction: () => _openCoinStore(context),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: StatePanel(
                  icon: Icons.search_off_rounded,
                  title: fa ? 'چیزی مطابق فیلترها نبود' : 'No item matches those filters',
                  message: fa ? 'جست‌وجو را پاک کن یا دسته دیگری را امتحان کن.' : 'Try another category, clear the search, or show items you cannot afford yet.',
                  actionLabel: fa ? 'پاک کردن فیلترها' : 'Clear filters',
                  onAction: () => setState(() {
                    _search.clear();
                    _query = '';
                    _category = null;
                    _affordableOnly = false;
                  }),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    Text(
                      fa ? '${filtered.length} آیتم' : '${filtered.length} item${filtered.length == 1 ? '' : 's'}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    if (catalog.any((item) => item.owned))
                      ShopTag(label: fa ? '${catalog.where((item) => item.owned).length} در وسایل تو' : '${catalog.where((item) => item.owned).length} owned', color: AppTheme.mint, icon: Icons.check_circle_rounded),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 236, mainAxisExtent: 296, crossAxisSpacing: 14, mainAxisSpacing: 14),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Entrance(
                      delay: Duration(milliseconds: (index % 8) * 40),
                      child: _ShopItemCard(item: filtered[index], coins: coins, pips: pips, fa: fa),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
                child: Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _openInventory(context), icon: const Icon(Icons.backpack_outlined), label: Text(fa ? 'وسایل من' : 'My inventory'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton.icon(onPressed: () => _openCoinStore(context), icon: const Icon(Icons.add_circle_outline), label: Text(fa ? 'خرید سکه' : 'Get coins'))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ShopItem> _applyFilters(List<ShopItem> catalog, {required int coins, required int pips}) {
    var list = catalog.where((item) {
      if (_category != null && item.category != _category) return false;
      if (_affordableOnly) {
        final balance = item.paysWithPips ? pips : coins;
        if (item.hasPrice && item.price > balance) return false;
      }
      if (_query.isEmpty) return true;
      if (item.name.toLowerCase().contains(_query) || item.description.toLowerCase().contains(_query)) return true;
      return shopCategoryLabel(item.category, false).toLowerCase().contains(_query) || shopCategoryLabel(item.category, true).contains(_query);
    }).toList();
    switch (_sort) {
      case _ShopSort.cheap:
        list.sort((a, b) => a.price.compareTo(b.price));
      case _ShopSort.pricey:
        list.sort((a, b) => b.price.compareTo(a.price));
      case _ShopSort.owned:
        list.sort((a, b) => (a.owned ? 1 : 0).compareTo(b.owned ? 1 : 0));
      case _ShopSort.curated:
        break;
    }
    return list;
  }

  Widget _header(BuildContext context, AppStrings strings, {required int coins, required int pips, required int owned}) {
    final fa = strings.isPersian;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const VibeLogo(compact: true),
          const SizedBox(width: 12),
          Text(strings.shop, style: Theme.of(context).textTheme.headlineSmall),
          const Spacer(),
          Stack(clipBehavior: Clip.none, children: [
            Container(decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.1), shape: BoxShape.circle), child: IconButton(onPressed: () => _openInventory(context), icon: const Icon(Icons.backpack_rounded, color: AppTheme.violet), tooltip: fa ? 'وسایل من' : 'My inventory')),
            if (owned > 0) Positioned(right: -2, top: -2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(gradient: AppTheme.mintGradient, borderRadius: BorderRadius.circular(99)), child: Text('$owned', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10)))),
          ]),
        ]),
        const SizedBox(height: 14),
        PressableScale(
          onTap: () => _openCoinStore(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.gold.withOpacity(.18), AppTheme.violet.withOpacity(.13)]),
              border: Border.all(color: AppTheme.gold.withOpacity(.3)),
            ),
            child: Row(children: [
              Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.goldGradient, borderRadius: BorderRadius.circular(12), boxShadow: AppTheme.glow(AppTheme.gold, strength: .3)), child: const Icon(Icons.circle, size: 15, color: Colors.white)),
              const SizedBox(width: 11),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(shopNumber(coins), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                Text(fa ? 'برای خرج کردن بزن' : 'Tap to top up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              const Spacer(),
              Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.14), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.brightness_1_rounded, size: 14, color: AppTheme.violet)),
              const SizedBox(width: 8),
              Text(shopNumber(pips), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(width: 10),
              const Icon(Icons.add_circle_rounded, size: 22, color: AppTheme.gold),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _spotlight(BuildContext context, AppStrings strings, List<ShopItem> catalog) {
    final fa = strings.isPersian;
    final featured = [...catalog]..sort((a, b) {
        final scoreA = (a.isLimited ? 2 : 0) + (a.owned ? 0 : 1);
        final scoreB = (b.isLimited ? 2 : 0) + (b.owned ? 0 : 1);
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        return b.price.compareTo(a.price);
      });
    final heroes = featured.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.auto_awesome_rounded, size: 18, color: AppTheme.fuchsia),
          const SizedBox(width: 8),
          Text(fa ? 'پیشنهاد ویژه' : 'Spotlight', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text(fa ? 'دسته‌های تازه' : 'Fresh drops', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: heroes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => _SpotlightCard(item: heroes[index], fa: fa),
          ),
        ),
      ],
    );
  }

  Widget _filters(BuildContext context, AppStrings strings, List<ShopItem> catalog) {
    final fa = strings.isPersian;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: fa ? 'جست‌وجو در فروشگاه' : 'Search the shop',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () => _search.clear(), icon: const Icon(Icons.close_rounded, size: 18)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<_ShopSort>(
            tooltip: fa ? 'مرتب‌سازی' : 'Sort',
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => [
              PopupMenuItem(value: _ShopSort.curated, child: Text(fa ? 'پیشنهادی' : 'Curated')),
              PopupMenuItem(value: _ShopSort.cheap, child: Text(fa ? 'ارزان‌ترین' : 'Price: low to high')),
              PopupMenuItem(value: _ShopSort.pricey, child: Text(fa ? 'گران‌ترین' : 'Price: high to low')),
              PopupMenuItem(value: _ShopSort.owned, child: Text(fa ? 'نداشته‌ها اول' : 'Not owned first')),
            ],
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: scheme.surfaceVariant.withOpacity(.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outline.withOpacity(.3))),
              child: const Icon(Icons.sort_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          PressableScale(
            onTap: () => setState(() => _affordableOnly = !_affordableOnly),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _affordableOnly ? AppTheme.violet.withOpacity(.16) : scheme.surfaceVariant.withOpacity(.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: _affordableOnly ? AppTheme.violet.withOpacity(.6) : scheme.outline.withOpacity(.3))),
              child: Icon(_affordableOnly ? Icons.savings_rounded : Icons.savings_outlined, size: 20, color: _affordableOnly ? AppTheme.violet : scheme.onSurfaceVariant),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryChip(label: fa ? 'همه' : 'All', icon: Icons.grid_view_rounded, color: AppTheme.violet, selected: _category == null, onTap: () => setState(() => _category = null)),
              for (final category in shopCategories)
                _CategoryChip(
                  label: category.label(fa),
                  icon: category.icon,
                  color: category.accent,
                  selected: _category == category.key,
                  count: catalog.where((item) => item.category == category.key).length,
                  onTap: () => setState(() => _category = _category == category.key ? null : category.key),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _openInventory(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InventoryScreen()));

  void _openCoinStore(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinStoreScreen()));
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.icon, required this.color, required this.selected, required this.onTap, this.count});
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(.16) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? color.withOpacity(.7) : Theme.of(context).colorScheme.outline.withOpacity(.3), width: selected ? 1.6 : 1),
            boxShadow: selected ? AppTheme.glow(color, strength: .18) : AppTheme.softShadow(dark: Theme.of(context).brightness == Brightness.dark),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: selected ? color : null)),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: (selected ? color : Theme.of(context).colorScheme.onSurfaceVariant).withOpacity(.16), borderRadius: BorderRadius.circular(99)), child: Text('$count', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant))),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.item, required this.fa});
  final ShopItem item;
  final bool fa;

  @override
  Widget build(BuildContext context) {
    final color = shopCategoryColor(item.category);
    return PressableScale(
      onTap: () => openShopItemSheet(context, item),
      child: Container(
        width: 262,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(.22), color.withOpacity(.08), AppTheme.violet.withOpacity(.12)]),
          border: Border.all(color: color.withOpacity(.35)),
          boxShadow: AppTheme.glow(color, strength: .22),
        ),
        child: Stack(
          children: [
            Positioned(right: -18, top: -18, child: Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.14)))),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (item.isLimited) ShopTag(label: fa ? 'محدود' : 'LIMITED', color: AppTheme.coral, icon: Icons.local_fire_department_rounded, filled: true) else ShopTag(label: shopCategoryLabel(item.category, fa).toUpperCase(), color: color, icon: shopCategoryIcon(item.category)),
                      ]),
                      const SizedBox(height: 10),
                      Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, height: 1.15, letterSpacing: -.3)),
                      const SizedBox(height: 4),
                      Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const Spacer(),
                      Row(children: [
                        if (item.hasPrice) ShopPricePill(price: item.price, paysWithPips: item.paysWithPips, dense: true),
                        if (item.owned) ...[
                          const SizedBox(width: 6),
                          ShopTag(label: item.equipped ? (fa ? 'فعال' : 'EQUIPPED') : (fa ? 'داری' : 'OWNED'), color: AppTheme.mint, icon: Icons.check_circle_rounded),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(99), boxShadow: AppTheme.glow(AppTheme.violet, strength: .3)),
                          child: Text(fa ? 'دیدن' : 'View', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Padding(padding: const EdgeInsets.only(right: 6, bottom: 26), child: FloatingShopItemArt(category: item.category, assetKey: item.assetKey, size: 78)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopItemCard extends ConsumerStatefulWidget {
  const _ShopItemCard({required this.item, required this.coins, required this.pips, required this.fa});
  final ShopItem item;
  final int coins;
  final int pips;
  final bool fa;

  @override
  ConsumerState<_ShopItemCard> createState() => _ShopItemCardState();
}

class _ShopItemCardState extends ConsumerState<_ShopItemCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final fa = widget.fa;
    final scheme = Theme.of(context).colorScheme;
    final color = shopCategoryColor(item.category);
    final balance = item.paysWithPips ? widget.pips : widget.coins;
    final affordable = !item.hasPrice || item.price <= balance;
    final live = shopItemById(ref, item.id) ?? item;
    return VibeCard(
      onTap: () => openShopItemSheet(context, item),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(clipBehavior: Clip.none, children: [
              ShopItemArt(category: item.category, assetKey: item.assetKey, size: 74),
              if (item.isLimited) Positioned(right: -10, top: -6, child: ShopTag(label: fa ? 'محدود' : 'LIMITED', color: AppTheme.coral, filled: true)),
              if (live.equipped) Positioned(left: -12, top: -6, child: ShopTag(label: fa ? 'فعال' : 'ON', color: AppTheme.mint, icon: Icons.check_circle_rounded, filled: true)),
            ]),
          ),
          const SizedBox(height: 14),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, letterSpacing: -.2)),
          const SizedBox(height: 4),
          Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
          const Spacer(),
          Row(children: [
            if (item.hasPrice)
              ShopPricePill(price: item.price, paysWithPips: item.paysWithPips, affordable: affordable, dense: true)
            else
              ShopTag(label: fa ? 'جایزه' : 'REWARD', color: color),
            if (live.ownedQuantity > 1) ...[const SizedBox(width: 6), ShopTag(label: '×${live.ownedQuantity}', color: AppTheme.violet)],
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: _action(context, live, fa)),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, ShopItem item, bool fa) {
    if (item.soldOut) {
      return FilledButton.tonal(onPressed: null, child: Text(fa ? 'تمام شد' : 'Sold out'));
    }
    if (item.equippable && item.owned) {
      if (item.equipped) {
        return FilledButton.tonalIcon(onPressed: _busy ? null : () => _setEquipped(false), icon: const Icon(Icons.check_circle_rounded, size: 17), label: Text(fa ? 'فعال است' : 'Equipped'));
      }
      return FilledButton.icon(
        onPressed: _busy ? null : () => _setEquipped(true),
        icon: _busy ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline_rounded, size: 18),
        label: Text(fa ? 'فعال کردن' : 'Equip'),
        style: FilledButton.styleFrom(minimumSize: const Size(48, 42), textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
      );
    }
    if (item.owned && !item.hasPrice) {
      return FilledButton.tonal(onPressed: () => openShopItemSheet(context, item), child: Text(fa ? 'در وسایل تو' : 'In your inventory'));
    }
    return FilledButton(
      onPressed: () => openShopItemSheet(context, item),
      style: FilledButton.styleFrom(minimumSize: const Size(48, 42), textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
      child: Text(item.owned ? (fa ? 'یکی دیگر بخر' : 'Buy another') : (fa ? 'خرید' : 'Buy')),
    );
  }

  Future<void> _setEquipped(bool equipped) async {
    setState(() => _busy = true);
    try {
      await ref.read(shopControllerProvider).setEquipped(widget.item.id, equipped: equipped);
      if (!mounted) return;
      showAppSnackBar(context, equipped ? '${widget.item.name} is now equipped.' : '${widget.item.name} was put away.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ShopShimmer extends StatelessWidget {
  const _ShopShimmer();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const ShimmerBox(height: 168, borderRadius: BorderRadius.all(Radius.circular(26))),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 236 / 296,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              ShimmerBox(height: 296, borderRadius: BorderRadius.all(Radius.circular(24))),
              ShimmerBox(height: 296, borderRadius: BorderRadius.all(Radius.circular(24))),
              ShimmerBox(height: 296, borderRadius: BorderRadius.all(Radius.circular(24))),
              ShimmerBox(height: 296, borderRadius: BorderRadius.all(Radius.circular(24))),
            ],
          ),
        ],
      );
}
