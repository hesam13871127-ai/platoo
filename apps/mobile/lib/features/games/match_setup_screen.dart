import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_logo.dart';
import '../../models/models.dart';
import 'game_room_screen.dart';

class MatchSetupScreen extends ConsumerStatefulWidget {
  const MatchSetupScreen({super.key, required this.game});
  final GameDescriptor game;
  @override ConsumerState<MatchSetupScreen> createState() => _MatchSetupScreenState();
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
      appBar: AppBar(title: Text(widget.game.name, style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
        children: [
          Center(child: GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 96)),
          const SizedBox(height: 18),
          Text(strings.isPersian ? 'میز خودت را بساز' : 'Set up your table', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text(strings.isPersian ? 'حریف‌ها و قوانین را انتخاب کن؛ بعد وارد صف می‌شوی.' : 'Choose a room style and player count. We will find a fair table for you.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(strings.isPersian ? 'نوع بازی' : 'Game mode', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SegmentedButton<String>(segments: [ButtonSegment(value: 'casual', label: Text(strings.casual), icon: const Icon(Icons.celebration_outlined)), ButtonSegment(value: 'ranked', label: Text(strings.ranked), icon: const Icon(Icons.emoji_events_outlined))], selected: {mode}, onSelectionChanged: busy ? null : (value) => setState(() => mode = value.first)),
            const SizedBox(height: 9),
            Text(mode == 'ranked' ? 'Your result changes your seasonal rating.' : 'Play for fun while keeping your profile stats.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ]))),
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(strings.isPersian ? 'تعداد بازیکن' : 'Players at the table', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 9, runSpacing: 9, children: [for (var count = widget.game.minPlayers; count <= widget.game.maxPlayers; count++) ChoiceChip(label: Text('$count'), selected: players == count, onSelected: busy ? null : (_) => setState(() => players = count))]),
            const SizedBox(height: 9),
            Text('$players players · after 15 seconds, the table can start with an invisible bot.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ]))),
          if (widget.game.supportsTeams) Padding(padding: const EdgeInsets.only(top: 14), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.1), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.groups_rounded, color: AppTheme.mint), const SizedBox(width: 10), Expanded(child: Text(strings.isPersian ? 'این بازی از تیم‌ها پشتیبانی می‌کند.' : 'This game supports balanced teams.', style: const TextStyle(fontWeight: FontWeight.w700)))]))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 16), child: _SetupError(message: error!)),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: busy ? null : _find, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.radar_rounded), label: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(strings.findMatch))),
          const SizedBox(height: 9),
          OutlinedButton.icon(onPressed: busy ? null : _instant, icon: const Icon(Icons.smart_toy_outlined), label: Text(strings.isPersian ? 'بازی فوری با بات' : 'Start instantly with bots')),
        ],
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
      if (mounted) setState(() => error = e.toString());
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
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _SetupError extends StatelessWidget {
  const _SetupError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 9), Expanded(child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.w700)))]));
}

class MatchQueueScreen extends ConsumerStatefulWidget {
  const MatchQueueScreen({super.key, required this.ticketId, required this.game, this.queuedAt});
  final String ticketId;
  final GameDescriptor game;
  final DateTime? queuedAt;
  @override ConsumerState<MatchQueueScreen> createState() => _MatchQueueScreenState();
}

class _MatchQueueScreenState extends ConsumerState<MatchQueueScreen> {
  Timer? timer;
  DateTime? queueStartedAt;
  String queueStatus = 'queued';
  String? error;
  int seconds = 0;
  bool polling = false;
  bool cancelling = false;
  bool allowPop = false;

  @override
  void initState() {
    super.initState();
    queueStartedAt = widget.queuedAt;
    unawaited(_poll());
    timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_poll()));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  int get elapsedSeconds {
    final started = queueStartedAt;
    if (started == null) return seconds;
    return DateTime.now().difference(started).inSeconds.clamp(0, 3600).toInt();
  }

  bool get fallbackReady => elapsedSeconds >= 15 && queueStatus == 'queued';

  Future<void> _poll() async {
    if (polling || cancelling) return;
    polling = true;
    try {
      final data = await ref.read(apiClientProvider).get('/matchmaking/${widget.ticketId}') as Map;
      if (!mounted) return;
      final serverQueuedAt = DateTime.tryParse(data['queuedAt']?.toString() ?? '');
      if (serverQueuedAt != null) queueStartedAt = serverQueuedAt;
      final nextStatus = data['status']?.toString() ?? 'queued';
      if (queueStartedAt == null) seconds += 1;
      if (nextStatus == 'cancelled' || nextStatus == 'expired') {
        timer?.cancel();
        setState(() { queueStatus = nextStatus; error = 'Matchmaking ended. Please try again.'; });
        return;
      }
      final rawMatch = data['match'];
      if (rawMatch is Map) {
        timer?.cancel();
        final match = Map<String, dynamic>.from(rawMatch);
        await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameRoomScreen(matchId: match['id'] as String, game: widget.game)));
        return;
      }
      setState(() { queueStatus = nextStatus; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      polling = false;
    }
  }

  Future<void> _cancel() async {
    if (cancelling) return;
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Leave matchmaking?'), content: const Text('Your place in the queue will be cancelled.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave queue'))]));
    if (confirmed != true || !mounted) return;
    setState(() { cancelling = true; error = null; });
    timer?.cancel();
    try {
      await ref.read(apiClientProvider).delete('/matchmaking/leave', query: {'ticketId': widget.ticketId});
      if (mounted) {
        setState(() => allowPop = true);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() { cancelling = false; error = e.toString(); });
        timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_poll()));
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
        appBar: AppBar(leading: IconButton(onPressed: cancelling ? null : _cancel, icon: const Icon(Icons.close_rounded), tooltip: strings.cancel), title: Text(strings.isPersian ? 'در حال پیدا کردن حریف' : 'Finding your table')),
        body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 470), child: Column(mainAxisSize: MainAxisSize.min, children: [
          GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 82),
          const SizedBox(height: 22),
          Text(_headline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(_description, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35)),
          const SizedBox(height: 22),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [const Icon(Icons.schedule_rounded, size: 20, color: AppTheme.violet), const SizedBox(width: 8), const Text('Queue progress', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), Text('${elapsedSeconds}s', style: const TextStyle(fontWeight: FontWeight.w900))]),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 9)),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: Text(fallbackReady ? 'Bot fallback is ready' : 'Human search runs for up to 15 seconds', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
          ]))),
          const SizedBox(height: 12),
          _QueueStep(icon: Icons.people_alt_rounded, title: 'Human players', active: queueStatus == 'queued' && !fallbackReady, complete: queueStatus == 'matched'),
          _QueueStep(icon: Icons.smart_toy_rounded, title: 'Invisible bot fallback', active: fallbackReady, complete: queueStatus == 'matched'),
          _QueueStep(icon: Icons.sync_rounded, title: 'Synchronize the game room', active: queueStatus == 'matched', complete: false),
          if (error != null) ...[
            const SizedBox(height: 12),
            _SetupError(message: error!),
            const SizedBox(height: 8),
            TextButton.icon(onPressed: () => unawaited(_poll()), icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ],
          const SizedBox(height: 18),
          TextButton(onPressed: cancelling ? null : _cancel, child: Text(cancelling ? 'Leaving queue…' : strings.cancel)),
        ])))),
      ),
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
