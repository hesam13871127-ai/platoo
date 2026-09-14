import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'admin_api.dart';

class AdminAuditTab extends ConsumerWidget {
  const AdminAuditTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(adminAuditProvider);
    return audit.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (page) => page.items.isEmpty
          ? const Center(child: Text('No admin actions logged yet.'))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminAuditProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: page.items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == page.items.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filledTonal(
                            onPressed: page.page > 0 ? () => ref.read(adminAuditPageProvider.notifier).state = page.page - 1 : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Page ${page.page + 1} of ${page.totalPages == 0 ? 1 : page.totalPages} · ${page.total} total',
                                style: const TextStyle(fontSize: 12)),
                          ),
                          IconButton.filledTonal(
                            onPressed: page.page + 1 < page.totalPages
                                ? () => ref.read(adminAuditPageProvider.notifier).state = page.page + 1
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    );
                  }
                  final entry = page.items[index];
                  return Card(
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.history_rounded, color: AppTheme.violet, size: 20),
                      ),
                      title: Text(strOf(entry['action']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      subtitle: Text(
                        '${strOf(entry['adminName'], 'admin')} · ${strOf(entry['entityType'])}${strOf(entry['entityId']).isEmpty ? '' : ' ${strOf(entry['entityId']).substring(0, strOf(entry['entityId']).length > 8 ? 8 : strOf(entry['entityId']).length)}…'} · ${dateLabel(entry['createdAt'])}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(strOf(entry['action'])),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('By ${strOf(entry['adminName'], 'admin')} · ${strOf(entry['createdAt'])}',
                                    style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 10),
                                const Text('Before', style: TextStyle(fontWeight: FontWeight.w900)),
                                Text(_preview(entry['before'])),
                                const SizedBox(height: 8),
                                const Text('After', style: TextStyle(fontWeight: FontWeight.w900)),
                                Text(_preview(entry['after'])),
                              ],
                            ),
                          ),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _preview(dynamic value) {
    if (value == null) return '—';
    final text = value.toString();
    return text.length > 600 ? '${text.substring(0, 600)}…' : text;
  }
}
