import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';

class PoolGameBoard extends StatefulWidget {
  const PoolGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<PoolGameBoard> createState() => _PoolGameBoardState();
}

class _PoolGameBoardState extends State<PoolGameBoard> {
  int? selectedBall;
  int selectedPocket = 0;
  double power = 70;
  double aim = 0;

  static const pockets = [Offset(.035, .06), Offset(.965, .06), Offset(.035, .94), Offset(.965, .94), Offset(.035, .5), Offset(.965, .5)];

  @override
  void didUpdateWidget(covariant PoolGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final remaining = _remaining;
    if (oldWidget.match.revision != widget.match.revision || (selectedBall != null && !remaining.contains(selectedBall))) {
      selectedBall = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    final groups = (widget.state['groups'] as List? ?? const []).map((group) => group?.toString()).toList();
    final viewerSeat = widget.match.viewerSeat.clamp(0, 1).toInt();
    final viewer = widget.match.players.where((player) => player['seat'] == viewerSeat).toList();
    final viewerId = viewer.isEmpty ? null : viewer.first['id']?.toString();
    final isTurn = widget.match.status == 'active' && viewerId != null && widget.state['turnPlayerId'] == viewerId;
    final group = groups.length > viewerSeat ? groups[viewerSeat] : null;
    final ownRemaining = group == null ? 0 : remaining.where((ball) => ball != 8 && _groupFor(ball) == group).length;
    final canEight = group != null && ownRemaining == 0;
    final isBreak = widget.state['phase'] == 'break';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.mintGradient, borderRadius: BorderRadius.circular(13), boxShadow: AppTheme.glow(AppTheme.mint, strength: .35)), child: const Icon(Icons.sports_bar_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          VibeText('Pool 8-ball', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: AppTheme.mint.withOpacity(.3))), child: VibeText('${remaining.length} balls', style: const TextStyle(color: AppTheme.mint, fontWeight: FontWeight.w900, fontSize: 12))),
        ]),
        const SizedBox(height: 8),
        _StatusDot(text: _status(isTurn, group, ownRemaining), active: isTurn, finished: widget.match.status == 'finished'),
        _lastShotBanner(),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1.42,
          child: LayoutBuilder(builder: (context, constraints) {
            final size = math.min(constraints.maxWidth, constraints.maxHeight);
            final ballSize = size * .082;
            final dark = Theme.of(context).brightness == Brightness.dark;
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _PoolTablePainter(selectedPocket: selectedPocket, aim: aim, showCue: isTurn, dark: dark))),
              if (isBreak) Positioned(top: 10, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(.45), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withOpacity(.25))), child: const VibeText('BREAK SHOT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.4))))),
              for (var pocket = 0; pocket < 6; pocket += 1)
                Positioned(
                  left: pockets[pocket].dx * constraints.maxWidth - 22,
                  top: pockets[pocket].dy * constraints.maxHeight - 22,
                  width: 44,
                  height: 44,
                  child: GestureDetector(onTap: isTurn ? () => setState(() => selectedPocket = pocket) : null, behavior: HitTestBehavior.opaque, child: const SizedBox.expand()),
                ),
              for (final ball in remaining) _ballWidget(ball, constraints.maxWidth, constraints.maxHeight, ballSize, isTurn, group, ownRemaining, canEight, isBreak),
            ]);
          }),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (var index = 0; index < widget.match.players.length; index += 1) ...[
            if (index > 0) const SizedBox(width: 10),
            _GroupChip(name: _playerName(index), group: groups.length > index ? groups[index] : null, remaining: _remainingFor(groups.length > index ? groups[index] : null, remaining), active: widget.state['turnIndex'] == index, color: index == viewerSeat ? AppTheme.violet : AppTheme.coral),
          ],
        ]),
        const SizedBox(height: 12),
        if (isTurn) ...[
          VibeCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const VibeText('Power', style: TextStyle(fontWeight: FontWeight.w800)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(trackHeight: 8, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11), overlayShape: const RoundSliderOverlayShape(overlayRadius: 20), activeTrackColor: AppTheme.mint, inactiveTrackColor: AppTheme.mint.withOpacity(.18), thumbColor: Colors.white),
                      child: Slider(value: power, min: 20, max: 100, divisions: 80, label: '${power.round()}', onChanged: (value) => setState(() => power = value)),
                    ),
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppTheme.mint.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: VibeText('${power.round()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const VibeText('Aim', style: TextStyle(fontWeight: FontWeight.w800)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(trackHeight: 8, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11), overlayShape: const RoundSliderOverlayShape(overlayRadius: 20), activeTrackColor: AppTheme.violet, inactiveTrackColor: AppTheme.violet.withOpacity(.18), thumbColor: Colors.white),
                      child: Slider(value: aim, min: 0, max: 360, divisions: 36, label: '${aim.round()}°', onChanged: (value) => setState(() => aim = value)),
                    ),
                  ),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppTheme.violet.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: VibeText('${aim.round()}°', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const VibeText('Pocket', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [for (var index = 0; index < 6; index += 1) _PocketChip(number: index + 1, selected: selectedPocket == index, onTap: () => setState(() => selectedPocket = index))])),
                ]),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 12),
          VibePrimaryButton(onPressed: _submit, icon: Icons.sports_bar_rounded, label: _buttonLabel(canEight)),
        ] else
          VibeText('Waiting for the other player to take a shot…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  List<int> get _remaining => (widget.state['remainingBalls'] as List? ?? const []).map((ball) => (ball as num).toInt()).toList();

  int _remainingFor(String? group, List<int> remaining) {
    if (group == null) return remaining.where((ball) => ball != 8).length;
    return remaining.where((ball) => ball != 8 && _groupFor(ball) == group).length;
  }

  Widget _lastShotBanner() {
    final raw = widget.state['lastShot'];
    if (raw is! Map || widget.match.status != 'active') return const SizedBox.shrink();
    final shot = Map<String, dynamic>.from(raw);
    final pocketed = (shot['pocketed'] as List? ?? const []).map((ball) => (ball as num).toInt()).toList();
    if (pocketed.isEmpty && shot['scratch'] != true) return const SizedBox.shrink();
    final mine = shot['actorId']?.toString() == _viewerId;
    final who = mine ? 'You' : _nameFor(shot['actorId']?.toString());
    final text = shot['scratch'] == true ? '$who scratched — turn passes.' : '$who pocketed ${pocketed.join(' · ')}.';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: (shot['scratch'] == true ? AppTheme.coral : AppTheme.mint).withOpacity(.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: (shot['scratch'] == true ? AppTheme.coral : AppTheme.mint).withOpacity(.3))),
        child: Row(children: [Icon(shot['scratch'] == true ? Icons.warning_amber_rounded : Icons.check_circle_rounded, size: 17, color: shot['scratch'] == true ? AppTheme.coral : AppTheme.mint), const SizedBox(width: 8), Expanded(child: VibeText(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))]),
      ),
    );
  }

  String _status(bool isTurn, String? group, int ownRemaining) {
    if (widget.match.status == 'finished') return widget.match.winnerIds.contains(_viewerId) ? 'You won the rack!' : 'The rack is finished';
    if (!isTurn) return 'Waiting for the active player…';
    if (widget.state['phase'] == 'break') return 'Break shot · select a ball or take a dry break.';
    if (group == null) return 'Open table · pocket a ball to claim solids or stripes.';
    if (ownRemaining == 0) return 'Your group is clear · call the eight ball.';
    return 'Your group: $group · select one of your balls.';
  }

  String? get _viewerId {
    final viewer = widget.match.players.where((player) => player['seat'] == widget.match.viewerSeat).toList();
    return viewer.isEmpty ? null : viewer.first['id']?.toString();
  }

  String _nameFor(String? id) {
    final found = widget.match.players.where((player) => player['id']?.toString() == id).toList();
    return found.isEmpty ? 'Opponent' : found.first['displayName']?.toString() ?? 'Opponent';
  }

  String _buttonLabel(bool canEight) {
    if (widget.state['phase'] == 'break') return selectedBall == null ? 'Take dry break' : 'Break and pocket $selectedBall';
    if (canEight) return selectedBall == 8 ? 'Pocket the eight ball' : 'Call the eight ball';
    return selectedBall == null ? 'Take dry shot' : 'Pocket ball $selectedBall';
  }

  Widget _ballWidget(int ball, double width, double height, double size, bool isTurn, String? group, int ownRemaining, bool canEight, bool isBreak) {
    final point = _ballPoint(ball, isBreak);
    final selectable = isTurn && _canSelect(ball, group, ownRemaining, canEight);
    final targetSize = size * (selectedBall == ball ? 1.18 : 1);
    return Positioned(
      left: point.dx * width - targetSize / 2,
      top: point.dy * height - targetSize / 2,
      width: targetSize,
      height: targetSize,
      child: GestureDetector(
        onTap: selectable ? () => setState(() => selectedBall = selectedBall == ball ? null : ball) : null,
        child: AnimatedScale(scale: selectedBall == ball ? 1.12 : 1, duration: const Duration(milliseconds: 160), child: _PoolBall(number: ball, size: targetSize, selected: selectedBall == ball, enabled: selectable)),
      ),
    );
  }

  bool _canSelect(int ball, String? group, int ownRemaining, bool canEight) {
    if (widget.state['phase'] == 'break') return true;
    if (ball == 8) return canEight;
    if (group == null) return true;
    return ownRemaining > 0 && _groupFor(ball) == group;
  }

  void _submit() {
    final action = <String, dynamic>{'type': 'shot', 'power': power.round(), 'aim': aim.round(), 'pocket': selectedPocket, 'targetBall': selectedBall};
    // Keep the local aim until a newer server revision arrives. This makes a
    // transient REST failure recoverable instead of silently losing the shot.
    widget.onAction(action);
  }

  String _groupFor(int ball) => ball <= 7 ? 'solids' : 'stripes';

  String _playerName(int seat) {
    final player = widget.match.players.where((candidate) => candidate['seat'] == seat).toList();
    return player.isEmpty ? 'Player ${seat + 1}' : player.first['displayName']?.toString() ?? 'Player ${seat + 1}';
  }

  Offset _ballPoint(int ball, bool isBreak) {
    if (!isBreak) {
      // Stable deterministic scatter so mid-game tables look alive. Display
      // only — the server tracks which balls remain, not their positions.
      final x = .14 + ((ball * 37) % 68) / 100;
      final y = .2 + ((ball * 53 + 11) % 60) / 100;
      return Offset(x, y);
    }
    var cursor = 1;
    for (var row = 0; row < 5; row += 1) {
      for (var column = 0; column <= row; column += 1) {
        if (cursor == ball) return Offset(.57 + row * .052, .5 + (column - row / 2) * .095);
        cursor += 1;
      }
    }
    return const Offset(.57, .5);
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.text, required this.active, required this.finished});
  final String text;
  final bool active;
  final bool finished;
  @override
  Widget build(BuildContext context) {
    final color = finished ? AppTheme.gold : active ? AppTheme.mint : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 8)])), const SizedBox(width: 9), Expanded(child: VibeText(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active && !finished ? null : Theme.of(context).colorScheme.onSurfaceVariant)))]);
  }
}

