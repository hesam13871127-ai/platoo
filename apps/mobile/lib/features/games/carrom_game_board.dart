import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';

class CarromGameBoard extends StatefulWidget {
  const CarromGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<CarromGameBoard> createState() => _CarromGameBoardState();
}

class _CarromGameBoardState extends State<CarromGameBoard> {
  final Set<int> selectedCoins = <int>{};
  double power = 65;
  bool queen = false;

  @override
  void didUpdateWidget(covariant CarromGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final remaining = _numbers(widget.state['remainingCoins']);
    if (oldWidget.match.revision != widget.match.revision) {
      selectedCoins.clear();
      queen = false;
    } else {
      selectedCoins.removeWhere((coin) => !remaining.contains(coin));
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _numbers(widget.state['remainingCoins']);
    final groups = (widget.state['groups'] as List? ?? const []).map((value) => value?.toString()).toList();
    final scores = _numbers(widget.state['scores']);
    final viewerGroup = widget.match.viewerSeat < groups.length ? groups[widget.match.viewerSeat] : null;
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    final isTurn = widget.match.status == 'active' && viewer.isNotEmpty && widget.state['turnPlayerId'] == viewer.first['id'];
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final pendingCover = (widget.state['queenPendingFor'] as num?)?.toInt() == widget.match.viewerSeat;
    final queenRemaining = widget.state['queenRemaining'] == true;
    final queenCall = queen && queenRemaining;
    final canStrike = isTurn && !finished && selectedCoins.length <= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.goldGradient, borderRadius: BorderRadius.circular(13), boxShadow: AppTheme.glow(AppTheme.gold, strength: .35)), child: const Icon(Icons.radio_button_checked_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          VibeText('Carrom', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          _CarromPill(label: viewerGroup == null ? 'Group open' : viewerGroup),
        ]),
        const SizedBox(height: 8),
        _StatusDot(text: _status(isTurn, pendingCover, finished), active: isTurn, finished: finished),
        _lastShotBanner(),
        const SizedBox(height: 11),
        _CarromBoard(
          remaining: remaining,
          queenAvailable: queenRemaining,
          queenPending: widget.state['queenPendingFor'] != null,
          selected: selectedCoins,
          group: viewerGroup,
          enabled: isTurn && !finished,
          onToggle: (coin) => setState(() {
            if (selectedCoins.contains(coin)) {
              selectedCoins.remove(coin);
            } else if (selectedCoins.length < 3) {
              selectedCoins.add(coin);
            }
          }),
        ),
        const SizedBox(height: 11),
        if (isTurn && !finished) ...[
          VibeCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: [
                Row(children: [
                  const VibeText('Power', style: TextStyle(fontWeight: FontWeight.w800)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(trackHeight: 8, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11), overlayShape: const RoundSliderOverlayShape(overlayRadius: 20), activeTrackColor: AppTheme.gold, inactiveTrackColor: AppTheme.gold.withOpacity(.18), thumbColor: Colors.white),
                      child: Slider(value: power, min: 1, max: 100, divisions: 99, label: power.round().toString(), onChanged: (value) => setState(() => power = value)),
                    ),
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: VibeText('${power.round()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                ]),
                if (queenRemaining) ...[
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: () => setState(() => queen = !queen),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: queen ? AppTheme.coral : AppTheme.coral.withOpacity(.18), shape: BoxShape.circle), child: VibeText('Q', style: TextStyle(color: queen ? Colors.white : AppTheme.coral, fontWeight: FontWeight.w900, fontSize: 14))),
                        const SizedBox(width: 10),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [VibeText('Call the queen', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), VibeText('Pocket her with one of your coins to cover', style: TextStyle(fontSize: 11))])),
                        AnimatedContainer(duration: const Duration(milliseconds: 180), width: 40, height: 22, alignment: queen ? Alignment.centerRight : Alignment.centerLeft, padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: queen ? AppTheme.coral : Theme.of(context).colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(99)), child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 11),
          VibePrimaryButton(onPressed: canStrike ? _submit : null, icon: Icons.sports_hockey_rounded, label: queenCall ? 'Pocket the queen' : pendingCover ? 'Cover the queen' : selectedCoins.isEmpty ? 'Strike' : 'Strike · ${selectedCoins.length}/3 coins'),
          const SizedBox(height: 8),
        ] else if (!finished)
          VibeText(pendingCover ? 'Cover the queen on your next turn.' : 'Waiting for the active player…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        _ScoreStrip(match: widget.match, scores: scores, groups: groups, turnPlayerId: widget.state['turnPlayerId']?.toString(), queenCoveredBy: (widget.state['queenCoveredBy'] as num?)?.toInt(), queenPendingFor: (widget.state['queenPendingFor'] as num?)?.toInt()),
      ],
    );
  }

  String _status(bool isTurn, bool pendingCover, bool finished) {
    if (finished) {
      final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
      final viewerId = viewer.isEmpty ? null : viewer.first['id']?.toString();
      if (widget.match.draw) return 'Draw · tied on points.';
      return widget.match.winnerIds.contains(viewerId) ? 'You settled the board!' : 'The board is settled.';
    }
    if (isTurn) return pendingCover ? 'Your turn · cover the queen with one of your coins.' : 'Your turn · target up to 3 coins, then strike.';
    return 'Choose your color by targeting a coin. The server resolves the strike and queen cover.';
  }

  Widget _lastShotBanner() {
    final raw = widget.state['lastShot'];
    if (raw is! Map || widget.match.status != 'active') return const SizedBox.shrink();
    final shot = Map<String, dynamic>.from(raw);
    final pocketed = (shot['pocketed'] as List? ?? const []).whereType<num>().map((coin) => coin.toInt()).toList();
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    final mine = viewer.isNotEmpty && shot['actorId']?.toString() == viewer.first['id']?.toString();
    final who = mine ? 'You' : _nameFor(shot['actorId']?.toString());
    final String text;
    final bool bad;
    if (shot['foul'] == true) {
      text = '$who committed a foul — a coin returns.';
      bad = true;
    } else if (shot['queen'] == true && pocketed.isNotEmpty) {
      text = '$who covered the queen and pocketed ${pocketed.join(' · ')}.';
      bad = false;
    } else if (shot['queen'] == true) {
      text = '$who took the queen — cover needed.';
      bad = false;
    } else if (pocketed.isNotEmpty) {
      text = '$who pocketed ${pocketed.join(' · ')}.';
      bad = false;
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: (bad ? AppTheme.coral : AppTheme.gold).withOpacity(.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: (bad ? AppTheme.coral : AppTheme.gold).withOpacity(.3))),
        child: Row(children: [Icon(bad ? Icons.flag_rounded : Icons.check_circle_rounded, size: 17, color: bad ? AppTheme.coral : AppTheme.gold), const SizedBox(width: 8), Expanded(child: VibeText(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))]),
      ),
    );
  }

  String _nameFor(String? id) {
    final found = widget.match.players.where((player) => player['id']?.toString() == id).toList();
    return found.isEmpty ? 'Opponent' : found.first['displayName']?.toString() ?? 'Opponent';
  }

  void _submit() {
    final coins = selectedCoins.toList()..sort();
    final calledQueen = queen && widget.state['queenRemaining'] == true;
    // Clear only after the server advances the revision; a failed request can
    // then be retried without rebuilding the strike from memory.
    widget.onAction({'type': 'strike', 'power': power.round(), 'targetCoins': coins, 'queen': calledQueen});
  }

  List<int> _numbers(dynamic value) => (value as List? ?? const []).whereType<num>().map((number) => number.toInt()).toList();
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.text, required this.active, required this.finished});
  final String text;
  final bool active;
  final bool finished;
  @override
  Widget build(BuildContext context) {
    final color = finished ? AppTheme.gold : active ? AppTheme.gold : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 8)])), const SizedBox(width: 9), Expanded(child: VibeText(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active && !finished ? null : Theme.of(context).colorScheme.onSurfaceVariant)))]);
  }
}

