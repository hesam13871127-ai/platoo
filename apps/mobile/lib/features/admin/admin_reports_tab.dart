import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'admin_api.dart';

class AdminReportsTab extends ConsumerWidget {
  const AdminReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminReportsProvider);
    final status = ref.watch(adminReportStatusProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(label: 'All', selected: status == null, onTap: () => _select(ref, null)),
                for (final s in const ['open', 'investigating', 'resolved', 'dismissed'])
                  _StatusChip(label: s, selected: status == s, onTap: () => _select(ref, s)),
              ],
            ),
          ),
        ),
        Expanded(
          child: reports.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
            data: (page) => page.items.isEmpty
                ? const Center(child: Text('All clear. No reports here.'))
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(adminReportsProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: page.items.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == page.items.length) {
                          return _ReportPager(page: page);
                        }
                        final item = page.items[index];
                        return _ReportCard(
                          item: item,
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (_) => _ReportDetailSheet(reportId: strOf(item['id'])),
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

  void _select(WidgetRef ref, String? status) {
    ref.read(adminReportStatusProvider.notifier).state = status;
    ref.read(adminReportPageProvider.notifier).state = 0;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _ReportPager extends ConsumerWidget {
  const _ReportPager({required this.page});
  final AdminPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: page.page > 0 ? () => ref.read(adminReportPageProvider.notifier).state = page.page - 1 : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('Page ${page.page + 1} of ${page.totalPages == 0 ? 1 : page.totalPages} · ${page.total} total',
                  style: const TextStyle(fontSize: 12)),
            ),
            IconButton.filledTonal(
              onPressed: page.page + 1 < page.totalPages ? () => ref.read(adminReportPageProvider.notifier).state = page.page + 1 : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(strOf(item['category'], 'report'),
                          style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                      child: Text(strOf(item['status']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    const Spacer(),
                    Text(dateLabel(item['createdAt']), style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 9),
                Text(strOf(item['description']), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('${strOf(item['reporterName'], 'Someone')} → ${strOf(item['reportedUserName'], '—')}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
}

class _ReportDetailSheet extends ConsumerStatefulWidget {
  const _ReportDetailSheet({required this.reportId});
  final String reportId;

  @override
  ConsumerState<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends ConsumerState<_ReportDetailSheet> {
  final _note = TextEditingController();
  String _status = 'resolved';
  String _action = 'none';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminReportDetailProvider(widget.reportId));
    final role = ref.watch(authProvider).value?.user.role;
    final admin = isAdminRole(role);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: detail.when(
          loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
          error: (error, _) => Padding(padding: const EdgeInsets.all(24), child: Text(error.toString())),
          data: (item) {
            final prior = asItemList(item['priorReports']);
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(strOf(item['category'], 'report'),
                            style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Text('Current: ${strOf(item['status'])}', style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Text(dateLabel(item['createdAt']), style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(strOf(item['description']), style: const TextStyle(fontSize: 15, height: 1.4)),
                  const SizedBox(height: 12),
                  _PersonRow(
                    label: 'Reporter',
                    name: strOf(item['reporterName'], '—'),
                    handle: strOf(item['reporterUsername']),
                  ),
                  const SizedBox(height: 6),
                  _PersonRow(
                    label: 'Reported',
                    name: strOf(item['reportedUserName'], '—'),
                    handle: strOf(item['reportedUsername']),
                    extra: strOf(item['reportedUserStatus']).isEmpty ? null : '(${strOf(item['reportedUserStatus'])})',
                  ),
                  if (strOf(item['gameId']).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Match: ${strOf(item['matchId'])} · ${strOf(item['gameId'])} (${strOf(item['matchMode'])})',
                        style: const TextStyle(fontSize: 12)),
                  ],
                  if (prior.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${prior.length} earlier report(s) against this user (latest: ${strOf(prior.first['category'])} · ${strOf(prior.first['status'])})',
                        style: const TextStyle(fontSize: 12, color: AppTheme.coral, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 16),
                  const Text('Resolution', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'investigating', child: Text('investigating')),
                      DropdownMenuItem(value: 'resolved', child: Text('resolved')),
                      DropdownMenuItem(value: 'dismissed', child: Text('dismissed')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _action,
                    decoration: const InputDecoration(labelText: 'Moderation action'),
                    items: [
                      const DropdownMenuItem(value: 'none', child: Text('No action on user')),
                      const DropdownMenuItem(value: 'warn', child: Text('Send warning')),
                      DropdownMenuItem(value: 'suspend_reported', enabled: admin, child: Text('Suspend reported user${admin ? '' : ' (admin only)'}')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _action = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Resolution note',
                      hintText: 'What was decided and why…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _submit(context, ref),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Apply resolution'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final result = await guardAdmin(
      context,
      () => ref.read(apiClientProvider).patch(
        '/admin/reports/${widget.reportId}',
        data: {'status': _status, 'resolutionNote': _note.text.trim(), 'moderationAction': _action},
      ),
    );
    if (result == null || !context.mounted) return;
    ref.invalidate(adminReportDetailProvider(widget.reportId));
    ref.invalidate(adminReportsProvider);
    ref.invalidate(adminOverviewProvider);
    showAdminMessage(context, 'Report $_status.');
    Navigator.pop(context);
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.label, required this.name, required this.handle, this.extra});
  final String label;
  final String name;
  final String handle;
  final String? extra;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text('$name${handle.isEmpty ? '' : ' · @$handle'}${extra == null ? '' : ' $extra'}', style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      );
}
