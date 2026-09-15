import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/player_avatar.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';
import '../iap/coin_store_screen.dart';
import '../social/social_screen.dart';

final shopItemsProvider = FutureProvider<List<ShopItem>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/shop/items') as List;
  return data.map((item) => ShopItem.fromJson(Map<String, dynamic>.from(item as Map))).toList();
});

final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/shop/inventory') as List;
  return data.map((item) => InventoryItem.fromJson(Map<String, dynamic>.from(item as Map))).toList();
});

final giftHistoryProvider = FutureProvider<({List<GiftHistoryEntry> received, List<GiftHistoryEntry> sent})>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/shop/gifts') as Map;
  final rec = (data['received'] as List? ?? []).map((e) => GiftHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map), isReceived: true)).toList();
  final snt = (data['sent'] as List? ?? []).map((e) => GiftHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map), isReceived: false)).toList();
  return (received: rec, sent: snt);
});

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  int _activeTab = 0; // 0: Catalog, 1: Inventory
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final Set<String> _busyItemIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
  }

  void _onTabChanged(int tab) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeTab = tab;
      _selectedCategory = 'all';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final user = ref.watch(authProvider).value?.user;
    final itemsAsync = ref.watch(shopItemsProvider);
    final inventoryAsync = ref.watch(inventoryProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final inventoryItems = inventoryAsync.valueOrNull ?? const <InventoryItem>[];
    final ownedMap = {for (final inv in inventoryItems) inv.itemId: inv};

    return VibePageBackground(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(shopItemsProvider);
          ref.invalidate(inventoryProvider);
          ref.invalidate(giftHistoryProvider);
          ref.invalidate(friendsProvider);
          try {
            await Future.wait([
              ref.read(shopItemsProvider.future),
              ref.read(inventoryProvider.future),
            ]);
          } catch (_) {}
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Top App Bar
            SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                sliver: SliverToBoxAdapter(
                  child: Entrance(
                    child: Row(
                      children: [
                        const VibeLogo(compact: true),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.shop,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PressableScale(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinStoreScreen())),
                          child: BalancePill(value: user?.coins ?? 0, icon: Icons.circle, color: AppTheme.gold),
                        ),
                        const SizedBox(width: 7),
                        BalancePill(value: user?.pips ?? 0, icon: Icons.brightness_1_rounded, color: AppTheme.violet),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: strings.giftHistory,
                          onPressed: () => _openGiftHistory(context),
                          icon: const Icon(Icons.card_giftcard_rounded, size: 20),
                          style: IconButton.styleFrom(
                            backgroundColor: (dark ? AppTheme.violet.withOpacity(.2) : AppTheme.violet.withOpacity(.1)),
                            foregroundColor: AppTheme.violet,
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Tab Selector: Catalog vs My Inventory
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              sliver: SliverToBoxAdapter(
                child: Entrance(
                  delay: const Duration(milliseconds: 40),
                  child: _ShopTabSwitcher(
                    activeTab: _activeTab,
                    onTabChanged: _onTabChanged,
                    strings: strings,
                    inventoryCount: inventoryItems.length,
                  ),
                ),
              ),
            ),

            if (_activeTab == 0) ...[
              // Featured Promo Hero Banner
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Entrance(
                    delay: const Duration(milliseconds: 70),
                    child: _ShopHero(strings: strings),
                  ),
                ),
              ),
            ] else ...[
              // Currently Equipped Strip in Inventory
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Entrance(
                    delay: const Duration(milliseconds: 70),
                    child: _EquippedCosmeticsStrip(
                      inventory: inventoryItems,
                      strings: strings,
                      onTapItem: (item) => _showItemDetails(context, item: null, owned: item),
                    ),
                  ),
                ),
              ),
            ],

            // Category Filter Pills
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              sliver: SliverToBoxAdapter(
                child: Entrance(
                  delay: const Duration(milliseconds: 100),
                  child: _CategoryPills(
                    selectedCategory: _selectedCategory,
                    onSelect: _onCategorySelected,
                    strings: strings,
                  ),
                ),
              ),
            ),

            // Search Bar
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverToBoxAdapter(
                child: Entrance(
                  delay: const Duration(milliseconds: 130),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: _activeTab == 0 ? strings.searchShop : (strings.isPersian ? 'جست‌وجوی وسایل…' : 'Search inventory…'),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
            ),

            // Main Content: Catalog Grid OR Inventory Grid
            if (_activeTab == 0)
              _buildCatalogContent(context, itemsAsync, ownedMap, strings)
            else
              _buildInventoryContent(context, inventoryAsync, strings),

            // Bottom Spacing
            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogContent(
    BuildContext context,
    AsyncValue<List<ShopItem>> itemsAsync,
    Map<String, InventoryItem> ownedMap,
    AppStrings strings,
  ) {
    return itemsAsync.when(
      loading: () => const SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(child: _ShopShimmer()),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: StatePanel(
          icon: Icons.cloud_off_rounded,
          title: strings.isPersian ? 'فروشگاه در دسترس نیست' : 'The shop is taking a break',
          message: strings.isPersian ? 'نتوانستیم کاتالوگ را بارگذاری کنیم. صفحه را به پایین بکشید.' : 'We could not load the catalog. Pull down to try again.',
          actionLabel: strings.retry,
          onAction: () => ref.invalidate(shopItemsProvider),
        ),
      ),
      data: (catalog) {
        final filtered = catalog.where((item) {
          final matchesCat = _selectedCategory == 'all' || item.category == _selectedCategory;
          final matchesQuery = _searchQuery.isEmpty ||
              item.name.toLowerCase().contains(_searchQuery) ||
              item.description.toLowerCase().contains(_searchQuery);
          return matchesCat && matchesQuery;
        }).toList();

        if (catalog.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: StatePanel(
              icon: Icons.inventory_2_outlined,
              title: strings.isPersian ? 'آیتمی در فروشگاه نیست' : 'Nothing in the shop yet',
              message: strings.isPersian ? 'تزئینات تازه به زودی اضافه خواهند شد.' : 'New table cosmetics will appear here soon.',
            ),
          );
        }

        if (filtered.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: StatePanel(
              icon: Icons.search_off_rounded,
              title: strings.noItemsCategory,
              message: strings.isPersian ? 'فیلتر دسته‌بندی یا جست‌وجوی خود را تغییر دهید.' : 'Try selecting another category or clear your search query.',
              actionLabel: strings.isPersian ? 'نمایش همه' : 'Show all',
              onAction: () => setState(() {
                _selectedCategory = 'all';
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = filtered[index];
                final owned = ownedMap[item.id];
                final isBusy = _busyItemIds.contains(item.id);
                return Entrance(
                  delay: Duration(milliseconds: (index % 8) * 40),
                  child: _ProductCard(
                    item: item,
                    owned: owned,
                    isBusy: isBusy,
                    strings: strings,
                    onTap: () => _showItemDetails(context, item: item, owned: owned),
                    onBuy: () => _buy(context, item),
                    onGift: item.isGiftable ? () => _openGiftSheet(context, item: item, owned: owned) : null,
                    onEquipToggle: owned != null ? () => _toggleEquip(context, owned) : null,
                  ),
                );
              },
              childCount: filtered.length,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              mainAxisExtent: 310,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInventoryContent(
    BuildContext context,
    AsyncValue<List<InventoryItem>> inventoryAsync,
    AppStrings strings,
  ) {
    return inventoryAsync.when(
      loading: () => const SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverToBoxAdapter(child: _ShopShimmer()),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: StatePanel(
          icon: Icons.cloud_off_rounded,
          title: strings.isPersian ? 'وسایل بارگذاری نشد' : 'Inventory unavailable',
          message: strings.isPersian ? 'صفحه را برای تلاش مجدد به پایین بکشید.' : 'Pull down to try loading your items again.',
          actionLabel: strings.retry,
          onAction: () => ref.invalidate(inventoryProvider),
        ),
      ),
      data: (items) {
        final filtered = items.where((item) {
          final matchesCat = _selectedCategory == 'all' || item.category == _selectedCategory;
          final matchesQuery = _searchQuery.isEmpty ||
              item.name.toLowerCase().contains(_searchQuery) ||
              item.description.toLowerCase().contains(_searchQuery);
          return matchesCat && matchesQuery;
        }).toList();

        if (items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: StatePanel(
              icon: Icons.backpack_outlined,
              title: strings.isPersian ? 'وسایل شما خالی است' : 'Your inventory is empty',
              message: strings.isPersian ? 'آیتم‌های خریداری‌شده یا هدیه گرفته‌شده در اینجا نمایش داده می‌شوند.' : 'Cosmetics you buy or receive as gifts will appear here.',
              actionLabel: strings.browseShop,
              onAction: () => setState(() => _activeTab = 0),
            ),
          );
        }

        if (filtered.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: StatePanel(
              icon: Icons.filter_alt_off_rounded,
              title: strings.noItemsCategory,
              message: strings.isPersian ? 'آیتمی در این دسته یافت نشد.' : 'You do not own any items in this category yet.',
              actionLabel: strings.browseShop,
              onAction: () => setState(() {
                _activeTab = 0;
              }),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = filtered[index];
                final isBusy = _busyItemIds.contains(item.itemId);
                return Entrance(
                  delay: Duration(milliseconds: (index % 8) * 40),
                  child: _InventoryCard(
                    item: item,
                    isBusy: isBusy,
                    strings: strings,
                    onTap: () => _showItemDetails(context, item: null, owned: item),
                    onEquipToggle: () => _toggleEquip(context, item),
                    onGift: item.isGiftable ? () => _openGiftSheet(context, item: null, owned: item) : null,
                  ),
                );
              },
              childCount: filtered.length,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              mainAxisExtent: 290,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
          ),
        );
      },
    );
  }

  // --- Purchase Logic ---
  Future<void> _buy(BuildContext context, ShopItem item) async {
    final strings = AppStrings(Localizations.localeOf(context));
    final user = ref.read(authProvider).value?.user;
    final currency = item.pricePips > 0 ? 'pips' : 'coins';
    final price = item.pricePips > 0 ? item.pricePips : item.priceCoins;
    final currentBalance = (currency == 'pips' ? user?.pips : user?.coins) ?? 0;

    if (currentBalance < price) {
      final needMore = price - currentBalance;
      final proceedToStore = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.isPersian ? 'موجودی ناکافی' : 'Insufficient balance'),
          content: Text(
            strings.isPersian
                ? 'برای خرید ${item.name} به $needMore $currency دیگر نیاز دارید.'
                : 'You need $needMore more $currency to purchase ${item.name}. Would you like to get more coins now?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(strings.getCoins)),
          ],
        ),
      );
      if (proceedToStore == true && context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinStoreScreen()));
      }
      return;
    }

    setState(() => _busyItemIds.add(item.id));
    try {
      final idempotencyKey = '${item.id}-${user?.id}-${DateTime.now().millisecondsSinceEpoch}';
      final res = await ref.read(apiClientProvider).post(
        '/shop/purchase',
        data: {
          'itemId': item.id,
          'quantity': 1,
          'idempotencyKey': idempotencyKey,
        },
      ) as Map;

      ref.invalidate(inventoryProvider);
      await ref.read(authProvider.notifier).refreshProfile();

      if (context.mounted) {
        HapticFeedback.heavyImpact();
        _showCelebrationSheet(context, item: item, res: res);
      }
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busyItemIds.remove(item.id));
    }
  }

  // --- Equip / Unequip Logic ---
  Future<void> _toggleEquip(BuildContext context, InventoryItem item) async {
    final strings = AppStrings(Localizations.localeOf(context));
    final newStatus = !item.equipped;
    setState(() => _busyItemIds.add(item.itemId));
    try {
      await ref.read(apiClientProvider).put(
        '/shop/equip',
        data: {'itemId': item.itemId, 'equipped': newStatus},
      );
      ref.invalidate(inventoryProvider);
      HapticFeedback.mediumImpact();
      if (context.mounted) {
        showAppSnackBar(
          context,
          newStatus
              ? (strings.isPersian ? '${item.name} فعال شد.' : '${item.name} equipped.')
              : (strings.isPersian ? '${item.name} غیرفعال شد.' : '${item.name} unequipped.'),
        );
      }
    } catch (error) {
      if (context.mounted) showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busyItemIds.remove(item.itemId));
    }
  }

  // --- Item Details Sheet ---
  void _showItemDetails(BuildContext context, {ShopItem? item, InventoryItem? owned}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _ItemDetailSheet(
        item: item,
        owned: owned,
        onBuy: item != null ? () => _buy(sheetContext, item) : null,
        onEquipToggle: owned != null ? () => _toggleEquip(sheetContext, owned) : null,
        onGift: (item?.isGiftable ?? owned?.isGiftable ?? true)
            ? () {
                Navigator.pop(sheetContext);
                _openGiftSheet(context, item: item, owned: owned);
              }
            : null,
      ),
    );
  }

  // --- Gift Sheet ---
  void _openGiftSheet(BuildContext context, {ShopItem? item, InventoryItem? owned}) {
    final strings = AppStrings(Localizations.localeOf(context));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _GiftSheet(
        item: item,
        owned: owned,
        onGiftSent: (recipientName, itemName) {
          ref.invalidate(inventoryProvider);
          ref.invalidate(giftHistoryProvider);
          ref.read(authProvider.notifier).refreshProfile();
          if (context.mounted) {
            HapticFeedback.heavyImpact();
            showAppSnackBar(
              context,
              strings.isPersian ? 'هدیه با موفقیت برای $recipientName ارسال شد! 🎁' : 'Gift ($itemName) sent to $recipientName! 🎁',
            );
          }
        },
      ),
    );
  }

  // --- Celebration Sheet ---
  void _showCelebrationSheet(BuildContext context, {required ShopItem item, required Map res}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _PurchaseCelebrationSheet(
        item: item,
        onEquipNow: () async {
          Navigator.pop(sheetContext);
          try {
            await ref.read(apiClientProvider).put('/shop/equip', data: {'itemId': item.id, 'equipped': true});
            ref.invalidate(inventoryProvider);
            if (context.mounted) {
              showAppSnackBar(context, '${item.name} equipped!');
            }
          } catch (_) {}
        },
      ),
    );
  }

  // --- Gift History Modal ---
  void _openGiftHistory(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _GiftHistorySheet(),
    );
  }
}

