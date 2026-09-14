import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// Game management: enable or disable each title, individually or in bulk.
/// Disabling a game also clears its matchmaking queue on the server.
class AdminGamesTab extends ConsumerWidget {
  const AdminGamesTab({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(adminGamesProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminGamesProvider),
      child: AdminAsync<List<Map<String, dynamic>>>(
        value: games,
        onRetry: () => ref.invalidate(adminGamesProvider),
        builder: (list) {
          final enabled = list.where((game) => asBool(game['isActive'])).length;
          return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            AdminSectionHeader(
              title: '$enabled of ${list.length} games live',
              subtitle: 'Turning a game off hides it from the lobby and clears its queue.',
              trailing: isAdmin
                  ? PopupMenuButton<bool>(
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) => _bulk(context, ref, list, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: true, child: Text('Enable all games')),
                        PopupMenuItem(value: false, child: Text('Disable all games')),
                      ],
                    )
                  : null,
            ),
            if (list.isEmpty)
              const AdminEmpty(icon: Icons.sports_esports_outlined, title: 'No games registered', message: 'Seed the games table to populate the lobby.')
            else
              for (final game in list) _GameTile(game: game, isAdmin: isAdmin),
          ]);
        },
      ),
    );
  }

  Future<void> _bulk(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> list, bool isActive) async {
    final ids = list.map((game) => game['id'].toString()).toList();
    try {
      await ref.read(adminRepositoryProvider).bulkToggleGames(ids, isActive);
      ref.invalidate(adminGamesProvider);
      await showAdminMessage(context, isActive ? 'All games enabled.' : 'All games disabled.');
    } catch (error) {
      await showAdminError(context, error);
    }
  }
}

class _GameTile extends ConsumerWidget {
  const _GameTile({required this.game, required this.isAdmin});
  final Map<String, dynamic> game;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = asBool(game['isActive']);
    final live = asInt(game['liveMatches']);
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: (active ? AppTheme.mint : Colors.grey).withOpacity(.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(active ? Icons.play_arrow_rounded : Icons.pause_rounded, color: active ? AppTheme.mint : Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(game['displayName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Wrap(spacing: 6, runSpacing: 4, children: [
                AdminStatusChip(label: game['category']?.toString() ?? '', color: AppTheme.violet),
                AdminStatusChip(label: '${game['minPlayers']}–${game['maxPlayers']} players', color: AppTheme.gold),
                if (live > 0) AdminStatusChip(label: '$live live', color: AppTheme.mint),
                AdminStatusChip(label: '${asInt(game['matchesThisWeek'])} this week', color: AppTheme.coral),
              ]),
            ]),
          ),
          if (isAdmin)
            Switch(
              value: active,
              onChanged: (value) async {
                if (!value && live > 0) {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('Disable ${game['displayName']}?'),
                      content: Text('$live match(es) are still running. They will finish normally, but no new tables can be opened.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disable')),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                }
                try {
                  await ref.read(adminRepositoryProvider).toggleGame(game['id'].toString(), value);
                  ref.invalidate(adminGamesProvider);
                } catch (error) {
                  await showAdminError(context, error);
                }
              },
            )
          else
            AdminStatusChip(label: active ? 'live' : 'off', color: active ? AppTheme.mint : Colors.grey),
        ]),
      ),
    );
  }
}
