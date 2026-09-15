import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';
import 'chat_socket.dart';

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
    final onlineCount = friends.valueOrNull?.where((friend) => friend.isOnline && friend.status != 'pending').length ?? 0;
    return VibePageBackground(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendsProvider);
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
                      Text(strings.social, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(width: 10),
                      if (onlineCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.13), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppTheme.mint.withOpacity(.35))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.mint, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('$onlineCount online', style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w900, fontSize: 12)),
                          ]),
                        ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.1), shape: BoxShape.circle),
                        child: IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen())), icon: const Icon(Icons.forum_rounded, color: AppTheme.violet)),
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
                    title: strings.friends,
                    subtitle: strings.isPersian ? 'بازی با دوستان همیشه بهتر است' : 'Tables are better together',
                    actionLabel: strings.chat,
                    onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen())),
                  ),
                ),
              ),
              friends.when(
                loading: () => const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(child: _FriendsShimmer()),
                ),
                error: (error, _) => const SliverFillRemaining(hasScrollBody: false, child: StatePanel(icon: Icons.cloud_off_rounded, title: 'Friends are offline', message: 'Pull down to try again.')),
                data: (list) => list.isEmpty
                    ? const SliverFillRemaining(hasScrollBody: false, child: StatePanel(icon: Icons.people_outline_rounded, title: 'Your table is more fun with friends', message: 'Search for a player and send the first invite.'))
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: EdgeInsets.only(bottom: index == list.length - 1 ? 0 : 10),
                              child: Entrance(
                                delay: Duration(milliseconds: (index % 10) * 40),
                                child: _FriendTile(friend: list[index], onAction: () => _friendAction(list[index]), onChat: () => _openChat(list[index])),
                              ),
                            ),
                            childCount: list.length,
                          ),
                        ),
                      ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                  child: VibePrimaryButton(onPressed: () => _createGroup(context), icon: Icons.group_add_rounded, label: strings.isPersian ? 'ساخت گروه' : 'Create a group'),
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
        ref.invalidate(friendsProvider);
        showAppSnackBar(context, 'Friend request sent.');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _friendAction(FriendEntry friend) async {
    if (friend.status == 'pending' && !friend.isRequester) {
      await ref.read(apiClientProvider).patch('/users/friends/${friend.friendshipId}', data: {'action': 'accept'});
      ref.invalidate(friendsProvider);
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

  Future<void> _createGroup(BuildContext context) async {
    final name = TextEditingController();
    final created = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(title: const Text('New group'), content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Group name')), actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                  onPressed: () async {
                    if (name.text.trim().isEmpty) return;
                    try {
                      await ref.read(apiClientProvider).post('/users/groups', data: {'name': name.text.trim(), 'isPrivate': true});
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (_) {}
                  },
                  child: const Text('Create')),
            ]));
    name.dispose();
    if (created == true && context.mounted) showAppSnackBar(context, 'Group created.');
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
                leading: VibeInitial(name: user['displayName']?.toString() ?? 'P', radius: 21),
                title: Text(user['displayName']?.toString() ?? 'Player', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('@${user['username']}'),
                trailing: Container(
                  decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), shape: BoxShape.circle),
                  child: IconButton(onPressed: () => onAdd(user), icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.violet, size: 20)),
                ),
              ),
          ],
        ),
      );
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.onAction, required this.onChat});
  final FriendEntry friend;
  final VoidCallback onAction;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final pending = friend.status == 'pending';
    return VibeCard(
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
                Text(friend.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  pending ? (friend.isRequester ? 'Request sent' : 'Wants to play') : (friend.isOnline ? 'Online now' : '@${friend.username}'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: !pending && friend.isOnline ? AppTheme.mint : Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (pending && !friend.isRequester)
            FilledButton(onPressed: onAction, style: FilledButton.styleFrom(minimumSize: const Size(60, 40), padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('Accept'))
          else
            Container(
              decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.1), shape: BoxShape.circle),
              child: IconButton(onPressed: onChat, icon: const Icon(Icons.chat_bubble_rounded, color: AppTheme.violet, size: 20)),
            ),
        ],
      ),
    );
  }
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

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(chatConversationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatePanel(icon: Icons.cloud_off_rounded, title: 'Chat is unavailable', message: 'We could not load your conversations.', actionLabel: 'Try again', onAction: () => ref.invalidate(chatConversationsProvider)),
        data: (list) => list.isEmpty
            ? const StatePanel(icon: Icons.forum_outlined, title: 'No conversations yet', message: 'Open a friend and say hello to start chatting.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final item = list[index];
                  final unread = (item['unreadCount'] as num?)?.toInt() ?? 0;
                  return VibeCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversation: item))),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        VibeInitial(name: item['title']?.toString() ?? 'C', radius: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['title']?.toString() ?? 'Conversation', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(item['lastMessage']?.toString() ?? 'Start the conversation', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(gradient: AppTheme.coralGradient, borderRadius: BorderRadius.circular(99), boxShadow: AppTheme.glow(AppTheme.coral, strength: .35)),
                            child: Text('$unread', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final chatConversationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/chat/conversations') as List;
  return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
});

class _ChatConnectionBanner extends StatelessWidget {
  const _ChatConnectionBanner({required this.status, required this.onRetry});
  final ChatSocketStatus status;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final offline = status == ChatSocketStatus.disconnected;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(offline ? Icons.cloud_off_rounded : Icons.sync_rounded, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(offline ? 'Chat is offline.' : 'Reconnecting chat…', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversation});
  final Map<String, dynamic> conversation;
  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final input = TextEditingController();
  Timer? timer;
  late final ChatSocket socket;
  List<Map<String, dynamic>> messages = [];
  ChatSocketStatus socketStatus = ChatSocketStatus.connecting;

  @override
  void initState() {
    super.initState();
    socket = ChatSocket(ref.read(tokenStoreProvider));
    _load();
    socket.connect(
        conversationId: widget.conversation['id'] as String,
        onStatus: (status) {
          if (mounted) setState(() => socketStatus = status);
        },
        onMessage: (message) {
          if (mounted && !messages.any((item) => item['id'] == message['id'])) setState(() => messages = [...messages, message]);
        });
    timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    socket.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(apiClientProvider).get('/chat/conversations/${widget.conversation['id']}/messages') as List;
      if (mounted) setState(() => messages = data.map((item) => Map<String, dynamic>.from(item as Map)).toList());
    } catch (_) {}
  }

  Future<void> _send() async {
    final body = input.text.trim();
    if (body.isEmpty) return;
    input.clear();
    try {
      await ref.read(apiClientProvider).post('/chat/messages', data: {'conversationId': widget.conversation['id'], 'body': body, 'kind': 'text'});
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authProvider).value?.user?.id;
    return Scaffold(
      appBar: AppBar(title: Text(widget.conversation['title']?.toString() ?? 'Chat')),
      body: Column(
        children: [
          if (socketStatus != ChatSocketStatus.connected) _ChatConnectionBanner(status: socketStatus, onRetry: socket.retry),
          Expanded(
            child: messages.isEmpty
                ? const StatePanel(icon: Icons.waving_hand_rounded, title: 'No messages yet', message: 'Say hello and start the conversation.')
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final message = messages[messages.length - 1 - index];
                      final mine = myId != null && message['senderId']?.toString() == myId;
                      final sender = message['senderName']?.toString() ?? '';
                      return Align(
                        alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .75),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                          decoration: BoxDecoration(
                            color: mine ? null : Theme.of(context).colorScheme.surfaceVariant,
                            gradient: mine ? AppTheme.primaryGradient : null,
                            borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 6), bottomRight: Radius.circular(mine ? 6 : 18)),
                            boxShadow: mine ? AppTheme.glow(AppTheme.violet, strength: .28) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!mine && sender.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(sender, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                              Text(message['body']?.toString() ?? '', style: TextStyle(height: 1.35, color: mine ? Colors.white : null)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: input, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'Write a message'))),
                  const SizedBox(width: 8),
                  PressableScale(
                    onTap: _send,
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient, boxShadow: AppTheme.glow(AppTheme.violet, strength: .4)),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    ),
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
