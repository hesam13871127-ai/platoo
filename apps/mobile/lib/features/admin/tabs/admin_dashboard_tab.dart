import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// Analytics dashboard: live totals, trend sparklines and per-game activity.
class AdminDashboardTab extends ConsumerStatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  ConsumerState<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends ConsumerState<AdminDashboardTab> {
  int _days = 14;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(adminOverviewProvider);
    final analytics = ref.watch(adminAnalyticsProvider(_days));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminOverviewProvider);
        ref.invalidate(adminAnalyticsProvider(_days));
      },
      child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        AdminAsync<Map<String, dynamic>>(
          value: overview,
          onRetry: () => ref.invalidate(adminOverviewProvider),
          builder: (data) {
            final users = Map<String, dynamic>.from(data['users'] as Map? ?? const {});
            final matches = Map<String, dynamic>.from(data['matches'] as Map? ?? const {});
            final reports = Map<String, dynamic>.from(data['reports'] as Map? ?? const {});
            final revenue = Map<String, dynamic>.from(data['revenue'] as Map? ?? const {});
            final economy = Map<String, dynamic>.from(data['economy'] as Map? ?? const {});
            return Column(children: [
              const AdminSectionHeader(title: 'At a glance', subtitle: 'Live platform health'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    AdminMetricCard(label: 'Total users', value: '${asInt(users['total'])}', icon: Icons.people_rounded, color: AppTheme.violet, caption: '+${asInt(users['newThisWeek'])} this week'),
                    AdminMetricCard(label: 'Active today', value: '${asInt(users['activeToday'])}', icon: Icons.bolt_rounded, color: AppTheme.mint, caption: '${asInt(users['activeThisMonth'])} in 30 days'),
                    AdminMetricCard(label: 'Live matches', value: '${asInt(matches['active'])}', icon: Icons.sports_esports_rounded, color: AppTheme.gold, caption: '${asInt(matches['startedToday'])} started today'),
                    AdminMetricCard(label: 'Open reports', value: '${asInt(reports['open'])}', icon: Icons.flag_rounded, color: AppTheme.coral, caption: '${asInt(reports['investigating'])} investigating'),
                    AdminMetricCard(label: 'Suspended', value: '${asInt(users['suspended'])}', icon: Icons.gavel_rounded, color: AppTheme.coral),
                    AdminMetricCard(label: 'Revenue', value: _money(asInt(revenue['amountMinor'])), icon: Icons.payments_rounded, color: AppTheme.mint, caption: '${_money(asInt(revenue['amountMinor30d']))} in 30 days'),
                    AdminMetricCard(label: 'Coins in circulation', value: '${asInt(economy['coins'])}', icon: Icons.circle, color: AppTheme.gold),
                    AdminMetricCard(label: 'Pips in circulation', value: '${asInt(economy['pips'])}', icon: Icons.brightness_1_rounded, color: AppTheme.violet),
                  ],
                ),
              ),
            ]);
          },
        ),
        AdminSectionHeader(
          title: 'Trends',
          subtitle: 'Last $_days days',
          trailing: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [ButtonSegment(value: 7, label: Text('7d')), ButtonSegment(value: 14, label: Text('14d')), ButtonSegment(value: 30, label: Text('30d'))],
            selected: {_days},
            onSelectionChanged: (value) => setState(() => _days = value.first),
          ),
        ),
        AdminAsync<Map<String, dynamic>>(
          value: analytics,
          onRetry: () => ref.invalidate(adminAnalyticsProvider(_days)),
          builder: (data) => Column(children: [
            _TrendCard(title: 'New signups', color: AppTheme.violet, series: _series(data['signups'])),
            _TrendCard(title: 'Matches created', color: AppTheme.mint, series: _series(data['matches'])),
            _TrendCard(title: 'Revenue (minor units)', color: AppTheme.gold, series: _series(data['revenue'])),
            const AdminSectionHeader(title: 'Activity by game'),
            for (final game in (data['games'] as List? ?? const []).map((g) => Map<String, dynamic>.from(g as Map)))
              ListTile(
                leading: Icon(asBool(game['isActive']) ? Icons.circle : Icons.circle_outlined, size: 12, color: asBool(game['isActive']) ? AppTheme.mint : Colors.grey),
                title: Text(game['displayName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${asInt(game['matches'])} matches · ${asInt(game['liveMatches'])} live'),
                trailing: Text('${asInt(game['finishedMatches'])} done', style: Theme.of(context).textTheme.bodySmall),
              ),
            const AdminSectionHeader(title: 'Top ranked players'),
            for (final player in (data['topPlayers'] as List? ?? const []).map((p) => Map<String, dynamic>.from(p as Map)))
              ListTile(
                leading: const Icon(Icons.emoji_events_rounded, color: AppTheme.gold, size: 20),
                title: Text(player['displayName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${asInt(player['wins'])} wins in ${asInt(player['gamesPlayed'])} games'),
                trailing: Text('${asInt(player['rating'])}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
          ]),
        ),
      ]),
    );
  }

  List<num> _series(Object? raw) => (raw as List? ?? const []).map((row) => asInt((row as Map)['value']) as num).toList();
  String _money(int minor) => '\$${(minor / 100).toStringAsFixed(2)}';
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.title, required this.color, required this.series});
  final String title;
  final Color color;
  final List<num> series;

  @override
  Widget build(BuildContext context) {
    final total = series.fold<num>(0, (sum, value) => sum + value);
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
            Text('$total total', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
          const SizedBox(height: 10),
          AdminSparkline(values: series, color: color),
        ]),
      ),
    );
  }
}
