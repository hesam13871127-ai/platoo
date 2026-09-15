import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';
import '../iap/coin_store_screen.dart';
import 'gift_sheet.dart';
import 'shop_providers.dart';
import 'shop_visuals.dart';

/// Opens the product sheet: full art, what is inside, price vs. balance, and
/// every action (buy / equip / gift) in one place. Write results stay in the
/// sheet until the player closes it, so nobody ever wonders if it worked.
Future<void> openShopItemSheet(BuildContext context, ShopItem item) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopItemSheet(item: item),
    );

class ShopItemSheet extends ConsumerStatefulWidget {
  const ShopItemSheet({super.key, required this.item});
  final ShopItem item;

  @override
  ConsumerState<ShopItemSheet> createState() => _ShopItemSheetState();
}

class _ShopItemSheetState extends ConsumerState<ShopItemSheet> {
  /// Minted once per sheet so "try again" after a timeout is always safe.
  late final String _purchaseKey = newPurchaseKey(widget.item.id);
  bool _busy = false;
  bool _equipBusy = false;
  String? _error;
  ShopPurchaseResult? _purchase;

  ShopItem get _item => shopItemById(ref, widget.item.id) ?? widget.item;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final item = _item;
    final user = ref.watch(authProvider).value?.user;
    final coins = user?.coins ?? 0;
    final pips = user?.pips ?? 0;
    final accent = shopCategoryColor(item.category);
    return ShopSheetShell(
      accent: accent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_purchase != null)
              _SuccessBlock(item: item, purchase: _purchase!, strings: strings, onEquip: item.equippable ? () => _setEquipped(true) : null, onClose: () => Navigator.of(context).pop(), onGift: item.isGiftable ? () => _openGift(item) : null)
            else ...[
              _header(context, item, strings),
              if (item.bundle != null && !item.bundle!.isEmpty) ...[
                const SizedBox(height: 18),
                _bundleBlock(context, item, strings),
              ],
              if (item.hasPrice) ...[
                const SizedBox(height: 18),
                _priceBlock(context, item, strings, coins: coins, pips: pips),
              ] else ...[
                const SizedBox(height: 16),
                Center(child: ShopWalletRow(coins: coins, pips: pips)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 20),
              _primaryAction(context, item, strings, coins: coins, pips: pips),
              if (item.isGiftable) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _openGift(item),
                  icon: const Icon(Icons.card_giftcard_rounded, size: 19),
                  label: Text(item.owned ? (strings.isPersian ? 'هدیه دادن' : 'Send as a gift') : (strings.isPersian ? 'خرید و هدیه دادن' : 'Buy and send as a gift')),
                ),
              ],
              if (item.equippable && item.owned && item.equipped) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _equipBusy ? null : () => _setEquipped(false),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(strings.isPersian ? 'برداشتن از حالت فعال' : 'Unequip'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ShopItem item, AppStrings strings) => Column(
        children: [
          const SizedBox(height: 6),
          FloatingShopItemArt(category: item.category, assetKey: item.assetKey, size: 92),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ShopTag(label: shopCategoryLabel(item.category, strings.isPersian).toUpperCase(), color: shopCategoryColor(item.category), icon: shopCategoryIcon(item.category)),
              if (item.isLimited) ShopTag(label: strings.isPersian ? 'محدود' : 'LIMITED', color: AppTheme.coral, icon: Icons.local_fire_department_rounded, filled: true),
              if (item.stockLeft != null && !item.soldOut && item.stockLeft! <= 10) ShopTag(label: strings.isPersian ? 'فقط ${shopNumber(item.stockLeft!)} عدد' : 'Only ${item.stockLeft} left', color: AppTheme.coral),
              if (item.owned) ShopTag(label: item.equipped ? (strings.isPersian ? 'فعال' : 'EQUIPPED') : (strings.isPersian ? '${shopNumber(item.ownedQuantity)} عدد داری' : 'OWNED ×${item.ownedQuantity}'), color: AppTheme.mint, icon: item.equipped ? Icons.check_circle_rounded : Icons.inventory_2_rounded),
              if (item.soldOut) ShopTag(label: strings.isPersian ? 'تمام شد' : 'SOLD OUT', color: Theme.of(context).colorScheme.onSurfaceVariant, filled: true),
            ],
          ),
          const SizedBox(height: 14),
          Text(item.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.description, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ],
      );

  Widget _bundleBlock(BuildContext context, ShopItem item, AppStrings strings) {
    final bundle = item.bundle!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.fuchsia.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.fuchsia.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.redeem_rounded, size: 18, color: AppTheme.fuchsia),
            const SizedBox(width: 8),
            Text(strings.isPersian ? 'داخل این پک' : 'Inside this pack', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
          ]),
          const SizedBox(height: 10),
          if (bundle.coins > 0) _contentRow(context, icon: Icons.circle, color: AppTheme.gold, label: strings.isPersian ? '${shopNumber(bundle.coins)} سکه' : '${shopNumber(bundle.coins)} coins'),
          if (bundle.pips > 0) _contentRow(context, icon: Icons.brightness_1_rounded, color: AppTheme.violet, label: strings.isPersian ? '${shopNumber(bundle.pips)} پیپ' : '${shopNumber(bundle.pips)} pips'),
          for (final content in bundle.items)
            _contentRow(context, content: content, label: content.quantity > 1 ? '${content.name} ×${content.quantity}' : content.name),
        ],
      ),
    );
  }

  Widget _contentRow(BuildContext context, {IconData? icon, Color? color, BundleContent? content, required String label}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          content == null
              ? Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: (color ?? AppTheme.violet).withOpacity(.14), borderRadius: BorderRadius.circular(9)), child: Icon(icon ?? Icons.auto_awesome_rounded, size: 15, color: color ?? AppTheme.violet))
              : ShopItemArt(category: content.category, assetKey: content.assetKey, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
        ]),
      );

  Widget _priceBlock(BuildContext context, ShopItem item, AppStrings strings, {required int coins, required int pips}) {
    final scheme = Theme.of(context).colorScheme;
    final balance = item.paysWithPips ? pips : coins;
    final missing = item.price - balance;
    final affordable = missing <= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withOpacity(.28)),
      ),
      child: Column(
        children: [
          Row(children: [
            Text(strings.isPersian ? 'قیمت' : 'Price', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: scheme.onSurfaceVariant)),
            const Spacer(),
            ShopPricePill(price: item.price, paysWithPips: item.paysWithPips, affordable: affordable),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text(strings.isPersian ? 'موجودی فعلی' : 'Your balance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: scheme.onSurfaceVariant)),
            const Spacer(),
            Text(shopNumber(balance), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          ]),
          if (affordable) ...[
            const SizedBox(height: 6),
            Row(children: [
              Text(strings.isPersian ? 'بعد از خرید' : 'After purchase', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text(shopNumber(balance - item.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.mint)),
            ]),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.coral),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.paysWithPips
                        ? (strings.isPersian ? 'به ${shopNumber(missing)} پیپ دیگر نیاز داری.' : 'You need ${shopNumber(missing)} more pips.')
                        : (strings.isPersian ? 'به ${shopNumber(missing)} سکه دیگر نیاز داری.' : 'You need ${shopNumber(missing)} more coins.'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.coral),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _primaryAction(BuildContext context, ShopItem item, AppStrings strings, {required int coins, required int pips}) {
    if (item.soldOut) {
      return FilledButton.icon(onPressed: null, icon: const Icon(Icons.block_rounded, size: 19), label: Text(strings.isPersian ? 'تمام شد' : 'Sold out'));
    }
    if (item.equippable && item.owned) {
      if (item.equipped) {
        return FilledButton.tonalIcon(onPressed: null, icon: const Icon(Icons.check_circle_rounded, size: 19), label: Text(strings.isPersian ? 'همین حالا فعال است' : 'Equipped right now'));
      }
      return FilledButton.icon(
        onPressed: _equipBusy ? null : () => _setEquipped(true),
        icon: _equipBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline_rounded, size: 20),
        label: Text(strings.isPersian ? 'فعال کردن' : 'Equip now'),
      );
    }
    if (!item.hasPrice) {
      return FilledButton.tonalIcon(onPressed: null, icon: const Icon(Icons.inventory_2_rounded, size: 19), label: Text(strings.isPersian ? 'در وسایل تو' : 'In your inventory'));
    }
    final balance = item.paysWithPips ? pips : coins;
    final missing = item.price - balance;
    if (missing > 0) {
      // Coins can be topped up from the store; pips are earned, so say so plainly.
      if (item.paysWithPips) {
        return FilledButton.tonalIcon(onPressed: null, icon: const Icon(Icons.lock_outline_rounded, size: 19), label: Text(strings.isPersian ? 'پیپ کافی نیست' : 'Not enough pips'));
      }
      return VibePrimaryButton(
        label: strings.isPersian ? '${shopNumber(missing)} سکه دیگر بگیر' : 'Get ${shopNumber(missing)} more coins',
        icon: Icons.add_circle_rounded,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CoinStoreScreen())),
      );
    }
    return VibePrimaryButton(
      label: _busy
          ? (strings.isPersian ? 'در حال خرید…' : 'Purchasing…')
          : item.owned
              ? (strings.isPersian ? 'یک نسخه دیگر بخر' : 'Buy another copy')
              : (strings.isPersian ? 'خرید' : 'Buy for ${shopNumber(item.price)} ${item.paysWithPips ? strings.pips.toLowerCase() : strings.coins.toLowerCase()}'),
      icon: Icons.shopping_bag_rounded,
      busy: _busy,
      onPressed: _buy,
    );
  }

  Future<void> _openGift(ShopItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GiftItemSheet(item: item),
    );
    if (mounted) setState(() {});
  }

  Future<void> _buy() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(shopControllerProvider).purchase(itemId: _item.id, idempotencyKey: _purchaseKey);
      if (!mounted) return;
      setState(() {
        _purchase = result;
        _busy = false;
      });
      showAppSnackBar(context, result.replayed ? 'This purchase was already in your inventory.' : '${_item.name} added to your inventory.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _setEquipped(bool equipped) async {
    setState(() => _equipBusy = true);
    try {
      await ref.read(shopControllerProvider).setEquipped(_item.id, equipped: equipped);
      if (!mounted) return;
      showAppSnackBar(context, equipped ? '${_item.name} is now equipped.' : '${_item.name} was unequipped.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _equipBusy = false);
    }
  }
}

