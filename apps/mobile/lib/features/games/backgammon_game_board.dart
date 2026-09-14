import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class BackgammonGameBoard extends StatefulWidget {
  const BackgammonGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  @override
  State<BackgammonGameBoard> createState() => _BackgammonGameBoardState();
}

class _BackgammonGameBoardState extends State<BackgammonGameBoard> {
  int? selectedFrom;

  @override
  void didUpdateWidget(covariant BackgammonGameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.revision != widget.match.revision) selectedFrom = null;
  }

  int get _seat => widget.match.viewerSeat;
  int get _own => _seat == 0 ? 1 : -1;

  List<int> get _points {
    final raw = widget.state['points'] as List? ?? const [];
    return List.generate(24, (i) => i < raw.length ? (raw[i] as num?)?.toInt() ?? 0 : 0);
  }

  List<int> get _dice {
    final raw = widget.state['dice'] as List? ?? const [];
    return raw.map((d) => (d as num?)?.toInt() ?? 0).where((d) => d > 0).toList();
  }

  int _countOf(dynamic value, int index) {
    final raw = value is List ? value : const [];
    return index < raw.length ? (raw[index] as num?)?.toInt() ?? 0 : 0;
  }

  bool get _isTurn {
    final viewer = widget.match.players.where((player) => player['seat'] == _seat).toList();
    return widget.match.status == 'active' && viewer.isNotEmpty && widget.state['turnPlayerId'] == viewer.first['id'];
  }

  bool _open(List<int> points, int to) => to == 24 || to == -1 || (to >= 0 && to < 24 && points[to] * _own >= -1);

  List<List<int>> _legalMoves(List<int> points, List<int> dice, int bar) {
    final moves = <List<int>>[];
    if (bar > 0) {
      for (final d in dice) {
        final to = _seat == 0 ? d - 1 : 24 - d;
        if (to >= 0 && to < 24 && _open(points, to)) moves.add([-1, to]);
      }
      return moves;
    }
    for (var from = 0; from < 24; from += 1) {
      if (points[from] * _own <= 0) continue;
      for (final d in dice) {
        final to = _seat == 0 ? from + d : from - d;
        if (_open(points, to)) moves.add([from, to]);
      }
    }
    return moves;
  }

  String _foeName() {
    final foe = widget.match.players.where((player) => player['seat'] != _seat).toList();
    return foe.isEmpty ? 'the other player' : foe.first['displayName']?.toString() ?? 'the other player';
  }

  void _tapPoint(int point, List<List<int>> moves, int bar) {
    if (!_isTurn || _dice.isEmpty) return;
    final from = bar > 0 ? -1 : selectedFrom;
    if (from != null && moves.any((m) => m[0] == from && m[1] == point)) {
      widget.onAction({'type': 'move', 'from': from, 'to': point});
      setState(() => selectedFrom = null);
      return;
    }
    if (bar > 0) return;
    final points = _points;
    if (points[point] * _own > 0 && moves.any((m) => m[0] == point)) {
      setState(() => selectedFrom = selectedFrom == point ? null : point);
    } else {
      setState(() => selectedFrom = null);
    }
  }

  void _tapTray(List<List<int>> moves, int bar) {
    if (!_isTurn || _dice.isEmpty) return;
    final from = bar > 0 ? -1 : selectedFrom;
    if (from == null) return;
    final off = _seat == 0 ? 24 : -1;
    if (moves.any((m) => m[0] == from && m[1] == off)) {
      widget.onAction({'type': 'move', 'from': from, 'to': off});
      setState(() => selectedFrom = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final dice = _dice;
    final bar = _countOf(widget.state['bar'], _seat);
    final foeBar = _countOf(widget.state['bar'], 1 - _seat);
    final off = _countOf(widget.state['borneOff'], _seat);
    final foeOff = _countOf(widget.state['borneOff'], 1 - _seat);
    final finished = widget.match.status == 'finished' || widget.state['finished'] == true;
    final moves = _isTurn && dice.isNotEmpty && !finished ? _legalMoves(points, dice, bar) : <List<int>>[];
    final from = bar > 0 && _isTurn ? -1 : selectedFrom;
    final targets = <int>{for (final m in moves) if (m[0] == from) m[1]};
    final canBearOff = targets.contains(_seat == 0 ? 24 : -1);
    final status = finished
        ? 'Match complete'
        : !_isTurn
            ? 'Waiting for ${_foeName()}…'
            : dice.isEmpty
                ? 'Your turn — roll the dice.'
                : moves.isEmpty
                    ? 'No legal moves — pass the dice.'
                    : bar > 0
                        ? 'Enter a checker from the bar.'
                        : from == null
                            ? 'Select one of your checkers.'
                            : 'Choose a highlighted point.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.casino_rounded, color: AppTheme.gold),
            const SizedBox(width: 8),
            const Text('Backgammon', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const Spacer(),
            for (final d in dice) _Die(value: d),
            if (dice.isEmpty && _isTurn && !finished)
              FilledButton.icon(onPressed: () => widget.onAction({'type': 'roll'}), icon: const Icon(Icons.casino_rounded, size: 18), label: const Text('Roll')),
            if (dice.isNotEmpty && moves.isEmpty && _isTurn && !finished)
              OutlinedButton.icon(onPressed: () => widget.onAction({'type': 'pass'}), icon: const Icon(Icons.skip_next_rounded, size: 18), label: const Text('Pass')),
          ]),
          const SizedBox(height: 7),
          Align(alignment: Alignment.centerLeft, child: Text(status, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFA9673B).withOpacity(.14), borderRadius: BorderRadius.circular(18)),
            child: Column(children: [
              Row(children: [
                for (var i = 0; i < 6; i += 1) Expanded(child: _Point(point: 12 + i, count: points[12 + i], top: true, selected: from == 12 + i, target: targets.contains(12 + i), seat: _seat, onTap: () => _tapPoint(12 + i, moves, bar))),
                _BarCell(count: foeBar, label: 'Foe', mine: false),
                for (var i = 6; i < 12; i += 1) Expanded(child: _Point(point: 12 + i, count: points[12 + i], top: true, selected: from == 12 + i, target: targets.contains(12 + i), seat: _seat, onTap: () => _tapPoint(12 + i, moves, bar))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                for (var i = 0; i < 6; i += 1) Expanded(child: _Point(point: 11 - i, count: points[11 - i], top: false, selected: from == 11 - i, target: targets.contains(11 - i), seat: _seat, onTap: () => _tapPoint(11 - i, moves, bar))),
                _BarCell(count: bar, label: 'You', mine: true),
                for (var i = 6; i < 12; i += 1) Expanded(child: _Point(point: 11 - i, count: points[11 - i], top: false, selected: from == 11 - i, target: targets.contains(11 - i), seat: _seat, onTap: () => _tapPoint(11 - i, moves, bar))),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: canBearOff ? () => _tapTray(moves, bar) : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: canBearOff ? AppTheme.mint.withOpacity(.25) : Theme.of(context).colorScheme.surfaceVariant.withOpacity(.5),
                    borderRadius: BorderRadius.circular(14),
                    border: canBearOff ? Border.all(color: AppTheme.mint, width: 2) : null,
                  ),
                  child: Text('Your off · $off/15${canBearOff ? ' — tap to bear off' : ''}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.5), borderRadius: BorderRadius.circular(14)),
                child: Text('Foe off · $foeOff/15', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.point, required this.count, required this.top, required this.selected, required this.target, required this.seat, required this.onTap});
  final int point;
  final int count;
  final bool top;
  final bool selected;
  final bool target;
  final int seat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final side = count > 0 ? 0 : count < 0 ? 1 : -1;
    final total = count.abs();
    const shown = 4;
    final checkers = List.generate(total > shown ? shown : total, (_) => _Checker(side: side));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 108,
        decoration: BoxDecoration(color: selected ? AppTheme.gold.withOpacity(.4) : target ? AppTheme.mint.withOpacity(.35) : null, borderRadius: BorderRadius.circular(8)),
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _TrianglePainter(color: (point.isEven ? const Color(0xFF8A5A33) : const Color(0xFFD9B382)).withOpacity(.55), up: !top))),
          if (side >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                mainAxisAlignment: top ? MainAxisAlignment.start : MainAxisAlignment.end,
                children: top
                    ? [...checkers, if (total > shown) _OverflowBadge(total: total)]
                    : [if (total > shown) _OverflowBadge(total: total), ...checkers.reversed],
              ),
            ),
          if (side < 0 && target) const Center(child: Icon(Icons.arrow_downward_rounded, color: AppTheme.mint, size: 18)),
        ]),
      ),
    );
  }
}

