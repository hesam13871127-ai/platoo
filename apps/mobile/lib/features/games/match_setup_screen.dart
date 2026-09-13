import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';
import 'game_room_screen.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key, required this.game});
  final GameDescriptor game;
  @override
  ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends ConsumerState<MatchSetupScreen> {
  late int players;
  String mode = 'casual';
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    players = widget.game.minPlayers;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Row(children: [GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 32), const SizedBox(width: 9), Expanded(child: Text(widget.game.name))])),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
          children: [
            Center(child: Hero(tag: 'game-${widget.game.id}', child: GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 100))),
            const SizedBox(height: 20),
            Text(strings.isPersian ? 'میز خودت را بساز' : 'Set up your table', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 7),
            Text(strings.isPersian ? 'حریف‌ها و قوانین را انتخاب کن؛ بعد وارد صف می‌شوی.' : 'Choose a room style and player count. We will find a fair table for you.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 22),
            _SetupCard(title: strings.isPersian ? 'نوع بازی' : 'Game mode', icon: Icons.tune_rounded, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<String>(segments: [ButtonSegment(value: 'casual', label: Text(strings.casual), icon: const Icon(Icons.celebration_outlined)), ButtonSegment(value: 'ranked', label: Text(strings.ranked), icon: const Icon(Icons.emoji_events_outlined))], selected: {mode}, onSelectionChanged: busy ? null : (value) => setState(() => mode = value.first)),
              const SizedBox(height: 10),
              Text(mode == 'ranked' ? 'Your result changes your seasonal rating.' : 'Play for fun while keeping your profile stats.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ])),
            const SizedBox(height: 13),
            _SetupCard(title: strings.isPersian ? 'تعداد بازیکن' : 'Players at the table', icon: Icons.people_alt_rounded, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 9, runSpacing: 9, children: [for (var count = widget.game.minPlayers; count <= widget.game.maxPlayers; count++) ChoiceChip(label: Text('$count'), selected: players == count, onSelected: busy ? null : (_) => setState(() => players = count))]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.timer_outlined, size: 17, color: scheme.onSurfaceVariant), const SizedBox(width: 7), Expanded(child: Text('$players players · after 15 seconds, the table can start with an invisible bot.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)))]),
            ])),
            if (widget.game.supportsTeams) ...[
              const SizedBox(height: 13),
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.1), borderRadius: BorderRadius.circular(17), border: Border.all(color: AppTheme.mint.withOpacity(.24))), child: Row(children: [const Icon(Icons.groups_rounded, color: AppTheme.mint), const SizedBox(width: 10), Expanded(child: Text(strings.isPersian ? 'این بازی از تیم‌های متعادل پشتیبانی می‌کند.' : 'This game supports balanced teams.', style: const TextStyle(fontWeight: FontWeight.w700)))])),
            ],
            if (error != null) ...[const SizedBox(height: 14), _SetupError(message: error!, onRetry: () => setState(() => error = null))],
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: busy ? null : _find, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.radar_rounded), label: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(strings.findMatch))),
            const SizedBox(height: 9),
            OutlinedButton.icon(onPressed: busy ? null : _instant, icon: const Icon(Icons.smart_toy_outlined), label: Text(strings.isPersian ? 'بازی فوری با بات' : 'Start instantly with bots')),
          ],
        ),
      ),
    );
  }

  Future<void> _find() async {
    setState(() { busy = true; error = null; });
    try {
      final data = await ref.read(apiClientProvider).post('/matchmaking/join', data: {'gameId': widget.game.id, 'mode': mode, 'playerCount': players}) as Map;
      if (!mounted) return;
      final queuedAt = DateTime.tryParse(data['queuedAt']?.toString() ?? '');
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchQueueScreen(ticketId: data['id'] as String, game: widget.game, queuedAt: queuedAt)));
    } catch (e) {
      if (mounted) setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _instant() async {
    setState(() { busy = true; error = null; });
    try {
      final data = await ref.read(apiClientProvider).post('/matches', data: {'gameId': widget.game.id, 'mode': mode, 'desiredPlayers': players}) as Map;
      if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameRoomScreen(matchId: data['id'] as String, game: widget.game)));
    } catch (e) {
      if (mounted) setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _friendlyError(Object error) => error is ApiException ? error.message : 'We could not start matchmaking. Check your connection and try again.';
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]), const SizedBox(height: 12), child])));
}