// =============================================================================
// Top Switcher: Catalog vs My Inventory
// =============================================================================
class _ShopTabSwitcher extends StatelessWidget {
  const _ShopTabSwitcher({
    required this.activeTab,
    required this.onTabChanged,
    required this.strings,
    required this.inventoryCount,
  });
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final AppStrings strings;
  final int inventoryCount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(dark ? .3 : .6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withOpacity(dark ? .2 : .1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: strings.catalog,
              icon: Icons.storefront_rounded,
              selected: activeTab == 0,
              onTap: () => onTabChanged(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: strings.myInventory,
              icon: Icons.backpack_rounded,
              badge: inventoryCount > 0 ? '$inventoryCount' : null,
              selected: activeTab == 1,
              onTap: () => onTabChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 10, offset: const Offset(0, 3))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? AppTheme.violet : scheme.onSurfaceVariant),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13.5,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.violet.withOpacity(.15) : scheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: selected ? AppTheme.violet : scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Category Pills
// =============================================================================
class _CategoryPills extends StatelessWidget {
  const _CategoryPills({
    required this.selectedCategory,
    required this.onSelect,
    required this.strings,
  });
  final String selectedCategory;
  final ValueChanged<String> onSelect;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final categories = [
      ('all', strings.all, Icons.dashboard_rounded, AppTheme.violet),
      ('avatar', strings.avatars, Icons.face_rounded, AppTheme.violet),
      ('frame', strings.frames, Icons.crop_square_rounded, AppTheme.coral),
      ('emote', strings.emotes, Icons.emoji_emotions_rounded, AppTheme.gold),
      ('table', strings.tables, Icons.table_restaurant_rounded, AppTheme.mint),
      ('dice', strings.dice, Icons.casino_rounded, const Color(0xFF4F7CAC)),
      ('bundle', strings.bundles, Icons.auto_awesome_motion_rounded, AppTheme.fuchsia),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final (key, label, icon, color) in categories)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _CategoryChip(
                label: label,
                icon: icon,
                color: color,
                selected: selectedCategory == key,
                onTap: () => onSelect(key),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(dark ? .25 : .15) : scheme.surfaceVariant.withOpacity(dark ? .3 : .6),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? color.withOpacity(.6) : scheme.outline.withOpacity(dark ? .2 : .1),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(.25), blurRadius: 10, offset: const Offset(0, 3))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? (dark ? Colors.white : color) : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3D Cosmetic Artwork Rendering Engine
// =============================================================================
class CosmeticArt extends StatelessWidget {
  const CosmeticArt({
    super.key,
    required this.category,
    required this.assetKey,
    this.size = 72,
    this.accentColor,
    this.ghost = false,
  });

  final String category;
  final String assetKey;
  final double size;
  final Color? accentColor;
  final bool ghost;

  Color _resolveColor() {
    if (accentColor != null) return accentColor!;
    return switch (category) {
      'avatar' => AppTheme.violet,
      'frame' => AppTheme.coral,
      'emote' => AppTheme.gold,
      'table' => AppTheme.mint,
      'dice' => const Color(0xFF4F7CAC),
      'bundle' => AppTheme.fuchsia,
      _ => AppTheme.violet,
    };
  }

  IconData _resolveIcon() {
    if (assetKey.contains('fire')) return Icons.local_fire_department_rounded;
    if (assetKey.contains('neon')) return Icons.face_retouching_natural_rounded;
    if (assetKey.contains('sunset')) return Icons.filter_frames_rounded;
    if (assetKey.contains('aurora')) return Icons.table_restaurant_rounded;
    if (assetKey.contains('crystal')) return Icons.casino_rounded;
    if (assetKey.contains('starter') || assetKey.contains('bundle')) return Icons.auto_awesome_motion_rounded;

    return switch (category) {
      'avatar' => Icons.face_rounded,
      'frame' => Icons.crop_square_rounded,
      'emote' => Icons.emoji_emotions_rounded,
      'table' => Icons.table_restaurant_rounded,
      'dice' => Icons.casino_rounded,
      'bundle' => Icons.card_giftcard_rounded,
      _ => Icons.auto_awesome_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    final icon = _resolveIcon();
    final radius = size * .32;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ambient glow halo
        if (!ghost)
          Positioned(
            left: -size * .16,
            top: -size * .16,
            child: Container(
              width: size * 1.32,
              height: size * 1.32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withOpacity(.38), color.withOpacity(0)],
                ),
              ),
            ),
          ),

        // Depth base layer (3D shadow bottom)
        Transform.translate(
          offset: Offset(size * .04, size * .07),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: Color.lerp(color, Colors.black, .5)!.withOpacity(.4),
            ),
          ),
        ),

