import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
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
    final gameName = strings.gameName(widget.game.id, widget.game.name);
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Row(children: [GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 32), const SizedBox(width: 9), Expanded(child: VibeText(gameName))])),
      body: SafeArea(
        child: VibePageBackground(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
            children: [
              Entrance(child: _GameHero(game: widget.game)),
              const SizedBox(height: 22),
              Entrance(delay: const Duration(milliseconds: 60), child: VibeText(strings.isPersian ? 'میز خودت را بساز' : 'Set up your table', style: Theme.of(context).textTheme.headlineSmall)),
              const SizedBox(height: 7),
              Entrance(delay: const Duration(milliseconds: 90), child: VibeText(strings.isPersian ? 'حریف‌ها و قوانین را انتخاب کن؛ بعد وارد صف می‌شوی.' : 'Choose a room style and player count. We will find a fair table for you.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant))),
              const SizedBox(height: 22),
              Entrance(
                delay: const Duration(milliseconds: 120),
                child: _SetupCard(
                  title: strings.isPersian ? 'نوع بازی' : 'Game mode',
                  icon: Icons.tune_rounded,
                  color: AppTheme.violet,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: [ButtonSegment(value: 'casual', label: VibeText(strings.casual), icon: const Icon(Icons.celebration_outlined)), ButtonSegment(value: 'ranked', label: VibeText(strings.ranked), icon: const Icon(Icons.emoji_events_outlined))],
                          selected: {mode},
                          onSelectionChanged: busy ? null : (value) => setState(() => mode = value.first),
                        ),
                      ),
                      const SizedBox(height: 10),
                      VibeText(mode == 'ranked' ? 'Your result changes your seasonal rating.' : 'Play for fun while keeping your profile stats.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Entrance(
                delay: const Duration(milliseconds: 150),
                child: _SetupCard(
                  title: strings.isPersian ? 'تعداد بازیکن' : 'Players at the table',
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.mint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 9, runSpacing: 9, children: [for (var count = widget.game.minPlayers; count <= widget.game.maxPlayers; count++) _PlayerCountChip(count: count, selected: players == count, onTap: busy ? null : () => setState(() => players = count))]),
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.timer_outlined, size: 17, color: scheme.onSurfaceVariant), const SizedBox(width: 7), Expanded(child: VibeText('$players players · after 15 seconds, the table can start with a ready opponent.', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)))]),
                    ],
                  ),
                ),
              ),
              if (widget.game.supportsTeams) ...[
                const SizedBox(height: 13),
                Entrance(
                  delay: const Duration(milliseconds: 180),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.mint.withOpacity(.14), AppTheme.mint.withOpacity(.06)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.mint.withOpacity(.3))),
                    child: Row(children: [
                      Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.16), shape: BoxShape.circle), child: const Icon(Icons.groups_rounded, color: AppTheme.mint, size: 21)),
                      const SizedBox(width: 12),
                      Expanded(child: VibeText(strings.isPersian ? 'این بازی از تیم‌های متعادل پشتیبانی می‌کند.' : 'This game supports balanced teams.', style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ),
              ],
              if (error != null) ...[const SizedBox(height: 14), _SetupError(message: error!, onRetry: () => setState(() => error = null))],
              const SizedBox(height: 26),
              VibePrimaryButton(onPressed: busy ? null : _find, busy: busy, icon: Icons.radar_rounded, label: strings.findMatch),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: busy ? null : _instant, icon: const Icon(Icons.bolt_rounded), label: VibeText(strings.isPersian ? 'شروع فوری' : 'Start a table now'))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _find() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await ref.read(apiClientProvider).post('/matchmaking/join', data: {'gameId': widget.game.id, 'mode': mode, 'playerCount': players}) as Map;
      if (!mounted) return;
      final queuedAt = DateTime.tryParse(data['queuedAt']?.toString() ?? '');
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchQueueScreen(ticketId: data['id'] as String, game: widget.game, queuedAt: queuedAt, mode: mode, players: players)));
    } catch (e) {
      if (mounted) setState(() => error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _instant() async {
    setState(() {
      busy = true;
      error = null;
    });
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

class _GameHero extends StatelessWidget {
  const _GameHero({required this.game});
  final GameDescriptor game;

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 210,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppTheme.violet.withOpacity(.3), AppTheme.violet.withOpacity(0)]))),
              Container(width: 152, height: 152, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.violet.withOpacity(.1), border: Border.all(color: AppTheme.violet.withOpacity(.28), width: 1.5))),
              Hero(tag: 'game-${game.id}', child: FloatingGameLogo(gameId: game.id, accent: game.accent, size: 112, floatRange: 6)),
            ],
          ),
        ),
      );
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.title, required this.icon, required this.color, required this.child});
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => VibeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 19, color: color)),
              const SizedBox(width: 10),
              VibeText(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -.2)),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _PlayerCountChip extends StatelessWidget {
  const _PlayerCountChip({required this.count, required this.selected, required this.onTap});
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: SizedBox(width: 26, child: Center(child: VibeText('$count'))),
        selected: selected,
        onSelected: onTap == null ? null : (_) => onTap!(),
        showCheckmark: false,
        labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
        selectedColor: AppTheme.violet,
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      );
}