class _SetupError extends StatelessWidget {
  const _SetupError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 9), Expanded(child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.w700))), IconButton(onPressed: onRetry, icon: const Icon(Icons.close_rounded))]));
}

class MatchQueueScreen extends ConsumerStatefulWidget {
  const MatchQueueScreen({super.key, required this.ticketId, required this.game, this.queuedAt});
  final String ticketId;
  final GameDescriptor game;
  final DateTime? queuedAt;
  @override
  ConsumerState<MatchQueueScreen> createState() => _MatchQueueScreenState();
}

class _MatchQueueScreenState extends ConsumerState<MatchQueueScreen> {
  Timer? pollTimer;
  Timer? clockTimer;
  DateTime? queueStartedAt;
  DateTime? lastChecked;
  String queueStatus = 'queued';
  String? error;
  int seconds = 0;
  int consecutiveErrors = 0;
  bool polling = false;
  bool cancelling = false;
  bool navigating = false;
  bool allowPop = false;

  @override
  void initState() {
    super.initState();
    queueStartedAt = widget.queuedAt;
    _startTimers();
    unawaited(_poll());
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    clockTimer?.cancel();
    super.dispose();
  }

  void _startTimers() {
    pollTimer?.cancel();
    clockTimer?.cancel();
    pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_poll()));
    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  int get elapsedSeconds {
    final started = queueStartedAt;
    if (started == null) return seconds;
    return DateTime.now().difference(started).inSeconds.clamp(0, 3600).toInt();
  }

  bool get fallbackReady => elapsedSeconds >= 15 && queueStatus == 'queued';

  String get elapsedLabel {
    final value = elapsedSeconds;
    final minutes = value ~/ 60;
    final remainder = value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  Future<void> _poll() async {
    if (polling || cancelling || navigating || !mounted) return;
    polling = true;
    try {
      final data = await ref.read(apiClientProvider).get('/matchmaking/${widget.ticketId}') as Map;
      if (!mounted) return;
      final serverQueuedAt = DateTime.tryParse(data['queuedAt']?.toString() ?? '');
      if (serverQueuedAt != null) queueStartedAt = serverQueuedAt;
      final nextStatus = data['status']?.toString() ?? 'queued';
      if (queueStartedAt == null) seconds += 3;
      lastChecked = DateTime.now();
      consecutiveErrors = 0;
      if (nextStatus == 'cancelled' || nextStatus == 'expired') {
        pollTimer?.cancel();
        setState(() { queueStatus = nextStatus; error = 'Matchmaking ended. Please try again.'; });
        return;
      }
      final rawMatch = data['match'];
      if (rawMatch is Map) {
        navigating = true;
        pollTimer?.cancel();
        final match = Map<String, dynamic>.from(rawMatch);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameRoomScreen(matchId: match['id'] as String, game: widget.game)));
        return;
      }
      setState(() { queueStatus = nextStatus; error = null; });
    } catch (e) {
      if (mounted) setState(() { consecutiveErrors += 1; error = 'Live queue updates are unavailable. Your place is being kept; we will keep trying.'; });
    } finally {
      polling = false;
    }
  }

  Future<void> _cancel() async {
    if (cancelling || navigating) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Leave matchmaking?'), content: const Text('Your place in the queue will be cancelled.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave queue'))]));
    if (confirmed != true || !mounted) return;
    setState(() { cancelling = true; error = null; });
    pollTimer?.cancel();
    clockTimer?.cancel();
    try {
      await ref.read(apiClientProvider).delete('/matchmaking/leave', query: {'ticketId': widget.ticketId});
      if (mounted) {
        allowPop = true;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() { cancelling = false; error = e is ApiException ? e.message : 'We could not leave the queue. Your place is still active.'; });
        _startTimers();
      }
    }
  }

  String get _headline => switch (queueStatus) {
    'matched' => 'Table found',
    'cancelled' || 'expired' => 'Queue ended',
    _ => fallbackReady ? 'Preparing your table' : 'Finding your table',
  };

  String get _description => switch (queueStatus) {
    'matched' => 'The room is being synchronized. One moment…',
    'cancelled' || 'expired' => 'This queue is no longer active.',
    _ => fallbackReady ? 'No human table yet. An invisible bot is ready to fill the seats.' : 'We are looking for real players with a compatible table.',
  };

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final progress = queueStatus == 'matched' ? 1.0 : (elapsedSeconds / 15).clamp(0.0, 1.0).toDouble();
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) unawaited(_cancel()); },
      child: Scaffold(
        appBar: AppBar(leading: IconButton(onPressed: cancelling ? null : _cancel, icon: const Icon(Icons.close_rounded), tooltip: strings.cancel), title: Row(children: [GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 31), const SizedBox(width: 9), Expanded(child: Text(strings.isPersian ? 'در حال پیدا کردن حریف' : 'Finding your table'))])),
        body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 30), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Hero(tag: 'game-${widget.game.id}', child: GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 86)),
          const SizedBox(height: 20),
          Text(_headline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_description, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35)),
          const SizedBox(height: 22),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Row(children: [const Icon(Icons.schedule_rounded, size: 20, color: AppTheme.violet), const SizedBox(width: 8), const Text('Queue time', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), Text(elapsedLabel, style: const TextStyle(fontWeight: FontWeight.w900))]), const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 9)), const SizedBox(height: 10), Align(alignment: AlignmentDirectional.centerStart, child: Text(fallbackReady ? 'Bot fallback is ready' : 'Human search runs for up to 15 seconds', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)))]))),
          const SizedBox(height: 12),
          _QueueStep(icon: Icons.people_alt_rounded, title: 'Human players', active: queueStatus == 'queued' && !fallbackReady, complete: queueStatus == 'matched'),
          _QueueStep(icon: Icons.smart_toy_rounded, title: 'Invisible bot fallback', active: fallbackReady, complete: queueStatus == 'matched'),
          _QueueStep(icon: Icons.sync_rounded, title: 'Synchronize the game room', active: queueStatus == 'matched', complete: false),
          if (error != null) ...[const SizedBox(height: 12), _QueueError(message: error!, retrying: consecutiveErrors > 0, onRetry: () { setState(() { error = null; consecutiveErrors = 0; }); unawaited(_poll()); })],
          if (lastChecked != null && error == null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Updated just now', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(height: 18),
          TextButton(onPressed: cancelling ? null : _cancel, child: Text(cancelling ? 'Leaving queue…' : strings.cancel)),
        ]))))),
      ),
    );
  }
}

class _QueueStep extends StatelessWidget {
  const _QueueStep({required this.icon, required this.title, required this.active, required this.complete});
  final IconData icon;
  final String title;
  final bool active;
  final bool complete;
  @override
  Widget build(BuildContext context) {
    final color = complete ? AppTheme.mint : active ? AppTheme.violet : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(children: [Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.12), shape: BoxShape.circle), child: Icon(complete ? Icons.check_rounded : icon, size: 17, color: color)), const SizedBox(width: 10), Text(title, style: TextStyle(fontWeight: active || complete ? FontWeight.w800 : FontWeight.w600, color: active || complete ? null : Theme.of(context).colorScheme.onSurfaceVariant))]));
  }
}

class _QueueError extends StatelessWidget {
  const _QueueError({required this.message, required this.retrying, required this.onRetry});
  final String message;
  final bool retrying;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(Icons.cloud_off_rounded, size: 19, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 9), Expanded(child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 12, fontWeight: FontWeight.w700))), TextButton(onPressed: onRetry, child: Text(retrying ? 'Retry now' : 'Retry'))]));
}
