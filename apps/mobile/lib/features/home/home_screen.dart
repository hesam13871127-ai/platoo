import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/player_avatar.dart';
import '../../core/widgets/state_panel.dart';
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

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final user = ref.watch(authProvider).value?.user;
    final catalog = ref.watch(gamesProvider);
    final games = catalog.maybeWhen(data: (value) => value, orElse: () => localGameCatalog);
    final filtered = games.where((game) {
      final matchesCategory = category == null || game.category == category;
      final matchesQuery = query.trim().isEmpty || game.name.toLowerCase().contains(query.trim().toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
    final featured = games.isEmpty ? null : games.first;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.violet,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverSafeArea(
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: _HomeHeader(user: user, strings: strings)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(child: featured == null ? const _EmptyCatalog() : _FeaturedBanner(game: featured, onTap: () => _open(context, featured))),
          ),
          if (catalog.isLoading && games.isEmpty)
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, 0), child: LinearProgressIndicator(minHeight: 3))),
          if (catalog.hasError)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(child: _CatalogNotice(onRetry: _refresh)),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 11),
            sliver: SliverToBoxAdapter(child: Row(children: [Expanded(child: Text(strings.games, style: Theme.of(context).textTheme.titleLarge)), Text('${filtered.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800))])),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 43,
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
                delegate: SliverChildBuilderDelegate((context, index) => _GameCard(game: filtered[index], onTap: () => _open(context, filtered[index])), childCount: filtered.length),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 265, mainAxisExtent: 205, crossAxisSpacing: 14, mainAxisSpacing: 14),
              ),
            )
          else
            SliverToBoxAdapter(child: _NoGamesFound(hasFilters: query.isNotEmpty || category != null, onClear: () { search.clear(); setState(() { query = ''; category = null; }); })),
          const SliverToBoxAdapter(child: SizedBox(height: 30)),
        ],
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
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name == null || name.isEmpty ? 'Welcome back' : 'Hi, $name', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(strings.isPersian ? 'میز بعدی‌ات آماده است' : 'Your next table is ready', style: Theme.of(context).textTheme.bodySmall),
      ])),
      BalancePill(value: user?.coins ?? 0, icon: Icons.circle, color: AppTheme.gold),
      const SizedBox(width: 8),
      PlayerAvatar(avatarUrl: user?.avatarUrl, displayName: user?.displayName ?? '', radius: 20),
    ]);
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Play ${game.name}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(27),
      child: Container(
        constraints: const BoxConstraints(minHeight: 177),
        padding: const EdgeInsets.fromLTRB(20, 20, 14, 20),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(27), gradient: const LinearGradient(colors: [AppTheme.violetDeep, AppTheme.violet], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: AppTheme.violet.withOpacity(.24), blurRadius: 20, offset: const Offset(0, 10))]),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('PLAY THE MOMENT', style: TextStyle(color: Color(0xFFD9CFFF), fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 10)),
            const SizedBox(height: 7),
            Text('Your table\nis waiting.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, height: 1.05)),
            const SizedBox(height: 12),
            Row(mainAxisSize: MainAxisSize.min, children: [Text('Try ${game.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(width: 7), const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18)]),
          ])),
          Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Transform.rotate(angle: -.16, child: GameLogo(gameId: game.id, accent: '#B7A5FF', size: 82))),
        ]),
      ),
    ),
  );
}

class _CatalogNotice extends StatelessWidget {
  const _CatalogNotice({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.13), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppTheme.gold.withOpacity(.3))), child: Row(children: [const Icon(Icons.cloud_off_rounded, color: AppTheme.gold, size: 19), const SizedBox(width: 9), const Expanded(child: Text('Showing the saved game catalog while we reconnect.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))), TextButton(onPressed: onRetry, child: const Text('Retry'))]));
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(label), selected: active, onSelected: (_) => onTap(), showCheckmark: false, padding: const EdgeInsets.symmetric(horizontal: 12), labelStyle: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant), selectedColor: AppTheme.violet, backgroundColor: Theme.of(context).colorScheme.surfaceVariant));
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});
  final GameDescriptor game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open ${game.name}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [GameLogo(gameId: game.id, accent: game.accent, size: 53), const Spacer(), if (game.supportsTeams) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.12), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.groups_rounded, color: AppTheme.mint, size: 15))]),
          const Spacer(),
          Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Row(children: [Icon(Icons.people_alt_outlined, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 4), Text('${game.minPlayers}–${game.maxPlayers}', style: Theme.of(context).textTheme.bodySmall), const Spacer(), Icon(Icons.arrow_forward_rounded, size: 18, color: Theme.of(context).colorScheme.primary)]),
        ])),
      ),
    ),
  );
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
