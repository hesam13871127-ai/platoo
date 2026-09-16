import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/player_avatar.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';
import '../games/match_setup_screen.dart';
import 'home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final search = TextEditingController();
  String query = '';
  GameCategory? category;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(gamesProvider);
    try {
      await ref.read(gamesProvider.future);
    } catch (_) {
      // The local catalog remains useful when the API is temporarily offline.
    }
  }

  void _randomMatch(List<GameDescriptor> games) {
    if (games.isEmpty) return;
    final randomGame = games[math.Random().nextInt(games.length)];
    _open(context, randomGame);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final user = ref.watch(authProvider).value?.user;
    final catalog = ref.watch(gamesProvider);
    final games = catalog.maybeWhen(data: (value) => value, orElse: () => coreGameCatalog);
    final filtered = games.where((game) {
      final matchesCategory = category == null || game.category == category;
      final matchesQuery = query.trim().isEmpty || game.name.toLowerCase().contains(query.trim().toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
    final featured = games.isEmpty ? null : games.first;

    return VibePageBackground(
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.violet,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverSafeArea(
              sliver: SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(child: Entrance(child: _HomeHeader(user: user, strings: strings))),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Entrance(
                  delay: const Duration(milliseconds: 30),
                  child: _HomeQuickStats(
                    user: user,
                    strings: strings,
                    onRandomPlay: () => _randomMatch(games),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: featured == null ? const _EmptyCatalog() : Entrance(delay: const Duration(milliseconds: 60), child: _FeaturedBanner(game: featured, onTap: () => _open(context, featured)))),
            ),
            if (catalog.isLoading && games.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(child: _CatalogShimmer()),
              ),
            if (catalog.hasError)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(child: _CatalogNotice(onRetry: _refresh)),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: strings.games,
                  subtitle: strings.isPersian ? 'بازی مورد علاقه‌ات را انتخاب کن' : 'Pick your next obsession',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppTheme.violet.withOpacity(.25))),
                    child: VibeText('${filtered.length}', style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 46,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(label: strings.isPersian ? 'همه' : 'All', active: category == null, onTap: () => setState(() => category = null)),
                    ...GameCategory.values.map((value) => _FilterChip(label: _categoryName(value, strings), active: category == value, onTap: () => setState(() => category = value))),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: search,
                  onChanged: (value) => setState(() => query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(hintText: strings.isPersian ? 'جست‌وجوی بازی' : 'Search games', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: query.isEmpty ? null : IconButton(onPressed: () { search.clear(); setState(() => query = ''); }, icon: const Icon(Icons.close_rounded))),
                ),
              ),
            ),
            if (filtered.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Entrance(
                      delay: Duration(milliseconds: (index % 10) * 45),
                      child: _GameCard(game: filtered[index], onTap: () => _open(context, filtered[index])),
                    ),
                    childCount: filtered.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 265, mainAxisExtent: 248, crossAxisSpacing: 14, mainAxisSpacing: 14),
                ),
              )
            else
              SliverToBoxAdapter(child: _NoGamesFound(hasFilters: query.isNotEmpty || category != null, onClear: () { search.clear(); setState(() { query = ''; category = null; }); })),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, GameDescriptor game) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchSetupScreen(game: game)));

  String _categoryName(GameCategory value, AppStrings strings) => switch (value) {
        GameCategory.board => strings.isPersian ? 'بردی' : 'Board',
        GameCategory.cards => strings.isPersian ? 'کارتی' : 'Cards',
        GameCategory.arcade => strings.isPersian ? 'آرکید' : 'Arcade',
        GameCategory.party => strings.isPersian ? 'دورهمی' : 'Party',
        GameCategory.sports => strings.isPersian ? 'ورزشی' : 'Sports',
      };
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.user, required this.strings});
  final UserProfile? user;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName.trim().split(' ').first;
    return Row(children: [
      const VibeLogo(compact: true),
      const SizedBox(width: 12),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        VibeText(name == null || name.isEmpty ? 'Welcome back' : 'Hi, $name', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        VibeText(strings.isPersian ? 'میز بعدی‌ات آماده است' : 'Your next table is ready', style: Theme.of(context).textTheme.bodySmall),
      ])),
      BalancePill(value: user?.coins ?? 0, icon: Icons.circle, color: AppTheme.gold),
      const SizedBox(width: 9),
      PlayerAvatar(avatarUrl: user?.avatarUrl, displayName: user?.displayName ?? '', radius: 21),
    ]);
  }
}