        // Main 3D Cosmetic Tile
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(color, Colors.white, .28)!,
                Color.lerp(color, Colors.white, .06)!,
                color,
                Color.lerp(color, Colors.black, .32)!,
              ],
              stops: const [0, .3, .7, 1],
            ),
            border: Border.all(color: Colors.white.withOpacity(.35), width: size * .025),
            boxShadow: ghost
                ? null
                : [
                    BoxShadow(color: color.withOpacity(.5), blurRadius: size * .28, offset: Offset(0, size * .12)),
                    BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: size * .1, offset: Offset(0, size * .04)),
                  ],
          ),
          child: Stack(
            children: [
              // Top gloss curved highlight
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: size * .45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withOpacity(.35), Colors.white.withOpacity(0)],
                    ),
                  ),
                ),
              ),
              // Pill specular reflex
              Positioned(
                top: size * .12,
                left: size * .16,
                child: Container(
                  width: size * .28,
                  height: size * .09,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              // Category Specific Visual Ornament
              Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: size * .48,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(.35), blurRadius: size * .08, offset: Offset(0, size * .04)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Floating animated 3D cosmetic for hero and detail sheets
class FloatingCosmeticArt extends StatefulWidget {
  const FloatingCosmeticArt({
    super.key,
    required this.category,
    required this.assetKey,
    this.size = 110,
    this.accentColor,
  });
  final String category;
  final String assetKey;
  final double size;
  final Color? accentColor;

  @override
  State<FloatingCosmeticArt> createState() => _FloatingCosmeticArtState();
}

class _FloatingCosmeticArtState extends State<FloatingCosmeticArt> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        builder: (context, child) {
          final t = _curve.value * 2 - 1;
          return Transform.translate(
            offset: Offset(0, 6 * t),
            child: Transform.rotate(angle: .04 * t, child: child),
          );
        },
        child: CosmeticArt(
          category: widget.category,
          assetKey: widget.assetKey,
          size: widget.size,
          accentColor: widget.accentColor,
        ),
      );
}

