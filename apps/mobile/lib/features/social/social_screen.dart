import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';
import '../games/match_setup_screen.dart';
import 'chat_screens.dart';
import 'groups_screens.dart';

final friendsProvider = FutureProvider<List<FriendEntry>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/users/friends') as List;
  return data.map((item) => FriendEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList();
});

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});
  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  final search = TextEditingController();
  List<Map<String, dynamic>> results = [];
  bool searching = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final friends = ref.watch(friendsProvider);
    final unread = (ref.watch(chatConversationsProvider).valueOrNull ?? const []).fold<int>(0, (sum, item) => sum + ((item['unreadCount'] as num?)?.toInt() ?? 0));
    final list = friends.valueOrNull ?? const <FriendEntry>[];
    final incoming = list.where((friend) => friend.status == 'pending' && !friend.isRequester).toList();
    final outgoing = list.where((friend) => friend.status == 'pending' && friend.isRequester).toList();
    final accepted = list.where((friend) => friend.status == 'accepted').toList()..sort((a, b) => (b.isOnline ? 1 : 0).compareTo(a.isOnline ? 1 : 0));
    final onlineCount = accepted.where((friend) => friend.isOnline).length;

    return VibePageBackground(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendsProvider);
          ref.invalidate(groupsProvider);
          ref.invalidate(chatConversationsProvider);
          try {
            await ref.read(friendsProvider.future);
          } catch (_) {}
        },
        child: SafeArea(
          top: true,
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Entrance(
                    child: Row(children: [
                      VibeText(strings.social, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(width: 10),
                      if (onlineCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.13), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppTheme.mint.withOpacity(.35))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.mint, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            VibeText('$onlineCount online', style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w900, fontSize: 12)),
                          ]),
                        ),
                      const Spacer(),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.1), shape: BoxShape.circle), child: IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen())), icon: const Icon(Icons.forum_rounded, color: AppTheme.violet))),
                          if (unread > 0) Positioned(right: -2, top: -2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(gradient: AppTheme.coralGradient, borderRadius: BorderRadius.circular(99)), child: VibeText(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)))),
                        ],
                      ),
                    ]),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    controller: search,
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: strings.isPersian ? 'جست‌وجوی دوستان' : 'Find people',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searching ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                    ),
                  ),
                ),
              ),
              if (results.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  sliver: SliverToBoxAdapter(child: _SearchResults(results: results, onAdd: _add)),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: strings.isPersian ? 'گروه‌ها' : 'Groups',
                    subtitle: strings.isPersian ? 'چت و بازی گروهی' : 'Chat rooms and game nights',
                    actionLabel: strings.isPersian ? 'جدید' : 'New',
                    onAction: () => _createGroup(context),
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 20), sliver: SliverToBoxAdapter(child: GroupsSection())),
              if (incoming.isNotEmpty || outgoing.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(child: SectionHeader(title: strings.isPersian ? 'درخواست‌ها' : 'Requests', subtitle: '${incoming.length + outgoing.length} pending')),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final all = [...incoming, ...outgoing];
                        final friend = all[index];
                        return Padding(padding: EdgeInsets.only(bottom: index == all.length - 1 ? 0 : 10), child: Entrance(delay: Duration(milliseconds: (index % 10) * 40), child: _RequestTile(friend: friend, onAccept: () => _handleRequest(friend, 'accept'), onDecline: () => _handleRequest(friend, 'reject'))));
                      },
                      childCount: incoming.length + outgoing.length,
                    ),
                  ),
                ),
              ],
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: strings.friends,
                    subtitle: accepted.isEmpty ? (strings.isPersian ? 'بازی با دوستان همیشه بهتر است' : 'Tables are better together') : '${accepted.length} friends · $onlineCount online',
                    actionLabel: strings.chat,
                    onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen())),
                  ),
                ),
              ),
              friends.when(
                loading: () => const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 20), sliver: SliverToBoxAdapter(child: _FriendsShimmer())),
                error: (error, _) => const SliverFillRemaining(hasScrollBody: false, child: StatePanel(icon: Icons.cloud_off_rounded, title: 'Friends are offline', message: 'Pull down to try again.')),
                data: (_) => accepted.isEmpty
                    ? const SliverFillRemaining(hasScrollBody: false, child: StatePanel(icon: Icons.people_outline_rounded, title: 'Your table is more fun with friends', message: 'Search for a player above and send the first invite.'))
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: EdgeInsets.only(bottom: index == accepted.length - 1 ? 0 : 10),
                              child: Entrance(delay: Duration(milliseconds: (index % 10) * 40), child: _FriendTile(friend: accepted[index], onChat: () => _openChat(accepted[index]), onPlay: () => _inviteToGame(accepted[index]), onMenu: () => _friendMenu(accepted[index]))),
                            ),
                            childCount: accepted.length,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => results = []);
      return;
    }
    setState(() => searching = true);
    try {
      final data = await ref.read(apiClientProvider).get('/users/search', query: {'q': query.trim()}) as List;
      if (mounted) setState(() => results = data.map((item) => Map<String, dynamic>.from(item as Map)).toList());
    } catch (_) {} finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _add(Map<String, dynamic> user) async {
    try {
      await ref.read(apiClientProvider).post('/users/friends/${user['id']}');
      if (mounted) {
        setState(() => results = []);
        search.clear();
        ref.invalidate(friendsProvider);
        showAppSnackBar(context, 'Friend request sent.');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _handleRequest(FriendEntry friend, String action) async {
    try {
      await ref.read(apiClientProvider).patch('/users/friends/${friend.friendshipId}', data: {'action': action});
      ref.invalidate(friendsProvider);
      if (mounted && action == 'accept') showAppSnackBar(context, '${friend.displayName} is now your friend.');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _openChat(FriendEntry friend) async {
    try {
      final data = await ref.read(apiClientProvider).post('/chat/conversations/private', data: {'userId': friend.id}) as Map;
      if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversation: Map<String, dynamic>.from(data))));
    } catch (error) {
      if (mounted) showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  Future<void> _inviteToGame(FriendEntry friend) async {
    final game = await showModalBottomSheet<GameDescriptor>(context: context, isScrollControlled: true, builder: (_) => const PlayTogetherSheet(partySize: 2));
    if (game == null || !mounted) return;
    try {
      final conversation = await ref.read(apiClientProvider).post('/chat/conversations/private', data: {'userId': friend.id}) as Map;
      await postRally(ref, conversationId: (conversation['id'] as Object).toString(), game: game, seats: seatsFor(game, 2));
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
      return;
    }
    if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchSetupScreen(game: game)));
  }

  Future<void> _friendMenu(FriendEntry friend) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: Theme.of(sheet).dividerColor, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 14),
              VibeInitial(name: friend.displayName, radius: 30),
              const SizedBox(height: 8),
              VibeText(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              VibeText('@${friend.username}', style: TextStyle(color: Theme.of(sheet).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              ListTile(leading: const Icon(Icons.chat_bubble_rounded, color: AppTheme.violet), title: const VibeText('Chat'), onTap: () => Navigator.of(sheet).pop('chat')),
              ListTile(leading: const Icon(Icons.sports_esports_rounded, color: AppTheme.violet), title: const VibeText('Invite to game'), onTap: () => Navigator.of(sheet).pop('play')),
              ListTile(leading: const Icon(Icons.person_remove_rounded, color: AppTheme.coral), title: const VibeText('Unfriend'), onTap: () => Navigator.of(sheet).pop('unfriend')),
              ListTile(leading: const Icon(Icons.block_rounded, color: AppTheme.coral), title: const VibeText('Block'), onTap: () => Navigator.of(sheet).pop('block')),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'chat') {
      _openChat(friend);
    } else if (action == 'play') {
      _inviteToGame(friend);
    } else if (action == 'unfriend' || action == 'block') {
      final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: VibeText(action == 'block' ? 'Block ${friend.displayName}?' : 'Unfriend ${friend.displayName}?'), content: VibeText(action == 'block' ? 'They will disappear from your friends and cannot contact you.' : 'You can send a new request later.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const VibeText('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: VibeText(action == 'block' ? 'Block' : 'Unfriend'))]));
      if (confirmed == true && mounted) _handleRequest(friend, action == 'block' ? 'block' : 'reject');
    }
  }

  Future<void> _createGroup(BuildContext context) async {
    final groupId = await showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (sheet) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom), child: const CreateGroupSheet()));
    if (groupId != null && context.mounted) {
      ref.invalidate(groupsProvider);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)));
    }
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onAdd});
  final List<Map<String, dynamic>> results;
  final ValueChanged<Map<String, dynamic>> onAdd;

  @override
  Widget build(BuildContext context) => VibeCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final user in results)
              ListTile(
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    VibeInitial(name: user['displayName']?.toString() ?? 'P', radius: 21),
                    if (user['isOnline'] == true) Positioned(right: -1, bottom: -1, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: AppTheme.mint, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2.5)))),
                  ],
                ),
                title: VibeText(user['displayName']?.toString() ?? 'Player', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: VibeText(user['isOnline'] == true ? 'Online now' : '@${user['username']}', style: TextStyle(color: user['isOnline'] == true ? AppTheme.mint : null)),
                trailing: Container(decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), shape: BoxShape.circle), child: IconButton(onPressed: () => onAdd(user), icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.violet, size: 20))),
              ),
          ],
        ),
      );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.friend, required this.onAccept, required this.onDecline});
  final FriendEntry friend;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final incoming = !friend.isRequester;
    return VibeCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          VibeInitial(name: friend.displayName, radius: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [VibeText(friend.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 2), VibeText(incoming ? 'Wants to be your friend' : 'Request sent · waiting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant))])),
          if (incoming) ...[
            FilledButton(onPressed: onAccept, style: FilledButton.styleFrom(minimumSize: const Size(64, 40), padding: const EdgeInsets.symmetric(horizontal: 16)), child: const VibeText('Accept')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onDecline, style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40), padding: const EdgeInsets.symmetric(horizontal: 14)), child: const VibeText('Decline')),
          ] else
            TextButton(onPressed: onDecline, child: const VibeText('Cancel')),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onChat, required this.onPlay, required this.onMenu});
  final FriendEntry friend;
  final VoidCallback onChat;
  final VoidCallback onPlay;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => VibeCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                VibeInitial(name: friend.displayName, radius: 24),
                if (friend.isOnline) Positioned(right: -1, bottom: -1, child: Container(width: 14, height: 14, decoration: BoxDecoration(color: AppTheme.mint, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2.5)))),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VibeText(friend.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  VibeText(friend.isOnline ? 'Online now' : '@${friend.username}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: friend.isOnline ? AppTheme.mint : Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Container(decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.12), shape: BoxShape.circle), child: IconButton(tooltip: 'Invite to game', onPressed: onPlay, icon: const Icon(Icons.sports_esports_rounded, color: AppTheme.mint, size: 20))),
            const SizedBox(width: 6),
            Container(decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.1), shape: BoxShape.circle), child: IconButton(tooltip: 'Chat', onPressed: onChat, icon: const Icon(Icons.chat_bubble_rounded, color: AppTheme.violet, size: 20))),
            InkWell(onTap: onMenu, borderRadius: BorderRadius.circular(99), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.more_vert_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20))),
          ],
        ),
      );
}

class _FriendsShimmer extends StatelessWidget {
  const _FriendsShimmer();
  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: ShimmerBox(height: 68, borderRadius: BorderRadius.all(Radius.circular(22))),
            ),
        ],
      );
}
