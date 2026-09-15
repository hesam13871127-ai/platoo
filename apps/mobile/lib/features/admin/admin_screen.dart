import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
import 'admin_api.dart';
import 'admin_audit_tab.dart';
import 'admin_games_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_seasons_tab.dart';
import 'admin_shop_tab.dart';
import 'admin_users_tab.dart';

export 'admin_api.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 6),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    HapticFeedback.selectionClick();
    _tabController.animateTo(index);
  }

  void _refreshAll() {
    ref.invalidate(adminOverviewProvider);
    ref.invalidate(adminAnalyticsProvider);
    ref.invalidate(adminRecentMatchesProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminShopProvider);
    ref.invalidate(adminGamesProvider);
    ref.invalidate(adminReportsProvider);
    ref.invalidate(adminSeasonsProvider);
    ref.invalidate(adminAuditProvider);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final user = ref.watch(authProvider).value?.user;
    final role = user?.role;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    if (!isStaffRole(role)) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.adminConsole)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, color: scheme.onErrorContainer, size: 34),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Staff access required',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'This console is only available to authorized moderators and admins.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isAdmin = isAdminRole(role);
    final overviewAsync = ref.watch(adminOverviewProvider);
    final openReportsCount = (overviewAsync.valueOrNull?['reports'] as Map?)?['open'] as num? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(strings.adminConsole, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isAdmin ? AppTheme.gold : AppTheme.mint).withOpacity(.2),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: (isAdmin ? AppTheme.gold : AppTheme.mint).withOpacity(.5)),
              ),
              child: Text(
                isAdmin ? 'ADMIN' : 'STAFF',
                style: TextStyle(
                  color: isAdmin ? (dark ? AppTheme.gold : const Color(0xFFB45309)) : AppTheme.mint,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: .5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh telemetry',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              _refreshAll();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outline.withOpacity(dark ? .25 : .12))),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.violet,
              indicatorWeight: 3,
              labelColor: AppTheme.violet,
              unselectedLabelColor: scheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: [
                const Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Dashboard'),
                const Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Users'),
                Tab(
                  icon: Badge(
                    isLabelVisible: openReportsCount.toInt() > 0,
                    label: Text('${openReportsCount.toInt()}'),
                    child: const Icon(Icons.flag_rounded, size: 18),
                  ),
                  text: 'Reports',
                ),
                const Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'Shop'),
                const Tab(icon: Icon(Icons.sports_esports_rounded, size: 18), text: 'Games'),
                const Tab(icon: Icon(Icons.emoji_events_rounded, size: 18), text: 'Seasons'),
                const Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Audit'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdminDashboardTab(onSwitchTab: _switchTab),
          const AdminUsersTab(),
          const AdminReportsTab(),
          const AdminShopTab(),
          const AdminGamesTab(),
          const AdminSeasonsTab(),
          const AdminAuditTab(),
        ],
      ),
    );
  }
}

