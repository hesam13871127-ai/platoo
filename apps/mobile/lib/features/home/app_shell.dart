import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';
import '../shop/shop_screen.dart';
import '../social/social_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;

  void _select(int value) {
    if (value == index) return;
    HapticFeedback.selectionClick();
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pages = [const HomeScreen(), const ShopScreen(), const SocialScreen(), const ProfileScreen()];
    final pendingRequests = ref.watch(friendsProvider).valueOrNull?.where((f) => f.status == 'pending' && !f.isRequester).length ?? 0;
    return Scaffold(
      extendBody: false,
      body: SafeArea(top: true, bottom: false, child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: scheme.outline.withOpacity(dark ? .3 : .14))),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(dark ? .4 : .08), blurRadius: 24, offset: const Offset(0, -8))],
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Row(
            children: [
              _NavItem(icon: Icons.sports_esports_outlined, selectedIcon: Icons.sports_esports_rounded, label: strings.play, selected: index == 0, onTap: () => _select(0)),
              _NavItem(icon: Icons.local_mall_outlined, selectedIcon: Icons.local_mall_rounded, label: strings.shop, selected: index == 1, onTap: () => _select(1)),
              _NavItem(icon: Icons.people_outline_rounded, selectedIcon: Icons.people_rounded, label: strings.social, selected: index == 2, badgeCount: pendingRequests, onTap: () => _select(2)),
              _NavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: strings.profile, selected: index == 3, onTap: () => _select(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.selectedIcon, required this.label, required this.selected, required this.onTap, this.badgeCount = 0});
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = scheme.primary;
    final idle = scheme.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: selected ? 20 : 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? active.withOpacity(.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                boxShadow: selected ? [BoxShadow(color: AppTheme.violet.withOpacity(.18), blurRadius: 14, offset: const Offset(0, 5))] : null,
              ),
              child: Badge(
                isLabelVisible: badgeCount > 0,
                label: VibeText('$badgeCount'),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(selected ? selectedIcon : icon, key: ValueKey(selected), size: 25, color: selected ? active : idle),
                ),
              ),
            ),
            const SizedBox(height: 4),
            VibeText(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: selected ? active : idle)),
          ],
        ),
      ),
    );
  }
}
