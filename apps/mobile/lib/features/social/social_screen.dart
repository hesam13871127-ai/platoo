import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import 'chat_socket.dart';

final friendsProvider = FutureProvider<List<FriendEntry>>((ref) async { final data = await ref.watch(apiClientProvider).get('/users/friends') as List; return data.map((item) => FriendEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList(); });

class SocialScreen extends ConsumerStatefulWidget { const SocialScreen({super.key}); @override ConsumerState<SocialScreen> createState() => _SocialScreenState(); }
class _SocialScreenState extends ConsumerState<SocialScreen> { final search = TextEditingController(); List<Map<String, dynamic>> results = []; bool searching = false; @override void dispose() { search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { final strings = AppStrings(Localizations.localeOf(context)); final friends = ref.watch(friendsProvider); return RefreshIndicator(onRefresh: () async { ref.invalidate(friendsProvider); try { await ref.read(friendsProvider.future); } catch (_) {} }, child: CustomScrollView(slivers: [SliverPadding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12), sliver: SliverToBoxAdapter(child: Row(children: [Text(strings.social, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), const Spacer(), IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen())), icon: const Icon(Icons.forum_rounded))]))), SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverToBoxAdapter(child: TextField(controller: search, onChanged: _search, decoration: InputDecoration(hintText: strings.isPersian ? 'جست‌وجوی دوستان' : 'Find people', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: searching ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null))),), if (results.isNotEmpty) SliverPadding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), sliver: SliverToBoxAdapter(child: _SearchResults(results: results, onAdd: _add))), SliverPadding(padding: const EdgeInsets.fromLTRB(20, 25, 20, 12), sliver: SliverToBoxAdapter(child: Row(children: [Text(strings.friends, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)), const Spacer(), TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen())), icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18), label: Text(strings.chat))]))), friends.when(loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())), error: (error, _) => const SliverFillRemaining(hasScrollBody: false, child: _SocialStatePanel(icon: Icons.cloud_off_rounded, title: 'Friends are offline', message: 'Pull down to try again.')), data: (list) => list.isEmpty ? const SliverFillRemaining(hasScrollBody: false, child: _SocialStatePanel(icon: Icons.people_outline_rounded, title: 'Your table is more fun with friends', message: 'Search for a player and send the first invite.')) : SliverList(delegate: SliverChildBuilderDelegate((context, index) => _FriendTile(friend: list[index], onAction: () => _friendAction(list[index]), onChat: () => _openChat(list[index])), childCount: list.length))), SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 30), child: FilledButton.tonalIcon(onPressed: () => _createGroup(context), icon: const Icon(Icons.group_add_rounded), label: const Text('Create a group'))))])); }
  Future<void> _search(String query) async { if (query.trim().length < 2) { setState(() => results = []); return; } setState(() => searching = true); try { final data = await ref.read(apiClientProvider).get('/users/search', query: {'q': query.trim()}) as List; if (mounted) setState(() => results = data.map((item) => Map<String, dynamic>.from(item as Map)).toList()); } catch (_) {} finally { if (mounted) setState(() => searching = false); } }
  Future<void> _add(Map<String, dynamic> user) async { try { await ref.read(apiClientProvider).post('/users/friends/${user['id']}'); if (mounted) { setState(() => results = []); ref.invalidate(friendsProvider); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent.'))); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } }
  Future<void> _friendAction(FriendEntry friend) async { if (friend.status == 'pending' && !friend.isRequester) { await ref.read(apiClientProvider).patch('/users/friends/${friend.friendshipId}', data: {'action': 'accept'}); ref.invalidate(friendsProvider); } }
  Future<void> _openChat(FriendEntry friend) async { try { final data = await ref.read(apiClientProvider).post('/chat/conversations/private', data: {'userId': friend.id}) as Map; if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversation: Map<String, dynamic>.from(data)))); } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()))); } }
  Future<void> _createGroup(BuildContext context) async { final name = TextEditingController(); final created = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('New group'), content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Group name')), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () async { if (name.text.trim().isEmpty) return; try { await ref.read(apiClientProvider).post('/users/groups', data: {'name': name.text.trim(), 'isPrivate': true}); if (context.mounted) Navigator.pop(context, true); } catch (_) {} }, child: const Text('Create'))])); name.dispose(); if (created == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group created.'))); }
}

