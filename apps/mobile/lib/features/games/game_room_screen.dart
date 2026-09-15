import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_service.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/vibe_components.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';
import 'game_rules_sheet.dart';
import 'game_socket.dart';
import 'four_in_a_row_game_board.dart';
import 'ocho_game_board.dart';
import 'chess_game_board.dart';
import 'ludo_game_board.dart';
import 'pool_game_board.dart';
import 'werewolf_game_board.dart';
import 'bingo_game_board.dart';
import 'dominoes_game_board.dart';
import 'carrom_game_board.dart';
import 'mini_golf_game_board.dart';
import 'table_soccer_game_board.dart';
import 'sketch_guess_game_board.dart';
import 'trivia_battle_game_board.dart';
import 'checkers_game_board.dart';
import 'mancala_game_board.dart';
import 'sea_battle_game_board.dart';
import 'backgammon_game_board.dart';
import 'hearts_game_board.dart';
import 'dice_party_game_board.dart';
import 'bowling_game_board.dart';
import 'darts_game_board.dart';
import 'emoji_charades_game_board.dart';
import 'impostor_light_game_board.dart';
import 'archery_game_board.dart';
import 'quick_challenges_game_board.dart';
import '../social/chat_screens.dart';

class GameRoomScreen extends ConsumerStatefulWidget {
  const GameRoomScreen({super.key, required this.matchId, required this.game});
  final String matchId;
  final GameDescriptor game;

