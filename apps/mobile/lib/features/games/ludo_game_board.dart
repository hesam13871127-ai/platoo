import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vibe_components.dart';
import '../../models/models.dart';

class LudoGameBoard extends StatelessWidget {
  const LudoGameBoard({super.key, required this.state, required this.match, required this.onAction});

  final Map<String, dynamic> state;
  final MatchModel match;
  final ValueChanged<Map<String, dynamic>> onAction;

  static const track = <Offset>[
    Offset(6, 0), Offset(6, 1), Offset(6, 2), Offset(6, 3), Offset(6, 4), Offset(6, 5),
    Offset(5, 6), Offset(4, 6), Offset(3, 6), Offset(2, 6), Offset(1, 6), Offset(0, 6), Offset(0, 7), Offset(0, 8),
    Offset(1, 8), Offset(2, 8), Offset(3, 8), Offset(4, 8), Offset(5, 8), Offset(6, 9), Offset(6, 10), Offset(6, 11), Offset(6, 12), Offset(6, 13), Offset(6, 14),
    Offset(7, 14), Offset(8, 14), Offset(8, 13), Offset(8, 12), Offset(8, 11), Offset(8, 10), Offset(8, 9), Offset(9, 8), Offset(10, 8), Offset(11, 8), Offset(12, 8), Offset(13, 8), Offset(14, 8), Offset(14, 7), Offset(14, 6),
    Offset(13, 6), Offset(12, 6), Offset(11, 6), Offset(10, 6), Offset(9, 6), Offset(8, 5), Offset(8, 4), Offset(8, 3), Offset(8, 2), Offset(8, 1), Offset(8, 0), Offset(7, 0),
  ];

  static const safeSquares = <int>{0, 8, 13, 21, 26, 34, 39, 47};
  static const colors = <Color>[AppTheme.coral, AppTheme.violet, Color(0xFF28A88A), AppTheme.gold];
  static const homeSpots = <List<Offset>>[
    [Offset(1, 10), Offset(3, 10), Offset(1, 12), Offset(3, 12)],
    [Offset(1, 1), Offset(3, 1), Offset(1, 3), Offset(3, 3)],
    [Offset(10, 1), Offset(12, 1), Offset(10, 3), Offset(12, 3)],
    [Offset(10, 10), Offset(12, 10), Offset(10, 12), Offset(12, 12)],
  ];
  static const finishLanes = <List<Offset>>[
    [Offset(1, 7), Offset(2, 7), Offset(3, 7), Offset(4, 7), Offset(5, 7)],
    [Offset(7, 1), Offset(7, 2), Offset(7, 3), Offset(7, 4), Offset(7, 5)],
    [Offset(13, 7), Offset(12, 7), Offset(11, 7), Offset(10, 7), Offset(9, 7)],
    [Offset(7, 13), Offset(7, 12), Offset(7, 11), Offset(7, 10), Offset(7, 9)],
  ];

