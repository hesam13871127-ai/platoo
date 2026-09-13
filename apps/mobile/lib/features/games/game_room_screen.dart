import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_service.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';
import 'game_socket.dart';
import 'four_in_a_row_game_board.dart';
import 'ocho_game_board.dart';
import 'chess_game_board.dart';
import 'ludo_game_board.dart';
import 'pool_game_board.dart';
import 'werewolf_game_board.dart';
import '../social/social_screen.dart';

class GameRoomScreen extends ConsumerStatefulWidget { const GameRoomScreen({super.key, required this.matchId, required this.game}); final String matchId; final GameDescriptor game; @override ConsumerState<GameRoomScreen> createState() => _GameRoomScreenState(); }
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
  GameSocketStatus socketStatus = GameSocketStatus.connecting;

  @override
  void initState() {
    super.initState();
    socket = GameSocket(ref.read(tokenStoreProvider));
    unawaited(socket.connect(matchId: widget.matchId, onUpdate: _acceptMatch, onError: _handleSocketError, onStatus: _handleSocketStatus));
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
    setState(() => socketStatus = status);
  }

  void _handleSocketError(String message) {
    if (!mounted) return;
    setState(() => error = message);
  }

  void _acceptMatch(Map<String, dynamic> data) {
    try {
      final next = MatchModel.fromJson(Map<String, dynamic>.from(data));
      if (!mounted) return;
      if (match != null && next.revision < match!.revision) return;
      setState(() {
        match = next;
        error = null;
      });
      if (next.status == 'finished') {
        if (next.reward != null) {
          poller?.cancel();
          completionGrace?.cancel();
          completionGrace = null;
        } else {
          completionGrace ??= Timer(const Duration(seconds: 20), () { poller?.cancel(); completionGrace = null; });
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
      if (mounted) setState(() => error = e.toString());
    } finally {
      loadInFlight = false;
    }
  }

  Future<void> _action(Map<String, dynamic> action) async {
    if (actionPending || match?.status != 'active') return;
    setState(() => actionPending = true);
    try {
      final data = await ref.read(apiClientProvider).post('/matches/${widget.matchId}/actions', data: action) as Map;
      _acceptMatch(Map<String, dynamic>.from(data));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => actionPending = false);
    }
  }

  void _retryLiveUpdates() {
    socket.retry();
    unawaited(_load());
  }

  String? get _syncMessage {
    if (error != null) return 'Showing the last confirmed state. ${error!}';
    return switch (socketStatus) {
      GameSocketStatus.connected => actionPending ? 'Sending your move…' : null,
      GameSocketStatus.connecting => 'Connecting to the live table…',
      GameSocketStatus.reconnecting => 'Live updates paused · reconnecting…',
      GameSocketStatus.disconnected => 'Live updates are offline · REST sync is still available.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final current = match;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
        title: Row(children: [
          GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.game.name, style: const TextStyle(fontWeight: FontWeight.w900))),
          if (current?.status == 'finished') const Icon(Icons.emoji_events_rounded, color: AppTheme.gold),
        ]),
        actions: [
          VoiceRoomButton(api: ref.read(apiClientProvider), matchId: widget.matchId),
          IconButton(onPressed: () => unawaited(_load()), icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh match'),
        ],
      ),
      body: current == null
          ? _RoomLoading(error: error, onRetry: _retryLiveUpdates)
          : _MatchBody(match: current, game: widget.game, onAction: _action, syncMessage: _syncMessage, onRetrySync: _retryLiveUpdates),
    );
  }
}

class _RoomLoading extends StatelessWidget {
  const _RoomLoading({required this.error, required this.onRetry});
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 18),
        Text(error == null ? 'Loading your table…' : 'We could not load this table.', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
        ],
      ]),
    ),
  );
}

class _MatchBody extends StatelessWidget {
  const _MatchBody({required this.match, required this.game, required this.onAction, required this.syncMessage, required this.onRetrySync});
  final MatchModel match;
  final GameDescriptor game;
  final ValueChanged<Map<String, dynamic>> onAction;
  final String? syncMessage;
  final VoidCallback onRetrySync;