  @override
  ConsumerState<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends ConsumerState<GameRoomScreen> {
  MatchModel? match;
  String? error;
  Timer? poller;
  Timer? completionGrace;
  late final GameSocket socket;
  bool completionSynced = false;
  bool rewardProfileSynced = false;
  bool actionPending = false;
  bool loadInFlight = false;
  bool leaving = false;
  GameSocketStatus socketStatus = GameSocketStatus.connecting;
  int socketRetries = 0;
  int loadFailures = 0;

  // Floating live reaction overlay
  final List<_FloatingEmote> _activeEmotes = [];

  @override
  void initState() {
    super.initState();
    socket = GameSocket(ref.read(tokenStoreProvider));
    unawaited(socket.connect(
      matchId: widget.matchId,
      onUpdate: _acceptMatch,
      onError: _handleSocketError,
      onStatus: _handleSocketStatus,
      onRetryAttempt: _handleSocketRetry,
    ));
    unawaited(_load());
    poller = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_load()));
  }

  @override
  void dispose() {
    poller?.cancel();
    completionGrace?.cancel();
    socket.dispose();
    super.dispose();
  }

  void _handleSocketStatus(GameSocketStatus status) {
    if (!mounted) return;
    setState(() {
      socketStatus = status;
      if (status == GameSocketStatus.connected) socketRetries = 0;
    });
  }

  void _handleSocketRetry(int attempt, Duration nextDelay) {
    if (!mounted) return;
    setState(() => socketRetries = attempt);
  }

  void _handleSocketError(String message) {
    if (!mounted) return;
    setState(() => error = message);
  }

  void _noteTurnTransition(MatchModel? current, MatchModel next) {
    if (current == null) return;
    final viewer = next.players.where((player) => player['seat'] == next.viewerSeat).toList();
    if (viewer.isEmpty) return;
    final viewerId = viewer.first['id'];
    if (next.status == 'finished' && current.status != 'finished') {
      if (viewer.first['result'] == 'win') {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
      return;
    }
    if (next.status == 'active' && next.state['turnPlayerId'] == viewerId && current.state['turnPlayerId'] != viewerId) {
      HapticFeedback.lightImpact();
    }
  }

  Future<bool> _confirmLeave() async {
    final current = match;
    if (leaving || current == null || current.status != 'active') return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave the table?'),
        content: const Text('The match will keep running while you are away. You can return from your active matches later.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _leave() async {
    if (leaving || !mounted) return;
    if (!await _confirmLeave() || !mounted) return;
    setState(() => leaving = true);
    Navigator.of(context).pop();
  }

  void _acceptMatch(Map<String, dynamic> data) {
    try {
      final next = MatchModel.fromJson(Map<String, dynamic>.from(data));
      if (!mounted || next.id != widget.matchId || next.gameId != widget.game.id) return;
      final current = match;
      if (current != null && next.revision < current.revision) return;
      if (current != null && next.revision == current.revision && current.status == 'finished' && (next.status != 'finished' || (current.reward != null && next.reward == null))) return;
      _noteTurnTransition(current, next);
      setState(() {
        match = next;
        error = null;
        loadFailures = 0;
      });
      if (next.status == 'finished') {
        if (next.reward != null) {
          poller?.cancel();
          completionGrace?.cancel();
          completionGrace = null;
        } else {
          completionGrace ??= Timer(const Duration(seconds: 60), () {
            poller?.cancel();
            completionGrace = null;
          });
        }
        if (!completionSynced) {
          completionSynced = true;
          rewardProfileSynced = next.reward != null;
          unawaited(ref.read(authProvider.notifier).refreshProfile());
        } else if (next.reward != null && !rewardProfileSynced) {
          rewardProfileSynced = true;
          unawaited(ref.read(authProvider.notifier).refreshProfile());
        }
      }
    } catch (_) {
      if (mounted) setState(() => error = 'The match update could not be read.');
    }
  }

  Future<void> _load() async {
    if (loadInFlight) return;
    loadInFlight = true;
    try {
      final data = await ref.read(apiClientProvider).get('/matches/${widget.matchId}') as Map;
      _acceptMatch(Map<String, dynamic>.from(data));
    } catch (e) {
      if (mounted) setState(() {
        loadFailures += 1;
        error = _friendlyError(e);
      });
    } finally {
      loadInFlight = false;
    }
  }

  String _friendlyError(Object error) => error is ApiException ? error.message : 'We could not reach the table. Showing the last confirmed state.';

  Future<void> _action(Map<String, dynamic> action) async {
    final current = match;
    if (actionPending || current == null || current.status != 'active') return;
    setState(() => actionPending = true);
    try {
      final payload = <String, dynamic>{...action, 'revision': current.revision};
      final data = await ref.read(apiClientProvider).post('/matches/${widget.matchId}/actions', data: payload) as Map;
      _acceptMatch(Map<String, dynamic>.from(data));
    } catch (e) {
      await _load();
      if (mounted) showAppSnackBar(context, _friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => actionPending = false);
    }
  }

  Future<void> _resign() async {
    final current = match;
    if (actionPending || current == null || current.status != 'active') return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resign this match?'),
        content: const Text('Resigning counts as a loss and your opponents win the table. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep playing')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => actionPending = true);
    try {
      final data = await ref.read(apiClientProvider).post('/matches/${widget.matchId}/resign') as Map;
      _acceptMatch(Map<String, dynamic>.from(data));
    } catch (e) {
      await _load();
      if (mounted) showAppSnackBar(context, _friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => actionPending = false);
    }
  }

  void _retryLiveUpdates() {
    socket.retry();
    unawaited(_load());
  }

  void _sendEmote(String emote) {
    HapticFeedback.lightImpact();
    final emoteKey = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _activeEmotes.add(_FloatingEmote(id: emoteKey, text: emote));
    });
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _activeEmotes.removeWhere((item) => item.id == emoteKey));
    });

    final convId = match?.conversationId;
    if (convId != null) {
      ref.read(apiClientProvider).post('/chat/messages', data: {
        'conversationId': convId,
        'body': emote,
        'kind': 'text',
      }).catchError((_) => null);
    }
  }

  String? get _syncMessage {
    if (loadFailures >= 2) return 'You look offline — retrying automatically. Moves send when you reconnect.';
    if (error != null) return 'Showing the last confirmed state. ${error!}';
    return switch (socketStatus) {
      GameSocketStatus.connected => actionPending ? 'Sending your move…' : null,
      GameSocketStatus.connecting => 'Connecting to the live table…',
      GameSocketStatus.reconnecting => socketRetries > 0 ? 'Reconnecting… (attempt $socketRetries)' : 'Live updates paused · reconnecting…',
      GameSocketStatus.disconnected => socket.slowMode ? 'Live updates are offline · moves still sync. Tap Retry to reconnect now.' : 'Live updates are offline · REST sync is still available.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final current = match;
    return PopScope(
      canPop: current == null || current.status == 'finished' || current.status == 'cancelled' || leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: leaving ? null : _leave, icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Leave table'),
          title: Row(
            children: [
              Hero(tag: 'game-${widget.game.id}', child: GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 34)),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.game.name, style: const TextStyle(fontWeight: FontWeight.w900))),
              if (current?.status == 'finished') const Icon(Icons.emoji_events_rounded, color: AppTheme.gold),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => GameRulesSheet.show(context, widget.game),
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: 'How to play & rules',
            ),
            _ConnectionDot(status: socketStatus, onTap: _retryLiveUpdates),
            VoiceRoomButton(api: ref.read(apiClientProvider), matchId: widget.matchId),
            IconButton(onPressed: () => unawaited(_load()), icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh match'),
            if (current?.status == 'active') IconButton(onPressed: actionPending ? null : _resign, icon: const Icon(Icons.flag_outlined), tooltip: 'Resign match'),
          ],
        ),
        body: Stack(
          children: [
            current == null
                ? _RoomLoading(error: error, onRetry: _retryLiveUpdates)
                : _MatchBody(
                    match: current,
                    game: widget.game,
                    onAction: _action,
                    actionPending: actionPending,
                    syncMessage: _syncMessage,
                    onRetrySync: _retryLiveUpdates,
                    onSendEmote: _sendEmote,
                  ),
            if (_activeEmotes.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      for (final emote in _activeEmotes)
                        _AnimatedFloatingEmote(key: ValueKey(emote.id), emote: emote.text),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingEmote {
  const _FloatingEmote({required this.id, required this.text});
  final String id;
  final String text;
}

class _AnimatedFloatingEmote extends StatefulWidget {
  const _AnimatedFloatingEmote({super.key, required this.emote});
  final String emote;

  @override
  State<_AnimatedFloatingEmote> createState() => _AnimatedFloatingEmoteState();
}

class _AnimatedFloatingEmoteState extends State<_AnimatedFloatingEmote> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  final double _randomDx = (math.Random().nextDouble() - 0.5) * 80;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final opacity = (1.0 - progress * progress).clamp(0.0, 1.0);
          final scale = 0.6 + math.sin(progress * math.pi * 0.7) * 0.6;
          final dy = -progress * 240;

          return Center(
            child: Transform.translate(
              offset: Offset(_randomDx, dy),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.75),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: AppTheme.glow(AppTheme.violet, strength: .4),
                      border: Border.all(color: Colors.white.withOpacity(.3), width: 1.5),
                    ),
                    child: Text(
                      widget.emote,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _RoomLoading extends StatelessWidget {
  const _RoomLoading({required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.12), shape: BoxShape.circle),
                    child: error == null
                        ? SizedBox(width: 25, height: 25, child: CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.primary))
                        : Icon(Icons.cloud_off_rounded, color: Theme.of(context).colorScheme.primary, size: 27),
                  ),
                  const SizedBox(height: 18),
                  Text(error == null ? 'Loading your table…' : 'We could not load this table.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(error ?? 'Connecting to the latest confirmed match state.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class _MatchBody extends StatelessWidget {
  const _MatchBody({
    required this.match,
    required this.game,
    required this.onAction,
    required this.actionPending,
    required this.syncMessage,
    required this.onRetrySync,
    required this.onSendEmote,
  });

  final MatchModel match;
  final GameDescriptor game;
  final ValueChanged<Map<String, dynamic>> onAction;
  final bool actionPending;
  final String? syncMessage;
  final VoidCallback onRetrySync;
  final ValueChanged<String> onSendEmote;

  @override
  Widget build(BuildContext context) {
    final active = match.status == 'active';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: match.players.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final player = match.players[index];
                  return _PlayerChip(
                    name: player['displayName']?.toString() ?? 'Player',
                    bot: player['isBot'] as bool? ?? false,
                    active: active && match.state['turnPlayerId'] == player['id'],
                    winner: match.winnerIds.contains(player['id']),
                    color: index.isEven ? AppTheme.violet : AppTheme.coral,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (syncMessage != null) _SyncBanner(message: syncMessage!, onRetry: onRetrySync),
            if (match.status == 'finished') _ResultBanner(match: match, game: game),
            if (match.status == 'cancelled') const _CancelledBanner(),
            Stack(
              children: [
                GameCanvas(game: game, state: match.state, match: match, onAction: onAction),
                if (actionPending) const Positioned.fill(child: _SendingMoveOverlay()),
              ],
            ),
            const SizedBox(height: 14),
            _TurnHint(match: match),
            if (active) ...[
              const SizedBox(height: 14),
              _QuickReactionRow(onSelect: onSendEmote),
            ],
            const SizedBox(height: 16),
            _RoomChatHint(
              onTap: match.conversationId == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ConversationScreen(
                            conversation: {'id': match.conversationId, 'title': '${game.name} table'},
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickReactionRow extends StatelessWidget {
  const _QuickReactionRow({required this.onSelect});
  final ValueChanged<String> onSelect;

  static const _emotes = ['👏', '🔥', '😂', '😎', '🎉', '😱', '🎯', '👑', '👋', 'GG', 'Nice!'];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _emotes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final emote = _emotes[index];
            return PressableScale(
              onTap: () => onSelect(emote),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: AppTheme.softShadow(dark: Theme.of(context).brightness == Brightness.dark),
                ),
                child: Center(
                  child: Text(
                    emote,
                    style: TextStyle(
                      fontSize: emote.length > 2 ? 12 : 16,
                      fontWeight: FontWeight.w900,
                      color: emote.length > 2 ? AppTheme.violet : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.status, required this.onTap});
  final GameSocketStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      GameSocketStatus.connected => AppTheme.mint,
      GameSocketStatus.connecting || GameSocketStatus.reconnecting => AppTheme.gold,
      GameSocketStatus.disconnected => Theme.of(context).disabledColor,
    };
    final label = switch (status) {
      GameSocketStatus.connected => 'Live connection is healthy',
      GameSocketStatus.connecting => 'Connecting to the live table…',
      GameSocketStatus.reconnecting => 'Reconnecting… tap to retry now',
      GameSocketStatus.disconnected => 'Live updates offline · tap to retry',
    };
    return IconButton(
      onPressed: status == GameSocketStatus.connected ? null : onTap,
      tooltip: label,
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 6)]),
      ),
    );
  }
}

class _SendingMoveOverlay extends StatelessWidget {
  const _SendingMoveOverlay();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withOpacity(.82), borderRadius: BorderRadius.circular(24)),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 12)]),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 9),
                Text('Sending move…', style: TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.14), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.gold.withOpacity(.35))),
        child: Row(
          children: [
            const Icon(Icons.sync_problem_rounded, size: 19, color: AppTheme.gold),
            const SizedBox(width: 9),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.name, required this.bot, required this.active, required this.winner, required this.color});
  final String name;
  final bool bot;
  final bool active;
  final bool winner;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        constraints: const BoxConstraints(maxWidth: 170),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(.13) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : Theme.of(context).dividerColor, width: active ? 1.5 : .6),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color.withOpacity(.2),
              child: Icon(bot ? Icons.smart_toy_rounded : Icons.person_rounded, size: 15, color: color),
            ),
            const SizedBox(width: 7),
            Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
            if (winner) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.emoji_events_rounded, size: 16, color: AppTheme.gold)),
          ],
        ),
      );
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.match, required this.game});
  final MatchModel match;
  final GameDescriptor game;

  @override
  Widget build(BuildContext context) {
    final viewer = match.players.where((player) => player['seat'] == match.viewerSeat).toList();
    final viewerResult = viewer.isEmpty ? null : viewer.first['result']?.toString();
    final winners = match.players.where((player) => match.winnerIds.contains(player['id'])).map((player) => player['displayName']?.toString() ?? 'Player').toList();
    final won = viewerResult == 'win';
    final lost = viewerResult == 'loss';
    final headline = match.draw ? 'It’s a draw' : won ? 'You won!' : lost ? 'Defeat' : winners.isEmpty ? 'Match complete' : '${winners.join(' and ')} won';
    final subline = match.draw ? 'Nobody takes the table this time.' : won ? 'Brilliant table — take the rewards.' : lost ? (winners.isEmpty ? 'Better luck at the next table.' : '${winners.join(' · ')} takes this one.') : winners.join(' · ');
    final icon = match.draw ? Icons.handshake_rounded : won ? Icons.celebration_rounded : Icons.sports_esports_rounded;
    final gradient = match.draw
        ? const LinearGradient(colors: [Color(0xFF0E3B32), Color(0xFF159A8C)])
        : won
            ? const LinearGradient(colors: [Color(0xFF2D2264), Color(0xFF7957F2)])
            : const LinearGradient(colors: [Color(0xFF2A2F45), Color(0xFF4A5170)]);
    final reward = match.reward;
    final xp = (reward?['xp'] as num?)?.toInt();
    final coins = (reward?['coins'] as num?)?.toInt();
    final before = viewer.isEmpty ? null : (viewer.first['ratingBefore'] as num?)?.toInt();
    final after = viewer.isEmpty ? null : (viewer.first['ratingAfter'] as num?)?.toInt();
    final delta = before != null && after != null ? after - before : null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: .96 + value * .04, alignment: Alignment.topCenter, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(22), boxShadow: AppTheme.glow(won ? AppTheme.violet : Colors.black45, strength: .35)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.gold, size: 32),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(headline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
                      if (subline.isNotEmpty) Text(subline, overflow: TextOverflow.ellipsis, maxLines: 2, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (xp != null && coins != null) ...[
              const Text('Rewards added to your profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RewardPill(icon: Icons.bolt_rounded, label: '+$xp XP'),
                  _RewardPill(icon: Icons.circle, label: '+$coins coins'),
                  if (delta != null && delta != 0) _RewardPill(icon: delta > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, label: '${delta > 0 ? '+' : ''}$delta rating'),
                ],
              ),
            ] else
              const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold)),
                  SizedBox(width: 9),
                  Expanded(child: Text('Result saved · rewards are being settled. This card will update automatically.', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700))),
                ],
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.home_rounded, color: Colors.white),
                    label: const Text('Back to games', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF2D2264)),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Play again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(99)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.gold),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
          ],
        ),
      );
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.6), borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).dividerColor)),
        child: const Row(
          children: [
            Icon(Icons.pause_circle_outline_rounded, size: 19),
            SizedBox(width: 9),
            Expanded(child: Text('This match was cancelled after too long without a move. No rating changed.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _TurnHint extends StatefulWidget {
  const _TurnHint({required this.match});
  final MatchModel match;
  @override
  State<_TurnHint> createState() => _TurnHintState();
}

class _TurnHintState extends State<_TurnHint> {
  Timer? ticker;
  Duration skew = Duration.zero;

  @override
  void initState() {
    super.initState();
    _syncSkew();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _TurnHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.turnDeadline != widget.match.turnDeadline || oldWidget.match.serverTime != widget.match.serverTime) _syncSkew();
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  void _syncSkew() {
    final serverTime = widget.match.serverTime;
    if (serverTime == null) {
      skew = Duration.zero;
      return;
    }
    skew = DateTime.tryParse(serverTime)?.difference(DateTime.now()) ?? Duration.zero;
  }

  Duration? _remaining() {
    final deadline = widget.match.turnDeadline;
    if (widget.match.status != 'active' || deadline == null) return null;
    return DateTime.tryParse(deadline)?.difference(DateTime.now().add(skew));
  }

  String _format(Duration remaining) {
    if (remaining <= Duration.zero) return '0:00';
    return '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final turnPlayers = match.players.where((player) => player['id'] == match.state['turnPlayerId']).toList();
    final turn = turnPlayers.isEmpty ? null : turnPlayers.first['displayName']?.toString();
    final viewer = match.players.where((player) => player['seat'] == match.viewerSeat).toList();
    final isYourTurn = viewer.isNotEmpty && viewer.first['id'] == match.state['turnPlayerId'];
    final remaining = _remaining();
    final urgent = remaining != null && remaining <= const Duration(seconds: 10);
    final message = match.status == 'finished'
        ? 'Match finished'
        : match.status == 'cancelled'
            ? 'Match cancelled'
            : turn == null
                ? 'Waiting for the table state'
                : isYourTurn
                    ? 'Your turn'
                    : 'Turn: $turn';
    final base = match.status == 'finished'
        ? AppTheme.gold
        : match.status == 'cancelled'
            ? Theme.of(context).disabledColor
            : isYourTurn
                ? AppTheme.mint
                : Theme.of(context).colorScheme.primary;
    final color = urgent ? AppTheme.coral : base;
    final trailing = match.status != 'active'
        ? null
        : remaining == null
            ? (isYourTurn ? 'Make your move' : 'Live')
            : _format(remaining);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(.2))),
      child: Row(
        children: [
          Icon(
            match.status == 'finished' || match.status == 'cancelled'
                ? Icons.flag_rounded
                : isYourTurn
                    ? Icons.touch_app_rounded
                    : Icons.timelapse_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(message, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: color))),
          if (trailing != null) Text(trailing, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _RoomChatHint extends StatelessWidget {
  const _RoomChatHint({this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.forum_outlined),
        label: const Text('Open table chat'),
      );
}

class GameCanvas extends StatefulWidget {
  const GameCanvas({super.key, required this.game, required this.state, required this.match, required this.onAction});
  final GameDescriptor game;
  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<GameCanvas> createState() => _GameCanvasState();
}

class _GameCanvasState extends State<GameCanvas> {
  final word = TextEditingController();

  @override
  void dispose() {
    word.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.game.id;
    if (id == 'four_in_a_row') return _four(context);
    if (id == 'chess') return _chess(context);
    if (id == 'ludo') return _ludo(context);
    if (id == 'pool_8_ball') return _pool(context);
    if (id == 'werewolf') return _werewolf(context);
    if (id == 'bingo') return BingoGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'dominoes') return DominoesGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'carrom') return CarromGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'mini_golf') return MiniGolfGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'table_soccer') return TableSoccerGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'sketch_guess') return SketchGuessGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'trivia_battle') return TriviaBattleGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'checkers') return CheckersGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'memory_race') return _memory(context);
    if (id == 'sea_battle') return SeaBattleGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'ocho') return _ocho(context);
    if (id == 'mancala') return MancalaGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'hearts' || id == 'spades') return HeartsGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'backgammon') return BackgammonGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'dice_party') return DicePartyGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'bowling') return BowlingGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'darts') return DartsGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'emoji_charades') return EmojiCharadesGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'impostor_light') return ImpostorLightGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'archery') return ArcheryGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    if (id == 'quick_challenges') return QuickChallengesGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
    return _generic(context);
  }

  Widget _four(BuildContext context) => FourInARowGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _chess(BuildContext context) => ChessGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _ludo(BuildContext context) => LudoGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _pool(BuildContext context) => PoolGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _werewolf(BuildContext context) => WerewolfGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);

  Widget _memory(BuildContext context) {
    final values = widget.state['values'] as List? ?? const [];
    final revealed = widget.state['revealed'] as List? ?? const [];
    final canAct = _canAct && widget.match.status != 'finished';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: values.length,
          itemBuilder: (_, index) {
            final visible = values[index] != null || (revealed.length > index && revealed[index] == true);
            return InkWell(
              onTap: visible || !canAct ? null : () => widget.onAction({'type': 'flip', 'index': index}),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(color: visible ? AppTheme.violet.withOpacity(.16) : AppTheme.violet, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text(
                    visible ? '${values[index] ?? '•'}' : '?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: visible ? AppTheme.violet : Colors.white),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _ocho(BuildContext context) => OchoGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);

  Widget _generic(BuildContext context) {
    if (widget.game.id == 'word_chain') {
      final canAct = _canAct;
      final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
      final turn = _turnName;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 52),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Build the chain', style: Theme.of(context).textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                finished
                    ? 'This table is complete.'
                    : canAct
                        ? 'Add a word that starts with the required letter.'
                        : 'Waiting for $turn to play…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: word,
                      enabled: canAct && !finished,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitWord(),
                      decoration: const InputDecoration(hintText: 'Type your word'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  FilledButton(onPressed: canAct && !finished ? _submitWord : null, child: const Icon(Icons.send_rounded)),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return _ComingSoon(game: widget.game, match: widget.match);
  }

  bool get _canAct {
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return widget.match.status == 'active' && viewer.isNotEmpty && widget.state['turnPlayerId'] == viewer.first['id'];
  }

  String get _turnName {
    final player = widget.match.players.where((candidate) => candidate['id'] == widget.state['turnPlayerId']).toList();
    return player.isEmpty ? 'the other player' : player.first['displayName']?.toString() ?? 'the other player';
  }

  void _submitWord() {
    final value = word.text.trim();
    if (value.isEmpty || !_canAct) return;
    widget.onAction({'type': 'word', 'word': value});
    word.clear();
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.game, required this.match});
  final GameDescriptor game;
  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final finished = match.status == 'finished' || match.state['finished'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GameLogo(gameId: game.id, accent: game.accent, size: 72),
            const SizedBox(height: 14),
            Text(
              finished ? 'Match complete' : '${game.name} is coming soon',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              finished
                  ? 'The final result is shown above.'
                  : 'This game does not have a mobile board yet, so the table is parked here. Your match is safe — check back after the next update.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to games'),
            ),
          ],
        ),
      ),
    );
  }
}
