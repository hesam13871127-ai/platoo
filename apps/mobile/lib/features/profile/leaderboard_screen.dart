import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/player_avatar.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../home/home_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String? gameId;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final games = ref.watch(gamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.15), shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_rounded, color: AppTheme.gold, size: 20),
            ),
            const SizedBox(width: 10),
            Text(strings.isPersian ? 'جدول امتیازات فصل' : 'Season Leaderboard', style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
      body: VibePageBackground(
        child: games.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => StatePanel(
            icon: Icons.cloud_off_rounded,
            title: strings.isPersian ? 'جدول امتیازات در دسترس نیست' : 'Leaderboard unavailable',
            message: strings.isPersian ? 'نتوانستیم لیست بازی‌ها را بارگذاری کنیم.' : 'We could not load the games catalog.',
            actionLabel: strings.retry,
            onAction: () => ref.invalidate(gamesProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return StatePanel(
                icon: Icons.emoji_events_outlined,
                title: strings.isPersian ? 'بازی یافت نشد' : 'No games yet',
                message: strings.isPersian ? 'رده‌بندی‌ها پس از انجام بازی‌های رتبه‌ای فعال می‌شوند.' : 'Rankings will appear once ranked tables open.',
              );
            }
            final selected = list.any((game) => game.id == gameId) ? gameId! : list.first.id;
            final selectedGame = list.firstWhere((g) => g.id == selected, orElse: () => list.first);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: VibeCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        GameLogo(gameId: selectedGame.id, accent: selectedGame.accent, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selected,
                              isExpanded: true,
                              items: [
                                for (final game in list)
                                  DropdownMenuItem(
                                    value: game.id,
                                    child: Text(
                                      game.name,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                    ),
                                  ),
                              ],
                              onChanged: (value) => setState(() => gameId = value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _Leaderboard(gameId: selected)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Leaderboard extends ConsumerWidget {
  const _Leaderboard({required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(Localizations.localeOf(context));
    final data = ref.watch(leaderboardProvider(gameId));
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StatePanel(
        icon: Icons.cloud_off_rounded,
        title: strings.isPersian ? 'رده‌بندی در دسترس نیست' : 'Leaderboard unavailable',
        message: strings.isPersian ? 'نتوانستیم رده‌بندی را بارگذاری کنیم.' : 'We could not load the rankings. Pull to retry.',
        actionLabel: strings.retry,
        onAction: () => ref.invalidate(leaderboardProvider(gameId)),
      ),
      data: (payload) {
        final entries = payload['entries'] as List? ?? const [];
        if (entries.isEmpty) {
          return StatePanel(
            icon: Icons.emoji_events_outlined,
            title: strings.isPersian ? 'هنوز رتبه‌ای ثبت نشده' : 'No rankings yet',
            message: strings.isPersian ? 'در یک مسابقه رتبه‌ای بازی کن تا اسمت در جدول ثبت شود!' : 'Play a ranked match to claim your place on the leaderboard.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(leaderboardProvider(gameId)),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final entry = Map<String, dynamic>.from(entries[index] as Map);
              final rank = (entry['rank'] as num?)?.toInt() ?? index + 1;
              final isTop3 = rank <= 3;
              final medalColor = rank == 1
                  ? AppTheme.gold
                  : rank == 2
                      ? const Color(0xFFC0C0C0)
                      : rank == 3
                          ? const Color(0xFFCD7F32)
                          : AppTheme.violet;

              return Entrance(
                delay: Duration(milliseconds: (index % 10) * 35),
                child: VibeCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: medalColor.withOpacity(.14),
                          shape: BoxShape.circle,
                          border: isTop3 ? Border.all(color: medalColor.withOpacity(.5), width: 1.5) : null,
                        ),
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: isTop3 ? medalColor : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      VibeInitial(name: entry['displayName']?.toString() ?? 'P', radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry['displayName']?.toString() ?? 'Player',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              strings.isPersian
                                  ? '${entry['wins'] ?? 0} برد · ${entry['gamesPlayed'] ?? 0} بازی'
                                  : '${entry['wins'] ?? 0} wins · ${entry['gamesPlayed'] ?? 0} matches',
                              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.violet.withOpacity(dark ? .2 : .1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.violet.withOpacity(.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: AppTheme.gold),
                            const SizedBox(width: 4),
                            Text(
                              '${entry['rating'] ?? 1000}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTheme.violet),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

final leaderboardProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, gameId) async =>
    Map<String, dynamic>.from(await ref.watch(apiClientProvider).get('/ranking/$gameId/leaderboard') as Map));