  @override
  Widget build(BuildContext context) {
    return ListView(
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
                active: match.status == 'active' && match.state['turnPlayerId'] == player['id'],
                winner: match.winnerIds.contains(player['id']),
                color: index.isEven ? AppTheme.violet : AppTheme.coral,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (syncMessage != null) _SyncBanner(message: syncMessage!, onRetry: onRetrySync),
        if (match.status == 'finished') _ResultBanner(match: match),
        GameCanvas(game: game, state: match.state, match: match, onAction: onAction),
        const SizedBox(height: 14),
        _TurnHint(match: match),
        const SizedBox(height: 18),
        _RoomChatHint(onTap: match.conversationId == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConversationScreen(conversation: {'id': match.conversationId, 'title': '${game.name} table'})))),
      ],
    );
  }
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
    child: Row(children: [
      const Icon(Icons.sync_problem_rounded, size: 19, color: AppTheme.gold),
      const SizedBox(width: 9),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ]),
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
    decoration: BoxDecoration(color: active ? color.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? color : Theme.of(context).dividerColor, width: active ? 1.5 : .6)),
    child: Row(children: [
      CircleAvatar(radius: 14, backgroundColor: color.withOpacity(.2), child: Icon(bot ? Icons.smart_toy_rounded : Icons.person_rounded, size: 15, color: color)),
      const SizedBox(width: 7),
      Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
      if (winner) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.emoji_events_rounded, size: 16, color: AppTheme.gold)),
    ]),
  );
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.match});
  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final viewer = match.players.where((player) => player['seat'] == match.viewerSeat).toList();
    final viewerResult = viewer.isEmpty ? null : viewer.first['result']?.toString();
    final winners = match.players.where((player) => match.winnerIds.contains(player['id'])).map((player) => player['displayName']?.toString() ?? 'Player').toList();
    final headline = match.draw ? 'It’s a draw' : viewerResult == 'win' ? 'You won!' : viewerResult == 'loss' ? 'Match complete' : winners.isEmpty ? 'Match complete' : '${winners.join(' and ')} won';
    final reward = match.reward;
    final xp = (reward?['xp'] as num?)?.toInt();
    final coins = (reward?['coins'] as num?)?.toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2D2264), Color(0xFF7957F2)]), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.celebration_rounded, color: AppTheme.gold, size: 32),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(headline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
            if (winners.isNotEmpty && !match.draw) Text(winners.join(' · '), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
        ]),
        const SizedBox(height: 14),
        if (xp != null && coins != null) ...[
          const Text('Rewards added to your profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _RewardPill(icon: Icons.bolt_rounded, label: '+$xp XP'),
            _RewardPill(icon: Icons.circle, label: '+$coins coins'),
          ]),
        ] else const Text('Result saved · rewards will appear after the next sync.', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.home_rounded, color: Colors.white), label: const Text('Back to games', style: TextStyle(color: Colors.white))),
      ]),
    );
  }
}

class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: AppTheme.gold), const SizedBox(width: 5), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))]));
}

class _TurnHint extends StatelessWidget {
  const _TurnHint({required this.match});
  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final turnPlayers = match.players.where((player) => player['id'] == match.state['turnPlayerId']).toList();
    final turn = turnPlayers.isEmpty ? null : turnPlayers.first['displayName']?.toString();
    final message = match.status == 'finished' ? 'Match finished' : turn == null ? 'Waiting for the table state' : 'Turn: $turn';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(match.status == 'finished' ? Icons.flag_rounded : Icons.timelapse_rounded, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 9), Expanded(child: Text(message, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)))]));
  }
}

class _RoomChatHint extends StatelessWidget { const _RoomChatHint({this.onTap}); final VoidCallback? onTap; @override Widget build(BuildContext context) => OutlinedButton.icon(onPressed: onTap, icon: const Icon(Icons.forum_outlined), label: const Text('Open table chat')); }

