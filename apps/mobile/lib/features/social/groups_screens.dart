import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/state_panel.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';
import '../games/match_setup_screen.dart';
import '../home/home_provider.dart';
import 'chat_screens.dart';

final groupsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/users/groups') as List;
  return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
});

final groupDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return Map<String, dynamic>.from(await ref.watch(apiClientProvider).get('/users/groups/$id') as Map);
});

Future<void> postRally(WidgetRef ref, {required String conversationId, required GameDescriptor game, required int seats}) async {
  final name = ref.read(authProvider).value?.user?.displayName ?? 'A player';
  await ref.read(apiClientProvider).post('/chat/messages', data: {'conversationId': conversationId, 'body': rallyMessageBody(actorName: name, gameName: game.name, gameId: game.id, seats: seats), 'kind': 'text'});
}

int seatsFor(GameDescriptor game, int partySize) => partySize.clamp(game.minPlayers, game.maxPlayers).toInt();

List<GameDescriptor> rallyGames(List<GameDescriptor> games, int partySize) {
  final eligible = games.where((game) => kGamesWithMobileBoard.contains(game.id) && game.maxPlayers >= 2 && game.minPlayers <= partySize).toList();
  eligible.sort((a, b) => a.minPlayers.compareTo(b.minPlayers));
  return eligible;
}

