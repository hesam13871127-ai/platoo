import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/player_avatar.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';
import '../admin/admin_screen.dart';
import 'leaderboard_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings(Localizations.localeOf(context));
    final user = ref.watch(authProvider).value?.user;
    final settings = ref.watch(settingsProvider);
    if (user == null) return const SizedBox.shrink();
    return VibePageBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
        children: [
          Entrance(child: _ProfileHeader(user: user)),
          const SizedBox(height: 16),
          Entrance(
            delay: const Duration(milliseconds: 70),
            child: Row(children: [
              _StatCard(label: strings.coins, value: '${user.coins}', icon: Icons.circle, gradient: AppTheme.goldGradient),
              const SizedBox(width: 10),
              _StatCard(label: strings.pips, value: '${user.pips}', icon: Icons.brightness_1_rounded, gradient: AppTheme.primaryGradient),
              const SizedBox(width: 10),
              _StatCard(label: 'XP', value: '${user.experience}', icon: Icons.bolt_rounded, gradient: AppTheme.coralGradient),
            ]),
          ),
          const SizedBox(height: 24),
          Entrance(
            delay: const Duration(milliseconds: 120),
            child: SectionHeader(title: strings.settings, subtitle: strings.isPersian ? 'برنامه را مال خودت کن' : 'Make the app yours'),
          ),
          const SizedBox(height: 10),
          Entrance(
            delay: const Duration(milliseconds: 150),
            child: VibeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.brightness_6_outlined, color: AppTheme.violet, size: 20)),
                    const SizedBox(width: 12),
                    Text(strings.isPersian ? 'پوسته' : 'Appearance', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeChoice>(
                      segments: [
                        ButtonSegment(value: ThemeChoice.system, label: Text(strings.isPersian ? 'سیستم' : 'System'), icon: const Icon(Icons.settings_suggest_outlined, size: 18)),
                        ButtonSegment(value: ThemeChoice.light, label: Text(strings.light), icon: const Icon(Icons.light_mode_outlined, size: 18)),
                        ButtonSegment(value: ThemeChoice.dark, label: Text(strings.dark), icon: const Icon(Icons.dark_mode_outlined, size: 18)),
                      ],
                      selected: {settings.theme},
                      onSelectionChanged: (value) {
                        final theme = value.first;
                        ref.read(settingsProvider.notifier).setTheme(theme);
                        ref.read(authProvider.notifier).updatePreferences(theme: theme).catchError((_) {
                          if (context.mounted) showAppSnackBar(context, 'Appearance saved on this device.');
                        });
                      },
                    ),
                  ),
                  const Divider(height: 26),
                  Row(children: [
                    Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.12), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.translate_rounded, color: AppTheme.mint, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(strings.language, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    SegmentedButton<AppLocale>(
                      segments: const [ButtonSegment(value: AppLocale.en, label: Text('EN')), ButtonSegment(value: AppLocale.fa, label: Text('FA'))],
                      selected: {settings.locale},
                      onSelectionChanged: (value) {
                        final locale = value.first;
                        ref.read(settingsProvider.notifier).setLocale(locale);
                        ref.read(authProvider.notifier).updatePreferences(locale: locale).catchError((_) {
                          if (context.mounted) showAppSnackBar(context, 'Language saved on this device.');
                        });
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Entrance(
            delay: const Duration(milliseconds: 190),
            child: _MenuTile(
              icon: Icons.emoji_events_rounded,
              iconColor: AppTheme.gold,
              title: 'Season leaderboard',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
            ),
          ),
          const SizedBox(height: 10),
          if (user.role == 'admin' || user.role == 'moderator') ...[
            Entrance(
              delay: const Duration(milliseconds: 210),
              child: _MenuTile(
                icon: Icons.admin_panel_settings_rounded,
                iconColor: AppTheme.violet,
                title: 'Admin console',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Entrance(
            delay: const Duration(milliseconds: 230),
            child: _MenuTile(icon: Icons.logout_rounded, iconColor: AppTheme.coral, title: strings.signOut, danger: true, onTap: () => _logout(context, ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(title: const Text('Sign out?'), content: const Text('You can sign back in whenever you are ready.'), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Sign out'))]));
    if (shouldLogout == true) await ref.read(authProvider.notifier).logout();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final progress = ((user.experience % 1000) / 1000).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: AppTheme.heroGradient, boxShadow: AppTheme.glow(AppTheme.violet, strength: .4)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(right: -30, top: -30, child: Container(width: 110, height: 110, decoration: BoxDecoration(color: Colors.white.withOpacity(.09), shape: BoxShape.circle))),
            Column(
              children: [
                Row(
                  children: [
                    PlayerAvatar(avatarUrl: user.avatarUrl, displayName: user.displayName, radius: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: -.3)),
                          const SizedBox(height: 3),
                          Text('@${user.username}', style: TextStyle(color: Colors.white.withOpacity(.75), fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withOpacity(.28))),
                      child: Text('LV ${user.level}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: .4)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.white.withOpacity(.2), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white)),
                ),
                const SizedBox(height: 7),
                Align(alignment: AlignmentDirectional.centerStart, child: Text('${user.experience} XP total', style: TextStyle(color: Colors.white.withOpacity(.8), fontWeight: FontWeight.w700, fontSize: 12))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.gradient});
  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: gradient, boxShadow: AppTheme.glow(AppTheme.violet, strength: .22)),
          child: Column(children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 7),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.iconColor, required this.title, required this.onTap, this.danger = false});
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VibeCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: iconColor.withOpacity(.13), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: danger ? scheme.error : iconColor, size: 21)),
        const SizedBox(width: 13),
        Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: danger ? scheme.error : null))),
        Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
      ]),
    );
  }
}
