import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_games_tab.dart';
import 'tabs/admin_reports_tab.dart';
import 'tabs/admin_seasons_tab.dart';
import 'tabs/admin_shop_tab.dart';
import 'tabs/admin_users_tab.dart';

/// The admin console shell. The API is the source of truth for access control,
/// but the client also gates the screen so a player never sees the entry point
/// and a moderator only sees the sections they are allowed to use.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).value?.user.role ?? 'player';
    if (role != 'admin' && role != 'moderator') return const _AccessDenied();
    final isAdmin = role == 'admin';

    final tabs = <({String label, IconData icon, Widget view})>[
      (label: 'Dashboard', icon: Icons.insights_rounded, view: const AdminDashboardTab()),
      (label: 'Users', icon: Icons.people_alt_rounded, view: AdminUsersTab(isAdmin: isAdmin)),
      (label: 'Reports', icon: Icons.flag_rounded, view: const AdminReportsTab()),
      (label: 'Shop', icon: Icons.storefront_rounded, view: AdminShopTab(isAdmin: isAdmin)),
      (label: 'Games', icon: Icons.sports_esports_rounded, view: AdminGamesTab(isAdmin: isAdmin)),
      (label: 'Seasons', icon: Icons.emoji_events_rounded, view: AdminSeasonsTab(isAdmin: isAdmin)),
      if (isAdmin) (label: 'Audit', icon: Icons.receipt_long_rounded, view: const _AuditTab()),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin console', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(child: AdminStatusChip(label: role, color: isAdmin ? AppTheme.violet : AppTheme.gold)),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in tabs) Tab(icon: Icon(tab.icon, size: 19), text: tab.label)],
          ),
        ),
        body: TabBarView(children: [for (final tab in tabs) tab.view]),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admin console')),
        body: const Center(
          child: AdminEmpty(
            icon: Icons.lock_rounded,
            title: 'Staff access only',
            message: 'This console is restricted to moderator and admin accounts.',
          ),
        ),
      );
}

/// A read-only trail of every change made through the console.
class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(adminAuditProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminAuditProvider),
      child: AdminAsync<List<Map<String, dynamic>>>(
        value: entries,
        onRetry: () => ref.invalidate(adminAuditProvider),
        builder: (list) => list.isEmpty
            ? const AdminEmpty(icon: Icons.receipt_long_rounded, title: 'No admin activity yet', message: 'Every change made here is recorded for review.')
            : ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                const AdminSectionHeader(title: 'Audit log', subtitle: 'Most recent changes first'),
                for (final entry in list)
                  ListTile(
                    leading: const Icon(Icons.history_rounded, size: 20),
                    title: Text(entry['action']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${entry['adminName']} · ${entry['entityType']} ${entry['entityId'] ?? ''}\n${shortDate(entry['createdAt'])}'),
                    isThreeLine: true,
                  ),
              ]),
      ),
    );
  }
}