Future<List<FriendEntry>> fetchFriends(WidgetRef ref) async {
  final data = await ref.read(apiClientProvider).get('/users/friends') as List;
  return data.map((item) => FriendEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList();
}

class GroupsSection extends ConsumerWidget {
  const GroupsSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return groups.when(
      loading: () => SizedBox(height: 148, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: 3, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, __) => const ShimmerBox(width: 168, height: 148, borderRadius: BorderRadius.all(Radius.circular(22))))),
      error: (_, __) => VibeCard(onTap: () => ref.invalidate(groupsProvider), child: Row(children: [const Icon(Icons.refresh_rounded, color: AppTheme.violet), const SizedBox(width: 10), VibeText('Could not load groups. Tap to retry.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))])),
      data: (list) => SizedBox(
        height: 152,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) {
            if (index == 0) return _NewGroupCard(onTap: () => _openCreate(context, ref));
            final group = list[index - 1];
            return _GroupCard(group: group, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group['id'] as String))));
          },
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final groupId = await showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (sheet) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom), child: const CreateGroupSheet()));
    if (groupId != null && context.mounted) {
      ref.invalidate(groupsProvider);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)));
    }
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});
  final Map<String, dynamic> group;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final count = (group['memberCount'] as num?)?.toInt() ?? 1;
    final role = group['role']?.toString() ?? 'member';
    final private = group['isPrivate'] == true || group['isPrivate'] == 1;
    return SizedBox(
      width: 168,
      child: VibeCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VibeInitial(name: group['name']?.toString() ?? 'G', radius: 22),
                const Spacer(),
                Icon(private ? Icons.lock_outline_rounded : Icons.public_rounded, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 10),
            VibeText(group['name']?.toString() ?? 'Group', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, height: 1.2)),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.group_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                VibeText('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                if (role == 'owner') const Icon(Icons.workspace_premium_rounded, size: 15, color: AppTheme.gold),
                if (role == 'admin') const Icon(Icons.shield_rounded, size: 15, color: AppTheme.violet),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewGroupCard extends StatelessWidget {
  const _NewGroupCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 120,
        child: PressableScale(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.violet.withOpacity(.5), width: 1.6), color: AppTheme.violet.withOpacity(.07)),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.group_add_rounded, color: AppTheme.violet, size: 28), SizedBox(height: 8), VibeText('New\ngroup', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w900, fontSize: 13, height: 1.25))]),
          ),
        ),
      );
}

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});
  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final name = TextEditingController();
  final description = TextEditingController();
  bool private = true;
  bool busy = false;
  late final Future<List<FriendEntry>> friendsFuture;
  final selected = <String>{};

  @override
  void initState() {
    super.initState();
    friendsFuture = fetchFriends(ref);
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 16),
                const VibeText('Create a group', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
                const SizedBox(height: 4),
                VibeText('A home base for your table — with its own chat and game nights.', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                TextField(controller: name, autofocus: true, maxLength: 80, decoration: const InputDecoration(labelText: 'Group name', hintText: 'Friday night champions')),
                const SizedBox(height: 10),
                TextField(controller: description, maxLines: 2, maxLength: 280, decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'What is this group about?')),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => setState(() => private = !private),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(private ? Icons.lock_outline_rounded : Icons.public_rounded, color: AppTheme.violet, size: 19)),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [VibeText(private ? 'Private group' : 'Open group', style: const TextStyle(fontWeight: FontWeight.w800)), VibeText(private ? 'Only invited members can join' : 'Anyone with the group can join', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))])),
                      Switch(value: private, onChanged: (value) => setState(() => private = value)),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                const VibeText('Invite friends', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 8),
                FutureBuilder<List<FriendEntry>>(
                  future: friendsFuture,
                  builder: (_, snapshot) {
                    final friends = (snapshot.data ?? const <FriendEntry>[]).where((friend) => friend.status == 'accepted').toList();
                    if (snapshot.connectionState == ConnectionState.waiting) return const ShimmerBox(height: 52, borderRadius: BorderRadius.all(Radius.circular(16)));
                    if (friends.isEmpty) return VibeText('No friends yet — you can invite people after creating the group.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant));
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final friend in friends)
                          PressableScale(
                            onTap: () => setState(() => selected.contains(friend.id) ? selected.remove(friend.id) : selected.add(friend.id)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.only(left: 5, right: 12, top: 5, bottom: 5),
                              decoration: BoxDecoration(color: selected.contains(friend.id) ? AppTheme.violet : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: selected.contains(friend.id) ? AppTheme.violet : Theme.of(context).dividerColor)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [VibeInitial(name: friend.displayName, radius: 15), const SizedBox(width: 7), VibeText(friend.displayName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected.contains(friend.id) ? Colors.white : null))]),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                VibePrimaryButton(onPressed: busy ? null : _create, busy: busy, icon: Icons.group_add_rounded, label: selected.isEmpty ? 'Create group' : 'Create and invite ${selected.length}'),
              ],
            ),
          ),
        ),
      );

  Future<void> _create() async {
    final trimmed = name.text.trim();
    if (trimmed.length < 2 || busy) return;
    setState(() => busy = true);
    try {
      final created = await ref.read(apiClientProvider).post('/users/groups', data: {'name': trimmed, 'description': description.text.trim(), 'isPrivate': private}) as Map;
      var failures = 0;
      for (final userId in selected) {
        try {
          await ref.read(apiClientProvider).post('/users/groups/${created['id']}/members', data: {'userId': userId});
        } catch (_) {
          failures += 1;
        }
      }
      if (!mounted) return;
      if (failures > 0) showAppSnackBar(context, 'Group created, but $failures invite${failures == 1 ? '' : 's'} failed.', isError: true);
      Navigator.of(context).pop((created['id'] as Object?)?.toString());
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.toString(), isError: true);
        setState(() => busy = false);
      }
    }
  }
}

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(groupDetailProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: const VibeText('Group')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => StatePanel(icon: Icons.cloud_off_rounded, title: 'Group unavailable', message: 'We could not load this group.', actionLabel: 'Try again', onAction: () => ref.invalidate(groupDetailProvider(groupId))),
        data: (group) => _GroupDetailBody(group: group, onChanged: () => ref.invalidate(groupDetailProvider(groupId))),
      ),
    );
  }
}