class GameCanvas extends StatefulWidget { const GameCanvas({super.key, required this.game, required this.state, required this.match, required this.onAction}); final GameDescriptor game; final Map<String, dynamic> state; final MatchModel match; final ValueChanged<Map<String, dynamic>> onAction; @override State<GameCanvas> createState() => _GameCanvasState(); }
class _GameCanvasState extends State<GameCanvas> { int? selected; final word = TextEditingController(); @override void dispose() { word.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { final id = widget.game.id; if (id == 'four_in_a_row') return _four(context); if (id == 'chess') return _chess(context); if (id == 'ludo') return _ludo(context); if (id == 'pool_8_ball') return _pool(context); if (id == 'werewolf') return _werewolf(context); if (id == 'checkers') return _gridGame(context); if (id == 'memory_race') return _memory(context); if (id == 'sea_battle') return _sea(context); if (id == 'ocho') return _ocho(context); if (id == 'mancala') return _mancala(context); return _generic(context); }
  Widget _four(BuildContext context) => FourInARowGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _chess(BuildContext context) => ChessGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _ludo(BuildContext context) => LudoGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _pool(BuildContext context) => PoolGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _werewolf(BuildContext context) => WerewolfGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _gridGame(BuildContext context) {
    final board = (widget.state['board'] as List? ?? const []).map((row) => (row as List).toList()).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
            itemCount: 64,
            itemBuilder: (_, index) {
              final r = index ~/ 8;
              final c = index % 8;
              final value = board.length > r && board[r].length > c ? board[r][c]?.toString() : null;
              final dark = (r + c).isOdd;
              return InkWell(
                onTap: () {
                  if (selected == null && value != null) {
                    setState(() => selected = index);
                  } else if (selected != null) {
                    final from = selected!;
                    setState(() => selected = null);
                    widget.onAction({'type': 'move', 'fromRow': from ~/ 8, 'fromCol': from % 8, 'toRow': r, 'toCol': c});
                  }
                },
                child: Container(
                  color: dark ? const Color(0xFFB98D67) : const Color(0xFFF1D2A9),
                  child: Center(
                    child: Text(
                      _piece(value),
                      style: TextStyle(
                        fontSize: 25,
                        color: selected == index ? AppTheme.coral : (value != null && value == value.toUpperCase() ? Colors.white : const Color(0xFF241A18)),
                        shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 2))],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  Widget _memory(BuildContext context) { final values = widget.state['values'] as List? ?? const []; final revealed = widget.state['revealed'] as List? ?? const []; return Card(child: Padding(padding: const EdgeInsets.all(14), child: GridView.builder(physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: values.length, itemBuilder: (_, index) { final visible = values[index] != null || (revealed.length > index && revealed[index] == true); return InkWell(onTap: visible ? null : () => widget.onAction({'type': 'flip', 'index': index}), borderRadius: BorderRadius.circular(12), child: Container(decoration: BoxDecoration(color: visible ? AppTheme.violet.withOpacity(.16) : AppTheme.violet, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(visible ? '${values[index] ?? '•'}' : '?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: visible ? AppTheme.violet : Colors.white))))); }))); }
  Widget _sea(BuildContext context) {
    final shots = widget.state['shots'] as List? ?? const [];
    if (widget.state['phase'] == 'placing') {
      final fleets = widget.state['fleets'] as List? ?? const [];
      final placed = fleets.isNotEmpty ? (fleets[0] as List).length : 0;
      final sizes = [5, 4, 3, 3, 2];
      final size = sizes[placed < sizes.length ? placed : sizes.length - 1];
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Text('Place your fleet', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Ship ${placed + 1} of 5 · ${size} cells along the top row', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => widget.onAction({'type': 'place', 'cells': List.generate(size, (index) => [placed, index])}), icon: const Icon(Icons.anchor_rounded), label: const Text('Place ship')),
          ]),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Text('Tap a coordinate to fire', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10, crossAxisSpacing: 2, mainAxisSpacing: 2),
                itemCount: 100,
                itemBuilder: (_, index) {
                  final r = index ~/ 10;
                  final c = index % 10;
                  final value = shots.isNotEmpty && (shots[0] as List).length > r ? ((shots[0] as List)[r] as List)[c] : -1;
                  return InkWell(
                    onTap: value == -1 ? () => widget.onAction({'type': 'fire', 'row': r, 'column': c}) : null,
                    child: Container(color: value == 1 ? AppTheme.coral : const Color(0xFF58B7D2), child: value == 1 ? const Icon(Icons.close_rounded, color: Colors.white, size: 14) : null),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _ocho(BuildContext context) => OchoGameBoard(state: widget.state, match: widget.match, onAction: widget.onAction);
  Widget _mancala(BuildContext context) { final pits = widget.state['pits'] as List? ?? const []; final mine = pits.isNotEmpty ? pits[0] as List : const []; return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [const Text('Choose a pit', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 14), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (var i = 0; i < mine.length; i++) InkWell(onTap: () => widget.onAction({'type': 'sow', 'pit': i}), child: CircleAvatar(radius: 24, backgroundColor: AppTheme.coral.withOpacity(.16), child: Text('${mine[i]}', style: const TextStyle(fontWeight: FontWeight.w900))))])]))); }
  Widget _generic(BuildContext context) { final id = widget.game.id; final type = switch (id) { 'dice_party' => 'roll', 'ludo' => widget.state['pendingRoll'] == null ? 'roll' : 'move', 'backgammon' => (widget.state['dice'] as List? ?? const []).isEmpty ? 'roll' : 'move', 'bingo' => 'call', 'archery' => 'shoot', 'bowling' => 'roll', 'darts' => 'throw', 'mini_golf' => 'putt', 'table_soccer' => 'shoot', 'pool_8_ball' => 'shot', 'carrom' => 'strike', 'dominoes' => (widget.state['boneyard'] as List? ?? const []).isNotEmpty ? 'draw' : 'play', 'word_chain' => 'word', 'impostor_light' => (widget.state['phase'] == 'clues' ? 'clue' : 'vote'), 'trivia_battle' || 'sketch_guess' || 'emoji_charades' || 'quick_challenges' => 'answer', _ => 'challenge' }; if (id == 'word_chain') return Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Expanded(child: TextField(controller: word, decoration: const InputDecoration(hintText: 'Type your word'))), const SizedBox(width: 10), FilledButton(onPressed: () { widget.onAction({'type': 'word', 'word': word.text}); word.clear(); }, child: const Icon(Icons.send_rounded))]))); return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Icon(_actionIcon(type), size: 48, color: Color(int.parse('FF${widget.game.accent.replaceFirst('#', '')}', radix: 16))), const SizedBox(height: 12), Text(_actionLabel(type), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 16), FilledButton(onPressed: () => widget.onAction(_defaultAction(type, id)), child: Text(_actionLabel(type)))]))); }
  Map<String, dynamic> _defaultAction(String type, String id) { if (type == 'roll' && id == 'bowling') return {'type': 'roll', 'pins': 8}; return switch (type) { 'roll' => {'type': 'roll'}, 'move' => {'type': 'move', 'token': 0, 'from': -1, 'to': 0}, 'call' => {'type': 'call', 'number': 1}, 'shoot' => id == 'archery' ? {'type': 'shoot', 'accuracy': 50} : {'type': 'shoot', 'power': 70}, 'throw' => {'type': 'throw', 'value': 20}, 'putt' => {'type': 'putt', 'strokes': 3}, 'shot' => {'type': 'shot', 'power': 70, 'pocket': 0}, 'strike' => {'type': 'strike', 'power': 70, 'pocketed': 1, 'queen': false}, 'draw' => {'type': 'draw'}, 'play' => {'type': 'play', 'index': 0, 'side': 'right'}, 'clue' => {'type': 'clue', 'clue': 'bright'}, 'vote' => {'type': 'vote', 'target': 0}, 'answer' => {'type': 'answer', 'answer': 0}, _ => {'type': 'challenge', 'score': 60} }; }
  String _actionLabel(String type) => switch (type) { 'roll' => 'Roll dice', 'move' => 'Move token', 'call' => 'Call number', 'shoot' => 'Shoot', 'throw' => 'Throw', 'putt' => 'Putt', 'shot' => 'Take shot', 'strike' => 'Strike', 'draw' => 'Draw tile', 'play' => 'Play tile', 'clue' => 'Give clue', 'vote' => 'Vote', 'answer' => 'Answer', _ => 'Complete challenge' };
  IconData _actionIcon(String type) => switch (type) { 'roll' => Icons.casino_rounded, 'move' => Icons.directions_run_rounded, 'call' => Icons.confirmation_num_rounded, 'shoot' => Icons.gps_fixed_rounded, 'throw' => Icons.adjust_rounded, 'putt' => Icons.golf_course_rounded, 'shot' => Icons.sports_bar_rounded, 'strike' => Icons.radio_button_checked_rounded, 'draw' => Icons.add_box_rounded, 'play' => Icons.style_rounded, 'clue' => Icons.lightbulb_outline_rounded, 'vote' => Icons.how_to_vote_rounded, 'answer' => Icons.quiz_rounded, _ => Icons.bolt_rounded };
  String _piece(String? value) { if (value == null) return ''; return switch (value) { 'K' => '♔', 'Q' => '♕', 'R' => '♖', 'B' => '♗', 'N' => '♘', 'P' => '♙', 'k' => '♚', 'q' => '♛', 'r' => '♜', 'b' => '♝', 'n' => '♞', 'p' => '♟', _ => '●' }; }
}