// =============================================================================
// Dashboard Tab
// =============================================================================
class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key, this.onSwitchTab});
  final ValueChanged<int>? onSwitchTab;

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
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(18),
        children: [
          // Quick Action Hub Navigation Cards
          if (onSwitchTab != null) ...[
            _QuickActionHub(onSwitchTab: onSwitchTab!, overview: overview.valueOrNull),
            const SizedBox(height: 22),
          ],

          // KPI Metrics Grid
          overview.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
            error: (error, _) => StatePanel(
              icon: Icons.error_outline_rounded,
              title: 'Overview unavailable',
              message: error.toString(),
            ),
            data: (data) => _Overview(data: data),
          ),

          const SizedBox(height: 26),

          // Activity Charts Section
          Row(
            children: [
              const Text('Activity & Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              SegmentedButton<int>(
                style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: 7, label: Text('7d')),
                  ButtonSegment(value: 30, label: Text('30d')),
                  ButtonSegment(value: 90, label: Text('90d')),
                ],
                selected: {days},
                onSelectionChanged: (value) {
                  HapticFeedback.selectionClick();
                  ref.read(adminDaysProvider.notifier).state = value.first;
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          analytics.when(
            loading: () => const VibeCard(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))),
            error: (error, _) => Text(error.toString()),
            data: (data) => _Analytics(data: data),
          ),

          const SizedBox(height: 26),

          // Recent Matches
          const Text('Recent live matches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          recent.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (items) => items.isEmpty
                ? const VibeCard(child: Padding(padding: EdgeInsets.all(18), child: Text('No matches recorded yet.')))
                : VibeCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.violet.withOpacity(.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.sports_esports_rounded, color: AppTheme.violet, size: 20),
                            ),
                            title: Text(strOf(items[i]['gameName'], 'Match'), style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${strOf(items[i]['mode'])} · ${intOf(items[i]['playerCount'])} players · ${dateLabel(items[i]['createdAt'])}'),
                            trailing: _StatusDot(status: strOf(items[i]['status'])),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// =============================================================================
// Quick Action Hub for Instant Tab Navigation
// =============================================================================
class _QuickActionHub extends StatelessWidget {
  const _QuickActionHub({required this.onSwitchTab, this.overview});
  final ValueChanged<int> onSwitchTab;
  final Map<String, dynamic>? overview;

  @override
  Widget build(BuildContext context) {
    final openReports = (overview?['reports'] as Map?)?['open'] as num? ?? 0;
    final totalUsers = (overview?['users'] as Map?)?['active'] as num? ?? 0;
    final activeGames = (overview?['games'] as Map?)?['active'] as num? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Navigation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            _HubActionTile(
              label: 'Users',
              subtitle: '$totalUsers active',
              icon: Icons.people_alt_rounded,
              color: AppTheme.violet,
              onTap: () => onSwitchTab(1),
            ),
            _HubActionTile(
              label: 'Reports',
              subtitle: openReports.toInt() > 0 ? '${openReports.toInt()} open' : 'All clear',
              icon: Icons.flag_rounded,
              color: openReports.toInt() > 0 ? AppTheme.coral : AppTheme.mint,
              badge: openReports.toInt() > 0 ? '${openReports.toInt()}' : null,
              onTap: () => onSwitchTab(2),
            ),
            _HubActionTile(
              label: 'Shop',
              subtitle: 'Cosmetics',
              icon: Icons.storefront_rounded,
              color: AppTheme.gold,
              onTap: () => onSwitchTab(3),
            ),
            _HubActionTile(
              label: 'Games',
              subtitle: '$activeGames active',
              icon: Icons.sports_esports_rounded,
              color: AppTheme.mint,
              onTap: () => onSwitchTab(4),
            ),
            _HubActionTile(
              label: 'Seasons',
              subtitle: 'Ranked rewards',
              icon: Icons.emoji_events_rounded,
              color: AppTheme.fuchsia,
              onTap: () => onSwitchTab(5),
            ),
            _HubActionTile(
              label: 'Audit Log',
              subtitle: 'History',
              icon: Icons.history_rounded,
              color: const Color(0xFF4F7CAC),
              onTap: () => onSwitchTab(6),
            ),
          ],
        ),
      ],
    );
  }
}

class _HubActionTile extends StatelessWidget {
  const _HubActionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(dark ? .35 : .2)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(dark ? .15 : .08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: AppTheme.coralGradient,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// KPI Telemetry Grid
// =============================================================================
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
      childAspectRatio: 1.5,
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
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(dark ? .3 : .15)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(dark ? .15 : .06), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.3)),
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// =============================================================================
// Activity Charts
// =============================================================================
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
          VibeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Top games by matches', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 12),
                for (final row in asItemList(data['matchesByGame']))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(strOf(row['gameName'], strOf(row['gameId'])), style: const TextStyle(fontWeight: FontWeight.w700))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.violet.withOpacity(.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${intOf(row['matches'])} matches', style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w800, fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ),
              ],
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

    return VibeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$total total', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (points.isEmpty)
            const Text('No telemetry data available for this timeframe.')
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
                            heightFactor: (intOf(point['value']) / max).clamp(0.06, 1.0).toDouble(),
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
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