class _PocketChip extends StatelessWidget {
  const _PocketChip({required this.number, required this.selected, required this.onTap});
  final int number;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? AppTheme.mint : Theme.of(context).colorScheme.surfaceVariant, shape: BoxShape.circle, border: Border.all(color: selected ? AppTheme.mint : Colors.transparent, width: 2), boxShadow: selected ? AppTheme.glow(AppTheme.mint, strength: .4) : null),
          child: VibeText('$number', style: TextStyle(fontWeight: FontWeight.w900, color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}

class _PoolTablePainter extends CustomPainter {
  const _PoolTablePainter({required this.selectedPocket, required this.aim, required this.showCue, required this.dark});
  final int selectedPocket;
  final double aim;
  final bool showCue;
  final bool dark;

  static const holes = [Offset(.035, .06), Offset(.965, .06), Offset(.035, .94), Offset(.965, .94), Offset(.035, .5), Offset(.965, .5)];

  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24));
    final rail = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? [const Color(0xFF5A3423), const Color(0xFF3A2015)] : [const Color(0xFF7D4E33), const Color(0xFF5A3423)]);
    canvas.drawRRect(outer, Paint()..shader = rail.createShader(Offset.zero & size));
    canvas.drawRRect(outer, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.black.withOpacity(.35));
    // Diamond sights along the rails.
    final sightPaint = Paint()..color = Colors.white.withOpacity(.75);
    for (var i = 1; i < 8; i += 1) {
      final x = size.width * (.07 + i * .12);
      canvas.drawCircle(Offset(x, size.height * .028), 2.2, sightPaint);
      canvas.drawCircle(Offset(x, size.height * .972), 2.2, sightPaint);
    }
    for (var i = 1; i < 4; i += 1) {
      final y = size.height * (.18 + i * .213);
      canvas.drawCircle(Offset(size.width * .017, y), 2.2, sightPaint);
      canvas.drawCircle(Offset(size.width * .983, y), 2.2, sightPaint);
    }
    final clothRect = Rect.fromLTWH(size.width * .035, size.height * .06, size.width * .93, size.height * .88);
    final cloth = RRect.fromRectAndRadius(clothRect, const Radius.circular(16));
    final felt = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? [const Color(0xFF14634A), const Color(0xFF0E4A37)] : [const Color(0xFF1B8A64), const Color(0xFF146B4D)]);
    canvas.drawRRect(cloth, Paint()..shader = felt.createShader(clothRect));
    // Soft center light.
    canvas.drawCircle(clothRect.center, math.min(size.width, size.height) * .42, Paint()..shader = RadialGradient(colors: [Colors.white.withOpacity(.08), Colors.white.withOpacity(0)]).createShader(Rect.fromCircle(center: clothRect.center, radius: math.min(size.width, size.height) * .42)));
    // Head string + foot spot.
    canvas.drawLine(Offset(size.width * .3, clothRect.top + 6), Offset(size.width * .3, clothRect.bottom - 6), Paint()..color = Colors.white.withOpacity(.14)..strokeWidth = 2);
    canvas.drawCircle(Offset(size.width * .68, clothRect.center.dy), 3.5, Paint()..color = Colors.white.withOpacity(.35));
    if (showCue) {
      final cueCenter = Offset(size.width * .22, clothRect.center.dy);
      final direction = Offset(math.cos(aim * math.pi / 180), math.sin(aim * math.pi / 180));
      final cueTip = cueCenter + direction * size.width * .31;
      final cueBack = cueCenter - direction * size.width * .13;
      canvas.drawLine(cueBack, cueTip, Paint()..color = Colors.white.withOpacity(.18)..strokeWidth = 7..strokeCap = StrokeCap.round);
      canvas.drawLine(cueBack, cueTip, Paint()..color = Colors.white.withOpacity(.72)..strokeWidth = 2..strokeCap = StrokeCap.round);
      canvas.drawCircle(cueCenter, math.min(size.width, size.height) * .026, Paint()..shader = RadialGradient(colors: [Colors.white, const Color(0xFFD8E6E1)]).createShader(Rect.fromCircle(center: cueCenter, radius: math.min(size.width, size.height) * .026)));
      canvas.drawCircle(cueCenter, math.min(size.width, size.height) * .026, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.white.withOpacity(.8));
    }
    // Pockets with rims and selection glow.
    for (var index = 0; index < holes.length; index += 1) {
      final center = Offset(holes[index].dx * size.width, holes[index].dy * size.height);
      final radius = math.min(size.width, size.height) * .052;
      canvas.drawCircle(center, radius + 2.5, Paint()..color = Colors.black.withOpacity(.5));
      canvas.drawCircle(center, radius, Paint()..shader = RadialGradient(colors: [const Color(0xFF000000), const Color(0xFF2A1E17)]).createShader(Rect.fromCircle(center: center, radius: radius)));
      if (index == selectedPocket) {
        canvas.drawCircle(center, radius + 5, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = AppTheme.mint);
        canvas.drawCircle(center, radius + 5, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..color = AppTheme.mint.withOpacity(.25));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PoolTablePainter oldDelegate) => oldDelegate.selectedPocket != selectedPocket || oldDelegate.aim != aim || oldDelegate.showCue != showCue || oldDelegate.dark != dark;
}

