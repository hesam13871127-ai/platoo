import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'admin_api.dart';

const _categories = ['avatar', 'frame', 'emote', 'table', 'dice', 'bundle'];

class AdminShopTab extends ConsumerWidget {
  const AdminShopTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(adminShopProvider);
    final role = ref.watch(authProvider).value?.user.role;
    final admin = isAdminRole(role);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _editItem(context, ref, null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New item'),
            )
          : null,
      body: shop.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No shop items yet.'))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminShopProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final active = boolOf(item['isActive'], fallback: true);
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: _color(strOf(item['category'])).withOpacity(.14), borderRadius: BorderRadius.circular(14)),
                          child: Icon(_icon(strOf(item['category'])), color: _color(strOf(item['category']))),
                        ),
                        title: Text(strOf(item['name']), style: TextStyle(fontWeight: FontWeight.w800, color: active ? null : Theme.of(context).disabledColor)),
                        subtitle: Text(
                          '${strOf(item['sku'])} · ${strOf(item['category'])} · ${_price(item)}${item['stock'] == null ? '' : ' · stock ${item['stock']}'}',
                        ),
                        trailing: admin
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: active,
                                    onChanged: (_) => _toggle(context, ref, item),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') _editItem(context, ref, item);
                                      if (value == 'delete') _delete(context, ref, item);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(value: 'delete', child: Text('Delete…')),
                                    ],
                                  ),
                                ],
                              )
                            : Icon(active ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: active ? AppTheme.mint : Theme.of(context).disabledColor),
                        onTap: admin ? () => _editItem(context, ref, item) : null,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  String _price(Map<String, dynamic> item) {
    final pips = intOf(item['pricePips']);
    final coins = intOf(item['priceCoins']);
    if (pips > 0) return '$pips pips';
    return '$coins coins';
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

  Future<void> _toggle(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    final next = !boolOf(item['isActive'], fallback: true);
    final result = await guardAdmin(
      context,
      () => ref.read(apiClientProvider).patch('/admin/shop/${item['id']}', data: {'isActive': next}),
    );
    if (result == null) return;
    ref.invalidate(adminShopProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Map<String, dynamic> item) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete “${strOf(item['name'])}”?'),
        content: const Text(
          'Deactivate removes it from the shop but keeps player inventories intact (recommended). '
          'Delete forever only works if nobody owns it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, 'soft'), child: const Text('Deactivate')),
          FilledButton(onPressed: () => Navigator.pop(context, 'hard'), child: const Text('Delete forever')),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final result = await guardAdmin(
      context,
      () => ref.read(apiClientProvider).delete('/admin/shop/${item['id']}', query: {'hard': choice == 'hard' ? 'true' : 'false'}),
    );
    if (result == null) return;
    ref.invalidate(adminShopProvider);
    showAdminMessage(context, choice == 'hard' ? 'Item deleted.' : 'Item deactivated.');
  }

  Future<void> _editItem(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) async {
    final sku = TextEditingController(text: strOf(existing?['sku']));
    final name = TextEditingController(text: strOf(existing?['name']));
    final description = TextEditingController(text: strOf(existing?['description']));
    final priceCoins = TextEditingController(text: '${intOf(existing?['priceCoins'])}');
    final pricePips = TextEditingController(text: '${intOf(existing?['pricePips'])}');
    final assetKey = TextEditingController(text: strOf(existing?['assetKey']));
    final stock = TextEditingController(text: existing?['stock'] == null ? '' : '${existing!['stock']}');
    final metadata = TextEditingController(text: existing?['metadata'] is Map ? jsonEncode(existing!['metadata']) : (existing?['metadata']?.toString() ?? ''));
    var category = strOf(existing?['category'], 'avatar');
    if (!_categories.contains(category)) category = 'avatar';
    var giftable = existing == null ? true : boolOf(existing['isGiftable'], fallback: true);
    var limited = existing == null ? false : boolOf(existing['isLimited']);
    var active = existing == null ? true : boolOf(existing['isActive'], fallback: true);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New shop item' : 'Edit item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: sku, decoration: const InputDecoration(labelText: 'SKU')),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: priceCoins, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coins'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: pricePips, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pips'))),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: assetKey, decoration: const InputDecoration(labelText: 'Asset key')),
                if (category == 'bundle') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: metadata,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bundle contents (JSON)',
                      helperText: 'e.g. {"grants":{"coins":1500,"items":[{"itemId":"<uuid>","quantity":1}]}}',
                      helperMaxLines: 3,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock (empty = unlimited)')),
                CheckboxListTile(value: giftable, title: const Text('Giftable'), contentPadding: EdgeInsets.zero, onChanged: (v) => setDialogState(() => giftable = v ?? true)),
                CheckboxListTile(value: limited, title: const Text('Limited'), contentPadding: EdgeInsets.zero, onChanged: (v) => setDialogState(() => limited = v ?? false)),
                CheckboxListTile(value: active, title: const Text('Active in shop'), contentPadding: EdgeInsets.zero, onChanged: (v) => setDialogState(() => active = v ?? true)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    final payload = <String, dynamic>{
      'sku': sku.text.trim(),
      'name': name.text.trim(),
      'description': description.text.trim(),
      'category': category,
      'priceCoins': int.tryParse(priceCoins.text.trim()) ?? 0,
      'pricePips': int.tryParse(pricePips.text.trim()) ?? 0,
      'assetKey': assetKey.text.trim().isEmpty ? 'bundle' : assetKey.text.trim(),
      'isGiftable': giftable,
      'isLimited': limited,
      'isActive': active,
    };
    final metadataText = metadata.text.trim();
    Map<String, dynamic>? parsedMetadata;
    if (metadataText.isNotEmpty) {
      try {
        final decoded = jsonDecode(metadataText);
        if (decoded is Map) parsedMetadata = Map<String, dynamic>.from(decoded);
      } catch (_) {
        parsedMetadata = null;
      }
    }
    final metadataInvalid = metadataText.isNotEmpty && parsedMetadata == null;
    final stockText = stock.text.trim();
    if (existing == null) {
      if (stockText.isNotEmpty) payload['stock'] = int.tryParse(stockText) ?? 0;
    } else {
      payload['stock'] = stockText.isEmpty ? null : int.tryParse(stockText) ?? 0;
    }
    sku.dispose();
    name.dispose();
    description.dispose();
    priceCoins.dispose();
    pricePips.dispose();
    assetKey.dispose();
    stock.dispose();
    metadata.dispose();
    if (saved != true || !context.mounted) return;
    if (metadataInvalid) {
      showAdminMessage(context, 'Bundle contents must be a JSON object like {"grants":{"coins":1500}}');
      return;
    }
    if (parsedMetadata != null) payload['metadata'] = parsedMetadata;

    final Object? result;
    if (existing == null) {
      result = await guardAdmin(context, () => ref.read(apiClientProvider).post('/admin/shop', data: payload));
    } else {
      result = await guardAdmin(context, () => ref.read(apiClientProvider).patch('/admin/shop/${existing['id']}', data: payload));
    }
    if (result == null) return;
    ref.invalidate(adminShopProvider);
    showAdminMessage(context, existing == null ? 'Item created.' : 'Item updated.');
  }
}