class _CarromBoard extends StatelessWidget {
  const _CarromBoard({required this.remaining, required this.queenAvailable, required this.queenPending, required this.selected, required this.group, required this.enabled, required this.onToggle});
  final List<int> remaining;
  final bool queenAvailable;
  final bool queenPending;
  final Set<int> selected;
  final String? group;
  final bool enabled;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? [const Color(0xFF8A5A36), const Color(0xFF5E3A20)] : [const Color(0xFFD39A61), const Color(0xFFB3793F)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF6E422C), width: 5), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 5))]),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: dark ? const Color(0xFFE3B981) : const Color(0xFFF2D0A4), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFF9D6842), width: 2)),
        child: Column(children: [
          const Row(children: [SizedBox(width: 30, height: 30, child: _PocketNet()), Spacer(), VibeText('TARGET COINS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Color(0xFF6B422D))), Spacer(), SizedBox(width: 30, height: 30, child: _PocketNet())]),
          const SizedBox(height: 10),
          if (remaining.isEmpty && !queenAvailable)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: VibeText('Board clear', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6B422D))))
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final coin in remaining) _Coin(coin: coin, selected: selected.contains(coin), enabled: enabled && _allowed(coin), dimmed: enabled && !_allowed(coin), onTap: () => onToggle(coin)),
                if (queenAvailable) _Queen(pending: queenPending),
              ],
            ),
          const SizedBox(height: 10),
          Row(children: [const SizedBox(width: 30, height: 30, child: _PocketNet()), const Spacer(), Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFB33A3A).withOpacity(.85), border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 20)), const Spacer(), const SizedBox(width: 30, height: 30, child: _PocketNet())]),
        ]),
      ),
    );
  }

  bool _allowed(int coin) {
    if (group == null) return true;
    return group == 'white' ? coin <= 9 : coin >= 10;
  }
}