class _SocialStatePanel extends StatelessWidget {
  const _SocialStatePanel({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 64, height: 64, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), shape: BoxShape.circle), child: Icon(icon, color: AppTheme.violet, size: 29)), const SizedBox(height: 13), Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center), const SizedBox(height: 6), Text(message, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center)])));
}

class _SearchResults extends StatelessWidget { const _SearchResults({required this.results, required this.onAdd}); final List<Map<String, dynamic>> results; final ValueChanged<Map<String, dynamic>> onAdd; @override Widget build(BuildContext context) => Card(child: Column(children: [for (final user in results) ListTile(leading: CircleAvatar(child: Text((user['displayName']?.toString() ?? 'P').substring(0, 1))), title: Text(user['displayName']?.toString() ?? 'Player', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('@${user['username']}'), trailing: IconButton(onPressed: () => onAdd(user), icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.violet)))])); }
class _FriendTile extends StatelessWidget { const _FriendTile({required this.friend, required this.onAction, required this.onChat}); final FriendEntry friend; final VoidCallback onAction; final VoidCallback onChat; @override Widget build(BuildContext context) { final pending = friend.status == 'pending'; return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), leading: Stack(children: [CircleAvatar(radius: 23, backgroundColor: AppTheme.violet.withOpacity(.15), child: Text(friend.displayName.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900))), if (friend.isOnline) Positioned(right: 0, bottom: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: AppTheme.mint, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2))))]), title: Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(pending ? (friend.isRequester ? 'Request sent' : 'Wants to play') : '@${friend.username}'), trailing: pending && !friend.isRequester ? FilledButton(onPressed: onAction, child: const Text('Accept')) : IconButton(onPressed: onChat, icon: const Icon(Icons.chat_bubble_outline_rounded))); } }

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(chatConversationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat', style: TextStyle(fontWeight: FontWeight.w900))),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No conversations yet.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final item = list[index];
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversation: item))),
                      leading: const CircleAvatar(child: Icon(Icons.forum_rounded)),
                      title: Text(item['title']?.toString() ?? 'Conversation', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(item['lastMessage']?.toString() ?? 'Start the conversation'),
                      trailing: item['unreadCount'] == 0 ? null : CircleAvatar(radius: 12, child: Text('${item['unreadCount']}')),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

final chatConversationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async { final data = await ref.watch(apiClientProvider).get('/chat/conversations') as List; return data.map((item) => Map<String, dynamic>.from(item as Map)).toList(); });

class _ChatConnectionBanner extends StatelessWidget {
  const _ChatConnectionBanner({required this.status, required this.onRetry});
  final ChatSocketStatus status;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final offline = status == ChatSocketStatus.disconnected;
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), color: Theme.of(context).colorScheme.surfaceVariant, child: Row(children: [Icon(offline ? Icons.cloud_off_rounded : Icons.sync_rounded, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 8), Expanded(child: Text(offline ? 'Chat is offline.' : 'Reconnecting chat…', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))), TextButton(onPressed: onRetry, child: const Text('Retry'))]));
  }
}


class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversation});
  final Map<String, dynamic> conversation;
  @override ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final input = TextEditingController();
  Timer? timer;
  late final ChatSocket socket;
  List<Map<String, dynamic>> messages = [];
  ChatSocketStatus socketStatus = ChatSocketStatus.connecting;
  @override void initState() { super.initState(); socket = ChatSocket(ref.read(tokenStoreProvider)); _load(); socket.connect(conversationId: widget.conversation['id'] as String, onStatus: (status) { if (mounted) setState(() => socketStatus = status); }, onMessage: (message) { if (mounted && !messages.any((item) => item['id'] == message['id'])) setState(() => messages = [...messages, message]); }); timer = Timer.periodic(const Duration(seconds: 10), (_) => _load()); }
  @override void dispose() { timer?.cancel(); socket.dispose(); input.dispose(); super.dispose(); }
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.conversation['title']?.toString() ?? 'Chat', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: Column(
        children: [
          if (socketStatus != ChatSocketStatus.connected) _ChatConnectionBanner(status: socketStatus, onRetry: socket.retry),
          Expanded(
            child: messages.isEmpty
                ? const Center(child: Text('Say hello 👋'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final message = messages[messages.length - 1 - index];
                      return Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(17)),
                          child: Text(message['body']?.toString() ?? ''),
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
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
