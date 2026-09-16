import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import 'admin_api.dart';

class AdminGamesTab extends ConsumerWidget {
  const AdminGamesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(adminGamesProvider);
    final role = ref.watch(authProvider).value?.user.role;
    final admin = isAdminRole(role);
    return games.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: VibeText(error.toString())),
      data: (items) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminGamesProvider),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final game = items[index];
            final active = boolOf(game['isActive'], fallback: true);
            final hasBoard = gameHasMobileBoard(strOf(game['id']));
            return Card(
              child: ListTile(
                leading: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _accent(strOf(game['accentColor'])).withOpacity(.15), borderRadius: BorderRadius.circular(14)),
                  child: VibeText(
                    strOf(game['displayName'], '?').isEmpty ? '?' : strOf(game['displayName'], '?')[0],
                    style: TextStyle(color: _accent(strOf(game['accentColor'])), fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                ),
                title: VibeText(
                  strOf(game['displayName']),
                  style: TextStyle(fontWeight: FontWeight.w800, color: active ? null : Theme.of(context).disabledColor),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VibeText('${strOf(game['id'])} · ${strOf(game['category'])} · ${intOf(game['minPlayers'], 2)}–${intOf(game['maxPlayers'], 2)} players'),
                    if (!hasBoard)
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.phonelink_erase_rounded, size: 13, color: AppTheme.coral), SizedBox(width: 4), VibeText('No mobile board UI — disable until shipped', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.coral))]),
                      ),
                  ],
                ),
                trailing: admin
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!active) const VibeText('Off  ', style: TextStyle(fontSize: 12)),
                          Switch(value: active, onChanged: (_) => _toggle(context, ref, game)),
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(context, ref, game),
                          ),
                        ],
                      )
                    : Icon(active ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: active ? AppTheme.mint : Theme.of(context).disabledColor),
                onTap: admin ? () => _edit(context, ref, game) : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Color _accent(String hex) {
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6) return AppTheme.violet;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return AppTheme.violet;
    return Color(0xFF000000 | value);
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Map<String, dynamic> game) async {
    final next = !boolOf(game['isActive'], fallback: true);
    if (!next) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: VibeText('Disable ${strOf(game['displayName'])}?'),
          content: const VibeText('Players will no longer see this game or be able to start new matches.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const VibeText('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const VibeText('Disable')),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final result = await guardAdmin(
      context,
      () => ref.read(apiClientProvider).patch('/admin/games/${game['id']}', data: {'isActive': next}),
    );
    if (result == null) return;
    ref.invalidate(adminGamesProvider);
    ref.invalidate(adminOverviewProvider);
    showAdminMessage(context, next ? '${game['displayName']} enabled.' : '${game['displayName']} disabled.');
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Map<String, dynamic> game) async {
    final displayName = TextEditingController(text: strOf(game['displayName']));
    final minPlayers = TextEditingController(text: '${intOf(game['minPlayers'], 2)}');
    final maxPlayers = TextEditingController(text: '${intOf(game['maxPlayers'], 2)}');
    final accent = TextEditingController(text: strOf(game['accentColor'], '#7957F2'));
    final iconKey = TextEditingController(text: strOf(game['iconKey']));
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: VibeText('Edit ${strOf(game['id'])}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: displayName, decoration: const InputDecoration(labelText: 'Display name')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: minPlayers, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min players'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: maxPlayers, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max players'))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: accent, decoration: const InputDecoration(labelText: 'Accent color (#RRGGBB)')),
              const SizedBox(height: 8),
              TextField(controller: iconKey, decoration: const InputDecoration(labelText: 'Icon key')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const VibeText('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const VibeText('Save')),
        ],
      ),
    );
    final payload = <String, dynamic>{
      'displayName': displayName.text.trim(),
      'minPlayers': int.tryParse(minPlayers.text.trim()) ?? intOf(game['minPlayers'], 2),
      'maxPlayers': int.tryParse(maxPlayers.text.trim()) ?? intOf(game['maxPlayers'], 2),
      'accentColor': accent.text.trim(),
      'iconKey': iconKey.text.trim(),
    };
    displayName.dispose();
    minPlayers.dispose();
    maxPlayers.dispose();
    accent.dispose();
    iconKey.dispose();
    if (saved != true || !context.mounted) return;
    final result = await guardAdmin(context, () => ref.read(apiClientProvider).patch('/admin/games/${game['id']}', data: payload));
    if (result == null) return;
    ref.invalidate(adminGamesProvider);
    showAdminMessage(context, 'Game updated.');
  }
}