class _GroupDetailBody extends ConsumerWidget {
  const _GroupDetailBody({required this.group, required this.onChanged});
  final Map<String, dynamic> group;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Warm the cache so the group chat opens instantly.
    ref.watch(chatConversationsProvider);
    final members = (group['members'] as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final myId = ref.watch(authProvider).value?.user?.id;
    final myRole = group['role']?.toString() ?? 'member';
    final canManage = myRole == 'owner' || myRole == 'admin';
    final private = group['isPrivate'] == true || group['isPrivate'] == 1;
    final onlineCount = members.where((member) => member['isOnline'] == true).length;
    final groupId = group['id'].toString();

    return RefreshIndicator(
      onRefresh: () async {
        onChanged();
        try {
          await ref.read(groupDetailProvider(groupId).future);
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        children: [
          VibeCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                VibeInitial(name: group['name']?.toString() ?? 'G', radius: 34),
                const SizedBox(height: 12),
                VibeText(group['name']?.toString() ?? 'Group', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                if ((group['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  VibeText(group['description'].toString(), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    _HeaderChip(icon: Icons.group_rounded, label: '${members.length} members'),
                    if (onlineCount > 0) _HeaderChip(icon: Icons.circle, iconColor: AppTheme.mint, label: '$onlineCount online'),
                    _HeaderChip(icon: private ? Icons.lock_outline_rounded : Icons.public_rounded, label: private ? 'Private' : 'Open'),
                    _HeaderChip(icon: myRole == 'owner' ? Icons.workspace_premium_rounded : myRole == 'admin' ? Icons.shield_rounded : Icons.person_rounded, label: 'You: $myRole'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _DetailAction(icon: Icons.forum_rounded, label: 'Chat', primary: true, onTap: () => _openChat(context, ref))),
              const SizedBox(width: 10),
              Expanded(child: _DetailAction(icon: Icons.person_add_alt_1_rounded, label: 'Invite', onTap: canManage ? () => _openInvite(context, ref, members) : null)),
              const SizedBox(width: 10),
              Expanded(child: _DetailAction(icon: Icons.sports_esports_rounded, label: 'Play', onTap: () => _openPlay(context, ref, members.length))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              VibeText('Members', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              VibeText('${members.length}', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const Spacer(),
              if (!canManage) VibeText('Ask an admin to invite friends', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          for (final member in members) _MemberTile(groupId: groupId, member: member, myId: myId, myRole: myRole, onChanged: onChanged),
          const SizedBox(height: 20),
          if (members.length <= 1)
            OutlinedButton.icon(onPressed: () => _leave(context, ref, disband: true), icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.coral), label: const VibeText('Disband group', style: TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w800)))
          else
            OutlinedButton.icon(onPressed: () => _leave(context, ref, disband: false), icon: const Icon(Icons.logout_rounded, color: AppTheme.coral), label: const VibeText('Leave group', style: TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _groupConversation(WidgetRef ref) async {
    try {
      final conversations = await ref.read(chatConversationsProvider.future);
      final found = conversations.where((item) => item['type']?.toString() == 'group' && item['groupId']?.toString() == group['id'].toString()).toList();
      return found.isEmpty ? null : found.first;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final conversation = await _groupConversation(ref);
    if (conversation == null) {
      if (context.mounted) showAppSnackBar(context, 'Group chat is not ready yet. Pull to refresh and try again.', isError: true);
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversation: conversation)));
    onChanged();
  }

  Future<void> _openInvite(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> members) async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (sheet) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom), child: InviteToGroupSheet(groupId: group['id'].toString(), memberIds: members.map((member) => member['id'].toString()).toSet(), onChanged: onChanged)));
    onChanged();
  }

  Future<void> _openPlay(BuildContext context, WidgetRef ref, int memberCount) async {
    final game = await showModalBottomSheet<GameDescriptor>(context: context, isScrollControlled: true, builder: (_) => PlayTogetherSheet(partySize: memberCount));
    if (game == null || !context.mounted) return;
    final conversation = await _groupConversation(ref);
    if (conversation != null) {
      try {
        await postRally(ref, conversationId: conversation['id'].toString(), game: game, seats: seatsFor(game, memberCount));
      } catch (_) {}
    }
    if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchSetupScreen(game: game)));
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, {required bool disband}) async {
    final myId = ref.read(authProvider).value?.user?.id;
    if (myId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: VibeText(disband ? 'Disband this group?' : 'Leave this group?'),
        content: VibeText(disband ? 'The group, its members, and its chat will be removed for everyone.' : (group['role']?.toString() == 'owner' ? 'Ownership passes to the longest-standing admin or member.' : 'You can be invited back at any time.')),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const VibeText('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: VibeText(disband ? 'Disband' : 'Leave'))],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/users/groups/${group['id']}/members/$myId');
      ref.invalidate(groupsProvider);
      if (context.mounted) {
        showAppSnackBar(context, disband ? 'Group disbanded.' : 'You left the group.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label, this.iconColor});
  final IconData icon;
  final String label;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.55), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 5), VibeText(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
      );
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => PressableScale(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .45 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: primary ? BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: AppTheme.glow(AppTheme.violet, strength: .35)) : BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).dividerColor)),
            child: Column(children: [Icon(icon, color: primary ? Colors.white : AppTheme.violet, size: 22), const SizedBox(height: 4), VibeText(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: primary ? Colors.white : null))]),
          ),
        ),
      );
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.groupId, required this.member, required this.myId, required this.myRole, required this.onChanged});
  final String groupId;
  final Map<String, dynamic> member;
  final String? myId;
  final String myRole;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelf = member['id']?.toString() == myId;
    final role = member['role']?.toString() ?? 'member';
    final online = member['isOnline'] == true;
    final canRemove = !isSelf && ((myRole == 'owner' && role != 'owner') || (myRole == 'admin' && role == 'member'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: VibeCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                VibeInitial(name: member['displayName']?.toString() ?? 'P', radius: 22),
                if (online) Positioned(right: -1, bottom: -1, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: AppTheme.mint, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2.5)))),
              ],
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Flexible(child: VibeText('${member['displayName'] ?? 'Player'}${isSelf ? ' (you)' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)))]),
                  const SizedBox(height: 3),
                  Row(children: [if (role == 'owner') const _RolePill(icon: Icons.workspace_premium_rounded, label: 'Owner', color: AppTheme.gold) else if (role == 'admin') const _RolePill(icon: Icons.shield_rounded, label: 'Admin', color: AppTheme.violet) else VibeText('@${member['username'] ?? 'player'}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))]),
                ],
              ),
            ),
            if (!isSelf) ...[
              Container(decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.1), shape: BoxShape.circle), child: IconButton(onPressed: () => _chat(context, ref), icon: const Icon(Icons.chat_bubble_rounded, color: AppTheme.violet, size: 19))),
              if (canRemove) ...[
                const SizedBox(width: 6),
                Container(decoration: BoxDecoration(color: AppTheme.coral.withOpacity(.1), shape: BoxShape.circle), child: IconButton(onPressed: () => _remove(context, ref), icon: const Icon(Icons.person_remove_rounded, color: AppTheme.coral, size: 19))),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _chat(BuildContext context, WidgetRef ref) async {
    try {
      final data = await ref.read(apiClientProvider).post('/chat/conversations/private', data: {'userId': member['id']}) as Map;
      if (context.mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversation: Map<String, dynamic>.from(data))));
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const VibeText('Remove member?'), content: VibeText('${member['displayName'] ?? 'This player'} will lose access to the group and its chat.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const VibeText('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const VibeText('Remove'))]));
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/users/groups/$groupId/members/${member['id']}');
      onChanged();
      if (context.mounted) showAppSnackBar(context, 'Member removed.');
    } catch (e) {
      if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), VibeText(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color))]));
}

