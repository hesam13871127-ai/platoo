import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'admin_api.dart';

class AdminSeasonsTab extends ConsumerWidget {
  const AdminSeasonsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasons = ref.watch(adminSeasonsProvider);
    final role = ref.watch(authProvider).value?.user.role;
    final admin = isAdminRole(role);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: () => _createSeason(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New season'),
            )
          : null,
      body: seasons.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No seasons yet.'))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminSeasonsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final season = items[index];
                    final status = strOf(season['status']);
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: _color(status).withOpacity(.14), borderRadius: BorderRadius.circular(14)),
                          child: Icon(_icon(status), color: _color(status)),
                        ),
                        title: Text(strOf(season['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '${dateLabel(season['startsAt'])} → ${dateLabel(season['endsAt'])} · ${intOf(season['rewardsCount'])} rewards · ${intOf(season['participantCount'])} players',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _color(status).withOpacity(.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(status, style: TextStyle(color: _color(status), fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => _SeasonDetailSheet(seasonId: strOf(season['id'])),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Color _color(String status) => switch (status) {
        'active' => AppTheme.mint,
        'scheduled' => AppTheme.gold,
        _ => AppTheme.violet,
      };

  IconData _icon(String status) => switch (status) {
        'active' => Icons.emoji_events_rounded,
        'scheduled' => Icons.schedule_rounded,
        _ => Icons.history_rounded,
      };

  Future<void> _createSeason(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final startsAt = TextEditingController(text: _todayPlus(0));
    final endsAt = TextEditingController(text: _todayPlus(90));
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New season'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: startsAt, decoration: const InputDecoration(labelText: 'Starts (YYYY-MM-DD)', hintText: '2026-01-01')),
            const SizedBox(height: 8),
            TextField(controller: endsAt, decoration: const InputDecoration(labelText: 'Ends (YYYY-MM-DD)', hintText: '2026-12-31')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    final payload = {'name': name.text.trim(), 'startsAt': _toIso(startsAt.text.trim()), 'endsAt': _toIso(endsAt.text.trim())};
    name.dispose();
    startsAt.dispose();
    endsAt.dispose();
    if (saved != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).post('/admin/seasons', data: payload));
    if (result == null) return;
    ref.invalidate(adminSeasonsProvider);
    showAdminMessage(context, 'Season created.');
  }

  String _todayPlus(int days) {
    final date = DateTime.now().add(Duration(days: days));
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _toIso(String input) {
    final parsed = DateTime.tryParse(input.trim());
    if (parsed == null) return input;
    return parsed.toUtc().toIso8601String();
  }
}

class _SeasonDetailSheet extends ConsumerWidget {
  const _SeasonDetailSheet({required this.seasonId});
  final String seasonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminSeasonDetailProvider(seasonId));
    final role = ref.watch(authProvider).value?.user.role;
    final admin = isAdminRole(role);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: detail.when(
          loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          error: (error, _) => Padding(padding: const EdgeInsets.all(24), child: Text(error.toString())),
          data: (season) {
            final status = strOf(season['status']);
            final rewards = asItemList(season['rewards']);
            final top = asItemList(season['topPlayers']);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strOf(season['name']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('${dateLabel(season['startsAt'])} → ${dateLabel(season['endsAt'])} · $status · ${intOf(season['participantCount'])} players',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Rewards', style: TextStyle(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      if (admin && status != 'finished')
                        TextButton.icon(
                          onPressed: () => _addReward(context, ref),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (rewards.isEmpty)
                    const Text('No rewards configured yet.')
                  else
                    for (final reward in rewards)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          title: Text('Ranks ${intOf(reward['minRank'])}–${intOf(reward['maxRank'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            '${intOf(reward['coins'])} coins · ${intOf(reward['pips'])} pips${strOf(reward['shopItemName']).isEmpty ? '' : ' · ${strOf(reward['shopItemName'])}'}',
                          ),
                          trailing: admin && status != 'finished'
                              ? IconButton(
                                  tooltip: 'Delete reward',
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () => _deleteReward(context, ref, strOf(reward['id'])),
                                )
                              : null,
                        ),
                      ),
                  if (top.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Top players', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    for (var i = 0; i < top.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('#${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.gold)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(strOf(top[i]['displayName']))),
                            Text('${intOf(top[i]['rating'])} rating', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                  ],
                  if (admin) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (status == 'scheduled')
                          FilledButton.icon(
                            onPressed: () => _activate(context, ref),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Activate'),
                          ),
                        if (status == 'active')
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.gold),
                            onPressed: () => _finish(context, ref),
                            icon: const Icon(Icons.emoji_events_rounded),
                            label: const Text('Finish & pay rewards'),
                          ),
                        if (status != 'finished')
                          OutlinedButton.icon(
                            onPressed: () => _edit(context, ref, season),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        if (status == 'scheduled')
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                            onPressed: () => _delete(context, ref),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Delete'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Activate season?'),
        content: Text('The currently active season (if any) will be finished first.'),
        actions: [
          _CancelButton(),
          _ConfirmButton(label: 'Activate'),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).post('/admin/seasons/$seasonId/activate'));
    if (result == null || !context.mounted) return;
    ref.invalidate(adminSeasonDetailProvider(seasonId));
    ref.invalidate(adminSeasonsProvider);
    showAdminMessage(context, 'Season activated.');
    Navigator.pop(context);
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Finish season?'),
        content: Text('Rank rewards will be paid out to winners. This cannot be undone.'),
        actions: [
          _CancelButton(),
          _ConfirmButton(label: 'Finish'),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).post('/admin/seasons/$seasonId/finish'));
    if (result == null || !context.mounted) return;
    ref.invalidate(adminSeasonDetailProvider(seasonId));
    ref.invalidate(adminSeasonsProvider);
    showAdminMessage(context, 'Season finished and rewards paid.');
    Navigator.pop(context);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Delete season?'),
        content: Text('Only scheduled seasons can be deleted.'),
        actions: [
          _CancelButton(),
          _ConfirmButton(label: 'Delete'),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).delete('/admin/seasons/$seasonId'));
    if (result == null || !context.mounted) return;
    ref.invalidate(adminSeasonsProvider);
    showAdminMessage(context, 'Season deleted.');
    Navigator.pop(context);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Map<String, dynamic> season) async {
    final name = TextEditingController(text: strOf(season['name']));
    final endsAt = TextEditingController(text: dateLabel(season['endsAt']));
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit season'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: endsAt, decoration: const InputDecoration(labelText: 'Ends (YYYY-MM-DD)')),
          ],
        ),
        actions: const [_CancelButton(), _ConfirmButton(label: 'Save')],
      ),
    );
    final payload = {'name': name.text.trim(), 'endsAt': _toIso(endsAt.text.trim())};
    name.dispose();
    endsAt.dispose();
    if (saved != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).patch('/admin/seasons/$seasonId', data: payload));
    if (result == null || !context.mounted) return;
    ref.invalidate(adminSeasonDetailProvider(seasonId));
    ref.invalidate(adminSeasonsProvider);
    showAdminMessage(context, 'Season updated.');
    Navigator.pop(context);
  }

  Future<void> _addReward(BuildContext context, WidgetRef ref) async {
    final minRank = TextEditingController(text: '1');
    final maxRank = TextEditingController(text: '1');
    final coins = TextEditingController(text: '0');
    final pips = TextEditingController(text: '0');
    final shopItemId = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add reward'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: TextField(controller: minRank, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min rank'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: maxRank, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max rank'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: coins, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coins'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: pips, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pips'))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: shopItemId, decoration: const InputDecoration(labelText: 'Shop item ID (optional)')),
            ],
          ),
        ),
        actions: const [_CancelButton(), _ConfirmButton(label: 'Add')],
      ),
    );
    final payload = <String, dynamic>{
      'minRank': int.tryParse(minRank.text.trim()) ?? 1,
      'maxRank': int.tryParse(maxRank.text.trim()) ?? 1,
      'coins': int.tryParse(coins.text.trim()) ?? 0,
      'pips': int.tryParse(pips.text.trim()) ?? 0,
    };
    if (shopItemId.text.trim().isNotEmpty) payload['shopItemId'] = shopItemId.text.trim();
    minRank.dispose();
    maxRank.dispose();
    coins.dispose();
    pips.dispose();
    shopItemId.dispose();
    if (saved != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).post('/admin/seasons/$seasonId/rewards', data: payload));
    if (result == null) return;
    ref.invalidate(adminSeasonDetailProvider(seasonId));
    ref.invalidate(adminSeasonsProvider);
    showAdminMessage(context, 'Reward added.');
  }

  Future<void> _deleteReward(BuildContext context, WidgetRef ref, String rewardId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Delete reward?'),
        actions: [_CancelButton(), _ConfirmButton(label: 'Delete')],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).delete('/admin/seasons/$seasonId/rewards/$rewardId'));
    if (result == null) return;
    ref.invalidate(adminSeasonDetailProvider(seasonId));
    ref.invalidate(adminSeasonsProvider);
    showAdminMessage(context, 'Reward deleted.');
  }

  String _toIso(String input) {
    final parsed = DateTime.tryParse(input.trim());
    if (parsed == null) return input;
    return parsed.toUtc().toIso8601String();
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton();

  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'));
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(label));
}