class _SuccessBlock extends StatelessWidget {
  const _SuccessBlock({required this.item, required this.purchase, required this.strings, this.onEquip, this.onClose, this.onGift});

  final ShopItem item;
  final ShopPurchaseResult purchase;
  final AppStrings strings;
  final VoidCallback? onEquip;
  final VoidCallback? onClose;
  final VoidCallback? onGift;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 6),
        Entrance(
          child: Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.mintGradient, boxShadow: AppTheme.glow(AppTheme.mint, strength: .42)),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 18),
        Text(purchase.replayed ? (strings.isPersian ? 'قبلاً خریده بودی' : 'Already in your inventory') : (strings.isPersian ? 'به وسایل تو اضافه شد' : 'Added to your inventory'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ShopItemArt(category: item.category, assetKey: item.assetKey, size: 40),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            Text(
              '${strings.isPersian ? 'موجودی' : 'Balance'}: ${shopNumber(item.paysWithPips ? purchase.balancePips : purchase.balanceCoins)} ${item.paysWithPips ? strings.pips.toLowerCase() : strings.coins.toLowerCase()}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ]),
        ]),
        if (purchase.grantedCoins > 0 || purchase.grantedItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.1), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.gold.withOpacity(.35))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(strings.isPersian ? 'محتوای پک' : 'Pack contents unlocked', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 10),
              if (purchase.grantedCoins > 0)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [const Icon(Icons.circle, size: 16, color: AppTheme.gold), const SizedBox(width: 8), Text('+${shopNumber(purchase.grantedCoins)} ${strings.coins.toLowerCase()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))])),
              if (purchase.grantedPips > 0)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [const Icon(Icons.brightness_1_rounded, size: 16, color: AppTheme.violet), const SizedBox(width: 8), Text('+${shopNumber(purchase.grantedPips)} ${strings.pips.toLowerCase()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))])),
              for (final granted in purchase.grantedItems)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [ShopItemArt(category: granted.category, assetKey: granted.assetKey, size: 26), const SizedBox(width: 10), Expanded(child: Text(granted.quantity > 1 ? '${granted.name} ×${granted.quantity}' : granted.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)))])),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        if (onEquip != null && !item.equipped)
          VibePrimaryButton(label: strings.isPersian ? 'فعال کردن' : 'Equip now', icon: Icons.check_circle_outline_rounded, onPressed: onEquip)
        else if (onGift != null)
          VibePrimaryButton(label: strings.isPersian ? 'هدیه دادن به دوست' : 'Send to a friend', icon: Icons.card_giftcard_rounded, onPressed: onGift)
        else
          VibePrimaryButton(label: strings.isPersian ? 'باشه' : 'Great', icon: Icons.check_rounded, onPressed: onClose ?? () {}),
        if (onEquip != null && !item.equipped && onGift != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onGift, child: Text(strings.isPersian ? 'هدیه دادن به دوست' : 'Send to a friend')),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.coral.withOpacity(.35))),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.coral),
          const SizedBox(width: 9),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.coral))),
        ]),
      );
}