class _Checker extends StatelessWidget {
  const _Checker({required this.side});
  final int side;

  @override
  Widget build(BuildContext context) {
    final light = side == 0;
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: light ? const Color(0xFFF5EDE0) : const Color(0xFF3A2C22),
        shape: BoxShape.circle,
        border: Border.all(color: light ? const Color(0xFF8A5A33) : Colors.black54, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: (light ? const Color(0xFF8A5A33) : Colors.white54).withOpacity(.7))))),
    );
  }
}

class _OverflowBadge extends StatelessWidget {
  const _OverflowBadge({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
        child: Text('+$total', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
      );
}

class _BarCell extends StatelessWidget {
  const _BarCell({required this.count, required this.label, required this.mine});
  final int count;
  final String label;
  final bool mine;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: count > 0 && mine ? AppTheme.coral.withOpacity(.3) : Colors.black.withOpacity(.12),
          borderRadius: BorderRadius.circular(8),
          border: count > 0 && mine ? Border.all(color: AppTheme.coral, width: 2) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Die extends StatelessWidget {
  const _Die({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        margin: const EdgeInsets.only(left: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: AppTheme.gold, width: 2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1))]),
        child: Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF3A2C22))),
      );
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter({required this.color, required this.up});
  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (up) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width / 2, 0);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color || old.up != up;
}