class _SetupError extends StatelessWidget {
  const _SetupError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(.2))),
        child: Row(children: [Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.onErrorContainer), const SizedBox(width: 9), Expanded(child: VibeText(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.w700))), IconButton(onPressed: onRetry, icon: const Icon(Icons.close_rounded))]),
      );
}

class MatchQueueScreen extends ConsumerStatefulWidget {
  const MatchQueueScreen({super.key, required this.ticketId, required this.game, this.queuedAt, this.mode = 'casual', this.players = 2});
  final String ticketId;
  final GameDescriptor game;
  final DateTime? queuedAt;
  final String mode;
  final int players;
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
    clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
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

  String get updatedAgo {
    final checked = lastChecked;
    if (checked == null) return 'Waiting for the first update';
    final ago = DateTime.now().difference(checked).inSeconds;
    if (ago < 5) return 'Updated just now';
    if (ago < 60) return 'Updated $ago seconds ago';
    return 'Updated ${ago ~/ 60} min ago';
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
        setState(() {
          queueStatus = nextStatus;
          error = 'Matchmaking ended. Please try again.';
        });
        return;
      }
      final rawMatch = data['match'];
      if (rawMatch is Map) {
        navigating = true;
        HapticFeedback.mediumImpact();
        pollTimer?.cancel();
        final match = Map<String, dynamic>.from(rawMatch);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameRoomScreen(matchId: match['id'] as String, game: widget.game)));
        return;
      }
      setState(() {
        queueStatus = nextStatus;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          consecutiveErrors += 1;
          error = 'Live queue updates are unavailable. Your place is being kept; we will keep trying.';
        });
      }
    } finally {
      polling = false;
    }
  }

  Future<void> _cancel() async {
    if (cancelling || navigating) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(title: const VibeText('Leave matchmaking?'), content: const VibeText('Your place in the queue will be cancelled.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const VibeText('Stay')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const VibeText('Leave queue'))]));
    if (confirmed != true || !mounted) return;
    setState(() {
      cancelling = true;
      error = null;
    });
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
        setState(() {
          cancelling = false;
          error = e is ApiException ? e.message : 'We could not leave the queue. Your place is still active.';
        });
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
        _ => fallbackReady ? 'No human table yet. A ready opponent will complete the table.' : 'We are looking for real players with a compatible table.',
      };

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    final progress = queueStatus == 'matched' ? 1.0 : (elapsedSeconds / 15).clamp(0.0, 1.0).toDouble();
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_cancel());
      },
      child: Scaffold(
        appBar: AppBar(leading: IconButton(onPressed: cancelling ? null : _cancel, icon: const Icon(Icons.close_rounded), tooltip: strings.cancel), title: Row(children: [GameLogo(gameId: widget.game.id, accent: widget.game.accent, size: 31), const SizedBox(width: 9), Expanded(child: VibeText(strings.isPersian ? 'در حال پیدا کردن حریف' : 'Finding your table'))])),
        body: SafeArea(
          child: VibePageBackground(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QueueArtwork(game: widget.game, matched: queueStatus == 'matched', pulse: (elapsedSeconds % 2) * .035),
                      const SizedBox(height: 20),
                      Entrance(delay: const Duration(milliseconds: 60), child: VibeText(_headline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall)),
                      const SizedBox(height: 8),
                      Entrance(delay: const Duration(milliseconds: 100), child: VibeText(_description, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35))),
                      const SizedBox(height: 14),
                      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                        _QueueChip(icon: widget.mode == 'ranked' ? Icons.emoji_events_outlined : Icons.celebration_outlined, label: widget.mode == 'ranked' ? 'Ranked' : 'Casual'),
                        _QueueChip(icon: Icons.people_alt_outlined, label: '${widget.players} players'),
                        _QueueChip(icon: Icons.videogame_asset_outlined, label: widget.game.name),
                      ]),
                      const SizedBox(height: 22),
                      VibeCard(
                        child: Column(children: [
                          Row(children: [
                            Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.13), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.schedule_rounded, size: 20, color: AppTheme.violet)),
                            const SizedBox(width: 10),
                            const VibeText('Queue time', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            const Spacer(),
                            VibeText(elapsedLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: .5)),
                          ]),
                          const SizedBox(height: 13),
                          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 10)),
                          const SizedBox(height: 10),
                          Align(alignment: AlignmentDirectional.centerStart, child: VibeText(fallbackReady ? 'A ready opponent is available' : 'Human search runs for up to 15 seconds', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      _QueueStep(icon: Icons.people_alt_rounded, title: 'Human players', active: queueStatus == 'queued' && !fallbackReady, complete: queueStatus == 'matched'),
                      _QueueStep(icon: Icons.bolt_rounded, title: 'Complete the table', active: fallbackReady, complete: queueStatus == 'matched'),
                      _QueueStep(icon: Icons.sync_rounded, title: 'Synchronize the game room', active: queueStatus == 'matched', complete: false),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        _QueueError(
                            message: error!,
                            retrying: consecutiveErrors > 0,
                            onRetry: () {
                              setState(() {
                                error = null;
                                consecutiveErrors = 0;
                              });
                              unawaited(_poll());
                            }),
                      ],
                      if (error == null) Padding(padding: const EdgeInsets.only(top: 10), child: VibeText(updatedAgo, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                      const SizedBox(height: 18),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: cancelling ? null : _cancel, icon: cancelling ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.close_rounded), label: VibeText(cancelling ? 'Leaving queue…' : strings.cancel))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueArtwork extends StatelessWidget {
  const _QueueArtwork({required this.game, required this.matched, required this.pulse});
  final GameDescriptor game;
  final bool matched;
  final double pulse;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 200,
        height: 172,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedScale(
              scale: matched ? 1 : 1 + pulse * 3,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              child: Container(width: 170, height: 170, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [(matched ? AppTheme.mint : AppTheme.violet).withOpacity(.32), AppTheme.violet.withOpacity(0)]))),
            ),
            Hero(tag: 'game-${game.id}', child: FloatingGameLogo(gameId: game.id, accent: game.accent, size: 100, floatRange: 5)),
          ],
        ),
      );
}

