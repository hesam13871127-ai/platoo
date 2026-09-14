import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// Reports and moderation queue. A moderator can triage, add internal notes and
/// close a report, optionally suspending or banning the reported account.
class AdminReportsTab extends ConsumerWidget {
  const AdminReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminReportsProvider);
    final status = ref.watch(adminReportStatusProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminReportsProvider),
      child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Row(children: [
            for (final filter in const [('open', 'Open'), ('investigating', 'Investigating'), ('resolved', 'Resolved'), ('dismissed', 'Dismissed'), ('', 'All')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(filter.$2), selected: status == filter.$1, onSelected: (_) => ref.read(adminReportStatusProvider.notifier).state = filter.$1),
              ),
          ]),
        ),
        AdminAsync<Map<String, dynamic>>(
          value: reports,
          onRetry: () => ref.invalidate(adminReportsProvider),
          builder: (data) {
            final items = (data['items'] as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
            if (items.isEmpty) {
              return const AdminEmpty(icon: Icons.verified_user_outlined, title: 'Queue is clear', message: 'No reports match this filter right now.');
            }
            return Column(children: [
              AdminSectionHeader(title: '${data['total']} report(s)'),
              for (final report in items) _ReportCard(report: report),
            ]);
          },
        ),
      ]),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = report['status']?.toString() ?? 'open';
    final priorReports = asInt(report['reportedUserTotalReports']);
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AdminStatusChip(label: report['category']?.toString() ?? 'report', color: AppTheme.coral),
            const SizedBox(width: 8),
            AdminStatusChip(label: status, color: statusColor(status)),
            const Spacer(),
            Text(shortDate(report['createdAt']), style: const TextStyle(fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          Text(report['description']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 10),
          Text('Reported by ${report['reporterName'] ?? 'unknown'} · about ${report['reportedUserName'] ?? 'no account'}', style: Theme.of(context).textTheme.bodySmall),
          if (priorReports > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('This account has $priorReports reports on file.', style: const TextStyle(fontSize: 12, color: AppTheme.coral, fontWeight: FontWeight.w700)),
            ),
          if (report['resolutionNote'] != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Note: ${report['resolutionNote']}', style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 4),
          Row(children: [
            TextButton.icon(onPressed: () => _notes(context, ref), icon: const Icon(Icons.sticky_note_2_outlined, size: 18), label: Text('Notes (${asInt(report['noteCount'])})')),
            const Spacer(),
            if (status == 'open')
              TextButton(onPressed: () => _resolve(context, ref, 'investigating', 'none'), child: const Text('Investigate')),
            TextButton(onPressed: () => _resolve(context, ref, 'dismissed', 'none'), child: const Text('Dismiss')),
            FilledButton(onPressed: () => _action(context, ref), child: const Text('Take action')),
          ]),
        ]),
      ),
    );
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref, String status, String action, {String? note, int? hours}) async {
    try {
      await ref.read(adminRepositoryProvider).resolveReport(report['id'].toString(), status: status, note: note, action: action, banDurationHours: hours);
      ref.invalidate(adminReportsProvider);
      ref.invalidate(adminOverviewProvider);
      await showAdminMessage(context, 'Report marked $status.');
    } catch (error) {
      await showAdminError(context, error);
    }
  }

  Future<void> _action(BuildContext context, WidgetRef ref) async {
    final note = TextEditingController();
    var action = 'none';
    var hours = 24;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Resolve report'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Resolution note')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: action,
              decoration: const InputDecoration(labelText: 'Action on the reported account'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No action')),
                DropdownMenuItem(value: 'suspend', child: Text('Temporary suspension')),
                DropdownMenuItem(value: 'ban', child: Text('Permanent ban')),
                DropdownMenuItem(value: 'unban', child: Text('Lift existing ban')),
              ],
              onChanged: (value) => setState(() => action = value ?? 'none'),
            ),
            if (action == 'suspend')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<int>(
                  value: hours,
                  decoration: const InputDecoration(labelText: 'Suspension length'),
                  items: const [
                    DropdownMenuItem(value: 24, child: Text('24 hours')),
                    DropdownMenuItem(value: 72, child: Text('3 days')),
                    DropdownMenuItem(value: 168, child: Text('7 days')),
                  ],
                  onChanged: (value) => setState(() => hours = value ?? 24),
                ),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Resolve')),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await _resolve(context, ref, 'resolved', action, note: note.text.trim(), hours: action == 'suspend' ? hours : null);
    }
    note.dispose();
  }

  void _notes(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _NotesSheet(reportId: report['id'].toString()),
      ),
    );
  }
}

class _NotesSheet extends ConsumerStatefulWidget {
  const _NotesSheet({required this.reportId});
  final String reportId;

  @override
  ConsumerState<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends ConsumerState<_NotesSheet> {
  final _body = TextEditingController();

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(adminReportNotesProvider(widget.reportId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Internal notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Visible to moderators only.', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: AdminAsync<List<Map<String, dynamic>>>(
            value: notes,
            builder: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('No notes yet.'))
                : ListView(shrinkWrap: true, children: [
                    for (final note in list)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(note['body']?.toString() ?? ''),
                        subtitle: Text('${note['authorName']} · ${shortDate(note['createdAt'])}'),
                      ),
                  ]),
          ),
        ),
        const SizedBox(height: 8),
        TextField(controller: _body, maxLines: 2, decoration: const InputDecoration(labelText: 'Add a note')),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () async {
            if (_body.text.trim().isEmpty) return;
            try {
              await ref.read(adminRepositoryProvider).addReportNote(widget.reportId, _body.text.trim());
              _body.clear();
              ref.invalidate(adminReportNotesProvider(widget.reportId));
              ref.invalidate(adminReportsProvider);
            } catch (error) {
              await showAdminError(context, error);
            }
          },
          child: const Text('Save note'),
        ),
      ]),
    );
  }
}
