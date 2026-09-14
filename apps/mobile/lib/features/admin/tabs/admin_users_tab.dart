import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// User management: search by name, handle, phone, email or id, then ban,
/// unban, change a role or correct a balance.
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    final status = ref.watch(adminUserStatusProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminUsersProvider),
      child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name, @handle, phone, email or id',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () { _controller.clear(); ref.read(adminUserQueryProvider.notifier).state = ''; setState(() {}); },
                    ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (value) => ref.read(adminUserQueryProvider.notifier).state = value.trim(),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            for (final filter in const [('', 'All'), ('active', 'Active'), ('suspended', 'Suspended'), ('deleted', 'Deleted')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter.$2),
                  selected: status == filter.$1,
                  onSelected: (_) => ref.read(adminUserStatusProvider.notifier).state = filter.$1,
                ),
              ),
          ]),
        ),
        AdminAsync<Map<String, dynamic>>(
          value: users,
          onRetry: () => ref.invalidate(adminUsersProvider),
          builder: (data) {
            final items = (data['items'] as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
            if (items.isEmpty) {
              return const AdminEmpty(icon: Icons.person_search_rounded, title: 'No accounts match', message: 'Try a different search term or clear the status filter.');
            }
            return Column(children: [
              AdminSectionHeader(title: '${data['total']} account(s)', subtitle: 'Showing page ${asInt(data['page']) + 1}'),
              for (final user in items) _UserTile(user: user, isAdmin: widget.isAdmin),
            ]);
          },
        ),
      ]),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user, required this.isAdmin});
  final Map<String, dynamic> user;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = user['status']?.toString() ?? 'active';
    final banned = status == 'suspended';
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: AppTheme.violet.withOpacity(.15), child: Text(_initial(user['displayName']), style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user['displayName']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('@${user['username']}  ·  Lv ${user['level'] ?? 1}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            AdminStatusChip(label: status, color: statusColor(status)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            AdminStatusChip(label: user['role']?.toString() ?? 'player', color: AppTheme.violet),
            AdminStatusChip(label: '${asInt(user['coins'])} coins', color: AppTheme.gold),
            AdminStatusChip(label: '${asInt(user['pips'])} pips', color: AppTheme.violet),
            if (asInt(user['reportCount']) > 0) AdminStatusChip(label: '${asInt(user['reportCount'])} reports', color: AppTheme.coral),
          ]),
          if (user['banReason'] != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Ban: ${user['banReason']}${user['banExpiresAt'] == null ? ' (permanent)' : ' until ${shortDate(user['banExpiresAt'])}'}',
                style: const TextStyle(fontSize: 12, color: AppTheme.coral, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            TextButton.icon(onPressed: () => _details(context, ref), icon: const Icon(Icons.info_outline_rounded, size: 18), label: const Text('Details')),
            const Spacer(),
            if (banned)
              FilledButton.icon(
                onPressed: () => _unban(context, ref),
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Unban'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.mint),
              )
            else
              FilledButton.icon(
                onPressed: () => _ban(context, ref),
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: const Text('Ban'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
              ),
            if (isAdmin) PopupMenuButton<String>(
              onSelected: (value) => value.startsWith('role:') ? _setRole(context, ref, value.substring(5)) : _adjust(context, ref, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'role:player', child: Text('Set role: player')),
                PopupMenuItem(value: 'role:moderator', child: Text('Set role: moderator')),
                PopupMenuItem(value: 'role:admin', child: Text('Set role: admin')),
                PopupMenuItem(value: 'coins', child: Text('Adjust coins')),
                PopupMenuItem(value: 'pips', child: Text('Adjust pips')),
              ],
            ),
          ]),
        ]),
      ),
    );
  }

  String _initial(Object? name) {
    final text = name?.toString().trim() ?? '';
    return text.isEmpty ? '?' : text.substring(0, 1).toUpperCase();
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, String success) async {
    try {
      await action();
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminOverviewProvider);
      await showAdminMessage(context, success);
    } catch (error) {
      await showAdminError(context, error);
    }
  }

  Future<void> _ban(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    var hours = 0; // 0 means permanent.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Ban ${user['displayName']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason (shown in the audit log)')),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: hours,
              decoration: const InputDecoration(labelText: 'Duration'),
              items: const [
                DropdownMenuItem(value: 24, child: Text('24 hours')),
                DropdownMenuItem(value: 72, child: Text('3 days')),
                DropdownMenuItem(value: 168, child: Text('7 days')),
                DropdownMenuItem(value: 720, child: Text('30 days')),
                DropdownMenuItem(value: 0, child: Text('Permanent')),
              ],
              onChanged: (value) => setState(() => hours = value ?? 0),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: AppTheme.coral), child: const Text('Ban')),
          ],
        ),
      ),
    );
    if (confirmed != true || reason.text.trim().length < 3) {
      if (confirmed == true) await showAdminError(context, 'A ban needs a reason of at least 3 characters.');
      reason.dispose();
      return;
    }
    await _run(context, ref, () => ref.read(adminRepositoryProvider).ban(user['id'].toString(), reason.text.trim(), durationHours: hours == 0 ? null : hours), 'Account banned.');
    reason.dispose();
  }

  Future<void> _unban(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Unban ${user['displayName']}'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'Note (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unban')),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(context, ref, () => ref.read(adminRepositoryProvider).unban(user['id'].toString(), reason: reason.text.trim()), 'Account reinstated.');
    }
    reason.dispose();
  }

  Future<void> _setRole(BuildContext context, WidgetRef ref, String role) =>
      _run(context, ref, () => ref.read(adminRepositoryProvider).setRole(user['id'].toString(), role), 'Role updated to $role.');

  Future<void> _adjust(BuildContext context, WidgetRef ref, String currency) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Adjust $currency'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: const InputDecoration(labelText: 'Amount (negative to remove)')),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply')),
        ],
      ),
    );
    final parsed = int.tryParse(amount.text.trim());
    if (confirmed == true && parsed != null && parsed != 0 && reason.text.trim().length >= 3) {
      await _run(context, ref, () => ref.read(adminRepositoryProvider).adjustWallet(user['id'].toString(), currency, parsed, reason.text.trim()), 'Balance updated.');
    } else if (confirmed == true) {
      await showAdminError(context, 'Enter a non-zero amount and a reason.');
    }
    amount.dispose();
    reason.dispose();
  }

  void _details(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        builder: (context, controller) => Consumer(
          builder: (context, ref, _) {
            final detail = ref.watch(adminUserDetailProvider(user['id'].toString()));
            return AdminAsync<Map<String, dynamic>>(
              value: detail,
              builder: (data) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                Text(data['displayName']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text('@${data['username']}  ·  ${data['email'] ?? data['phone'] ?? 'no contact'}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Text('Joined ${shortDate(data['createdAt'])}  ·  Last seen ${shortDate(data['lastSeenAt'])}', style: Theme.of(context).textTheme.bodySmall),
                const Divider(height: 26),
                const Text('Ban history', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if ((data['bans'] as List? ?? const []).isEmpty) const Text('No bans on record.') else
                  for (final ban in (data['bans'] as List).map((b) => Map<String, dynamic>.from(b as Map)))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(ban['liftedAt'] == null ? Icons.gavel_rounded : Icons.lock_open_rounded, color: ban['liftedAt'] == null ? AppTheme.coral : AppTheme.mint),
                      title: Text(ban['reason']?.toString() ?? ''),
                      subtitle: Text('${shortDate(ban['createdAt'])} by ${ban['issuedByName'] ?? 'system'}${ban['liftedAt'] == null ? '' : ' · lifted ${shortDate(ban['liftedAt'])}'}'),
                    ),
                const Divider(height: 26),
                const Text('Reports against this account', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if ((data['reportsAgainst'] as List? ?? const []).isEmpty) const Text('None.') else
                  for (final report in (data['reportsAgainst'] as List).map((r) => Map<String, dynamic>.from(r as Map)))
                    ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(report['description']?.toString() ?? ''), subtitle: Text('${report['category']} · ${report['status']}')),
                const Divider(height: 26),
                const Text('Recent matches', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if ((data['recentMatches'] as List? ?? const []).isEmpty) const Text('No matches yet.') else
                  for (final match in (data['recentMatches'] as List).map((m) => Map<String, dynamic>.from(m as Map)))
                    ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${match['gameId']} · ${match['mode']}'), subtitle: Text('${match['status']} · ${match['result']} · ${shortDate(match['createdAt'])}')),
              ]),
            );
          },
        ),
      ),
    );
  }
}