  @override
  Widget build(BuildContext context) {
    final positions = (state['positions'] as List? ?? const []).map<List<int>>((side) => (side as List).map((position) => (position as num).toInt()).toList()).toList();
    final roll = (state['pendingRoll'] as num?)?.toInt();
    final viewerSeat = positions.isEmpty ? 0 : match.viewerSeat.clamp(0, positions.length - 1).toInt();
    final viewer = match.players.where((player) => player['seat'] == viewerSeat).toList();
    final viewerId = viewer.isEmpty ? null : viewer.first['id']?.toString();
    final isTurn = match.status == 'active' && viewerId != null && state['turnPlayerId'] == viewerId;
    final legal = roll == null || viewerSeat >= positions.length ? <int>[] : [for (var token = 0; token < positions[viewerSeat].length; token += 1) if (_canMove(positions, viewerSeat, token, roll)) token];
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(gradient: AppTheme.sunsetGradient, borderRadius: BorderRadius.circular(13), boxShadow: AppTheme.glow(AppTheme.coral, strength: .35)), child: const Icon(Icons.casino_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 10),
          VibeText('Ludo', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          AnimatedSwitcher(duration: const Duration(milliseconds: 260), transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child), child: roll != null ? _Die(value: roll, key: ValueKey(roll)) : _DiePlaceholder(dark: dark)),
        ]),
        const SizedBox(height: 8),
        _StatusDot(text: _status(isTurn, roll, legal), active: isTurn, finished: match.status == 'finished'),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (context, constraints) {
            final cell = constraints.maxWidth / 15;
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _LudoPainter(track: track, safeSquares: safeSquares, colors: colors, finishLanes: finishLanes, dark: dark))),
              for (var side = 0; side < positions.length && side < 4; side += 1)
                for (var token = 0; token < positions[side].length; token += 1)
                  _tokenWidget(context, side, token, positions[side][token], cell, viewerSeat, isTurn, roll, legal),
            ]);
          }),
        ),
        const SizedBox(height: 12),
        if (isTurn && roll == null) VibePrimaryButton(onPressed: () => onAction({'type': 'roll'}), icon: Icons.casino_rounded, label: 'Roll dice'),
        if (isTurn && roll != null && legal.isEmpty)
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => onAction({'type': 'pass'}), icon: Icon(roll == 6 ? Icons.refresh_rounded : Icons.skip_next_rounded), label: VibeText(roll == 6 ? 'No move · roll again' : 'No move · pass'))),
        if (isTurn && roll != null && legal.isNotEmpty)
          Builder(builder: (context) {
            final viewerColor = colors[viewerSeat.clamp(0, 3).toInt()];
            return Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), decoration: BoxDecoration(color: viewerColor.withOpacity(.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: viewerColor.withOpacity(.35))), child: Row(children: [Icon(Icons.touch_app_rounded, size: 17, color: viewerColor), const SizedBox(width: 8), VibeText('Rolled $roll · tap a glowing token', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))]));
          }),
        if (!isTurn) VibeText('Waiting for the active player…', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [for (var side = 0; side < positions.length && side < 4; side += 1) _PlayerChip(color: colors[side], label: _playerName(side), finished: positions[side].where((position) => position == 57).length, active: state['turnPlayerId'] == _idFor(side))]),
      ],
    );
  }

  String _status(bool isTurn, int? roll, List<int> legal) {
    if (match.status == 'finished') return match.draw ? 'Draw' : match.winnerIds.contains(_viewerId) ? 'You completed your tokens!' : 'The match is finished';
    if (!isTurn) return 'Waiting for the active player…';
    if (roll == null) return 'Your turn · roll to begin';
    if (legal.isEmpty) return roll == 6 ? 'No token can move · roll again' : 'No token can move · pass';
    return 'Rolled $roll · tap a highlighted token';
  }

  String? get _viewerId {
    final viewer = match.players.where((player) => player['seat'] == match.viewerSeat).toList();
    return viewer.isEmpty ? null : viewer.first['id']?.toString();
  }

  String? _idFor(int side) {
    final player = match.players.where((candidate) => candidate['seat'] == side).toList();
    return player.isEmpty ? null : player.first['id']?.toString();
  }

  String _playerName(int side) {
    final player = match.players.where((candidate) => candidate['seat'] == side).toList();
    return player.isEmpty ? 'Player ${side + 1}' : player.first['displayName']?.toString() ?? 'Player ${side + 1}';
  }

  bool _canMove(List<List<int>> positions, int side, int token, int roll) {
    final position = positions[side][token];
    if (position == 57) return false;
    if (position == -1 && roll != 6) return false;
    final destination = position == -1 ? 0 : position + roll;
    if (destination > 57) return false;
    final firstTrackProgress = position == -1 ? destination : position + 1;
    for (var progress = firstTrackProgress; progress <= math.min(destination, 51); progress += 1) {
      if (_hasOpponentBlockade(positions, side, progress)) return false;
    }
    return true;
  }

  bool _hasOpponentBlockade(List<List<int>> positions, int side, int progress) {
    if (progress >= 52) return false;
    final absolute = (side * 13 + progress) % 52;
    final sideTeam = _teamFor(side);
    var opponents = 0;
    for (var other = 0; other < positions.length; other += 1) {
      if (other == side || sideTeam != null && sideTeam == _teamFor(other)) continue;
      opponents += positions[other].where((position) => position >= 0 && position < 52 && (other * 13 + position) % 52 == absolute).length;
    }
    return opponents >= 2;
  }

  int? _teamFor(int side) {
    final player = match.players.where((candidate) => candidate['seat'] == side).toList();
    final team = player.isEmpty ? null : player.first['team'];
    return team is num ? team.toInt() : null;
  }

  Widget _tokenWidget(BuildContext context, int side, int token, int position, double cell, int viewerSeat, bool isTurn, int? roll, List<int> legal) {
    final point = _pointFor(side, token, position);
    final finished = position == 57;
    final size = cell * (finished ? .5 : .78);
    final selectable = side == viewerSeat && isTurn && roll != null && legal.contains(token);
    final offset = position >= 0 && position < 52 ? Offset((token % 2) * cell * .14, (token ~/ 2) * cell * .14) : Offset.zero;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
      left: point.dx * cell + (cell - size) / 2 + offset.dx,
      top: point.dy * cell + (cell - size) / 2 + offset.dy,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: selectable ? () => onAction({'type': 'move', 'token': token}) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: RadialGradient(center: const Alignment(-.35, -.4), radius: 1.1, colors: [Color.lerp(colors[side], Colors.white, .4)!, colors[side], Color.lerp(colors[side], Colors.black, .25)!], stops: const [0, .55, 1]),
            shape: BoxShape.circle,
            border: Border.all(color: selectable ? Colors.white : Colors.black26, width: selectable ? 3 : 1),
            boxShadow: [if (selectable) BoxShadow(color: colors[side].withOpacity(.7), blurRadius: 12, spreadRadius: 1) else const BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(1, 2))],
          ),
          child: Center(child: VibeText('${token + 1}', style: TextStyle(fontSize: cell * (finished ? .16 : .24), color: Colors.white, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black45, blurRadius: 2)]))),
        ),
      ),
    );
  }

  Offset _pointFor(int side, int token, int position) {
    if (position < 0) return homeSpots[side][token];
    if (position >= 52 && position < 57) return finishLanes[side][position - 52];
    if (position >= 57) return Offset(6.1 + (token % 2) * .55, 6.1 + (token ~/ 2) * .55);
    return track[(side * 13 + position) % 52];
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.text, required this.active, required this.finished});
  final String text;
  final bool active;
  final bool finished;
  @override
  Widget build(BuildContext context) {
    final color = finished ? AppTheme.gold : active ? AppTheme.coral : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 8)])), const SizedBox(width: 9), Expanded(child: VibeText(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: active && !finished ? null : Theme.of(context).colorScheme.onSurfaceVariant)))]);
  }
}