class _HomeQuickStats extends StatelessWidget {
  const _HomeQuickStats({required this.user, required this.strings, required this.onRandomPlay});
  final UserProfile? user;
  final AppStrings strings;
  final VoidCallback onRandomPlay;

  @override
  Widget build(BuildContext context) {
    final level = user?.level ?? 1;
    final exp = user?.experience ?? 0;
    final expInLevel = exp % 500;
    final progress = (expInLevel / 500.0).clamp(0.0, 1.0);
    final fa = strings.isPersian;

    return VibeCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 15),
                const SizedBox(width: 3),
                VibeText(
                  fa ? 'سطح $level' : 'Lvl $level',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    VibeText(
                      fa ? 'پیشرفت فصل' : 'Season XP',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    const Spacer(),
                    VibeText('$expInLevel / 500 XP',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppTheme.violet.withOpacity(.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.violet),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          PressableScale(
            onTap: onRandomPlay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.mint.withOpacity(.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.mint.withOpacity(.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.casino_rounded, color: AppTheme.mint, size: 16),
                  const SizedBox(width: 5),
                  VibeText(
                    fa ? 'تصادفی' : 'Random',
                    style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();
  @override
  Widget build(BuildContext context) => const StatePanel(icon: Icons.casino_outlined, title: 'No featured tables', message: 'New tables will appear here soon. Pull to refresh.');
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.game, required this.onTap});
  final GameDescriptor game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final name = strings.gameName(game.id, game.name);
    return Semantics(
        button: true,
        label: strings.translateText('Play $name'),
        child: PressableScale(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 236),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: AppTheme.heroGradient, boxShadow: AppTheme.glow(AppTheme.violet, strength: .45)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  Positioned(right: -40, top: -46, child: Container(width: 168, height: 168, decoration: BoxDecoration(color: AppTheme.fuchsia.withOpacity(.3), shape: BoxShape.circle))),
                  Positioned(left: -44, bottom: -56, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: AppTheme.sky.withOpacity(.22), shape: BoxShape.circle))),
                  Positioned(right: 90, bottom: -64, child: Container(width: 130, height: 130, decoration: BoxDecoration(color: Colors.white.withOpacity(.07), shape: BoxShape.circle))),
                  Positioned(left: 40, top: -70, child: Transform.rotate(angle: .5, child: Container(width: 56, height: 340, decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(99))))),
                  Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x2E000000)])))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 16, 22),
                    child: Row(children: [
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withOpacity(.28))),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star_rounded, color: Colors.white, size: 13), SizedBox(width: 4), VibeText('FEATURED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 10))]),
                        ),
                        const SizedBox(height: 10),
                        VibeText(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: -.6, height: 1.05)),
                        const SizedBox(height: 9),
                        Wrap(spacing: 7, runSpacing: 7, children: [
                          _MetaChip(icon: Icons.people_alt_outlined, label: '${game.minPlayers}–${game.maxPlayers}'),
                          if (game.supportsTeams) const _MetaChip(icon: Icons.groups_rounded, label: 'Teams'),
                        ]),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 14, offset: const Offset(0, 6))]),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [VibeText('Play now', style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900, fontSize: 14)), SizedBox(width: 7), Icon(Icons.arrow_forward_rounded, color: AppTheme.violet, size: 18)]),
                        ),
                      ])),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 6),
                        child: SizedBox(
                          width: 128,
                          height: 150,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(width: 132, height: 132, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withOpacity(.2), Colors.white.withOpacity(0)]))),
                              Transform.rotate(angle: -.1, child: FloatingGameLogo(gameId: game.id, accent: '#B7A5FF', size: 104, floatRange: 6)),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withOpacity(.22))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 13), const SizedBox(width: 5), VibeText(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))]),
      );
}