class InviteToGroupSheet extends ConsumerStatefulWidget {
  const InviteToGroupSheet({super.key, required this.groupId, required this.memberIds, required this.onChanged});
  final String groupId;
  final Set<String> memberIds;
  final VoidCallback onChanged;
  @override
  ConsumerState<InviteToGroupSheet> createState() => _InviteToGroupSheetState();
}

class _InviteToGroupSheetState extends ConsumerState<InviteToGroupSheet> {
  final search = TextEditingController();
  late final Future<List<FriendEntry>> friendsFuture;
  List<Map<String, dynamic>> results = [];
  bool searching = false;
  final adding = <String>{};
  final added = <String>{};

  @override
  void initState() {
    super.initState();
    friendsFuture = fetchFriends(ref);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 16),
              const VibeText('Invite to group', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
              const SizedBox(height: 4),
              VibeText('Friends join instantly. Anyone you find by search can be added too.', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              TextField(controller: search, onChanged: _search, decoration: InputDecoration(hintText: 'Search players', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: searching ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FutureBuilder<List<FriendEntry>>(
                        future: friendsFuture,
                        builder: (_, snapshot) {
                          final friends = (snapshot.data ?? const <FriendEntry>[]).where((friend) => friend.status == 'accepted' && !widget.memberIds.contains(friend.id)).toList();
                          if (snapshot.connectionState == ConnectionState.waiting) return const ShimmerBox(height: 120, borderRadius: BorderRadius.all(Radius.circular(16)));
                          if (friends.isEmpty && results.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: VibeText('Everyone you know is already here. Search above to find more players.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)));
                          final friendIds = friends.map((friend) => friend.id).toSet();
                          final extra = results.where((user) => !widget.memberIds.contains(user['id']?.toString()) && !friendIds.contains(user['id']?.toString())).toList();
                          return Column(
                            children: [
                              for (final friend in friends) _InviteRow(id: friend.id, name: friend.displayName, username: friend.username, online: friend.isOnline, state: added.contains(friend.id) ? 2 : adding.contains(friend.id) ? 1 : 0, onAdd: () => _add(friend.id)),
                              if (extra.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Align(alignment: Alignment.centerLeft, child: VibeText('Search results', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                                const SizedBox(height: 6),
                                for (final user in extra) _InviteRow(id: user['id'].toString(), name: user['displayName']?.toString() ?? 'Player', username: user['username']?.toString() ?? 'player', online: user['isOnline'] == true, state: added.contains(user['id']?.toString()) ? 2 : adding.contains(user['id']?.toString()) ? 1 : 0, onAdd: () => _add(user['id'].toString())),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

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

  Future<void> _add(String userId) async {
    if (adding.contains(userId) || added.contains(userId)) return;
    setState(() => adding.add(userId));
    try {
      await ref.read(apiClientProvider).post('/users/groups/${widget.groupId}/members', data: {'userId': userId});
      if (mounted) setState(() => added.add(userId));
      widget.onChanged();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => adding.remove(userId));
    }
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.id, required this.name, required this.username, required this.online, required this.state, required this.onAdd});
  final String id;
  final String name;
  final String username;
  final bool online;
  final int state;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: VibeCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  VibeInitial(name: name, radius: 20),
                  if (online) Positioned(right: -1, bottom: -1, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: AppTheme.mint, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2.5)))),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [VibeText(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), VibeText('@$username', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))])),
              if (state == 2)
                const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_rounded, color: AppTheme.mint, size: 19), SizedBox(width: 5), VibeText('Added', style: TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w900, fontSize: 13))])
              else if (state == 1)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                FilledButton.tonal(onPressed: onAdd, style: FilledButton.styleFrom(minimumSize: const Size(64, 36), padding: const EdgeInsets.symmetric(horizontal: 14)), child: const VibeText('Add')),
            ],
          ),
        ),
      );
}

