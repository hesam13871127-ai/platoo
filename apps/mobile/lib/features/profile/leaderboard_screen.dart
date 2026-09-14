import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_panel.dart';
import '../home/home_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget { const LeaderboardScreen({super.key}); @override ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState(); }
class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String? gameId;
  @override
  Widget build(BuildContext context) {
    final games = ref.watch(gamesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Season leaderboard')),
      body: games.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatePanel(icon: Icons.cloud_off_rounded, title: 'Leaderboard unavailable', message: 'We could not load the games.', actionLabel: 'Try again', onAction: () => ref.invalidate(gamesProvider)),
        data: (list) {
          if (list.isEmpty) return const StatePanel(icon: Icons.emoji_events_outlined, title: 'No games yet', message: 'Rankings will appear once tables open.');
          final selected = list.any((game) => game.id == gameId) ? gameId! : list.first.id;
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: DropdownButtonFormField<String>(value: selected, decoration: const InputDecoration(labelText: 'Game'), items: [for (final game in list) DropdownMenuItem(value: game.id, child: Text(game.name))], onChanged: (value) => setState(() => gameId = value))),
            Expanded(child: _Leaderboard(gameId: selected)),
          ]);
        },
      ),
    );
  }
}
class _Leaderboard extends ConsumerWidget {
  const _Leaderboard({required this.gameId});
  final String gameId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(leaderboardProvider(gameId));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StatePanel(icon: Icons.cloud_off_rounded, title: 'Leaderboard unavailable', message: 'We could not load the rankings.', actionLabel: 'Try again', onAction: () => ref.invalidate(leaderboardProvider(gameId))),
      data: (payload) {
        final entries = payload['entries'] as List? ?? const [];
        if (entries.isEmpty) return const StatePanel(icon: Icons.emoji_events_outlined, title: 'No rankings yet', message: 'Play a ranked match to claim your place.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final entry = Map<String, dynamic>.from(entries[index] as Map);
            final rank = (entry['rank'] as num?)?.toInt() ?? index + 1;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: rank <= 3 ? AppTheme.gold.withOpacity(.2) : AppTheme.violet.withOpacity(.12),
                  child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                title: Text(entry['displayName']?.toString() ?? 'Player', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${entry['wins'] ?? 0} wins · ${entry['gamesPlayed'] ?? 0} games'),
                trailing: Text('${entry['rating'] ?? 1000}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ),
            );
          },
        );
      },
    );
  }
}

final leaderboardProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, gameId) async => Map<String, dynamic>.from(await ref.watch(apiClientProvider).get('/ranking/$gameId/leaderboard') as Map));