class _QueueChip extends StatelessWidget {
  const _QueueChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.6), borderRadius: BorderRadius.circular(99), border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 5), VibeText(strings.translateText(label), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
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
    final strings = AppStrings(Localizations.localeOf(context));
    final color = complete ? AppTheme.mint : active ? AppTheme.violet : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: complete || active ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(color, Colors.white, .1)!, color]) : null,
            color: complete || active ? null : color.withOpacity(.12),
            shape: BoxShape.circle,
            boxShadow: complete || active ? AppTheme.glow(color, strength: .3) : null,
          ),
          child: Icon(complete ? Icons.check_rounded : icon, size: 18, color: complete || active ? Colors.white : color),
        ),
        const SizedBox(width: 11),
        VibeText(strings.translateText(title), style: TextStyle(fontWeight: active || complete ? FontWeight.w800 : FontWeight.w600, color: active || complete ? null : Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _QueueError extends StatelessWidget {
  const _QueueError({required this.message, required this.retrying, required this.onRetry});
  final String message;
  final bool retrying;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(.2))),
        child: Row(children: [
          Icon(Icons.cloud_off_rounded, size: 19, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 9),
          Expanded(child: VibeText(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 12, fontWeight: FontWeight.w700))),
          TextButton(onPressed: onRetry, child: VibeText(retrying ? 'Retry now' : 'Retry')),
        ]),
      );
}
