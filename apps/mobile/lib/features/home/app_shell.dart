import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final pages = [const HomeScreen(), const ShopScreen(), const SocialScreen(), const ProfileScreen()];
    return Scaffold(
      extendBody: false,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (value) {
          if (value == index) return;
          HapticFeedback.selectionClick();
          setState(() => index = value);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.sports_esports_outlined), selectedIcon: const Icon(Icons.sports_esports_rounded), label: strings.play),
          NavigationDestination(icon: const Icon(Icons.local_mall_outlined), selectedIcon: const Icon(Icons.local_mall_rounded), label: strings.shop),
          NavigationDestination(icon: const Icon(Icons.people_outline_rounded), selectedIcon: const Icon(Icons.people_rounded), label: strings.social),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: strings.profile),
        ],
      ),
    );
  }
}
