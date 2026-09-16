import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'admin_api.dart';

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetPage() => ref.read(adminUserPageProvider.notifier).state = 0;

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    final status = ref.watch(adminUserStatusProvider);
    final role = ref.watch(adminUserRoleProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search username, name, phone, email…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _search.clear();
                        ref.read(adminUserSearchProvider.notifier).state = '';
                        _resetPage();
                        setState(() {});
                      },
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (value) {
              ref.read(adminUserSearchProvider.notifier).state = value.trim();
              _resetPage();
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _FilterChip(label: 'All statuses', selected: status == null, onTap: () { ref.read(adminUserStatusProvider.notifier).state = null; _resetPage(); }),
              for (final s in const ['active', 'suspended', 'deleted'])
                _FilterChip(label: s, selected: status == s, onTap: () { ref.read(adminUserStatusProvider.notifier).state = s; _resetPage(); }),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: VibeText('·')),
              _FilterChip(label: 'All roles', selected: role == null, onTap: () { ref.read(adminUserRoleProvider.notifier).state = null; _resetPage(); }),
              for (final r in const ['player', 'moderator', 'admin'])
                _FilterChip(label: r, selected: role == r, onTap: () { ref.read(adminUserRoleProvider.notifier).state = r; _resetPage(); }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: users.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: VibeText(error.toString())),
            data: (page) => page.items.isEmpty
                ? const Center(child: VibeText('No users match these filters.'))
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(adminUsersProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: page.items.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == page.items.length) {
                          return _Pager(
                            page: page.page,
                            totalPages: page.totalPages,
                            total: page.total,
                            onPrev: page.page > 0 ? () => ref.read(adminUserPageProvider.notifier).state = page.page - 1 : null,
                            onNext: page.page + 1 < page.totalPages ? () => ref.read(adminUserPageProvider.notifier).state = page.page + 1 : null,
                          );
                        }
                        final user = page.items[index];
                        final name = strOf(user['displayName'], 'Player');
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.violet.withOpacity(.15),
                              child: VibeText(
                                name.isEmpty ? '?' : name[0].toUpperCase(),
                                style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900),
                              ),
                            ),
                            title: VibeText(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: VibeText('@${strOf(user['username'])} · Lv ${intOf(user['level'], 1)} · ${intOf(user['coins'])} coins'),
                            trailing: _UserStatusBadge(status: strOf(user['status']), role: strOf(user['role'])),
                            onTap: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (_) => _UserDetailSheet(userId: strOf(user['id'])),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: VibeText(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.totalPages, required this.total, this.onPrev, this.onNext});
  final int page;
  final int totalPages;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: VibeText('Page ${page + 1} of ${totalPages == 0 ? 1 : totalPages} · $total total', style: const TextStyle(fontSize: 12)),
            ),
            IconButton.filledTonal(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
      );
}

