import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

const _categories = ['avatar', 'frame', 'emote', 'table', 'dice', 'bundle'];

/// Shop management: create, edit, enable/disable and remove catalogue items.
class AdminShopTab extends ConsumerWidget {
  const AdminShopTab({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(adminShopProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(onPressed: () => _edit(context, ref, null), icon: const Icon(Icons.add_rounded), label: const Text('New item'))
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminShopProvider),
        child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search by name or SKU', prefixIcon: Icon(Icons.search_rounded)),
              onSubmitted: (value) => ref.read(adminShopQueryProvider.notifier).state = value.trim(),
            ),
          ),
          AdminAsync<List<Map<String, dynamic>>>(
            value: items,
            onRetry: () => ref.invalidate(adminShopProvider),
            builder: (list) => list.isEmpty
                ? const AdminEmpty(icon: Icons.inventory_2_outlined, title: 'The catalogue is empty', message: 'Create the first shop item to get started.')
                : Column(children: [
                    AdminSectionHeader(title: '${list.length} item(s)', subtitle: '${list.where((item) => asBool(item['isActive'])).length} currently on sale'),
                    for (final item in list) _ShopTile(item: item, isAdmin: isAdmin, onEdit: () => _edit(context, ref, item)),
                  ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ShopItemForm(existing: existing),
      ),
    );
    if (saved == true) {
      ref.invalidate(adminShopProvider);
      await showAdminMessage(context, existing == null ? 'Shop item created.' : 'Shop item updated.');
    }
  }
}

class _ShopTile extends ConsumerWidget {
  const _ShopTile({required this.item, required this.isAdmin, required this.onEdit});
  final Map<String, dynamic> item;
  final bool isAdmin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = asBool(item['isActive']);
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(item['sku']?.toString() ?? '', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            if (isAdmin)
              Switch(value: active, onChanged: (value) async {
                try {
                  await ref.read(adminRepositoryProvider).toggleShopItem(item['id'].toString(), value);
                  ref.invalidate(adminShopProvider);
                } catch (error) {
                  await showAdminError(context, error);
                }
              })
            else
              AdminStatusChip(label: active ? 'on sale' : 'hidden', color: active ? AppTheme.mint : Colors.grey),
          ]),
          Text(item['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            AdminStatusChip(label: item['category']?.toString() ?? '', color: AppTheme.violet),
            if (asInt(item['priceCoins']) > 0) AdminStatusChip(label: '${asInt(item['priceCoins'])} coins', color: AppTheme.gold),
            if (asInt(item['pricePips']) > 0) AdminStatusChip(label: '${asInt(item['pricePips'])} pips', color: AppTheme.violet),
            AdminStatusChip(label: '${asInt(item['owned'])} owned', color: AppTheme.mint),
            if (item['stock'] != null) AdminStatusChip(label: 'stock ${asInt(item['stock'])}', color: AppTheme.coral),
          ]),
          if (isAdmin)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Edit')),
              TextButton.icon(
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.coral),
              ),
            ]),
        ]),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${item['name']}?'),
        content: const Text('If players already own this item it is retired from the catalogue instead of deleted, so inventories stay intact.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: AppTheme.coral), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await ref.read(adminRepositoryProvider).deleteShopItem(item['id'].toString());
      ref.invalidate(adminShopProvider);
      await showAdminMessage(context, result['retired'] == true ? 'Item retired because players own it.' : 'Item deleted.');
    } catch (error) {
      await showAdminError(context, error);
    }
  }
}

class _ShopItemForm extends ConsumerStatefulWidget {
  const _ShopItemForm({this.existing});
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<_ShopItemForm> createState() => _ShopItemFormState();
}

class _ShopItemFormState extends ConsumerState<_ShopItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sku = TextEditingController(text: widget.existing?['sku']?.toString() ?? '');
  late final TextEditingController _name = TextEditingController(text: widget.existing?['name']?.toString() ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.existing?['description']?.toString() ?? '');
  late final TextEditingController _assetKey = TextEditingController(text: widget.existing?['assetKey']?.toString() ?? '');
  late final TextEditingController _coins = TextEditingController(text: '${asInt(widget.existing?['priceCoins'])}');
  late final TextEditingController _pips = TextEditingController(text: '${asInt(widget.existing?['pricePips'])}');
  late String _category = widget.existing?['category']?.toString() ?? 'avatar';
  late bool _giftable = widget.existing == null ? true : asBool(widget.existing!['isGiftable']);
  late bool _active = widget.existing == null ? true : asBool(widget.existing!['isActive']);
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_sku, _name, _description, _assetKey, _coins, _pips]) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(editing ? 'Edit shop item' : 'New shop item', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          if (!editing)
            TextFormField(
              controller: _sku,
              decoration: const InputDecoration(labelText: 'SKU', helperText: 'Unique catalogue code, e.g. frame_neon_01'),
              validator: (value) => (value ?? '').trim().length < 2 ? 'A SKU of at least 2 characters is required.' : null,
            ),
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Name'), validator: (value) => (value ?? '').trim().length < 2 ? 'A name is required.' : null),
          TextFormField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
          TextFormField(controller: _assetKey, decoration: const InputDecoration(labelText: 'Asset key'), validator: (value) => (value ?? '').trim().isEmpty ? 'An asset key is required.' : null),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [for (final category in _categories) DropdownMenuItem(value: category, child: Text(category))],
            onChanged: (value) => setState(() => _category = value ?? 'avatar'),
          ),
          Row(children: [
            Expanded(child: TextFormField(controller: _coins, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price in coins'))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _pips, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price in pips'))),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _giftable, onChanged: (value) => setState(() => _giftable = value), title: const Text('Can be gifted')),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (value) => setState(() => _active = value), title: const Text('Visible in the shop')),
          const SizedBox(height: 10),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save item')),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final coins = int.tryParse(_coins.text.trim()) ?? 0;
    final pips = int.tryParse(_pips.text.trim()) ?? 0;
    if (coins <= 0 && pips <= 0) {
      await showAdminError(context, 'Set a coin or pip price above zero.');
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'category': _category,
      'priceCoins': coins,
      'pricePips': pips,
      'assetKey': _assetKey.text.trim(),
      'isGiftable': _giftable,
      'isActive': _active,
    };
    try {
      final repository = ref.read(adminRepositoryProvider);
      if (widget.existing == null) {
        await repository.createShopItem({...payload, 'sku': _sku.text.trim()});
      } else {
        await repository.updateShopItem(widget.existing!['id'].toString(), payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      await showAdminError(context, error);
      if (mounted) setState(() => _saving = false);
    }
  }
}
