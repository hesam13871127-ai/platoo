import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/player_avatar.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';
import '../social/social_screen.dart' show friendsProvider;
import 'shop_providers.dart';
import 'shop_visuals.dart';

/// Sending a cosmetic now looks like sending a present: pick a friend from the
/// real friend list (never a raw user id), choose how many, add a note, confirm.
/// If the sender does not own a copy yet, the sheet buys one on the way.
class GiftItemSheet extends ConsumerStatefulWidget {
  const GiftItemSheet({super.key, required this.item});
  final ShopItem item;

  @override
  ConsumerState<GiftItemSheet> createState() => _GiftItemSheetState();
}

class _GiftItemSheetState extends ConsumerState<GiftItemSheet> {
  late final String _purchaseKey = newPurchaseKey(widget.item.id);
  final _note = TextEditingController();
  final _search = TextEditingController();
  String? _recipientId;
  String _recipientName = '';
  String _query = '';
  int _quantity = 1;
  bool _busy = false;
  String? _error;
  ShopGiftResult? _result;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _note.dispose();
    _search.dispose();
    super.dispose();
  }

  ShopItem get _item => shopItemById(ref, widget.item.id) ?? widget.item;
  int get _owned => _item.ownedQuantity;
  bool get _needsPurchase => _owned < _quantity;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final scheme = Theme.of(context).colorScheme;
    final accent = shopCategoryColor(widget.item.category);
    return ShopSheetShell(
      accent: accent,
      maxHeightFactor: .9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_result != null)
              _success(context, strings, scheme)
            else ...[
              Row(children: [
                ShopItemArt(category: widget.item.category, assetKey: widget.item.assetKey, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(strings.isPersian ? 'هدیه دادن' : 'Send as a gift', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      _owned > 0
                          ? (strings.isPersian ? '${widget.item.name} · ${shopNumber(_owned)} عدد داری' : '${widget.item.name} · you own ${shopNumber(_owned)}')
                          : (strings.isPersian ? '${widget.item.name} · با خرید و ارسال هدیه' : '${widget.item.name} · buy it and send it'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                    ),
                  ]),
                ),
              ]),
              if (_needsPurchase) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.gold.withOpacity(.35))),
                  child: Row(children: [
                    const Icon(Icons.shopping_bag_rounded, size: 18, color: AppTheme.gold),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _owned == 0
                            ? (strings.isPersian ? 'برای هدیه دادن، اول یک نسخه خریداری می‌شود.' : 'One copy is bought first and sent straight to your friend.')
                            : (strings.isPersian ? 'یک نسخه بیشتر خریده و ارسال می‌شود.' : 'One extra copy is bought and sent to your friend.'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              Row(children: [
                Text(strings.isPersian ? 'انتخاب دوست' : 'Pick a friend', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                const Icon(Icons.group_rounded, size: 18, color: AppTheme.violet),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                decoration: InputDecoration(hintText: strings.isPersian ? 'جست‌وجوی دوستان' : 'Search friends', prefixIcon: const Icon(Icons.search_rounded, size: 20), isDense: true),
              ),
              const SizedBox(height: 10),
              _friendPicker(context, strings, scheme),
              if (_owned > 1) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Text(strings.isPersian ? 'تعداد' : 'Quantity', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  _stepper(context),
                ]),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                maxLines: 2,
                maxLength: 240,
                decoration: InputDecoration(labelText: strings.isPersian ? 'یادداشت (اختیاری)' : 'Add a note (optional)', hintText: strings.isPersian ? 'برای دوستت یک پیام بگذار' : 'Say something nice', isDense: true, counterText: ''),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.coral.withOpacity(.35))),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.coral),
                    const SizedBox(width: 9),
                    Expanded(child: Text(_error!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.coral))),
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              VibePrimaryButton(
                label: _busy
                    ? (strings.isPersian ? 'در حال ارسال…' : 'Sending…')
                    : _needsPurchase
                        ? (strings.isPersian ? 'خرید و ارسال (${shopNumber(_item.price)} ${_item.paysWithPips ? strings.pips.toLowerCase() : strings.coins.toLowerCase()})' : 'Buy and send (${shopNumber(_item.price)} ${_item.paysWithPips ? 'pips' : 'coins'})')
                        : (strings.isPersian ? 'ارسال هدیه' : 'Send gift'),
                icon: Icons.card_giftcard_rounded,
                busy: _busy,
                onPressed: _recipientId == null || _busy ? null : _send,
              ),
              if (_recipientId == null) ...[
                const SizedBox(height: 8),
                Center(child: Text(strings.isPersian ? 'اول یک دوست انتخاب کن' : 'Choose a friend to continue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant))),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _friendPicker(BuildContext context, AppStrings strings, ColorScheme scheme) {
    final friends = ref.watch(friendsProvider);
    return friends.when(
      loading: () => Column(children: const [ShimmerBox(height: 58, borderRadius: BorderRadius.all(Radius.circular(16))), SizedBox(height: 8), ShimmerBox(height: 58, borderRadius: BorderRadius.all(Radius.circular(16)))]),
      error: (_, __) => _notice(strings.isPersian ? 'لیست دوستان بارگذاری نشد.' : 'Could not load your friends. Pull the Social tab to retry.', scheme),
      data: (list) {
        final accepted = list.where((friend) => friend.status == 'accepted').toList()..sort((a, b) => (b.isOnline ? 1 : 0).compareTo(a.isOnline ? 1 : 0));
        final filtered = _query.isEmpty
            ? accepted
            : accepted.where((friend) => friend.displayName.toLowerCase().contains(_query) || friend.username.toLowerCase().contains(_query)).toList();
        if (accepted.isEmpty) return _notice(strings.isPersian ? 'هنوز دوستی نداری. از تب اجتماعی دوست پیدا کن.' : 'No friends yet — add someone from the Social tab first.', scheme);
        if (filtered.isEmpty) return _notice(strings.isPersian ? 'دوستی با این نام پیدا نشد.' : 'No friend matches that name.', scheme);
        return Column(
          children: [
            for (final friend in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FriendRow(
                  friend: friend,
                  selected: friend.id == _recipientId,
                  onTap: () => setState(() {
                    _recipientId = friend.id;
                    _recipientName = friend.displayName;
                  }),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _notice(String message, ColorScheme scheme) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: scheme.surfaceVariant.withOpacity(.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outline.withOpacity(.3))),
        child: Text(message, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: scheme.onSurfaceVariant)),
      );

  Widget _stepper(BuildContext context) => Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.6), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          IconButton(onPressed: _quantity <= 1 ? null : () => setState(() => _quantity--), icon: const Icon(Icons.remove_rounded, size: 18)),
          Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          IconButton(onPressed: _quantity >= _owned ? null : () => setState(() => _quantity++), icon: const Icon(Icons.add_rounded, size: 18)),
        ]),
      );

  Widget _success(BuildContext context, AppStrings strings, ColorScheme scheme) {
    final result = _result!;
    return Column(
      children: [
        const SizedBox(height: 8),
        Entrance(
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.coralGradient, boxShadow: AppTheme.glow(AppTheme.coral, strength: .4)),
            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 18),
        Text(strings.isPersian ? 'هدیه ارسال شد' : 'Gift sent', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          strings.isPersian
              ? '${result.quantity} عدد ${result.itemName} برای ${result.recipientName} رفت. در چت به او خبر داده شد.'
              : '${result.quantity}× ${result.itemName} is on its way to ${result.recipientName}. They were notified in chat.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 22),
        VibePrimaryButton(label: strings.isPersian ? 'باشه' : 'Done', icon: Icons.check_rounded, onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  Future<void> _send() async {
    final recipientId = _recipientId;
    if (recipientId == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(shopControllerProvider);
      final result = _needsPurchase
          ? await controller.buyAndGift(itemId: widget.item.id, idempotencyKey: _purchaseKey, recipientId: recipientId, recipientName: _recipientName, quantity: 1, note: _note.text)
          : await controller.sendGift(itemId: widget.item.id, recipientId: recipientId, quantity: _quantity, note: _note.text);
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.selected, required this.onTap});
  final FriendEntry friend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.violet.withOpacity(.12) : scheme.surfaceVariant.withOpacity(.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppTheme.violet.withOpacity(.6) : scheme.outline.withOpacity(.28), width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          PlayerAvatar(displayName: friend.displayName, radius: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(friend.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
              const SizedBox(height: 1),
              Row(children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: friend.isOnline ? AppTheme.mint : scheme.onSurfaceVariant.withOpacity(.5), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(friend.isOnline ? 'Online now' : '@${friend.username}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
              ]),
            ]),
          ),
          AnimatedScale(
            scale: selected ? 1 : .7,
            duration: const Duration(milliseconds: 160),
            child: Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? AppTheme.violet : scheme.onSurfaceVariant.withOpacity(.6), size: 24),
          ),
        ]),
      ),
    );
  }
}