class _UserStatusBadge extends StatelessWidget {
  const _UserStatusBadge({required this.status, required this.role});
  final String status;
  final String role;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppTheme.mint,
      'suspended' => AppTheme.coral,
      _ => Theme.of(context).colorScheme.outline,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
          child: VibeText(status, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const SizedBox(height: 2),
        VibeText(role, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _UserDetailSheet extends ConsumerWidget {
  const _UserDetailSheet({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminUserDetailProvider(userId));
    final role = ref.watch(authProvider).value?.user.role;
    final admin = isAdminRole(role);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: detail.when(
          loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          error: (error, _) => Padding(padding: const EdgeInsets.all(24), child: VibeText(error.toString())),
          data: (data) {
            final user = Map<String, dynamic>.from(data['user'] as Map);
            final stats = Map<String, dynamic>.from(data['stats'] as Map? ?? const {});
            final recentMatches = asItemList(data['recentMatches']);
            final against = asItemList(data['reportsAgainst']);
            final suspended = strOf(user['status']) == 'suspended';
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.violet.withOpacity(.15),
                        child: VibeText(
                          strOf(user['displayName'], '?').isEmpty ? '?' : strOf(user['displayName'], '?')[0].toUpperCase(),
                          style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900, fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            VibeText(strOf(user['displayName'], 'Player'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            VibeText('@${strOf(user['username'])} · ${strOf(user['role'])} · Lv ${intOf(user['level'], 1)}',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      _UserStatusBadge(status: strOf(user['status']), role: strOf(user['role'])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(icon: Icons.circle, label: '${intOf(user['coins'])} coins', color: AppTheme.gold),
                      _InfoChip(icon: Icons.brightness_1_rounded, label: '${intOf(user['pips'])} pips', color: AppTheme.violet),
                      _InfoChip(icon: Icons.stadium_rounded, label: '${intOf(stats['matchesPlayed'])} matches', color: AppTheme.mint),
                      _InfoChip(icon: Icons.people_rounded, label: '${intOf(stats['friends'])} friends', color: AppTheme.violet),
                      _InfoChip(icon: Icons.flag_rounded, label: '${against.length} reports', color: AppTheme.coral),
                    ],
                  ),
                  const SizedBox(height: 12),
                  VibeText('Joined ${dateLabel(user['createdAt'])} · last seen ${dateLabel(user['lastSeenAt'])}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  if (strOf(user['phone']).isNotEmpty || strOf(user['email']).isNotEmpty)
                    VibeText('${strOf(user['phone'])} ${strOf(user['email'])}'.trim(),
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  const VibeText('Recent matches', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  if (recentMatches.isEmpty)
                    const VibeText('No matches played yet.')
                  else
                    for (final match in recentMatches.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(child: VibeText(strOf(match['gameName'], strOf(match['gameId'])))),
                            VibeText('${strOf(match['result'], '—')} · ${dateLabel(match['createdAt'])}',
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                  const SizedBox(height: 16),
                  if (!admin)
                    const VibeText('User moderation actions require an admin account.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (suspended)
                          FilledButton.icon(
                            onPressed: () => _unban(context, ref),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const VibeText('Unban'),
                          )
                        else
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
                            onPressed: () => _ban(context, ref),
                            icon: const Icon(Icons.gavel_rounded),
                            label: const VibeText('Ban'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _changeRole(context, ref, strOf(user['role'])),
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: const VibeText('Role'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _adjustWallet(context, ref),
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const VibeText('Wallet'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _ban(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const VibeText('Ban user'),
        content: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (shown to the user)', hintText: 'Violation of community rules'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const VibeText('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const VibeText('Ban')),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).post('/admin/users/$userId/ban', data: {'reason': text}));
    if (result == null || !context.mounted) return;
    ref.invalidate(adminUserDetailProvider(userId));
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminOverviewProvider);
    showAdminMessage(context, 'User banned.');
    Navigator.pop(context);
  }

  Future<void> _unban(BuildContext context, WidgetRef ref) async {
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).post('/admin/users/$userId/unban'));
    if (result == null || !context.mounted) return;
    ref.invalidate(adminUserDetailProvider(userId));
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminOverviewProvider);
    showAdminMessage(context, 'User unbanned.');
    Navigator.pop(context);
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref, String current) async {
    var selected = current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const VibeText('Change role'),
          content: DropdownButtonFormField<String>(
            value: selected,
            items: const [
              DropdownMenuItem(value: 'player', child: VibeText('player')),
              DropdownMenuItem(value: 'moderator', child: VibeText('moderator')),
              DropdownMenuItem(value: 'admin', child: VibeText('admin')),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => selected = value);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const VibeText('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const VibeText('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).patch('/admin/users/$userId', data: {'role': selected}));
    if (result == null || !context.mounted) return;
    ref.invalidate(adminUserDetailProvider(userId));
    ref.invalidate(adminUsersProvider);
    showAdminMessage(context, 'Role updated to $selected.');
    Navigator.pop(context);
  }

  Future<void> _adjustWallet(BuildContext context, WidgetRef ref) async {
    final coins = TextEditingController(text: '0');
    final pips = TextEditingController(text: '0');
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const VibeText('Adjust wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: TextField(controller: coins, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coins ±'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: pips, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pips ±'))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason (required)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const VibeText('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const VibeText('Apply')),
        ],
      ),
    );
    final payload = {'coins': int.tryParse(coins.text.trim()) ?? 0, 'pips': int.tryParse(pips.text.trim()) ?? 0, 'reason': reason.text.trim()};
    coins.dispose();
    pips.dispose();
    reason.dispose();
    if (confirmed != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).post('/admin/users/$userId/wallet', data: payload));
    if (result == null || !context.mounted) return;
    ref.invalidate(adminUserDetailProvider(userId));
    ref.invalidate(adminUsersProvider);
    showAdminMessage(context, 'Wallet adjusted.');
    Navigator.pop(context);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            VibeText(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      );
}
