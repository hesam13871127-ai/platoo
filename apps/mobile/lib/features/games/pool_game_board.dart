import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
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
  bool scratch = false;

  @override
  void didUpdateWidget(covariant PoolGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final remaining = _remaining;
    if (oldWidget.match.revision != widget.match.revision || (selectedBall != null && !remaining.contains(selectedBall))) {
      selectedBall = null;
      scratch = false;
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.sports_bar_rounded, color: Color(0xFF1C9B78)),
            const SizedBox(width: 8),
            const Text('Pool 8-ball', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            Text('${remaining.length} balls left', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 7),
          Align(alignment: Alignment.centerLeft, child: Text(_status(isTurn, group, ownRemaining), style: TextStyle(color: isTurn ? const Color(0xFF1C9B78) : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.45,
            child: LayoutBuilder(builder: (context, constraints) {
              final size = math.min(constraints.maxWidth, constraints.maxHeight);
              final ballSize = size * .075;
              return Stack(children: [
                Positioned.fill(child: CustomPaint(painter: const _PoolTablePainter())),
                for (final ball in remaining) _ballWidget(ball, constraints.maxWidth, constraints.maxHeight, ballSize, isTurn, group, ownRemaining, canEight),
              ]);
            }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            for (var index = 0; index < widget.match.players.length; index += 1) ...[
              if (index > 0) const SizedBox(width: 10),
              _GroupChip(name: _playerName(index), group: groups.length > index ? groups[index] : null, active: widget.state['turnIndex'] == index, color: index == viewerSeat ? AppTheme.violet : AppTheme.coral),
            ],
          ]),
          const SizedBox(height: 12),
          if (isTurn) ...[
            Row(children: [
              const Text('Power', style: TextStyle(fontWeight: FontWeight.w800)),
              Expanded(child: Slider(value: power, min: 20, max: 100, divisions: 80, label: '${power.round()}', onChanged: (value) => setState(() => power = value))),
              Text('${power.round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            Row(children: [
              const Text('Pocket', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Expanded(child: Wrap(spacing: 5, children: [for (var index = 0; index < 6; index += 1) ChoiceChip(label: Text('${index + 1}'), selected: selectedPocket == index, onSelected: (_) => setState(() => selectedPocket = index))])),
            ]),
            SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, title: const Text('Cue-ball scratch', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Use for a foul or a missed shot'), value: scratch, onChanged: (value) => setState(() => scratch = value)),
            FilledButton.icon(onPressed: () => _submit(), icon: const Icon(Icons.sports_bar_rounded), label: Text(_buttonLabel(canEight))),
          ] else Text('Waiting for the other player to take a shot…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }

  List<int> get _remaining => (widget.state['remainingBalls'] as List? ?? const []).map((ball) => (ball as num).toInt()).toList();

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

  String _buttonLabel(bool canEight) {
    if (widget.state['phase'] == 'break') return selectedBall == null ? 'Take dry break' : 'Break and pocket $selectedBall';
    if (canEight) return selectedBall == 8 ? 'Pocket the eight ball' : 'Call the eight ball';
    return selectedBall == null ? 'Take dry shot' : 'Pocket ball $selectedBall';
  }

  Widget _ballWidget(int ball, double width, double height, double size, bool isTurn, String? group, int ownRemaining, bool canEight) {
    final point = _ballPoint(ball);
    final selectable = isTurn && _canSelect(ball, group, ownRemaining, canEight);
    return Positioned(
      left: point.dx * width - size / 2,
      top: point.dy * height - size / 2,
      width: size,
      height: size,
      child: GestureDetector(onTap: selectable ? () => setState(() => selectedBall = selectedBall == ball ? null : ball) : null, child: _PoolBall(number: ball, selected: selectedBall == ball, enabled: selectable)),
    );
  }

  bool _canSelect(int ball, String? group, int ownRemaining, bool canEight) {
    if (widget.state['phase'] == 'break') return true;
    if (ball == 8) return canEight;
    if (group == null) return true;
    return ownRemaining > 0 && _groupFor(ball) == group;
  }

  void _submit() {
    final action = <String, dynamic>{'type': 'shot', 'power': power.round(), 'pocket': selectedPocket, 'pocketed': selectedBall == null ? <int>[] : [selectedBall], 'scratch': scratch};
    // Keep the local aim until a newer server revision arrives. This makes a
    // transient REST failure recoverable instead of silently losing the shot.
    widget.onAction(action);
  }

  String _groupFor(int ball) => ball <= 7 ? 'solids' : 'stripes';

  String _playerName(int seat) {
    final player = widget.match.players.where((candidate) => candidate['seat'] == seat).toList();
    return player.isEmpty ? 'Player ${seat + 1}' : player.first['displayName']?.toString() ?? 'Player ${seat + 1}';
  }

  Offset _ballPoint(int ball) {
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

class _PoolTablePainter extends CustomPainter {
  const _PoolTablePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final outer = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22));
    canvas.drawRRect(outer, Paint()..color = const Color(0xFF6E422C));
    final cloth = RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .035, size.height * .06, size.width * .93, size.height * .88), const Radius.circular(15));
    canvas.drawRRect(cloth, Paint()..color = const Color(0xFF167457));
    final inner = RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .065, size.height * .095, size.width * .87, size.height * .81), const Radius.circular(12));
    canvas.drawRRect(inner, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white24);
    final holes = [const Offset(.035, .06), const Offset(.965, .06), const Offset(.035, .94), const Offset(.965, .94), const Offset(.035, .5), const Offset(.965, .5)];
    for (final hole in holes) canvas.drawCircle(Offset(hole.dx * size.width, hole.dy * size.height), math.min(size.width, size.height) * .045, Paint()..color = const Color(0xFF17110F));
    canvas.drawLine(Offset(size.width * .16, size.height * .5), Offset(size.width * .84, size.height * .5), Paint()..color = Colors.white12..strokeWidth = 1);
  }
  @override
  bool shouldRepaint(covariant _PoolTablePainter oldDelegate) => false;
}

class _PoolBall extends StatelessWidget {
  const _PoolBall({required this.number, required this.selected, required this.enabled});
  final int number;
  final bool selected;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final stripe = number >= 9;
    final color = _ballColor(number);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(color: stripe ? Colors.white : color, shape: BoxShape.circle, border: Border.all(color: selected ? Colors.white : enabled ? color : Colors.black38, width: selected ? 3 : 1.2), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))]),
      child: Stack(alignment: Alignment.center, children: [
        if (stripe) Align(alignment: Alignment.center, child: Container(height: 7, color: color)),
        Container(width: 15, height: 15, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Center(child: Text('$number', style: TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.w900)))),
      ]),
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
  const _GroupChip({required this.name, required this.group, required this.active, required this.color});
  final String name;
  final String? group;
  final bool active;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), decoration: BoxDecoration(color: active ? color.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? color : Theme.of(context).dividerColor)), child: Column(children: [Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text(group ?? 'open table', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant))])));
}