class _PoolBall extends StatelessWidget {
  const _PoolBall({required this.number, required this.size, required this.selected, required this.enabled});
  final int number;
  final double size;
  final bool selected;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final stripe = number >= 9;
    final color = _ballColor(number);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-.35, -.4), radius: 1.1, colors: stripe ? [Colors.white, const Color(0xFFD8D4E2)] : [Color.lerp(color, Colors.white, .45)!, color, Color.lerp(color, Colors.black, .3)!], stops: stripe ? const [0, 1] : const [0, .55, 1]),
        border: Border.all(color: selected ? Colors.white : enabled ? color.withOpacity(.8) : Colors.black38, width: selected ? 3 : 1.2),
        boxShadow: [if (selected) BoxShadow(color: Colors.white.withOpacity(.55), blurRadius: 12) else const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 2))],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (stripe) Container(height: size * .34, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
          Container(
            width: size * .44,
            height: size * .44,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Center(child: VibeText('$number', style: TextStyle(fontSize: size * .2, color: Colors.black, fontWeight: FontWeight.w900))),
          ),
          Positioned(top: size * .12, left: size * .18, child: Container(width: size * .22, height: size * .12, decoration: BoxDecoration(color: Colors.white.withOpacity(.65), borderRadius: BorderRadius.circular(99)))),
        ],
      ),
    );
  }

  Color _ballColor(int number) => switch (number) {
        1 || 9 => const Color(0xFFE8B331),
        2 || 10 => const Color(0xFF2E63B8),
        3 || 11 => const Color(0xFFD7463F),
        4 || 12 => const Color(0xFF6C3A9C),
        5 || 13 => const Color(0xFFE87A2D),
        6 || 14 => const Color(0xFF2E9A62),
        7 || 15 => const Color(0xFF8E2F2F),
        _ => Colors.black,
      };
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.name, required this.group, required this.remaining, required this.active, required this.color});
  final String name;
  final String? group;
  final int remaining;
  final bool active;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(color: active ? color.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? color : Theme.of(context).dividerColor, width: active ? 1.8 : 1)),
          child: Column(children: [
            VibeText(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 2),
            VibeText(group == null ? 'open table' : '$group · $remaining left', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? color : Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
}
