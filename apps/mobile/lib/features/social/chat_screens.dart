import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../games/match_setup_screen.dart';
import '../home/home_provider.dart';
import 'chat_socket.dart';

final chatConversationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/chat/conversations') as List;
  return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
});

/// Game rally embedded in a chat message: `... [rally:gameId:seats]`.
/// Rendered as a join card; unknown games fall back to plain text.
final _rallyPattern = RegExp(r'\[rally:([A-Za-z0-9_]+):(\d+)\]');

({String gameId, int seats})? parseRally(String body) {
  final match = _rallyPattern.firstMatch(body);
  if (match == null) return null;
  return (gameId: match.group(1)!, seats: int.tryParse(match.group(2) ?? '') ?? 2);
}

String rallyMessageBody({required String actorName, required String gameName, required String gameId, required int seats}) =>
    '🎮 $actorName wants to play $gameName!\nQueue up for the same game to land at one table. [rally:$gameId:$seats]';

String friendlyChatTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final parsed = DateTime.tryParse(iso)?.toLocal();
  if (parsed == null) return '';
  final diff = DateTime.now().difference(parsed);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${parsed.day}/${parsed.month}/${parsed.year}';
}

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});
  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final filter = TextEditingController();

  @override
  void dispose() {
    filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(chatConversationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: filter,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Search conversations', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => StatePanel(icon: Icons.cloud_off_rounded, title: 'Chat is unavailable', message: 'We could not load your conversations.', actionLabel: 'Try again', onAction: () => ref.invalidate(chatConversationsProvider)),
              data: (list) {
                final query = filter.text.trim().toLowerCase();
                final visible = query.isEmpty ? list : list.where((item) => (item['title']?.toString() ?? '').toLowerCase().contains(query)).toList();
                if (list.isEmpty) return const StatePanel(icon: Icons.forum_outlined, title: 'No conversations yet', message: 'Open a friend or a group and say hello to start chatting.');
                if (visible.isEmpty) return const StatePanel(icon: Icons.search_off_rounded, title: 'No matches', message: 'Try a different search.');
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(chatConversationsProvider);
                    try {
                      await ref.read(chatConversationsProvider.future);
                    } catch (_) {}
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final item = visible[index];
                      final unread = (item['unreadCount'] as num?)?.toInt() ?? 0;
                      final isGroup = item['type']?.toString() == 'group';
                      final last = item['lastMessage']?.toString() ?? '';
                      final preview = parseRally(last) != null ? '🎮 Game invite — tap to join the queue' : last.isEmpty ? 'Start the conversation' : last;
                      return VibeCard(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversation: item))),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                VibeInitial(name: item['title']?.toString() ?? 'C', radius: 24),
                                if (isGroup) Positioned(right: -3, bottom: -3, child: Container(width: 20, height: 20, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.violet, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2)), child: const Icon(Icons.group_rounded, color: Colors.white, size: 11))),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(item['title']?.toString() ?? 'Conversation', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                                      const SizedBox(width: 8),
                                      Text(friendlyChatTime(item['lastMessageAt']?.toString()), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Expanded(child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: unread > 0 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400))),
                                      if (unread > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(gradient: AppTheme.coralGradient, borderRadius: BorderRadius.circular(99), boxShadow: AppTheme.glow(AppTheme.coral, strength: .35)), child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
      // The server returns newest-first; the list below reads oldest-first.
      final loaded = data.map((item) => Map<String, dynamic>.from(item as Map)).toList().reversed.toList();
      if (!mounted) return;
      setState(() => messages = loaded);
      final myId = ref.read(authProvider).value?.user?.id;
      final unread = loaded.reversed.where((item) => item['senderId']?.toString() != myId).toList();
      if (unread.isNotEmpty) {
        try {
          await ref.read(apiClientProvider).post('/chat/conversations/${widget.conversation['id']}/read/${unread.first['id']}');
          ref.invalidate(chatConversationsProvider);
        } catch (_) {}
      }
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
    final isGroup = widget.conversation['type']?.toString() == 'group';
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          if (isGroup) ...[Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.14), shape: BoxShape.circle), child: const Icon(Icons.group_rounded, color: AppTheme.violet, size: 18)), const SizedBox(width: 9)],
          Expanded(child: Text(widget.conversation['title']?.toString() ?? 'Chat', maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
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
                      final rally = parseRally(message['body']?.toString() ?? '');
                      if (rally != null) return _RallyBubble(message: message, rally: rally, mine: mine);
                      return _MessageBubble(message: message, mine: mine);
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
                    child: Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient, boxShadow: AppTheme.glow(AppTheme.violet, strength: .4)), child: const Icon(Icons.send_rounded, color: Colors.white, size: 22)),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});
  final Map<String, dynamic> message;
  final bool mine;
  @override
  Widget build(BuildContext context) {
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
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine && sender.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(sender, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Text(message['body']?.toString() ?? '', style: TextStyle(height: 1.35, color: mine ? Colors.white : null)),
            const SizedBox(height: 3),
            Text(friendlyChatTime(message['createdAt']?.toString()), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: mine ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _RallyBubble extends StatelessWidget {
  const _RallyBubble({required this.message, required this.rally, required this.mine});
  final Map<String, dynamic> message;
  final ({String gameId, int seats}) rally;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final games = localGameCatalog.where((game) => game.id == rally.gameId).toList();
    if (games.isEmpty) return _MessageBubble(message: message, mine: mine);
    final game = games.first;
    final sender = message['senderName']?.toString() ?? '';
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.violet.withOpacity(.2), AppTheme.violet.withOpacity(.07)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.violet.withOpacity(.45), width: 1.4),
          boxShadow: AppTheme.glow(AppTheme.violet, strength: .25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GameLogo(gameId: game.id, accent: game.accent, size: 46),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🎮 Game invite', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .6, color: AppTheme.violet)),
                      const SizedBox(height: 2),
                      Text(mine ? 'You rallied for ${game.name}' : '$sender rallied for ${game.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Queue up for the same game to land at one table.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.14), borderRadius: BorderRadius.circular(99)), child: Text('${game.minPlayers}–${game.maxPlayers} players', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.violet))),
                const Spacer(),
                PressableScale(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchSetupScreen(game: game))),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9), decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(99), boxShadow: AppTheme.glow(AppTheme.violet, strength: .35)), child: const Text('Join queue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