class _Die extends StatelessWidget {
  const _Die({super.key, required this.value});
  final int value;
  static const _pips = <int, List<int>>{
    1: [4],
    2: [2, 6],
    3: [2, 4, 6],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pips = _pips[value] ?? const [4];
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? [const Color(0xFF3A4152), const Color(0xFF262B3A)] : [Colors.white, const Color(0xFFE8E4F2)]),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.coral.withOpacity(.4), width: 1.5),
        boxShadow: AppTheme.glow(AppTheme.coral, strength: .3),
      ),
      child: GridView.count(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2, physics: const NeverScrollableScrollPhysics(), children: [for (var index = 0; index < 9; index += 1) pips.contains(index) ? Container(decoration: const BoxDecoration(color: AppTheme.coral, shape: BoxShape.circle)) : const SizedBox.shrink()]),
    );
  }
}

class _DiePlaceholder extends StatelessWidget {
  const _DiePlaceholder({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.5), borderRadius: BorderRadius.circular(13), border: Border.all(color: Theme.of(context).dividerColor)), child: Icon(Icons.casino_outlined, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant));
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.color, required this.label, required this.finished, required this.active});
  final Color color;
  final String label;
  final int finished;
  final bool active;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: active ? color.withOpacity(.13) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: active ? color : Theme.of(context).dividerColor, width: active ? 1.8 : 1)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(.5), blurRadius: 5)])),
            const SizedBox(width: 7),
            VibeText(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            VibeText('$finished/4', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: active ? color : Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
}

class _LudoPainter extends CustomPainter {
  const _LudoPainter({required this.track, required this.safeSquares, required this.colors, required this.finishLanes, required this.dark});
  final List<Offset> track;
  final Set<int> safeSquares;
  final List<Color> colors;
  final List<List<Offset>> finishLanes;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    final board = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    canvas.drawRRect(board, Paint()..color = dark ? const Color(0xFF1B2030) : const Color(0xFFF8F4ED));
    canvas.drawRRect(board, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = dark ? Colors.white12 : Colors.black12);
    for (var side = 0; side < 4; side += 1) {
      final base = switch (side) { 0 => const Offset(0, 9), 1 => const Offset(0, 0), 2 => const Offset(9, 0), _ => const Offset(9, 9) };
      final rect = Rect.fromLTWH(base.dx * cell, base.dy * cell, cell * 6, cell * 6);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), Paint()..color = colors[side].withOpacity(dark ? .28 : .18));
      final inner = rect.deflate(cell * .8);
      canvas.drawRRect(RRect.fromRectAndRadius(inner, const Radius.circular(10)), Paint()..color = dark ? const Color(0xFF262C3F).withOpacity(.92) : Colors.white.withOpacity(.85));
    }
    for (var index = 0; index < track.length; index += 1) {
      final rect = Rect.fromLTWH(track[index].dx * cell + 1, track[index].dy * cell + 1, cell - 2, cell - 2);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      final isStart = index % 13 == 0;
      final base = safeSquares.contains(index) ? (dark ? const Color(0xFF4A3A22) : const Color(0xFFFFE7BD)) : dark ? const Color(0xFF2A3042) : Colors.white;
      canvas.drawRRect(rrect, Paint()..color = isStart ? colors[index ~/ 13].withOpacity(dark ? .5 : .45) : base);
      canvas.drawRRect(rrect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = dark ? Colors.white10 : Colors.black12);
      if (safeSquares.contains(index) && !isStart) _drawStar(canvas, rect.center, cell * .18, dark ? const Color(0xFFE8B331) : const Color(0xFFB77A41));
      if (isStart) _drawStar(canvas, rect.center, cell * .2, Colors.white);
    }
    for (var side = 0; side < 4; side += 1) {
      for (var index = 0; index < finishLanes[side].length; index += 1) {
        final point = finishLanes[side][index];
        final rect = Rect.fromLTWH(point.dx * cell + 1, point.dy * cell + 1, cell - 2, cell - 2);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = colors[side].withOpacity(dark ? .5 : .25));
      }
    }
    final center = Rect.fromLTWH(6 * cell, 6 * cell, 3 * cell, 3 * cell);
    canvas.drawRect(center, Paint()..color = dark ? const Color(0xFF262C3F) : Colors.white);
    final triangles = [
      [Offset(6 * cell, 6 * cell), Offset(9 * cell, 6 * cell), Offset(7.5 * cell, 7.5 * cell)],
      [Offset(9 * cell, 6 * cell), Offset(9 * cell, 9 * cell), Offset(7.5 * cell, 7.5 * cell)],
      [Offset(9 * cell, 9 * cell), Offset(6 * cell, 9 * cell), Offset(7.5 * cell, 7.5 * cell)],
      [Offset(6 * cell, 9 * cell), Offset(6 * cell, 6 * cell), Offset(7.5 * cell, 7.5 * cell)],
    ];
    for (var side = 0; side < triangles.length; side += 1) {
      final path = Path()..addPolygon(triangles[side], true);
      canvas.drawPath(path, Paint()..color = colors[side].withOpacity(.8));
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var index = 0; index < 10; index += 1) {
      final angle = -math.pi / 2 + index * math.pi / 5;
      final length = index.isEven ? radius : radius * .42;
      final point = center + Offset(math.cos(angle) * length, math.sin(angle) * length);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LudoPainter oldDelegate) => oldDelegate.dark != dark || oldDelegate.track != track || oldDelegate.safeSquares != safeSquares;
}