class PlayTogetherSheet extends ConsumerWidget {
  const PlayTogetherSheet({super.key, required this.partySize});
  final int partySize;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(gamesProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(99)))),
            const SizedBox(height: 16),
            const VibeText('Play together', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
            const SizedBox(height: 4),
            VibeText('Pick a game — an invite lands in the chat and you jump into the queue.', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            Flexible(
              child: games.when(
                loading: () => _GameList(games: rallyGames(localGameCatalog, partySize)),
                error: (_, __) => _GameList(games: rallyGames(localGameCatalog, partySize)),
                data: (list) => _GameList(games: rallyGames(list.isEmpty ? localGameCatalog : list, partySize)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameList extends StatelessWidget {
  const _GameList({required this.games});
  final List<GameDescriptor> games;
  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: VibeText('No games fit this party size right now.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
    return SingleChildScrollView(
      child: Column(
        children: [
          for (final game in games)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VibeCard(
                onTap: () => Navigator.of(context).pop(game),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                child: Row(
                  children: [
                    GameLogo(gameId: game.id, accent: game.accent, size: 46),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [VibeText(game.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), const SizedBox(height: 3), VibeText('${game.minPlayers}–${game.maxPlayers} players${game.supportsTeams ? ' · teams' : ''}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))])),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.violet),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
