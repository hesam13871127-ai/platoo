import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// Season management: schedule a season, activate it, define ranked reward
/// tiers and close it out so the ranking service pays those rewards.
class AdminSeasonsTab extends ConsumerWidget {
  const AdminSeasonsTab({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasons = ref.watch(adminSeasonsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(onPressed: () => _create(context, ref), icon: const Icon(Icons.add_rounded), label: const Text('New season'))
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminSeasonsProvider),
        child: AdminAsync<List<Map<String, dynamic>>>(
          value: seasons,
          onRetry: () => ref.invalidate(adminSeasonsProvider),
          builder: (list) => ListView(padding: const EdgeInsets.only(bottom: 90), children: [
            const AdminSectionHeader(title: 'Seasons', subtitle: 'Only one season can be active at a time.'),
            if (list.isEmpty)
              const AdminEmpty(icon: Icons.emoji_events_outlined, title: 'No seasons yet', message: 'Schedule the first ranked season to start awarding rewards.')
            else
              for (final season in list) _SeasonCard(season: season, isAdmin: isAdmin),
          ]),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    var startsAt = DateTime.now();
    var endsAt = DateTime.now().add(const Duration(days: 30));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Schedule a season'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Season name')),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Starts'),
              subtitle: Text(startsAt.toLocal().toString().split('.').first),
              trailing: const Icon(Icons.calendar_today_rounded, size: 18),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: startsAt, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
                if (picked != null) setState(() => startsAt = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ends'),
              subtitle: Text(endsAt.toLocal().toString().split('.').first),
              trailing: const Icon(Icons.event_rounded, size: 18),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: endsAt, firstDate: startsAt.add(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
                if (picked != null) setState(() => endsAt = picked);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (confirmed == true && name.text.trim().length >= 2 && endsAt.isAfter(startsAt)) {
      try {
        await ref.read(adminRepositoryProvider).createSeason(name.text.trim(), startsAt, endsAt);
        ref.invalidate(adminSeasonsProvider);
        await showAdminMessage(context, 'Season scheduled.');
      } catch (error) {
        await showAdminError(context, error);
      }
    } else if (confirmed == true) {
      await showAdminError(context, 'Give the season a name and an end date after the start date.');
    }
    name.dispose();
  }
}

class _SeasonCard extends ConsumerWidget {
  const _SeasonCard({required this.season, required this.isAdmin});
  final Map<String, dynamic> season;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = season['status']?.toString() ?? 'scheduled';
    final id = season['id'].toString();
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(season['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            AdminStatusChip(label: status, color: statusColor(status)),
          ]),
          const SizedBox(height: 6),
          Text('${shortDate(season['startsAt'])} → ${shortDate(season['endsAt'])}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            AdminStatusChip(label: '${asInt(season['rewardCount'])} reward tiers', color: AppTheme.gold),
            AdminStatusChip(label: '${asInt(season['participants'])} participants', color: AppTheme.mint),
          ]),
          const Divider(height: 22),
          _Rewards(seasonId: id, isAdmin: isAdmin && status != 'finished'),
          if (isAdmin)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (status != 'finished')
                TextButton.icon(onPressed: () => _addReward(context, ref, id), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Reward tier')),
              if (status == 'scheduled')
                FilledButton(onPressed: () => _run(context, ref, () => ref.read(adminRepositoryProvider).activateSeason(id), 'Season activated.'), child: const Text('Activate')),
              if (status == 'active')
                FilledButton(
                  onPressed: () => _finish(context, ref, id),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
                  child: const Text('Finish & pay out'),
                ),
            ]),
        ]),
      ),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, String success) async {
    try {
      await action();
      ref.invalidate(adminSeasonsProvider);
      await showAdminMessage(context, success);
    } catch (error) {
      await showAdminError(context, error);
    }
  }

  Future<void> _finish(BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finish this season?'),
        content: const Text('Rewards are paid to the ranked leaderboard immediately and the season is closed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: AppTheme.coral), child: const Text('Finish')),
        ],
      ),
    );
    if (confirmed == true) await _run(context, ref, () => ref.read(adminRepositoryProvider).finishSeason(id), 'Season finished and rewards paid.');
  }

  Future<void> _addReward(BuildContext context, WidgetRef ref, String seasonId) async {
    final minRank = TextEditingController(text: '1');
    final maxRank = TextEditingController(text: '10');
    final coins = TextEditingController(text: '0');
    final pips = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add a reward tier'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: TextField(controller: minRank, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'From rank'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: maxRank, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'To rank'))),
          ]),
          Row(children: [
            Expanded(child: TextField(controller: coins, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coins'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: pips, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pips'))),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(adminRepositoryProvider).createReward(seasonId, {
          'minRank': int.tryParse(minRank.text.trim()) ?? 1,
          'maxRank': int.tryParse(maxRank.text.trim()) ?? 1,
          'coins': int.tryParse(coins.text.trim()) ?? 0,
          'pips': int.tryParse(pips.text.trim()) ?? 0,
        });
        ref.invalidate(adminSeasonRewardsProvider(seasonId));
        ref.invalidate(adminSeasonsProvider);
        await showAdminMessage(context, 'Reward tier added.');
      } catch (error) {
        await showAdminError(context, error);
      }
    }
    for (final controller in [minRank, maxRank, coins, pips]) controller.dispose();
  }
}

class _Rewards extends ConsumerWidget {
  const _Rewards({required this.seasonId, required this.isAdmin});
  final String seasonId;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(adminSeasonRewardsProvider(seasonId));
    return rewards.maybeWhen(
      data: (list) => list.isEmpty
          ? Text('No reward tiers defined yet.', style: Theme.of(context).textTheme.bodySmall)
          : Column(children: [
              for (final reward in list)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.workspace_premium_rounded, color: AppTheme.gold, size: 20),
                  title: Text('Ranks ${reward['minRank']}–${reward['maxRank']}'),
                  subtitle: Text('${asInt(reward['coins'])} coins · ${asInt(reward['pips'])} pips${reward['shopItemName'] == null ? '' : ' · ${reward['shopItemName']}'}'),
                  trailing: isAdmin
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.coral),
                          onPressed: () async {
                            try {
                              await ref.read(adminRepositoryProvider).deleteReward(reward['id'].toString());
                              ref.invalidate(adminSeasonRewardsProvider(seasonId));
                              ref.invalidate(adminSeasonsProvider);
                            } catch (error) {
                              await showAdminError(context, error);
                            }
                          },
                        )
                      : null,
                ),
            ]),
      orElse: () => const SizedBox(height: 8),
    );
  }
}