class _CatalogNotice extends StatelessWidget {
  const _CatalogNotice({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.gold.withOpacity(.16), AppTheme.gold.withOpacity(.07)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.gold.withOpacity(.35)),
        ),
        child: Row(children: [
          Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.2), shape: BoxShape.circle), child: const Icon(Icons.cloud_off_rounded, color: AppTheme.gold, size: 18)),
          const SizedBox(width: 10),
          const Expanded(child: VibeText('Showing the saved game catalog while we reconnect.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          TextButton(onPressed: onRetry, child: const VibeText('Retry')),
        ]),
      );
}

class _CatalogShimmer extends StatelessWidget {
  const _CatalogShimmer();
  @override
  Widget build(BuildContext context) => Column(
        children: [
          const ShimmerBox(height: 150, borderRadius: BorderRadius.all(Radius.circular(28))),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 265 / 248,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              ShimmerBox(height: 248, borderRadius: BorderRadius.all(Radius.circular(26))),
              ShimmerBox(height: 248, borderRadius: BorderRadius.all(Radius.circular(26))),
              ShimmerBox(height: 248, borderRadius: BorderRadius.all(Radius.circular(26))),
              ShimmerBox(height: 248, borderRadius: BorderRadius.all(Radius.circular(26))),
            ],
          ),
        ],
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: VibeText(label),
          selected: active,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: active ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
          selectedColor: AppTheme.violet,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99), side: active ? BorderSide.none : BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(.3))),
        ),
      );
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});
  final GameDescriptor game;
  final VoidCallback onTap;

  Color _accent(String hex) {
    final parsed = int.tryParse('FF${hex.replaceFirst('#', '')}', radix: 16);
    return parsed == null ? AppTheme.violet : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context));
    final name = strings.gameName(game.id, game.name);
    final accent = _accent(game.accent);
    return Semantics(
      button: true,
      label: strings.translateText('Open $name'),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: scheme.outline.withOpacity(dark ? .3 : .14)),
            boxShadow: AppTheme.softShadow(dark: dark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 136,
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(accent, Colors.white, .14)!, accent, Color.lerp(accent, Colors.black, .35)!], stops: const [0, .55, 1])),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(right: -26, top: -26, child: Container(width: 92, height: 92, decoration: BoxDecoration(color: Colors.white.withOpacity(.12), shape: BoxShape.circle))),
                      Positioned(left: -20, bottom: -30, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.black.withOpacity(.14), shape: BoxShape.circle))),
                      Positioned(left: 26, top: -40, child: Transform.rotate(angle: .45, child: Container(width: 34, height: 220, decoration: BoxDecoration(color: Colors.white.withOpacity(.07), borderRadius: BorderRadius.circular(99))))),
                      Container(width: 108, height: 108, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withOpacity(.16), Colors.white.withOpacity(0)]))),
                      GameLogo(gameId: game.id, accent: game.accent, size: 76),
                      if (game.supportsTeams)
                        Positioned(
                          top: 9,
                          right: 9,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(.3), borderRadius: BorderRadius.circular(99)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.groups_rounded, color: Colors.white, size: 13), SizedBox(width: 4), VibeText('TEAMS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6))]),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VibeText(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        Row(children: [
                          Icon(Icons.people_alt_outlined, size: 15, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 5),
                          VibeText('${game.minPlayers}–${game.maxPlayers}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: accent.withOpacity(.12), shape: BoxShape.circle), child: Icon(Icons.arrow_forward_rounded, size: 16, color: accent)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoGamesFound extends StatelessWidget {
  const _NoGamesFound({required this.hasFilters, required this.onClear});
  final bool hasFilters;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: StatePanel(icon: Icons.search_off_rounded, title: hasFilters ? 'No games match that search' : 'No games are available right now', message: hasFilters ? 'Try another name or browse every category.' : 'Pull to refresh and try again.', actionLabel: hasFilters ? 'Clear filters' : null, onAction: hasFilters ? onClear : null),
      );
}