// =============================================================================
// Hero Spotlight Banner
// =============================================================================
class _ShopHero extends StatelessWidget {
  const _ShopHero({required this.strings});
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFFC44DFF), Color(0xFFFF735C)],
        ),
        boxShadow: AppTheme.glow(AppTheme.violet, strength: .4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.2),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          strings.isPersian ? '✨ فروشگاه ویژه' : '✨ FEATURED COLLECTION',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        strings.isPersian ? 'حال و هوای میزت را بساز' : 'Make the table yours',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 21,
                          letterSpacing: -.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.isPersian
                            ? 'آواتارهای درخشان، فریم‌ها، تاس‌های سه‌بعدی و میزهای اختصاصی.'
                            : 'Glow avatars, frames, 3D dice and custom table themes for game nights.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.9),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      PressableScale(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinStoreScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 12, offset: const Offset(0, 5)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_circle_rounded, color: AppTheme.violet, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                strings.getCoins,
                                style: const TextStyle(
                                  color: AppTheme.violet,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                const FloatingCosmeticArt(
                  category: 'bundle',
                  assetKey: 'bundle_starter',
                  size: 78,
                  accentColor: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Currently Equipped Strip in Inventory
// =============================================================================
class _EquippedCosmeticsStrip extends StatelessWidget {
  const _EquippedCosmeticsStrip({
    required this.inventory,
    required this.strings,
    required this.onTapItem,
  });
  final List<InventoryItem> inventory;
  final AppStrings strings;
  final ValueChanged<InventoryItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    final equippedItems = inventory.where((item) => item.equipped).toList();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.mint.withOpacity(.35)),
        boxShadow: [
          BoxShadow(color: AppTheme.mint.withOpacity(dark ? .15 : .08), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.mint.withOpacity(.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.mint, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                strings.currentlyEquipped,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${equippedItems.length} active',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (equippedItems.isEmpty)
            Text(
              strings.isPersian ? 'هیچ آیتمی هنوز فعال نشده است. روی وسایل خود دکمه «فعال کردن» را بزنید.' : 'No cosmetics equipped yet. Tap "Equip" on any item below to show it off.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (final item in equippedItems)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: PressableScale(
                        onTap: () => onTapItem(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: scheme.surfaceVariant.withOpacity(dark ? .4 : .8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: scheme.outline.withOpacity(.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CosmeticArt(category: item.category, assetKey: item.assetKey, size: 28, ghost: true),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                  Text(
                                    item.category.toUpperCase(),
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppTheme.mint),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Product Card (Catalog)
// =============================================================================
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.item,
    this.owned,
    required this.isBusy,
    required this.strings,
    required this.onTap,
    required this.onBuy,
    this.onGift,
    this.onEquipToggle,
  });

  final ShopItem item;
  final InventoryItem? owned;
  final bool isBusy;
  final AppStrings strings;
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final VoidCallback? onGift;
  final VoidCallback? onEquipToggle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final isEquipped = owned?.equipped ?? false;
    final isOwned = owned != null;
    final isLimited = item.isLimited;
    final stock = item.stock;
    final isSoldOut = stock != null && stock <= 0;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isEquipped
                ? AppTheme.mint.withOpacity(.6)
                : scheme.outline.withOpacity(dark ? .3 : .14),
            width: isEquipped ? 1.6 : 1,
          ),
          boxShadow: isEquipped
              ? [BoxShadow(color: AppTheme.mint.withOpacity(.2), blurRadius: 16, offset: const Offset(0, 6))]
              : AppTheme.softShadow(dark: dark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Artwork + Badges
            Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: CosmeticArt(category: item.category, assetKey: item.assetKey, size: 76),
                  ),
                ),
                // Limited Edition / Stock Badge
                if (isLimited || stock != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: isSoldOut
                            ? const LinearGradient(colors: [Colors.grey, Colors.blueGrey])
                            : AppTheme.coralGradient,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: (isSoldOut ? Colors.grey : AppTheme.coral).withOpacity(.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSoldOut ? Icons.block_rounded : Icons.local_fire_department_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isSoldOut
                                ? strings.soldOut
                                : (stock != null ? '$stock ${strings.leftInStock}' : strings.limitedEdition),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Equipped Status Badge
                if (isEquipped)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.mint,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(color: AppTheme.mint.withOpacity(.35), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            strings.equipped,
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (isOwned)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        owned!.quantity > 1 ? '${strings.owned} x${owned!.quantity}' : strings.owned,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -.2),
            ),
            const SizedBox(height: 2),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, height: 1.3, color: scheme.onSurfaceVariant),
            ),

            const Spacer(),

            // Price & Action Buttons
            Row(
              children: [
                // Price Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: (item.pricePips > 0 ? AppTheme.violet : AppTheme.gold).withOpacity(.13),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.pricePips > 0 ? Icons.brightness_1_rounded : Icons.circle,
                        size: 13,
                        color: item.pricePips > 0 ? AppTheme.violet : AppTheme.gold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.pricePips > 0 ? item.pricePips : item.priceCoins}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          color: item.pricePips > 0 ? AppTheme.violet : (dark ? AppTheme.gold : const Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Gift Button
                if (onGift != null)
                  IconButton(
                    onPressed: onGift,
                    tooltip: strings.giftToFriend,
                    icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                    color: AppTheme.pink,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),

                // Main CTA Button
                if (isOwned && (item.category == 'avatar' || item.category == 'frame' || item.category == 'table'))
                  FilledButton.tonal(
                    onPressed: isBusy ? null : onEquipToggle,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(54, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: isEquipped ? AppTheme.mint.withOpacity(.18) : null,
                      foregroundColor: isEquipped ? AppTheme.mint : null,
                    ),
                    child: isBusy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            isEquipped ? strings.equipped : strings.equip,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                  )
                else
                  FilledButton(
                    onPressed: (isBusy || isSoldOut) ? null : onBuy,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(54, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: isBusy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            isSoldOut ? strings.soldOut : strings.buy,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Inventory Card (My Inventory Tab)
// =============================================================================
class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.isBusy,
    required this.strings,
    required this.onTap,
    required this.onEquipToggle,
    this.onGift,
  });

  final InventoryItem item;
  final bool isBusy;
  final AppStrings strings;
  final VoidCallback onTap;
  final VoidCallback onEquipToggle;
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final isEquipped = item.equipped;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isEquipped
                ? AppTheme.mint.withOpacity(.7)
                : scheme.outline.withOpacity(dark ? .3 : .14),
            width: isEquipped ? 1.8 : 1,
          ),
          boxShadow: isEquipped
              ? [BoxShadow(color: AppTheme.mint.withOpacity(.25), blurRadius: 18, offset: const Offset(0, 6))]
              : AppTheme.softShadow(dark: dark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: CosmeticArt(category: item.category, assetKey: item.assetKey, size: 74),
                  ),
                ),
                // Quantity Badge
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'x${item.quantity}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                // Equipped Badge
                if (isEquipped)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.mint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            strings.equipped,
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -.2),
            ),
            const SizedBox(height: 2),
            Text(
              item.description.isNotEmpty ? item.description : item.category.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            Row(
              children: [
                if (onGift != null)
                  IconButton(
                    onPressed: onGift,
                    tooltip: strings.giftToFriend,
                    icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                    color: AppTheme.pink,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: isBusy ? null : onEquipToggle,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(70, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: isEquipped ? AppTheme.mint.withOpacity(.18) : null,
                    foregroundColor: isEquipped ? AppTheme.mint : null,
                  ),
                  child: isBusy
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          isEquipped ? strings.unequip : strings.equip,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Item Detail Sheet (Modal View)
// =============================================================================
class _ItemDetailSheet extends StatelessWidget {
  const _ItemDetailSheet({
    this.item,
    this.owned,
    this.onBuy,
    this.onEquipToggle,
    this.onGift,
  });

  final ShopItem? item;
  final InventoryItem? owned;
  final VoidCallback? onBuy;
  final VoidCallback? onEquipToggle;
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final name = item?.name ?? owned?.name ?? 'Cosmetic';
    final description = item?.description ?? owned?.description ?? '';
    final category = item?.category ?? owned?.category ?? 'cosmetic';
    final assetKey = item?.assetKey ?? owned?.assetKey ?? 'bundle';
    final isEquipped = owned?.equipped ?? false;
    final isGiftable = item?.isGiftable ?? owned?.isGiftable ?? true;
    final priceCoins = item?.priceCoins ?? 0;
    final pricePips = item?.pricePips ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Center Floating Cosmetic
            Center(
              child: FloatingCosmeticArt(
                category: category,
                assetKey: assetKey,
                size: 110,
              ),
            ),
            const SizedBox(height: 18),

            // Category & Limited Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.violet.withOpacity(.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.violet,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                if (item?.isLimited == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.coralGradient,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          strings.limitedEdition,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isEquipped) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.mint,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          strings.equipped,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            Text(
              name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant, height: 1.4),
              textAlign: TextAlign.center,
            ),

            if (item != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: (pricePips > 0 ? AppTheme.violet : AppTheme.gold).withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pricePips > 0 ? Icons.brightness_1_rounded : Icons.circle,
                      size: 18,
                      color: pricePips > 0 ? AppTheme.violet : AppTheme.gold,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pricePips > 0 ? pricePips : priceCoins} ${pricePips > 0 ? strings.pips : strings.coins}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: pricePips > 0 ? AppTheme.violet : (dark ? AppTheme.gold : const Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Row
            Row(
              children: [
                if (isGiftable && onGift != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onGift,
                      icon: const Icon(Icons.card_giftcard_rounded, color: AppTheme.pink),
                      label: Text(strings.gift, style: const TextStyle(color: AppTheme.pink)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (owned != null && onEquipToggle != null) ...[
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onEquipToggle!();
                      },
                      icon: Icon(isEquipped ? Icons.remove_circle_outline_rounded : Icons.check_circle_outline_rounded),
                      label: Text(isEquipped ? strings.unequip : strings.equip),
                    ),
                  ),
                ] else if (item != null && onBuy != null) ...[
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onBuy!();
                      },
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(strings.buy),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Purchase Celebration Sheet (Delightful Confirmation)
// =============================================================================
class _PurchaseCelebrationSheet extends StatelessWidget {
  const _PurchaseCelebrationSheet({required this.item, required this.onEquipNow});
  final ShopItem item;
  final VoidCallback onEquipNow;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.glow(AppTheme.violet, strength: .4),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              strings.unlocked,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              strings.isPersian ? '${item.name} به وسایل شما اضافه شد!' : '${item.name} was added to your inventory!',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FloatingCosmeticArt(category: item.category, assetKey: item.assetKey, size: 96),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(strings.isPersian ? 'بستن' : 'Done'),
                  ),
                ),
                if (item.category == 'avatar' || item.category == 'frame' || item.category == 'table') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onEquipNow,
                      child: Text(strings.equipNow),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Interactive Gifting Flow Sheet
// =============================================================================
class _GiftSheet extends ConsumerStatefulWidget {
  const _GiftSheet({
    this.item,
    this.owned,
    required this.onGiftSent,
  });

  final ShopItem? item;
  final InventoryItem? owned;
  final void Function(String recipientName, String itemName) onGiftSent;

  @override
  ConsumerState<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends ConsumerState<_GiftSheet> {
  FriendEntry? _selectedFriend;
  final _manualRecipient = TextEditingController();
  final _note = TextEditingController();
  int _quantity = 1;
  bool _sending = false;
  String _friendSearch = '';

  @override
  void dispose() {
    _manualRecipient.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submitGift(BuildContext context) async {
    final strings = AppStrings(Localizations.localeOf(context));
    final recipientId = _selectedFriend?.id ?? _manualRecipient.text.trim();
    if (recipientId.isEmpty) {
      showAppSnackBar(context, strings.selectFriend, isError: true);
      return;
    }

    final itemId = widget.item?.id ?? widget.owned?.itemId ?? '';
    final itemName = widget.item?.name ?? widget.owned?.name ?? 'Item';
    final recipientName = _selectedFriend?.displayName ?? 'Friend';

    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).post('/shop/gift', data: {
        'recipientId': recipientId,
        'itemId': itemId,
        'quantity': _quantity,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        'buyDirect': widget.owned == null || (widget.owned!.quantity < _quantity),
      });

      if (context.mounted) {
        Navigator.pop(context);
        widget.onGiftSent(recipientName, itemName);
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(context, error.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final friendsAsync = ref.watch(friendsProvider);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final itemName = widget.item?.name ?? widget.owned?.name ?? 'Item';
    final category = widget.item?.category ?? widget.owned?.category ?? 'bundle';
    final assetKey = widget.item?.assetKey ?? widget.owned?.assetKey ?? 'bundle';
    final ownedQty = widget.owned?.quantity ?? 0;

    final friends = (friendsAsync.valueOrNull ?? const <FriendEntry>[])
        .where((f) => f.status == 'accepted')
        .where((f) => _friendSearch.isEmpty || f.displayName.toLowerCase().contains(_friendSearch) || f.username.toLowerCase().contains(_friendSearch))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Item Preview
              Row(
                children: [
                  CosmeticArt(category: category, assetKey: assetKey, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.isPersian ? 'ارسال $itemName به عنوان هدیه' : 'Gift $itemName',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          ownedQty > 0
                              ? (strings.isPersian ? 'شما $ownedQty عدد در وسایل دارید (رایگان)' : 'You own $ownedQty in your inventory (Free)')
                              : (strings.isPersian ? 'خرید مستقیم و ارسال برای دوست' : 'Direct purchase for your friend'),
                          style: TextStyle(
                            fontSize: 12,
                            color: ownedQty > 0 ? AppTheme.mint : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Step 1: Select Recipient
              Text(
                strings.selectFriend,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(height: 8),

              if (friends.isNotEmpty) ...[
                TextField(
                  onChanged: (v) => setState(() => _friendSearch = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: strings.isPersian ? 'جست‌وجوی دوستان…' : 'Search friends…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    itemCount: friends.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final isSelected = _selectedFriend?.id == friend.id;
                      return PressableScale(
                        onTap: () => setState(() => _selectedFriend = friend),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.violet.withOpacity(dark ? .3 : .15) : scheme.surfaceVariant.withOpacity(dark ? .3 : .6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppTheme.violet : scheme.outline.withOpacity(dark ? .2 : .1),
                              width: isSelected ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              VibeInitial(name: friend.displayName, radius: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                    Text('@${friend.username}', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppTheme.violet, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                // Manual input fallback if no friends
                TextField(
                  controller: _manualRecipient,
                  decoration: InputDecoration(
                    labelText: strings.isPersian ? 'شناسه کاربر دوست' : 'Friend user ID',
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Personal Note
              TextField(
                controller: _note,
                maxLength: 240,
                decoration: InputDecoration(
                  labelText: strings.giftNote,
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                ),
              ),

              const SizedBox(height: 16),

              // Action Button
              VibePrimaryButton(
                onPressed: _sending ? null : () => _submitGift(context),
                label: strings.sendGift,
                icon: Icons.card_giftcard_rounded,
                busy: _sending,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Gift History Sheet
// =============================================================================
class _GiftHistorySheet extends ConsumerWidget {
  const _GiftHistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(Localizations.localeOf(context));
    final historyAsync = ref.watch(giftHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.giftHistory,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TabBar(
                tabs: [
                  Tab(text: strings.received),
                  Tab(text: strings.sent),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 350,
                child: historyAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => StatePanel(
                    icon: Icons.cloud_off_rounded,
                    title: 'History unavailable',
                    message: error.toString(),
                  ),
                  data: (history) => TabBarView(
                    children: [
                      _buildHistoryList(history.received, isReceived: true, scheme: scheme, strings: strings),
                      _buildHistoryList(history.sent, isReceived: false, scheme: scheme, strings: strings),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    List<GiftHistoryEntry> list, {
    required bool isReceived,
    required ColorScheme scheme,
    required AppStrings strings,
  }) {
    if (list.isEmpty) {
      return StatePanel(
        icon: Icons.card_giftcard_rounded,
        title: isReceived ? 'No gifts received yet' : 'No gifts sent yet',
        message: isReceived
            ? 'When friends send you gifts, they will appear here.'
            : 'Send a cosmetic gift to a friend to surprise them!',
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = list[index];
        return VibeCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CosmeticArt(category: entry.category, assetKey: entry.assetKey, size: 42, ghost: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.itemName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isReceived ? 'From: ${entry.otherUserName}' : 'To: ${entry.otherUserName}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '“${entry.note}”',
                        style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: scheme.primary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Shimmer Loading Skeleton
// =============================================================================
class _ShopShimmer extends StatelessWidget {
  const _ShopShimmer();
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 260 / 290,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ShimmerBox(height: 290, borderRadius: BorderRadius.all(Radius.circular(26))),
          ShimmerBox(height: 290, borderRadius: BorderRadius.all(Radius.circular(26))),
          ShimmerBox(height: 290, borderRadius: BorderRadius.all(Radius.circular(26))),
          ShimmerBox(height: 290, borderRadius: BorderRadius.all(Radius.circular(26))),
        ],
      );
}
