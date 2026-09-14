import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'admin_api.dart';
import 'admin_audit_tab.dart';
import 'admin_games_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_seasons_tab.dart';
import 'admin_shop_tab.dart';
import 'admin_users_tab.dart';

export 'admin_api.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).value?.user.role;
    if (!isStaffRole(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin console')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, color: Theme.of(context).colorScheme.onErrorContainer, size: 30),
                ),
                const SizedBox(height: 16),
                const Text('Admin access required', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
                const SizedBox(height: 8),
                const Text(
                  'This console is only available to moderators and admins.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin console', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(adminOverviewProvider);
                ref.invalidate(adminAnalyticsProvider);
                ref.invalidate(adminRecentMatchesProvider);
                ref.invalidate(adminUsersProvider);
                ref.invalidate(adminShopProvider);
                ref.invalidate(adminGamesProvider);
                ref.invalidate(adminReportsProvider);
                ref.invalidate(adminSeasonsProvider);
                ref.invalidate(adminAuditProvider);
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Users'),
              Tab(text: 'Reports'),
              Tab(text: 'Shop'),
              Tab(text: 'Games'),
              Tab(text: 'Seasons'),
              Tab(text: 'Audit'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminDashboardTab(),
            AdminUsersTab(),
            AdminReportsTab(),
            AdminShopTab(),
            AdminGamesTab(),
            AdminSeasonsTab(),
            AdminAuditTab(),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(adminOverviewProvider);
    final analytics = ref.watch(adminAnalyticsProvider);
    final recent = ref.watch(adminRecentMatchesProvider);
    final days = ref.watch(adminDaysProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminOverviewProvider);
        ref.invalidate(adminAnalyticsProvider);
        ref.invalidate(adminRecentMatchesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          overview.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(error.toString()),
            data: (data) => _Overview(data: data),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Text('Activity', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const Spacer(),
              SegmentedButton<int>(
                style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 7, label: Text('7d')),
                  ButtonSegment(value: 30, label: Text('30d')),
                  ButtonSegment(value: 90, label: Text('90d')),
                ],
                selected: {days},
                onSelectionChanged: (value) => ref.read(adminDaysProvider.notifier).state = value.first,
              ),
            ],
          ),
          const SizedBox(height: 12),
          analytics.when(
            loading: () => const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))),
            error: (error, _) => Text(error.toString()),
            data: (data) => _Analytics(data: data),
          ),
          const SizedBox(height: 26),
          const Text('Recent matches', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          recent.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (items) => items.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No matches yet.')))
                : Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            dense: true,
                            title: Text(strOf(items[i]['gameName'], 'Match'), style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${strOf(items[i]['mode'])} · ${intOf(items[i]['playerCount'])} players · ${dateLabel(items[i]['createdAt'])}'),
                            trailing: _StatusDot(status: strOf(items[i]['status'])),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final users = Map<String, dynamic>.from(data['users'] as Map? ?? const {});
    final matches = Map<String, dynamic>.from(data['matches'] as Map? ?? const {});
    final reports = Map<String, dynamic>.from(data['reports'] as Map? ?? const {});
    final revenue = Map<String, dynamic>.from(data['revenue'] as Map? ?? const {});
    final activity = Map<String, dynamic>.from(data['activity'] as Map? ?? const {});
    final games = Map<String, dynamic>.from(data['games'] as Map? ?? const {});
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _Metric(label: 'Active users', value: '${intOf(users['active'])}', icon: Icons.people_rounded, color: AppTheme.violet),
        _Metric(label: 'Online today', value: '${intOf(users['dau'])}', icon: Icons.bolt_rounded, color: AppTheme.gold),
        _Metric(label: 'Live matches', value: '${intOf(matches['active'])}', icon: Icons.sports_esports_rounded, color: AppTheme.mint),
        _Metric(label: 'Matches today', value: '${intOf(matches['today'])}', icon: Icons.stadium_rounded, color: AppTheme.mint),
        _Metric(label: 'Open reports', value: '${intOf(reports['open'])}', icon: Icons.flag_rounded, color: AppTheme.coral),
        _Metric(label: 'New users (7d)', value: '${intOf(users['newWeek'])}', icon: Icons.person_add_rounded, color: AppTheme.violet),
        _Metric(label: 'Players today', value: '${intOf(activity['activePlayers'])}', icon: Icons.groups_rounded, color: AppTheme.mint),
        _Metric(label: 'Games live', value: '${intOf(games['active'])}/${intOf(games['total'])}', icon: Icons.videogame_asset_rounded, color: AppTheme.gold),
        _Metric(label: 'Revenue (paid)', value: _money(intOf(revenue['amountMinor'])), icon: Icons.payments_rounded, color: AppTheme.gold),
        _Metric(label: 'Suspended', value: '${intOf(users['suspended'])}', icon: Icons.gavel_rounded, color: AppTheme.coral),
      ],
    );
  }

  String _money(int minor) {
    if (minor >= 100) return '\$${(minor / 100).toStringAsFixed(2)}';
    return '\$$minor¢'.replaceAll('\$0¢', '\$0');
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
}

class _Analytics extends StatelessWidget {
  const _Analytics({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          _ChartCard(
            title: 'New users',
            color: AppTheme.violet,
            points: asSeries(data['signupsByDay']),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Matches',
            color: AppTheme.mint,
            points: asSeries(data['matchesByDay']),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Active players',
            color: AppTheme.coral,
            points: asSeries(data['activePlayersByDay']),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top games', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  for (final row in asItemList(data['matchesByGame']))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(strOf(row['gameName'], strOf(row['gameId'])), style: const TextStyle(fontWeight: FontWeight.w700))),
                          Text('${intOf(row['matches'])} matches', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.color, required this.points});
  final String title;
  final Color color;
  final List<Map<String, dynamic>> points;

  @override
  Widget build(BuildContext context) {
    var max = 0;
    var total = 0;
    for (final point in points) {
      final value = intOf(point['value']);
      total += value;
      if (value > max) max = value;
    }
    if (max == 0) max = 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('$total total', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            if (points.isEmpty)
              const Text('No data yet.')
            else
              SizedBox(
                height: 110,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in points)
                      Expanded(
                        child: Tooltip(
                          message: '${dateLabel(point['day'])} · ${intOf(point['value'])}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1.5),
                            child: FractionallySizedBox(
                              heightFactor: (intOf(point['value']) / max).clamp(0.05, 1.0).toDouble(),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color.withOpacity(.85),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppTheme.mint,
      'finished' => AppTheme.violet,
      'waiting' => AppTheme.gold,
      _ => Theme.of(context).colorScheme.outline,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(status, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
