import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget { const LeaderboardScreen({super.key}); @override ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState(); }
class _Leaderboard extends ConsumerWidget {
  const _Leaderboard({required this.gameId});
  final String gameId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(leaderboardProvider(gameId));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const _LeaderboardState(icon: Icons.cloud_off_rounded, title: 'Leaderboard unavailable', message: 'Try again when the table is back online.'),
      data: (payload) {
        final entries = payload['entries'] as List? ?? const [];
        if (entries.isEmpty) return const _LeaderboardState(icon: Icons.emoji_events_outlined, title: 'No rankings yet', message: 'Play a ranked match to claim your place.');
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

class _LeaderboardState extends StatelessWidget {
  const _LeaderboardState({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 44, color: AppTheme.gold), const SizedBox(height: 13), Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center), const SizedBox(height: 6), Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)])));
}