class _PocketNet extends StatelessWidget {
  const _PocketNet();
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xFF000000), Color(0xFF3A2A26)]), border: Border.all(color: AppTheme.coral, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))]));
}

class _Coin extends StatelessWidget {
  const _Coin({required this.coin, required this.selected, required this.enabled, required this.dimmed, required this.onTap});
  final int coin;
  final bool selected;
  final bool enabled;
  final bool dimmed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final white = coin <= 9;
    return PressableScale(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: const Alignment(-.35, -.4), radius: 1.1, colors: white ? [const Color(0xFFFFF6E3), const Color(0xFFF0D9AE), const Color(0xFFC9A06B)] : [const Color(0xFF5A4644), const Color(0xFF3C2B2A), const Color(0xFF1D1515)], stops: const [0, .55, 1]),
          border: Border.all(color: selected ? AppTheme.gold : white ? const Color(0xFF9D6842) : const Color(0xFF1D1515), width: selected ? 3 : 1.5),
          boxShadow: [if (selected) ...AppTheme.glow(AppTheme.gold, strength: .5) else const BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))],
        ),
        child: Opacity(opacity: dimmed ? .4 : 1, child: VibeText('$coin', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: white ? const Color(0xFF583B2C) : Colors.white))),
      ),
    );
  }
}

class _Queen extends StatelessWidget {
  const _Queen({required this.pending});
  final bool pending;
  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(center: Alignment(-.35, -.4), radius: 1.1, colors: [Color(0xFFE87A7A), AppTheme.coral, Color(0xFF8E2F2F)], stops: [0, .55, 1]),
          border: Border.all(color: pending ? Colors.white : AppTheme.gold, width: pending ? 3 : 2),
          boxShadow: pending ? AppTheme.glow(Colors.white, strength: .5) : const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))],
        ),
        child: const VibeText('Q', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, shadows: [Shadow(color: Colors.black45, blurRadius: 2)])),
      );
}

class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({required this.match, required this.scores, required this.groups, required this.turnPlayerId, required this.queenCoveredBy, required this.queenPendingFor});
  final MatchModel match;
  final List<int> scores;
  final List<String?> groups;
  final String? turnPlayerId;
  final int? queenCoveredBy;
  final int? queenPendingFor;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: match.players.map((player) {
          final seat = (player['seat'] as num?)?.toInt() ?? 0;
          final score = seat < scores.length ? scores[seat] : 0;
          final active = player['id']?.toString() == turnPlayerId;
          final group = seat < groups.length ? groups[seat] : null;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: active ? AppTheme.gold.withOpacity(.16) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? AppTheme.gold : Theme.of(context).dividerColor, width: active ? 1.8 : 1)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (group != null) Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: group == 'white' ? const Color(0xFFF0D9AE) : const Color(0xFF3C2B2A), shape: BoxShape.circle, border: Border.all(color: Colors.black26))),
                VibeText('${player['displayName'] ?? 'Player'}  $score', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                if (queenCoveredBy == seat) ...[const SizedBox(width: 5), const VibeText('♛', style: TextStyle(fontSize: 13, color: AppTheme.gold))],
                if (queenPendingFor == seat) ...[const SizedBox(width: 5), const Icon(Icons.hourglass_bottom_rounded, size: 13, color: AppTheme.coral)],
              ],
            ),
          );
        }).toList(),
      );
}

class _CarromPill extends StatelessWidget {
  const _CarromPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.gold.withOpacity(.35))), child: VibeText(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)));
}
